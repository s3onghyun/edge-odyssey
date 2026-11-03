import Foundation

/// The colours, palette "Aegean night": navy ink, a muted sea teal, one warm-brass accent (a
/// session's last fifth and the arrival), slate for breaks, a slate blue for Claude Code and a
/// rust for its usage storm. Each has a light and a dark variant (sRGB hex). Pure, so the tests
/// hold every pair to WCAG AA; Palette turns them into colours.
enum Tones {
    struct Pair { let light: UInt32, dark: UInt32 }

    // Neutrals: focus mode's page, the dial's bezel and hub, the dial's face, text.
    static let paper = Pair(light: 0xF3F0E8, dark: 0x0D1420)
    static let surface = Pair(light: 0xFBF9F4, dark: 0x152031)
    static let face = Pair(light: 0xE9E5DC, dark: 0x243046)
    static let ink = Pair(light: 0x18222F, dark: 0xE9E5DC)
    static let muted = Pair(light: 0x56606E, dark: 0x9AA4B4)
    // Hues: few and desaturated.
    static let teal = Pair(light: 0x4A807C, dark: 0x6FA7A1)     // focus
    static let brass = Pair(light: 0x977542, dark: 0xC8A46A)    // the last fifth, arrival
    static let slate = Pair(light: 0x6F7D95, dark: 0x8A9AB8)    // a break
    static let signal = Pair(light: 0x5A78A0, dark: 0x7F9CC6)   // Claude Code works / waits
    static let rust = Pair(light: 0xA9573F, dark: 0xCF7A5C)     // near the usage limit
    /// The menu-bar arrival badge: bright brass with navy ink on either menu bar.
    static let badge: UInt32 = 0xC8A46A
    static let badgeInk: UInt32 = 0x18222F

    /// WCAG 2 relative luminance of an sRGB hex colour.
    static func luminance(_ rgb: UInt32) -> Double {
        func ch(_ shift: UInt32) -> Double {
            let v = Double(rgb >> shift & 0xFF) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch(16) + 0.7152 * ch(8) + 0.0722 * ch(0)
    }

    /// WCAG 2 contrast ratio, 1...21.
    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
