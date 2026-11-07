import Testing
@testable import EdgeMotion

@Test func completedFocusesAreCountedForToday() {
    var progress = SessionGoalProgress()
    #expect(progress.complete(day: "2026-11-8") == 1)
    #expect(progress.complete(day: "2026-11-8") == 2)
    #expect(progress.count == 2)
}

@Test func sessionGoalResetsAtLocalMidnight() {
    var progress = SessionGoalProgress(day: "2026-11-8", count: 3)
    #expect(progress.normalizing(day: "2026-11-9") == 0)
    #expect(progress.day == "2026-11-9")
    #expect(progress.complete(day: "2026-11-9") == 1)
    progress.reset(day: "2026-11-9")
    #expect(progress.count == 0)
}

@Test func goalReachedOnlyOnTheCrossingFocus() {
    #expect(SessionGoal.value(0) == 0)
    #expect(SessionGoal.value(24) == 24)
    #expect(SessionGoal.value(25) == 0)
    #expect(!SessionGoal.reachedNow(previous: 2, count: 3, goal: 4))
    #expect(SessionGoal.reachedNow(previous: 3, count: 4, goal: 4))
    #expect(!SessionGoal.reachedNow(previous: 4, count: 5, goal: 4))
    #expect(sessionGoalMessage(count: 4, goal: 4, lang: .en) == ("Daily goal reached", "You completed 4 of 4 focus sessions today."))
}

@Test func dailyGoalDoesNotChangeLongBreaksButStopsAutoNextFocus() {
    #expect(Durations.isLongBreak(afterFocus: 4, every: 4))
    #expect(!Durations.isLongBreak(afterFocus: 3, every: 4))
    #expect(SessionGoal.shouldAutoStartNext(requested: true, count: 3, goal: 4))
    #expect(!SessionGoal.shouldAutoStartNext(requested: true, count: 4, goal: 4))
    #expect(!SessionGoal.shouldAutoStartNext(requested: false, count: 3, goal: 4))
}
