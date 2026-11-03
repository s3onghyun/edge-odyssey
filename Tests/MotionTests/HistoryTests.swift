import Testing
@testable import EdgeMotion

@Test func todaySumsTheDaysRuns() {
    let tz = "Asia/Seoul", c = cal(tz)
    let r = [run("2026-11-03 09:00", "2026-11-03 09:25", tz),
             run("2026-11-03 10:00", "2026-11-03 10:50", tz),
             run("2026-11-03 14:00", "2026-11-03 14:10", tz, done: false),
             run("2026-11-02 09:00", "2026-11-02 09:25", tz)]   // yesterday
    let s = History.summary(r, on: at("2026-11-03 18:00", tz), calendar: c)
    #expect(s.seconds == 85 * 60)
    #expect(s.sessions == 3)
    #expect(s.longest == 50 * 60)
}

@Test func runOverMidnightIsSplitByWallTime() {
    let tz = "Asia/Seoul", c = cal(tz)
    let r = [run("2026-11-02 23:40", "2026-11-03 00:20", tz)]   // 20 min each side
    #expect(History.summary(r, on: at("2026-11-02 12:00", tz), calendar: c) == DaySummary(seconds: 1200, sessions: 1, longest: 2400))
    #expect(History.summary(r, on: at("2026-11-03 12:00", tz), calendar: c) == DaySummary(seconds: 1200, sessions: 0, longest: 0))
    // Paused for half of it: 20 minutes on the clock over 40 of wall time, split evenly.
    let paused = [run("2026-11-02 23:40", "2026-11-03 00:20", tz, minutes: 20)]
    #expect(History.summary(paused, on: at("2026-11-03 01:00", tz), calendar: c).seconds == 600)
}

@Test func theDayDependsOnTheTimeZone() {
    // 23:30-23:50 in Seoul is mid-afternoon UTC: the same run lands on one day in each.
    let r = [run("2026-11-03 23:30", "2026-11-03 23:50", "Asia/Seoul")]
    #expect(History.summary(r, on: at("2026-11-03 12:00", "Asia/Seoul"), calendar: cal("Asia/Seoul")).seconds == 1200)
    #expect(History.summary(r, on: at("2026-11-03 12:00", "UTC"), calendar: cal("UTC")).seconds == 1200)
    #expect(History.summary(r, on: at("2026-11-04 12:00", "UTC"), calendar: cal("UTC")).seconds == 0)
    // 00:10-00:40 in Seoul is still the day before in UTC.
    let early = [run("2026-11-04 00:10", "2026-11-04 00:40", "Asia/Seoul")]
    #expect(History.summary(early, on: at("2026-11-03 12:00", "UTC"), calendar: cal("UTC")).sessions == 1)
    #expect(History.summary(early, on: at("2026-11-04 12:00", "Asia/Seoul"), calendar: cal("Asia/Seoul")).sessions == 1)
}

@Test func daylightSavingDaysAreStillWholeDays() {
    // New York, 2026-11-01: 01:00-02:00 happens twice (a 25-hour day).
    let tz = "America/New_York", c = cal(tz)
    let r = [run("2026-11-01 00:30", "2026-11-01 03:30", tz)]   // 4 hours of wall time
    #expect(r[0].seconds == 4 * 3600)
    #expect(History.summary(r, on: at("2026-11-01 12:00", tz), calendar: c).seconds == 4 * 3600)
    let week = History.days(r, endingOn: at("2026-11-03 12:00", tz), count: 7, calendar: c)
    #expect(week.count == 7)
    #expect(week.map(\.seconds) == [0, 0, 0, 0, 14_400, 0, 0])
    #expect(Set(week.map { c.component(.hour, from: $0.day) }) == [0])   // every bar starts at midnight
}

@Test func daysAreOldestFirstAndIncludeEmptyOnes() {
    let tz = "Asia/Seoul", c = cal(tz)
    let r = [run("2026-11-01 09:00", "2026-11-01 10:00", tz), run("2026-11-03 09:00", "2026-11-03 09:30", tz)]
    let d = History.days(r, endingOn: at("2026-11-03 20:00", tz), count: 3, calendar: c)
    #expect(d.map(\.seconds) == [3600, 0, 1800])
    #expect(d.first?.day == at("2026-11-01 00:00", tz))
}

@Test func zeroLengthRunCountsOnItsStartDay() {
    let tz = "UTC", c = cal(tz)
    var v = run("2026-11-03 10:00", "2026-11-03 10:00", tz)
    v.seconds = 5
    #expect(History.summary([v], on: at("2026-11-03 00:00", tz), calendar: c).seconds == 5)
}

@Test func leaguesAreTwelveAnHour() {
    #expect(History.leagues(3600) == 12)
    #expect(History.leagues(299) == 0)
    #expect(History.leagues(-5) == 0)
}

@Test func csvEscapesLabels() {
    let tz = "Asia/Seoul"
    var v = run("2026-11-03 09:00", "2026-11-03 09:25", tz)
    v.label = "Write \"intro\", then =SUM(A1)"
    var w = v
    w.label = "=HYPERLINK(\"x\")"
    w.completed = false
    let lines = History.csv([v, w], timeZone: zone(tz)).split(separator: "\n")
    #expect(lines[0] == "start,end,mode,minutes,completed,label")
    #expect(lines[1] == "2026-11-03T09:00:00+09:00,2026-11-03T09:25:00+09:00,focus,25.0,yes,\"Write \"\"intro\"\", then =SUM(A1)\"")
    #expect(lines[2].hasSuffix(",no,\"'=HYPERLINK(\"\"x\"\")\""))
}

@Test func spansAreHoursAndMinutes() {
    #expect(History.span(0, lang: .en) == "0m")
    #expect(History.span(59, lang: .en) == "0m")
    #expect(History.span(45 * 60, lang: .en) == "45m")
    #expect(History.span(135 * 60 + 30, lang: .en) == "2h 15m")
    #expect(History.span(135 * 60, lang: .ko) == "2시간 15분" && History.span(135 * 60, lang: .ja) == "2時間15分")
    #expect(History.span(45 * 60, lang: .zh) == "45分钟")
}

@Test func logSurvivesARelaunchAndSkipsBrokenLines() {
    let url = scratchFile()
    var a = run("2026-11-03 09:00", "2026-11-03 09:25", "UTC")
    a.label = "Draft, \"chapter\" 1"
    let b = run("2026-11-03 10:00", "2026-11-03 10:07", "UTC", done: false)
    let log = HistoryLog(url: url)
    #expect(log.records.isEmpty)
    log.append(a)
    appendText("{not json\n", to: url)   // a torn or hand-edited line
    log.append(b)
    #expect(HistoryLog(url: url).records == [a, b])
    log.clear()
    #expect(HistoryLog(url: url).records.isEmpty)
}
