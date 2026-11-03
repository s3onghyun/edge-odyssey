import Foundation

/// A release version in SemVer order: MAJOR.MINOR.PATCH, then the prerelease (1.0.0-rc.1 < 1.0.0).
/// A leading "v" is fine and build metadata ("+abc") is ignored. A `git describe` tail
/// ("0.2.0-3-gabc1234", 3 commits after v0.2.0) sorts after its tag, so a development build is
/// not offered the release it already contains. Anything else is nil.
struct SemVer: Comparable, CustomStringConvertible {
    let core: [Int]
    let pre: [String]
    /// Commits after the tag, from a `git describe` tail; 0 for a release.
    var ahead = 0

    init?(_ text: String) {
        var s = Substring(text.trimmingCharacters(in: .whitespaces))
        if s.first == "v" || s.first == "V" { s = s.dropFirst() }
        if let plus = s.firstIndex(of: "+") { s = s[..<plus] }
        let dash = s.firstIndex(of: "-")
        let nums = s[..<(dash ?? s.endIndex)].split(separator: ".", omittingEmptySubsequences: false)
        let core = nums.compactMap { $0.allSatisfy(\.isASCII) ? Int($0) : nil }
        guard nums.count == 3, core.count == 3, core.allSatisfy({ $0 >= 0 }) else { return nil }
        var pre = dash.map { s[s.index(after: $0)...].split(separator: ".", omittingEmptySubsequences: false).map(String.init) } ?? []
        guard pre.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") } }) else { return nil }
        if pre.count == 1, let m = pre[0].wholeMatch(of: #/(\d+)-g[0-9a-f]{4,40}(-dirty)?/#), let n = Int(m.output.1) {
            ahead = n
            pre = []
        }
        self.core = core
        self.pre = pre
    }

    var description: String { core.map(String.init).joined(separator: ".") + (pre.isEmpty ? "" : "-" + pre.joined(separator: ".")) }

    static func < (a: SemVer, b: SemVer) -> Bool {
        if a.core != b.core { return a.core.lexicographicallyPrecedes(b.core) }
        if a.pre.isEmpty && b.pre.isEmpty { return a.ahead < b.ahead }
        if a.pre.isEmpty || b.pre.isEmpty { return !a.pre.isEmpty && b.pre.isEmpty }   // a release beats its prereleases
        for (x, y) in zip(a.pre, b.pre) where x != y {
            switch (Int(x), Int(y)) {
            case let (i?, j?): return i < j
            case (.some, nil): return true    // numbers sort before words
            case (nil, .some): return false
            case (nil, nil): return x < y
            }
        }
        return a.pre.count < b.pre.count
    }
}

/// The update notice. One HTTPS GET to GitHub's latest-release API, at most once a day (or when
/// asked), with no cookies, no cache and only the headers below. Nothing is downloaded or
/// installed: the notice opens the release page, and the user replaces the app as on the first
/// install (README). A self-updater is left out until it can be proven safe: with ad-hoc signing
/// a signature check proves nothing, and a checksum from the same release only catches corruption.
enum Update {
    static let latestAPI = URL(string: "https://api.github.com/repos/s3onghyun/edge-odyssey/releases/latest")!
    static let interval: TimeInterval = 86_400

    /// Built from the version (release.yml tags `v<version>`), never taken from the API's answer.
    static func page(_ v: SemVer) -> URL { URL(string: "https://github.com/s3onghyun/edge-odyssey/releases/tag/v\(v)")! }

    /// A failed check counts as the day's check; a clock moved backwards checks again.
    static func isDue(now: Date, last: Date?) -> Bool {
        guard let last else { return true }
        return now < last || now.timeIntervalSince(last) >= interval
    }

    /// The `releases/latest` answer -> its version. Drafts, prereleases and tags that are not versions -> nil.
    static func parse(_ data: Data) -> SemVer? {
        struct Release: Decodable { let tag_name: String; let draft: Bool?; let prerelease: Bool? }
        guard data.count <= 1 << 20, let r = try? JSONDecoder().decode(Release.self, from: data),
              r.draft != true, r.prerelease != true, let v = SemVer(r.tag_name), v.ahead == 0 else { return nil }
        return v
    }

    /// What to show: a version newer than this one that the user has not skipped.
    static func offer(current: SemVer?, latest: SemVer?, skipped: String?) -> SemVer? {
        guard let current, let latest, current < latest, latest.description != skipped else { return nil }
        return latest
    }

    /// The fixed language header: URLSession would otherwise send the system's languages.
    static func headers(_ v: SemVer) -> [String: String] {
        ["User-Agent": "EdgeOdyssey/\(v)", "Accept": "application/vnd.github+json", "Accept-Language": "en"]
    }
}
