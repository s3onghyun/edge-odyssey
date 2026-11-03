import Foundation

// Source reading for SettingsTests, kept apart for the same reason as HistoryFixtures.

/// App.control's cases in Sources/main.swift: each command and the UserDefaults keys its case line saves.
/// A case only for the bare command (`case "rest" where arg.isEmpty`) is skipped, as the first case of a repeated name wins: the window always sends a value.
struct ControlCases {
    private(set) var keys: [String: [String]] = [:]

    init(_ main: String) throws {
        guard let a = main.range(of: "func control("), let b = main.range(of: "// MARK: status item", range: a.upperBound..<main.endIndex) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let saved = try NSRegularExpression(pattern: #"(?:remember\(|forKey: )"([A-Za-z0-9.]+)""#)
        var name: String?
        for line in main[a.upperBound..<b.lowerBound].split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if line.hasPrefix("case \"") {   // a case runs until the next one
                let n = String(line.dropFirst(6).prefix { $0 != "\"" })
                name = line.contains("where arg.isEmpty") || keys[n] != nil ? nil : n
                if let name { keys[name] = [] }
            }
            guard let name else { continue }
            keys[name]! += saved.matches(in: line, range: NSRange(line.startIndex..., in: line)).map { String(line[Range($0.range(at: 1), in: line)!]) }
        }
    }
}

/// The control commands a piece of source sends: `"name:…"`, `bind(…, "name")`, `cmd: "name"`, `send("name")`, `control("name")`.
func sentCommands(_ text: String, known: Set<String>) -> Set<String> {
    let re = try! NSRegularExpression(pattern: #""([a-z][a-z0-9-]*):|, "([a-z][a-z0-9-]*)"\)|cmd: "([a-z][a-z0-9-]*)"|(?:send|control)\("([a-z][a-z0-9-]*)"\)"#)
    var out = Set<String>()
    for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
        for g in 1...4 { if let r = Range(m.range(at: g), in: text) { out.insert(String(text[r])) } }
    }
    return out.intersection(known)
}

/// The text between two markers of a file (the menu builder in main.swift).
func between(_ text: String, _ from: String, _ to: String) -> String {
    guard let a = text.range(of: from), let b = text.range(of: to, range: a.upperBound..<text.endIndex) else { return "" }
    return String(text[a.lowerBound..<b.lowerBound])
}
