import AppKit
import CoreImage
import ImageIO
import QuartzCore

/// Focus mode's window content: a calm background, the dial (or, for the stopwatch, the large
/// count) with a caption beneath, preset chips while idle, and Start/Pause, Skip and Exit buttons
/// that appear while the pointer moves. The track and Odysseus are an Overlay's layers (`stage`),
/// placed by FocusLayout. Keys: Space starts, pauses or resumes; S skips; Esc exits; arrows (or
/// scrolling, or dragging the dial) change the time. A click on the background exits. Behind it
/// all, optionally, a dimmed nature photo.
final class FocusView: NSView {
    /// "toggle", "skip" or "exit".
    var onAction: ((String) -> Void)?
    /// The stage changed size: the scene has to be laid out again.
    var onResize: (() -> Void)?
    /// Scrolling anywhere in the window, and the arrow keys (steps, modifiers), change the time.
    var onScroll: ((NSEvent) -> Void)?
    var onAdjust: ((Int, NSEvent.ModifierFlags) -> Void)?
    /// A preset chip (minutes) was clicked.
    var onPreset: ((Double) -> Void)?
    let dial = DialView()
    var spriteHeight: CGFloat = 26 * FocusLayout.travelerScale { didSet { needsLayout = true } }

    private let stage: CALayer
    private let canvas = NSView()      // layer-hosting: background content; controls sit above it
    private let content = CALayer()    // everything but the window colour (hidden while sharing)
    private let backdrop = CALayer()   // the photo, softened once when it is picked
    private let scrim = CALayer()      // dims the photo so the time stays readable
    private var backdropURL: URL?
    private var hasBackdrop: Bool { backdrop.contents != nil }
    private let time = CATextLayer()
    private let caption = CATextLayer()
    private let footer = CATextLayer()   // today's total, at the foot of the voyage
    private let primary = NSButton(title: "", target: nil, action: nil)   // titled by show()
    private let skip = NSButton(title: "", target: nil, action: nil)
    private let exit = NSButton(title: "", target: nil, action: nil)
    private let controls: NSStackView
    private let chips = NSStackView()
    private var presets: [Double] = []
    private var dialShown = false
    private var timeText = "", captionText = "", footerText = ""
    private var sizes = (time: CGFloat(24), caption: CGFloat(14), footer: CGFloat(12))
    private var glyphs = 5
    private var lastStage = CGSize.zero
    private var hideTimer: Timer?

    init(stage: CALayer) {
        self.stage = stage
        controls = NSStackView(views: [primary, skip, exit])
        super.init(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        wantsLayer = true
        canvas.frame = bounds
        canvas.autoresizingMask = [.width, .height]
        canvas.layer = CALayer()
        canvas.wantsLayer = true
        addSubview(canvas)
        canvas.layer!.addSublayer(content)
        content.masksToBounds = true   // the drifting photo is a little larger than the window
        backdrop.contentsGravity = .resizeAspectFill
        scrim.backgroundColor = NSColor(white: 0, alpha: 0.42).cgColor
        content.addSublayer(backdrop)
        content.addSublayer(scrim)
        content.addSublayer(stage)
        for l in [time, caption, footer] {   // fonts: Typography, set with the text in paintText()
            l.alignmentMode = .center
            l.truncationMode = .end
            content.addSublayer(l)
        }
        for (b, sel) in [(primary, #selector(primaryPressed)), (skip, #selector(skipPressed)), (exit, #selector(exitPressed))] {
            b.target = self
            b.action = sel
            b.bezelStyle = .rounded
            b.controlSize = .large
        }
        controls.spacing = 12
        controls.alphaValue = 0
        controls.isHidden = true   // faded-out buttons take no clicks: a click there exits
        dial.onStep = { [weak self] in self?.onAdjust?($0, []) }
        addSubview(dial)
        chips.spacing = 8
        addSubview(chips)
        addSubview(controls)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    private var dark: Bool { effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }

    /// Light and dark appearance: a deep night sea or a pale sand page, the digits in ink.
    /// Over a photo the digits are always light, on a dark scrim.
    override func updateLayer() {
        layer?.backgroundColor = Palette.color(Tones.paper, dark: dark).cgColor
        dial.night = night
        paintText()
        for l in [time, caption, footer] {
            l.shadowOpacity = hasBackdrop ? 0.6 : 0
            l.shadowRadius = 6
            l.shadowOffset = .zero
        }
    }

    private var night: Bool { dark || hasBackdrop }
    private var ink: NSColor { hasBackdrop ? NSColor(white: 0.95, alpha: 1) : Palette.color(Tones.ink, dark: dark) }
    private var soft: NSColor { hasBackdrop ? NSColor(white: 0.95, alpha: 0.75) : Palette.color(Tones.muted, dark: dark) }

    /// The texts in their Typography roles: the hero count, captions in tracked medium.
    private func paintText() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        time.string = Typography.string(timeText, .hero, size: sizes.time, color: ink)
        caption.string = Typography.string(captionText, .caption, size: sizes.caption, color: soft)
        footer.string = Typography.string(footerText, .caption, size: sizes.footer, color: soft)
        CATransaction.commit()
    }

    /// Shows `url` (nil: none) behind the voyage, blurred a little and dimmed, with an optional
    /// slow drift. The picture is decoded at most 2048 px wide, so a huge photo costs no more.
    func setBackdrop(_ url: URL?, drift: Bool) {
        if url != backdropURL {
            backdropURL = url
            backdrop.contents = url.flatMap(Self.softened)
        }
        scrim.isHidden = !hasBackdrop
        backdrop.removeAnimation(forKey: "drift")
        if drift, hasBackdrop {   // Ken Burns: in the render server, a few frames a second is plenty
            let a = CABasicAnimation(keyPath: "transform")
            a.fromValue = CATransform3DMakeScale(1.04, 1.04, 1)
            a.toValue = CATransform3DConcat(CATransform3DMakeScale(1.12, 1.12, 1), CATransform3DMakeTranslation(-24, 12, 0))
            a.duration = 90
            a.autoreverses = true
            a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            a.preferredFrameRateRange = CAFrameRateRange(minimum: 4, maximum: 12, preferred: 10)
            backdrop.add(a, forKey: "drift")
        }
        needsDisplay = true
    }

    static func softened(_ url: URL) -> CGImage? {
        let opts = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2048,
                    kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts) else { return nil }
        let ci = CIImage(cgImage: img)
        return CIContext().createCGImage(ci.clampedToExtent().applyingGaussianBlur(sigma: 3), from: ci.extent)
    }

    override func viewDidChangeBackingProperties() {
        let scale = window?.backingScaleFactor ?? 2
        time.contentsScale = scale
        caption.contentsScale = scale
        footer.contentsScale = scale
    }

    override func layout() {
        super.layout()
        let st = FocusLayout.stage(in: bounds.size)
        let fs = FocusLayout.timeFontSize(stage: st, spriteHeight: spriteHeight, glyphs: glyphs)
        let room = FocusLayout.timeRoom(stage: st, spriteHeight: spriteHeight)
        let cs = max(14, (fs * 0.12).rounded())
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.frame = bounds
        backdrop.frame = bounds
        scrim.frame = bounds
        stage.frame = st
        let fs2 = max(12, (cs * 0.85).rounded())
        sizes = (fs, cs, fs2)
        // CATextLayer draws from the top of its bounds: one line box, centred a little high.
        // Sized to the room, drawn across everything inside the traveler's band: never clipped.
        let band = st.insetBy(dx: spriteHeight, dy: spriteHeight)
        let c = controls.fittingSize, k = chips.fittingSize
        if dialShown {   // the dial, then the caption, the chips and the buttons beneath it
            let d = FocusLayout.dial(room: room, reserve: cs * 2.2 + k.height + c.height + cs * 2)
            dial.frame = d
            caption.frame = CGRect(x: band.minX, y: d.minY - cs * 2, width: band.width, height: cs * 1.4)
        } else {
            time.frame = CGRect(x: band.minX, y: (room.midY - fs * 0.5).rounded(), width: band.width, height: (fs * 1.25).rounded())
            caption.frame = CGRect(x: band.minX, y: time.frame.minY - cs * 1.8, width: band.width, height: cs * 1.4)
        }
        footer.frame = CGRect(x: band.minX, y: band.minY + fs2 * 0.6, width: band.width, height: fs2 * 1.4)
        CATransaction.commit()
        paintText()
        chips.frame = CGRect(x: ((bounds.width - k.width) / 2).rounded(), y: (caption.frame.minY - k.height - cs).rounded(), width: k.width, height: k.height)
        controls.frame = CGRect(x: ((bounds.width - c.width) / 2).rounded(),
                                y: ((dialShown ? chips.frame.minY - cs : caption.frame.minY - cs * 1.5) - c.height).rounded(),
                                width: c.width, height: c.height)
        if st.size != lastStage {
            lastStage = st.size
            onResize?()
        }
    }

    /// Called once a second while a session runs, and on every state change. `dial`: nil shows the
    /// large count instead (the stopwatch). `presets`: chips (title, minutes), empty for none.
    func show(time t: String, caption c: String, primary p: String, skip s: String?, footer f: String, contentHidden: Bool,
              dial ds: DialView.State?, presets ps: [(title: String, minutes: Double)], selected: Double?) {
        if (t, c, f) != (timeText, captionText, footerText) { (timeText, captionText, footerText) = (t, c, f); paintText() }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.isHidden = contentHidden
        time.isHidden = ds != nil
        CATransaction.commit()
        if (ds != nil) != dialShown { dialShown = ds != nil; needsLayout = true }
        if let ds { dial.show(ds, time: t) }
        dial.isHidden = contentHidden || ds == nil
        if ps.map(\.minutes) != presets || chips.arrangedSubviews.map({ ($0 as? NSButton)?.title ?? "" }) != ps.map(\.title) {
            presets = ps.map(\.minutes)
            chips.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (i, preset) in ps.enumerated() {
                let b = NSButton(title: preset.title, target: self, action: #selector(presetPressed(_:)))
                b.tag = i
                b.bezelStyle = .rounded
                b.setButtonType(.pushOnPushOff)
                b.font = Typography.font(.numeral, size: NSFont.systemFontSize)
                chips.addArrangedSubview(b)
            }
            needsLayout = true
        }
        for case let b as NSButton in chips.arrangedSubviews { b.state = presets[b.tag] == selected ? .on : .off }
        chips.isHidden = contentHidden || ps.isEmpty
        if t.count != glyphs { glyphs = t.count; needsLayout = true }
        if primary.title != p { primary.title = p; needsLayout = true }   // the buttons are centred by width
        if skip.title != s ?? "" { skip.title = s ?? ""; needsLayout = true }
        skip.isHidden = s == nil
        let x = L.t("Exit (Esc)", "나가기 (Esc)", "終了 (Esc)", "退出 (Esc)")
        if exit.title != x { exit.title = x; needsLayout = true }
        setAccessibilityLabel(contentHidden ? L.t("Focus mode", "집중 모드", "集中モード", "专注模式") : "\(c), \(t)")
    }

    // MARK: input

    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 49: onAction?("toggle")            // Space
        case 1: onAction?("skip")               // S
        case 53: onAction?("exit")              // Esc
        case 126, 124: onAdjust?(1, e.modifierFlags)    // Up, Right: more time
        case 125, 123: onAdjust?(-1, e.modifierFlags)   // Down, Left: less
        default: super.keyDown(with: e)
        }
    }

    override func scrollWheel(with e: NSEvent) { onScroll?(e) }

    override func cancelOperation(_ sender: Any?) { onAction?("exit") }

    override func mouseUp(with e: NSEvent) {
        // The click that brings the window forward only activates it; the next one exits.
        if e.clickCount == 1, window?.isKeyWindow == true { onAction?("exit") }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    /// The controls fade in while the pointer moves and out a few seconds after it stops.
    override func mouseMoved(with e: NSEvent) {
        if controls.alphaValue < 1 || controls.isHidden {
            controls.isHidden = false
            NSAnimationContext.runAnimationGroup { $0.duration = 0.25; controls.animator().alphaValue = 1 }
        }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            guard let self, !self.controls.frame.contains(self.convert(self.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)) else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.6; self.controls.animator().alphaValue = 0 }) {
                if self.controls.alphaValue == 0 { self.controls.isHidden = true }
            }
        }
    }

    @objc private func presetPressed(_ b: NSButton) { onPreset?(presets[b.tag]) }
    @objc private func primaryPressed() { onAction?("toggle") }
    @objc private func skipPressed() { onAction?("skip") }
    @objc private func exitPressed() { onAction?("exit") }
}
