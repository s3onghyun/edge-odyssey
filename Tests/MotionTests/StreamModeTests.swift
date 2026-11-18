import CoreGraphics
import Testing
@testable import EdgeMotion

// Stream mode (Sources/StreamMode.swift): what it changes about capture, and the session HUD.

@Suite struct StreamModeTests {
    @Test func offKeepsTodaysCaptureBehaviour() {
        // Off: excluded from capture unless --capture-visible, and the saved hide setting applies as is.
        #expect(StreamMode.excludesFromCapture(streamMode: false, captureVisible: false))
        #expect(!StreamMode.excludesFromCapture(streamMode: false, captureVisible: true))
        #expect(StreamMode.hidesWhenCaptured(streamMode: false, hideWhenCaptured: true))
        #expect(!StreamMode.hidesWhenCaptured(streamMode: false, hideWhenCaptured: false))
        for phase in [Phase.idle, .focus, .arrived, .rest] { #expect(!StreamMode.showsHUD(streamMode: false, phase: phase)) }
    }

    @Test func onShowsInCapturesAndNeverHides() {
        for flag in [false, true] {
            #expect(!StreamMode.excludesFromCapture(streamMode: true, captureVisible: flag))
            #expect(!StreamMode.hidesWhenCaptured(streamMode: true, hideWhenCaptured: flag))
        }
        #expect(!StreamMode.showsHUD(streamMode: true, phase: .idle))
        for phase in [Phase.focus, .arrived, .rest] { #expect(StreamMode.showsHUD(streamMode: true, phase: phase)) }
    }

    @Test func sessionCountsThroughTheLongBreakCycle() {
        let every = 4
        let seen = (1...9).map { StreamMode.session(focusCount: $0, every: every) }
        #expect(seen.map { $0.n } == [1, 2, 3, 4, 1, 2, 3, 4, 1])
        #expect(seen.allSatisfy { $0.of == 4 })
        // The long break follows the last session of a cycle, as Durations counts it.
        for n in 1...9 { #expect(Durations.isLongBreak(afterFocus: n, every: every) == (StreamMode.session(focusCount: n, every: every).n == every)) }
        let none = StreamMode.session(focusCount: 0, every: 4)   // nothing started yet
        #expect(none.n == 1 && none.of == 4)
        #expect(StreamMode.session(focusCount: 3, every: 0).of == 1)    // never divides by zero
    }

    @Test func hudReadsPhaseTimeAndSession() {
        let s = (n: 2, of: 4)
        func text(_ l: Lang, _ mode: TimerMode, _ phase: Phase, long: Bool = false, clock: String = "18:32", paused: Bool = false) -> String? {
            StreamMode.hudText(mode: mode, phase: phase, restIsLong: long, clock: clock, paused: paused, session: s, lang: l)
        }
        #expect(text(.en, .pomodoro, .focus) == "Focus · 18:32 · 2/4")
        #expect(text(.ko, .pomodoro, .focus) == "집중 · 18:32 · 2/4")
        #expect(text(.ja, .pomodoro, .focus) == "集中 · 18:32 · 2/4")
        #expect(text(.zh, .pomodoro, .focus) == "专注 · 18:32 · 2/4")
        #expect(text(.en, .pomodoro, .rest, clock: "4:59") == "Break · 4:59 · 2/4")
        #expect(text(.en, .pomodoro, .rest, long: true, clock: "14:59") == "Long break · 14:59 · 2/4")
        #expect(text(.en, .pomodoro, .arrived, clock: "+0:42") == "Arrived · +0:42 · 2/4")
        #expect(text(.en, .pomodoro, .focus, paused: true) == "Focus · paused · 2/4")
        #expect(text(.en, .timer, .focus, clock: "9:59") == "Timer · 9:59")          // no sessions outside Pomodoro
        #expect(text(.en, .stopwatch, .focus, clock: "12:03") == "Stopwatch · 12:03")
        for mode in TimerMode.allCases { #expect(text(.en, mode, .idle) == nil) }
        #expect(text(.en, .pomodoro, .focus, clock: countdown(18 * 60 + 31.2)) == "Focus · 18:32 · 2/4")
    }

    @Test func hudSitsBottomRightInsideTheUsableArea() {
        let area = CGRect(x: 0, y: 70, width: 1512, height: 875)   // below the menu bar, above the Dock
        let chip = CGSize(width: 160, height: 26)
        let o = StreamMode.hudOrigin(chip: chip, in: area)
        #expect(o.x + chip.width == area.maxX - StreamMode.hudMargin && o.y == area.minY + StreamMode.hudMargin)
        #expect(area.contains(CGRect(origin: o, size: chip)))
    }

    @Test func hudStaysAllSessionWhileLast5HidesOnlyTheEdge() {
        func v(content: Bool = true, blocked: Bool = false, last5: Bool, hud: Bool) -> [Bool] {
            let r = StreamMode.visibility(content: content, blocked: blocked, hiddenForLast5: last5, hud: hud)
            return [r.overlay, r.edge]
        }
        #expect(v(last5: true, hud: true) == [true, false])     // stream mode, early in a focus: the HUD alone
        #expect(v(last5: false, hud: true) == [true, true])     // the last 5 minutes: the edge joins it
        #expect(v(last5: true, hud: false) == [false, false])   // no HUD (stream mode off, another display): as before
        #expect(v(last5: false, hud: false) == [true, true])
        for last5 in [false, true] {
            #expect(v(blocked: true, last5: last5, hud: true) == [false, false])    // Hide now, a covered display
            #expect(v(content: false, last5: last5, hud: true) == [false, false])   // idle
        }
    }
}
