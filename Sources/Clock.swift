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
