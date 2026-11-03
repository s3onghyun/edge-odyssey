import AppKit
import Charts
import SwiftUI

// The ordinary windows: the logbook, the focus history and the first-run welcome guide.

/// Opens (or brings back) a small titled window hosting a SwiftUI view.
final class PanelWindow {
    private var window: NSWindow?

    func show<V: View>(title: String, _ view: V) {
        let w = window ?? NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable],
                                   backing: .buffered, defer: false)
        w.title = title
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: view)
        w.setContentSize(w.contentView!.fittingSize)
        if window == nil { w.center() }
        window = w
        NSApp.activate(ignoringOtherApps: true)   // a menu-bar app has to bring itself forward
        w.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
    var isOpen: Bool { window?.isVisible == true }
    func retitle(_ title: String) { window?.title = title }
}

/// Tells the open SwiftUI windows that the language changed, so they redraw in it and keep their state.
final class LanguageWatch: ObservableObject {
    static let shared = LanguageWatch()
    func changed() { objectWillChange.send() }
}

// MARK: - logbook

/// Art for a found book: frames of the character and its episode props, layered as on screen.
/// Offsets are in sprite widths (x, right) and heights (y, up).
private let bookArt: [Int: [(svg: String, x: CGFloat, y: CGFloat)]] = [
    1: [("walk-1", -0.3, 0), ("ep-owl-0", 0.3, 0.1)],
    5: [("storm-1", 0, 0)],
    9: [("walk-0", -0.45, 0), ("ep-cyclops-4", 0.45, 0)],
    10: [("walk-2", 0.25, 0), ("ep-bag-3", -0.45, 0)],
    12: [("sirens-1", 0, 0)],
    13: [("ithaca-0", 0, 0)],
    17: [("ithaca-2", 0, 0)],
]

struct LogbookView: View {
    let found: [Int: Date]
    let character: URL?   // vector character folder
    @ObservedObject private var language = LanguageWatch.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("Logbook", "항해 일지", "航海日誌", "航海日志")).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(L.t("\(found.count) of 24 books found. Episodes happen during focus sessions; each one charts a book of the Odyssey.",
                         "24권 중 \(found.count)권을 찾았어요. 에피소드는 집중하는 동안 일어나고, 하나마다 『오디세이아』의 한 권이 기록돼요.",
                         "24巻中 \(found.count) 巻を発見。エピソードは集中中に起こり、それぞれが『オデュッセイア』の一巻を記します。",
                         "已找到 24 卷中的 \(found.count) 卷。插曲在专注时发生，每一段记下《奥德赛》的一卷。"))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {   // not lazy: the window sizes to fit it
                ForEach(0..<4, id: \.self) { row in
                    GridRow { ForEach(1...6, id: \.self) { col in card(row * 6 + col).frame(width: 118) } }
                }
            }
            Text(L.t("Books without a voyage yet are uncharted waters: later versions add more episodes.",
                     "아직 항해가 없는 권은 미지의 바다예요. 다음 버전에서 에피소드가 늘어나요.",
                     "まだ航海のない巻は未知の海です。今後のバージョンでエピソードが増えます。",
                     "尚无航程的卷是未知水域：以后的版本会加入更多插曲。"))
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(width: 6 * 118 + 5 * 10, alignment: .leading)   // the grid's width: longer translations wrap instead of widening it
        .padding(20)
        .environment(\.locale, L.locale)
    }

    @ViewBuilder private func card(_ b: Int) -> some View {
        let date = found[b]
        let findable = Episode.findableBooks.contains(b)
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(date != nil ? Color(red: 0.23, green: 0.12, blue: 0.25) : Color.secondary.opacity(0.08))
                if date != nil, let art = bookArt[b], let folder = character {
                    ZStack {
                        ForEach(art.indices, id: \.self) { i in
                            if let img = NSImage(contentsOf: folder.appendingPathComponent(art[i].svg + ".svg")) {
                                Image(nsImage: img).resizable().frame(width: 64, height: 52)
                                    .offset(x: art[i].x * 64, y: -art[i].y * 52)
                            }
                        }
                    }
                } else {
                    Text(findable ? "?" : "~").font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 118, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(L.t("Book \(b)", "제\(b)권", "第\(b)巻", "第\(b)卷")).font(.caption.bold())
            Text(Episode.bookTitle(b)).font(.caption2).multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(date.map { $0.formatted(.dateTime.year().month(.abbreviated).day().locale(L.locale)) }
                 ?? (findable ? L.t("not yet found", "아직 못 찾음", "未発見", "尚未找到") : L.t("uncharted", "미지의 바다", "未踏の海", "未知水域")))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .opacity(date != nil ? 1 : findable ? 0.75 : 0.45)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - welcome guide

struct WelcomeView: View {
    let character: URL?
    /// Installs the hook scripts and copies the settings snippet; returns a status line.
    let copyHookSnippet: () -> String
    let setLoginItem: (Bool) -> Void
    let finish: (_ startFocus: Bool) -> Void

    @State private var page = 0
    @State private var copied: String?
    @State private var login = LoginItem.isOn
    @ObservedObject private var language = LanguageWatch.shared

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: voyage
                case 1: claude
                default: quiet
                }
            }
            .frame(width: 480, height: 330, alignment: .topLeading)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            Divider()
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if page > 0 { Button(L.t("Back", "이전", "戻る", "上一步")) { page -= 1 } }
                if page < 2 {
                    Button(L.t("Next", "다음", "次へ", "下一步")) { page += 1 }.keyboardShortcut(.defaultAction)
                } else {
                    Button(L.t("Close", "닫기", "閉じる", "关闭")) { finish(false) }
                    Button(L.t("Start a focus voyage", "집중 항해 시작", "集中の航海を始める", "开始专注航行")) { finish(true) }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .environment(\.locale, L.locale)
    }

    private func art(_ svg: String, height: CGFloat = 78) -> some View {
        Group {
            if let url = character?.appendingPathComponent(svg + ".svg"), let img = NSImage(contentsOf: url) {
                Image(nsImage: img).resizable().aspectRatio(32.0 / 26.0, contentMode: .fit).frame(height: height)
                    .accessibilityHidden(true)   // decoration
            }
        }
    }

    private func title(_ t: String) -> some View {
        Text(t).font(.system(size: 22, weight: .bold, design: .rounded))
    }

    private var voyage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 18) {
                art("walk-1"); art("climb-crag-1"); art("slide-0")
            }
            title(L.t("A voyage around your screen", "화면 둘레를 도는 항해", "画面をめぐる航海", "绕屏幕一周的航行"))
            Text(L.t("Start a focus from the menu bar (25 minutes, or another length under Timer). Odysseus rows along the bottom edge, climbs the right, hangs from the top and slides down the left, arriving home exactly when time is up. The trail behind him is your progress; breaks are short visits to Ithaca.",
                     "메뉴 막대에서 집중을 시작하세요(25분, 다른 길이는 타이머 메뉴에서). 오디세우스가 아래 가장자리를 노 저어 가고, 오른쪽을 오르고, 위에 매달려 가다가 왼쪽을 미끄러져 내려와 시간이 다 되는 순간 집에 닿아요. 지나온 자취가 진행 막대이고, 쉬는 시간은 이타카에 잠깐 들르는 시간이에요.",
                     "メニューバーから集中を始めます（25分、ほかの長さはタイマーメニューで）。オデュッセウスは下の辺を漕ぎ、右を登り、上にぶら下がって進み、左を滑り降りて、時間ちょうどに家へ着きます。後ろの航跡が進み具合で、休憩はイタケへの短い寄港です。",
                     "从菜单栏开始专注（25 分钟，其他时长在“计时”菜单里）。奥德修斯沿底边划船、攀上右侧、挂在顶边前行、从左侧滑下，时间到时正好到家。他身后的航迹就是进度，休息是在伊萨卡短暂停靠。"))
            VStack(alignment: .leading, spacing: 4) {
                Label(L.t("Mode: Odysseus voyage, or a thin border only", "모드: 오디세우스 항해, 또는 얇은 테두리만",
                          "モード：オデュッセウスの航海、または細い枠だけ", "模式：奥德修斯航行，或只显示细边框"), systemImage: "sailboat")
                Label(L.t("Show on: main display, all displays, or the one you work on", "표시: 주 모니터, 모든 모니터, 또는 작업 중인 모니터",
                          "表示先：メインディスプレイ、すべて、または作業中のディスプレイ", "显示在：主显示器、所有显示器或正在使用的显示器"), systemImage: "display.2")
                Label(L.t("Border 2-4 px, or show only in the last 5 minutes", "테두리 2-4 px, 또는 마지막 5분에만 표시",
                          "枠 2〜4 px、または最後の5分だけ表示", "边框 2-4 像素，或只在最后 5 分钟显示"), systemImage: "square.dashed")
            }
            .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var claude: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 18) { art("sirens-1"); art("storm-1") }
            title(L.t("Claude Code signals (optional)", "Claude Code 신호 (선택)", "Claude Code のシグナル（任意）", "Claude Code 信号（可选）"))
            Text(L.t("With a small hook, the edge tells you what Claude Code is doing: a quiet blue edge while it works, the Sirens and one soft gold swell when it waits for you, and Poseidon's storm near the 5-hour limit. Nothing leaves your Mac.",
                     "작은 훅 하나로 가장자리가 Claude Code의 상태를 알려 줘요. 일하는 동안은 조용한 파란 테두리, 당신을 기다릴 때는 세이렌과 한 번의 부드러운 금빛 물결, 5시간 한도에 가까우면 포세이돈의 폭풍. 아무것도 Mac 밖으로 나가지 않아요.",
                     "小さなフックで、画面の縁が Claude Code の様子を知らせます。作業中は静かな青い縁、あなたを待っているときはセイレーンと一度だけのやわらかな金色のうねり、5時間の上限が近いとポセイドンの嵐。Mac の外には何も送りません。",
                     "装上一个小钩子，屏幕边缘就会告诉你 Claude Code 在做什么：工作时是安静的蓝边，等你时是塞壬和一次柔和的金色涌动，接近 5 小时上限时是波塞冬的风暴。任何内容都不会离开你的 Mac。"))
            HStack(spacing: 12) {
                Button(L.t("Copy hook snippet", "훅 설정 복사", "フック設定をコピー", "复制钩子配置")) { copied = copyHookSnippet() }
                if let copied { Text(copied).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Text(L.t("Then paste it into ~/.claude/settings.json yourself (merge it with any \"hooks\" you already have). Edge Odyssey never edits that file. Already have a statusLine? Keep yours and set EDGE_ODYSSEY_STATUSLINE_NEXT to it.",
                     "그다음 ~/.claude/settings.json 에 직접 붙여 넣으세요(이미 있는 \"hooks\"와 합쳐서). Edge Odyssey는 그 파일을 고치지 않아요. 이미 statusLine이 있다면 그대로 두고 EDGE_ODYSSEY_STATUSLINE_NEXT 에 지정하세요.",
                     "次に ~/.claude/settings.json へ自分で貼り付けてください（既存の \"hooks\" とまとめて）。Edge Odyssey はそのファイルを編集しません。statusLine がすでにあれば、そのまま残して EDGE_ODYSSEY_STATUSLINE_NEXT に指定してください。",
                     "然后自己把它粘贴到 ~/.claude/settings.json（与已有的 \"hooks\" 合并）。Edge Odyssey 从不修改该文件。已经有 statusLine？保留它，并把它设给 EDGE_ODYSSEY_STATUSLINE_NEXT。"))
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var quiet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 18) { art("doze-0"); art("ithaca-0") }
            title(L.t("Out of your way", "방해하지 않아요", "じゃまをしません", "不打扰你"))
            Text(L.t("The edge never takes a click. It hides in full-screen apps and while your screen is shared or recorded, and Control-Option-Command-H hides it any time. Episodes from the Odyssey fill a 24-book logbook as you focus.",
                     "가장자리는 클릭을 가로채지 않아요. 전체 화면 앱에서, 그리고 화면을 공유하거나 녹화하는 동안 숨고, Control-Option-Command-H로 언제든 숨길 수 있어요. 집중하는 동안 『오디세이아』의 에피소드가 24권짜리 항해 일지를 채워요.",
                     "縁がクリックを奪うことはありません。フルスクリーンのアプリや、画面の共有・録画中は隠れ、Control-Option-Command-H でいつでも隠せます。集中するうちに『オデュッセイア』のエピソードが24巻の航海日誌を埋めていきます。",
                     "边缘从不拦截点击。在全屏应用中、共享或录制屏幕时它会隐藏，随时按 Control-Option-Command-H 也能隐藏。专注时，《奥德赛》的插曲会填满 24 卷的航海日志。"))
            Toggle(L.t("Launch Edge Odyssey at login", "로그인할 때 Edge Odyssey 실행", "ログイン時に Edge Odyssey を起動", "登录时启动 Edge Odyssey"), isOn: $login)
                .onChange(of: login) { setLoginItem($0); login = LoginItem.isOn }
            Text(L.t("Off unless you turn it on. You can change it later under Settings in the menu.",
                     "켜기 전에는 꺼져 있어요. 나중에 메뉴의 설정에서 바꿀 수 있어요.",
                     "オンにしない限りオフです。あとでメニューの「設定」から変えられます。",
                     "除非你打开，否则保持关闭。之后可在菜单的“设置”中更改。"))
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

// MARK: - history

/// Today's totals, a 7- or 30-day bar chart against the daily goal, the latest runs, and
/// CSV export / clear. A snapshot: reopen it to refresh.
struct HistoryView: View {
    let today: DaySummary
    @State var goalHours: Double
    let week: [(day: Date, seconds: Double)]
    let month: [(day: Date, seconds: Double)]
    let recent: [Voyage]
    let setGoal: (Double) -> Void
    let export: () -> Void
    let clear: () -> Void
    @State private var span = 7
    @ObservedObject private var language = LanguageWatch.shared

    init(today: DaySummary, goalHours: Double, week: [(day: Date, seconds: Double)], month: [(day: Date, seconds: Double)],
         recent: [Voyage], setGoal: @escaping (Double) -> Void, export: @escaping () -> Void, clear: @escaping () -> Void) {
        self.today = today
        _goalHours = State(initialValue: goalHours)
        self.week = week
        self.month = month
        self.recent = recent
        self.setGoal = setGoal
        self.export = export
        self.clear = clear
    }

    private var days: [(day: Date, seconds: Double)] { span == 7 ? week : month }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("Today you sailed \(History.leagues(today.seconds)) leagues", "오늘 \(History.leagues(today.seconds))리그를 항해했어요",
                         "今日は \(History.leagues(today.seconds)) リーグ航海しました", "今天航行了 \(History.leagues(today.seconds)) 里格"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(L.t("\(History.span(today.seconds)) of focus · \(sessions(today.sessions)) · longest \(History.span(today.longest))",
                         "집중 \(History.span(today.seconds)) · \(sessions(today.sessions)) · 최장 \(History.span(today.longest))",
                         "集中 \(History.span(today.seconds)) · \(sessions(today.sessions)) · 最長 \(History.span(today.longest))",
                         "专注 \(History.span(today.seconds)) · \(sessions(today.sessions)) · 最长 \(History.span(today.longest))"))
                    .font(.callout).foregroundStyle(.secondary)
            }
            if goalHours > 0 {
                ProgressView(value: min(today.seconds / (goalHours * 3600), 1)) {
                    Text(L.t("Daily goal: \(Int(goalHours)) h · \(Int(today.seconds / (goalHours * 36)))%",
                             "하루 목표: \(Int(goalHours))시간 · \(Int(today.seconds / (goalHours * 36)))%",
                             "1日の目標：\(Int(goalHours))時間 · \(Int(today.seconds / (goalHours * 36)))%",
                             "每日目标：\(Int(goalHours)) 小时 · \(Int(today.seconds / (goalHours * 36)))%")).font(.caption)
                }
            }
            HStack {
                Picker("", selection: $span) {
                    Text(L.t("7 days", "7일", "7日", "7 天")).tag(7)
                    Text(L.t("30 days", "30일", "30日", "30 天")).tag(30)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 160)
                Spacer()
                Picker(L.t("Daily goal", "하루 목표", "1日の目標", "每日目标"), selection: $goalHours) {
                    Text(L.t("None", "없음", "なし", "无")).tag(0.0)
                    ForEach([1, 2, 3, 4, 5, 6, 8], id: \.self) { h in Text(L.t("\(h) h", "\(h)시간", "\(h)時間", "\(h) 小时")).tag(Double(h)) }
                }
                .fixedSize()   // the label's length varies by language
                .onChange(of: goalHours) { setGoal($0) }
            }
            Chart {
                ForEach(days, id: \.day) { d in
                    BarMark(x: .value(L.t("Day", "날짜", "日付", "日期"), d.day, unit: .day), y: .value(L.t("Hours", "시간", "時間", "小时"), d.seconds / 3600))
                        .foregroundStyle(goalHours > 0 && d.seconds >= goalHours * 3600 ? Color.orange : Color.teal)
                }
                if goalHours > 0 {
                    RuleMark(y: .value(L.t("Goal", "목표", "目標", "目标"), goalHours))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(.secondary)
                }
            }
            .chartYAxisLabel(L.t("hours", "시간", "時間", "小时"))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: span == 7 ? 1 : 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: span == 7 ? .dateTime.weekday(.abbreviated).locale(L.locale) : .dateTime.month(.defaultDigits).day().locale(L.locale))
                }
            }
            .frame(height: 180)
            .accessibilityLabel(L.t("Focus hours per day over the last \(span) days", "최근 \(span)일 동안 하루 집중 시간",
                                    "直近 \(span) 日間の1日あたりの集中時間", "最近 \(span) 天每天的专注小时数"))
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("Latest", "최근", "最近", "最近")).font(.headline)
                if recent.isEmpty {
                    Text(L.t("No voyages yet. Each focus, timer and stopwatch run is kept here when it ends.",
                             "아직 항해가 없어요. 집중, 타이머, 스톱워치는 끝날 때마다 여기에 남아요.",
                             "まだ航海がありません。集中・タイマー・ストップウォッチは終わるたびにここに残ります。",
                             "还没有航程。每次专注、计时器和秒表结束时都会记在这里。"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(Array(recent.enumerated()), id: \.offset) { _, v in
                    HStack(spacing: 8) {
                        Text(v.start, format: .dateTime.month(.abbreviated).day().hour().minute().locale(L.locale)).monospacedDigit().frame(width: 130, alignment: .leading)
                        Text(modeName(v.mode)).lineLimit(1).frame(width: 104, alignment: .leading)
                        Text(History.span(v.seconds)).monospacedDigit().frame(width: 60, alignment: .trailing)
                        Text(v.completed ? "✓" : L.t("stopped", "중단", "中断", "中止")).foregroundStyle(.secondary).lineLimit(1).frame(width: 60, alignment: .leading)
                        Text(v.label ?? "").lineLimit(1).truncationMode(.tail)
                    }
                    .font(.callout)
                }
            }
            HStack {
                Text(L.t("Kept only on this Mac, in ~/.edge-odyssey/history.jsonl.", "이 Mac의 ~/.edge-odyssey/history.jsonl 에만 남아요.",
                         "この Mac の ~/.edge-odyssey/history.jsonl にだけ保存されます。", "只保存在这台 Mac 的 ~/.edge-odyssey/history.jsonl 中。"))
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button(L.t("Export CSV…", "CSV로 내보내기…", "CSV を書き出す…", "导出 CSV…"), action: export)
                Button(L.t("Clear History…", "기록 지우기…", "記録を消去…", "清除记录…"), role: .destructive, action: clear)
            }
        }
        .padding(20)
        .frame(width: 560)
        .environment(\.locale, L.locale)
    }

    private func sessions(_ n: Int) -> String {
        L.t(n == 1 ? "1 session" : "\(n) sessions", "\(n)회", "\(n)回", "\(n) 次")
    }

    /// The history file's "focus", "timer" or "stopwatch", as the list shows it.
    private func modeName(_ m: String) -> String {
        switch m {
        case "timer": return L.t("Timer", "타이머", "タイマー", "计时器")
        case "stopwatch": return L.t("Stopwatch", "스톱워치", "ストップウォッチ", "秒表")
        default: return L.t("Focus", "집중", "集中", "专注")
        }
    }
}
