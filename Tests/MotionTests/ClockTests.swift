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
    #expect(minutesLeft(12 * 60 + 50) == "13m")
    #expect(minutesLeft(60) == "1m")
    #expect(minutesLeft(59) == "59s")
}
