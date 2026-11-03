import CoreGraphics
import Testing
@testable import EdgeMotion

// Focus mode: the track sits inside the window, Odysseus (3x) walks just inside the track at
// an even pace, and the countdown never overlaps him, on landscape and vertical windows.

let focusWindows: [CGSize] = [
    CGSize(width: 1728, height: 1117),   // MacBook Pro 16" full screen
    CGSize(width: 3840 / 2, height: 2160 / 2),
    CGSize(width: 1080, height: 1920),   // a display turned vertical
    CGSize(width: 1200, height: 1920),
    CGSize(width: 480, height: 480),     // the smallest focus window
]
let focusSpriteHeight = 26 * FocusLayout.travelerScale

@Test(arguments: focusWindows)
func focusTrackSitsInsideWindow(window: CGSize) {
    let s = FocusLayout.stage(in: window)
    #expect(s.minX > 0 && s.minY > 0 && s.maxX < window.width && s.maxY < window.height)
    #expect(abs(s.midX - window.width / 2) < 0.5 && abs(s.midY - window.height / 2) < 0.5)
    #expect(abs(s.minX - s.minY) < 0.5)   // same margin on every side: the track has the window's shape
}

@Test(arguments: focusWindows)
func focusTravelerIsAtElapsedShareOfTrack(window: CGSize) {
    let stage = FocusLayout.stage(in: window)
    let j = Journey(size: stage.size, inset: focusSpriteHeight / 2, weights: Journey.weights(physical: false))
    let side = (w: Double(stage.width - focusSpriteHeight), h: Double(stage.height - focusSpriteHeight))
    let length = 2 * (side.w + side.h)
    #expect(abs(j.edges.reduce(0) { $0 + Double($1.length) } - length) < 1e-6)
    for t in [0.25, 0.5, 0.75] {
        let (k, u) = j.locate(t)
        let p = j.edges[k].point(u)
        #expect(abs(routeDistance(j, edge: k, p) / length - t) < 1e-9)
        // Halfway is the opposite corner region: on a 4-edge route, t = 0.5 is exactly the
        // point diagonally opposite the start, measured along the route.
        if t == 0.5 { #expect(abs(Double(p.x) + Double(p.y) - (side.w + side.h) - Double(focusSpriteHeight)) < 1e-6) }
        // The sprite (centre `p`, half a sprite each way) stays inside the stage.
        #expect(p.x >= focusSpriteHeight / 2 - 1e-9 && p.x <= stage.width - focusSpriteHeight / 2 + 1e-9)
        #expect(p.y >= focusSpriteHeight / 2 - 1e-9 && p.y <= stage.height - focusSpriteHeight / 2 + 1e-9)
    }
}

@Test(arguments: focusWindows)
func focusCountdownFitsInsideTheVoyage(window: CGSize) {
    let stage = FocusLayout.stage(in: window)
    let room = FocusLayout.timeRoom(stage: stage, spriteHeight: focusSpriteHeight)
    for glyphs in [4, 5, 7] {   // 9:59, 25:00, 1:30:00
        let fs = FocusLayout.timeFontSize(stage: stage, spriteHeight: focusSpriteHeight, glyphs: glyphs)
        #expect(CGFloat(glyphs) * FocusLayout.glyphWidth * fs <= room.width + 1e-9)   // never truncated
        #expect(fs <= max(24, room.height * 0.32))
        #expect(fs >= 24)
    }
    // Readable from across a room on a full-screen display.
    if min(window.width, window.height) >= 1000 {
        #expect(FocusLayout.timeFontSize(stage: stage, spriteHeight: focusSpriteHeight, glyphs: 5) >= 150)
    }
}
