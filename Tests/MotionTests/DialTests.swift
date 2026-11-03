import CoreGraphics
import Testing
@testable import EdgeMotion

// The focus-mode dial: angle <-> minutes, snapping, detents, wheel steps, the wedge, the menu-bar ring.

@Test func angleAndMinutesRoundTrip() {
    #expect(Dial.angle(minutes: 0) == 0)
    #expect(abs(Dial.angle(minutes: 15) - .pi / 2) < 1e-9)
    #expect(abs(Dial.angle(minutes: 30) - .pi) < 1e-9)
    #expect(abs(Dial.angle(minutes: 90) - 2 * .pi) < 1e-9)   // more than an hour fills the face
    #expect(Dial.angle(minutes: -5) == 0)
    for m in stride(from: 0.0, to: 60, by: 2.5) {   // a point at that angle reads back the same minutes
        let a = Dial.angle(minutes: m)
        #expect(abs(Dial.minutes(dx: 100 * sin(a), dy: 100 * cos(a)) - m) < 1e-9)
    }
    #expect(abs(Dial.minutes(dx: 1, dy: 0) - 15) < 1e-9)     // three o'clock
    #expect(abs(Dial.minutes(dx: 0, dy: -1) - 30) < 1e-9)    // six
    #expect(abs(Dial.minutes(dx: -1, dy: 0) - 45) < 1e-9)    // nine
    #expect(Dial.minutes(dx: -0.01, dy: 1) > 59.9)   // just left of twelve: near 60, not 0
}

@Test func snapsToWholeMinutesAndNearbyDetents() {
    #expect(Dial.snap(24.2) == 24)        // too far from 25 to stick
    #expect(Dial.snap(24.4) == 25)
    #expect(Dial.snap(25.7) == 25)
    #expect(Dial.snap(14.5) == 15)
    #expect(Dial.snap(47.4) == 47)
    #expect(Dial.snap(49.6) == 50)
    #expect(Dial.snap(32.6) == 33)
}

@Test func dragNeverWrapsAcrossTwelve() {
    #expect(Dial.drag(from: 58, to: 2) == 60)    // past the top going up: hold at 60
    #expect(Dial.drag(from: 60, to: 5) == 60)    // still past it
    #expect(Dial.drag(from: 60, to: 50.2) == 50) // back on the face
    #expect(Dial.drag(from: 3, to: 57) == 0)     // below zero: hold at 0
    #expect(Dial.drag(from: 0, to: 58) == 0)
    #expect(Dial.drag(from: 20, to: 30.4) == 30)
}

@Test func detentsTolerateARunningClock() {
    #expect(Dial.isDetent(25) && Dial.isDetent(50) && Dial.isDetent(15) && Dial.isDetent(45))
    #expect(Dial.isDetent(25 - 0.5 / 60))         // half a second short of 25:00
    #expect(!Dial.isDetent(24) && !Dial.isDetent(26) && !Dial.isDetent(25 - 2.0 / 60))
}

@Test func wheelStepsHoldAtDetents() {
    // Away from a detent every notch moves a minute.
    #expect(Dial.wheel(from: 20, notches: 1, held: 0) == (1, 0))
    #expect(Dial.wheel(from: 20, notches: 3, held: 0) == (3, 0))
    // At 25 the first two notches are held, the third moves on.
    #expect(Dial.wheel(from: 25, notches: 1, held: 0) == (0, 1))
    #expect(Dial.wheel(from: 25, notches: 1, held: 1) == (0, 2))
    #expect(Dial.wheel(from: 25, notches: 1, held: 2) == (1, 0))
    // A trackpad burst runs onto a detent and stops there: 23 -> 25, then two held.
    #expect(Dial.wheel(from: 23, notches: 4, held: 0) == (2, 2))
    #expect(Dial.wheel(from: 23, notches: 5, held: 0) == (3, 0))
    // Down works the same way, and a held count carries over between events.
    #expect(Dial.wheel(from: 16, notches: -3, held: 0) == (-1, 2))
    var m = 16.0, held = 0, moves = 0
    for _ in 0..<5 { let r = Dial.wheel(from: m, notches: -1, held: held); m += Double(r.notches); held = r.held; moves += r.notches }
    #expect(m == 13 && moves == -3)   // 16 -> 15, two held, then 14 and 13
    #expect(Dial.wheel(from: 20, notches: 0, held: 1) == (0, 1))
}

@Test func wedgeIsCoralInTheLastFifth() {
    let full = Dial.wedge(left: 25, total: 25)
    #expect(full.coral == 5 && full.teal == 25)
    let late = Dial.wedge(left: 3, total: 25)   // in the last fifth: all coral
    #expect(late.coral == 3 && late.teal == 3)
    let long = Dial.wedge(left: 90, total: 90)  // longer than the face: full, coral its first 18 minutes
    #expect(long.coral == 18 && long.teal == 60)
    #expect(Dial.wedge(left: -1, total: 25) == (0, 0))
}

@Test func menuBarRingFillsAndEmpties() {
    #expect(Dial.ring(.idle, left: 10, total: 25) == nil)
    #expect(Dial.ring(.arrived, left: 0, total: 25) == nil)
    #expect(Dial.ring(.focus, left: 25 * 60, total: 25 * 60)! == (0, .focus))
    #expect(Dial.ring(.focus, left: 15 * 60, total: 20 * 60)! == (0.25, .focus))
    #expect(Dial.ring(.focus, left: 300, total: 25 * 60)!.tone == .warm)   // last five minutes
    #expect(Dial.ring(.focus, left: 301, total: 25 * 60)!.tone == .focus)
    #expect(Dial.ring(.rest, left: 60, total: 300)! == (0.2, .rest))       // a break empties
    #expect(Dial.ring(.focus, left: 0, total: 0) == nil)
}

@Test(arguments: focusWindows)
func dialFitsTheRoomAboveItsRows(window: CGSize) {
    let st = FocusLayout.stage(in: window)
    let room = FocusLayout.timeRoom(stage: st, spriteHeight: focusSpriteHeight)
    let reserve: CGFloat = 120
    let d = FocusLayout.dial(room: room, reserve: reserve)
    #expect(d.width == d.height && d.width > 0)
    #expect(d.minX >= room.minX && d.maxX <= room.maxX && d.maxY <= room.maxY + 0.5)
    #expect(d.minY - reserve >= room.minY - 0.5)   // the rows beneath stay in the room too
}
