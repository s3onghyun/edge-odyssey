import CoreGraphics
import Foundation

/// Stream mode: for people who record or stream their screen and want viewers to see the voyage.
/// Off (the default), the edge and focus mode keep out of screenshots, recordings and shares, and
/// hide while the screen is captured. On, they show up in captures, stay on screen while captured,
/// and a small session HUD ("Focus · 18:32 · 2/4") sits in the bottom-right corner, with the agent's
/// narration ("⛵ Claude rowing…") under it while Claude Code works or waits. Pure, so the tests decide it.
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

    /// What a display shows: its overlay at all, and the edge inside it. `content`: something runs
    /// for this display; `blocked`: Hide now, a covered display or capture hiding. "Only the last
    /// 5 minutes" hides just the edge when the HUD is on this display, so the HUD stays all session.
    static func visibility(content: Bool, blocked: Bool, hiddenForLast5: Bool, hud: Bool) -> (overlay: Bool, edge: Bool) {
        let overlay = content && !blocked && (!hiddenForLast5 || hud)
        return (overlay, overlay && !hiddenForLast5)
    }

    /// Room kept between the HUD and the display's usable area: clear of the edge and the traveler.
    static let hudMargin: CGFloat = 36

    /// The HUD's origin, bottom right of `area` (y up, as the overlay's layers are), `margin` in.
    static func hudOrigin(chip size: CGSize, in area: CGRect, margin m: CGFloat = hudMargin) -> CGPoint {
        CGPoint(x: (area.maxX - m - size.width).rounded(), y: (area.minY + m).rounded())
    }

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
        guard let name = phaseName(mode: mode, phase: phase, restIsLong: restIsLong, lang: lang) else { return nil }
        let time = paused ? pausedWord(lang) : clock
        let parts = [name, time] + (mode == .pomodoro ? ["\(session.n)/\(session.of)"] : [])
        return parts.joined(separator: " · ")
    }

    /// The HUD's name for what runs: "Focus", "Break", "Long break", "Arrived", "Timer" or
    /// "Stopwatch". Nil when idle. The browser-source overlay names the phase the same way.
    static func phaseName(mode: TimerMode, phase: Phase, restIsLong: Bool, lang: Lang? = nil) -> String? {
        switch (mode, phase) {
        case (_, .idle): return nil
        case (.timer, _): return L.t("Timer", "타이머", "タイマー", "计时", in: lang)
        case (.stopwatch, _): return L.t("Stopwatch", "스톱워치", "ストップウォッチ", "秒表", in: lang)
        case (.pomodoro, .focus): return L.t("Focus", "집중", "集中", "专注", in: lang)
        case (.pomodoro, .arrived): return L.t("Arrived", "도착", "到着", "已到达", in: lang)
        case (.pomodoro, .rest):
            return restIsLong ? L.t("Long break", "긴 휴식", "長い休憩", "长休息", in: lang) : L.t("Break", "휴식", "休憩", "休息", in: lang)
        }
    }

    /// What the HUD shows in place of the time while paused.
    static func pausedWord(_ lang: Lang? = nil) -> String { L.t("paused", "일시정지", "一時停止", "暂停", in: lang) }

    // MARK: agent narration

    /// The agent state a stream narrates: the edge's own display state (`App.agentState`, already
    /// held through a break like the edge's signal, and changed only when the hook's state does),
    /// so the narration never runs ahead of the edge. Idle when the Claude Code signals are off.
    /// Only the state is narrated: never a repo, branch, folder or session.
    static func narratedState(_ state: AgentState, agentEnabled: Bool) -> AgentState {
        agentEnabled ? state : .idle
    }

    /// The narration line for viewers: what the coding agent is doing. Nil when idle (nothing shows).
    static func narration(_ state: AgentState, lang: Lang? = nil) -> String? {
        switch state {
        case .idle: return nil
        case .working: return L.t("⛵ Claude rowing…", "⛵ Claude 노 젓는 중…", "⛵ Claude が漕いでいます…", "⛵ Claude 正在划桨…", in: lang)
        case .waiting:
            return L.t("🎶 Sirens: Claude needs you", "🎶 세이렌: Claude가 당신을 불러요", "🎶 セイレーン：Claude があなたを呼んでいます", "🎶 塞壬：Claude 需要你", in: lang)
        case .limit: return L.t("⛈ Near the usage limit", "⛈ 사용 한도에 가까워요", "⛈ 使用上限が近づいています", "⛈ 接近用量上限", in: lang)
        }
    }

    /// Room between the session chip and the narration chip under it.
    static let hudGap: CGFloat = 6

    /// Where the HUD's chips sit, bottom right of `area`: the narration (when there is one) at the
    /// margin, the session chip right above it, both right-aligned. Without a narration the session
    /// chip keeps its own place at the margin.
    static func hudStack(session: CGSize?, narration: CGSize?, in area: CGRect, margin m: CGFloat = hudMargin)
        -> (session: CGPoint?, narration: CGPoint?) {
        let low = narration.map { hudOrigin(chip: $0, in: area, margin: m) }
        let high = session.map { size -> CGPoint in
            var p = hudOrigin(chip: size, in: area, margin: m)
            if let narration { p.y += narration.height + hudGap }
            return p
        }
        return (high, low)
    }
}
