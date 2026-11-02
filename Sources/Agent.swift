import Foundation

/// Watches the tiny state files written by the Claude Code hooks in hooks/.
///
///   <dir>/sessions/<session_id>   "<working|waiting|limit> <epoch>"   (one per session)
///   <dir>/usage                   "<five_hour_used_percent> <epoch>"  (from the status line)
///
/// A directory vnode source wakes us when a hook renames a file into place, so there is
/// no polling beyond a once-a-minute expiry sweep.
final class AgentWatcher {
    let dir: URL
    var limitPercent = 85.0
    var onChange: ((AgentState) -> Void)?
    var log: ((String) -> Void)?
    private(set) var state: AgentState = .idle
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
        var waiting = false, working = false, limit = false
        let files = (try? FileManager.default.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil)) ?? []
        for f in files where !f.lastPathComponent.hasPrefix(".") {
            guard let text = try? String(contentsOf: f, encoding: .utf8) else { continue }
            let p = text.split(whereSeparator: { $0 == " " || $0 == "\n" })
            guard p.count >= 2, let ts = Double(p[1]) else { continue }
            let age = now - ts
            switch p[0] {
            case "waiting" where age < 12 * 3600: waiting = true
            case "working" where age < 20 * 60: working = true
            case "limit" where age < 5 * 3600: limit = true
            default: break
            }
        }
        if let u = try? String(contentsOf: dir.appendingPathComponent("usage"), encoding: .utf8) {
            let p = u.split(whereSeparator: { $0 == " " || $0 == "\n" })
            if p.count >= 2, let pct = Double(p[0]), let ts = Double(p[1]), now - ts < 5 * 3600, pct >= limitPercent {
                limit = true
            }
        }
        let s: AgentState = waiting ? .waiting : limit ? .limit : working ? .working : .idle
        if s != state {
            state = s
            log?("agent: \(s.rawValue)")
            onChange?(s)
        }
    }
}
