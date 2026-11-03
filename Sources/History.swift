import Foundation

/// One run of the clock, kept in the local history: a Pomodoro focus, a countdown timer or a
/// stopwatch, finished or stopped early. Breaks are not recorded.
struct Voyage: Codable, Equatable {
    var start: Date
    var end: Date
    var mode: String          // "focus", "timer" or "stopwatch"
    var seconds: Double       // time on the clock, pauses left out
    var completed: Bool       // ran to the end (a stopwatch counts as completed when stopped)
    var label: String?
}

/// Totals for one day.
struct DaySummary: Equatable {
    var seconds = 0.0         // all clock time that fell on this day
    var sessions = 0          // runs that started this day
    var longest = 0.0         // the longest single run that started this day
}

enum History {
    /// A league for every five minutes at the oar: twelve an hour.
    static func leagues(_ seconds: Double) -> Int { Int(max(seconds, 0) / 300) }

    /// How much of `v`'s clock time fell inside `day` (a start-of-day). A run over midnight is
    /// split in proportion to the wall time on each side, so pauses count evenly.
    static func seconds(of v: Voyage, on day: Date, calendar: Calendar) -> Double {
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return 0 }
        let wall = v.end.timeIntervalSince(v.start)
        guard wall > 0 else { return (day..<next).contains(v.start) ? v.seconds : 0 }
        let overlap = min(v.end, next).timeIntervalSince(max(v.start, day))
        return overlap > 0 ? v.seconds * overlap / wall : 0
    }

    static func summary(_ records: [Voyage], on date: Date, calendar: Calendar) -> DaySummary {
        let day = calendar.startOfDay(for: date)
        var s = DaySummary()
        for v in records {
            s.seconds += seconds(of: v, on: day, calendar: calendar)
            if calendar.isDate(v.start, inSameDayAs: day) {
                s.sessions += 1
                s.longest = max(s.longest, v.seconds)
            }
        }
        return s
    }

    /// The last `count` days up to and including the day of `date`, oldest first: (start of day, seconds).
    static func days(_ records: [Voyage], endingOn date: Date, count: Int, calendar: Calendar) -> [(day: Date, seconds: Double)] {
        let last = calendar.startOfDay(for: date)
        return (0..<count).reversed().compactMap { back in
            guard let d = calendar.date(byAdding: .day, value: -back, to: last) else { return nil }
            return (d, records.reduce(0) { $0 + seconds(of: $1, on: d, calendar: calendar) })
        }
    }

    /// Spreadsheet text: one row per run, local times with their offset. A label that a
    /// spreadsheet would read as a formula is prefixed with an apostrophe.
    static func csv(_ records: [Voyage], timeZone: TimeZone) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = timeZone
        func cell(_ s: String) -> String {
            let safe = s.first.map { "=+-@\t\r".contains($0) } == true ? "'" + s : s
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let rows = records.map { v in
            [f.string(from: v.start), f.string(from: v.end), v.mode, String(format: "%.1f", v.seconds / 60),
             v.completed ? "yes" : "no", cell(v.label ?? "")].joined(separator: ",")
        }
        return (["start,end,mode,minutes,completed,label"] + rows).joined(separator: "\n") + "\n"
    }
}

extension History {
    /// "2h 15m", "45m", "0m": whole minutes, rounded down.
    static func span(_ seconds: Double) -> String {
        let m = Int(max(seconds, 0) / 60)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}

/// The history file: one JSON object per line, appended as each run ends. It stays on this Mac.
/// A line that can't be read (a crash mid-write, a hand edit) is skipped, not fatal.
final class HistoryLog {
    let url: URL
    private(set) var records: [Voyage] = []

    init(url: URL) {
        self.url = url
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        records = text.split(separator: "\n").compactMap { try? dec.decode(Voyage.self, from: Data($0.utf8)) }
    }

    func append(_ v: Voyage) {
        records.append(v)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = .sortedKeys
        guard var line = try? enc.encode(v) else { return }
        line.append(0x0A)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: line)
        } else {
            try? line.write(to: url, options: .atomic)
        }
    }

    func clear() {
        records = []
        try? FileManager.default.removeItem(at: url)
    }
}
