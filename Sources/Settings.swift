import AppKit
import SwiftUI

// The Settings window (⌘, in the menu): every option the menu offers, in one window that stays
// open. Each control sends the same `control(...)` command the menu sends, so it saves the same
// UserDefaults key and applies at once (Tests/MotionTests/SettingsTests checks this).

struct SettingsView: View {
    let app: App
    @ObservedObject private var watch = LanguageWatch.shared   // redraws after every change (App.control)

    private var o: Options { app.o }
    private func send(_ cmd: String) { app.control(cmd) }
    /// A control showing `value` that sends `cmd:<new value>`.
    private func bind<T>(_ value: T, _ cmd: String, _ arg: @escaping (T) -> String = { "\($0)" }) -> Binding<T> {
        Binding(get: { value }, set: { send("\(cmd):\(arg($0))") })
    }
    private func flag(_ on: Bool, _ cmd: String) -> Binding<Bool> { bind(on, cmd) { $0 ? "on" : "off" } }
    private func mins(_ m: Int) -> String { L.t("\(m) min", "\(m)분", "\(m)分", "\(m) 分钟") }
    private var custom: String { L.t("Custom…", "직접 입력…", "カスタム…", "自定义…") }

    /// Presets plus the current length when it is not one; picking "Custom…" (tag -1) asks.
    private func minutes(_ title: String, _ presets: [Int], current: Double, cmd: String, ask: @escaping () -> Void) -> some View {
        let now = Int(current)
        return Picker(title, selection: Binding(get: { now }, set: { $0 < 0 ? ask() : send("\(cmd):\($0)") })) {
            ForEach((presets + (presets.contains(now) ? [] : [now])).sorted(), id: \.self) { Text(mins($0)).tag($0) }
            Divider()
            Text(custom).tag(-1)
        }
    }

    var body: some View {
        Form {
            Section {
                Picker(L.t("Mode", "모드", "モード", "模式"), selection: bind(o.mode.rawValue, "mode")) {
                    Text(L.t("Pomodoro", "뽀모도로", "ポモドーロ", "番茄钟")).tag("pomodoro")
                    Text(L.t("Countdown", "카운트다운", "カウントダウン", "倒计时")).tag("timer")
                    Text(L.t("Stopwatch", "스톱워치", "ストップウォッチ", "秒表")).tag("stopwatch")
                }.pickerStyle(.segmented)
                minutes(L.t("Focus", "집중", "集中", "专注"), Durations.focusPresets, current: o.focusMinutes, cmd: "focus") {
                    if let m = app.askMinutes(L.t("Focus length", "집중 길이", "集中の長さ", "专注时长"), current: o.focusMinutes, range: Durations.focusRange) {
                        send("focus:\(Int(m))")
                    }
                }
                minutes(L.t("Break", "휴식", "休憩", "休息"), Durations.breakPresets, current: o.restMinutes, cmd: "rest") {
                    if let m = app.askMinutes(L.t("Break length", "휴식 길이", "休憩の長さ", "休息时长"), current: o.restMinutes, range: Durations.breakRange) {
                        send("rest:\(Int(m))")
                    }
                }
                Picker(L.t("Long break", "긴 휴식", "長い休憩", "长休息"), selection: bind(o.longEvery, "long-every")) {
                    ForEach(Durations.longEveryChoices, id: \.self) { n in Text(L.t("Every \(n) sessions", "\(n)회마다", "\(n)回ごと", "每 \(n) 次")).tag(n) }
                }
                let cd = Int(o.timerSeconds)
                Picker(L.t("Countdown length", "카운트다운 길이", "カウントダウンの長さ", "倒计时时长"),
                       selection: Binding(get: { cd }, set: { s in
                           guard s < 0 else { send("timer:\(s / 60)"); return }
                           if let t = app.ask(L.t("Timer length", "타이머 길이", "タイマーの長さ", "计时时长"),
                                              hint: L.t("Minutes (10), m:ss (1:30) or h:mm:ss (1:15:00), up to 24 hours.",
                                                        "분(10), 분:초(1:30) 또는 시:분:초(1:15:00), 24시간까지.",
                                                        "分（10）、分:秒（1:30）または 時:分:秒（1:15:00）、24時間まで。",
                                                        "分钟（10）、分:秒（1:30）或 时:分:秒（1:15:00），最长 24 小时。"),
                                              current: countdown(o.timerSeconds)) { send("timer:\(t)") }
                       })) {
                    ForEach(Durations.timerPresets.map { $0 * 60 }, id: \.self) { Text(mins($0 / 60)).tag($0) }
                    if !Durations.timerPresets.map({ $0 * 60 }).contains(cd) { Text(countdown(o.timerSeconds)).tag(cd) }
                    Divider()
                    Text(custom).tag(-1)
                }
            } header: { Text(L.t("Timer", "타이머", "タイマー", "计时")).type(.headline) }

            Section {
                Toggle(L.t("Notify when time is up", "시간이 다 되면 알림", "時間になったら通知", "时间到时通知"), isOn: flag(o.notifyAtEnd, "notify"))
                Picker(L.t("Sound", "소리", "サウンド", "声音"), selection: bind(o.sound, "sound")) {
                    Text(L.t("Harp", "하프", "ハープ", "竖琴")).tag("harp")
                    Text(L.t("Glass (system)", "유리 (시스템)", "ガラス（システム）", "玻璃（系统）")).tag("glass")
                    Text(L.t("Off", "끔", "オフ", "关闭")).tag("off")
                }
                Picker(L.t("Volume", "음량", "音量", "音量"), selection: bind(o.soundVolume, "volume")) {
                    Text(L.t("Low", "작게", "小", "低")).tag("low")
                    Text(L.t("Medium", "보통", "中", "中")).tag("medium")
                }.pickerStyle(.segmented).disabled(o.sound == "off")
                Toggle(L.t("Start the break by itself when a focus ends", "집중이 끝나면 휴식 자동 시작", "集中が終わったら休憩を自動で始める", "专注结束后自动开始休息"),
                       isOn: flag(o.autoStartBreak, "autorest"))
                Picker(L.t("If I don't answer at Ithaca", "도착 후 확인이 없으면", "到着後に応答がなければ", "到达后没有回应时"), selection: bind(o.autoRestMinutes, "autorest-after")) {
                    ForEach(ArrivalWait.choices, id: \.self) { n in
                        Text(n == 0 ? L.t("Keep waiting (up to 60 min)", "계속 기다리기 (최대 60분)", "待ち続ける（最大60分）", "继续等待（最多 60 分钟）")
                                    : L.t("Start the break after \(n) min", "\(n)분 뒤 자동으로 휴식 시작", "\(n)分後に休憩を自動で始める", "\(n) 分钟后自动开始休息")).tag(n)
                    }
                }.disabled(o.autoStartBreak)
                Toggle(L.t("Start the next focus after a break", "휴식이 끝나면 다음 집중 시작", "休憩のあと次の集中を始める", "休息后自动开始下一次专注"),
                       isOn: flag(o.autoNextFocus, "autonext"))
            } header: { Text(L.t("When time is up", "시간이 다 되면", "時間になったら", "时间到时")).type(.headline) }

            Section {
                Picker(L.t("Style", "스타일", "スタイル", "样式"), selection: bind(o.style.rawValue, "style")) {
                    Text(L.t("Odysseus voyage", "오디세우스 항해", "オデュッセウスの航海", "奥德修斯航行")).tag("traveler")
                    Text(L.t("Thin border only", "얇은 테두리만", "細い枠だけ", "只显示细边框")).tag("border")
                }.pickerStyle(.segmented)
                Picker(L.t("Speed", "속도", "速さ", "速度"), selection: bind(o.physicalPace ? "physical" : "even", "pace")) {
                    Text(L.t("Even (halfway round = halfway through)", "고르게 (반 바퀴 = 절반 지남)", "一定（半周＝半分経過）", "匀速（走到一半＝过了一半）")).tag("even")
                    Text(L.t("Physical (slow climb, fast slide)", "물리적 (오르막은 느리게, 미끄럼은 빠르게)", "物理的（登りはゆっくり、滑りは速く）", "物理（攀爬慢，滑下快）")).tag("physical")
                }
                Picker(L.t("Show on", "표시할 곳", "表示先", "显示在"), selection: bind(o.display, "display")) {
                    Text(L.t("Main display", "주 모니터", "メインディスプレイ", "主显示器")).tag("main")
                    Text(L.t("All displays", "모든 모니터", "すべてのディスプレイ", "所有显示器")).tag("all")
                    Text(L.t("Follow me (the display I'm working on)", "나를 따라 (작업 중인 모니터)", "自分についてくる（作業中のディスプレイ）", "跟随我（正在使用的显示器）")).tag("follow")
                    Divider()
                    ForEach(NSScreen.screens.map(\.localizedName), id: \.self) { Text($0).tag($0) }
                }
                Picker(L.t("Border", "테두리", "枠", "边框"), selection: bind(Int(o.thickness), "thickness")) {
                    ForEach([2, 3, 4], id: \.self) { Text(verbatim: "\($0) px").tag($0) }
                }.pickerStyle(.segmented)
                Toggle(L.t("Only show in the last 5 minutes", "마지막 5분에만 표시", "最後の5分だけ表示", "只在最后 5 分钟显示"), isOn: flag(o.onlyLast5, "last5"))
                Toggle(L.t("Count down in seconds (12:50, not 13m)", "초 단위로 표시 (13분 대신 12:50)", "秒単位で表示（13分ではなく 12:50）", "按秒倒计时（12:50，而非 13 分）"),
                       isOn: flag(o.showSeconds, "seconds"))
            } header: { Text(L.t("On screen", "화면 표시", "画面表示", "屏幕显示")).type(.headline) }

            Section {
                if NSScreen.screens.count > 1 {
                    Picker(L.t("Open on", "열 곳", "表示先", "显示在"), selection: bind(o.focusDisplay, "focus-display")) {
                        ForEach(NSScreen.screens.map(\.localizedName), id: \.self) { Text($0).tag($0) }
                        if !NSScreen.screens.map(\.localizedName).contains(o.focusDisplay) { Text("—").tag(o.focusDisplay) }
                    }
                }
                Picker(L.t("Background", "배경", "背景", "背景"), selection: bind(o.background, "background")) {
                    Text(L.t("Off", "끔", "オフ", "关闭")).tag("off")
                    Text(L.t("A different photo each session", "세션마다 다른 사진", "セッションごとに別の写真", "每次换一张照片")).tag("cycle")
                    Divider()
                    ForEach(app.backgroundFiles(), id: \.self) { Text(app.photoTitle($0)).tag($0.lastPathComponent) }
                }
                Toggle(L.t("Slow drift", "천천히 움직이기", "ゆっくり動かす", "缓慢漂移"), isOn: flag(o.backgroundDrift, "drift"))
                HStack {
                    Text(o.backgroundFolder.isEmpty ? L.t("Photos that come with the app", "앱에 들어 있는 사진", "アプリ付属の写真", "应用自带的照片")
                                                    : URL(fileURLWithPath: o.backgroundFolder).lastPathComponent)
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if !o.backgroundFolder.isEmpty {
                        Button(L.t("Use the app's photos", "앱 사진 사용", "アプリの写真を使う", "使用应用的照片")) { send("background-folder:") }
                    }
                    Button(L.t("Choose folder…", "폴더 선택…", "フォルダを選択…", "选择文件夹…")) { app.chooseBackgroundFolder() }
                }
            } header: { Text(L.t("Focus mode", "집중 모드", "集中モード", "专注模式")).type(.headline) }

            Section {
                Picker(L.t("Language", "언어", "言語", "语言"), selection: bind(UserDefaults.standard.string(forKey: "language") ?? "auto", "language")) {
                    Text(L.t("System", "시스템", "システム", "系统") + " (\(L.resolve("auto").name))").tag("auto")
                    Divider()
                    ForEach(Lang.allCases, id: \.rawValue) { Text($0.name).tag($0.rawValue) }
                }
                Toggle(L.t("Show Claude Code signals", "Claude Code 신호 표시", "Claude Code のシグナルを表示", "显示 Claude Code 信号"), isOn: flag(o.agentEnabled, "agent"))
                Toggle(L.t("Doze while a game, video or social app is in front", "게임·동영상·SNS 앱이 앞에 있으면 졸기",
                           "ゲーム・動画・SNS アプリが前面にあるとき居眠りする", "游戏、视频或社交应用在前台时打瞌睡"), isOn: flag(o.lotusEnabled, "lotus-enabled"))
                Toggle(L.t("Hide while the screen is shared or recorded", "화면 공유·녹화 중에는 숨기기", "画面の共有・録画中は隠す", "共享或录制屏幕时隐藏"),
                       isOn: flag(o.hideWhenCaptured, "share-hide"))
                Toggle(L.t("Launch at login", "로그인할 때 실행", "ログイン時に起動", "登录时启动"), isOn: flag(LoginItem.isOn, "login"))
                HStack {
                    Toggle(L.t("Check for updates once a day", "하루 한 번 업데이트 확인", "1日1回アップデートを確認", "每天检查一次更新"), isOn: flag(app.checkUpdates, "updates"))
                    Spacer()
                    Button(app.updateStatus == .checking ? L.t("Checking…", "확인 중…", "確認中…", "正在检查…") : L.t("Check now", "지금 확인", "今すぐ確認", "立即检查")) {
                        send("update-check")
                    }.disabled(!app.checkUpdates || app.updateStatus == .checking)
                }
                Button(L.t("Welcome guide…", "시작 안내…", "はじめにガイド…", "欢迎指南…")) { app.showWelcome() }
            } header: { Text(L.t("General", "일반", "一般", "通用")).type(.headline) }
        }
        .formStyle(.grouped)
        .id(L.lang)   // a language change rebuilds the pickers' rows, which SwiftUI would otherwise keep
        .tint(Color(nsColor: Palette.calm))
        .frame(width: 480, height: 640)
        .environment(\.locale, L.locale)
    }
}

extension App {
    var settingsTitle: String { L.t("Settings", "설정", "設定", "设置") }
    func showSettings() { settingsWindow.show(title: settingsTitle, SettingsView(app: self)) }
}
