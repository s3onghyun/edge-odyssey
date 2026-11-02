import Foundation

/// Time left as a countdown: "12:50", "0:59", "1:00:00" from an hour up. Rounds up, so a
/// full 25-minute session first shows 25:00 and 0:00 appears only when time is out.
func countdown(_ seconds: Double) -> String {
    let s = Int(max(seconds, 0).rounded(.up))
    if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) }
    return String(format: "%d:%02d", s / 60, s % 60)
}

/// The older, quieter style: whole minutes ("13m"), seconds only in the last minute.
func minutesLeft(_ seconds: Double) -> String {
    seconds >= 60 ? "\(Int((seconds / 60).rounded(.up)))m" : "\(Int(max(seconds, 0)))s"
}

/// Session lengths the menu offers, and the bounds a typed custom length is held to.
enum Durations {
    static let focusPresets = [15, 25, 45, 50, 90]
    static let breakPresets = [5, 10, 15]
    static let longEveryChoices = Array(2...6)
    static let focusRange = 1.0...240.0
    static let breakRange = 1.0...60.0

    /// Whole minutes typed by the user, or nil when it isn't a number in `range`.
    static func minutes(_ text: String, in range: ClosedRange<Double>) -> Double? {
        guard let v = Double(text.trimmingCharacters(in: .whitespaces)), v.isFinite else { return nil }
        let m = v.rounded()
        return range.contains(m) ? m : nil
    }

    /// The n-th focus (1-based) is followed by a long break every `every` sessions.
    static func isLongBreak(afterFocus n: Int, every: Int) -> Bool { every > 0 && n > 0 && n % every == 0 }

    /// A long break is 15 minutes, never shorter than the short break.
    static func longBreakMinutes(rest: Double) -> Double { max(15, rest) }
}

/// The notification at the end of a focus session (arrival) or of a break.
func endMessage(focusEnded: Bool, longBreak: Bool, breakMinutes: Int, korean: Bool) -> (title: String, body: String) {
    switch (focusEnded, korean) {
    case (true, true): return (longBreak ? "칼립소의 섬!" : "이타카!", "\(breakMinutes)분 쉬어요")
    case (true, false): return (longBreak ? "Calypso's island!" : "Ithaca!", "Take a \(breakMinutes)-minute break")
    case (false, true): return ("쉬는 시간 끝", "준비되면 메뉴에서 다음 집중을 시작하세요")
    case (false, false): return ("Break's over", "Start the next focus from the menu when you're ready")
    }
}
