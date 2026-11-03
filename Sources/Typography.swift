import AppKit
import SwiftUI

/// The app's one type scale. SF Pro (the system font) carries text; SF Pro Rounded is the voyage's
/// voice: the big countdown, window titles, the dial's numerals and the arrival badge. Every role
/// but the title has monospaced digits, so a ticking "12:50" -> "12:49" never jitters (a title's
/// "12 leagues" does not tick and reads better proportional). System fonts only: no bundled fonts.
enum Typography {
    enum Role {
        case hero       // focus-mode countdown (its size comes from the layout)
        case title      // window titles
        case headline   // section heads in windows
        case body
        case callout    // secondary lines under a title
        case caption    // small print, focus-mode caption and footer
        case numeral    // the dial's minute labels and preset chips
        case menuBar    // the status-item time
        case badge      // the menu-bar arrival badge
    }

    struct Spec {
        var size: CGFloat
        var weight: NSFont.Weight
        var rounded = false
        var tracking: CGFloat = 0   // in em: tighter for big digits, looser for small print
        var tabular = true          // monospaced digits
    }

    static func spec(_ r: Role) -> Spec {
        switch r {
        case .hero: return Spec(size: 96, weight: .light, rounded: true, tracking: -0.02)
        case .title: return Spec(size: 22, weight: .bold, rounded: true, tracking: -0.01, tabular: false)
        case .headline: return Spec(size: 13, weight: .semibold)
        case .body: return Spec(size: 13, weight: .regular)
        case .callout: return Spec(size: 12, weight: .regular)
        case .caption: return Spec(size: 10, weight: .medium, tracking: 0.02)
        case .numeral: return Spec(size: 11, weight: .medium, rounded: true)
        case .menuBar: return Spec(size: NSFont.systemFontSize, weight: .regular)
        case .badge: return Spec(size: NSFont.systemFontSize, weight: .semibold, rounded: true)
        }
    }

    /// The role's font, optionally at another size or weight (the menu-bar time turns semibold in
    /// the last five minutes; focus mode scales its text to the window).
    static func font(_ r: Role, size: CGFloat? = nil, weight: NSFont.Weight? = nil) -> NSFont {
        let s = spec(r)
        let base = s.tabular ? NSFont.monospacedDigitSystemFont(ofSize: size ?? s.size, weight: weight ?? s.weight)
                             : NSFont.systemFont(ofSize: size ?? s.size, weight: weight ?? s.weight)
        guard s.rounded, let d = base.fontDescriptor.withDesign(.rounded) else { return base }
        guard s.tabular else { return NSFont(descriptor: d, size: size ?? s.size) ?? base }
        // withDesign drops the digit feature: ask for tabular figures again.
        let mono = d.addingAttributes([.featureSettings: [[NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                                                            NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector]]])
        return NSFont(descriptor: mono, size: size ?? s.size) ?? base
    }

    /// Letter spacing in points for `r` at `size`, for NSAttributedString's `.kern`.
    static func kern(_ r: Role, size: CGFloat? = nil) -> CGFloat { spec(r).tracking * (size ?? spec(r).size) }

    /// Text in a role's font, colour and tracking (CATextLayer and image drawing take these).
    static func string(_ text: String, _ r: Role, size: CGFloat? = nil, weight: NSFont.Weight? = nil, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.font: font(r, size: size, weight: weight), .kern: kern(r, size: size),
                                                       .foregroundColor: color])
    }
}

extension View {
    /// SwiftUI text in one of the app's type roles.
    func type(_ r: Typography.Role, size: CGFloat? = nil, weight: NSFont.Weight? = nil) -> some View {
        font(Font(Typography.font(r, size: size, weight: weight) as CTFont)).tracking(Typography.kern(r, size: size))
    }
}
