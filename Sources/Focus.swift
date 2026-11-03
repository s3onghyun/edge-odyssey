import AppKit
import QuartzCore

/// Focus mode's window content: a calm background, the large countdown and a caption in the
/// middle, and Start/Pause, Skip and Exit buttons that appear while the pointer moves. The
/// track and Odysseus are an Overlay's layers (`stage`), placed by FocusLayout.
/// Keys: Space starts, pauses or resumes; S skips; Esc exits. A click on the background exits.
final class FocusView: NSView {
    /// "toggle", "skip" or "exit".
    var onAction: ((String) -> Void)?
    /// The stage changed size: the scene has to be laid out again.
    var onResize: (() -> Void)?
    var spriteHeight: CGFloat = 26 * FocusLayout.travelerScale { didSet { needsLayout = true } }

    private let stage: CALayer
    private let canvas = NSView()      // layer-hosting: background content; controls sit above it
    private let content = CALayer()    // everything but the background (hidden while sharing)
    private let time = CATextLayer()
    private let caption = CATextLayer()
    private let primary = NSButton(title: "Start", target: nil, action: nil)
    private let skip = NSButton(title: "Skip", target: nil, action: nil)
    private let exit = NSButton(title: "Exit (Esc)", target: nil, action: nil)
    private let controls: NSStackView
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
        content.addSublayer(stage)
        for (l, weight) in [(time, NSFont.Weight.light), (caption, .regular)] {
            l.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: weight)
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
        addSubview(controls)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    private var dark: Bool { effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }

    /// Light and dark appearance: a deep night sea or a pale sand page, the digits in ink.
    override func updateLayer() {
        layer?.backgroundColor = (dark ? NSColor(srgbRed: 0.06, green: 0.07, blue: 0.10, alpha: 1)
                                       : NSColor(srgbRed: 0.97, green: 0.96, blue: 0.93, alpha: 1)).cgColor
        time.foregroundColor = (dark ? NSColor(white: 0.93, alpha: 1) : NSColor(srgbRed: 0.12, green: 0.13, blue: 0.17, alpha: 1)).cgColor
        caption.foregroundColor = (dark ? NSColor(white: 0.93, alpha: 0.55) : NSColor(srgbRed: 0.12, green: 0.13, blue: 0.17, alpha: 0.55)).cgColor
    }

    override func viewDidChangeBackingProperties() {
        let scale = window?.backingScaleFactor ?? 2
        time.contentsScale = scale
        caption.contentsScale = scale
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
        stage.frame = st
        time.fontSize = fs
        // CATextLayer draws from the top of its bounds: one line box, centred a little high.
        // Sized to the room, drawn across everything inside the traveler's band: never clipped.
        let band = st.insetBy(dx: spriteHeight, dy: spriteHeight)
        time.frame = CGRect(x: band.minX, y: (room.midY - fs * 0.5).rounded(), width: band.width, height: (fs * 1.25).rounded())
        caption.fontSize = cs
        caption.frame = CGRect(x: band.minX, y: time.frame.minY - cs * 1.8, width: band.width, height: cs * 1.4)
        CATransaction.commit()
        let c = controls.fittingSize
        controls.frame = CGRect(x: ((bounds.width - c.width) / 2).rounded(), y: (caption.frame.minY - c.height - cs * 1.5).rounded(),
                                width: c.width, height: c.height)
        if st.size != lastStage {
            lastStage = st.size
            onResize?()
        }
    }

    /// Called once a second while a session runs, and on every state change.
    func show(time t: String, caption c: String, primary p: String, skip s: String?, contentHidden: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if time.string as? String != t { time.string = t }
        if caption.string as? String != c { caption.string = c }
        content.isHidden = contentHidden
        CATransaction.commit()
        if t.count != glyphs { glyphs = t.count; needsLayout = true }
        if primary.title != p { primary.title = p }
        skip.title = s ?? "Skip"
        skip.isHidden = s == nil
        setAccessibilityLabel(contentHidden ? "Focus mode" : "\(c), \(t)")
    }

    // MARK: input

    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 49: onAction?("toggle")            // Space
        case 1: onAction?("skip")               // S
        case 53: onAction?("exit")              // Esc
        default: super.keyDown(with: e)
        }
    }

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

    @objc private func primaryPressed() { onAction?("toggle") }
    @objc private func skipPressed() { onAction?("skip") }
    @objc private func exitPressed() { onAction?("exit") }
}
