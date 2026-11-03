import AppKit

/// The type system for the arrival UI: SF Pro (the system font) for text, SF Pro Rounded for the
/// arrival badge, and monospaced digits wherever a time ticks, so "+0:41" -> "+0:42" never jitters.
/// One place for sizes and weights; the rest of the app keeps its own fonts for now.
enum Typography {
    /// Menu-bar badge: SF Pro Rounded, semibold, menu-bar size.
    static var badge: NSFont { rounded(NSFont.systemFontSize, .semibold) }

    /// SF Pro with monospaced digits.
    static func clock(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    /// SF Pro Rounded with monospaced digits (plain SF Pro when the rounded design is missing).
    static func rounded(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        let base = clock(size, weight)
        guard let d = base.fontDescriptor.withDesign(.rounded) else { return base }
        let mono = d.addingAttributes([.featureSettings: [[NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                                                            NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector]]])
        return NSFont(descriptor: mono, size: size) ?? base
    }
}
