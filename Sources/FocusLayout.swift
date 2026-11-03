import CoreGraphics

/// Geometry of the focus-mode window (pure, shared with the tests): a screen-shaped track
/// inset from the window edge, Odysseus walking just inside it at 3x, and the countdown
/// centred in the space he leaves free.
enum FocusLayout {
    static let travelerScale: CGFloat = 3
    static let trackWidth: CGFloat = 6
    /// Advance of one glyph of the countdown font, in em (monospaced digits, light weight).
    static let glyphWidth: CGFloat = 0.62

    /// The track's rectangle in window coordinates, inset by 7% of the shorter side.
    static func stage(in window: CGSize) -> CGRect {
        let m = (min(window.width, window.height) * 0.07).rounded()
        return CGRect(origin: .zero, size: window).insetBy(dx: m, dy: m)
    }

    /// The traveler fills a band one sprite high inside the track; the countdown gets the
    /// rest, with half a sprite height of air on each side.
    static func timeRoom(stage: CGRect, spriteHeight sh: CGFloat) -> CGRect {
        stage.insetBy(dx: 1.5 * sh, dy: 1.5 * sh)
    }

    /// Largest countdown font whose `glyphs` characters fit the room, and no taller than a third
    /// of it (so a wide display gets big digits, not a wall of them).
    static func timeFontSize(stage: CGRect, spriteHeight: CGFloat, glyphs: Int) -> CGFloat {
        let room = timeRoom(stage: stage, spriteHeight: spriteHeight)
        return max(24, min(room.width / (CGFloat(max(glyphs, 1)) * glyphWidth), room.height * 0.32)).rounded(.down)
    }

    /// The dial: the largest square that fits the room with `reserve` points left beneath it for
    /// the caption, the preset chips and the buttons; the pair is centred in the room.
    static func dial(room: CGRect, reserve: CGFloat) -> CGRect {
        let d = max(0, min(room.width, room.height - reserve)).rounded(.down)
        return CGRect(x: (room.midX - d / 2).rounded(), y: (room.midY - (d + reserve) / 2 + reserve).rounded(), width: d, height: d)
    }
}
