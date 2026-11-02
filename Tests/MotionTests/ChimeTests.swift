import Testing
@testable import EdgeMotion

@Test func chimeSoundPerChoice() {
    #expect(Chime.sound("harp", focusEnded: true) == "harp-arrive-ithaca")
    #expect(Chime.sound("harp", focusEnded: false) == "harp-set-sail")
    #expect(Chime.sound("glass", focusEnded: true) == "Glass")
    #expect(Chime.sound("glass", focusEnded: false) == "Glass")
    #expect(Chime.sound("off", focusEnded: true) == nil)
    #expect(Chime.sound("off", focusEnded: false) == nil)
}

@Test func chimeChoiceAndVolumeParsing() {
    #expect(Chime.choice(nil) == "off")
    #expect(Chime.choice("on") == "harp")      // the old on/off toggle
    #expect(Chime.choice("glass") == "glass")
    #expect(Chime.choice("bogus") == "off")
    #expect(Chime.volume(nil) == "low")
    #expect(Chime.volume("medium") == "medium")
    #expect(Chime.volume("loud") == "low")
}
