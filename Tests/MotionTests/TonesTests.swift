import Testing
@testable import EdgeMotion

// The palette meets WCAG AA in both appearances: text 4.5:1, graphics (wedge, edge, rings) 3:1.

@Test func contrastMatchesWCAG() {
    #expect(abs(Tones.contrast(0x000000, 0xFFFFFF) - 21) < 0.01)
    #expect(Tones.contrast(0x777777, 0x777777) == 1)
    #expect(abs(Tones.contrast(0x767676, 0xFFFFFF) - 4.54) < 0.01)   // the classic AA grey
}

@Test(arguments: [false, true])
func textMeetsAA(dark: Bool) {
    func v(_ p: Tones.Pair) -> UInt32 { dark ? p.dark : p.light }
    for bg in [Tones.paper, Tones.surface, Tones.face] {
        #expect(Tones.contrast(v(Tones.ink), v(bg)) >= 4.5)
        #expect(Tones.contrast(v(Tones.muted), v(bg)) >= 4.5)
    }
    #expect(Tones.contrast(Tones.badgeInk, Tones.badge) >= 4.5)
}

@Test(arguments: [false, true])
func huesStandOutAsGraphics(dark: Bool) {
    func v(_ p: Tones.Pair) -> UInt32 { dark ? p.dark : p.light }
    for hue in [Tones.teal, Tones.brass, Tones.slate, Tones.signal, Tones.rust] {
        for bg in [Tones.paper, Tones.surface, Tones.face] {   // the wedge sits on the face, rings and edges on the page
            #expect(Tones.contrast(v(hue), v(bg)) >= 3)
        }
    }
}
