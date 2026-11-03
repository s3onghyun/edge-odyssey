import Testing
@testable import EdgeMotion

@Test func timeUpStateMachine() {
    #expect(TimerMode.pomodoro.timeUp(in: .focus, autoNext: false) == .arrive)
    #expect(TimerMode.pomodoro.timeUp(in: .rest, autoNext: false) == .breakOver(next: false))
    #expect(TimerMode.pomodoro.timeUp(in: .rest, autoNext: true) == .breakOver(next: true))
    #expect(TimerMode.timer.timeUp(in: .focus, autoNext: true) == .timerDone)   // a timer never takes a break
    #expect(TimerMode.stopwatch.timeUp(in: .focus, autoNext: false) == .lap)
    for m in TimerMode.allCases { #expect(m.timeUp(in: .idle, autoNext: true) == nil) }
}

@Test func savedModeFallsBackToPomodoro() {
    #expect(TimerMode.named("timer") == .timer)
    #expect(TimerMode.named("stopwatch") == .stopwatch)
    #expect(TimerMode.named(nil) == .pomodoro)
    #expect(TimerMode.named("egg") == .pomodoro)
}

@Test func stopwatchRoundsDown() {
    #expect(elapsedClock(0) == "0:00")
    #expect(elapsedClock(0.9) == "0:00")
    #expect(elapsedClock(59.99) == "0:59")
    #expect(elapsedClock(3600) == "1:00:00")
    #expect(elapsedClock(-2) == "0:00")
}

@Test func stepsFollowModifiers() {
    #expect(TimeAdjust.step(shift: false, option: false) == 60)
    #expect(TimeAdjust.step(shift: true, option: false) == 300)
    #expect(TimeAdjust.step(shift: false, option: true) == 10)
    #expect(TimeAdjust.step(shift: true, option: true) == 10)   // Option is the fine control
}

@Test func mouseWheelIsOneStepPerEvent() {
    #expect(TimeAdjust.notches(carry: 0, delta: 1, precise: false) == (1, 0))
    #expect(TimeAdjust.notches(carry: 0, delta: 7.5, precise: false) == (1, 0))   // accelerated wheel
    #expect(TimeAdjust.notches(carry: 0, delta: -0.1, precise: false) == (-1, 0))
    #expect(TimeAdjust.notches(carry: 5, delta: 0, precise: true) == (0, 5))
}

@Test func trackpadDeltasAddUp() {
    var carry = 0.0, total = 0
    for _ in 0..<10 {   // 10 x 6 pt = 60 pt: two steps, 12 pt carried
        let r = TimeAdjust.notches(carry: carry, delta: 6, precise: true)
        total += r.notches; carry = r.carry
    }
    #expect(total == 2 && carry == 12)
    let back = TimeAdjust.notches(carry: carry, delta: -20, precise: true)   // reversing uses the carry first
    #expect(back.notches == 0 && back.carry == -8)
    #expect(TimeAdjust.notches(carry: 0, delta: -50, precise: true) == (-2, -2))
}

@Test func idleLengthIsClamped() {
    let r = Durations.timerRange
    #expect(TimeAdjust.duration(600, elapsed: 0, by: 60, in: r) == 660)
    #expect(TimeAdjust.duration(600, elapsed: 0, by: -600, in: r) == 10)    // floor: 10 s
    #expect(TimeAdjust.duration(86_400, elapsed: 0, by: 300, in: r) == 86_400)
    #expect(TimeAdjust.duration(20, elapsed: 0, by: -10, in: r) == 10)
}

@Test func runningCountdownMovesWhatIsLeft() {
    let r = Durations.timerRange
    // 10 minutes, 4 gone: +1 min leaves 7, so the session is 11 minutes long.
    #expect(TimeAdjust.duration(600, elapsed: 240, by: 60, in: r) == 660)
    #expect(TimeAdjust.duration(600, elapsed: 240, by: -300, in: r) == 300)   // 1 min left
    // Never shortened below 10 s left...
    #expect(TimeAdjust.duration(600, elapsed: 540, by: -300, in: r) == 550)
    // ...and a time already under the floor is not pushed back up by shortening.
    #expect(TimeAdjust.duration(600, elapsed: 595, by: -60, in: r) == 600)
    #expect(TimeAdjust.duration(600, elapsed: 595, by: 60, in: r) == 660)
    // Over time (the timer is about to fire) counts as nothing left.
    #expect(TimeAdjust.duration(600, elapsed: 610, by: 60, in: r) == 670)
}

@Test func typedTimerLengths() {
    let r = Durations.timerRange
    #expect(Durations.seconds("10", in: r) == 600)
    #expect(Durations.seconds(" 2.5 ", in: r) == 150)
    #expect(Durations.seconds("1:30", in: r) == 90)
    #expect(Durations.seconds("0:45", in: r) == 45)
    #expect(Durations.seconds("1:00:00", in: r) == 3600)
    #expect(Durations.seconds("24:00:00", in: r) == 86_400)
    for bad in ["", "abc", "0", "0:05", "1:60", "1:2:3:4", "-1", "1.5:00", "1:", "nan", "inf", "24:00:01"] {
        #expect(Durations.seconds(bad, in: r) == nil, "\(bad)")
    }
}

@Test func timerDoneMessages() {
    #expect(timerDoneMessage(seconds: 600, lang: .en) == ("Time's up", "Your 10:00 timer is done"))
    #expect(timerDoneMessage(seconds: 90, lang: .ko) == ("시간 종료", "1:30 타이머가 끝났어요"))
}
