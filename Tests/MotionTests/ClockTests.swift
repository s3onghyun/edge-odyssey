import Testing
@testable import EdgeMotion

@Test func countdownFormats() {
    #expect(countdown(25 * 60) == "25:00")
    #expect(countdown(59 * 60 + 59) == "59:59")
    #expect(countdown(600) == "10:00")
    #expect(countdown(59) == "0:59")
    #expect(countdown(0) == "0:00")
    #expect(countdown(-3) == "0:00")
    #expect(countdown(3600) == "1:00:00")
    #expect(countdown(3600 + 61) == "1:01:01")
}

@Test func countdownRoundsUpAtBoundaries() {
    #expect(countdown(599.01) == "10:00")   // still a sliver of the 10th minute left
    #expect(countdown(599.0) == "9:59")
    #expect(countdown(59.5) == "1:00")
    #expect(countdown(0.2) == "0:01")
    #expect(countdown(3599.5) == "1:00:00")
}

@Test func minutesLeftKeepsTheOldStyle() {
    #expect(minutesLeft(12 * 60 + 50, lang: .en) == "13m")
    #expect(minutesLeft(60, lang: .en) == "1m")
    #expect(minutesLeft(59, lang: .en) == "59s")
    #expect(minutesLeft(12 * 60 + 50, lang: .ko) == "13분" && minutesLeft(59, lang: .ja) == "59秒")
}

@Test func customMinutesAreValidated() {
    #expect(Durations.minutes("30", in: Durations.focusRange) == 30)
    #expect(Durations.minutes(" 52.4 ", in: Durations.focusRange) == 52)
    #expect(Durations.minutes("240", in: Durations.focusRange) == 240)
    for bad in ["0", "-5", "241", "abc", "", "nan", "inf", "1e9"] {
        #expect(Durations.minutes(bad, in: Durations.focusRange) == nil)
    }
    #expect(Durations.minutes("61", in: Durations.breakRange) == nil)
}

@Test(arguments: Durations.longEveryChoices)
func longBreakComesEveryNthSession(every: Int) {
    let longs = (1...12).filter { Durations.isLongBreak(afterFocus: $0, every: every) }
    #expect(longs == Array(stride(from: every, through: 12, by: every)))
    #expect(!Durations.isLongBreak(afterFocus: 0, every: every))
}

@Test func longBreakIsNeverShorterThanTheShortOne() {
    #expect(Durations.longBreakMinutes(rest: 5) == 15)
    #expect(Durations.longBreakMinutes(rest: 20) == 20)
}

@Test func endMessages() {
    #expect(endMessage(focusEnded: true, longBreak: false, breakMinutes: 5, lang: .ko) == ("이타카!", "5분 쉬어요"))
    #expect(endMessage(focusEnded: true, longBreak: true, breakMinutes: 15, lang: .en).title == "Calypso's island!")
    #expect(endMessage(focusEnded: false, longBreak: false, breakMinutes: 5, lang: .en).title == "Break's over")
    #expect(endMessage(focusEnded: true, longBreak: false, breakMinutes: 5, lang: .ja).body == "5分休みましょう")
    #expect(endMessage(focusEnded: true, longBreak: false, breakMinutes: 5, lang: .zh).body == "休息 5 分钟")
}
