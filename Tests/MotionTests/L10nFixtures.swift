import Foundation
@testable import EdgeMotion

// Foundation helpers for L10nTests and UpdateTests, kept apart for the same reason as HistoryFixtures.

let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized

/// A file of this repository, as text ("build.sh", ".github/workflows/release.yml").
func repoFile(_ path: String) throws -> String { try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8) }

/// Every Swift file in Sources/: (file name, text).
func sourceFiles() throws -> [(name: String, text: String)] {
    try FileManager.default.contentsOfDirectory(at: repoRoot.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "swift" }
        .map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
}

/// Monday 2026-11-02 (UTC) as the history chart labels it in `l`.
func weekday(_ l: Lang) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return Date(timeIntervalSince1970: 1_793_620_800).formatted(Date.FormatStyle(calendar: cal, timeZone: cal.timeZone).weekday(.abbreviated).locale(l.locale))
}

func instant(_ t: Double) -> Date { Date(timeIntervalSince1970: t) }

/// A `releases/latest` answer; html_url points elsewhere on purpose.
func releaseJSON(_ tag: String, draft: Bool = false, pre: Bool = false) -> Data {
    Data(#"{"tag_name":"\#(tag)","draft":\#(draft),"prerelease":\#(pre),"html_url":"https://evil.example/","body":"x"}"#.utf8)
}

func bytes(_ s: String) -> Data { Data(s.utf8) }
func oversized() -> Data { Data(count: (1 << 20) + 1) }
