import Testing
@testable import EdgeMotion

@Test func agentStateFileKeepsCwdAndGitMetadata() {
    let session = AgentSession.parse("waiting 1234\ncwd /work/edge odyssey\nrepo edge-odyssey\nbranch fix/agent-signal\n")
    #expect(session == AgentSession(state: .waiting, timestamp: 1234, cwd: "/work/edge odyssey", repo: "edge-odyssey", branch: "fix/agent-signal"))
    #expect(session?.label == "edge-odyssey@fix/agent-signal")
}

@Test func oldStateFilesStillParseWithoutMetadata() {
    let session = AgentSession.parse("working 1234\n")
    #expect(session == AgentSession(state: .working, timestamp: 1234, cwd: nil, repo: nil, branch: nil))
    #expect(session?.label == nil)
}

@Test func latestActiveAgentFillsOnlyAnEmptyLabel() {
    let sessions = [
        AgentSession(state: .working, timestamp: 900, cwd: "/work/old", repo: "old", branch: "main"),
        AgentSession(state: .waiting, timestamp: 990, cwd: "/work/new", repo: "new", branch: "fix/label"),
    ]
    let status = AgentStatus.summarize(sessions, now: 1_000)
    #expect(status.waitingCount == 1)
    #expect(status.latestLabel == "new@fix/label")
    #expect(status.label(or: nil) == "new@fix/label")
    #expect(status.label(or: "Write release notes") == "Write release notes")
}

@Test func waitingAgentsAreHeldDuringBreakAndAnnouncedOnceAfterward() {
    var signal = BreakAgentSignal()
    let waiting = AgentStatus(state: .waiting, waitingCount: 2, latestLabel: "edge@main")
    #expect(signal.displayState(for: waiting, duringBreak: true) == .idle)
    #expect(signal.breakEnded(with: waiting) == 2)
    #expect(signal.breakEnded(with: waiting) == nil)
    #expect(signal.displayState(for: waiting, duringBreak: false) == .waiting)
}

@Test func resolvedAgentDoesNotGetAnnouncedAfterBreak() {
    var signal = BreakAgentSignal()
    _ = signal.displayState(for: AgentStatus(state: .waiting, waitingCount: 1), duringBreak: true)
    #expect(signal.breakEnded(with: AgentStatus()) == nil)
}

@Test func breakWaitingMessageUsesTheExistingFriendlyTone() {
    #expect(agentWaitingMessage(count: 2, lang: .en).body == "2 agents are waiting for you")
    #expect(agentWaitingMessage(count: 2, lang: .ko).body == "에이전트 2개가 기다려요")
}
