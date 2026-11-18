import Foundation
import Testing
@testable import EdgeMotion

private func scratchDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("edge-odyssey-state-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func mode(_ url: URL) -> Int? {
    (try? FileManager.default.attributesOfItem(atPath: url.path))?[.posixPermissions] as? Int
}

@Test func firstDuplicateKeyLineWinsInAStateFile() {
    let session = AgentSession.parse("working 1234\nrepo real\nbranch main\nrepo forged\nbranch forged\n")
    #expect(session?.repo == "real")
    #expect(session?.branch == "main")
}

@Test func onlySmallRegularSessionFilesAreRead() throws {
    let state = scratchDir()
    defer { try? FileManager.default.removeItem(at: state) }
    let sessions = state.appendingPathComponent("sessions")
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    try "waiting 1234\nrepo real\n".write(to: sessions.appendingPathComponent("real"), atomically: true, encoding: .utf8)
    // oversized: a valid first line followed by 1 MiB of padding
    try ("working 1234\n" + String(repeating: "x", count: 1 << 20)).write(to: sessions.appendingPathComponent("big"), atomically: true, encoding: .utf8)
    // a symlink to a valid state file outside sessions/
    let outside = state.appendingPathComponent("outside")
    try "working 1234\n".write(to: outside, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(at: sessions.appendingPathComponent("link"), withDestinationURL: outside)
    // a FIFO with no writer: reading it the old way blocks forever
    #expect(mkfifo(sessions.appendingPathComponent("fifo").path, 0o600) == 0)
    try FileManager.default.createDirectory(at: sessions.appendingPathComponent("subdir"), withIntermediateDirectories: true)

    let started = Date()
    let found = AgentWatcher.sessions(in: sessions)
    #expect(Date().timeIntervalSince(started) < 1)
    #expect(found == [AgentSession(state: .waiting, timestamp: 1234, cwd: nil, repo: "real", branch: nil)])
    #expect(StateFiles.readSmall(sessions.appendingPathComponent("big")) == nil)
    #expect(StateFiles.readSmall(sessions.appendingPathComponent("link")) == nil)
    #expect(StateFiles.readSmall(outside) == "working 1234\n")
}

@Test func stateFolderAndFilesAreThisAccountsOnly() throws {
    let state = scratchDir()
    defer { try? FileManager.default.removeItem(at: state) }
    // an older version left the folder and the history world-readable
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: state.path)
    let historyURL = state.appendingPathComponent("history.jsonl")
    try "".write(to: historyURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: historyURL.path)

    let history = HistoryLog(url: historyURL)
    #expect(mode(historyURL) == 0o600)
    history.append(run("2026-11-03 09:00", "2026-11-03 09:25", "UTC"))
    #expect(mode(historyURL) == 0o600)
    #expect(mode(state) == 0o700)

    let fresh = state.appendingPathComponent("new").appendingPathComponent("history.jsonl")
    HistoryLog(url: fresh).append(run("2026-11-03 09:00", "2026-11-03 09:25", "UTC"))   // the atomic-write path
    #expect(mode(fresh) == 0o600)
    #expect(mode(fresh.deletingLastPathComponent()) == 0o700)

    let logbookURL = state.appendingPathComponent("logbook.json")
    Logbook(url: logbookURL).record(.cyclops)
    #expect(mode(logbookURL) == 0o600)

    let sessions = state.appendingPathComponent("sessions")
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
    StateFiles.makePrivateDirectory(sessions)
    #expect(mode(sessions) == 0o700)
}

@Test func customStateDirSnippetStaysValidJSON() throws {
    let snippet = try String(contentsOf: repoRoot.appendingPathComponent("hooks/claude-settings-snippet.json"), encoding: .utf8)
    let path = "/Users/me/it's \"odd\" back\\slash dir"
    let rewritten = HookSnippet.rewrite(snippet, stateDir: path)
    let json = try #require(try JSONSerialization.jsonObject(with: Data(rewritten.utf8)) as? [String: Any])
    let hooks = try #require(json["hooks"] as? [String: Any])
    let entry = try #require((hooks["UserPromptSubmit"] as? [[String: Any]])?.first?["hooks"] as? [[String: Any]])
    let command = try #require(entry.first?["command"] as? String)
    let quoted = "'/Users/me/it'\\''s \"odd\" back\\slash dir'"
    #expect(command == "EDGE_ODYSSEY_STATE_DIR=\(quoted) \(quoted)/hooks/edge-odyssey-hook.sh working")
    #expect(!rewritten.contains(HookSnippet.defaultHooksPath))

    // the shell reads the quoted path back as exactly the original path
    let sh = Process()
    sh.executableURL = URL(fileURLWithPath: "/bin/sh")
    sh.arguments = ["-c", "printf '%s' \(quoted)"]
    let out = Pipe()
    sh.standardOutput = out
    try sh.run()
    sh.waitUntilExit()
    #expect(String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) == path)
}
