import Foundation

/// The UI languages. `zh` is Simplified Chinese.
enum Lang: String, CaseIterable {
    case en, ko, ja, zh

    /// The localization name macOS uses (`CFBundleLocalizations` in build.sh).
    var localization: String { self == .zh ? "zh-Hans" : rawValue }
    var locale: Locale { Locale(identifier: ["en": "en_US", "ko": "ko_KR", "ja": "ja_JP", "zh": "zh_CN"][rawValue]!) }
    /// Each language by its own name, as the Language menu lists it.
    var name: String { ["en": "English", "ko": "한국어", "ja": "日本語", "zh": "简体中文"][rawValue]! }
}

/// Every UI string is one `L.t(en, ko, ja, zh)` call, computed when it is shown, so a language
/// change applies at once without a restart. A missing language is a compile error;
/// Tests/MotionTests/L10nTests reads every call in Sources/ and checks each translation.
enum L {
    /// The menu's choice ("auto", "en", "ko", "ja", "zh"), saved as `language`.
    static var lang = resolve(UserDefaults.standard.string(forKey: "language") ?? "auto")
    /// Development only (`--lang pseudo`): every string about 40% longer and accented, to find truncation.
    static var pseudo = false
    /// The locale for dates and numbers in the chosen language.
    static var locale: Locale { pseudo ? Lang.en.locale : lang.locale }

    /// The language setting -> a language. "auto" asks macOS to match all the preferred languages
    /// in order (Traditional Chinese is not given Simplified), else English.
    static func resolve(_ pref: String, system: [String] = Locale.preferredLanguages) -> Lang {
        if let l = Lang(rawValue: pref) { return l }
        let match = Bundle.preferredLocalizations(from: Lang.allCases.map(\.localization), forPreferences: system).first
        return Lang.allCases.first { $0.localization == match } ?? .en
    }

    /// `in:` pins a language (tests); otherwise the chosen one.
    static func t(_ en: String, _ ko: String, _ ja: String, _ zh: String, in l: Lang? = nil) -> String {
        if pseudo && l == nil { return stretch(en) }
        switch l ?? lang {
        case .en: return en
        case .ko: return ko
        case .ja: return ja
        case .zh: return zh
        }
    }

    /// "Settings" -> "[Šéttîñgš ~~~]": accented, about 40% longer, bracketed so a cut-off end shows.
    static func stretch(_ s: String) -> String {
        let accents: [Character: Character] = ["a": "á", "e": "é", "i": "î", "o": "ö", "u": "ü", "n": "ñ", "s": "š", "c": "ç",
                                               "A": "Å", "E": "É", "I": "Î", "O": "Ö", "U": "Ü", "S": "Š", "C": "Ç"]
        return "[" + String(s.map { accents[$0] ?? $0 }) + " " + String(repeating: "~", count: max(2, s.count * 2 / 5)) + "]"
    }
}
