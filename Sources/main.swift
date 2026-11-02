import AppKit
import ServiceManagement

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

    /// Settings the menu changes are kept in UserDefaults; command-line flags override them
    /// for one run without being saved.
    static let saved: [String: Any] = ["style": "traveler", "display": "main", "thickness": 3.0, "onlyLast5": false,
                                       "agentEnabled": true, "lotusEnabled": true, "hideWhenCaptured": true]

    init(_ args: [String], defaults d: UserDefaults = .standard) {
        d.register(defaults: Self.saved)
        style = Style(rawValue: d.string(forKey: "style") ?? "") ?? .traveler
        display = d.string(forKey: "display") ?? "main"
        thickness = CGFloat(min(max(d.double(forKey: "thickness"), 2), 4))
        onlyLast5 = d.bool(forKey: "onlyLast5")
        agentEnabled = d.bool(forKey: "agentEnabled")
        lotusEnabled = d.bool(forKey: "lotusEnabled")
        hideWhenCaptured = d.bool(forKey: "hideWhenCaptured")
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

let ctlNotification = Notification.Name("dev.edgeodyssey.ctl")

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

    var focusDuration: TimeInterval { o.focusMinutes * 60 / o.speed }
    var restDuration: TimeInterval { (restIsLong ? 15 : o.restMinutes) * 60 / o.speed }
    var phaseDuration: TimeInterval { phase == .rest ? restDuration : focusDuration }
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
        let j = Journey(size: host.screen.frame.size, inset: CGFloat(sprite.height) * pt / 2, weights: Journey.physicalWeights)
        let plan = EpisodePlanner.plan(seed: UInt64(phaseStart.timeIntervalSince1970) &+ UInt64(focusCount),
                                       journey: j, focusSeconds: focusDuration,
                                       lastFiveShare: (300 / o.speed) / focusDuration, forced: o.episodes)
        let now = elapsed
        for (ep, share) in plan {
            let delay = share * focusDuration - now
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
            let floorSeconds = min(6, focusDuration * 0.08)
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
            host.play(.circe, sprite: sprite, seconds: min(8, focusDuration * 0.25))
        case .owl:
            host.play(.owl, sprite: sprite, seconds: max(remaining, 1))
        default:
            host.play(ep, sprite: sprite, seconds: 2)
        }
    }

    func pause() {
        guard phase != .idle, pausedAt == nil else { return }
        pausedAt = Date()
        phaseTimer?.invalidate(); last5Timer?.invalidate()
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
        phaseTimer?.invalidate(); last5Timer?.invalidate()
        cancelEpisodes()
        refresh()
    }

    func startRest() {
        cancelEpisodes()
        restIsLong = focusCount % 4 == 0      // every fourth break is long: Calypso's island
        logbook.record(restIsLong ? .calypso : .ithaca)
        phase = .rest
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
            self.phase == .focus ? self.startRest() : self.stop()
        }
        phaseTimer?.tolerance = 0.1
        let untilLast5 = remaining - 300 / o.speed
        if phase == .focus, untilLast5 > 0 {
            last5Timer = Timer.scheduledTimer(withTimeInterval: untilLast5, repeats: false) { [weak self] _ in self?.refresh() }
        }
        titleTimer?.invalidate()
        let every: TimeInterval = o.speed > 1 ? 1 : 15
        titleTimer = Timer.scheduledTimer(withTimeInterval: every, repeats: true) { [weak self] _ in self?.updateTitle() }
        titleTimer?.tolerance = every / 3
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
        case "char": if sprites[arg] != nil { o.character = arg; refresh() }
        case "thickness": o.thickness = CGFloat(min(max(Double(arg) ?? 3, 2), 4)); remember("thickness", Double(o.thickness)); refresh()
        case "last5": o.onlyLast5 = arg == "on"; remember("onlyLast5", o.onlyLast5); refresh()
        case "agent": o.agentEnabled = arg != "off"; remember("agentEnabled", o.agentEnabled); refresh()
        case "lotus-enabled":
            o.lotusEnabled = arg != "off"
            if !o.lotusEnabled { lotus = false }
            remember("lotusEnabled", o.lotusEnabled); refresh()
        case "share-hide": o.hideWhenCaptured = arg != "off"; remember("hideWhenCaptured", o.hideWhenCaptured); refresh()
        case "hide": manualHidden = true; refresh()
        case "show": manualHidden = false; refresh()
        case "display": o.display = arg; remember("display", arg); refresh(); planEpisodes()
        case "lotus": lotus = arg == "on"; if lotus { logbook.record(.lotus) }; refresh()
        case "logbook": showLogbook()
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
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func updateTitle() {
        guard let b = statusItem?.button else { return }
        if phase == .idle {
            b.title = ""
            b.image = NSImage(systemSymbolName: agentState == .waiting ? "circle.circle.fill" : "circle.dashed", accessibilityDescription: "Edge Odyssey")
            return
        }
        let r = remaining * o.speed   // show nominal minutes in demo speed too
        b.image = NSImage(systemSymbolName: phase == .rest ? "cup.and.saucer" : "circle.dashed.inset.filled", accessibilityDescription: "Edge Odyssey")
        b.title = pausedAt != nil ? " paused" : r >= 60 ? " \(Int((r / 60).rounded(.up)))m" : " \(Int(r))s"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header: String
        switch phase {
        case .idle: header = "Ready"
        case .focus: header = pausedAt != nil ? "Focus paused" : "Focus: \(Int((remaining * o.speed / 60).rounded(.up))) min left"
        case .rest: header = "Break: \(Int((remaining * o.speed / 60).rounded(.up))) min left"
        }
        let h = NSMenuItem(title: header, action: nil, keyEquivalent: "")
        h.isEnabled = false
        menu.addItem(h)
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
    func showWelcome() {}

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
