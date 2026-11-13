import Foundation

/// Time left as a countdown: "12:50", "0:59", "1:00:00" from an hour up. Rounds up, so a
/// full 25-minute session first shows 25:00 and 0:00 appears only when time is out.
func countdown(_ seconds: Double) -> String {
    let s = Int(max(seconds, 0).rounded(.up))
    if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) }
    return String(format: "%d:%02d", s / 60, s % 60)
}

/// The older, quieter style: whole minutes ("13m"), seconds only in the last minute.
func minutesLeft(_ seconds: Double, lang: Lang? = nil) -> String {
    let m = Int((seconds / 60).rounded(.up)), s = Int(max(seconds, 0))
    return seconds >= 60 ? L.t("\(m)m", "\(m)분", "\(m)分", "\(m)分", in: lang) : L.t("\(s)s", "\(s)초", "\(s)秒", "\(s)秒", in: lang)
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

/// The notification at the end of a focus session (arrival) or of a break. `waits`: the break
/// starts only when the user says so.
func endMessage(focusEnded: Bool, longBreak: Bool, breakMinutes m: Int, waits: Bool = false, autoRestMinutes a: Int = 0, lang: Lang? = nil) -> (title: String, body: String) {
    guard focusEnded else {
        return (L.t("Break's over", "쉬는 시간 끝", "休憩おわり", "休息结束", in: lang),
                L.t("Start the next focus from the menu when you're ready", "준비되면 메뉴에서 다음 집중을 시작하세요",
                    "準備ができたらメニューから次の集中を始めましょう", "准备好后，从菜单开始下一次专注", in: lang))
    }
    return (longBreak ? L.t("Calypso's island!", "칼립소의 섬!", "カリュプソの島！", "卡吕普索之岛！", in: lang)
                      : L.t("Ithaca!", "이타카!", "イタケ！", "伊萨卡！", in: lang),
            !waits ? L.t("Take a \(m)-minute break", "\(m)분 쉬어요", "\(m)分休みましょう", "休息 \(m) 分钟", in: lang)
            : a > 0 ? L.t("Focus done. Start your \(m)-minute break to stop the clock (it starts by itself in \(a) min).",
                          "집중 완료. \(m)분 휴식을 시작하면 타이머가 멈춰요 (\(a)분 뒤 자동 시작).",
                          "集中完了。\(m) 分の休憩を始めるとタイマーが止まります（\(a) 分後に自動で始まります）。",
                          "专注完成。开始 \(m) 分钟休息，计时就会停止（\(a) 分钟后自动开始）。", in: lang)
            : L.t("Focus done. Start your \(m)-minute break to stop the clock.", "집중 완료. \(m)분 휴식을 시작하면 타이머가 멈춰요.",
                  "集中完了。\(m) 分の休憩を始めるとタイマーが止まります。", "专注完成。开始 \(m) 分钟休息，计时就会停止。", in: lang))
}

/// The arrival notification when the optional number of focus sessions for today is complete.
func sessionGoalMessage(count: Int, goal: Int, lang: Lang? = nil) -> (title: String, body: String) {
    (L.t("Daily goal reached", "오늘의 목표 달성", "今日の目標を達成", "已完成今日目标", in: lang),
     L.t("You completed \(count) of \(goal) focus sessions today.", "오늘 집중 \(count)/\(goal)회를 완료했어요.",
         "今日の集中を \(count)/\(goal) 回終えました。", "今天已完成 \(count)/\(goal) 次专注。", in: lang))
}

/// The notification when a countdown timer reaches 0:00.
func timerDoneMessage(seconds: Int, lang: Lang? = nil) -> (title: String, body: String) {
    let t = countdown(Double(seconds))
    return (L.t("Time's up", "시간 종료", "時間です", "时间到", in: lang),
            L.t("Your \(t) timer is done", "\(t) 타이머가 끝났어요", "\(t) のタイマーが終わりました", "\(t) 的计时已结束", in: lang))
}

/// Deferred until a break ends, so an agent does not interrupt the break itself.
func agentWaitingMessage(count: Int, lang: Lang? = nil) -> (title: String, body: String) {
    let body = count == 1
        ? L.t("1 agent is waiting for you", "에이전트 1개가 기다려요", "エージェント 1 件があなたを待っています", "有 1 个代理在等你", in: lang)
        : L.t("\(count) agents are waiting for you", "에이전트 \(count)개가 기다려요",
              "\(count) 件のエージェントがあなたを待っています", "有 \(count) 个代理在等你", in: lang)
    return (L.t("Agents are waiting", "에이전트가 기다리고 있어요", "エージェントが待っています", "有代理在等待", in: lang),
            body)
}

/// The sound played when a focus ends (arrival) or a break ends (setting sail).
enum Chime {
    static let choices = ["harp", "glass", "off"]           // menu order; the harp (at low volume) is the default
    static let volumes: [String: Float] = ["low": 0.25, "medium": 0.5]

    /// A saved or typed choice: the harp when nothing is saved, "off" when it isn't one. Legacy
    /// `sound:on` means the harp.
    static func choice(_ s: String?) -> String {
        guard let s else { return "harp" }
        return s == "on" ? "harp" : choices.contains(s) ? s : "off"
    }
    static func volume(_ s: String?) -> String { volumes[s ?? ""] == nil ? "low" : s! }

    /// The NSSound name to play, nil for silence. Harp files ship in the app's Resources.
    static func sound(_ choice: String, focusEnded: Bool) -> String? {
        switch choice {
        case "harp": return focusEnded ? "harp-arrive-ithaca" : "harp-set-sail"
        case "glass": return "Glass"
        default: return nil
        }
    }

    /// The end notification makes the system sound only when the app plays no chime of its own:
    /// one sound, never two. (macOS still lets the user silence it per app.)
    static func notificationSounds(_ choice: String) -> Bool { choice == "off" }
}

/// `arrived`: a Pomodoro focus is over and waits, counting the time since, until the user starts
/// the break (or sails on for a few more minutes).
enum Phase { case idle, focus, arrived, rest }

/// What the user does at Ithaca.
enum ArrivalChoice: String {
    case rest     // start the break
    case extend   // five more minutes of focus

    static let extraMinutes = 5.0

    /// The phase this leads to and its length in (nominal) seconds.
    func next(breakMinutes: Double) -> (phase: Phase, seconds: Double) {
        switch self {
        case .rest: return (.rest, breakMinutes * 60)
        case .extend: return (.focus, Self.extraMinutes * 60)
        }
    }
}

/// How long Ithaca waits when nobody answers: the break starts by itself after `autoRestMinutes`
/// (0: never), and the overtime never runs past `cap`: then the voyage ends and the clock goes idle.
enum ArrivalWait {
    static let choices = [0, 1, 3, 5, 10]   // minutes; 0 is off
    static let defaultMinutes = 3
    static let cap = 3600.0                 // seconds

    static func minutes(_ saved: Int) -> Int { choices.contains(saved) ? saved : defaultMinutes }

    /// When the wait ends (seconds after arrival) and what follows: the break, or idle.
    static func end(autoRestMinutes m: Int) -> (seconds: Double, then: Phase) {
        m > 0 ? (min(Double(m) * 60, cap), .rest) : (cap, .idle)
    }
}

/// Time since arrival, as the menu bar counts it: "+0:42", "+1:05:00".
func overtime(_ seconds: Double) -> String { "+" + elapsedClock(seconds) }

/// Pomodoro (focus, then a break), a plain countdown timer, or a stopwatch that counts up.
enum TimerMode: String, CaseIterable {
    case pomodoro, timer, stopwatch

    /// A saved or typed choice; Pomodoro when it isn't one.
    static func named(_ s: String?) -> TimerMode { TimerMode(rawValue: s ?? "") ?? .pomodoro }

    /// What happens when a phase's time is up: the timer state machine.
    enum TimeUp: Equatable {
        case arrive(restNow: Bool) // a Pomodoro focus is over: Ithaca; the break waits unless `restNow`
        case breakOver(next: Bool) // the break is over; `next`: the next focus starts by itself
        case timerDone           // a countdown reached 0:00
        case lap                 // a stopwatch finished one lap round the edge and carries on
    }

    func timeUp(in phase: Phase, autoNext: Bool, autoRest: Bool = false) -> TimeUp? {
        switch (self, phase) {
        case (_, .idle), (_, .arrived): return nil   // arrived: nothing runs out, the overtime counts up
        case (.pomodoro, .focus): return .arrive(restNow: autoRest)
        case (.pomodoro, .rest): return .breakOver(next: autoNext)
        case (.timer, _): return .timerDone
        case (.stopwatch, _): return .lap
        }
    }
}

/// Time shown by a stopwatch: like `countdown`, but rounded down (0:00 at the start).
func elapsedClock(_ seconds: Double) -> String { countdown(max(seconds, 0).rounded(.down)) }

/// Changing a time with the scroll wheel, a trackpad or the arrow keys.
enum TimeAdjust {
    /// One notch or key press: a minute; Shift five minutes; Option ten seconds.
    static func step(shift: Bool, option: Bool) -> Double { option ? 10 : shift ? 300 : 60 }

    /// Trackpad scrolling (precise deltas, in points) needed for one step.
    static let pointsPerNotch = 24.0

    /// Whole steps in one scroll event plus what carries over to the next. A mouse wheel moves one
    /// step per event whatever its acceleration; a trackpad's small deltas add up.
    static func notches(carry: Double, delta: Double, precise: Bool) -> (notches: Int, carry: Double) {
        guard delta != 0 else { return (0, carry) }
        guard precise else { return (delta > 0 ? 1 : -1, 0) }
        let total = carry + delta
        let n = Int(total / pointsPerNotch)   // toward zero: a reversed swipe first uses up the carry
        return (n, total - Double(n) * pointsPerNotch)
    }

    /// A countdown of `duration` seconds, `elapsed` of them gone, moved by `delta`: the new
    /// duration. What is left stays within `range`, except that shortening never lifts a time that
    /// is already below the range's floor. Idle lengths use elapsed 0.
    static func duration(_ duration: Double, elapsed: Double, by delta: Double, in range: ClosedRange<Double>) -> Double {
        let left = max(duration - elapsed, 0)
        let floor = min(range.lowerBound, left)
        return elapsed + min(max(left + delta, floor), range.upperBound)
    }
}

extension Durations {
    static let timerPresets = [1, 3, 5, 10, 15, 30, 60]   // minutes
    static let timerRange = 10.0...86_400.0                // seconds: 10 s to 24 h
    static let stopwatchLap = 3600.0                       // one lap of the edge per hour

    /// A typed timer length: "10" or "2.5" (minutes), "1:30" (m:ss) or "1:00:00" (h:mm:ss).
    /// Seconds, or nil when it isn't one or falls outside `range`.
    static func seconds(_ text: String, in range: ClosedRange<Double>) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        let nums = parts.map { Double($0) }
        guard (1...3).contains(parts.count), nums.allSatisfy({ $0 != nil && $0!.isFinite && $0! >= 0 }) else { return nil }
        let v = nums.map { $0! }
        if v.count > 1, v.contains(where: { $0 != $0.rounded() }) || v.dropFirst().contains(where: { $0 >= 60 }) { return nil }
        let s: Double
        switch v.count {
        case 1: s = (v[0] * 60).rounded()
        case 2: s = v[0] * 60 + v[1]
        default: s = v[0] * 3600 + v[1] * 60 + v[2]
        }
        return range.contains(s) ? s : nil
    }
}
