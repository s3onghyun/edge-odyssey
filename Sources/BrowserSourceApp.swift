import AppKit

// The browser-source overlay in the app: the toggle, its server's life, and the state it pushes.
// BrowserSource (pure) decides what is served; OverlayServer serves it on 127.0.0.1.

extension App {
    var browserOverlayTitle: String {
        L.t("Browser-source overlay (OBS)", "브라우저 소스 오버레이 (OBS)", "ブラウザソースオーバーレイ（OBS）", "浏览器源叠加层（OBS）")
    }
    var overlayURL: String { BrowserSource.url(port: o.overlayPort) }
    var copyOverlayURLTitle: String { L.t("Copy overlay URL", "오버레이 URL 복사", "オーバーレイの URL をコピー", "复制叠加层网址") }

    /// One line under the toggle: what the URL is for, or why it is not answering.
    var overlayNote: String {
        switch overlayFailure {
        case .portInUse?:
            return L.t("Port \(o.overlayPort) is in use by another app. Choose another port.", "다른 앱이 포트 \(o.overlayPort)을 쓰고 있어요. 다른 포트를 고르세요.",
                       "ポート \(o.overlayPort) は別のアプリが使っています。別のポートを選んでください。", "端口 \(o.overlayPort) 已被其他应用占用。请选择其他端口。")
        case .other?:
            return L.t("The overlay could not start. Turn it off and on, or choose another port.", "오버레이를 시작하지 못했어요. 껐다 켜거나 다른 포트를 고르세요.",
                       "オーバーレイを開始できませんでした。オフにしてからオンにするか、別のポートを選んでください。", "叠加层无法启动。请关闭后重新打开，或选择其他端口。")
        case nil:
            return L.t("In OBS: Sources > Browser, paste this URL, 1920 × 1080. Only this Mac can open it.",
                       "OBS에서 소스 > 브라우저를 추가하고 이 URL을 붙여 넣으세요 (1920 × 1080). 이 Mac에서만 열 수 있어요.",
                       "OBS でソース > ブラウザを追加し、この URL を貼り付けます（1920 × 1080）。この Mac からしか開けません。",
                       "在 OBS 中添加来源 > 浏览器，粘贴此网址（1920 × 1080）。只有这台 Mac 能打开。")
        }
    }

    /// The state the overlay shows now: stream mode's HUD state, in real seconds, and the narrated agent state.
    var overlaySnapshot: BrowserSource.Snapshot {
        BrowserSource.snapshot(mode: o.mode, phase: phase, restIsLong: restIsLong, duration: phaseDuration * o.speed, elapsed: elapsed * o.speed,
                               paused: pausedAt != nil, focusCount: focusCount, longEvery: o.longEvery, lang: L.lang,
                               agent: narratedAgent)
    }

    /// Starts or stops the server to match the setting. A port change restarts it.
    func applyBrowserOverlay(restart: Bool = false) {
        if restart || !o.browserOverlay { stopBrowserOverlay() }
        guard o.browserOverlay, overlayServer == nil else { return }
        let server = OverlayServer(port: o.overlayPort)
        server.log = { [weak self] s in DispatchQueue.main.async { self?.log(s) } }
        server.onReady = { [weak self, weak server] _ in
            guard let self, server === self.overlayServer else { return }
            self.overlayFailure = nil
            LanguageWatch.shared.changed()
        }
        server.onFailure = { [weak self, weak server] f in
            guard let self, server === self.overlayServer else { return }
            self.overlayFailure = f
            self.stopBrowserOverlay(keepFailure: true)
            LanguageWatch.shared.changed()
        }
        server.onClients = { [weak self, weak server] n in
            guard let self, server === self.overlayServer else { return }
            self.overlayTick(clients: n)
        }
        overlayServer = server
        overlayFailure = nil
        updateOverlaySprites()
        server.start()
        publishOverlay(force: true)
    }

    func stopBrowserOverlay(keepFailure: Bool = false) {
        overlayServer?.stop()
        overlayServer = nil
        overlayTimer?.invalidate()
        overlayTimer = nil
        if !keepFailure { overlayFailure = nil }
    }

    /// Once a second while a browser source is connected, so its clock and line keep time; no
    /// wakeups when nothing is watching.
    func overlayTick(clients: Int) {
        guard clients > 0 else { overlayTimer?.invalidate(); overlayTimer = nil; return }
        guard overlayTimer == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.publishOverlay(force: true) }
        t.tolerance = 0.05
        RunLoop.main.add(t, forMode: .common)
        overlayTimer = t
    }

    /// Sends the state when it changed (or always, `force`: the heartbeat).
    func publishOverlay(force: Bool = false) {
        guard let s = overlayServer else { return }
        s.publish(BrowserSource.json(overlaySnapshot), force: force)
    }

    /// The chosen character's frames for the page, as PNG `data:` URIs.
    func updateOverlaySprites() {
        guard let server = overlayServer, overlaySpritesFor != o.character || overlaySprites == nil else {
            if let s = overlaySprites { overlayServer?.setSprites(s) }
            return
        }
        overlaySpritesFor = o.character
        overlaySprites = Self.browserSprites(spriteURLs[o.character])
        server.setSprites(overlaySprites ?? BrowserSource.Sprites())
    }

    /// Renders a character for the overlay: vector art at twice the edge's size (sharp on
    /// Retina), pixel art at one pixel per sprite pixel (the page scales it without smoothing).
    static func browserSprites(_ url: URL?) -> BrowserSource.Sprites? {
        guard let url, let sheet = try? SpriteSheet(url: url, scale: 2) else { return nil }
        var out = BrowserSource.Sprites(width: sheet.width, height: sheet.height, pixelated: sheet.pixelated)
        for name in BrowserSource.spriteAnims {
            guard let a = sheet.anims[name] else { continue }
            let frames = a.frames.compactMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }.map(BrowserSource.dataURI)
            if frames.count == a.frames.count { out.anims[name] = .init(fps: a.fps, frames: frames) }
        }
        return out.anims["walk"] == nil ? nil : out
    }

    func copyOverlayURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(overlayURL, forType: .string)
    }

    /// Asks for a port; nil when cancelled or not one of BrowserSource.ports.
    func askOverlayPort() -> Int? {
        guard let text = ask(L.t("Overlay port", "오버레이 포트", "オーバーレイのポート", "叠加层端口"),
                             hint: L.t("A number from 1024 to 49151. The default is \(BrowserSource.defaultPort).",
                                       "1024~49151 사이 숫자. 기본값은 \(BrowserSource.defaultPort)이에요.",
                                       "1024〜49151 の数字。初期値は \(BrowserSource.defaultPort) です。",
                                       "1024 到 49151 之间的数字。默认是 \(BrowserSource.defaultPort)。"),
                             current: "\(o.overlayPort)") else { return nil }
        return BrowserSource.port(text)
    }

    /// The menu's items under the toggle: the URL to copy, or why it is not answering.
    func browserOverlayMenuItems() -> [NSMenuItem] {
        guard o.browserOverlay else { return [] }
        if overlayFailure != nil {
            let why = NSMenuItem(title: overlayNote, action: nil, keyEquivalent: "")
            why.isEnabled = false
            why.indentationLevel = 1
            return [why]
        }
        let copy = MenuAction(copyOverlayURLTitle + " (" + overlayURL + ")") { [weak self] in self?.copyOverlayURL() }
        copy.indentationLevel = 1
        return [copy]
    }
}
