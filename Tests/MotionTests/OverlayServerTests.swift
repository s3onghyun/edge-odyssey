#if canImport(Network)
import Foundation
import Network
import Testing
@testable import EdgeMotion

// The browser-source overlay's listener (Sources/OverlayServer.swift), on a real socket: it binds
// 127.0.0.1 only, answers over loopback and nowhere else, streams to several clients, and closes
// everything when turned off.

@Suite(.serialized) struct OverlayServerTests {
    struct Timeout: Error {}
    struct Failed: Error { let why: String }

    /// Runs `body`, failing after `seconds` instead of hanging the suite.
    func within<T: Sendable>(_ seconds: Double, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { g in
            g.addTask { try await body() }
            g.addTask { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)); throw Timeout() }
            defer { g.cancelAll() }
            return try await g.next()!
        }
    }

    /// A server on a free port, listening.
    func running() async throws -> (OverlayServer, Int) {
        let server = OverlayServer(port: 0, callbacks: DispatchQueue(label: "overlay-test"))
        let port: Int = try await within(10) {
            try await withCheckedThrowingContinuation { (k: CheckedContinuation<Int, Error>) in
                let once = NSLock()
                var done = false
                func finish(_ r: Result<Int, Error>) {
                    once.lock(); defer { once.unlock() }
                    if !done { done = true; k.resume(with: r) }
                }
                server.onReady = { finish(.success($0)) }
                server.onFailure = { finish(.failure(Failed(why: "\($0)"))) }
                server.start()
            }
        }
        return (server, port)
    }

    /// Whether a TCP connection to `ip`:`port` is accepted.
    func connects(_ ip: String, _ port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        a.sin_family = sa_family_t(AF_INET)
        a.sin_port = in_port_t(UInt16(port).bigEndian)
        guard inet_pton(AF_INET, ip, &a.sin_addr) == 1 else { return false }
        return withUnsafePointer(to: &a) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        } == 0
    }

    /// This Mac's IPv4 addresses other than loopback (Wi-Fi, Ethernet, VPN).
    func otherAddresses() -> [String] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }
        var out: [String] = []
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let sa = p.pointee.ifa_addr, sa.pointee.sa_family == sa_family_t(AF_INET),
                  Int32(p.pointee.ifa_flags) & IFF_LOOPBACK == 0 else { continue }
            var addr = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
            out.append(String(cString: buf))
        }
        return out
    }

    @Test func listenerParametersAreLoopbackOnly() throws {
        let p = OverlayServer.parameters(port: BrowserSource.defaultPort)
        guard case .hostPort(let host, let port)? = p.requiredLocalEndpoint else {
            Issue.record("no required local endpoint: \(String(describing: p.requiredLocalEndpoint))")
            return
        }
        #expect(host == .ipv4(.loopback))
        #expect(port.rawValue == UInt16(BrowserSource.defaultPort))
        #expect(p.requiredInterfaceType == .loopback)
        #expect(!p.includePeerToPeer)
    }

    @Test func answersOnLoopbackAndNowhereElse() async throws {
        let (server, port) = try await running()
        defer { server.stop() }
        #expect(port > 0)
        let session = URLSession(configuration: .ephemeral)
        let (page, res) = try await session.data(from: URL(string: "http://127.0.0.1:\(port)/overlay")!)
        let http = try #require(res as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect(http.value(forHTTPHeaderField: "Cache-Control") == "no-store")
        #expect(String(decoding: page, as: UTF8.self).hasPrefix("<!doctype html>"))
        let (_, missing) = try await session.data(from: URL(string: "http://127.0.0.1:\(port)/nope")!)
        #expect((missing as? HTTPURLResponse)?.statusCode == 404)
        #expect(connects("127.0.0.1", port))
        for ip in otherAddresses() { #expect(!connects(ip, port), "answered on \(ip)") }
    }

    @Test func streamsToSeveralClientsAndClosesThemWhenTurnedOff() async throws {
        let (server, port) = try await running()
        let session = URLSession(configuration: .ephemeral)
        let events = URL(string: "http://127.0.0.1:\(port)/events")!
        actor Seen {
            var focus: Set<Int> = []
            func saw(_ client: Int) { focus.insert(client) }
            func count() -> Int { focus.count }
        }
        let seen = Seen()
        // Two browser sources at once; each reads until its stream ends.
        let clients = (0..<2).map { n in
            Task { () -> Bool in
                let (bytes, res) = try await session.bytes(from: events)
                guard (res as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("text/event-stream") == true else { return false }
                do {
                    for try await line in bytes.lines where line.hasPrefix("data: ") && line.contains(#""phase":"focus""#) { await seen.saw(n) }
                } catch {}   // the connection went away: also an end
                return true
            }
        }
        let focus = BrowserSource.json(BrowserSource.snapshot(mode: .pomodoro, phase: .focus, restIsLong: false, duration: 1500, elapsed: 10,
                                                              paused: false, focusCount: 1, longEvery: 4, lang: .en))
        let reached = try await within(15) { () -> Bool in
            while await seen.count() < 2 {
                server.publish(focus, force: true)   // the heartbeat, until both have it
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            return true
        }
        #expect(reached)
        server.stop()
        for c in clients {
            let ended = try await within(10) { try await c.value }
            #expect(ended, "a stream did not end, or was not an event stream")
        }
        // Off: the URL stops answering.
        let off = try await within(10) { () -> Bool in
            for _ in 0..<50 {
                do { _ = try await session.data(from: URL(string: "http://127.0.0.1:\(port)/overlay")!) } catch { return true }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            return false
        }
        #expect(off)
    }
}
#endif
