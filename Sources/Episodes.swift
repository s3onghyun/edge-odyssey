import Foundation

/// Short encounters from Homer's Odyssey (public domain). They decorate the voyage only:
/// they never change where the traveler is at a given time, never take input, and are
/// collected in a local logbook of the poem's 24 books.
enum Episode: String, CaseIterable {
    case cyclops, aeolus, whirlpool, circe, owl, lotus, sirens, storm, calypso, ithaca

    /// Books of the Odyssey this encounter belongs to.
    var books: [Int] {
        switch self {
        case .owl: return [1]
        case .calypso, .storm: return [5]
        case .lotus, .cyclops: return [9]
        case .aeolus, .circe: return [10]
        case .sirens, .whirlpool: return [12]
        case .ithaca: return [13, 17]
        }
    }

    static let bookTitles: [Int: String] = [
        1: "Athena's owl", 5: "Calypso and Poseidon's storm", 9: "The Lotus-eaters and the Cyclops",
        10: "Aeolus' winds and Circe", 12: "The Sirens, Scylla and Charybdis", 13: "Home to Ithaca",
        17: "Old Argos",
    ]
}

/// Deterministic per-session randomness, so a session's encounters can be reproduced.
struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func chance(_ p: Double) -> Bool { Double(next() % 10_000) / 10_000 < p }
}

/// Which encounters a focus lap gets, and when (as a share of the lap).
enum EpisodePlanner {
    static func plan(seed: UInt64, journey j: Journey, focusSeconds: TimeInterval, lastFiveShare: Double,
                     forced: [Episode]?) -> [(Episode, Double)] {
        let m = j.timeMarks
        let at: [Episode: Double] = [
            .cyclops: m[0] + 0.12 * (m[1] - m[0]),          // early on the floor: eye, boulder, then the ram
            .circe: m[1] + 0.06 * (m[2] - m[1]),            // piglets follow him up the cliff
            .aeolus: m[2] + 0.35 * (m[3] - m[2]),           // a gust along the ceiling
            .whirlpool: max(m[3] - 0.5 / focusSeconds, m[2]), // spun round the top-left corner
            .owl: max(1 - lastFiveShare, 0.75),             // last minutes: Athena guides him home
        ]
        var picks: [Episode]
        if let forced { picks = forced.filter { at[$0] != nil } } else {
            var rng = SplitMix64(state: seed)
            picks = [rng.chance(0.5) ? Episode.cyclops : .circe]
            if rng.chance(0.6) { picks.append(.aeolus) }
            if rng.chance(0.5) { picks.append(.whirlpool) }
            if rng.chance(0.25) { picks.append(picks.contains(.cyclops) ? .circe : .cyclops) }
            picks.append(.owl)
        }
        return picks.compactMap { e in at[e].map { (e, $0) } }.sorted { $0.1 < $1.1 }
    }
}

/// Collected books, stored as small JSON next to the agent state (local only).
final class Logbook {
    private let url: URL
    private(set) var found: [Int: Date] = [:]
    var onNew: ((Int) -> Void)?

    init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let raw = try? JSONDecoder().decode([String: Double].self, from: data) {
            for (k, v) in raw { if let b = Int(k) { found[b] = Date(timeIntervalSince1970: v) } }
        }
    }

    func record(_ e: Episode) {
        var changed = false
        for b in e.books where found[b] == nil {
            found[b] = Date()
            changed = true
            onNew?(b)
        }
        guard changed else { return }
        let raw = Dictionary(uniqueKeysWithValues: found.map { (String($0.key), $0.value.timeIntervalSince1970) })
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(raw).write(to: url, options: .atomic)
    }
}
