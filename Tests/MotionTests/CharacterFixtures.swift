import Foundation

// File reading for CharacterTests, kept apart for the same reason as HistoryFixtures.

/// The animation names a character declares (`anim: <name> ...` in character.txt or a .sprite).
func animations(_ path: String) throws -> [String] {
    try repoFile(path).split(separator: "\n").compactMap { line in
        line.hasPrefix("anim:") ? line.dropFirst(5).split(separator: " ").first.map(String.init) : nil
    }
}

/// The SVG frames a vector character's character.txt lists that are not in its folder.
func missingFrames(_ id: String) throws -> [String] {
    try repoFile("assets/characters/\(id)/character.txt")
        .split(whereSeparator: { $0 == "," || $0 == "=" || $0.isWhitespace }).map(String.init)
        .filter { $0.hasSuffix(".svg") && !FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("assets/characters/\(id)/\($0)").path) }
}
