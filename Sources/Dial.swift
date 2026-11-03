import Foundation

/// The Time-Timer-style dial in focus mode: a 60-minute face read clockwise from twelve o'clock,
/// a wedge for the time left, gold detents at the usual session lengths. Pure math, shared with
/// the tests; DialView draws it.
enum Dial {
    static let faceMinutes = 60.0
    static let detents: [Double] = [15, 25, 45, 50]
    /// Plain wheel notches a detent swallows before the time moves on: a click stop you can feel.
    static let holdNotches = 2
    /// A drag that ends this close to a detent (in minutes) lands on it.
    static let snapMinutes = 0.75
    /// The wedge's coral part: a session's last fifth, as on the edge.
    static let warmShare = 0.2

    /// Clockwise angle from twelve o'clock, in radians. More than an hour fills the face.
    static func angle(minutes m: Double) -> Double { min(max(m, 0), faceMinutes) / faceMinutes * 2 * .pi }

    /// The minutes under a point `dx`, `dy` from the centre (y up): 0..<60, clockwise from twelve.
    static func minutes(dx: Double, dy: Double) -> Double {
        let a = atan2(dx, dy)   // 0 at twelve, clockwise positive
        return (a < 0 ? a + 2 * .pi : a) / (2 * .pi) * faceMinutes
    }

    /// A whole minute, or a detent when one is near.
    static func snap(_ m: Double) -> Double { detents.first { abs($0 - m) <= snapMinutes } ?? m.rounded() }

    /// The next value while dragging: the minutes under the pointer, snapped, but never wrapping
    /// across twelve o'clock: past 60 it holds at 60, below 0 at 0, until the pointer comes back.
    static func drag(from previous: Double, to raw: Double) -> Double {
        if previous > 45 && raw < 15 { return faceMinutes }
        if previous < 15 && raw > 45 { return 0 }
        return snap(raw)
    }

    /// Within a second of a detent (a running clock is never exactly on one).
    static func isDetent(_ m: Double) -> Bool { detents.contains { abs($0 - m) < 1.0 / 60 } }

    /// One-minute wheel notches from `minutes`: how many of them move the time once each detent
    /// on the way has held its first `holdNotches`. `held` carries over to the next scroll event.
    static func wheel(from minutes: Double, notches: Int, held: Int) -> (notches: Int, held: Int) {
        var m = minutes, moved = 0, held = held
        let step = notches > 0 ? 1 : -1
        for _ in 0..<abs(notches) {
            if isDetent(m) && held < holdNotches { held += 1; continue }
            m += Double(step); moved += step; held = 0
        }
        return (moved, held)
    }

    /// The wedge for `left` of `total` minutes, as clockwise extents from twelve: coral up to
    /// where the session's last fifth begins, teal from there to the time left.
    static func wedge(left: Double, total: Double) -> (coral: Double, teal: Double) {
        let l = min(max(left, 0), faceMinutes)
        return (min(l, max(total, 0) * warmShare), l)
    }

    /// The menu-bar ring: how full it is and its colour, nil when no clock runs. A focus fills up
    /// (coral in its last five minutes), a break empties.
    enum Tone { case focus, warm, rest }
    static func ring(_ phase: Phase, left: Double, total: Double) -> (fill: Double, tone: Tone)? {
        guard total > 0 else { return nil }
        let share = min(max(left / total, 0), 1)
        switch phase {
        case .focus: return (1 - share, left <= 300 ? .warm : .focus)
        case .rest: return (share, .rest)
        case .idle, .arrived: return nil
        }
    }
}
