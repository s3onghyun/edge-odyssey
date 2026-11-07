import Foundation

/// The optional number of completed Pomodoro focuses to aim for today. The progress deliberately
/// lives apart from History: resetting a goal should not throw away the user's logbook.
enum SessionGoal {
    static let presets = [4, 6, 8]
    static let range: ClosedRange<Int> = 1...24

    /// Zero means no goal; every positive value must fit the custom picker.
    static func value(_ saved: Int) -> Int { saved == 0 || range.contains(saved) ? saved : 0 }
    static func isReached(count: Int, goal: Int) -> Bool { goal > 0 && count >= goal }
    static func reachedNow(previous: Int, count: Int, goal: Int) -> Bool {
        goal > 0 && previous < goal && count >= goal
    }
    static func shouldAutoStartNext(requested: Bool, count: Int, goal: Int) -> Bool {
        requested && !isReached(count: count, goal: goal)
    }

    /// A stable local-day key without a formatter or a scheduled midnight task.
    static func localDayKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.era, .year, .month, .day], from: now)
        return "\(c.era ?? 0)-\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}

/// A local-calendar day and its completed focus count. `normalizing` makes a stale stored day
/// become zero at local midnight without a timer or background work.
struct SessionGoalProgress: Equatable {
    var day: String?
    var count: Int

    init(day: String? = nil, count: Int = 0) {
        self.day = day
        self.count = max(count, 0)
    }

    @discardableResult
    mutating func normalizing(day: String) -> Int {
        guard self.day == day else {
            self.day = day
            count = 0
            return count
        }
        return count
    }

    @discardableResult
    mutating func complete(day: String) -> Int {
        normalizing(day: day)
        count += 1
        return count
    }

    mutating func reset(day: String) {
        self.day = day
        count = 0
    }
}
