import CoreGraphics
import Foundation

/// Stream mode: for people who record or stream their screen and want viewers to see the voyage.
/// Off (the default), the edge and focus mode keep out of screenshots, recordings and shares, and
/// hide while the screen is captured. On, they show up in captures, stay on screen while captured,
/// and a small session HUD ("Focus · 18:32 · 2/4") sits in a corner. Pure, so the tests decide it.
enum StreamMode {
    /// Whether the overlay and focus-mode windows exclude themselves from capture
    /// (`NSWindow.sharingType` `.none`, else `.readOnly`). `captureVisible`: the `--capture-visible`
    /// flag, which shows them in captures for one run without the rest of stream mode.
    static func excludesFromCapture(streamMode: Bool, captureVisible: Bool) -> Bool { !(streamMode || captureVisible) }

    /// Whether the edge hides while the screen is shared or recorded. Stream mode turns the hiding
    /// off without changing the saved setting, so it comes back when stream mode goes off.
    static func hidesWhenCaptured(streamMode: Bool, hideWhenCaptured: Bool) -> Bool { !streamMode && hideWhenCaptured }

    /// The session HUD shows only in stream mode, while something runs.
    static func showsHUD(streamMode: Bool, phase: Phase) -> Bool { streamMode && phase != .idle }

    /// Which Pomodoro of the current long-break cycle this is: (2, 4) is the second of four. It
    /// counts like `Durations.isLongBreak`, so the long break follows n == of.
    static func session(focusCount: Int, every: Int) -> (n: Int, of: Int) {
        let of = max(every, 1)
        return (focusCount <= 0 ? 1 : (focusCount - 1) % of + 1, of)
    }

    /// The HUD's one line: phase, time and (Pomodoro only) the session, e.g. "Focus · 18:32 · 2/4".
    /// `clock` is the time as the app shows it (countdown, overtime or stopwatch). Nil when idle.
    static func hudText(mode: TimerMode, phase: Phase, restIsLong: Bool, clock: String, paused: Bool,
                        session: (n: Int, of: Int), lang: Lang? = nil) -> String? {
        let name: String
        switch (mode, phase) {
        case (_, .idle): return nil
        case (.timer, _): name = L.t("Timer", "타이머", "タイマー", "计时", in: lang)
        case (.stopwatch, _): name = L.t("Stopwatch", "스톱워치", "ストップウォッチ", "秒表", in: lang)
        case (.pomodoro, .focus): name = L.t("Focus", "집중", "集中", "专注", in: lang)
        case (.pomodoro, .arrived): name = L.t("Arrived", "도착", "到着", "已到达", in: lang)
        case (.pomodoro, .rest):
            name = restIsLong ? L.t("Long break", "긴 휴식", "長い休憩", "长休息", in: lang) : L.t("Break", "휴식", "休憩", "休息", in: lang)
        }
        let time = paused ? L.t("paused", "일시정지", "一時停止", "暂停", in: lang) : clock
        let parts = [name, time] + (mode == .pomodoro ? ["\(session.n)/\(session.of)"] : [])
        return parts.joined(separator: " · ")
    }
}

/// Where the session HUD sits on the display.
enum HUDCorner: String, CaseIterable {
    case bottomRight = "bottom-right", bottomLeft = "bottom-left", topRight = "top-right", topLeft = "top-left"

    /// A saved or typed choice; bottom right when it isn't one.
    static func named(_ s: String?) -> HUDCorner { HUDCorner(rawValue: s ?? "") ?? .bottomRight }

    /// Room kept between the HUD and the display's usable area: clear of the edge and the traveler.
    static let margin: CGFloat = 36

    var title: String {
        switch self {
        case .bottomRight: return L.t("Bottom right", "오른쪽 아래", "右下", "右下")
        case .bottomLeft: return L.t("Bottom left", "왼쪽 아래", "左下", "左下")
        case .topRight: return L.t("Top right", "오른쪽 위", "右上", "右上")
        case .topLeft: return L.t("Top left", "왼쪽 위", "左上", "左上")
        }
    }

    /// The HUD's origin for a chip of `size` inside `area` (y up, as the overlay's layers are),
    /// `margin` in from the corner.
    func origin(chip size: CGSize, in area: CGRect, margin m: CGFloat = HUDCorner.margin) -> CGPoint {
        let left = self == .bottomLeft || self == .topLeft, top = self == .topLeft || self == .topRight
        return CGPoint(x: (left ? area.minX + m : area.maxX - m - size.width).rounded(),
                       y: (top ? area.maxY - m - size.height : area.minY + m).rounded())
    }
}
