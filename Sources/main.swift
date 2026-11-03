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
    var autoStartBreak = false      // start the break by itself when a focus ends (else wait at Ithaca)
    var autoRestMinutes = ArrivalWait.defaultMinutes   // waiting at Ithaca: the break starts by itself after this (0: never)
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
    var goalHours = 4.0             // daily focus goal in the history; 0: none
    var lang: String?               // --lang en|ko|ja|zh|auto|pseudo: this run only (the menu's choice is saved)

    /// Settings the menu changes are kept in UserDefaults; command-line flags override them
    /// for one run without being saved.
    static let saved: [String: Any] = ["style": "traveler", "display": "main", "thickness": 3.0, "onlyLast5": false,
                                       "agentEnabled": true, "lotusEnabled": true, "hideWhenCaptured": true,
                                       "showSeconds": true, "focusMinutes": 25.0, "restMinutes": 5.0, "longEvery": 4,
                                       "notifyAtEnd": true, "soundVolume": "low", "autoNextFocus": false, "autoStartBreak": false, "autoRestMinutes": ArrivalWait.defaultMinutes, "pace": "even",
                                       "focusDisplay": "", "mode": "pomodoro", "timerSeconds": 600.0,
                                       "focusBackground": "cycle", "backgroundFolder": "", "backgroundDrift": true, "dailyGoalHours": 4.0,
                                       "checkUpdates": true]   // "sound" unregistered: see init

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
        // 0.1 kept an on/off toggle; nothing saved at all means the default (the harp).
        sound = Chime.choice(d.string(forKey: "sound") ?? d.object(forKey: "soundAtEnd").map { _ in d.bool(forKey: "soundAtEnd") ? "on" : "off" })
        soundVolume = Chime.volume(d.string(forKey: "soundVolume"))
        autoNextFocus = d.bool(forKey: "autoNextFocus")
        autoStartBreak = d.bool(forKey: "autoStartBreak")
        autoRestMinutes = ArrivalWait.minutes(d.integer(forKey: "autoRestMinutes"))
        physicalPace = d.string(forKey: "pace") == "physical"
        focusDisplay = d.string(forKey: "focusDisplay") ?? ""
        mode = TimerMode.named(d.string(forKey: "mode"))
        timerSeconds = Durations.timerRange.contains(d.double(forKey: "timerSeconds")) ? d.double(forKey: "timerSeconds") : 600
        background = d.string(forKey: "focusBackground") ?? "cycle"
        backgroundFolder = d.string(forKey: "backgroundFolder") ?? ""
        backgroundDrift = d.bool(forKey: "backgroundDrift")
        goalHours = min(max(d.double(forKey: "dailyGoalHours"), 0), 16)
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
            case "--lang": lang = it.next()
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

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
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
    var arrivalHint: NSPopover?         // the one-time bubble under the arrival badge
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
    var detentHeld = 0                   // wheel notches the dial's current detent has held (Dial.wheel)
    var menuBarRing: String?             // the ring now drawn in the menu bar, to redraw only on change
    var appearanceWatch: NSKeyValueObservation?
    var lengthShownUntil = Date.distantPast   // idle: the menu bar shows the length just scrolled to
    var backgroundIndex = Int.random(in: 0..<1000)
    lazy var history = HistoryLog(url: o.stateDir.appendingPathComponent("history.jsonl"))
    var runStart: Date?                  // the focus, timer or stopwatch now running started then
    var runLabel: String?                // the user's one-line note for this (or the next) run
    var updateStatus: UpdateStatus?      // the update check this run: checking, up to date or failed

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
        // The palette has light and dark variants: recolour the edge and the menu bar when macOS switches.
        appearanceWatch = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in DispatchQueue.main.async { self?.refresh() } }
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
            self?.checkForUpdate()
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
        UNUserNotificationCenter.current().delegate = self
        registerArrivalActions()
        refresh()
        scheduleUpdateChecks()
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
        recordRun()   // a timer still showing 0:00
        runStart = Date()
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
        guard phase == .focus || phase == .rest, pausedAt == nil else { return }
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
        recordRun()
        clearArrivalNotice()
        phase = .idle
        pausedAt = nil
        lapStart = Date()                                   // agent laps restart from home
        lapFrozenAt = agentState == .working ? nil : lapStart
        phaseTimer?.invalidate(); last5Timer?.invalidate(); titleTimer?.invalidate()
        cancelEpisodes()
        refresh()
    }

    func startRest() {
        recordRun()
        clearArrivalNotice()
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
        let every: TimeInterval = o.showSeconds || o.speed > 1 || phase == .arrived ? 1 : 15   // the overtime shows seconds
        let t = Timer(timeInterval: every, repeats: true) { [weak self] _ in self?.updateTitle() }
        t.tolerance = every == 1 ? 0.05 : 5
        RunLoop.main.add(t, forMode: .common)   // .common: keeps ticking while the menu is open
        titleTimer = t
    }

    func timeUp() {
        switch o.mode.timeUp(in: phase, autoNext: o.autoNextFocus, autoRest: o.autoStartBreak) {
        case .arrive(let restNow): focusEnded(restNow: restNow)
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
        allOverlays.forEach { $0.celebrate() }
        chime(focusEnded: true)
        notify(timerDoneMessage(seconds: Int(phaseDuration * o.speed)))
        let ended = phaseStart
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in   // a new start in between wins
            guard let self, self.phaseStart == ended, self.phase == .focus else { return }
            self.stop()
        }
    }

    // MARK: history

    /// Keeps the run that is ending in the local history: a focus, timer or stopwatch, finished
    /// or stopped early. Under a minute and unfinished, it was a false start and is left out.
    func recordRun() {
        guard phase == .focus, let start = runStart else { return }
        runStart = nil
        defer { runLabel = nil }
        let finished = o.mode != .stopwatch && remaining <= 0.5
        guard let v = currentRun(from: start, finished: finished), finished || v.seconds >= 60 else { return }
        history.append(v)
        log("history: \(v.mode) \(Int(v.seconds))s completed=\(v.completed)")
    }

    /// The run in progress as a history record (nominal seconds, even at demo speed).
    func currentRun(from start: Date? = nil, finished: Bool = false) -> Voyage? {
        guard phase == .focus, let s = start ?? runStart else { return nil }
        let secs = (o.mode == .stopwatch ? elapsed : min(elapsed, phaseDuration)) * o.speed
        return Voyage(start: s, end: Date(), mode: o.mode == .pomodoro ? "focus" : o.mode.rawValue, seconds: secs,
                      completed: finished || o.mode == .stopwatch, label: runLabel)
    }

    /// Today so far, the run in progress included.
    var today: DaySummary {
        let dayStart = Calendar.current.startOfDay(for: Date())   // ticks every second: skip older runs cheaply
        let recent = history.records.filter { $0.end > dayStart } + (currentRun().map { [$0] } ?? [])
        return History.summary(recent, on: dayStart, calendar: .current)
    }

    /// "Today 2h 15m · 4 sessions · longest 50m · 27 leagues · 56% of 4h"; `short` leaves out the
    /// sessions and the longest run.
    func todayLine(short: Bool = false) -> String {
        let t = today, n = t.sessions, longest = History.span(t.longest), lg = History.leagues(t.seconds)
        var parts = [L.t("Today \(History.span(t.seconds))", "오늘 \(History.span(t.seconds))", "今日 \(History.span(t.seconds))", "今天 \(History.span(t.seconds))"),
                     L.t("\(lg) leagues", "\(lg)리그", "\(lg) リーグ", "\(lg) 里格")]
        if !short {
            parts.insert(contentsOf: [L.t(n == 1 ? "1 session" : "\(n) sessions", "\(n)회", "\(n)回", "\(n) 次"),
                                      L.t("longest \(longest)", "최장 \(longest)", "最長 \(longest)", "最长 \(longest)")], at: 1)
        }
        if o.goalHours > 0 {
            let pct = Int(t.seconds / (o.goalHours * 36)), h = Int(o.goalHours)
            parts.append(L.t("\(pct)% of \(h)h", "\(h)시간의 \(pct)%", "\(h)時間の \(pct)%", "\(h) 小时的 \(pct)%"))
        }
        return parts.joined(separator: " · ")
    }

    func askLabel() {
        guard let t = ask(phase == .focus ? L.t("Label this session", "이 세션의 이름", "このセッションのラベル", "本次的标签")
                                          : L.t("Label the next session", "다음 세션의 이름", "次のセッションのラベル", "下一次的标签"),
                          hint: L.t("One line, kept in your history on this Mac (empty clears it).",
                                    "한 줄로, 이 Mac의 기록에 남아요(비우면 지워져요).",
                                    "1行で。この Mac の記録に残ります（空にすると消えます）。",
                                    "一行文字，保存在这台 Mac 的记录里（留空即清除）。"),
                          current: runLabel ?? "", wide: true) else { return }
        let line = t.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        runLabel = line.isEmpty ? nil : String(line.prefix(120))
    }

    let historyWindow = PanelWindow()

    func showHistory() {
        let cal = Calendar.current, now = Date()
        let recs = history.records + (currentRun().map { [$0] } ?? [])
        historyWindow.show(title: historyTitle, HistoryView(
            today: today, goalHours: o.goalHours,
            week: History.days(recs, endingOn: now, count: 7, calendar: cal),
            month: History.days(recs, endingOn: now, count: 30, calendar: cal),
            recent: Array(history.records.suffix(8).reversed()),
            setGoal: { [weak self] in self?.control("goal:\($0)") },
            export: { [weak self] in self?.exportHistory() },
            clear: { [weak self] in self?.clearHistory() }))
    }

    func exportHistory() {
        let p = NSSavePanel()
        let day = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        p.nameFieldStringValue = "edge-odyssey-history-\(day).csv"
        p.allowedContentTypes = [.commaSeparatedText]
        NSApp.activate(ignoringOtherApps: true)
        guard p.runModal() == .OK, let url = p.url else { return }
        do { try History.csv(history.records, timeZone: .current).write(to: url, atomically: true, encoding: .utf8) }
        catch { log("export: \(error)") }
    }

    func clearHistory() {
        let a = NSAlert()
        let n = history.records.count
        a.messageText = L.t("Clear your focus history?", "집중 기록을 지울까요?", "集中の記録を消去しますか？", "清除你的专注记录？")
        a.informativeText = L.t("All \(n) recorded sessions are deleted from this Mac. This can't be undone. (The logbook of the Odyssey is kept.)",
                                "기록된 세션 \(n)개가 모두 이 Mac에서 지워져요. 되돌릴 수 없어요. (오디세이아 항해 일지는 남아요.)",
                                "記録された \(n) 件のセッションがすべてこの Mac から削除されます。元に戻せません。（オデュッセイアの航海日誌は残ります。）",
                                "将从这台 Mac 删除全部 \(n) 条记录，且无法撤销。（奥德赛航海日志会保留。）")
        a.addButton(withTitle: L.t("Clear History", "기록 지우기", "記録を消去", "清除记录"))
        a.addButton(withTitle: L.t("Cancel", "취소", "キャンセル", "取消"))
        a.buttons[0].hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        control("clear-history")
    }

    /// Time is up: he reaches Ithaca (or Calypso's island), a gold wave runs twice round the edge,
    /// the harp plays and a notification comes. Then he waits there, the menu bar counting the
    /// time since, until the user starts the break or sails on (or the break starts by itself).
    func focusEnded(restNow: Bool) {
        restIsLong = Durations.isLongBreak(afterFocus: focusCount, every: o.longEvery)
        log("focus ended: \(restIsLong ? "Calypso" : "Ithaca"), restNow=\(restNow) notify=\(o.notifyAtEnd) sound=\(o.sound)")
        if restNow { startRest() } else { arrive() }
        allOverlays.forEach { $0.celebrate() }
        chime(focusEnded: true)
        notify(endMessage(focusEnded: true, longBreak: restIsLong, breakMinutes: Int(breakMinutes), waits: !restNow,
                          autoRestMinutes: o.autoRestMinutes), actions: !restNow)
    }

    /// Home at Ithaca, waiting for the user: nothing runs out, only the overtime counts up.
    func arrive() {
        recordRun()   // the focus is finished: kept now, not when the user gets round to the break
        cancelEpisodes()
        phaseTimer?.invalidate(); last5Timer?.invalidate()
        phase = .arrived
        phaseStart = Date()   // `elapsed` is now the time since arrival
        pausedAt = nil
        pausedTotal = 0
        let end = ArrivalWait.end(autoRestMinutes: o.autoRestMinutes)   // so the overtime never runs forever
        phaseTimer = Timer.scheduledTimer(withTimeInterval: end.seconds / o.speed, repeats: false) { [weak self] _ in
            guard let self, self.phase == .arrived else { return }
            self.log("arrival: nobody answered, \(end.then == .rest ? "break" : "idle")")
            end.then == .rest ? self.confirmArrival(.rest) : self.stop()
        }
        scheduleTitleTimer()
        refresh()
        showArrivalHintOnce()
    }

    /// Seconds until the break starts by itself, while waiting at Ithaca; nil when it never does.
    var autoRestLeft: Double? {
        guard phase == .arrived, o.autoRestMinutes > 0 else { return nil }
        return max(ArrivalWait.end(autoRestMinutes: o.autoRestMinutes).seconds - elapsed * o.speed, 0)
    }

    /// The first arrival ever: a bubble under the badge says what it is and how to move on.
    func showArrivalHintOnce() {
        guard !UserDefaults.standard.bool(forKey: "arrivalHintShown"), let b = statusItem?.button, b.window != nil else { return }
        UserDefaults.standard.set(true, forKey: "arrivalHintShown")
        let text = NSTextField(wrappingLabelWithString: L.t(
            "Focus done! The badge counts the time since. Click it to start your break (the clock stops), sail on 5 more minutes, or finish.",
            "집중 완료! 배지는 끝난 뒤 지난 시간이에요. 클릭해서 휴식을 시작하면(타이머가 멈춰요), 5분 더 집중하거나 끝낼 수 있어요.",
            "集中完了！バッジは終わってからの時間です。クリックして休憩を始める（タイマーが止まります）、あと5分集中する、または終了できます。",
            "专注完成！徽章显示结束后过去的时间。点击它开始休息（计时停止）、再专注 5 分钟，或结束。"))
        text.font = Typography.font(.body)
        text.preferredMaxLayoutWidth = 260
        let pad: CGFloat = 14, size = text.fittingSize
        let v = NSView(frame: NSRect(x: 0, y: 0, width: size.width + 2 * pad, height: size.height + 2 * pad))
        text.frame = NSRect(x: pad, y: pad, width: size.width, height: size.height)
        v.addSubview(text)
        let vc = NSViewController()
        vc.view = v
        let p = NSPopover()
        p.behavior = .transient
        p.contentViewController = vc
        p.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        arrivalHint = p
    }

    /// At Ithaca: start the break, or five more minutes of focus (the same voyage, so the next
    /// long break comes no sooner).
    func confirmArrival(_ c: ArrivalChoice) {
        guard phase == .arrived else { return }
        log("arrival: \(c.rawValue) after \(Int(elapsed * o.speed))s")
        let next = c.next(breakMinutes: breakMinutes)
        guard next.phase == .focus else { startRest(); return }
        clearArrivalNotice()
        runStart = Date()
        phase = .focus
        phaseDuration = next.seconds / o.speed
        phaseStart = Date()
        pausedAt = nil
        pausedTotal = 0
        schedulePhaseTimers()
        refresh()
        planEpisodes()
    }

    /// The break is over: wait for a click (default) or start the next focus by itself.
    func breakEnded(startNext: Bool) {
        log("break ended: autoNextFocus=\(startNext)")
        chime(focusEnded: false)
        if !startNext { notify(endMessage(focusEnded: false, longBreak: false, breakMinutes: 0)) }
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

    /// The end-of-time notification, when the user wants it. `actions`: [Start break] [+5 min].
    func notify(_ m: (title: String, body: String), actions: Bool = false) {
        if o.notifyAtEnd { post(m, id: Self.endNotice, category: actions ? Self.arrivalCategory : nil, sound: Chime.notificationSounds(o.sound)) }
    }

    static let endNotice = "edge-odyssey-end"
    static let arrivalCategory = "edge-odyssey-arrival"

    /// Asks for permission the first time; if the user declines, nothing is shown. Time-sensitive,
    /// so it stays on screen longer; a Focus mode that doesn't allow it still holds it back.
    func post(_ m: (title: String, body: String), id: String, category: String? = nil, sound: Bool = false) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { self.log("notification: \(error)") }
            self.log("notification: granted=\(granted) \(m.title)")
            guard granted else { return }
            let c = UNMutableNotificationContent()
            c.title = m.title
            c.body = m.body
            c.interruptionLevel = .timeSensitive
            if sound { c.sound = .default }
            if let category { c.categoryIdentifier = category }
            center.add(UNNotificationRequest(identifier: id, content: c, trigger: nil)) { e in if let e { self.log("notification: \(e)") } }
        }
    }

    /// The arrival notification's buttons, in the current language (registered again on a change).
    func registerArrivalActions() {
        let rest = UNNotificationAction(identifier: ArrivalChoice.rest.rawValue, title: L.t("Start break", "휴식 시작", "休憩を始める", "开始休息"))
        let x = Int(ArrivalChoice.extraMinutes)
        let more = UNNotificationAction(identifier: ArrivalChoice.extend.rawValue, title: L.t("+\(x) min", "+\(x)분", "+\(x)分", "+\(x) 分钟"))
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Self.arrivalCategory, actions: [rest, more], intentIdentifiers: []),
        ])
    }

    /// Once the user has moved on, the arrival notification has nothing left to say.
    func clearArrivalNotice() {
        arrivalHint?.close()
        guard phase == .arrived else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.endNotice])
    }

    func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse, withCompletionHandler done: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let choice = ArrivalChoice(rawValue: r.actionIdentifier) { self?.confirmArrival(choice) }
            done()
        }
    }

    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound])   // shown even while one of our windows (focus mode) is in front
    }

    /// Asks for a custom length in whole minutes; nil when cancelled or out of range.
    func askMinutes(_ title: String, current: Double, range: ClosedRange<Double>) -> Double? {
        let lo = Int(range.lowerBound), hi = Int(range.upperBound)
        return ask(title, hint: L.t("Minutes, \(lo) to \(hi). Applies from the next session.", "\(lo)~\(hi)분. 다음 세션부터 적용돼요.",
                                    "\(lo)〜\(hi) 分。次のセッションから適用されます。", "\(lo) 到 \(hi) 分钟，从下一次开始生效。"),
                   current: String(Int(current))).flatMap { Durations.minutes($0, in: range) }
    }

    /// The typed text, or nil when cancelled.
    func ask(_ title: String, hint: String, current: String, wide: Bool = false) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = hint
        let field = NSTextField(string: current)
        field.frame = NSRect(x: 0, y: 0, width: current.count > 8 || wide ? 280 : 80, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: L.t("Set", "설정", "設定", "设定"))
        alert.addButton(withTitle: L.t("Cancel", "취소", "キャンセル", "取消"))
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
        var n = r.notches
        // Setting a length, the dial's detents hold the plain one-minute steps for a moment.
        if phase == .idle, n != 0, e.modifierFlags.isDisjoint(with: [.shift, .option]), let m = dialState?.left {
            (n, detentHeld) = Dial.wheel(from: m, notches: n, held: detentHeld)
        }
        adjust(notches: n, e.modifierFlags)
    }

    func adjust(notches: Int, _ flags: NSEvent.ModifierFlags) {
        guard notches != 0 else { return }
        let d = Double(notches) * TimeAdjust.step(shift: flags.contains(.shift), option: flags.contains(.option))
        let before = dialState?.left
        adjust(by: d)
        if let v = focusOverlay?.focusView, let a = dialState?.left, let b = before, abs(a - b) > 0.01 {   // "+1m" by the boat
            v.dial.nudge((d > 0 ? "+" : "\u{2212}") + minutesLeft(abs(d)))
        }
    }

    /// A click or drag on the dial: the time it shows becomes `minutes`.
    func setDial(_ minutes: Double) {
        guard let ds = dialState, ds.settable else { return }
        detentHeld = 0
        let delta = (minutes - ds.left) * 60
        if abs(delta) >= 1 { adjust(by: delta) }
    }

    /// The dial's reading: idle, the next length; running, what is left; nil for the stopwatch.
    var dialState: DialView.State? {
        guard o.mode != .stopwatch else { return nil }
        switch phase {
        case .idle:
            let m = o.mode == .timer ? o.timerSeconds / 60 : o.focusMinutes
            return .init(left: m, total: m, tone: .focus, settable: true)
        case .arrived: return .init(left: 0, total: phaseDuration * o.speed / 60, tone: .arrived, settable: false)
        case .focus, .rest:
            return .init(left: remaining * o.speed / 60, total: phaseDuration * o.speed / 60, tone: phase == .rest ? .rest : .focus, settable: true)
        }
    }

    /// Idle: the length of the next session (saved). Running: this session only, by moving what
    /// is left. The stopwatch has nothing to set.
    func adjust(by delta: Double) {
        let before = dialState?.left
        defer {   // a detent you can feel, on a Force Touch trackpad
            if let a = dialState?.left, let b = before, abs(a - b) > 0.001, Dial.isDetent(a) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
        switch (phase, o.mode) {
        case (_, .stopwatch), (.arrived, _): return
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
        defer { if settingsWindow.isOpen { LanguageWatch.shared.changed() } }   // the Settings window shows the new value
        let parts = cmd.split(separator: ":", maxSplits: 1).map(String.init)
        let arg = parts.count > 1 ? parts[1] : ""
        switch parts[0] {
        case "start": start()
        case "pause": pause()
        case "resume": resume()
        case "stop": stop()
        case "skip": (phase == .focus && o.mode == .pomodoro) || phase == .arrived ? startRest() : stop()
        case "rest" where arg.isEmpty: confirmArrival(.rest)   // "rest:10" (a break length) is below
        case "extend": confirmArrival(.extend)
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
        case "autorest-after": if let n = Int(arg) { o.autoRestMinutes = ArrivalWait.minutes(n); remember("autoRestMinutes", o.autoRestMinutes) }
        case "autonext": o.autoNextFocus = arg == "on"; remember("autoNextFocus", o.autoNextFocus)
        case "autorest": o.autoStartBreak = arg == "on"; remember("autoStartBreak", o.autoStartBreak)
        case "share-hide": o.hideWhenCaptured = arg != "off"; remember("hideWhenCaptured", o.hideWhenCaptured); refresh()
        case "hide": manualHidden = true; refresh()
        case "show": manualHidden = false; refresh()
        case "display": o.display = arg; remember("display", arg); refresh(); planEpisodes()
        case "lotus": lotus = arg == "on"; if lotus { logbook.record(.lotus) }; refresh()
        case "logbook": showLogbook()
        case "welcome": showWelcome()
        case "settings": showSettings()
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
        case "adjust": if let d = Double(arg) { adjust(by: d) }
        case "label": runLabel = arg.isEmpty ? nil : String(arg.prefix(120))
        case "goal": if let h = Double(arg), (0...16).contains(h) { o.goalHours = h; remember("dailyGoalHours", h); refresh() }
        case "history": showHistory()
        case "clear-history": history.clear(); refresh(); if historyWindow.isOpen { showHistory() }   // scripting/demo: seconds, e.g. adjust:60
        case "background": o.background = arg; remember("focusBackground", arg); applyBackground()
        case "background-folder": o.backgroundFolder = arg; remember("backgroundFolder", arg); applyBackground()
        case "drift": o.backgroundDrift = arg != "off"; remember("backgroundDrift", o.backgroundDrift); applyBackground()
        case "language": setLanguage(arg)
        case "updates": UserDefaults.standard.set(arg != "off", forKey: "checkUpdates"); if arg != "off" { checkForUpdate() }
        case "update-check": checkForUpdate(asked: true)
        case "skip-update": if let v = updateOffer { UserDefaults.standard.set(v.description, forKey: "update.skipped") }
        case "release-page": if let v = updateOffer { NSWorkspace.shared.open(Update.page(v)) }
        case "quit": NSApp.terminate(nil)
        default: log("unknown ctl \(cmd)")
        }
    }

    // MARK: status item

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: "Edge Odyssey")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = Typography.font(.menuBar)   // monospaced digits: 12:50 -> 12:49 without the icon wobbling
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func updateTitle() {
        updateFocus()
        guard let b = statusItem?.button else { return }
        let tip = phase == .arrived ? L.t("Focus done: time since. Click to start your break.", "집중 완료 후 지난 시간이에요. 클릭해서 휴식을 시작하세요.",
                                          "集中が終わってからの時間です。クリックして休憩を始めましょう。", "专注结束后过去的时间。点击开始休息。") : nil
        if b.toolTip != tip { b.toolTip = tip }
        if phase == .idle {
            b.title = lengthShownUntil > Date() ? " " + idleLength : ""
            b.image = NSImage(systemSymbolName: agentState == .waiting ? "circle.circle.fill" : "circle.dashed", accessibilityDescription: "Edge Odyssey")
            titleSymbol = nil
            menuBarRing = nil
            return
        }
        if phase == .arrived {   // a gold badge, redrawn once a second: "⚓ Arrived +0:42"
            let text = L.t("Arrived", "도착", "到着", "已到达") + " " + overtime(elapsed * o.speed)
            if b.title != "" { b.title = "" }
            b.image = arrivalBadge(text)
            b.setAccessibilityLabel(header)
            titleSymbol = "arrived"
            menuBarRing = nil
            if let h = headerItem, h.title != header { h.title = header }
            return
        }
        // A progress ring: a focus fills it (coral in the last five minutes), a break empties it.
        let ring = Dial.ring(phase, left: remaining * o.speed, total: phaseDuration * o.speed) ?? (0, .focus)
        let key = "\(ring.tone)-\(Int(ring.fill * 64))-\(Palette.dark)"
        if key != menuBarRing {   // redrawn only when it visibly changes
            b.image = DialView.ringIcon(ring.fill, ring.tone)
            menuBarRing = key
            titleSymbol = nil
        }
        let late = ring.tone == .warm && pausedAt == nil
        let font = Typography.font(.menuBar, weight: late ? .semibold : nil)
        if b.font != font { b.font = font }
        let title = " " + (pausedAt != nil ? L.t("paused", "일시정지", "一時停止", "暂停") : left)
        if b.title != title { b.title = title }
        if let h = headerItem, h.title != header { h.title = header }
    }

    /// The menu-bar badge while a finished focus waits: bright brass with navy ink, so it reads on a
    /// light or a dark menu bar (gold text alone would not). The anchor comes from Apple Symbols:
    /// a plain glyph, not the colour emoji.
    func arrivalBadge(_ text: String) -> NSImage {
        let ink = Palette.color(Tones.badgeInk), h: CGFloat = 18
        let s = NSMutableAttributedString(string: "\u{2693}\u{FE0E} ", attributes: [.font: NSFont(name: "Apple Symbols", size: 15) ?? Typography.font(.badge),
                                                                                 .foregroundColor: ink, .baselineOffset: -1])
        s.append(Typography.string(text, .badge, color: ink))
        let ts = s.size()
        return NSImage(size: NSSize(width: ceil(ts.width) + 14, height: h), flipped: false) { r in
            Palette.color(Tones.badge).setFill()
            NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2).fill()
            s.draw(at: NSPoint(x: 7, y: ((h - ts.height) / 2).rounded()))
            return true
        }
    }

    /// Time left in the user's chosen style, nominal even at demo speed.
    var left: String {
        if o.mode == .stopwatch { let e = elapsed * o.speed; return o.showSeconds ? elapsedClock(e) : History.span(e) }
        return o.showSeconds ? countdown(remaining * o.speed) : minutesLeft(remaining * o.speed)
    }

    var header: String {
        let paused = pausedAt != nil
        let t = left, n = idleLength
        switch (phase, o.mode) {
        case (.idle, .pomodoro): return L.t("Ready", "준비", "準備完了", "就绪")
        case (.idle, .timer): return L.t("Timer: \(n)", "타이머: \(n)", "タイマー：\(n)", "计时器：\(n)")
        case (.idle, .stopwatch): return L.t("Stopwatch: ready", "스톱워치: 준비", "ストップウォッチ：準備完了", "秒表：就绪")
        case (.arrived, _):
            let o = overtime(elapsed * self.o.speed)
            guard let a = autoRestLeft.map(countdown) else { return L.t("Arrived \(o)", "도착 \(o)", "到着 \(o)", "已到达 \(o)") }
            return L.t("Arrived \(o) · break starts by itself in \(a)", "도착 \(o) · \(a) 뒤 휴식 자동 시작",
                       "到着 \(o) · \(a) 後に休憩が自動で始まります", "已到达 \(o) · \(a) 后自动开始休息")
        case (_, .timer): return paused ? L.t("Timer paused: \(t) left", "타이머 일시정지: \(t) 남음", "タイマー一時停止：残り \(t)", "计时器已暂停：剩余 \(t)")
                                        : L.t("Timer: \(t) left", "타이머: \(t) 남음", "タイマー：残り \(t)", "计时器：剩余 \(t)")
        case (_, .stopwatch): return paused ? L.t("Stopwatch paused: \(t)", "스톱워치 일시정지: \(t)", "ストップウォッチ一時停止：\(t)", "秒表已暂停：\(t)")
                                            : L.t("Stopwatch: \(t)", "스톱워치: \(t)", "ストップウォッチ：\(t)", "秒表：\(t)")
        case (.focus, _): return paused ? L.t("Focus paused: \(t) left", "집중 일시정지: \(t) 남음", "集中一時停止：残り \(t)", "专注已暂停：剩余 \(t)")
                                        : L.t("Focus: \(t) left", "집중: \(t) 남음", "集中：残り \(t)", "专注：剩余 \(t)")
        case (.rest, _): return paused ? L.t("Break paused: \(t) left", "휴식 일시정지: \(t) 남음", "休憩一時停止：残り \(t)", "休息已暂停：剩余 \(t)")
                                       : L.t("Break: \(t) left", "휴식: \(t) 남음", "休憩：残り \(t)", "休息：剩余 \(t)")
        }
    }

    /// Waiting at Ithaca: one line on what happened, then the three ways on, in large type.
    func arrivalMenuItems() -> [NSMenuItem] {
        let m = Int((phaseDuration * o.speed / 60).rounded()), b = Int(breakMinutes), x = Int(ArrivalChoice.extraMinutes)
        let what = NSMenuItem(title: restIsLong
            ? L.t("Calypso's island! \(m)-min focus done — start the break to stop the clock", "칼립소의 섬 도착! 집중 \(m)분 완료 — 휴식을 시작하면 타이머가 멈춰요",
                  "カリュプソの島に到着！\(m)分の集中完了 — 休憩を始めるとタイマーが止まります", "到达卡吕普索之岛！专注 \(m) 分钟完成 — 开始休息，计时就会停止")
            : L.t("Ithaca! \(m)-min focus done — start the break to stop the clock", "이타카 도착! 집중 \(m)분 완료 — 휴식을 시작하면 타이머가 멈춰요",
                  "イタケに到着！\(m)分の集中完了 — 休憩を始めるとタイマーが止まります", "到达伊萨卡！专注 \(m) 分钟完成 — 开始休息，计时就会停止"),
            action: nil, keyEquivalent: "")
        what.isEnabled = false
        let rest = MenuAction(L.t("☕ Start break (\(b) min)", "☕ 휴식 시작 (\(b)분)", "☕ 休憩を始める（\(b)分）", "☕ 开始休息（\(b) 分钟）"), key: "s") { [weak self] in
            self?.control("rest")
        }
        let more = MenuAction(L.t("+\(x) min more focus", "+\(x)분 더 집중", "+\(x)分 集中を続ける", "再专注 +\(x) 分钟")) { [weak self] in self?.control("extend") }
        let end = MenuAction(L.t("Finish", "끝내기", "終了する", "结束")) { [weak self] in self?.stop() }
        for (item, weight) in [(rest, NSFont.Weight.semibold), (more, .regular), (end, .regular)] {
            item.attributedTitle = NSAttributedString(string: item.title, attributes: [.font: NSFont.systemFont(ofSize: 15, weight: weight)])
        }
        return [what, rest, more, end, .separator()]
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if phase == .arrived { arrivalMenuItems().forEach(menu.addItem) }   // first: what happened and the way out
        updateMenuItems().forEach(menu.addItem)
        let h = NSMenuItem(title: header, action: nil, keyEquivalent: "")
        h.isEnabled = false
        menu.addItem(h)
        headerItem = h
        let td = NSMenuItem(title: todayLine(), action: nil, keyEquivalent: "")
        td.isEnabled = false
        menu.addItem(td)
        if phase == .idle {
            let title: String
            switch o.mode {
            case .pomodoro:
                let m = Int(o.focusMinutes)
                title = L.t("Start focus (\(m) min)", "집중 시작 (\(m)분)", "集中を開始（\(m)分）", "开始专注（\(m) 分钟）")
            case .timer:
                let n = idleLength
                title = L.t("Start timer (\(n))", "타이머 시작 (\(n))", "タイマーを開始（\(n)）", "开始计时（\(n)）")
            case .stopwatch: title = L.t("Start stopwatch", "스톱워치 시작", "ストップウォッチを開始", "开始秒表")
            }
            menu.addItem(MenuAction(title, key: "s") { [weak self] in self?.start() })
        } else if phase == .arrived {
            // its actions lead the menu (arrivalMenuItems)
        } else {
            if pausedAt == nil { menu.addItem(MenuAction(L.t("Pause", "일시정지", "一時停止", "暂停")) { [weak self] in self?.pause() }) }
            else { menu.addItem(MenuAction(L.t("Resume", "재개", "再開", "继续")) { [weak self] in self?.resume() }) }
            if o.mode == .pomodoro {
                menu.addItem(MenuAction(phase == .focus ? L.t("Skip to break", "휴식으로 건너뛰기", "休憩へスキップ", "跳到休息")
                                                        : L.t("End break", "휴식 끝내기", "休憩を終える", "结束休息")) { [weak self] in self?.control("skip") })
            }
            menu.addItem(MenuAction(L.t("Stop", "정지", "停止", "停止")) { [weak self] in self?.stop() })
        }
        let labelTitle = runLabel.map { l in L.t("Label: \(l)…", "이름: \(l)…", "ラベル：\(l)…", "标签：\(l)…") }
            ?? (phase == .focus ? L.t("Label this session…", "이 세션에 이름 붙이기…", "このセッションにラベルを付ける…", "为本次添加标签…")
                                : L.t("Label the next session…", "다음 세션에 이름 붙이기…", "次のセッションにラベルを付ける…", "为下一次添加标签…"))
        menu.addItem(MenuAction(labelTitle) { [weak self] in self?.askLabel() })
        let fm = MenuAction(focusOverlay == nil ? L.t("Focus mode", "집중 모드", "集中モード", "专注模式")
                                                : L.t("Close focus mode", "집중 모드 닫기", "集中モードを閉じる", "关闭专注模式")) { [weak self] in self?.toggleFocusMode() }
        fm.keyEquivalent = "f"
        fm.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(fm)
        menu.addItem(.separator())
        menu.addItem(MenuAction(L.t("Settings…", "설정…", "設定…", "设置…"), key: ",") { [weak self] in self?.showSettings() })

        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let m = NSMenu()
            items.forEach(m.addItem)
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = m
            return item
        }
        menu.addItem(submenu(L.t("Mode", "모드", "モード", "模式"), [
            MenuAction(L.t("Odysseus voyage (border + traveler)", "오디세우스 항해 (테두리 + 여행자)", "オデュッセウスの航海（枠＋旅人）", "奥德修斯航行（边框＋旅人）"),
                       checked: o.style == .traveler) { [weak self] in self?.control("style:traveler") },
            MenuAction(L.t("Thin border only", "얇은 테두리만", "細い枠だけ", "只显示细边框"), checked: o.style == .border) { [weak self] in self?.control("style:border") },
            .separator(),
            MenuAction(L.t("Speed: Even (halfway round = halfway through)", "속도: 고르게 (반 바퀴 = 절반 지남)", "速さ：一定（半周＝半分経過）", "速度：匀速（走到一半＝过了一半）"),
                       checked: !o.physicalPace) { [weak self] in self?.control("pace:even") },
            MenuAction(L.t("Speed: Physical (slow climb, fast slide)", "속도: 물리적 (오르막은 느리게, 미끄럼은 빠르게)", "速さ：物理的（登りはゆっくり、滑りは速く）", "速度：物理（攀爬慢，滑下快）"),
                       checked: o.physicalPace) { [weak self] in self?.control("pace:physical") },
        ]))
        var displays: [NSMenuItem] = [
            MenuAction(L.t("Main display", "주 모니터", "メインディスプレイ", "主显示器"), checked: o.display == "main") { [weak self] in self?.control("display:main") },
            MenuAction(L.t("All displays (Odysseus follows you)", "모든 모니터 (오디세우스가 따라와요)", "すべてのディスプレイ（オデュッセウスがついてくる）", "所有显示器（奥德修斯跟着你）"),
                       checked: o.display == "all") { [weak self] in self?.control("display:all") },
            MenuAction(L.t("Follow me (the display I'm working on)", "나를 따라 (작업 중인 모니터)", "自分についてくる（作業中のディスプレイ）", "跟随我（正在使用的显示器）"),
                       checked: o.display == "follow") { [weak self] in self?.control("display:follow") },
            .separator(),
        ]
        for (i, scr) in NSScreen.screens.enumerated() {
            let size = "\(Int(scr.frame.width))x\(Int(scr.frame.height))\(scr.backingScaleFactor > 1 ? " Retina" : "")"
            let name = scr.localizedName   // saved by name: indices shift when displays come and go
            displays.append(MenuAction("\(name) (\(size))", checked: o.display == name || o.display == String(i)) { [weak self] in
                self?.control("display:\(name)")
            })
        }
        menu.addItem(submenu(L.t("Show on", "표시할 곳", "表示先", "显示在"), displays))
        if NSScreen.screens.count > 1 {
            menu.addItem(submenu(L.t("Focus mode on", "집중 모드를 열 곳", "集中モードの表示先", "专注模式显示在"), NSScreen.screens.map { scr in
                let name = scr.localizedName
                return MenuAction(name, checked: o.focusDisplay == name) { [weak self] in self?.control("focus-display:\(name)") }
            }))
        }
        var backgrounds: [NSMenuItem] = [
            MenuAction(L.t("Off", "끔", "オフ", "关闭"), checked: o.background == "off") { [weak self] in self?.control("background:off") },
            MenuAction(L.t("A different photo each session", "세션마다 다른 사진", "セッションごとに別の写真", "每次换一张照片"),
                       checked: o.background == "cycle") { [weak self] in self?.control("background:cycle") },
        ]
        let files = backgroundFiles()
        if !files.isEmpty { backgrounds.append(.separator()) }
        for f in files {
            let name = f.lastPathComponent
            backgrounds.append(MenuAction(photoTitle(f), checked: o.background == name) { [weak self] in self?.control("background:\(name)") })
        }
        backgrounds.append(.separator())
        let folder = o.backgroundFolder.isEmpty ? nil : URL(fileURLWithPath: o.backgroundFolder).lastPathComponent
        let folderTitle = folder.map { f in L.t("My folder: \(f)…", "내 폴더: \(f)…", "自分のフォルダ：\(f)…", "我的文件夹：\(f)…") }
            ?? L.t("Use my own folder…", "내 폴더 사용…", "自分のフォルダを使う…", "使用我自己的文件夹…")
        backgrounds.append(MenuAction(folderTitle, checked: folder != nil) { [weak self] in self?.chooseBackgroundFolder() })
        if folder != nil {
            backgrounds.append(MenuAction(L.t("Use the photos that come with the app", "앱에 들어 있는 사진 사용", "アプリ付属の写真を使う", "使用应用自带的照片")) { [weak self] in
                self?.control("background-folder:")
            })
        }
        backgrounds.append(MenuAction(L.t("Slow drift", "천천히 움직이기", "ゆっくり動かす", "缓慢漂移"), checked: o.backgroundDrift) { [weak self] in
            guard let self else { return }
            self.control(self.o.backgroundDrift ? "drift:off" : "drift:on")
        })
        menu.addItem(submenu(L.t("Focus mode background", "집중 모드 배경", "集中モードの背景", "专注模式背景"), backgrounds))
        menu.addItem(submenu(L.t("Border", "테두리", "枠", "边框"), [2, 3, 4].map { t in
            MenuAction(t == 2 ? L.t("2 px (thinnest)", "2 px (가장 얇게)", "2 px（最も細い）", "2 像素（最细）") : "\(t) px",
                       checked: Int(o.thickness) == t) { [weak self] in self?.control("thickness:\(t)") }
        }))
        func mins(_ m: Int) -> String { L.t("\(m) min", "\(m)분", "\(m)分", "\(m) 分钟") }
        func choices(_ presets: [Int], current: Double, cmd: String, custom: @escaping () -> Void) -> [NSMenuItem] {
            var items: [NSMenuItem] = presets.map { m in
                MenuAction(mins(m), checked: Int(current) == m) { [weak self] in self?.control("\(cmd):\(m)") }
            }
            let isCustom = !presets.contains(Int(current)), m = mins(Int(current))
            items.append(MenuAction(isCustom ? L.t("Custom (\(m))…", "직접 입력 (\(m))…", "カスタム（\(m)）…", "自定义（\(m)）…")
                                             : L.t("Custom…", "직접 입력…", "カスタム…", "自定义…"), checked: isCustom, custom))
            return items
        }
        let long = Int(Durations.longBreakMinutes(rest: o.restMinutes))
        let cd = countdown(o.timerSeconds), fmin = mins(Int(o.focusMinutes)), bmin = mins(Int(o.restMinutes)), every = o.longEvery
        menu.addItem(submenu(L.t("Timer", "타이머", "タイマー", "计时"), [
            MenuAction(L.t("Pomodoro (focus, then a break)", "뽀모도로 (집중 후 휴식)", "ポモドーロ（集中のあと休憩）", "番茄钟（专注后休息）"),
                       checked: o.mode == .pomodoro) { [weak self] in self?.control("mode:pomodoro") },
            MenuAction(L.t("Countdown timer", "카운트다운 타이머", "カウントダウンタイマー", "倒计时"), checked: o.mode == .timer) { [weak self] in self?.control("mode:timer") },
            MenuAction(L.t("Stopwatch", "스톱워치", "ストップウォッチ", "秒表"), checked: o.mode == .stopwatch) { [weak self] in self?.control("mode:stopwatch") },
            submenu(L.t("Countdown: \(cd)", "카운트다운: \(cd)", "カウントダウン：\(cd)", "倒计时：\(cd)"), Durations.timerPresets.map { m in
                MenuAction(mins(m), checked: o.mode == .timer && o.timerSeconds == Double(m * 60)) { [weak self] in self?.control("timer:\(m)") }
            } + [MenuAction(L.t("Custom…", "직접 입력…", "カスタム…", "自定义…")) { [weak self] in
                guard let self, let t = self.ask(L.t("Timer length", "타이머 길이", "タイマーの長さ", "计时时长"),
                                                 hint: L.t("Minutes (10), m:ss (1:30) or h:mm:ss (1:15:00), up to 24 hours. Or scroll over the time.",
                                                           "분(10), 분:초(1:30) 또는 시:분:초(1:15:00), 24시간까지. 시간 위에서 스크롤해도 돼요.",
                                                           "分（10）、分:秒（1:30）または 時:分:秒（1:15:00）、24時間まで。時間の上でスクロールしても変えられます。",
                                                           "分钟（10）、分:秒（1:30）或 时:分:秒（1:15:00），最长 24 小时。也可以在时间上滚动。"),
                                                 current: countdown(self.o.timerSeconds)) else { return }
                self.control("timer:\(t)")
            }]),
            .separator(),
            submenu(L.t("Focus: \(fmin)", "집중: \(fmin)", "集中：\(fmin)", "专注：\(fmin)"), choices(Durations.focusPresets, current: o.focusMinutes, cmd: "focus") { [weak self] in
                guard let self, let m = self.askMinutes(L.t("Focus length", "집중 길이", "集中の長さ", "专注时长"), current: self.o.focusMinutes, range: Durations.focusRange) else { return }
                self.control("focus:\(Int(m))")
            }),
            submenu(L.t("Break: \(bmin)", "휴식: \(bmin)", "休憩：\(bmin)", "休息：\(bmin)"), choices(Durations.breakPresets, current: o.restMinutes, cmd: "rest") { [weak self] in
                guard let self, let m = self.askMinutes(L.t("Break length", "휴식 길이", "休憩の長さ", "休息时长"), current: self.o.restMinutes, range: Durations.breakRange) else { return }
                self.control("rest:\(Int(m))")
            }),
            submenu(L.t("Long break (\(long) min): every \(every) sessions", "긴 휴식 (\(long)분): \(every)회마다",
                        "長い休憩（\(long)分）：\(every)回ごと", "长休息（\(long) 分钟）：每 \(every) 次"), Durations.longEveryChoices.map { n in
                MenuAction(L.t("Every \(n) sessions", "\(n)회마다", "\(n)回ごと", "每 \(n) 次"), checked: o.longEvery == n) { [weak self] in self?.control("long-every:\(n)") }
            }),
            .separator(),
            MenuAction(L.t("Notify when time is up", "시간이 다 되면 알림", "時間になったら通知", "时间到时通知"), checked: o.notifyAtEnd) { [weak self] in
                guard let self else { return }
                self.control(self.o.notifyAtEnd ? "notify:off" : "notify:on")
            },
            submenu(L.t("Sound", "소리", "サウンド", "声音"), [
                MenuAction(L.t("Harp", "하프", "ハープ", "竖琴"), checked: o.sound == "harp") { [weak self] in self?.control("sound:harp") },
                MenuAction(L.t("Glass (system)", "유리 (시스템)", "ガラス（システム）", "玻璃（系统）"), checked: o.sound == "glass") { [weak self] in self?.control("sound:glass") },
                MenuAction(L.t("Off", "끔", "オフ", "关闭"), checked: o.sound == "off") { [weak self] in self?.control("sound:off") },
                .separator(),
                MenuAction(L.t("Volume: low", "음량: 작게", "音量：小", "音量：低"), checked: o.soundVolume == "low") { [weak self] in self?.control("volume:low") },
                MenuAction(L.t("Volume: medium", "음량: 보통", "音量：中", "音量：中"), checked: o.soundVolume == "medium") { [weak self] in self?.control("volume:medium") },
            ]),
            MenuAction(L.t("Start the break by itself when a focus ends", "집중이 끝나면 휴식 자동 시작", "集中が終わったら休憩を自動で始める", "专注结束后自动开始休息"),
                       checked: o.autoStartBreak) { [weak self] in
                guard let self else { return }
                self.control(self.o.autoStartBreak ? "autorest:off" : "autorest:on")
            },
            submenu(L.t("If I don't answer at Ithaca", "도착 후 확인이 없으면", "到着後に応答がなければ", "到达后没有回应时"),
                    ArrivalWait.choices.map { n in
                MenuAction(n == 0 ? L.t("Keep waiting (up to 60 min)", "계속 기다리기 (최대 60분)", "待ち続ける（最大60分）", "继续等待（最多 60 分钟）")
                                  : L.t("Start the break after \(n) min", "\(n)분 뒤 자동으로 휴식 시작", "\(n)分後に休憩を自動で始める", "\(n) 分钟后自动开始休息"),
                           checked: o.autoRestMinutes == n) { [weak self] in self?.control("autorest-after:\(n)") }
            }),
            MenuAction(L.t("Start the next focus after a break", "휴식이 끝나면 다음 집중 시작", "休憩のあと次の集中を始める", "休息后自动开始下一次专注"),
                       checked: o.autoNextFocus) { [weak self] in
                guard let self else { return }
                self.control(self.o.autoNextFocus ? "autonext:off" : "autonext:on")
            },
        ]))
        menu.addItem(MenuAction(L.t("Only show in the last 5 minutes", "마지막 5분에만 표시", "最後の5分だけ表示", "只在最后 5 分钟显示"), checked: o.onlyLast5) { [weak self] in
            guard let self else { return }
            self.control(self.o.onlyLast5 ? "last5:off" : "last5:on")
        })
        menu.addItem(.separator())
        let agentTitle: String
        switch agentState {
        case .idle: agentTitle = L.t("Claude Code: no active session", "Claude Code: 활성 세션 없음", "Claude Code：アクティブなセッションなし", "Claude Code：没有活动会话")
        case .working: agentTitle = L.t("Claude Code: working", "Claude Code: 작업 중", "Claude Code：作業中", "Claude Code：工作中")
        case .waiting: agentTitle = L.t("Claude Code: waiting for you", "Claude Code: 당신을 기다리는 중", "Claude Code：あなたを待っています", "Claude Code：在等你")
        case .limit: agentTitle = L.t("Claude Code: near usage limit", "Claude Code: 사용 한도 가까움", "Claude Code：使用上限が近い", "Claude Code：接近用量上限")
        }
        let ai = NSMenuItem(title: agentTitle, action: nil, keyEquivalent: "")
        ai.isEnabled = false
        menu.addItem(ai)
        menu.addItem(.separator())
        let todaySpan = History.span(today.seconds), books = logbook.found.count
        menu.addItem(MenuAction(L.t("History (today \(todaySpan))…", "기록 (오늘 \(todaySpan))…", "記録（今日 \(todaySpan)）…", "记录（今天 \(todaySpan)）…"), key: "y") { [weak self] in self?.showHistory() })
        menu.addItem(MenuAction(L.t("Logbook (\(books) of 24 books)…", "항해 일지 (24권 중 \(books)권)…", "航海日誌（24巻中 \(books) 巻）…", "航海日志（24 卷中 \(books) 卷）…"), key: "l") { [weak self] in
            self?.showLogbook()
        })
        let pref = UserDefaults.standard.string(forKey: "language") ?? "auto"
        let languages: [NSMenuItem] = [MenuAction(L.t("System", "시스템", "システム", "系统") + " (\(L.resolve("auto").name))", checked: pref == "auto") { [weak self] in
            self?.control("language:auto")
        }, .separator()] + Lang.allCases.map { l in
            MenuAction(l.name, checked: pref == l.rawValue) { [weak self] in self?.control("language:\(l.rawValue)") }
        }
        menu.addItem(submenu(L.t("General", "일반", "一般", "通用"), [
            submenu(L.t("Language", "언어", "言語", "语言"), languages),
            .separator(),
            MenuAction(L.t("Show Claude Code signals", "Claude Code 신호 표시", "Claude Code のシグナルを表示", "显示 Claude Code 信号"), checked: o.agentEnabled) { [weak self] in
                guard let self else { return }
                self.control(self.o.agentEnabled ? "agent:off" : "agent:on")
            },
            MenuAction(L.t("Doze while a game, video or social app is in front", "게임·동영상·SNS 앱이 앞에 있으면 졸기",
                           "ゲーム・動画・SNS アプリが前面にあるとき居眠りする", "游戏、视频或社交应用在前台时打瞌睡"), checked: o.lotusEnabled) { [weak self] in
                guard let self else { return }
                self.control(self.o.lotusEnabled ? "lotus-enabled:off" : "lotus-enabled:on")
            },
            MenuAction(L.t("Hide while the screen is shared or recorded", "화면 공유·녹화 중에는 숨기기", "画面の共有・録画中は隠す", "共享或录制屏幕时隐藏"), checked: o.hideWhenCaptured) { [weak self] in
                guard let self else { return }
                self.control(self.o.hideWhenCaptured ? "share-hide:off" : "share-hide:on")
            },
            MenuAction(L.t("Count down in seconds (12:50, not 13m)", "초 단위로 표시 (13분 대신 12:50)", "秒単位で表示（13分ではなく 12:50）", "按秒倒计时（12:50，而非 13 分）"), checked: o.showSeconds) { [weak self] in
                guard let self else { return }
                self.control(self.o.showSeconds ? "seconds:off" : "seconds:on")
            },
            .separator(),
        ] + updateSettingsItems() + [
            .separator(),
            MenuAction(L.t("Launch at login", "로그인할 때 실행", "ログイン時に起動", "登录时启动"), checked: LoginItem.isOn) { [weak self] in self?.toggleLoginItem() },
            MenuAction(L.t("Welcome guide…", "시작 안내…", "はじめにガイド…", "欢迎指南…")) { [weak self] in self?.showWelcome() },
        ]))
        let hide = MenuAction(manualHidden ? L.t("Show again", "다시 보이기", "再表示", "重新显示") : L.t("Hide now", "지금 숨기기", "今すぐ隠す", "立即隐藏")) { [weak self] in
            self?.toggleHidden()
        }
        hide.keyEquivalent = "h"
        hide.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(hide)
        menu.addItem(.separator())
        menu.addItem(MenuAction(L.t("Quit Edge Odyssey", "Edge Odyssey 종료", "Edge Odyssey を終了", "退出 Edge Odyssey"), key: "q") { NSApp.terminate(nil) })
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
            v.onPreset = { [weak self] in self?.pickPreset($0) }
            v.dial.onSet = { [weak self] in self?.setDial($0) }
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

    /// A preset chip under the dial: the next focus or timer length.
    func pickPreset(_ minutes: Double) {
        detentHeld = 0
        control(o.mode == .timer ? "timer:\(Int(minutes))" : "focus:\(Int(minutes))")
        refresh()
    }

    /// Space, S, Esc and the buttons in the focus window.
    func focusAction(_ a: String) {
        switch a {
        case "toggle": phase == .idle ? start() : phase == .arrived ? control("rest") : pausedAt == nil ? pause() : resume()
        case "skip": if phase == .arrived { control("extend") } else if phase != .idle, o.mode == .pomodoro { control("skip") }
        default: closeFocusMode()
        }
    }

    /// The big countdown, caption and buttons; ticks with the menu-bar text.
    func updateFocus() {
        guard let v = focusOverlay?.focusView else { return }
        let paused = pausedAt != nil
        let caption: String
        let homeward = L.t("sailing home to Ithaca", "이타카로 돌아가는 중", "イタケへ帰航中", "正驶向伊萨卡")
        switch (phase, o.mode) {
        case (.idle, .pomodoro):
            let m = Int(o.focusMinutes)
            caption = L.t("Space to start a \(m)-minute focus", "Space로 \(m)분 집중 시작", "Space で \(m) 分の集中を開始", "按空格开始 \(m) 分钟专注")
        case (.idle, .timer): caption = L.t("Space to start · scroll to set", "Space로 시작 · 스크롤로 설정", "Space で開始 · スクロールで設定", "按空格开始 · 滚动设定")
        case (.idle, .stopwatch): caption = L.t("Space to start the stopwatch", "Space로 스톱워치 시작", "Space でストップウォッチを開始", "按空格开始秒表")
        case (.arrived, _):
            caption = restIsLong ? L.t("Calypso's island! · voyage complete", "칼립소의 섬! · 항해 완료", "カリュプソの島！ · 航海完了", "卡吕普索之岛！ · 航行完成")
                                 : L.t("Ithaca! · voyage complete", "이타카! · 항해 완료", "イタケ！ · 航海完了", "伊萨卡！ · 航行完成")
        case (_, .timer):
            caption = paused ? L.t("Timer paused", "타이머 일시정지", "タイマー一時停止", "计时器已暂停")
                : remaining <= 0 ? L.t("Time's up · Ithaca!", "시간 종료 · 이타카!", "時間です · イタケ！", "时间到 · 伊萨卡！")
                : L.t("Timer", "타이머", "タイマー", "计时器") + " · " + homeward
        case (_, .stopwatch):
            let lap = Int(elapsed / phaseDuration) + 1
            caption = paused ? L.t("Stopwatch paused", "스톱워치 일시정지", "ストップウォッチ一時停止", "秒表已暂停")
                : L.t("Stopwatch · lap \(lap) round the edge", "스톱워치 · 가장자리 \(lap)바퀴째", "ストップウォッチ · 縁を \(lap) 周目", "秒表 · 绕边缘第 \(lap) 圈")
        case (.focus, _):
            caption = paused ? L.t("Focus paused", "집중 일시정지", "集中一時停止", "专注已暂停")
                : lotus ? L.t("Focus · the Lotus-eaters beckon", "집중 · 로토스 먹는 사람들이 손짓해요", "集中 · ロートパゴスが手招きしている", "专注 · 食莲人在招手")
                : L.t("Focus", "집중", "集中", "专注") + " · " + homeward
        case (.rest, _):
            caption = paused ? L.t("Break paused", "휴식 일시정지", "休憩一時停止", "休息已暂停")
                : restIsLong ? L.t("Long break · Calypso's island", "긴 휴식 · 칼립소의 섬", "長い休憩 · カリュプソの島", "长休息 · 卡吕普索之岛")
                : L.t("Break · home on Ithaca", "휴식 · 고향 이타카에서", "休憩 · 故郷イタケで", "休息 · 在家乡伊萨卡")
        }
        v.show(time: phase == .idle ? idleLength : phase == .arrived ? overtime(elapsed * o.speed) : o.mode == .stopwatch ? elapsedClock(elapsed * o.speed) : countdown(remaining * o.speed),
               caption: caption,
               primary: phase == .idle ? L.t("Start (Space)", "시작 (Space)", "開始 (Space)", "开始 (空格)")
                   : phase == .arrived ? L.t("Start break (Space)", "휴식 시작 (Space)", "休憩を始める (Space)", "开始休息 (空格)")
                   : paused ? L.t("Resume (Space)", "재개 (Space)", "再開 (Space)", "继续 (空格)") : L.t("Pause (Space)", "일시정지 (Space)", "一時停止 (Space)", "暂停 (空格)"),
               skip: phase == .idle || o.mode != .pomodoro ? nil
                   : phase == .arrived ? L.t("+\(Int(ArrivalChoice.extraMinutes)) min (S)", "+\(Int(ArrivalChoice.extraMinutes))분 (S)", "+\(Int(ArrivalChoice.extraMinutes))分 (S)", "+\(Int(ArrivalChoice.extraMinutes)) 分钟 (S)")
                   : phase == .focus ? L.t("Skip to break (S)", "휴식으로 건너뛰기 (S)", "休憩へスキップ (S)", "跳到休息 (S)")
                   : L.t("End break (S)", "휴식 끝내기 (S)", "休憩を終える (S)", "结束休息 (S)"),
               footer: todayLine(short: true),
               contentHidden: manualHidden || (o.hideWhenCaptured && detector.result.capturing),
               dial: dialState,
               presets: phase != .idle || o.mode == .stopwatch ? []
                   : (o.mode == .timer ? Durations.timerPresets : Durations.focusPresets).map { m in
                       (L.t("\(m) min", "\(m)분", "\(m)分", "\(m) 分钟"), Double(m)) },
               selected: dialState?.left)
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

    /// The photos that ship with the app by name; anything else from its file name
    /// ("storm-over-the-sea.jpg" -> "Storm over the sea").
    func photoTitle(_ u: URL) -> String {
        let name = u.deletingPathExtension().lastPathComponent
        if o.backgroundFolder.isEmpty {
            switch name {
            case "aegean-islands-from-orbit": return L.t("Aegean islands from orbit", "궤도에서 본 에게해의 섬들", "軌道から見たエーゲ海の島々", "从轨道俯瞰爱琴海诸岛")
            case "aegean-sunglint-from-orbit": return L.t("Aegean sunglint from orbit", "궤도에서 본 에게해의 햇빛 반사", "軌道から見たエーゲ海のサングリント", "从轨道俯瞰爱琴海的日光反射")
            case "milky-way-over-still-water": return L.t("Milky Way over still water", "잔잔한 물 위의 은하수", "静かな水面に映る天の川", "静水之上的银河")
            case "rough-seas-aleutians": return L.t("Rough seas, Aleutians", "알류샨 열도의 거친 바다", "アリューシャンの荒波", "阿留申群岛的汹涌海面")
            case "sea-cliffs-santa-cruz-island": return L.t("Sea cliffs, Santa Cruz Island", "산타크루즈섬의 해식 절벽", "サンタクルーズ島の海食崖", "圣克鲁斯岛的海崖")
            case "sea-spray-on-coastal-rocks": return L.t("Sea spray on coastal rocks", "해안 바위에 부서지는 물보라", "海岸の岩に砕ける波しぶき", "海岸礁石上的浪花")
            case "sunset-over-the-bering-sea": return L.t("Sunset over the Bering Sea", "베링해의 해넘이", "ベーリング海の夕日", "白令海上的日落")
            default: break
            }
        }
        let t = name.replacingOccurrences(of: "-", with: " ")
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
        p.message = L.t("Choose a folder of photos (JPEG, PNG or HEIC) for the focus mode background.",
                        "집중 모드 배경으로 쓸 사진 폴더(JPEG, PNG, HEIC)를 고르세요.",
                        "集中モードの背景に使う写真のフォルダ（JPEG、PNG、HEIC）を選んでください。",
                        "选择一个照片文件夹（JPEG、PNG 或 HEIC）作为专注模式背景。")
        NSApp.activate(ignoringOtherApps: true)
        guard p.runModal() == .OK, let url = p.url else { return }
        control("background-folder:\(url.path)")
    }

    func applicationWillTerminate(_ n: Notification) { recordRun() }   // quitting mid-run still keeps it

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
            alert.messageText = L.t("Couldn't change Launch at login", "로그인할 때 실행을 바꾸지 못했어요", "ログイン時の起動を変更できませんでした", "无法更改“登录时启动”")
            alert.informativeText = error.localizedDescription + "\n\n" + L.t(
                "You can add Edge Odyssey in System Settings > General > Login Items.",
                "시스템 설정 > 일반 > 로그인 항목에서 Edge Odyssey를 추가할 수 있어요.",
                "システム設定 > 一般 > ログイン項目 で Edge Odyssey を追加できます。",
                "可以在“系统设置 > 通用 > 登录项”中添加 Edge Odyssey。")
            alert.addButton(withTitle: L.t("Open Login Items", "로그인 항목 열기", "ログイン項目を開く", "打开登录项"))
            alert.addButton(withTitle: L.t("Cancel", "취소", "キャンセル", "取消"))
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { SMAppService.openSystemSettingsLoginItems() }
        }
    }

    // MARK: windows

    let logbookWindow = PanelWindow()
    let settingsWindow = PanelWindow()
    var logbookTitle: String { L.t("Logbook", "항해 일지", "航海日誌", "航海日志") }
    var historyTitle: String { L.t("History", "기록", "記録", "记录") }
    var welcomeTitle: String { L.t("Welcome to Edge Odyssey", "Edge Odyssey에 오신 걸 환영해요", "Edge Odyssey へようこそ", "欢迎使用 Edge Odyssey") }

    func showLogbook() {
        logbookWindow.show(title: logbookTitle, LogbookView(found: logbook.found, character: sprites["odysseus-vector"]?.folder))
    }
    let welcomeWindow = PanelWindow()

    func showWelcome() {
        UserDefaults.standard.set(true, forKey: "onboarded")
        welcomeWindow.show(title: welcomeTitle, WelcomeView(
            character: sprites["odysseus-vector"]?.folder,
            copyHookSnippet: { [weak self] in self?.installHooksAndCopySnippet() ?? "" },
            setLoginItem: { [weak self] in self?.setLoginItem($0) },
            sound: o.sound != "off",
            setSound: { [weak self] in self?.control($0 ? "sound:harp" : "sound:off") },   // picking the harp plays it
            preview: { [weak self] in self?.chime(focusEnded: true) },
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
        else { return L.t("Hook files are missing from the app bundle.", "앱 번들에 훅 파일이 없어요.", "アプリにフックのファイルがありません。", "应用包中缺少钩子文件。") }
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
        } catch {
            let e = error.localizedDescription
            return L.t("Couldn't install the hook scripts: \(e)", "훅 스크립트를 설치하지 못했어요: \(e)", "フックのスクリプトをインストールできませんでした：\(e)", "无法安装钩子脚本：\(e)")
        }
        let home = fm.homeDirectoryForCurrentUser.appendingPathComponent(".edge-odyssey").path
        if o.stateDir.path != home {   // a custom --state-dir: the hooks must write there too
            let dir = "'" + o.stateDir.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
            snippet = snippet.replacingOccurrences(of: "$HOME/.edge-odyssey/hooks/", with: "EDGE_ODYSSEY_STATE_DIR=\(dir) \(dir)/hooks/")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        log("hooks installed in \(dest.path), snippet copied")
        let shown = dest.path.replacingOccurrences(of: fm.homeDirectoryForCurrentUser.path, with: "~")
        return L.t("Copied. Hook scripts are in \(shown).", "복사했어요. 훅 스크립트는 \(shown) 에 있어요.", "コピーしました。フックのスクリプトは \(shown) にあります。", "已复制。钩子脚本在 \(shown)。")
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
        w.contentView = v   // no caption here: recordings say their speed in their own caption
        w.orderFrontRegardless()
        backdrops.append(w)
    }
}

// MARK: entry

let opts = Options(CommandLine.arguments)
if let l = opts.lang { if l == "pseudo" { L.pseudo = true } else { L.lang = L.resolve(l) } }
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
