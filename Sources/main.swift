import AppKit
import ServiceManagement
import UserNotifications

// Edge Odyssey - a thin, click-through screen-edge timer and agent signal.

struct Options {
    var speed = 1.0                 // demo: 60 makes a 25-minute focus last 25 seconds
    var focusMinutes = 25.0
    var restMinutes = 5.0
    var stateDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".edge-odyssey")
    var style = Style.traveler
    var character = "odysseus-vector"
    var thickness: CGFloat = 3
    var excludeFromCapture = true
    var hideWhenCaptured = true
    var onlyLast5 = false
    var autostart = false
    /// Where to show: "main", "all" (border everywhere, traveler where you work),
    /// "follow" (only the display with your active window), or a display index / name.
    var display = "main"
    var demoBackdrop: [Int] = []
    var assets: URL?
    var verbose = false
    var exportSprites: URL?
    var ctl: String?
    var episodes: [Episode]?        // demo: force these encounters every lap
    var climbVariant: String?       // demo: force a climb variant (climb, climb-crag, climb-olive, climb-mast)
    var ceilingVariant: String?     // demo: force zip or cling
    var lotusEnabled = true         // doze when a game, video or social app is frontmost
    var agentEnabled = true         // show Claude Code signals
    var showSeconds = true          // menu bar counts down 12:50; off shows whole minutes (13m)
    var longEvery = 4               // a long break after every n-th focus
    var notifyAtEnd = true          // macOS notification when a focus or a break ends
    var sound = "off"               // Chime.choices: harp, glass or off, at the end of a focus and a break
    var soundVolume = "low"         // Chime.volumes: low or medium
    var autoNextFocus = false       // start the next focus by itself when a break ends
    var physicalPace = false        // traveler pace: even (position = elapsed share) or physical per-edge speeds

    /// Settings the menu changes are kept in UserDefaults; command-line flags override them
    /// for one run without being saved.
    static let saved: [String: Any] = ["style": "traveler", "display": "main", "thickness": 3.0, "onlyLast5": false,
                                       "agentEnabled": true, "lotusEnabled": true, "hideWhenCaptured": true,
                                       "showSeconds": true, "focusMinutes": 25.0, "restMinutes": 5.0, "longEvery": 4,
                                       "notifyAtEnd": true, "soundVolume": "low", "autoNextFocus": false, "pace": "even"]   // "sound" unregistered: see init

    init(_ args: [String], defaults d: UserDefaults = .standard) {
        d.register(defaults: Self.saved)
        style = Style(rawValue: d.string(forKey: "style") ?? "") ?? .traveler
        display = d.string(forKey: "display") ?? "main"
        thickness = CGFloat(min(max(d.double(forKey: "thickness"), 2), 4))
        onlyLast5 = d.bool(forKey: "onlyLast5")
        agentEnabled = d.bool(forKey: "agentEnabled")
        lotusEnabled = d.bool(forKey: "lotusEnabled")
        hideWhenCaptured = d.bool(forKey: "hideWhenCaptured")
        showSeconds = d.bool(forKey: "showSeconds")
        focusMinutes = Durations.minutes(String(d.double(forKey: "focusMinutes")), in: Durations.focusRange) ?? 25
        restMinutes = Durations.minutes(String(d.double(forKey: "restMinutes")), in: Durations.breakRange) ?? 5
        longEvery = Durations.longEveryChoices.contains(d.integer(forKey: "longEvery")) ? d.integer(forKey: "longEvery") : 4
        notifyAtEnd = d.bool(forKey: "notifyAtEnd")
        sound = Chime.choice(d.string(forKey: "sound") ?? (d.bool(forKey: "soundAtEnd") ? "on" : nil))   // 0.1 kept an on/off toggle
        soundVolume = Chime.volume(d.string(forKey: "soundVolume"))
        autoNextFocus = d.bool(forKey: "autoNextFocus")
        physicalPace = d.string(forKey: "pace") == "physical"
        var it = args.dropFirst().makeIterator()
        while let a = it.next() {
            switch a {
            case "--speed": speed = Double(it.next() ?? "") ?? 1
            case "--focus": focusMinutes = Double(it.next() ?? "") ?? 25
            case "--rest": restMinutes = Double(it.next() ?? "") ?? 5
            case "--state-dir": stateDir = URL(fileURLWithPath: it.next() ?? "")
            case "--style": style = Style(rawValue: it.next() ?? "") ?? .traveler
            case "--char": character = it.next() ?? "odysseus-vector"
            case "--thickness": thickness = CGFloat(Double(it.next() ?? "") ?? 3)
            case "--capture-visible": excludeFromCapture = false
            case "--no-share-hide": hideWhenCaptured = false
            case "--last5": onlyLast5 = true
            case "--autostart": autostart = true
            case "--traveler-screen", "--display": display = it.next() ?? "main"
            case "--demo-backdrop": demoBackdrop = (it.next() ?? "").split(separator: ",").compactMap { Int($0) }
            case "--assets": assets = URL(fileURLWithPath: it.next() ?? "")
            case "--export-sprites": exportSprites = URL(fileURLWithPath: it.next() ?? "")
            case "--ctl": ctl = it.next()
            case "--no-lotus": lotusEnabled = false
            case "--climb": climbVariant = it.next()
            case "--ceiling": ceilingVariant = it.next()
            case "--pace": physicalPace = it.next() == "physical"
            case "--episodes": episodes = (it.next() ?? "").split(separator: ",").compactMap { Episode(rawValue: String($0)) }
            case "--fps": Overlay.maxFPS = Float(it.next() ?? "") ?? 0
            case "-v", "--verbose": verbose = true
            default: break
            }
        }
        if let env = ProcessInfo.processInfo.environment["EDGE_ODYSSEY_STATE_DIR"], !env.isEmpty {
            stateDir = URL(fileURLWithPath: env)
        }
    }
}

/// Launch at login through SMAppService (macOS 13+). Never registered unless the user asks.
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}

/// Scoped to the bundle id, so a test build (another id) never controls or quits your copy.
let ctlNotification = Notification.Name((Bundle.main.bundleIdentifier ?? "dev.edgeodyssey.app") + ".ctl")

final class MenuAction: NSMenuItem {
    private var handler: (() -> Void)?
    convenience init(_ title: String, key: String = "", checked: Bool = false, _ handler: @escaping () -> Void) {
        self.init(title: title, action: #selector(fire), keyEquivalent: key)
        self.handler = handler
        target = self
        state = checked ? .on : .off
    }
    @objc private func fire() { handler?() }
}

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var o: Options
    var sprites: [String: SpriteSheet] = [:]
    var overlays: [Overlay] = []
    var phase: Phase = .idle
    var phaseStart = Date()
    var pausedAt: Date?
    var pausedTotal: TimeInterval = 0
    var manualHidden = false
    var agentState: AgentState = .idle
    var lapStart = Date()
    var lapFrozenAt: Date?
    let detector = Detector()
    lazy var watcher = AgentWatcher(dir: o.stateDir)
    var statusItem: NSStatusItem!
    var phaseTimer: Timer?
    var last5Timer: Timer?
    var titleTimer: Timer?
    var titleSymbol: String?           // the symbol now in the menu bar
    weak var headerItem: NSMenuItem?   // the "Focus: 12:50 left" line, ticking while the menu is open
    var backdrops: [NSWindow] = []
    // voyage state
    var focusCount = 0
    var episodeTimers: [Timer] = []
    lazy var logbook = Logbook(url: o.stateDir.appendingPathComponent("logbook.json"))
    var lotus = false
    var overrideAnim: String?
    var restIsLong = false

    init(_ o: Options) { self.o = o }

    func log(_ s: String) {
        guard o.verbose else { return }
        FileHandle.standardError.write("[\(String(format: "%.3f", Date().timeIntervalSince1970))] \(s)\n".data(using: .utf8)!)
    }

    /// Set when a phase starts, so a length changed in the menu applies from the next session.
    var phaseDuration: TimeInterval = 25 * 60
    var breakMinutes: Double { restIsLong ? Durations.longBreakMinutes(rest: o.restMinutes) : o.restMinutes }
    var elapsed: TimeInterval { (pausedAt ?? Date()).timeIntervalSince(phaseStart) - pausedTotal }
    var remaining: TimeInterval { max(phaseDuration - elapsed, 0) }

    // MARK: lifecycle

    func applicationDidFinishLaunching(_ n: Notification) {
        loadSprites()
        buildStatusItem()
        for b in o.demoBackdrop { showBackdrop(on: b) }
        rebuildOverlays()
        detector.log = { [weak self] in self?.log($0) }
        detector.onChange = { [weak self] _ in self?.refresh() }
        detector.start()
        watcher.log = { [weak self] in self?.log($0) }
        watcher.onChange = { [weak self] s in
            guard let self else { return }
            // The agent lap clock only runs while the agent works, so the traveler resumes
            // from where it stopped to listen (waiting) or ride out the storm (limit).
            let now = Date()
            if self.agentState == .idle && s != .idle {   // a session appears: start the lap from home
                self.lapStart = now
                self.lapFrozenAt = s == .working ? nil : now
            }
            if self.agentState == .working && s != .working { self.lapFrozenAt = now }
            if s == .working {
                if self.agentState == .idle && self.lapFrozenAt == nil { self.lapStart = now }
                if let f = self.lapFrozenAt { self.lapStart += now.timeIntervalSince(f); self.lapFrozenAt = nil }
            }
            if s == .idle { self.lapFrozenAt = nil; self.lapStart = now }
            if s == .waiting { self.logbook.record(.sirens) }
            if s == .limit { self.logbook.record(.storm) }
            self.agentState = s
            self.refresh()
        }
        watcher.start()
        HotKey.handler = { [weak self] in self?.toggleHidden() }
        HotKey.register()
        DistributedNotificationCenter.default().addObserver(forName: ctlNotification, object: nil, queue: .main) { [weak self] n in
            if let cmd = n.object as? String { self?.control(cmd) }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.rebuildOverlays()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let self, let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let distracting = self.o.lotusEnabled && Self.isDistracting(app)
            if distracting != self.lotus {
                self.lotus = distracting
                if distracting && self.phase == .focus { self.logbook.record(.lotus) }
                self.log("lotus: \(distracting) (\(app.bundleIdentifier ?? "?"))")
                self.refresh()
            }
        }
        if o.autostart { start() }
        refresh()
        if !UserDefaults.standard.bool(forKey: "onboarded") && !o.autostart { showWelcome() }
        log("launched: state dir \(o.stateDir.path), speed \(o.speed)")
    }

    /// The Lotus-eaters: games, video and social apps (by their own App Store category).
    static func isDistracting(_ app: NSRunningApplication) -> Bool {
        guard let url = app.bundleURL, let info = Bundle(url: url)?.infoDictionary,
              let cat = info["LSApplicationCategoryType"] as? String else { return false }
        return cat.hasPrefix("public.app-category.") && (cat.contains("games") || cat.hasSuffix("entertainment")
            || cat.hasSuffix("social-networking") || cat.hasSuffix("video"))
    }

    func loadSprites() {
        // characters/ = shipping art; sketches/ = design-discussion drafts (not final).
        var roots: [URL] = []
        if let a = o.assets { roots.append(a) }
        if let r = Bundle.main.resourceURL { roots.append(r) }
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        roots.append(exe.deletingLastPathComponent().appendingPathComponent("../../assets"))
        let dirs = roots.flatMap { [$0.appendingPathComponent("characters"), $0.appendingPathComponent("sketches")] }
        for d in dirs {
            let files = (try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? []
            let isVector = { (u: URL) in FileManager.default.fileExists(atPath: u.appendingPathComponent("character.txt").path) }
            for f in files where (f.pathExtension == "sprite" || isVector(f))
                && sprites[f.pathExtension == "sprite" ? f.deletingPathExtension().lastPathComponent : f.lastPathComponent] == nil {
                do { let s = try SpriteSheet(url: f); sprites[s.id] = s } catch { log("sprite error: \(error)") }
            }
        }
        if sprites[o.character] == nil { o.character = sprites["odysseus-vector"] != nil ? "odysseus-vector" : sprites.keys.sorted().first ?? "" }
        log("sprites: \(sprites.keys.sorted())")
    }

    /// Display connected, disconnected or changed: keep the overlay of every display that is
    /// still there (it resizes in place, so its border and traveler carry on without a fade),
    /// add overlays for new displays and close the ones whose display is gone.
    func rebuildOverlays() {
        var kept: [CGDirectDisplayID: Overlay] = [:]
        for ov in overlays { kept[displayID(ov.screen)] = ov }
        overlays = NSScreen.screens.map { scr in
            if let ov = kept.removeValue(forKey: displayID(scr)) { ov.move(to: scr); return ov }
            return Overlay(screen: scr, excludeFromCapture: o.excludeFromCapture)
        }
        kept.values.forEach { $0.close() }
        for ov in overlays {
            ov.sceneProvider = { [weak self, weak ov] in ov.flatMap { self?.scene(for: $0) } ?? Scene() }
            ov.log = { [weak self] in self?.log($0) }
        }
        refresh()
    }

    // MARK: model -> scenes

    func displayID(_ s: NSScreen) -> CGDirectDisplayID {
        s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    func scene(for ov: Overlay) -> Scene {
        var s = Scene()
        s.phase = phase
        s.duration = phaseDuration
        s.elapsed = min(elapsed, phaseDuration)
        s.paused = pausedAt != nil
        s.agent = o.agentEnabled ? agentState : .idle
        s.lapDuration = 720 / o.speed
        s.lapElapsed = (lapFrozenAt ?? Date()).timeIntervalSince(lapStart).truncatingRemainder(dividingBy: s.lapDuration)
        s.style = o.style
        s.thickness = o.thickness
        s.sprite = sprites[o.character]
        // Per-lap variety, seeded so a lap looks the same after a restart.
        var rng = SplitMix64(state: UInt64(max(focusCount, 0)) &* 7919 &+ 17)
        s.climbAnim = o.climbVariant ?? ["climb", "climb-crag", "climb-olive", "climb-mast"][Int(rng.next() % 4)]
        s.ceilingAnim = o.ceilingVariant ?? (focusCount % 2 == 1 ? "zip" : "cling")
        s.physical = o.physicalPace
        s.restIsLong = restIsLong
        s.dozing = lotus && phase == .focus
        s.overrideAnim = overrideAnim
        let (borderScreens, travelerScreen) = targetScreens()
        s.hostsTraveler = ov.screen == travelerScreen
        let onThisDisplay = borderScreens.contains(ov.screen)
        let hasContent = (phase != .idle || s.agent != .idle) && onThisDisplay
        let hiddenForLast5 = o.onlyLast5 && phase == .focus && remaining > 300 / o.speed && s.agent != .waiting
        s.visible = hasContent && !manualHidden && !hiddenForLast5
            && !(o.hideWhenCaptured && detector.result.capturing)
            && !detector.result.coveredDisplays.contains(displayID(ov.screen))
        return s
    }

    // MARK: displays

    /// The display you are working on: the one holding the frontmost app's front window,
    /// else the one under the cursor.
    var activeScreen: NSScreen? {
        if let id = detector.result.activeDisplay, let s = NSScreen.screens.first(where: { displayID($0) == id }) { return s }
        let m = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(m) }
    }

    /// Which displays get the border, and which one hosts the traveler.
    func targetScreens() -> ([NSScreen], NSScreen?) {
        let screens = NSScreen.screens
        guard let main = screens.first else { return ([], nil) }
        switch o.display {
        case "main": return ([main], main)
        case "all": return (screens, activeScreen ?? main)
        case "follow": let a = activeScreen ?? main; return ([a], a)
        default:
            let pick = Int(o.display).flatMap { screens.indices.contains($0) ? screens[$0] : nil }
                ?? screens.first { $0.localizedName == o.display }
            let s = pick ?? main   // a disconnected display falls back to the main one
            return ([s], s)
        }
    }

    func refresh() {
        for ov in overlays { ov.apply(scene(for: ov)) }
        updateTitle()
    }

    // MARK: timer control

    func start() {
        phase = .focus
        focusCount += 1
        phaseDuration = o.focusMinutes * 60 / o.speed
        phaseStart = Date()
        pausedAt = nil
        pausedTotal = 0
        schedulePhaseTimers()
        refresh()
        planEpisodes()
    }

    // MARK: episodes

    var hostOverlay: Overlay? { overlays.first { scene(for: $0).hostsTraveler } }

    func cancelEpisodes() {
        episodeTimers.forEach { $0.invalidate() }
        episodeTimers.removeAll()
        overrideAnim = nil
        overlays.forEach { $0.clearEpisodes() }
    }

    func planEpisodes() {
        cancelEpisodes()
        guard phase == .focus, pausedAt == nil, o.style == .traveler, let host = hostOverlay,
              let sprite = sprites[o.character] else { return }
        let pt = sprite.unitPoints(backing: host.screen.backingScaleFactor)
        let j = Journey(size: host.screen.frame.size, inset: CGFloat(sprite.height) * pt / 2, weights: Journey.weights(physical: o.physicalPace))
        let plan = EpisodePlanner.plan(seed: UInt64(phaseStart.timeIntervalSince1970) &+ UInt64(focusCount),
                                       journey: j, focusSeconds: phaseDuration,
                                       lastFiveShare: (300 / o.speed) / phaseDuration, forced: o.episodes)
        let now = elapsed
        for (ep, share) in plan {
            let delay = share * phaseDuration - now
            guard delay > 0 else { continue }
            let t = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in self?.fire(ep) }
            t.tolerance = 0.05
            episodeTimers.append(t)
        }
        log("episodes: " + plan.map { "\($0.0.rawValue)@\(String(format: "%.2f", $0.1))" }.joined(separator: " "))
    }

    func fire(_ ep: Episode) {
        guard phase == .focus, pausedAt == nil, let host = hostOverlay, let sprite = sprites[o.character] else { return }
        log("episode: \(ep.rawValue)")
        logbook.record(ep)
        switch ep {
        case .cyclops:
            host.play(.cyclops, sprite: sprite, seconds: 3)
            // then he escapes under the belly of a ram for a stretch of the floor
            let floorSeconds = min(6, phaseDuration * 0.08)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
                guard let self, self.phase == .focus else { return }
                self.overrideAnim = "ram"
                self.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + floorSeconds) { [weak self] in
                    self?.overrideAnim = nil
                    self?.refresh()
                }
            }
        case .circe:
            host.play(.circe, sprite: sprite, seconds: min(8, phaseDuration * 0.25))
        case .owl:
            host.play(.owl, sprite: sprite, seconds: max(remaining, 1))
        default:
            host.play(ep, sprite: sprite, seconds: 2)
        }
    }

    func pause() {
        guard phase != .idle, pausedAt == nil else { return }
        pausedAt = Date()
        phaseTimer?.invalidate(); last5Timer?.invalidate(); titleTimer?.invalidate()
        cancelEpisodes()
        refresh()
    }

    func resume() {
        guard let p = pausedAt else { return }
        pausedTotal += Date().timeIntervalSince(p)
        pausedAt = nil
        schedulePhaseTimers()
        refresh()
        planEpisodes()
    }

    func stop() {
        phase = .idle
        pausedAt = nil
        lapStart = Date()                                   // agent laps restart from home
        lapFrozenAt = agentState == .working ? nil : lapStart
        phaseTimer?.invalidate(); last5Timer?.invalidate(); titleTimer?.invalidate()
        cancelEpisodes()
        refresh()
    }

    func startRest() {
        cancelEpisodes()
        restIsLong = Durations.isLongBreak(afterFocus: focusCount, every: o.longEvery)   // long: Calypso's island
        logbook.record(restIsLong ? .calypso : .ithaca)
        phase = .rest
        phaseDuration = breakMinutes * 60 / o.speed
        phaseStart = Date()
        pausedAt = nil
        pausedTotal = 0
        schedulePhaseTimers()
        refresh()
    }

    func schedulePhaseTimers() {
        phaseTimer?.invalidate(); last5Timer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.phase == .focus ? self.focusEnded() : self.breakEnded()
        }
        phaseTimer?.tolerance = 0.1
        let untilLast5 = remaining - 300 / o.speed
        if phase == .focus, untilLast5 > 0 {
            last5Timer = Timer.scheduledTimer(withTimeInterval: untilLast5, repeats: false) { [weak self] _ in self?.refresh() }
        }
        scheduleTitleTimer()
    }

    /// Ticks only the menu-bar text (and the open menu's header), never the edge animation.
    func scheduleTitleTimer() {
        titleTimer?.invalidate()
        guard phase != .idle, pausedAt == nil else { return }   // nothing counts down: no wakeups
        let every: TimeInterval = o.showSeconds || o.speed > 1 ? 1 : 15
        let t = Timer(timeInterval: every, repeats: true) { [weak self] _ in self?.updateTitle() }
        t.tolerance = every == 1 ? 0.05 : 5
        RunLoop.main.add(t, forMode: .common)   // .common: keeps ticking while the menu is open
        titleTimer = t
    }

    /// Time is up: he reaches Ithaca (or Calypso's island), the edge glows gold once, and,
    /// if the user wants them, a notification and a soft sound.
    func focusEnded() {
        log("focus ended: \(restIsLong ? "Calypso" : "Ithaca"), notify=\(o.notifyAtEnd) sound=\(o.sound)")
        startRest()
        overlays.forEach { $0.glow() }
        chime(focusEnded: true)
        notify(endMessage(focusEnded: true, longBreak: restIsLong, breakMinutes: Int(breakMinutes), korean: korean))
    }

    /// The break is over: wait for a click (default) or start the next focus by itself.
    func breakEnded() {
        log("break ended: autoNextFocus=\(o.autoNextFocus)")
        chime(focusEnded: false)
        if !o.autoNextFocus { notify(endMessage(focusEnded: false, longBreak: false, breakMinutes: 0, korean: korean)) }
        o.autoNextFocus ? start() : stop()
    }

    /// Harp: arriving at Ithaca after a focus, setting sail after a break. Silent when off.
    func chime(focusEnded: Bool) {
        guard let name = Chime.sound(o.sound, focusEnded: focusEnded) else { return }
        guard let snd = NSSound(named: name) else { log("sound: \(name) not found"); return }
        log("sound: \(name) at \(o.soundVolume)")
        snd.volume = Chime.volumes[o.soundVolume] ?? 0.25
        snd.play()
    }

    var korean: Bool { Locale.preferredLanguages.first?.hasPrefix("ko") == true }

    /// Asks for permission the first time; if the user declines, nothing is shown.
    func notify(_ m: (title: String, body: String)) {
        guard o.notifyAtEnd else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, error in
            if let error { self.log("notification: \(error)") }
            self.log("notification: granted=\(granted) \(m.title)")
            guard granted else { return }
            let c = UNMutableNotificationContent()
            c.title = m.title
            c.body = m.body
            center.add(UNNotificationRequest(identifier: "edge-odyssey-end", content: c, trigger: nil)) { e in if let e { self.log("notification: \(e)") } }
        }
    }

    /// Asks for a custom length in whole minutes; nil when cancelled or out of range.
    func askMinutes(_ what: String, current: Double, range: ClosedRange<Double>) -> Double? {
        let alert = NSAlert()
        alert.messageText = "\(what) length"
        alert.informativeText = "Minutes, \(Int(range.lowerBound)) to \(Int(range.upperBound)). Applies from the next session."
        let field = NSTextField(string: String(Int(current)))
        field.frame = NSRect(x: 0, y: 0, width: 80, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return Durations.minutes(field.stringValue, in: range)
    }

    func toggleHidden() {
        manualHidden.toggle()
        log("manual hide: \(manualHidden)")
        refresh()
    }

    /// Saves one setting the user changed (only that one: other values may be one-run flags).
    func remember(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }

    func control(_ cmd: String) {
        log("ctl: \(cmd)")
        let parts = cmd.split(separator: ":", maxSplits: 1).map(String.init)
        let arg = parts.count > 1 ? parts[1] : ""
        switch parts[0] {
        case "start": start()
        case "pause": pause()
        case "resume": resume()
        case "stop": stop()
        case "skip": phase == .focus ? startRest() : stop()
        case "seek":   // demo only: jump to a share of the current phase, e.g. seek:0.4
            if let f = Double(arg), phase != .idle {
                phaseStart = Date().addingTimeInterval(-f * phaseDuration)
                pausedTotal = 0
                if pausedAt != nil { pausedAt = Date() }
                schedulePhaseTimers(); refresh(); planEpisodes()
            }
        case "style": o.style = Style(rawValue: arg) ?? o.style; remember("style", o.style.rawValue); refresh(); planEpisodes()
        case "pace": o.physicalPace = arg == "physical"; remember("pace", o.physicalPace ? "physical" : "even"); refresh(); planEpisodes()
        case "char": if sprites[arg] != nil { o.character = arg; refresh() }
        case "thickness": o.thickness = CGFloat(min(max(Double(arg) ?? 3, 2), 4)); remember("thickness", Double(o.thickness)); refresh()
        case "last5": o.onlyLast5 = arg == "on"; remember("onlyLast5", o.onlyLast5); refresh()
        case "agent": o.agentEnabled = arg != "off"; remember("agentEnabled", o.agentEnabled); refresh()
        case "lotus-enabled":
            o.lotusEnabled = arg != "off"
            if !o.lotusEnabled { lotus = false }
            remember("lotusEnabled", o.lotusEnabled); refresh()
        case "seconds": o.showSeconds = arg != "off"; remember("showSeconds", o.showSeconds); scheduleTitleTimer(); updateTitle()
        case "focus": if let m = Durations.minutes(arg, in: Durations.focusRange) { o.focusMinutes = m; remember("focusMinutes", m) }
        case "rest": if let m = Durations.minutes(arg, in: Durations.breakRange) { o.restMinutes = m; remember("restMinutes", m) }
        case "long-every": if let n = Int(arg), Durations.longEveryChoices.contains(n) { o.longEvery = n; remember("longEvery", n) }
        case "notify": o.notifyAtEnd = arg != "off"; remember("notifyAtEnd", o.notifyAtEnd)
        case "sound": o.sound = Chime.choice(arg); remember("sound", o.sound); if o.sound != "off" { chime(focusEnded: true) }   // a preview
        case "volume": o.soundVolume = Chime.volume(arg); remember("soundVolume", o.soundVolume); chime(focusEnded: true)
        case "autonext": o.autoNextFocus = arg == "on"; remember("autoNextFocus", o.autoNextFocus)
        case "share-hide": o.hideWhenCaptured = arg != "off"; remember("hideWhenCaptured", o.hideWhenCaptured); refresh()
        case "hide": manualHidden = true; refresh()
        case "show": manualHidden = false; refresh()
        case "display": o.display = arg; remember("display", arg); refresh(); planEpisodes()
        case "lotus": lotus = arg == "on"; if lotus { logbook.record(.lotus) }; refresh()
        case "logbook": showLogbook()
        case "welcome": showWelcome()
        case "episode": if let e = Episode(rawValue: arg) { fire(e) }
        case "login": setLoginItem(arg == "on")
        case "quit": NSApp.terminate(nil)
        default: log("unknown ctl \(cmd)")
        }
    }

    // MARK: status item

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: "Edge Odyssey")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)   // 12:50 -> 12:49 without the icon wobbling
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func updateTitle() {
        guard let b = statusItem?.button else { return }
        if phase == .idle {
            b.title = ""
            b.image = NSImage(systemSymbolName: agentState == .waiting ? "circle.circle.fill" : "circle.dashed", accessibilityDescription: "Edge Odyssey")
            titleSymbol = nil
            return
        }
        let symbol = phase == .rest ? "cup.and.saucer" : "circle.dashed.inset.filled"
        if symbol != titleSymbol {   // the per-second tick changes only the text
            b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Edge Odyssey")
            titleSymbol = symbol
        }
        let title = pausedAt != nil ? " paused" : " " + left
        if b.title != title { b.title = title }
        if let h = headerItem, h.title != header { h.title = header }
    }

    /// Time left in the user's chosen style, nominal even at demo speed.
    var left: String { o.showSeconds ? countdown(remaining * o.speed) : minutesLeft(remaining * o.speed) }

    var header: String {
        switch phase {
        case .idle: return "Ready"
        case .focus: return pausedAt != nil ? "Focus paused: \(left) left" : "Focus: \(left) left"
        case .rest: return pausedAt != nil ? "Break paused: \(left) left" : "Break: \(left) left"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let h = NSMenuItem(title: header, action: nil, keyEquivalent: "")
        h.isEnabled = false
        menu.addItem(h)
        headerItem = h
        if phase == .idle {
            menu.addItem(MenuAction("Start focus (\(Int(o.focusMinutes)) min)", key: "s") { [weak self] in self?.start() })
        } else {
            if pausedAt == nil { menu.addItem(MenuAction("Pause") { [weak self] in self?.pause() }) }
            else { menu.addItem(MenuAction("Resume") { [weak self] in self?.resume() }) }
            menu.addItem(MenuAction(phase == .focus ? "Skip to break" : "End break") { [weak self] in self?.control("skip") })
            menu.addItem(MenuAction("Stop") { [weak self] in self?.stop() })
        }
        menu.addItem(.separator())

        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let m = NSMenu()
            items.forEach(m.addItem)
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = m
            return item
        }
        menu.addItem(submenu("Mode", [
            MenuAction("Odysseus voyage (border + traveler)", checked: o.style == .traveler) { [weak self] in self?.control("style:traveler") },
            MenuAction("Thin border only", checked: o.style == .border) { [weak self] in self?.control("style:border") },
            .separator(),
            MenuAction("Speed: Even (halfway round = halfway through)", checked: !o.physicalPace) { [weak self] in self?.control("pace:even") },
            MenuAction("Speed: Physical (slow climb, fast slide)", checked: o.physicalPace) { [weak self] in self?.control("pace:physical") },
        ]))
        var displays: [NSMenuItem] = [
            MenuAction("Main display", checked: o.display == "main") { [weak self] in self?.control("display:main") },
            MenuAction("All displays (Odysseus follows you)", checked: o.display == "all") { [weak self] in self?.control("display:all") },
            MenuAction("Follow me (the display I'm working on)", checked: o.display == "follow") { [weak self] in self?.control("display:follow") },
            .separator(),
        ]
        for (i, scr) in NSScreen.screens.enumerated() {
            let size = "\(Int(scr.frame.width))x\(Int(scr.frame.height))\(scr.backingScaleFactor > 1 ? " Retina" : "")"
            let name = scr.localizedName   // saved by name: indices shift when displays come and go
            displays.append(MenuAction("\(name) (\(size))", checked: o.display == name || o.display == String(i)) { [weak self] in
                self?.control("display:\(name)")
            })
        }
        menu.addItem(submenu("Show on", displays))
        menu.addItem(submenu("Border", [2, 3, 4].map { t in
            MenuAction("\(t) px\(t == 2 ? " (thinnest)" : "")", checked: Int(o.thickness) == t) { [weak self] in self?.control("thickness:\(t)") }
        }))
        func choices(_ presets: [Int], current: Double, unit: String, cmd: String, custom: @escaping () -> Void) -> [NSMenuItem] {
            var items: [NSMenuItem] = presets.map { m in
                MenuAction("\(m) \(unit)", checked: Int(current) == m) { [weak self] in self?.control("\(cmd):\(m)") }
            }
            let isCustom = !presets.contains(Int(current))
            items.append(MenuAction(isCustom ? "Custom (\(Int(current)) \(unit))…" : "Custom…", checked: isCustom, custom))
            return items
        }
        let long = Int(Durations.longBreakMinutes(rest: o.restMinutes))
        menu.addItem(submenu("Timer", [
            submenu("Focus: \(Int(o.focusMinutes)) min", choices(Durations.focusPresets, current: o.focusMinutes, unit: "min", cmd: "focus") { [weak self] in
                guard let self, let m = self.askMinutes("Focus", current: self.o.focusMinutes, range: Durations.focusRange) else { return }
                self.control("focus:\(Int(m))")
            }),
            submenu("Break: \(Int(o.restMinutes)) min", choices(Durations.breakPresets, current: o.restMinutes, unit: "min", cmd: "rest") { [weak self] in
                guard let self, let m = self.askMinutes("Break", current: self.o.restMinutes, range: Durations.breakRange) else { return }
                self.control("rest:\(Int(m))")
            }),
            submenu("Long break (\(long) min): every \(o.longEvery) sessions", Durations.longEveryChoices.map { n in
                MenuAction("Every \(n) sessions", checked: o.longEvery == n) { [weak self] in self?.control("long-every:\(n)") }
            }),
            .separator(),
            MenuAction("Notify when time is up", checked: o.notifyAtEnd) { [weak self] in
                guard let self else { return }
                self.control(self.o.notifyAtEnd ? "notify:off" : "notify:on")
            },
            submenu("Sound", [
                MenuAction("Harp", checked: o.sound == "harp") { [weak self] in self?.control("sound:harp") },
                MenuAction("Glass (system)", checked: o.sound == "glass") { [weak self] in self?.control("sound:glass") },
                MenuAction("Off", checked: o.sound == "off") { [weak self] in self?.control("sound:off") },
                .separator(),
                MenuAction("Volume: low", checked: o.soundVolume == "low") { [weak self] in self?.control("volume:low") },
                MenuAction("Volume: medium", checked: o.soundVolume == "medium") { [weak self] in self?.control("volume:medium") },
            ]),
            MenuAction("Start the next focus after a break", checked: o.autoNextFocus) { [weak self] in
                guard let self else { return }
                self.control(self.o.autoNextFocus ? "autonext:off" : "autonext:on")
            },
        ]))
        menu.addItem(MenuAction("Only show in the last 5 minutes", checked: o.onlyLast5) { [weak self] in
            guard let self else { return }
            self.control(self.o.onlyLast5 ? "last5:off" : "last5:on")
        })
        menu.addItem(.separator())
        let agentTitle: String
        switch agentState {
        case .idle: agentTitle = "Claude Code: no active session"
        case .working: agentTitle = "Claude Code: working"
        case .waiting: agentTitle = "Claude Code: waiting for you"
        case .limit: agentTitle = "Claude Code: near usage limit"
        }
        let ai = NSMenuItem(title: agentTitle, action: nil, keyEquivalent: "")
        ai.isEnabled = false
        menu.addItem(ai)
        menu.addItem(.separator())
        menu.addItem(MenuAction("Logbook (\(logbook.found.count) of 24 books)…", key: "l") { [weak self] in self?.showLogbook() })
        menu.addItem(submenu("Settings", [
            MenuAction("Show Claude Code signals", checked: o.agentEnabled) { [weak self] in
                guard let self else { return }
                self.control(self.o.agentEnabled ? "agent:off" : "agent:on")
            },
            MenuAction("Doze while a game, video or social app is in front", checked: o.lotusEnabled) { [weak self] in
                guard let self else { return }
                self.control(self.o.lotusEnabled ? "lotus-enabled:off" : "lotus-enabled:on")
            },
            MenuAction("Hide while the screen is shared or recorded", checked: o.hideWhenCaptured) { [weak self] in
                guard let self else { return }
                self.control(self.o.hideWhenCaptured ? "share-hide:off" : "share-hide:on")
            },
            MenuAction("Count down in seconds (12:50, not 13m)", checked: o.showSeconds) { [weak self] in
                guard let self else { return }
                self.control(self.o.showSeconds ? "seconds:off" : "seconds:on")
            },
            .separator(),
            MenuAction("Launch at login", checked: LoginItem.isOn) { [weak self] in self?.toggleLoginItem() },
            MenuAction("Welcome guide…") { [weak self] in self?.showWelcome() },
        ]))
        let hide = MenuAction(manualHidden ? "Show again" : "Hide now") { [weak self] in self?.toggleHidden() }
        hide.keyEquivalent = "h"
        hide.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(hide)
        menu.addItem(.separator())
        menu.addItem(MenuAction("Quit Edge Odyssey", key: "q") { NSApp.terminate(nil) })
    }

    // MARK: login item (off unless the user turns it on)

    func toggleLoginItem() { setLoginItem(!LoginItem.isOn) }

    func setLoginItem(_ on: Bool) {
        do {
            try LoginItem.set(on)
            log("login item: \(SMAppService.mainApp.status.rawValue)")
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            log("login item: \(error)")
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at login"
            alert.informativeText = "\(error.localizedDescription)\n\nYou can add Edge Odyssey in System Settings > General > Login Items."
            alert.addButton(withTitle: "Open Login Items")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { SMAppService.openSystemSettingsLoginItems() }
        }
    }

    // MARK: windows

    let logbookWindow = PanelWindow()

    func showLogbook() {
        logbookWindow.show(title: "Logbook", LogbookView(found: logbook.found, character: sprites["odysseus-vector"]?.folder))
    }
    let welcomeWindow = PanelWindow()

    func showWelcome() {
        UserDefaults.standard.set(true, forKey: "onboarded")
        welcomeWindow.show(title: "Welcome to Edge Odyssey", WelcomeView(
            character: sprites["odysseus-vector"]?.folder,
            copyHookSnippet: { [weak self] in self?.installHooksAndCopySnippet() ?? "" },
            setLoginItem: { [weak self] in self?.setLoginItem($0) },
            finish: { [weak self] start in
                self?.welcomeWindow.close()
                if start, self?.phase == .idle { self?.start() }
            }))
    }

    /// Puts the hook scripts in the app's own folder (~/.edge-odyssey/hooks) and copies the
    /// settings snippet for the user to paste. ~/.claude/settings.json is never touched.
    func installHooksAndCopySnippet() -> String {
        guard let src = Bundle.main.resourceURL?.appendingPathComponent("hooks"),
              var snippet = try? String(contentsOf: src.appendingPathComponent("claude-settings-snippet.json"), encoding: .utf8)
        else { return "Hook files are missing from the app bundle." }
        let fm = FileManager.default
        let dest = o.stateDir.appendingPathComponent("hooks")
        do {
            try fm.createDirectory(at: dest, withIntermediateDirectories: true)
            for name in ["edge-odyssey-hook.sh", "edge-odyssey-statusline.sh"] {
                let to = dest.appendingPathComponent(name)
                try? fm.removeItem(at: to)
                try fm.copyItem(at: src.appendingPathComponent(name), to: to)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: to.path)
            }
        } catch { return "Couldn't install the hook scripts: \(error.localizedDescription)" }
        let home = fm.homeDirectoryForCurrentUser.appendingPathComponent(".edge-odyssey").path
        if o.stateDir.path != home {   // a custom --state-dir: the hooks must write there too
            let dir = "'" + o.stateDir.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
            snippet = snippet.replacingOccurrences(of: "$HOME/.edge-odyssey/hooks/", with: "EDGE_ODYSSEY_STATE_DIR=\(dir) \(dir)/hooks/")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        log("hooks installed in \(dest.path), snippet copied")
        return "Copied. Hook scripts are in \(dest.path.replacingOccurrences(of: fm.homeDirectoryForCurrentUser.path, with: "~"))."
    }

    // MARK: demo backdrop (keeps private screen content out of recordings)

    func showBackdrop(on index: Int) {
        guard NSScreen.screens.indices.contains(index) else { return }
        let scr = NSScreen.screens[index]
        let w = NSWindow(contentRect: scr.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.setFrame(scr.frame, display: false)
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .stationary]
        w.isReleasedWhenClosed = false
        let v = NSView(frame: CGRect(origin: .zero, size: scr.frame.size))
        let root = CAGradientLayer()
        root.colors = [NSColor(srgbRed: 0.93, green: 0.94, blue: 0.96, alpha: 1).cgColor,
                       NSColor(srgbRed: 0.84, green: 0.87, blue: 0.92, alpha: 1).cgColor]
        v.layer = root
        v.wantsLayer = true
        let size = scr.frame.size
        func mockWindow(_ r: CGRect, dark: Bool) {
            let win = CALayer()
            win.frame = r
            win.backgroundColor = (dark ? NSColor(srgbRed: 0.13, green: 0.14, blue: 0.18, alpha: 1) : .white).cgColor
            win.cornerRadius = 10
            win.shadowOpacity = 0.18
            win.shadowRadius = 14
            win.shadowOffset = CGSize(width: 0, height: -4)
            for i in 0..<Int((r.height - 60) / 22) {
                let line = CALayer()
                let lw = (r.width - 60) * CGFloat([0.8, 0.55, 0.7, 0.4, 0.65][i % 5])
                line.frame = CGRect(x: 24 + CGFloat(i % 3) * 14, y: r.height - 56 - CGFloat(i) * 22, width: lw, height: 8)
                line.backgroundColor = (dark ? NSColor(white: 1, alpha: 0.16) : NSColor(white: 0, alpha: 0.08)).cgColor
                line.cornerRadius = 4
                win.addSublayer(line)
            }
            root.addSublayer(win)
        }
        mockWindow(CGRect(x: size.width * 0.08, y: size.height * 0.18, width: size.width * 0.5, height: size.height * 0.62), dark: true)
        mockWindow(CGRect(x: size.width * 0.52, y: size.height * 0.28, width: size.width * 0.38, height: size.height * 0.5), dark: false)
        let label = CATextLayer()
        label.string = "Edge Odyssey - demo backdrop (timer at \(Int(o.speed))x speed)"
        label.fontSize = 15
        label.foregroundColor = NSColor(white: 0.25, alpha: 1).cgColor
        label.contentsScale = scr.backingScaleFactor
        label.frame = CGRect(x: size.width * 0.08, y: size.height * 0.1, width: size.width * 0.8, height: 22)
        root.addSublayer(label)
        w.contentView = v
        w.orderFrontRegardless()
        backdrops.append(w)
    }
}

// MARK: entry

let opts = Options(CommandLine.arguments)
if let cmd = opts.ctl {
    DistributedNotificationCenter.default().postNotificationName(ctlNotification, object: cmd, userInfo: nil, deliverImmediately: true)
    exit(0)
}
if let dir = opts.exportSprites {
    let probe = App(opts)
    probe.loadSprites()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for s in probe.sprites.values { for sc in [1, 2, 3] { try? s.exportPNGs(to: dir, scale: sc) } }
    print("exported \(probe.sprites.count) characters to \(dir.path)")
    exit(0)
}
let app = NSApplication.shared
let delegate = App(opts)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
