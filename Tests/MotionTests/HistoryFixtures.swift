import Foundation
@testable import EdgeMotion

// Date helpers for HistoryTests, kept apart: with only the Command Line Tools, a file that imports
// both Testing and Foundation needs a cross-import overlay that isn't installed.

func cal(_ tz: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: tz)!
    return c
}

func at(_ s: String, _ tz: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: tz)!
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

func run(_ from: String, _ to: String, _ tz: String, minutes: Double? = nil, done: Bool = true) -> Voyage {
    let a = at(from, tz), b = at(to, tz)
    return Voyage(start: a, end: b, mode: "focus", seconds: (minutes ?? b.timeIntervalSince(a) / 60) * 60, completed: done)
}

func zone(_ tz: String) -> TimeZone { TimeZone(identifier: tz)! }

/// A fresh file path in a new temporary folder.
func scratchFile() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("edge-odyssey-tests-\(UUID().uuidString)")
    return dir.appendingPathComponent("history.jsonl")
}

func appendText(_ s: String, to url: URL) {
    let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    try? (old + s).write(to: url, atomically: true, encoding: .utf8)
}
