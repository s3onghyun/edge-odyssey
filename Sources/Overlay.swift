import AppKit
import QuartzCore

enum AgentState: String { case idle, working, waiting, limit }
enum Style: String { case border, traveler }

/// Everything one screen needs to draw, computed by the app from its model.
struct Scene {
    var visible = false
    var phase: Phase = .idle
    var elapsed: TimeInterval = 0
    var duration: TimeInterval = 1
    var paused = false
    var agent: AgentState = .idle
    /// Agent-only lap (no timer running): elapsed seconds into the lap, and lap length.
    var lapElapsed: TimeInterval = 0
    var lapDuration: TimeInterval = 720
    var style: Style = .traveler
    var thickness: CGFloat = 3
    var hostsTraveler = false
    var sprite: SpriteSheet?
    /// Per-lap variety: which climb (right edge) and which hang (top edge) this lap uses.
    var climbAnim = "climb"
    var ceilingAnim = "cling"
    var physical = false            // physical pace: per-edge speeds; even pace: position = elapsed share
    var calm = false                // stopwatch: the trail stays teal, nothing runs out
    var restIsLong = false          // long break: Calypso's island; short break: Ithaca
    var dozing = false              // a distracting app is in front: the Lotus-eaters
    var overrideAnim: String?       // a short encounter that replaces the pose (the ram)
    var devicePixelsPerSpritePixel = 3
}

/// The colours (values and contrast checks in Tones): the light or dark variant by the system
/// appearance, since the edge sits over whatever is on screen. Focus mode passes its own `dark`.
enum Palette {
    static var dark: Bool { NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }

    static func color(_ rgb: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
    static func color(_ p: Tones.Pair, dark d: Bool = Palette.dark, alpha: CGFloat = 1) -> NSColor { color(d ? p.dark : p.light, alpha: alpha) }

    static var calm: NSColor { color(Tones.teal) }                    // focus
    static var warm: NSColor { color(Tones.brass) }                   // the last fifth
    static var rest: NSColor { color(Tones.slate) }                   // a break
    static var working: NSColor { color(Tones.signal, alpha: 0.45) } // quiet: Claude Code works
    static var waiting: NSColor { color(Tones.signal) }               // Claude Code waits
    static var arrive: NSColor { color(Tones.brass) }                 // home at Ithaca
    static var limit: NSColor { color(Tones.rust, alpha: 0.9) }       // the storm near the usage limit
    static let track = NSColor(white: 0.5, alpha: 0.12)

    static func focus(at t: Double) -> NSColor {
        guard t > 0.8 else { return calm }
        return calm.blended(withFraction: CGFloat((t - 0.8) / 0.2), of: warm) ?? warm
    }
}

/// A transparent, click-through, borderless window covering one display.
/// All motion runs as Core Animation animations in the render server, so the app
/// itself only wakes on state changes and at the four corners of each lap.
final class Overlay {
    /// Debug override (`--fps N`): pin every continuous animation to N fps (0 = speed-based).
    static var maxFPS: Float = 0
    /// One clock for every repeating animation (sprite frames, sway, grip...). Re-adding an
    /// animation with this begin time continues its cycle instead of restarting it, so a
    /// state change never makes the traveler pop.
    static let epoch = CACurrentMediaTime()

    /// Frame rate for a motion whose fastest point moves `speed` points per second: just
    /// enough that each rendered step moves at most one device pixel, capped by the display.
    /// Slow travel stays cheap (about 8 fps at real speed); sways, gusts and demo speed get
    /// up to the full refresh rate.
    private func rate(_ speed: Double) -> Float {
        if Self.maxFPS > 0 { return Self.maxFPS }
        let fps = (speed * Double(screen.backingScaleFactor)).rounded(.up)
        return Float(min(max(fps, 8), Double(max(screen.maximumFramesPerSecond, 60))))
    }

    private func tune<T: CAAnimation>(_ a: T, _ fps: Float) -> T {
        if #available(macOS 12.0, *) {
            a.preferredFrameRateRange = CAFrameRateRange(minimum: min(fps, 8), maximum: fps, preferred: fps)
        }
        return a
    }

    /// Makes a repeating animation continue its cycle from a fixed start (default: the shared
    /// `epoch`) instead of restarting it whenever it is re-added.
    private func phaseLocked<T: CAAnimation>(_ a: T, on layer: CALayer, since start: CFTimeInterval = Overlay.epoch) -> T {
        a.beginTime = layer.convertTime(start, from: nil)
        return a
    }

    private(set) var screen: NSScreen
    let window: NSWindow
    private let root = CALayer()
    private let track = CAShapeLayer()
    private let fill = CAShapeLayer()
    private let agentRing = CAShapeLayer()
    private let mover = CALayer()   // gross position along the edge
    private let poser = CALayer()   // rotation onto the edge + sway / grip micro-motion
    private let spriteLayer = CALayer()
    private var edgeTimer: Timer?
    private var lastEdge: Int?
    private var lastAgent: AgentState = .idle
    private var shown = false
    var sceneProvider: (() -> Scene)?
    var log: ((String) -> Void)?
    /// Set in focus mode: the track and traveler are drawn on this view's stage, inside an
    /// ordinary window the user opened, instead of on a click-through window over a display.
    let focusView: FocusView?
    /// What the route is laid out on: the whole display, or the focus window's stage.
    var stageSize: CGSize { root.bounds.size }

    init(screen: NSScreen, excludeFromCapture: Bool) {
        focusView = nil
        self.screen = screen
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .statusBar
        // No .fullScreenAuxiliary: the overlay never appears in another app's full-screen space.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.sharingType = excludeFromCapture ? .none : .readOnly

        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.layer = root
        view.wantsLayer = true
        window.contentView = view
        root.frame = view.bounds
        setUpLayers()
    }

    /// The focus-mode window on `screen` (or at `frame`, a debug/demo flag), resizable and
    /// ready for full screen. It takes clicks and keys; FocusView lays out the stage.
    init(focusOn screen: NSScreen, excludeFromCapture: Bool, frame: CGRect?) {
        self.screen = screen
        let v = screen.visibleFrame
        placement = frame ?? v.insetBy(dx: v.width * 0.15, dy: v.height * 0.15)
        window = NSWindow(contentRect: placement,
                          styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = L.t("Focus mode", "집중 모드", "集中モード", "专注模式")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]
        window.minSize = CGSize(width: 480, height: 480)
        window.sharingType = excludeFromCapture ? .none : .readOnly
        let view = FocusView(stage: root)
        focusView = view
        window.contentView = view
        place()
        setUpLayers()
    }

    /// Where the focus window belongs. Setting the content view and ordering the window front
    /// both pull a new window onto the main display, so the frame is applied again after them.
    private var placement = CGRect.zero
    func place() { window.setFrame(placement, display: true) }

    private func setUpLayers() {
        root.opacity = 0
        for l in [track, fill, agentRing] {
            l.fillColor = nil
            l.lineCap = .butt
            l.lineJoin = .miter
            root.addSublayer(l)
        }
        agentRing.shadowOffset = .zero
        agentRing.shadowRadius = 7
        root.addSublayer(mover)
        mover.addSublayer(poser)
        poser.addSublayer(spriteLayer)
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.minificationFilter = .nearest
        spriteLayer.contentsGravity = .resize
    }

    func close() {
        edgeTimer?.invalidate()
        focusView == nil ? window.orderOut(nil) : window.close()
    }

    /// The same display came back with new parameters (resolution, arrangement, a monitor
    /// connected or disconnected elsewhere): resize in place, so nothing fades or restarts.
    func move(to screen: NSScreen) {
        self.screen = screen
        guard focusView == nil else { return }   // an ordinary window: macOS places it
        window.setFrame(screen.frame, display: false)
        window.contentView?.frame = CGRect(origin: .zero, size: screen.frame.size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = CGRect(origin: .zero, size: screen.frame.size)
        CATransaction.commit()
    }

    /// Arrival: a brass wave runs twice round the edge from the harbor (bottom-left, where
    /// the route starts and ends), then ripples and a few sparkles there. One-shot Core Animation
    /// on throwaway layers: nothing keeps running, and a hidden overlay skips it.
    func celebrate() {
        guard shown, let path = track.path else { return }
        let size = root.bounds.size, len = 2 * (size.width + size.height), gold = Palette.arrive.cgColor
        let k = min(max(min(size.width, size.height) / 800, 1), 2)   // focus mode's stage can be larger
        let now = root.convertTime(CACurrentMediaTime(), from: nil)
        let wave = CAShapeLayer()
        wave.frame = root.bounds
        wave.path = path
        wave.fillColor = nil
        wave.lineWidth = max(track.lineWidth, 3) * 2 + 2
        wave.lineCap = .round
        wave.strokeColor = gold
        wave.shadowColor = gold
        wave.shadowOffset = .zero
        wave.shadowRadius = 18
        wave.shadowOpacity = 1
        let crest = len * 0.28
        wave.lineDashPattern = [NSNumber(value: Double(crest)), NSNumber(value: Double(len - crest))]
        wave.opacity = 0
        root.insertSublayer(wave, below: mover)
        let run = CABasicAnimation(keyPath: "lineDashPhase")   // a falling phase carries the dash forward
        run.fromValue = crest
        run.toValue = crest - 2 * len                           // two laps, ending at the harbor
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.06, 0.82, 1]
        let wavesGo = CAAnimationGroup()
        wavesGo.animations = [run, fade]
        wavesGo.duration = 2.8
        wavesGo.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        wave.add(tune(wavesGo, rate(Double(2 * len) / 2.8)), forKey: "arrive")

        let harbor = CALayer()
        harbor.frame = root.bounds
        root.insertSublayer(harbor, below: mover)
        let corner = CGPoint(x: track.lineWidth / 2, y: track.lineWidth / 2)
        func once(_ l: CALayer, after delay: CFTimeInterval, _ a: CAAnimation) {
            a.beginTime = now + delay
            l.add(tune(a, 30), forKey: "arrive")
        }
        for i in 0..<3 {   // ripples spreading from the harbor corner
            let r = 120 * k
            let ring = CAShapeLayer()
            ring.bounds = CGRect(x: 0, y: 0, width: 2 * r, height: 2 * r)
            ring.position = corner
            ring.path = CGPath(ellipseIn: ring.bounds.insetBy(dx: 2, dy: 2), transform: nil)
            ring.fillColor = nil
            ring.strokeColor = gold
            ring.lineWidth = 2.5
            ring.opacity = 0
            harbor.addSublayer(ring)
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.12
            scale.toValue = 1
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 0.95
            fadeOut.toValue = 0
            let g = CAAnimationGroup()
            g.animations = [scale, fadeOut]
            g.duration = 1.6
            g.timingFunction = CAMediaTimingFunction(name: .easeOut)
            once(ring, after: 0.3 + 0.35 * Double(i), g)
        }
        for (i, at) in [(46, 92), (104, 40), (88, 128), (150, 82)].enumerated() {   // sparkles round the harbor
            let star = CAShapeLayer()
            let r = 7 * k
            star.bounds = CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)
            star.position = CGPoint(x: corner.x + CGFloat(at.0) * k, y: corner.y + CGFloat(at.1) * k)
            let p = CGMutablePath()   // a four-point star
            for j in 0..<8 {
                let a = CGFloat(j) * .pi / 4, d = j % 2 == 0 ? r : r * 0.32
                let pt = CGPoint(x: sin(a) * d, y: cos(a) * d)
                j == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
            star.path = p
            star.fillColor = gold
            star.shadowColor = gold
            star.shadowOffset = .zero
            star.shadowRadius = 4
            star.shadowOpacity = 1
            star.opacity = 0
            harbor.addSublayer(star)
            let twinkle = CAKeyframeAnimation(keyPath: "opacity")
            twinkle.values = [0, 1, 0]
            let grow = CAKeyframeAnimation(keyPath: "transform.scale")
            grow.values = [0.3, 1.2, 0.6]
            let g = CAAnimationGroup()
            g.animations = [twinkle, grow]
            g.duration = 0.9
            once(star, after: 0.55 + 0.22 * Double(i), g)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            wave.removeFromSuperlayer()
            harbor.removeFromSuperlayer()
        }
    }

    // MARK: - apply

    func apply(_ s: Scene) {
        edgeTimer?.invalidate()
        edgeTimer = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        setVisible(s.visible)
        guard s.visible else { lastEdge = nil; return }

        let size = root.bounds.size
        let weights = Journey.weights(physical: s.style == .traveler && s.physical)
        let borderInset = s.thickness / 2
        let borderJourney = Journey(size: size, inset: borderInset, weights: weights)
        let path = Journey.borderPath(size: size, inset: borderInset)
        for l in [track, fill, agentRing] {
            l.frame = root.bounds
            l.path = path
            l.lineWidth = s.thickness
        }

        applyTimerBorder(s, borderJourney)
        applyAgentRing(s)
        applyTraveler(s, size: size, weights: weights)
        lastAgent = s.agent
    }

    private func setVisible(_ v: Bool) {
        guard v != shown else { return }
        shown = v
        if v, focusView == nil { window.orderFrontRegardless() }
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = root.presentation()?.opacity ?? root.opacity
        a.toValue = v ? 1 : 0
        a.duration = 0.6
        root.opacity = v ? 1 : 0
        root.add(a, forKey: "fade")
        if !v {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                guard let self, !self.shown else { return }
                if self.focusView == nil { self.window.orderOut(nil) }
                // Hidden: leave nothing animating, so the render server has no work for us.
                for l in [self.fill, self.agentRing, self.mover, self.poser, self.spriteLayer] { l.removeAllAnimations() }
                self.clearEpisodes()
            }
        }
    }

    private func applyTimerBorder(_ s: Scene, _ j: Journey) {
        fill.removeAllAnimations()
        guard s.phase != .idle else {
            track.isHidden = true
            fill.isHidden = true
            return
        }
        track.isHidden = false
        fill.isHidden = false
        track.strokeColor = Palette.track.cgColor
        if s.phase == .arrived {   // home: the whole trail in brass, still, until the user moves on
            fill.strokeColor = Palette.arrive.cgColor
            fill.strokeEnd = 1
            return
        }
        let t0 = min(max(s.elapsed / s.duration, 0), 1)
        let remaining = max(s.duration - s.elapsed, 0.01)

        if s.phase == .rest {   // break: the trail drains away in lavender
            fill.strokeColor = Palette.rest.cgColor
            fill.strokeEnd = s.paused ? CGFloat(1 - t0) : 0
            if !s.paused {
                let a = CABasicAnimation(keyPath: "strokeEnd")
                a.fromValue = 1 - t0
                a.toValue = 0
                a.duration = remaining
                let len = Double(2 * (root.bounds.width + root.bounds.height))
                fill.add(tune(a, rate(len / remaining)), forKey: "drain")
            }
            return
        }

        fill.strokeColor = Palette.focus(at: s.calm ? 0 : t0).cgColor
        fill.strokeEnd = CGFloat(j.lengthFraction(t0))
        guard !s.paused else { return }
        // Trail end follows the same per-edge time mapping as the traveler.
        let physical = s.style == .traveler && s.physical
        let zip = s.ceilingAnim == "zip"
        let route = routeSamples(j, from: t0, zip: zip, profiled: physical)
        let a = CAKeyframeAnimation(keyPath: "strokeEnd")
        a.keyTimes = route.map { NSNumber(value: $0.time) }
        a.values = route.map { j.lengthMarks[$0.edge] + (j.lengthMarks[$0.edge + 1] - j.lengthMarks[$0.edge]) * $0.u }
        a.calculationMode = .linear
        a.duration = remaining
        a.fillMode = .forwards
        a.isRemovedOnCompletion = false
        fill.strokeEnd = 1
        // Rate from the fastest the trail end moves on the current edge (it is rebuilt at corners).
        let k0 = route[0].edge
        let edgeSeconds = max((j.timeMarks[k0 + 1] - j.timeMarks[k0]) * s.duration, 0.01)
        let tip = Double(j.edges[k0].length) / edgeSeconds * (physical ? profilePeak(j.edges[k0].kind, zip: zip) : 1)
        fill.add(tune(a, rate(tip)), forKey: "progress")
        guard !s.calm else { return }

        let samples = 8
        let c = CAKeyframeAnimation(keyPath: "strokeColor")
        c.values = (0...samples).map { Palette.focus(at: t0 + (1 - t0) * Double($0) / Double(samples)).cgColor }
        c.duration = remaining
        c.fillMode = .forwards
        c.isRemovedOnCompletion = false
        fill.strokeColor = Palette.warm.cgColor
        fill.add(tune(c, 4), forKey: "color")   // a slow colour drift needs only a few steps a second
    }

    private func applyAgentRing(_ s: Scene) {
        let color: NSColor?
        switch s.agent {
        case .idle: color = nil
        case .working: color = s.phase == .idle ? Palette.working : nil   // stay quiet during a focus timer
        case .waiting: color = Palette.waiting
        case .limit: color = Palette.limit
        }
        guard let color else {
            agentRing.isHidden = true
            agentRing.removeAllAnimations()
            return
        }
        agentRing.isHidden = false
        agentRing.strokeColor = color.cgColor
        agentRing.shadowColor = color.cgColor
        agentRing.lineWidth = s.thickness + (s.agent == .waiting ? 1 : 0)
        agentRing.shadowOpacity = s.agent == .waiting ? 0.9 : 0
        agentRing.opacity = s.agent == .waiting ? 0.8 : 1
        if s.agent == .waiting && lastAgent != .waiting {
            // One soft swell, then steady. Never blinks.
            let p = CAKeyframeAnimation(keyPath: "opacity")
            p.values = [0, 1, 0.8]
            p.keyTimes = [0, 0.45, 1]
            p.duration = 1.8
            agentRing.add(p, forKey: "pulse")
        }
    }

    // MARK: - traveler

    private func applyTraveler(_ s: Scene, size: CGSize, weights: [EdgeKind: Double]) {
        // Only the animations rebuilt below; a turn, a landing squash or an episode gust/spin
        // that is still playing finishes untouched.
        mover.removeAnimation(forKey: "go")
        for key in ["grip", "gust", "rattle"] { poser.removeAnimation(forKey: key) }
        spriteLayer.removeAnimation(forKey: "frames")
        let moving: Bool
        let t: Double
        let total: TimeInterval
        switch s.phase {
        case .focus:
            t = s.elapsed / s.duration; total = s.duration; moving = !s.paused && t < 0.999
        case .rest, .arrived:   // home again: at the start corner; in focus mode, mid-floor under the clock
            t = focusView == nil ? 0 : Double(size.width) / Double(4 * (size.width + size.height))
            total = s.duration; moving = false
        case .idle:
            t = s.lapElapsed / s.lapDuration; total = s.lapDuration
            moving = s.agent == .working
        }
        let travelerVisible = s.style == .traveler && s.hostsTraveler && s.sprite != nil
            && (s.phase != .idle || s.agent != .idle)
        mover.isHidden = !travelerVisible
        guard travelerVisible, let sprite = s.sprite else { lastEdge = nil; return }

        let pt = sprite.unitPoints(backing: screen.backingScaleFactor)
        spriteLayer.magnificationFilter = sprite.pixelated ? .nearest : .linear
        spriteLayer.minificationFilter = sprite.pixelated ? .nearest : .trilinear
        spriteLayer.contentsScale = screen.backingScaleFactor
        let sw = CGFloat(sprite.width) * pt, sh = CGFloat(sprite.height) * pt
        spriteLayer.bounds = CGRect(x: 0, y: 0, width: sw, height: sh)
        spriteLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        spriteLayer.position = .zero
        spriteLayer.removeAnimation(forKey: "sway")
        spriteLayer.transform = CATransform3DIdentity

        let j = Journey(size: size, inset: sh / 2, weights: weights)
        let (k, local) = j.locate(t)
        let edge = j.edges[k]
        // Even pace keeps every edge linear: gravity and zipline easing would bend time again.
        mover.position = edge.point(s.physical ? edgeProfile(edge.kind, zip: s.ceilingAnim == "zip")(local) : local)
        poser.setAffineTransform(CGAffineTransform(rotationAngle: edge.angle))

        // A character with no edge art sails every edge like the floor (the turn below rounds the corner).
        let sails = sailsEveryEdge(sprite.anims.keys)
        let kind = sails ? .floor : edge.kind
        // Pick frames: waiting agent -> wave; break -> sleep; paused/limit -> idle; else per edge.
        func pick(_ names: String...) -> String { names.first { sprite.anims[$0] != nil } ?? "walk" }
        let animName: String
        if s.agent == .waiting { animName = pick("sirens", "wave") }          // the agent is calling you
        else if s.phase == .arrived { animName = pick("ithaca", "idle") }
        else if s.phase == .rest { animName = s.restIsLong ? pick("rest", "sleep") : pick("ithaca", "rest", "sleep") }
        else if s.agent == .limit && !moving { animName = pick("storm", "idle") } // near the usage limit
        else if !moving { animName = pick("idle") }
        else if let o = s.overrideAnim, edge.kind == .floor, sprite.anims[o] != nil { animName = o }
        else if s.dozing { animName = pick("doze", "walk") }
        else {
            switch kind {
            case .floor: animName = "walk"
            case .ceiling: animName = pick(s.ceilingAnim, "cling", "walk")
            case .climb: animName = pick(s.climbAnim, "climb", "walk")
            case .slide: animName = "slide"
            }
        }
        playFrames(sprite.anims[animName] ?? sprite.anims["walk"]!, slow: kind == .ceiling && moving ? 1.6 : 1)

        // Corner transition: a quick turn (and a squash when landing from the slide).
        if let prev = lastEdge, prev != k, moving || s.phase == .rest {
            let prevAngle = j.edges[prev].angle
            var target = edge.angle
            while target < prevAngle { target += 2 * .pi }
            let turn = CABasicAnimation(keyPath: "transform.rotation.z")
            turn.fromValue = prevAngle
            turn.toValue = target
            turn.duration = 0.35
            turn.timingFunction = CAMediaTimingFunction(name: .easeOut)
            poser.add(turn, forKey: "turn")
            if j.edges[prev].kind == .slide && !sails {
                let squash = CAKeyframeAnimation(keyPath: "transform.scale.y")
                squash.values = [0.6, 1.15, 0.95, 1]
                squash.keyTimes = [0, 0.35, 0.7, 1]
                squash.duration = 0.45
                spriteLayer.add(squash, forKey: "land")
            }
        }
        lastEdge = k
        let o = screen.frame.origin
        log?(String(format: "traveler edge=%d anim=%@ moving=%d from=%.0f,%.0f to=%.0f,%.0f dur=%.2f screenOrigin=%.0f,%.0f",
                    k, animName, moving ? 1 : 0, mover.position.x, mover.position.y, edge.end.x, edge.end.y,
                    moving ? (j.timeMarks[k + 1] - t) * total : 0, o.x, o.y))
        guard moving else { return }

        // Gross motion over the rest of the route, timed exactly by the journey mapping. It runs
        // through the corners on its own; the corner timer below only changes the pose.
        let zip = s.ceilingAnim == "zip"
        let edgeEndT = j.timeMarks[k + 1]
        let edgeRemaining = max((edgeEndT - t) * total, 0.01)
        let route = routeSamples(j, from: t, zip: zip, profiled: s.physical)
        let go = CAKeyframeAnimation(keyPath: "position")
        go.keyTimes = route.map { NSNumber(value: $0.time) }
        go.values = route.map { NSValue(point: j.edges[$0.edge].point($0.u)) }
        go.duration = max((1 - t) * total, 0.01)
        go.fillMode = .forwards
        go.isRemovedOnCompletion = false
        go.calculationMode = .linear
        mover.position = j.edges.last!.end
        let speed = Double(edge.length) / max((j.timeMarks[k + 1] - j.timeMarks[k]) * total, 0.01)
        mover.add(tune(go, rate(speed * (s.physical ? profilePeak(edge.kind, zip: zip) : 1))), forKey: "go")

        // Micro-motion cycles count from the moment he reached this edge: zero offset at the
        // corner, and the same phase however often the scene is re-applied.
        let edgeStart = CACurrentMediaTime() - (t - j.timeMarks[k]) * total
        addMicroMotion(kind, speed: speed, zip: zip, spriteHeight: sh, since: edgeStart)

        edgeTimer = Timer.scheduledTimer(withTimeInterval: edgeRemaining + 0.02, repeats: false) { [weak self] _ in
            guard let self, let scene = self.sceneProvider?() else { return }
            self.apply(scene)
        }
        edgeTimer?.tolerance = 0.05
    }

    // MARK: - episodes

    private var props: [CALayer] = []

    func clearEpisodes() {
        props.forEach { $0.removeFromSuperlayer() }
        props.removeAll()
    }

    /// Plays a short encounter around the traveler. Purely decorative: no input, no effect
    /// on where the traveler is at any time (gusts and spins net to zero displacement).
    func play(_ ep: Episode, sprite: SpriteSheet, seconds: TimeInterval) {
        guard shown, !mover.isHidden else { return }
        let pt = sprite.unitPoints(backing: screen.backingScaleFactor)
        let size = CGSize(width: CGFloat(sprite.width) * pt, height: CGFloat(sprite.height) * pt)
        let here = mover.presentation()?.position ?? mover.position
        let angle = (poser.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0

        func prop(_ anim: String, in parent: CALayer, at p: CGPoint, rotation: CGFloat = 0, once: Bool, life: TimeInterval) {
            guard let a = sprite.anims[anim] else { return }
            let l = CALayer()
            l.bounds = CGRect(origin: .zero, size: size)
            l.position = p
            l.contentsGravity = .resize
            l.contentsScale = screen.backingScaleFactor
            l.magnificationFilter = sprite.pixelated ? .nearest : .linear
            l.contents = a.frames.last
            l.setAffineTransform(CGAffineTransform(rotationAngle: rotation))
            let flip = flipTiming(fps: a.fps)
            let f = CAKeyframeAnimation(keyPath: "contents")
            f.values = a.frames
            f.calculationMode = .discrete
            f.duration = flip.frame * Double(a.frames.count)
            f.repeatCount = once ? 1 : .infinity
            l.add(tune(f, flip.rate), forKey: "frames")
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, NSNumber(value: min(0.4 / life, 0.2)), NSNumber(value: 1 - min(0.5 / life, 0.2)), 1]
            fade.duration = life
            l.opacity = 0
            l.add(tune(fade, 30), forKey: "fade")   // can last minutes (the owl): keep it cheap
            parent.addSublayer(l)
            props.append(l)
            DispatchQueue.main.asyncAfter(deadline: .now() + life) { [weak self, weak l] in
                l?.removeFromSuperlayer()
                self?.props.removeAll { $0 === l }
            }
        }

        switch ep {
        case .cyclops:   // stationary in the world, ahead of the boat on the floor
            let ahead = CGPoint(x: here.x + cos(angle) * 110 * sprite.scale, y: here.y + sin(angle) * 110 * sprite.scale)
            prop("ep-cyclops", in: root, at: ahead, rotation: angle, once: true, life: max(seconds, 3))
        case .circe:     // piglets trot behind him
            prop("ep-piglets", in: poser, at: CGPoint(x: -size.width * 0.95, y: 0), once: false, life: seconds)
        case .aeolus:    // the bag bursts behind him and the gust shoves him along, then eases back
            prop("ep-bag", in: poser, at: CGPoint(x: -size.width * 0.7, y: 0), once: true, life: 2.2)
            let d = CGPoint(x: cos(angle), y: sin(angle))
            let g = CAKeyframeAnimation(keyPath: "position")
            g.isAdditive = true
            g.values = [0, 70, 55, 25, 0].map { NSValue(point: CGPoint(x: d.x * $0 * sprite.scale, y: d.y * $0 * sprite.scale)) }
            g.keyTimes = [0, 0.12, 0.35, 0.7, 1]
            g.duration = 4
            // On the poser, not the mover: the mover's route animation is rebuilt on every
            // re-apply and, added later, would override an additive gust on the same layer.
            poser.add(tune(g, rate(70 * sprite.scale / (0.12 * 4))), forKey: "gust-\(Date().timeIntervalSince1970)")
        case .whirlpool: // Charybdis spins him round the corner
            prop("ep-whirl", in: poser, at: .zero, once: false, life: 1.8)
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.isAdditive = true
            spin.fromValue = 0
            spin.toValue = 4 * Double.pi
            spin.duration = 1.6
            spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            spriteLayer.add(spin, forKey: "spin")
        case .owl:       // Athena's owl flies just ahead until the end of the session
            prop("ep-owl", in: poser, at: CGPoint(x: size.width * 0.9, y: size.height * 0.45), once: false, life: seconds)
        default:
            break
        }
    }

    private func playFrames(_ a: SpriteAnim, slow: Double) {
        spriteLayer.contents = a.frames[0]
        guard a.frames.count > 1 else { return }
        let flip = flipTiming(fps: a.fps / slow)
        let f = CAKeyframeAnimation(keyPath: "contents")
        f.values = a.frames
        f.calculationMode = .discrete
        f.duration = flip.frame * Double(a.frames.count)
        f.repeatCount = .infinity
        spriteLayer.add(tune(phaseLocked(f, on: spriteLayer), flip.rate), forKey: "frames")
    }

    /// Edge-specific motion layered on top of the exact gross motion. Each cycle nets to
    /// zero displacement, so it never changes where the traveler is at a given time.
    private func addMicroMotion(_ kind: EdgeKind, speed: Double, zip: Bool, spriteHeight sh: CGFloat, since start: CFTimeInterval) {
        spriteLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        switch kind {
        case .climb:
            // Grip-and-pull steps of ~8 pt, with a small slip back every fourth step.
            let step = 8.0
            let p = min(max(step / max(speed, 0.001), 0.25), 5)
            let actual: [(Double, Double)] = [(0, 0), (0.55, 0), (1, 1), (1.55, 1), (2, 2), (2.55, 2),
                                             (3, 3.5), (3.15, 2.85), (3.55, 2.85), (4, 4)]
            let a = CAKeyframeAnimation(keyPath: "position.y")
            a.isAdditive = true
            a.keyTimes = actual.map { NSNumber(value: $0.0 / 4) }
            a.values = actual.map { ($0.1 - $0.0) * step }
            a.duration = 4 * p
            a.repeatCount = .infinity
            // fastest moment: the slip back (0.65 step in 0.15 of a step period) on top of travel
            poser.add(tune(phaseLocked(a, on: poser, since: start), rate(0.65 * step / (0.15 * p) + speed)), forKey: "grip")
        case .ceiling:
            // Hanging from the top edge: swing like a pendulum about the hands (the edge side).
            spriteLayer.anchorPoint = CGPoint(x: 0.5, y: 0)
            spriteLayer.position = CGPoint(x: 0, y: -sh / 2)
            let sway = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            sway.isAdditive = true
            sway.values = zip ? [0, 0.22, 0, -0.16, 0] : [0, 0.1, 0, -0.08, 0]
            sway.duration = zip ? 1.6 : 2.6
            sway.repeatCount = .infinity
            sway.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
            // feet swing on a radius of one sprite height; ease-in-out peaks at ~1.6x the average
            let peak = 1.6 * (zip ? 0.22 : 0.1) * Double(sh) / (sway.duration / 4)
            spriteLayer.add(tune(phaseLocked(sway, on: spriteLayer, since: start), rate(peak)), forKey: "sway")
            if !zip {
                let gust = CAKeyframeAnimation(keyPath: "position.x")
                gust.isAdditive = true
                gust.values = [0, -7, 0, 5, 0]
                gust.duration = 3.4
                gust.repeatCount = .infinity
                poser.add(tune(phaseLocked(gust, on: poser, since: start), rate(7 / (3.4 / 4) + speed)), forKey: "gust")
            }
        case .slide:
            let jitter = CAKeyframeAnimation(keyPath: "position.x")
            jitter.isAdditive = true
            jitter.values = [0, 0.8, 0, -0.8, 0]
            jitter.duration = 0.3
            jitter.repeatCount = .infinity
            poser.add(tune(phaseLocked(jitter, on: poser, since: start), rate(0.8 / (0.3 / 4))), forKey: "rattle")
        case .floor:
            break
        }
    }
}
