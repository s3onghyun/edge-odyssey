import Foundation
import Testing
@testable import EdgeMotion

// Agent-state narration (StreamMode.narration, BrowserSource.Snapshot.agent/narration): what
// viewers of a stream are told about the coding agent. Only the state, never the project.

@Suite struct NarrationTests {
    @Test func eachStateHasOneLineInEveryLanguage() {
        #expect(StreamMode.narration(.idle) == nil)   // idle: nothing shows
        for l in Lang.allCases {
            #expect(StreamMode.narration(.idle, lang: l) == nil)
            let lines = [AgentState.working, .waiting, .limit].compactMap { StreamMode.narration($0, lang: l) }
            #expect(lines.count == 3 && Set(lines).count == 3, "\(l)")
            for line in lines { #expect(line.count <= 40, "\(l): \(line)") }   // a chip, not a sentence
        }
        #expect(StreamMode.narration(.working, lang: .en) == "⛵ Claude rowing…")
        #expect(StreamMode.narration(.waiting, lang: .en) == "🎶 Sirens: Claude needs you")
        #expect(StreamMode.narration(.limit, lang: .en) == "⛈ Near the usage limit")
        #expect(StreamMode.narration(.working, lang: .ko) == "⛵ Claude 노 젓는 중…")
    }

    @Test func narrationFollowsTheSignals() {
        for s in [AgentState.idle, .working, .waiting, .limit] {
            #expect(StreamMode.narratedState(s, agentEnabled: true) == s)
            #expect(StreamMode.narratedState(s, agentEnabled: false) == .idle)   // signals off
        }
    }

    @Test func narrationFollowsTheEdgesBreakHold() {
        // A waiting agent stays quiet on the edge during a break; the narration says nothing either.
        var hold = BreakAgentSignal()
        let status = AgentStatus(state: .waiting, waitingCount: 1, latestLabel: "edge-odyssey@main")
        let shown = hold.displayState(for: status, duringBreak: true)
        #expect(shown == .idle && StreamMode.narration(StreamMode.narratedState(shown, agentEnabled: true)) == nil)
        #expect(StreamMode.narration(hold.displayState(for: status, duringBreak: false)) == "🎶 Sirens: Claude needs you")
    }

    /// A hook session whose repo, branch, folder and id must never reach a viewer.
    @Test func noProjectDetailEverReachesTheHUDOrTheOverlay() throws {
        let repo = "secret-repo-xyz", branch = "feature/hidden-branch-42", cwd = "/Users/someone/work/secret-repo-xyz"
        let sessionID = "5f1c0de0-aaaa-bbbb-cccc-0123456789ab"
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("narration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let now = Date().timeIntervalSince1970
        var leaks: [String] = []
        for state in ["working", "waiting", "limit"] {
            try "\(state) \(Int(now))\ncwd \(cwd)\nrepo \(repo)\nbranch \(branch)\n"
                .write(to: dir.appendingPathComponent(sessionID), atomically: true, encoding: .utf8)
            let sessions = AgentWatcher.sessions(in: dir)
            let status = AgentStatus.summarize(sessions, now: now)
            #expect(status.latestLabel == "\(repo)@\(branch)")   // the fixture does carry them
            let agent = StreamMode.narratedState(status.state, agentEnabled: true)
            #expect(agent.rawValue == state)
            for lang in Lang.allCases {
                let narration = StreamMode.narration(agent, lang: lang)
                #expect(narration != nil)
                let hud = [StreamMode.hudText(mode: .pomodoro, phase: .focus, restIsLong: false, clock: "18:32", paused: false,
                                              session: (2, 4), lang: lang), narration].compactMap { $0 }.joined(separator: "\n")
                let snapshots = [Phase.idle, .focus].map {
                    BrowserSource.snapshot(mode: .pomodoro, phase: $0, restIsLong: false, duration: 1500, elapsed: 60, paused: false,
                                           focusCount: 2, longEvery: 4, lang: lang, agent: agent)
                }
                let json = snapshots.map(BrowserSource.json).joined(separator: "\n")
                let page = BrowserSource.page(sprites: BrowserSource.Sprites(width: 32, height: 26))
                let served = BrowserSource.reply(to: "GET /events HTTP/1.1\r\nHost: 127.0.0.1:47213\r\n", port: 47213,
                                                 state: { BrowserSource.json(snapshots[1]) }, page: { page })
                guard case .stream(let head) = served else { Issue.record("no event stream"); continue }
                for (what, text) in [("hud", hud), ("json", json), ("page", page), ("events", String(decoding: head, as: UTF8.self))] {
                    for secret in [repo, branch, "\(repo)@\(branch)", cwd, sessionID, "hidden-branch", "secret-repo"] where text.contains(secret) {
                        leaks.append("\(state) \(lang) \(what): \(secret)")
                    }
                }
            }
        }
        #expect(leaks.isEmpty, "\(leaks.joined(separator: "\n"))")
    }
}
