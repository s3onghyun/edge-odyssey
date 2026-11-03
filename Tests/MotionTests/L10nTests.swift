import Testing
@testable import EdgeMotion

// Languages: the setting, the formats, and a check of every UI string in Sources/.

/// Reads Swift source well enough to find every `L.t(` call and every string literal outside one:
/// comments, "…" and """…""" literals with \( ) interpolation, #"…"# raw literals, and brackets.
struct SourceStrings {
    struct Call { var line: Int; var args: [String]; var literals: [String]; var interpolations: [[String]] }
    var calls: [Call] = []
    /// String literals outside `L.t(` calls that contain Hangul: a Korean-only string nobody translated.
    var strayHangul: [(line: Int, text: String)] = []
    /// English literals handed straight to a menu item, button, label, alert or window title: an
    /// untranslated string.
    var strayUI: [(line: Int, text: String)] = []
    static let uiSinks = ["MenuAction(", "Text(", "Button(", "Label(", "Toggle(", "Picker(", "NSButton(title:", "addButton(withTitle:",
                          "messageText =", "informativeText =", "message =", ".title =", "show(title:", "accessibilityLabel(",
                          "setAccessibilityLabel(", "chartYAxisLabel("]

    init(_ source: String) {
        let c = Array(source)
        var i = 0
        func at(_ j: Int, _ s: String) -> Bool {
            let a = Array(s)
            return j + a.count <= c.count && Array(c[j..<(j + a.count)]) == a
        }
        func line(_ j: Int) -> Int { c[..<j].reduce(1) { $1 == "\n" ? $0 + 1 : $0 } }
        func comment(_ j: Int) -> Int? {   // index after a comment starting at j
            if at(j, "//") { var k = j; while k < c.count && c[k] != "\n" { k += 1 }; return k }
            if at(j, "/*") { var k = j + 2; while k < c.count && !at(k, "*/") { k += 1 }; return k + 2 }
            return nil
        }
        func literal(_ j: Int) -> (end: Int, text: String, interp: [String]) { SourceStrings.readLiteral(c, j) }
        /// From an opening bracket: the index after its match, and the source of each top-level argument.
        func group(_ start: Int) -> (end: Int, args: [String]) {
            var depth = 0, j = start, argStart = start + 1, args: [String] = []
            while j < c.count {
                if let k = comment(j) { j = k; continue }
                if c[j] == "\"" || (c[j] == "#" && (at(j + 1, "\"") || at(j + 1, "#"))) { j = literal(j).end; continue }
                switch c[j] {
                case "(", "[", "{": depth += 1
                case ")", "]", "}":
                    depth -= 1
                    if depth == 0 {
                        args.append(String(c[argStart..<j]).trimmingCharacters(in: .whitespacesAndNewlines))
                        return (j + 1, args)
                    }
                case "," where depth == 1:
                    args.append(String(c[argStart..<j]).trimmingCharacters(in: .whitespacesAndNewlines))
                    argStart = j + 1
                default: break
                }
                j += 1
            }
            return (j, args)
        }
        /// The literals in one argument (usually one; `String(format: "…", …)` has one plus values).
        func parts(_ arg: String) -> (text: String, interp: [String]) {
            let a = Array(arg)
            var j = 0, text = "", interp: [String] = []
            while j < a.count {
                if a[j] == "\"" || (a[j] == "#" && j + 1 < a.count && (a[j + 1] == "\"" || a[j + 1] == "#")) {
                    let l = SourceStrings.readLiteral(a, j); text += l.text; interp += l.interp; j = l.end
                } else { j += 1 }
            }
            return (text, interp)
        }
        while i < c.count {
            if let k = comment(i) { i = k; continue }
            if c[i] == "\"" || (c[i] == "#" && (at(i + 1, "\"") || at(i + 1, "#"))) {
                let l = literal(i)
                if l.text.unicodeScalars.contains(where: Script.hangul) { strayHangul.append((line(i), l.text)) }
                var ls = i
                while ls > 0 && c[ls - 1] != "\n" { ls -= 1 }
                let before = String(c[ls..<i]).trimmingCharacters(in: .whitespaces)
                if l.text.contains(where: { $0.isASCII && $0.isLetter }), SourceStrings.uiSinks.contains(where: { before.hasSuffix($0) }) {
                    strayUI.append((line(i), l.text))
                }
                i = l.end
                continue
            }
            if at(i, "L.t("), i == 0 || !(c[i - 1].isLetter || c[i - 1].isNumber || c[i - 1] == "." || c[i - 1] == "_") {
                var g = group(i + 3)
                if g.args.count == 5, g.args[4].hasPrefix("in:") { g.args.removeLast() }   // L.t(…, in: lang): a pinned language
                let p = g.args.map(parts)
                calls.append(Call(line: line(i), args: g.args, literals: p.map(\.text), interpolations: p.map { $0.interp.sorted() }))
                i = g.end
                continue
            }
            i += 1
        }
    }

    /// From an opening quote (or the #s of a raw literal): the index after it, its text, its interpolations.
    static func readLiteral(_ c: [Character], _ start: Int) -> (end: Int, text: String, interp: [String]) {
        var j = start, hashes = 0
        while c[j] == "#" { hashes += 1; j += 1 }
        func at(_ k: Int, _ s: String) -> Bool { let a = Array(s); return k + a.count <= c.count && Array(c[k..<(k + a.count)]) == a }
        let quote = at(j, "\"\"\"") ? "\"\"\"" : "\"", close = quote + String(repeating: "#", count: hashes)
        j += quote.count
        var text = "", interp: [String] = []
        while j < c.count {
            if hashes == 0 && c[j] == "\\" && j + 1 < c.count {
                if c[j + 1] == "(" {
                    var depth = 0, k = j + 1
                    repeat {
                        if c[k] == "\"" { k = readLiteral(c, k).end; continue }
                        if c[k] == "(" { depth += 1 } else if c[k] == ")" { depth -= 1 }
                        k += 1
                    } while depth > 0 && k < c.count
                    interp.append(String(c[(j + 2)..<(k - 1)]))
                    j = k
                } else {
                    text.append(c[j]); text.append(c[j + 1]); j += 2
                }
                continue
            }
            if at(j, close) { return (j + close.count, text, interp) }
            text.append(c[j]); j += 1
        }
        return (j, text, interp)
    }

    /// Problems with the calls: what a translator has to fix, one line each.
    func problems() -> [String] {
        var out: [String] = []
        for call in calls {
            let where_ = "line \(call.line)"
            guard call.args.count == 4 else { out.append("\(where_): \(call.args.count) arguments, want en, ko, ja, zh"); continue }
            let names = ["en", "ko", "ja", "zh"]
            for (n, text) in zip(names, call.literals) where text.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append("\(where_): \(n) is empty")
            }
            let (en, ko, ja, zh) = (call.literals[0], call.literals[1], call.literals[2], call.literals[3])
            let quotesKorean = en.unicodeScalars.contains(where: Script.hangul)   // "The carrier (지게)": on purpose
            if !ko.unicodeScalars.contains(where: Script.hangul) { out.append("\(where_): ko has no Hangul: \(ko)") }
            if !ja.unicodeScalars.contains(where: { Script.kana($0) || Script.han($0) }) { out.append("\(where_): ja has no kana or kanji: \(ja)") }
            if !zh.unicodeScalars.contains(where: Script.han) { out.append("\(where_): zh has no Chinese characters: \(zh)") }
            if zh.unicodeScalars.contains(where: Script.kana) { out.append("\(where_): zh has Japanese kana: \(zh)") }
            for (n, text) in [("ja", ja), ("zh", zh)] where !quotesKorean && text.unicodeScalars.contains(where: Script.hangul) {
                out.append("\(where_): \(n) has Hangul: \(text)")
            }
            for (n, i) in zip(names.dropFirst(), call.interpolations.dropFirst()) where i != call.interpolations[0] {
                out.append("\(where_): \(n) shows other values than en: \(i) vs \(call.interpolations[0])")
            }
            let specs = call.args.map { arg in
                arg.hasPrefix("String(format:") ? arg.matches(of: #/%[0-9.]*[a-z@]/#).map { String($0.output) } : []
            }
            for (n, s) in zip(names.dropFirst(), specs.dropFirst()) where s != specs[0] {
                out.append("\(where_): \(n) format \(s) differs from en \(specs[0])")
            }
        }
        return out
    }
}

enum Script {
    static func hangul(_ u: Unicode.Scalar) -> Bool { (0xAC00...0xD7A3).contains(u.value) || (0x1100...0x11FF).contains(u.value) || (0x3130...0x318F).contains(u.value) }
    static func kana(_ u: Unicode.Scalar) -> Bool { (0x3040...0x30FF).contains(u.value) }
    static func han(_ u: Unicode.Scalar) -> Bool { (0x4E00...0x9FFF).contains(u.value) || (0x3400...0x4DBF).contains(u.value) }
}

@Suite struct Languages {
    @Test func everyStringIsTranslated() throws {
        var calls = 0, problems: [String] = []
        for f in try sourceFiles() {
            let scan = SourceStrings(f.text)
            calls += scan.calls.count
            problems += scan.problems().map { "\(f.name) \($0)" }
            // on purpose: the language's own name in the Language menu (Lang.name)
            problems += scan.strayHangul.filter { $0.text != "한국어" }.map { "\(f.name) line \($0.line): Korean-only string \"\($0.text)\"" }
            problems += scan.strayUI.map { "\(f.name) line \($0.line): untranslated UI string \"\($0.text)\"" }
        }
        #expect(calls > 200, "the scanner found only \(calls) L.t calls: is it still reading the sources?")
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test func theCheckCatchesMistakes() {
        let good = #"Text(L.t("Save", "저장", "保存", "保存")); let s = L.t("in \(m)m", "\(m)분 뒤", "\(m)分後", "\(m)分钟后")"#
        #expect(SourceStrings(good).problems().isEmpty)
        #expect(SourceStrings(good).calls.count == 2)
        let bad = [
            #"L.t("Save", "저장", "", "保存")"#,                               // empty
            #"L.t("Save", "저장", "Save", "保存")"#,                           // English copied into ja
            #"L.t("Save", "Save", "保存", "保存")"#,                           // English copied into ko
            #"L.t("Save", "저장", "保存", "保存する")"#,                        // Japanese in zh
            #"L.t("Save", "저장", "저장", "保存")"#,                           // Korean in ja
            #"L.t("in \(m)m", "\(m)분 뒤", "分後", "\(m)分钟后")"#,             // ja dropped the value
            #"L.t(String(format: "$%.2f", x), String(format: "$%.2f원", x), String(format: "$%d円", x), String(format: "$%.2f元", x))"#,
        ]
        for b in bad { #expect(!SourceStrings(b).problems().isEmpty, "\(b)") }
        #expect(SourceStrings(#"Text("저장") // "주석" "#).strayHangul.map(\.text) == ["저장"])
        #expect(SourceStrings(#"x(L.t("in \(m)m", "\(m)분 뒤", "\(m)分後", "\(m)分钟后", in: lang))"#).problems().isEmpty)
        #expect(!SourceStrings(#"x(L.t("Save", "저장", "保存", "", in: lang))"#).problems().isEmpty)
        // English handed straight to the UI is caught; symbols and translated strings are not
        #expect(SourceStrings(#"menu.addItem(MenuAction("Pause") { })"#).strayUI.map(\.text) == ["Pause"])
        #expect(SourceStrings(#"a.addButton(withTitle: "Cancel"); w.title = "Logbook""#).strayUI.count == 2)
        #expect(SourceStrings(#"Text("?"); Text("✓"); Text(L.t("Save", "저장", "保存", "保存")); log("Save")"#).strayUI.isEmpty)
        #expect(SourceStrings(##"let a = #""type":"저장""#; /* "삭제" */"##).strayHangul.count == 1)
    }

    @Test func settingPicksALanguage() {
        #expect(L.resolve("auto", system: ["ko-KR", "en-US"]) == .ko)
        #expect(L.resolve("auto", system: ["en-US", "ko-KR"]) == .en)
        #expect(L.resolve("auto", system: []) == .en)
        #expect(L.resolve("auto", system: ["fr-FR", "ko-KR"]) == .ko)       // the whole list, not just the first
        #expect(L.resolve("auto", system: ["ja-JP"]) == .ja)
        #expect(L.resolve("auto", system: ["zh-CN"]) == .zh)
        #expect(L.resolve("auto", system: ["zh-Hans-SG", "en"]) == .zh)
        #expect(L.resolve("auto", system: ["zh-Hant-TW", "en-US"]) == .en)   // Traditional is not given Simplified
        #expect(L.resolve("auto", system: ["zh-TW", "ja-JP"]) == .ja)
        #expect(L.resolve("ko", system: ["en-US"]) == .ko)
        #expect(L.resolve("en", system: ["ko-KR"]) == .en)
        #expect(L.resolve("ja", system: ["ko-KR"]) == .ja)
        #expect(L.resolve("zh", system: ["en-US"]) == .zh)
    }

    @Test func formatsFollowTheLanguage() {
        #expect(History.span(135 * 60, lang: .en) == "2h 15m" && History.span(135 * 60, lang: .zh) == "2小时15分")
        #expect(minutesLeft(12 * 60 + 50, lang: .zh) == "13分" && minutesLeft(30, lang: .ko) == "30초")
        #expect(Lang.allCases.map(\.locale.identifier) == ["en_US", "ko_KR", "ja_JP", "zh_CN"])
        // dates in the windows use the chosen language's locale, not the system's
        #expect(weekday(.en) == "Mon" && weekday(.ko) == "월" && weekday(.ja) == "月" && weekday(.zh) == "周一")
        #expect(Episode.bookTitle(13, lang: .ja) == "イタケへの帰郷" && Episode.bookTitle(25).isEmpty)
    }

    /// The pseudo-locale (`--lang pseudo` with `--render`) must really be longer, or it finds no truncation.
    @Test func pseudoLocaleIsLonger() {
        for s in ["Settings", "Quit", "Odysseus is rowing home", "OK"] {
            let p = L.stretch(s)
            #expect(Double(p.count) >= Double(s.count) * 1.4 && p.hasPrefix("[") && p.hasSuffix("]"), "\(p)")
        }
    }

    /// System Settings › Language & Region › Applications offers only what the bundle declares.
    @Test func bundleDeclaresEveryLanguage() throws {
        let script = try repoFile("build.sh")
        let declared = try #require(script.firstMatch(of: #/CFBundleLocalizations</key><array>(.*?)</array>/#)?.output.1)
        for l in Lang.allCases { #expect(declared.contains("<string>\(l.localization)</string>"), "\(l)") }
    }
}
