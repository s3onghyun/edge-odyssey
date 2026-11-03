import AppKit
import QuartzCore

/// The Time-Timer-style dial in focus mode (Dial has the math): a bezel with minute ticks and
/// numerals, gold detent dots, the wedge of time left (teal, coral in the session's last fifth,
/// lavender on a break), a sailboat handle at its edge and the countdown in the hub. Click or drag
/// to set it; the wheel and arrow keys reach it through FocusView. VoiceOver sees an adjustable slider.
final class DialView: NSView {
    enum Tone { case focus, rest, arrived }
    struct State { var left: Double; var total: Double; var tone: Tone; var settable: Bool }   // minutes

    /// Minutes picked by a click or a drag.
    var onSet: ((Double) -> Void)?
    /// VoiceOver's increment (+1) and decrement (-1).
    var onStep: ((Int) -> Void)?
    /// On a dark appearance or over a photo.
    var night = false { didSet { if night != oldValue { recolor() } } }

    private let bezel = CAShapeLayer(), face = CAShapeLayer(), minors = CAShapeLayer(), majors = CAShapeLayer()
    private let coral = CAShapeLayer(), teal = CAShapeLayer(), rim = CAShapeLayer(), dots = CAShapeLayer()
    private let hand = CALayer(), needle = CAShapeLayer(), boat = CALayer(), disc = CAShapeLayer(), hull = CAShapeLayer(), sail = CAShapeLayer()
    private let hub = CAShapeLayer(), time = CATextLayer(), bubble = CALayer(), bubbleText = CATextLayer()
    private let numerals = (0..<12).map { _ in CATextLayer() }
    private var state = State(left: 0, total: 0, tone: .focus, settable: false)
    private var timeText = ""
    private var dragMinutes = 0.0
    private var numeralSize: CGFloat = 11

    // Radii, set by layout: the bezel, the face (and wedge), the hub.
    private var rOuter: CGFloat = 0, rFace: CGFloat = 0, rHub: CGFloat = 0
    private var centre: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()   // layer-hosting: y up, like the rest of focus mode
        wantsLayer = true
        for l in [bezel, face, coral, teal, rim, dots, minors, majors] { layer!.addSublayer(l) }
        numerals.forEach { $0.alignmentMode = .center; layer!.addSublayer($0) }
        layer!.addSublayer(hand)
        hand.addSublayer(needle)
        hand.addSublayer(boat)
        [disc, hull, sail].forEach(boat.addSublayer)
        layer!.addSublayer(hub)
        layer!.addSublayer(time)
        layer!.addSublayer(bubble)
        bubble.addSublayer(bubbleText)
        for w in [coral, teal] { w.fillColor = nil; w.lineCap = .butt; w.strokeStart = 0; w.strokeEnd = 0 }
        rim.fillColor = nil
        time.alignmentMode = .center
        bubbleText.alignmentMode = .center
        bubble.opacity = 0
        bubble.backgroundColor = NSColor(srgbRed: 0.11, green: 0.12, blue: 0.15, alpha: 0.88).cgColor
        recolor()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeBackingProperties() {
        let s = window?.backingScaleFactor ?? 2
        (numerals + [time, bubbleText]).forEach { $0.contentsScale = s }
    }

    private func point(_ minutes: Double, _ r: CGFloat) -> CGPoint {
        let a = Dial.angle(minutes: minutes)
        return CGPoint(x: centre.x + r * CGFloat(sin(a)), y: centre.y + r * CGFloat(cos(a)))
    }

    private func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil) }

    override func layout() {
        super.layout()
        let R = min(bounds.width, bounds.height) / 2, c = centre
        rOuter = R * 0.86; rFace = R * 0.76; rHub = rFace * 0.44
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for l in [bezel, face, coral, teal, rim, dots, minors, majors, hub, needle] as [CALayer] { l.frame = bounds }
        // The hand and boat turn: frame is undefined under a transform, so place them by bounds and position.
        hand.bounds = bounds
        hand.position = c
        bezel.path = circle(c, rOuter)
        face.path = circle(c, rFace)
        hub.path = circle(c, rHub)
        rim.path = circle(c, rFace)
        rim.lineWidth = max(2, R * 0.018)
        // The wedge: a stroke as wide as the face's radius round a circle half as wide, from twelve
        // clockwise, so strokeEnd is the share of an hour and animates smoothly.
        let ring = CGMutablePath()
        ring.addArc(center: c, radius: rFace / 2, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        for w in [coral, teal] { w.path = ring; w.lineWidth = rFace }
        let minor = CGMutablePath(), major = CGMutablePath()
        for i in 0..<60 {
            let p = i % 5 == 0 ? major : minor
            p.move(to: point(Double(i), rFace + R * 0.02))
            p.addLine(to: point(Double(i), rFace + R * (i % 5 == 0 ? 0.085 : 0.05)))
        }
        minors.path = minor; minors.lineWidth = max(1, R * 0.006)
        majors.path = major; majors.lineWidth = max(1.5, R * 0.012)
        let dot = CGMutablePath()
        for m in Dial.detents { dot.addPath(circle(point(m, rFace - R * 0.05), max(2.5, R * 0.017))) }
        dots.path = dot
        let ns = max(9, (R * 0.062).rounded())
        numeralSize = ns
        for (i, n) in numerals.enumerated() {
            let p = point(Double(i * 5), R * 0.94)
            n.frame = CGRect(x: p.x - ns * 1.2, y: p.y - ns * 0.62, width: ns * 2.4, height: ns * 1.3)
        }
        paintNumerals()
        // The hand points to twelve and turns; the boat sits at its tip and turns back upright.
        let needlePath = CGMutablePath()
        needlePath.move(to: c)
        needlePath.addLine(to: CGPoint(x: c.x, y: c.y + rFace))
        needle.path = needlePath
        needle.lineWidth = max(1.5, R * 0.008)
        let hr = max(10, R * 0.075)
        boat.bounds = CGRect(x: 0, y: 0, width: 2 * hr, height: 2 * hr)
        boat.position = CGPoint(x: c.x, y: c.y + rFace)
        for l in [disc, hull, sail] { l.frame = boat.bounds }
        disc.path = circle(CGPoint(x: hr, y: hr), hr)
        disc.lineWidth = max(2, hr * 0.16)
        let h = CGMutablePath()   // a hull, a mast and a square sail, in the boat's own space
        h.move(to: CGPoint(x: hr * 0.42, y: hr * 0.72)); h.addLine(to: CGPoint(x: hr * 1.58, y: hr * 0.72))
        h.addLine(to: CGPoint(x: hr * 1.36, y: hr * 0.48)); h.addLine(to: CGPoint(x: hr * 0.64, y: hr * 0.48)); h.closeSubpath()
        h.addRect(CGRect(x: hr * 0.96, y: hr * 0.72, width: hr * 0.08, height: hr * 0.84))
        hull.path = h
        sail.path = CGPath(rect: CGRect(x: hr * 0.66, y: hr * 0.9, width: hr * 0.68, height: hr * 0.56), transform: nil)
        CATransaction.commit()
        paintTime()
        apply(animated: false)
    }

    // MARK: state

    /// Called once a second and on every change. A jump bigger than a tick (the user set the time)
    /// springs over ~0.18 s; the per-second tick moves without animation.
    func show(_ s: State, time t: String) {
        let animated = abs(s.left - state.left) > 0.05 && rFace > 0
        let retone = s.tone != state.tone
        state = s
        if t != timeText { timeText = t; paintTime() }
        if retone { recolor() }
        apply(animated: animated)
    }

    private func apply(animated: Bool) {
        let s = state, left = s.tone == .arrived ? 0 : s.left
        let w = Dial.wedge(left: left, total: s.total), a = CGFloat(Dial.angle(minutes: left))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        set(coral, "strokeEnd", w.coral / Dial.faceMinutes, animated)
        set(teal, "strokeStart", w.coral / Dial.faceMinutes, animated)
        set(teal, "strokeEnd", w.teal / Dial.faceMinutes, animated)
        set(hand, "transform.rotation.z", -a, animated)
        set(boat, "transform.rotation.z", a, animated)
        hand.isHidden = s.tone == .arrived
        rim.isHidden = s.tone != .arrived
        CATransaction.commit()
        setAccessibilityEnabled(s.settable)
    }

    private func set(_ l: CALayer, _ key: String, _ v: Any, _ animated: Bool) {
        if animated, let from = l.presentation()?.value(forKeyPath: key) {
            let sp = CASpringAnimation(keyPath: key)
            sp.fromValue = from
            sp.toValue = v
            sp.stiffness = 600
            sp.damping = 49   // critically damped: no wobble past the new time
            sp.duration = 0.18
            l.add(sp, forKey: key)
        }
        l.setValue(v, forKeyPath: key)
    }

    /// A small "+1m" note by the boat, for a wheel or arrow step.
    func nudge(_ text: String) {
        guard rFace > 0 else { return }
        let fs = max(11, (rOuter * 0.06).rounded())
        let str = Typography.string(text, .numeral, size: fs, weight: .semibold, color: .white)
        let w = str.size().width + fs * 1.2, h = fs * 1.7
        let p = point(state.tone == .arrived ? 0 : state.left, rFace * 0.62)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bubble.frame = CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h)
        bubble.cornerRadius = h / 2
        bubbleText.string = str
        bubbleText.frame = CGRect(x: 0, y: (h - fs * 1.25) / 2, width: w, height: fs * 1.25)   // one line box, centred
        CATransaction.commit()
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.7, 1]
        fade.duration = 1.2
        bubble.add(fade, forKey: "fade")
    }

    // MARK: colours

    private var ink: NSColor { night ? NSColor(white: 0.95, alpha: 1) : NSColor(srgbRed: 0.12, green: 0.13, blue: 0.17, alpha: 1) }
    private var numeralColor: NSColor { ink.withAlphaComponent(0.5) }

    private func recolor() {
        let calm = state.tone == .rest ? Palette.rest : Palette.calm
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bezel.fillColor = (night ? NSColor(white: 1, alpha: 0.06) : NSColor(srgbRed: 1, green: 0.995, blue: 0.98, alpha: 0.95)).cgColor
        bezel.shadowColor = NSColor.black.cgColor
        bezel.shadowOpacity = night ? 0 : 0.10
        bezel.shadowRadius = 18
        bezel.shadowOffset = CGSize(width: 0, height: -4)
        face.fillColor = (night ? NSColor(white: 1, alpha: 0.05) : NSColor(srgbRed: 0.945, green: 0.925, blue: 0.88, alpha: 1)).cgColor
        minors.strokeColor = ink.withAlphaComponent(0.28).cgColor
        majors.strokeColor = ink.withAlphaComponent(0.55).cgColor
        coral.strokeColor = (state.tone == .rest ? Palette.rest : Palette.warm).cgColor
        teal.strokeColor = calm.cgColor
        rim.strokeColor = Palette.arrive.cgColor
        dots.fillColor = Palette.arrive.cgColor
        needle.strokeColor = ink.withAlphaComponent(0.8).cgColor
        hub.fillColor = (night ? NSColor(srgbRed: 0.09, green: 0.10, blue: 0.13, alpha: 1) : NSColor(srgbRed: 1, green: 0.99, blue: 0.975, alpha: 1)).cgColor
        disc.fillColor = hub.fillColor
        disc.strokeColor = calm.withAlphaComponent(1).cgColor
        hull.fillColor = NSColor(srgbRed: 0.45, green: 0.29, blue: 0.17, alpha: 1).cgColor
        sail.fillColor = Palette.warm.withAlphaComponent(1).cgColor
        CATransaction.commit()
        paintNumerals()
        paintTime()
    }

    private func paintNumerals() {
        for (i, n) in numerals.enumerated() { n.string = Typography.string("\(i * 5)", .numeral, size: numeralSize, color: numeralColor) }
    }

    /// The countdown in the hub: as large as fits it.
    private func paintTime() {
        guard rHub > 0 else { return }
        let fs = (rHub * 1.62 / (CGFloat(max(timeText.count, 4)) * FocusLayout.glyphWidth)).rounded(.down)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        time.string = Typography.string(timeText, .hero, size: fs, color: ink)
        time.frame = CGRect(x: centre.x - rHub, y: (centre.y - fs * 0.62).rounded(), width: 2 * rHub, height: (fs * 1.25).rounded())
        CATransaction.commit()
    }

    // MARK: input

    private func minutes(at e: NSEvent) -> Double? {
        let p = convert(e.locationInWindow, from: nil)
        let dx = Double(p.x - centre.x), dy = Double(p.y - centre.y)
        return hypot(dx, dy) > Double(rHub) ? Dial.minutes(dx: dx, dy: dy) : nil   // the hub is not a direction
    }

    /// The dial takes clicks inside its bezel; outside it they reach FocusView (a background click exits).
    override func hitTest(_ p: NSPoint) -> NSView? {
        let q = convert(p, from: superview)
        return !isHidden && hypot(q.x - centre.x, q.y - centre.y) <= rOuter ? self : nil
    }

    override func mouseDown(with e: NSEvent) {
        guard state.settable, let m = minutes(at: e) else { return }
        dragMinutes = Dial.snap(m)   // a click jumps there
        onSet?(dragMinutes)
    }

    override func mouseDragged(with e: NSEvent) {
        guard state.settable, let raw = minutes(at: e) else { return }
        let m = Dial.drag(from: dragMinutes, to: raw)
        if m != dragMinutes { dragMinutes = m; onSet?(m) }
    }

    override func mouseUp(with e: NSEvent) {}   // a click on the dial never exits focus mode

    // MARK: menu bar

    /// The menu-bar ring, drawn in colour (not a template): a faint track and the arc of `fill`
    /// clockwise from twelve.
    static func ringIcon(_ fill: Double, _ tone: Dial.Tone) -> NSImage {
        let color = tone == .rest ? Palette.rest : tone == .warm ? Palette.warm : Palette.calm
        let img = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { r in
            let c = NSPoint(x: r.midX, y: r.midY), radius: CGFloat = 6
            let track = NSBezierPath(ovalIn: NSRect(x: c.x - radius, y: c.y - radius, width: 2 * radius, height: 2 * radius))
            track.lineWidth = 2.2
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()   // resolved for the menu bar's appearance when drawn
            track.stroke()
            guard fill > 0 else { return true }
            let arc = NSBezierPath()
            arc.appendArc(withCenter: c, radius: radius, startAngle: 90, endAngle: 90 - 360 * CGFloat(min(fill, 1)), clockwise: true)
            arc.lineWidth = 2.2
            arc.lineCapStyle = .round
            color.withAlphaComponent(1).setStroke()
            arc.stroke()
            return true
        }
        img.accessibilityDescription = "Edge Odyssey"
        return img
    }

    // MARK: accessibility: an adjustable slider

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .slider }
    override func accessibilityLabel() -> String? { L.t("Time on the dial", "다이얼 시간", "ダイヤルの時間", "表盘时间") }
    override func accessibilityValue() -> Any? { timeText }
    override func accessibilityHelp() -> String? {
        L.t("Scroll, drag or use the arrow keys to set the time", "스크롤하거나 끌거나 화살표 키로 시간을 맞춰요",
            "スクロール、ドラッグ、矢印キーで時間を合わせます", "滚动、拖动或用方向键设定时间")
    }
    override func accessibilityPerformIncrement() -> Bool { onStep?(1); return true }
    override func accessibilityPerformDecrement() -> Bool { onStep?(-1); return true }
}
