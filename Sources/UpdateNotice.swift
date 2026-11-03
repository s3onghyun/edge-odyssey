import AppKit

// The app's side of the language setting and the update notice (L10n.swift, Update.swift).

enum UpdateStatus { case checking, upToDate, failed }

extension App {
    // MARK: language

    /// "auto", "en", "ko", "ja" or "zh", applied at once: the menu is rebuilt each time it opens,
    /// and what was built earlier (window titles, the open SwiftUI windows, focus mode) is redrawn here.
    func setLanguage(_ pref: String) {
        let p = Lang(rawValue: pref) == nil ? "auto" : pref
        remember("language", p)
        L.pseudo = false
        L.lang = L.resolve(p)
        log("language: \(p) -> \(L.lang.rawValue)")
        logbookWindow.retitle(logbookTitle)
        historyWindow.retitle(historyTitle)
        welcomeWindow.retitle(welcomeTitle)
        focusOverlay?.window.title = L.t("Focus mode", "집중 모드", "集中モード", "专注模式")
        registerArrivalActions()
        LanguageWatch.shared.changed()
        refresh()
    }

    // MARK: update notice

    /// The running version; a build without one never checks.
    static let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(SemVer.init)

    /// No cookies and no cache; the request carries only Update.headers.
    static let updateSession: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.httpCookieAcceptPolicy = .never
        c.httpShouldSetCookies = false
        c.httpCookieStorage = nil
        c.urlCache = nil
        return URLSession(configuration: c)
    }()

    var checkUpdates: Bool { UserDefaults.standard.bool(forKey: "checkUpdates") }

    var updateOffer: SemVer? {
        let d = UserDefaults.standard
        return checkUpdates ? Update.offer(current: Self.version, latest: d.string(forKey: "update.latest").flatMap(SemVer.init),
                                           skipped: d.string(forKey: "update.skipped")) : nil
    }

    /// Soon after launch, then hourly, a check that asks GitHub only when a day has passed.
    func scheduleUpdateChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.checkForUpdate() }
        let t = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in self?.checkForUpdate() }
        t.tolerance = 600
        RunLoop.main.add(t, forMode: .common)
    }

    /// Asks GitHub when a day has passed since the last check, or now when `asked` (Check now).
    func checkForUpdate(asked: Bool = false, now: Date = Date()) {
        let d = UserDefaults.standard
        let last = (d.object(forKey: "update.lastCheck") as? Double).map(Date.init(timeIntervalSince1970:))
        guard checkUpdates, let v = Self.version, updateStatus != .checking, asked || Update.isDue(now: now, last: last) else { return }
        d.set(now.timeIntervalSince1970, forKey: "update.lastCheck")
        updateStatus = .checking
        var req = URLRequest(url: Update.latestAPI, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        for (k, value) in Update.headers(v) { req.setValue(value, forHTTPHeaderField: k) }
        Self.updateSession.dataTask(with: req) { data, resp, _ in
            let found = (resp as? HTTPURLResponse)?.statusCode == 200 ? data.flatMap(Update.parse) : nil
            DispatchQueue.main.async { [weak self] in self?.learned(found) }
        }.resume()
    }

    private func learned(_ latest: SemVer?) {
        updateStatus = latest == nil ? .failed : .upToDate
        log("update check: latest \(latest?.description ?? "unknown"), running \(Self.version?.description ?? "-")")
        guard let latest else { return }
        UserDefaults.standard.set(latest.description, forKey: "update.latest")
        // one notification per new version; the menu rows stay until it is installed or skipped
        guard let v = updateOffer, UserDefaults.standard.string(forKey: "update.notified") != v.description else { return }
        UserDefaults.standard.set(v.description, forKey: "update.notified")
        post((L.t("Edge Odyssey \(v) is out", "Edge Odyssey \(v)이 나왔어요", "Edge Odyssey \(v) が出ました", "Edge Odyssey \(v) 已发布"),
              L.t("Open the menu to see the release page, or skip this version.", "메뉴에서 릴리스 페이지를 보거나 이 버전을 건너뛸 수 있어요.",
                  "メニューからリリースページを開くか、このバージョンをスキップできます。", "打开菜单可查看发布页面，或跳过此版本。")),
             id: "edge-odyssey-update-\(v)")
    }

    /// The rows at the top of the menu while a newer version is out.
    func updateMenuItems() -> [NSMenuItem] {
        guard let v = updateOffer else { return [] }
        let page = MenuAction(L.t("Edge Odyssey \(v) is out: release page…", "Edge Odyssey \(v)이 나왔어요: 릴리스 페이지…",
                                  "Edge Odyssey \(v) が出ました：リリースページ…", "Edge Odyssey \(v) 已发布：发布页面…")) { [weak self] in
            self?.control("release-page")
        }
        page.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
        let skip = MenuAction(L.t("Skip this version", "이 버전 건너뛰기", "このバージョンをスキップ", "跳过此版本")) { [weak self] in self?.control("skip-update") }
        return [page, skip, .separator()]
    }

    /// Settings: the off switch and Check now, with what the last check found.
    func updateSettingsItems() -> [NSMenuItem] {
        let toggle = MenuAction(L.t("Check for updates once a day", "하루 한 번 업데이트 확인", "1日1回アップデートを確認", "每天检查一次更新"),
                                checked: checkUpdates) { [weak self] in
            guard let self else { return }
            self.control(self.checkUpdates ? "updates:off" : "updates:on")
        }
        guard checkUpdates, let v = Self.version else { return [toggle] }
        let now: String
        switch updateStatus {
        case .checking: now = L.t("Checking for updates…", "업데이트 확인 중…", "アップデートを確認中…", "正在检查更新…")
        case .failed: now = L.t("Check now (the last check failed)", "지금 확인 (지난 확인 실패)", "今すぐ確認（前回の確認は失敗）", "立即检查（上次检查失败）")
        case .upToDate where updateOffer == nil:
            now = L.t("Check now (\(v) is the latest)", "지금 확인 (\(v)이 최신)", "今すぐ確認（\(v) が最新）", "立即检查（\(v) 是最新版）")
        default: now = L.t("Check now", "지금 확인", "今すぐ確認", "立即检查")
        }
        let check = MenuAction(now) { [weak self] in self?.control("update-check") }
        check.isEnabled = updateStatus != .checking
        return [toggle, check]
    }
}
