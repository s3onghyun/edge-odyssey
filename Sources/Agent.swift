import Foundation

enum AgentState: String, Equatable { case idle, working, waiting, limit }

/// One hook-written session. Extra lines deliberately leave the original first-line contract
/// readable by older app versions.
struct AgentSession: Equatable {
    var state: AgentState
    var timestamp: TimeInterval
    var cwd: String?
    var repo: String?
    var branch: String?

    var label: String? {
        guard let repo, !repo.isEmpty, let branch, !branch.isEmpty else { return nil }
        return String("\(repo)@\(branch)".prefix(120))
    }

    static func parse(_ text: String) -> AgentSession? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first?.split(whereSeparator: { $0 == " " || $0 == "\t" }), first.count >= 2,
              let state = AgentState(rawValue: String(first[0])), let timestamp = TimeInterval(first[1]) else { return nil }
        var values: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let space = line.firstIndex(of: " ") else { continue }
            values[String(line[..<space])] = String(line[line.index(after: space)...])
        }
        return AgentSession(state: state, timestamp: timestamp, cwd: values["cwd"], repo: values["repo"], branch: values["branch"])
    }
}

struct AgentStatus: Equatable {
    var state: AgentState = .idle
    var waitingCount = 0
    var latestLabel: String?

    static func summarize(_ sessions: [AgentSession], now: TimeInterval) -> AgentStatus {
        let fresh = sessions.filter { session in
            let age = now - session.timestamp
            switch session.state {
            case .waiting: return age < 12 * 3600
            case .working: return age < 20 * 60
            case .limit: return age < 5 * 3600
            case .idle: return false
            }
        }
        let waiting = fresh.filter { $0.state == .waiting }
        let state: AgentState = !waiting.isEmpty ? .waiting
            : fresh.contains(where: { $0.state == .limit }) ? .limit
            : fresh.contains(where: { $0.state == .working }) ? .working : .idle
        return AgentStatus(state: state, waitingCount: waiting.count,
                           latestLabel: fresh.sorted { $0.timestamp > $1.timestamp }.compactMap(\.label).first)
    }

    func label(or userLabel: String?) -> String? { userLabel ?? latestLabel }
}

/// Keeps waiting agents quiet during a break, then exposes their count exactly once when it ends.
struct BreakAgentSignal: Equatable {
    private(set) var held = false

    mutating func displayState(for status: AgentStatus, duringBreak: Bool) -> AgentState {
        guard duringBreak, status.waitingCount > 0 else { return status.state }
        held = true
        return status.state == .waiting ? .idle : status.state
    }

    mutating func breakEnded(with status: AgentStatus) -> Int? {
        defer { held = false }
        return held && status.waitingCount > 0 ? status.waitingCount : nil
    }
}

/// Watches the tiny state files written by the Claude Code and Codex hooks in hooks/.
///
///   <dir>/sessions/<session_id>   "<working|waiting|limit> <epoch>"   (one per session)
///   <dir>/usage                   "<five_hour_used_percent> <epoch>"  (from the status line)
///
/// A directory vnode source wakes us when a hook renames a file into place, so there is
/// no polling beyond a once-a-minute expiry sweep.
final class AgentWatcher {
    let dir: URL
    var limitPercent = 85.0
    var onChange: ((AgentStatus) -> Void)?
    var log: ((String) -> Void)?
    private(set) var status = AgentStatus()
    var state: AgentState { status.state }
    private var sources: [DispatchSourceFileSystemObject] = []
    private var sweep: Timer?

    init(dir: URL) { self.dir = dir }

    var sessionsDir: URL { dir.appendingPathComponent("sessions") }

    func start() {
        try? FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        for d in [sessionsDir, dir] {   // sessions/ for hook states, the parent for "usage"
            let fd = open(d.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
            src.setEventHandler { [weak self] in self?.reload() }
            src.setCancelHandler { close(fd) }
            src.resume()
            sources.append(src)
        }
        sweep = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.reload() }
        sweep?.tolerance = 20
        reload()
    }

    func reload() {
        let now = Date().timeIntervalSince1970
        var sessions: [AgentSession] = []
        let files = (try? FileManager.default.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil)) ?? []
        for f in files where !f.lastPathComponent.hasPrefix(".") {
            guard let text = try? String(contentsOf: f, encoding: .utf8) else { continue }
            if let session = AgentSession.parse(text) { sessions.append(session) }
        }
        var next = AgentStatus.summarize(sessions, now: now)
        if let u = try? String(contentsOf: dir.appendingPathComponent("usage"), encoding: .utf8) {
            let p = u.split(whereSeparator: { $0 == " " || $0 == "\n" })
            if p.count >= 2, let pct = Double(p[0]), let ts = Double(p[1]), now - ts < 5 * 3600, pct >= limitPercent {
                next.state = next.state == .waiting ? .waiting : .limit
            }
        }
        if next != status {
            status = next
            log?("agent: \(next.state.rawValue) waiting=\(next.waitingCount)")
            onChange?(next)
        }
    }
}
