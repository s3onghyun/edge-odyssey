import Foundation
import Network

/// The browser-source overlay's HTTP server (BrowserSource decides what it says). It listens on
/// 127.0.0.1 only (never another interface, no Bonjour), makes no connections of its own, and
/// only reads: every request is answered from the latest state and the page. Event streams stay
/// open and get each new state; stop() closes the listener and every connection at once.
final class OverlayServer {
    enum Failure: Equatable { case portInUse, other(String) }

    /// The port asked for; 0 picks a free one (the tests). `boundPort` is the one in use.
    let port: Int
    private(set) var boundPort = 0
    /// Called on `callbacks`: listening (on this port), failed, and the number of open event streams.
    var onReady: ((Int) -> Void)?
    var onFailure: ((Failure) -> Void)?
    var onClients: ((Int) -> Void)?
    var log: (String) -> Void = { _ in }

    /// Connections at once (OBS keeps one or two; a browser tab or two more).
    static let maxConnections = 32
    /// A client has this long to send its request head.
    static let headTimeout: TimeInterval = 10

    private let queue = DispatchQueue(label: "edge-odyssey.overlay-server")
    private let callbacks: DispatchQueue
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var streams: [ObjectIdentifier: NWConnection] = [:]
    private var reading: Set<ObjectIdentifier> = []
    private var state = BrowserSource.json(BrowserSource.Snapshot())
    private var sprites = BrowserSource.Sprites()
    private var stopped = false

    init(port: Int, callbacks: DispatchQueue = .main) {
        self.port = port
        self.callbacks = callbacks
    }

    /// TCP bound to 127.0.0.1 at `port`, on the loopback interface only, with no peer-to-peer
    /// (AWDL) interfaces. Network.framework advertises nothing unless a service is set; none is.
    static func parameters(port: Int) -> NWParameters {
        let p = NWParameters.tcp
        let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) ?? .any
        p.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: nwPort)
        p.requiredInterfaceType = .loopback
        p.includePeerToPeer = false
        p.allowLocalEndpointReuse = true   // back on at once after being turned off
        return p
    }

    func start() {
        queue.async { [self] in
            guard listener == nil, !stopped else { return }
            do {
                let l = try NWListener(using: Self.parameters(port: port))
                l.newConnectionHandler = { [weak self] c in self?.accept(c) }
                l.stateUpdateHandler = { [weak self] s in self?.listenerChanged(s) }
                listener = l
                l.start(queue: queue)
            } catch {
                failed(error)
            }
        }
    }

    /// Closes the listener and every connection; the overlay's URL stops answering.
    func stop() {
        queue.async { [self] in
            stopped = true
            listener?.cancel()
            listener = nil
            let all = Array(connections.values)
            connections.removeAll()
            streams.removeAll()
            reading.removeAll()
            all.forEach { $0.cancel() }
            clientsChanged()
        }
    }

    /// A new state for every open event stream (and the next /state.json). Unchanged state is sent
    /// only when `force`d: the once-a-second heartbeat.
    func publish(_ json: String, force: Bool = false) {
        queue.async { [self] in
            guard force || json != state else { return }
            state = json
            let event = Data(BrowserSource.sseEvent(json).utf8)
            for c in streams.values {
                c.send(content: event, completion: .contentProcessed { [weak c] e in if e != nil { c?.cancel() } })
            }
        }
    }

    /// The character the page draws.
    func setSprites(_ s: BrowserSource.Sprites) { queue.async { [self] in sprites = s } }

    // MARK: on `queue`

    private func listenerChanged(_ s: NWListener.State) {
        switch s {
        case .ready:
            boundPort = Int(listener?.port?.rawValue ?? 0)
            log("overlay: listening on \(BrowserSource.host):\(boundPort)")
            let p = boundPort
            callbacks.async { [weak self] in self?.onReady?(p) }
        case .failed(let e), .waiting(let e):
            listener?.cancel()
            listener = nil
            failed(e)
        default: break
        }
    }

    private func failed(_ e: Error) {
        let f: Failure
        if case .posix(let code)? = e as? NWError, code == .EADDRINUSE { f = .portInUse } else { f = .other("\(e)") }
        log("overlay: \(f)")
        callbacks.async { [weak self] in self?.onFailure?(f) }
    }

    private func accept(_ c: NWConnection) {
        guard !stopped, connections.count < Self.maxConnections else { c.cancel(); return }
        let id = ObjectIdentifier(c)
        connections[id] = c
        reading.insert(id)
        c.stateUpdateHandler = { [weak self, weak c] s in
            guard let self, let c else { return }
            switch s {
            case .failed, .cancelled: self.drop(c)
            default: break
            }
        }
        c.start(queue: queue)
        readHead(c, Data())
        queue.asyncAfter(deadline: .now() + Self.headTimeout) { [weak self, weak c] in
            guard let self, let c, self.reading.contains(ObjectIdentifier(c)) else { return }
            c.cancel()   // never finished its request
        }
    }

    private func readHead(_ c: NWConnection, _ buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self, weak c] data, _, done, error in
            guard let self, let c, self.connections[ObjectIdentifier(c)] != nil else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                self.reading.remove(ObjectIdentifier(c))
                self.answer(c, head: String(decoding: buffer[buffer.startIndex..<end.lowerBound], as: UTF8.self))
            } else if buffer.count > BrowserSource.maxHead {
                self.reading.remove(ObjectIdentifier(c))
                self.finish(c, BrowserSource.response(431, body: "Request head too large\n"))
            } else if done || error != nil {
                c.cancel()
            } else {
                self.readHead(c, buffer)
            }
        }
    }

    private func answer(_ c: NWConnection, head: String) {
        let reply = BrowserSource.reply(to: head, port: boundPort, state: { state }, page: { BrowserSource.page($0, sprites: sprites) })
        switch reply {
        case .respond(let d):
            finish(c, d)
        case .stream(let d):
            streams[ObjectIdentifier(c)] = c
            c.send(content: d, completion: .contentProcessed { [weak c] e in if e != nil { c?.cancel() } })
            clientsChanged()
            watchForClose(c)
        }
    }

    /// Sends a whole response, then closes the connection.
    private func finish(_ c: NWConnection, _ d: Data) {
        c.send(content: d, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { [weak c] _ in c?.cancel() })
    }

    /// An event stream only ends when the client goes (OBS reloads or closes the source) or we stop.
    private func watchForClose(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self, weak c] _, _, done, error in
            guard let c else { return }
            if done || error != nil { c.cancel() } else { self?.watchForClose(c) }
        }
    }

    private func drop(_ c: NWConnection) {
        let id = ObjectIdentifier(c)
        connections[id] = nil
        reading.remove(id)
        if streams.removeValue(forKey: id) != nil { clientsChanged() }
    }

    private func clientsChanged() {
        let n = streams.count
        callbacks.async { [weak self] in self?.onClients?(n) }
    }
}
