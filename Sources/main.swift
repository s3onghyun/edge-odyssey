import AppKit
import Carbon.HIToolbox
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
    var focusDisplay = ""           // focus mode opens on this display (by name), else the one you work on
    var focusAtLaunch = false       // demo/test: open focus mode at launch
    var focusFrame: CGRect?         // demo/test: focus mode as a window at x,y,w,h instead of full screen
    var appearance: String?         // demo/test: "dark" or "light" instead of the system appearance
    var mode = TimerMode.pomodoro   // Pomodoro, a plain countdown timer, or a stopwatch
    var timerSeconds = 600.0        // the countdown timer's length
    var background = "cycle"        // focus mode backdrop: "off", "cycle" or one photo's file name
    var backgroundFolder = ""       // the user's own photo folder; empty: the photos that ship with the app
    var backgroundDrift = true      // a slow Ken Burns drift on the backdrop

    /// Settings the menu changes are kept in UserDefaults; command-line flags override them
    /// for one run without being saved.
    static let saved: [String: Any] = ["style": "traveler", "display": "main", "thickness": 3.0, "onlyLast5": false,
                                       "agentEnabled": true, "lotusEnabled": true, "hideWhenCaptured": true,
                                       "showSeconds": true, "focusMinutes": 25.0, "restMinutes": 5.0, "longEvery": 4,
                                       "notifyAtEnd": true, "soundVolume": "low", "autoNextFocus": false, "pace": "even",
                                       "focusDisplay": "", "mode": "pomodoro", "timerSeconds": 600.0,
                                       "focusBackground": "cycle", "backgroundFolder": "", "backgroundDrift": true]   // "sound" unregistered: see init

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
        focusDisplay = d.string(forKey: "focusDisplay") ?? ""
        mode = TimerMode.named(d.string(forKey: "mode"))
        timerSeconds = Durations.timerRange.contains(d.double(forKey: "timerSeconds")) ? d.double(forKey: "timerSeconds") : 600
        background = d.string(forKey: "focusBackground") ?? "cycle"
        backgroundFolder = d.string(forKey: "backgroundFolder") ?? ""
        backgroundDrift = d.bool(forKey: "backgroundDrift")
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
            case "--focus-mode": focusAtLaunch = true
            case "--appearance": appearance = it.next()
            case "--mode": mode = TimerMode.named(it.next())
            case "--timer": timerSeconds = Durations.seconds(it.next() ?? "", in: Durations.timerRange) ?? 600
            case "--background": background = it.next() ?? "cycle"
            case "--focus-frame":
                let v = (it.next() ?? "").split(separator: ",").compactMap { Double($0) }
                if v.count == 4 { focusFrame = CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }
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

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var o: Options
    var sprites: [String: SpriteSheet] = [:]
    var spriteURLs: [String: URL] = [:]
    var overlays: [Overlay] = []
    /// Focus mode's window, while it is open. It hosts the traveler (3x, `focusSprites`).
    var focusOverlay: Overlay?
    var focusSprites: [String: SpriteSheet] = [:]
    var allOverlays: [Overlay] { overlays + (focusOverlay.map { [$0] } ?? []) }
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
    var scrollCarry = 0.0                // trackpad scrolling not yet worth a whole step
    var lengthShownUntil = Date.distantPast   // idle: the menu bar shows the length just scrolled to
    var backgroundIndex = Int.random(in: 0..<1000)

    init(_ o: Options) { self.o = o }

    func log(_ s: String) {
        guard o.verbose else { return }
        FileHandle.standardError.write("[\(String(format: "%.3f", Date().timeIntervalSince1970))] \(s)\n".data(using: .utf8)!)
    }

    /// Set when a phase starts, so a length changed in the menu applies from the next session.
    var phaseDuration: TimeInterval = 25 * 60
    var breakMinutes: Double { restIsLong ? Durations.longBreakMinutes(rest: o.restMinutes) : o.restMinutes }
    var elapsed: TimeInterval { (pausedAt ?? Date()).timeIntervalSince(phaseStart) - pausedTotal }
    /// Time left; for the stopwatch, until the end of this lap round the edge.
    var remaining: TimeInterval {
        o.mode == .stopwatch ? phaseDuration - elapsed.truncatingRemainder(dividingBy: phaseDuration) : max(phaseDuration - elapsed, 0)
    }

    // MARK: lifecycle

    func applicationDidFinishLaunching(_ n: Notification) {
        if let a = o.appearance { NSApp.appearance = NSAppearance(named: a == "dark" ? .darkAqua : .aqua) }
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
        HotKey.register(kVK_ANSI_H) { [weak self] in self?.toggleHidden() }
        HotKey.register(kVK_ANSI_F) { [weak self] in self?.toggleFocusMode() }
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
        if o.focusAtLaunch { openFocusMode() }
        // Scrolling over the menu-bar time changes it, as in focus mode.
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
            guard let self, let w = e.window, w === self.statusItem.button?.window else { return e }
            self.scrolled(e)
            return nil
        }
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

    /// --assets, the app's Resources, then the repository's assets/ next to a development build.
    var resourceRoots: [URL] {
        var roots: [URL] = []
        if let a = o.assets { roots.append(a) }
        if let r = Bundle.main.resourceURL { roots.append(r) }
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        roots.append(exe.deletingLastPathComponent().appendingPathComponent("../../assets"))
        return roots
    }

    func loadSprites() {
        // characters/ = shipping art; sketches/ = design-discussion drafts (not final).
        let dirs = resourceRoots.flatMap { [$0.appendingPathComponent("characters"), $0.appendingPathComponent("sketches")] }
        for d in dirs {
            let files = (try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? []
            let isVector = { (u: URL) in FileManager.default.fileExists(atPath: u.appendingPathComponent("character.txt").path) }
            for f in files where (f.pathExtension == "sprite" || isVector(f))
                && sprites[f.pathExtension == "sprite" ? f.deletingPathExtension().lastPathComponent : f.lastPathComponent] == nil {
                do { let s = try SpriteSheet(url: f); sprites[s.id] = s; spriteURLs[s.id] = f } catch { log("sprite error: \(error)") }
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
        if let f = focusOverlay, let s = f.window.screen { f.move(to: s) }
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
        s.elapsed = o.mode == .stopwatch ? elapsed.truncatingRemainder(dividingBy: phaseDuration) : min(elapsed, phaseDuration)
        s.calm = o.mode == .stopwatch   // laps never turn coral: nothing is running out
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
        if ov === focusOverlay {   // opened by the user: no last-5-minutes or covered-display hiding
            s.hostsTraveler = true
            s.thickness = FocusLayout.trackWidth
            s.sprite = focusSprite
            s.visible = phase != .idle || s.agent != .idle
            return s
        }
        let (borderScreens, travelerScreen) = targetScreens()
        s.hostsTraveler = focusOverlay == nil && ov.screen == travelerScreen
        // Focus mode replaces the edge on its own display.
        let onThisDisplay = borderScreens.contains(ov.screen) && focusOverlay.map { displayID($0.screen) != displayID(ov.screen) } ?? true
        let hasContent = (phase != .idle || s.agent != .idle) && onThisDisplay
        let hiddenForLast5 = o.onlyLast5 && phase == .focus && o.mode != .stopwatch && remaining > 300 / o.speed && s.agent != .waiting
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
        for ov in allOverlays { ov.apply(scene(for: ov)) }
        updateTitle()
    }

    // MARK: timer control

    func start() {
        phase = .focus
        if o.mode == .pomodoro { focusCount += 1 }   // timers and stopwatches don't bring a long break closer
        switch o.mode {
        case .pomodoro: phaseDuration = o.focusMinutes * 60 / o.speed
        case .timer: phaseDuration = o.timerSeconds / o.speed
        case .stopwatch: phaseDuration = Durations.stopwatchLap / o.speed
        }
        if o.background == "cycle" { backgroundIndex += 1; applyBackground() }
        phaseStart = Date()
        pausedAt = nil
        pausedTotal = 0
        schedulePhaseTimers()
        refresh()
        planEpisodes()
    }

    // MARK: episodes

    var hostOverlay: Overlay? { allOverlays.first { scene(for: $0).hostsTraveler } }

    func cancelEpisodes() {
        episodeTimers.forEach { $0.invalidate() }
        episodeTimers.removeAll()
        overrideAnim = nil
        allOverlays.forEach { $0.clearEpisodes() }
    }

    func planEpisodes() {
        cancelEpisodes()
        guard phase == .focus, pausedAt == nil, o.style == .traveler, o.mode != .stopwatch, let host = hostOverlay,
              let sprite = scene(for: host).sprite else { return }
        let pt = sprite.unitPoints(backing: host.screen.backingScaleFactor)
        let j = Journey(size: host.stageSize, inset: CGFloat(sprite.height) * pt / 2, weights: Journey.weights(physical: o.physicalPace))
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
        guard phase == .focus, pausedAt == nil, let host = hostOverlay, let sprite = scene(for: host).sprite else { return }
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
        phaseTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in self?.timeUp() }
        phaseTimer?.tolerance = 0.1
        let untilLast5 = remaining - 300 / o.speed
        if phase == .focus, o.mode != .stopwatch, untilLast5 > 0 {
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

    func timeUp() {
        switch o.mode.timeUp(in: phase, autoNext: o.autoNextFocus) {
        case .arrive: focusEnded()
        case .breakOver(let next): breakEnded(startNext: next)
        case .timerDone: timerDone()
        case .lap: schedulePhaseTimers(); refresh()
        case nil: break
        }
    }

    /// A countdown timer reached 0:00: the same glow, sound and notification as an arrival,
    /// a moment at Ithaca, then ready for the next one.
    func timerDone() {
        log("timer done: notify=\(o.notifyAtEnd) sound=\(o.sound)")
        phaseTimer?.invalidate(); last5Timer?.invalidate(); titleTimer?.invalidate()
        cancelEpisodes()
        refresh()
        updateTitle()
        allOverlays.forEach { $0.glow() }
        chime(focusEnded: true)
        notify(timerDoneMessage(seconds: Int(phaseDuration * o.speed), korean: korean))
        let ended = phaseStart
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in   // a new start in between wins
            guard let self, self.phaseStart == ended, self.phase == .focus else { return }
            self.stop()
        }
    }

    /// Time is up: he reaches Ithaca (or Calypso's island), the edge glows gold once, and,
    /// if the user wants them, a notification and a soft sound.
    func focusEnded() {
        log("focus ended: \(restIsLong ? "Calypso" : "Ithaca"), notify=\(o.notifyAtEnd) sound=\(o.sound)")
        startRest()
        allOverlays.forEach { $0.glow() }
        chime(focusEnded: true)
        notify(endMessage(focusEnded: true, longBreak: restIsLong, breakMinutes: Int(breakMinutes), korean: korean))
    }

    /// The break is over: wait for a click (default) or start the next focus by itself.
    func breakEnded(startNext: Bool) {
        log("break ended: autoNextFocus=\(startNext)")
        chime(focusEnded: false)
        if !startNext { notify(endMessage(focusEnded: false, longBreak: false, breakMinutes: 0, korean: korean)) }
        startNext ? start() : stop()
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
        askLength(what, hint: "Minutes, \(Int(range.lowerBound)) to \(Int(range.upperBound)). Applies from the next session.",
                  current: String(Int(current))).flatMap { Durations.minutes($0, in: range) }
    }

    /// The typed text, or nil when cancelled.
    func askLength(_ what: String, hint: String, current: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "\(what) length"
        alert.informativeText = hint
        let field = NSTextField(string: current)
        field.frame = NSRect(x: 0, y: 0, width: 80, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    // MARK: adjusting time (scroll wheel, trackpad, arrow keys)

    /// A scroll over the menu-bar time or the focus window: up adds time, down takes it away,
    /// whichever way the system scrolls content. Shift turns a mouse wheel sideways, so its
    /// horizontal delta counts too.
    func scrolled(_ e: NSEvent) {
        guard e.momentumPhase.isEmpty else { return }   // the glide after a swipe would run away
        if e.phase == .began { scrollCarry = 0 }
        let raw = e.scrollingDeltaY != 0 || !e.modifierFlags.contains(.shift) ? e.scrollingDeltaY : e.scrollingDeltaX
        let r = TimeAdjust.notches(carry: scrollCarry, delta: raw * (e.isDirectionInvertedFromDevice ? -1 : 1),
                                   precise: e.hasPreciseScrollingDeltas)
        scrollCarry = r.carry
        adjust(notches: r.notches, e.modifierFlags)
    }

    func adjust(notches: Int, _ flags: NSEvent.ModifierFlags) {
        guard notches != 0 else { return }
        adjust(by: Double(notches) * TimeAdjust.step(shift: flags.contains(.shift), option: flags.contains(.option)))
    }

    /// Idle: the length of the next session (saved). Running: this session only, by moving what
    /// is left. The stopwatch has nothing to set.
    func adjust(by delta: Double) {
        switch (phase, o.mode) {
        case (_, .stopwatch): return
        case (.idle, .timer):
            o.timerSeconds = TimeAdjust.duration(o.timerSeconds, elapsed: 0, by: delta, in: Durations.timerRange)
            remember("timerSeconds", o.timerSeconds)
        case (.idle, .pomodoro):   // the focus length is whole minutes
            let r = Durations.focusRange
            o.focusMinutes = TimeAdjust.duration(o.focusMinutes, elapsed: 0, by: (delta / 60).rounded(.awayFromZero), in: r)
            remember("focusMinutes", o.focusMinutes)
        default:
            let r = Durations.timerRange
            phaseDuration = TimeAdjust.duration(phaseDuration, elapsed: elapsed, by: delta / o.speed,
                                                in: (r.lowerBound / o.speed)...(r.upperBound / o.speed))
            if pausedAt == nil { schedulePhaseTimers(); planEpisodes() }
        }
        log("adjust \(delta): \(phase == .idle ? idleLength : left)")
        lengthShownUntil = Date().addingTimeInterval(2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) { [weak self] in self?.updateTitle() }
        refresh()
    }

    /// The length the next start runs for, as the clock shows it.
    var idleLength: String {
        switch o.mode {
        case .pomodoro: return countdown(o.focusMinutes * 60)
        case .timer: return countdown(o.timerSeconds)
        case .stopwatch: return elapsedClock(0)
        }
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
        case "skip": phase == .focus && o.mode == .pomodoro ? startRest() : stop()
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
        case "focus-mode": arg == "on" ? openFocusMode() : arg == "off" ? closeFocusMode() : toggleFocusMode()
        case "focus-display": openFocusMode(on: arg)
        case "mode":   // switching stops what is running: its clock means something else
            if phase != .idle { stop() }
            o.mode = TimerMode.named(arg); remember("mode", o.mode.rawValue); refresh()
        case "timer":   // a countdown length ("10", "1:30"); picking one means the timer
            if let sec = Durations.seconds(arg, in: Durations.timerRange) {
                o.timerSeconds = sec; remember("timerSeconds", sec)
                if o.mode != .timer { control("mode:timer") } else { refresh() }
            }
        case "adjust": if let d = Double(arg) { adjust(by: d) }   // scripting/demo: seconds, e.g. adjust:60
        case "background": o.background = arg; remember("focusBackground", arg); applyBackground()
        case "background-folder": o.backgroundFolder = arg; remember("backgroundFolder", arg); applyBackground()
        case "drift": o.backgroundDrift = arg != "off"; remember("backgroundDrift", o.backgroundDrift); applyBackground()
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
        updateFocus()
        guard let b = statusItem?.button else { return }
        if phase == .idle {
            b.title = lengthShownUntil > Date() ? " " + idleLength : ""
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
    var left: String {
        if o.mode == .stopwatch { let e = elapsed * o.speed; return o.showSeconds ? elapsedClock(e) : "\(Int(e / 60))m" }
        return o.showSeconds ? countdown(remaining * o.speed) : minutesLeft(remaining * o.speed)
    }

    var header: String {
        let paused = pausedAt != nil
        switch (phase, o.mode) {
        case (.idle, .pomodoro): return "Ready"
        case (.idle, .timer): return "Timer: \(idleLength)"
        case (.idle, .stopwatch): return "Stopwatch: ready"
        case (_, .timer): return paused ? "Timer paused: \(left) left" : "Timer: \(left) left"
        case (_, .stopwatch): return paused ? "Stopwatch paused: \(left)" : "Stopwatch: \(left)"
        case (.focus, _): return paused ? "Focus paused: \(left) left" : "Focus: \(left) left"
        case (.rest, _): return paused ? "Break paused: \(left) left" : "Break: \(left) left"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let h = NSMenuItem(title: header, action: nil, keyEquivalent: "")
        h.isEnabled = false
        menu.addItem(h)
        headerItem = h
        if phase == .idle {
            let title: String
            switch o.mode {
            case .pomodoro: title = "Start focus (\(Int(o.focusMinutes)) min)"
            case .timer: title = "Start timer (\(idleLength))"
            case .stopwatch: title = "Start stopwatch"
            }
            menu.addItem(MenuAction(title, key: "s") { [weak self] in self?.start() })
        } else {
            if pausedAt == nil { menu.addItem(MenuAction("Pause") { [weak self] in self?.pause() }) }
            else { menu.addItem(MenuAction("Resume") { [weak self] in self?.resume() }) }
            if o.mode == .pomodoro {
                menu.addItem(MenuAction(phase == .focus ? "Skip to break" : "End break") { [weak self] in self?.control("skip") })
            }
            menu.addItem(MenuAction("Stop") { [weak self] in self?.stop() })
        }
        let fm = MenuAction(focusOverlay == nil ? "Focus mode" : "Close focus mode") { [weak self] in self?.toggleFocusMode() }
        fm.keyEquivalent = "f"
        fm.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(fm)
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
        if NSScreen.screens.count > 1 {
            menu.addItem(submenu("Focus mode on", NSScreen.screens.map { scr in
                let name = scr.localizedName
                return MenuAction(name, checked: o.focusDisplay == name) { [weak self] in self?.control("focus-display:\(name)") }
            }))
        }
        var backgrounds: [NSMenuItem] = [
            MenuAction("Off", checked: o.background == "off") { [weak self] in self?.control("background:off") },
            MenuAction("A different photo each session", checked: o.background == "cycle") { [weak self] in self?.control("background:cycle") },
        ]
        let files = backgroundFiles()
        if !files.isEmpty { backgrounds.append(.separator()) }
        for f in files {
            let name = f.lastPathComponent
            backgrounds.append(MenuAction(Self.photoTitle(f), checked: o.background == name) { [weak self] in self?.control("background:\(name)") })
        }
        backgrounds.append(.separator())
        let folder = o.backgroundFolder.isEmpty ? nil : URL(fileURLWithPath: o.backgroundFolder).lastPathComponent
        backgrounds.append(MenuAction(folder.map { "My folder: \($0)…" } ?? "Use my own folder…", checked: folder != nil) { [weak self] in
            self?.chooseBackgroundFolder()
        })
        if folder != nil {
            backgrounds.append(MenuAction("Use the photos that come with the app") { [weak self] in self?.control("background-folder:") })
        }
        backgrounds.append(MenuAction("Slow drift", checked: o.backgroundDrift) { [weak self] in
            guard let self else { return }
            self.control(self.o.backgroundDrift ? "drift:off" : "drift:on")
        })
        menu.addItem(submenu("Focus mode background", backgrounds))
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
            MenuAction("Pomodoro (focus, then a break)", checked: o.mode == .pomodoro) { [weak self] in self?.control("mode:pomodoro") },
            MenuAction("Countdown timer", checked: o.mode == .timer) { [weak self] in self?.control("mode:timer") },
            MenuAction("Stopwatch", checked: o.mode == .stopwatch) { [weak self] in self?.control("mode:stopwatch") },
            submenu("Countdown: \(countdown(o.timerSeconds))", Durations.timerPresets.map { m in
                MenuAction("\(m) min", checked: o.mode == .timer && o.timerSeconds == Double(m * 60)) { [weak self] in self?.control("timer:\(m)") }
            } + [MenuAction("Custom…") { [weak self] in
                guard let self, let t = self.askLength("Timer", hint: "Minutes (10), m:ss (1:30) or h:mm:ss (1:15:00), up to 24 hours. Or scroll over the time.",
                                                       current: countdown(self.o.timerSeconds)) else { return }
                self.control("timer:\(t)")
            }]),
            .separator(),
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

    // MARK: focus mode

    /// The 3x traveler, rasterised once per character the first time focus mode needs it.
    var focusSprite: SpriteSheet? {
        if let s = focusSprites[o.character] { return s }
        guard let url = spriteURLs[o.character], let s = try? SpriteSheet(url: url, scale: FocusLayout.travelerScale) else { return sprites[o.character] }
        focusSprites[o.character] = s
        return s
    }

    /// Opens focus mode full screen on the remembered display (else the one you work on),
    /// or moves it to the display named `name`.
    func openFocusMode(on name: String? = nil) {
        let screens = NSScreen.screens
        guard let screen = screens.first(where: { $0.localizedName == (name ?? o.focusDisplay) }) ?? activeScreen ?? screens.first else { return }
        if let f = focusOverlay {
            if name == nil || f.screen == screen {
                NSApp.activate(ignoringOtherApps: true)
                f.window.makeKeyAndOrderFront(nil)
                return
            }
            closeFocusMode()
        }
        o.focusDisplay = screen.localizedName
        remember("focusDisplay", o.focusDisplay)
        cancelEpisodes()
        let f = Overlay(focusOn: screen, excludeFromCapture: o.excludeFromCapture, frame: o.focusFrame)
        focusOverlay = f
        f.log = { [weak self] in self?.log($0) }
        f.sceneProvider = { [weak self, weak f] in f.flatMap { self?.scene(for: $0) } ?? Scene() }
        f.window.delegate = self
        if let v = f.focusView {
            if let sp = focusSprite { v.spriteHeight = CGFloat(sp.height) * sp.unitPoints(backing: screen.backingScaleFactor) }
            v.onAction = { [weak self] in self?.focusAction($0) }
            v.onResize = { [weak self] in self?.refresh() }
            v.onScroll = { [weak self] in self?.scrolled($0) }
            v.onAdjust = { [weak self] in self?.adjust(notches: $0, $1) }
        }
        if o.background == "cycle" { backgroundIndex += 1 }
        applyBackground()
        NSApp.activate(ignoringOtherApps: true)
        f.window.makeKeyAndOrderFront(nil)
        f.place()   // full screen goes to the display the window is on
        if let s = f.window.screen { f.move(to: s) }
        f.window.makeFirstResponder(f.focusView)
        if o.focusFrame == nil { f.window.toggleFullScreen(nil) }
        log("focus mode: open on \(screen.localizedName) window=\(f.window.windowNumber) frame=\(f.window.frame) now on \(f.window.screen?.localizedName ?? "-")")
        refresh()
        planEpisodes()
    }

    func closeFocusMode() {
        guard let f = focusOverlay else { return }
        cancelEpisodes()
        focusOverlay = nil
        f.close()
        log("focus mode: closed")
        refresh()
        planEpisodes()
    }

    func toggleFocusMode() { focusOverlay == nil ? openFocusMode() : closeFocusMode() }

    /// Space, S, Esc and the buttons in the focus window.
    func focusAction(_ a: String) {
        switch a {
        case "toggle": phase == .idle ? start() : pausedAt == nil ? pause() : resume()
        case "skip": if phase != .idle, o.mode == .pomodoro { control("skip") }
        default: closeFocusMode()
        }
    }

    /// The big countdown, caption and buttons; ticks with the menu-bar text.
    func updateFocus() {
        guard let v = focusOverlay?.focusView else { return }
        let paused = pausedAt != nil
        let caption: String
        switch (phase, o.mode) {
        case (.idle, .pomodoro): caption = "Space to start a \(Int(o.focusMinutes))-minute focus"
        case (.idle, .timer): caption = "Space to start · scroll to set"
        case (.idle, .stopwatch): caption = "Space to start the stopwatch"
        case (_, .timer): caption = paused ? "Timer paused" : remaining <= 0 ? "Time's up · Ithaca!" : "Timer · sailing home to Ithaca"
        case (_, .stopwatch): caption = paused ? "Stopwatch paused" : "Stopwatch · lap \(Int(elapsed / phaseDuration) + 1) round the edge"
        case (.focus, _): caption = paused ? "Focus paused" : lotus ? "Focus · the Lotus-eaters beckon" : "Focus · sailing home to Ithaca"
        case (.rest, _): caption = paused ? "Break paused" : restIsLong ? "Long break · Calypso's island" : "Break · home on Ithaca"
        }
        v.show(time: phase == .idle ? idleLength : o.mode == .stopwatch ? elapsedClock(elapsed * o.speed) : countdown(remaining * o.speed),
               caption: caption,
               primary: phase == .idle ? "Start (Space)" : paused ? "Resume (Space)" : "Pause (Space)",
               skip: phase == .idle || o.mode != .pomodoro ? nil : phase == .focus ? "Skip to break (S)" : "End break (S)",
               contentHidden: manualHidden || (o.hideWhenCaptured && detector.result.capturing))
    }

    // MARK: focus mode background

    /// Photos in the user's folder, else the ones that ship with the app (assets/backgrounds).
    func backgroundFiles() -> [URL] {
        let dirs = o.backgroundFolder.isEmpty ? resourceRoots.map { $0.appendingPathComponent("backgrounds") }
                                              : [URL(fileURLWithPath: o.backgroundFolder)]
        for d in dirs {
            let files = ((try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? [])
                .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if !files.isEmpty { return files }
        }
        return []
    }

    /// "storm-over-the-sea.jpg" -> "Storm over the sea".
    static func photoTitle(_ u: URL) -> String {
        let t = u.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    func applyBackground() {
        guard let v = focusOverlay?.focusView else { return }
        let files = backgroundFiles()
        let pick = o.background == "off" || files.isEmpty ? nil
            : files.first { $0.lastPathComponent == o.background } ?? files[backgroundIndex % files.count]
        log("background: \(pick?.lastPathComponent ?? "none")")
        v.setBackdrop(pick, drift: o.backgroundDrift)
    }

    func chooseBackgroundFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.message = "Choose a folder of photos (JPEG, PNG or HEIC) for the focus mode background."
        NSApp.activate(ignoringOtherApps: true)
        guard p.runModal() == .OK, let url = p.url else { return }
        control("background-folder:\(url.path)")
    }

    func windowWillClose(_ n: Notification) {
        if (n.object as? NSWindow) === focusOverlay?.window { closeFocusMode() }
    }

    func windowDidChangeScreen(_ n: Notification) {
        guard let f = focusOverlay, (n.object as? NSWindow) === f.window, let s = f.window.screen else { return }
        f.move(to: s)
        refresh()
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
