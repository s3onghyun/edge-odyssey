import Foundation

/// The browser-source overlay: a page OBS (or any streaming app's browser source) shows over a
/// camera scene, with the edge's progress line, Odysseus, the phase and the session, pushed live
/// from the app. Off by default. On, OverlayServer serves it on 127.0.0.1 only; it only reads the
/// timer and never takes commands. Everything here is pure (the HTTP routing, the state, the event
/// framing, the page), so the tests decide it; OverlayServer does the network I/O.
enum BrowserSource {
    /// The listener's only address: loopback, so nothing off this Mac can connect.
    static let host = "127.0.0.1"
    static let defaultPort = 47213
    /// Ports the user can pick: unprivileged, below the range macOS hands out for outgoing connections.
    static let ports = 1024...49151

    /// A typed or saved port, or nil when it is not a whole number in `ports`.
    static func port(_ raw: String) -> Int? {
        guard let p = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)), ports.contains(p) else { return nil }
        return p
    }

    /// The address to paste into OBS.
    static func url(port: Int) -> String { "http://\(host):\(port)/overlay" }

    // MARK: state

    struct Session: Codable, Equatable { var n: Int; var of: Int }

    /// What the overlay shows: the same state as stream mode's HUD. Times are in real seconds.
    struct Snapshot: Codable, Equatable {
        var v = 1                 // the schema
        var phase = "idle"        // idle, focus, break, long-break or arrived
        var mode = "pomodoro"     // pomodoro, timer or stopwatch
        var label = ""            // the phase as the HUD names it, in the app's language; "" when idle
        var clock = ""            // the time as the HUD shows it: "18:32", "+0:42" (arrived), "12:03" (stopwatch), "paused"
        var duration = 0.0        // the phase's length (a stopwatch: one lap round the edge)
        var remaining = 0.0       // left of the phase (a stopwatch: of this lap)
        var progress = 0.0        // 0...1 of the phase (a stopwatch: of this lap)
        var paused = false
        var session: Session?     // Pomodoro only: 2 of 4
        var agent = "idle"        // the coding agent: idle, working, waiting or limit (idle with narration off)
        var narration = ""        // its line for viewers, in the app's language; "" when idle. Never a repo or branch.

        enum CodingKeys: String, CodingKey { case v, phase, mode, label, clock, duration, remaining, progress, paused, session, agent, narration }

        func encode(to e: Encoder) throws {
            var c = e.container(keyedBy: CodingKeys.self)
            try c.encode(v, forKey: .v)
            try c.encode(phase, forKey: .phase)
            try c.encode(mode, forKey: .mode)
            try c.encode(label, forKey: .label)
            try c.encode(clock, forKey: .clock)
            try c.encode(duration, forKey: .duration)
            try c.encode(remaining, forKey: .remaining)
            try c.encode(progress, forKey: .progress)
            try c.encode(paused, forKey: .paused)
            try c.encode(session, forKey: .session)   // null outside Pomodoro, so the keys never change
            try c.encode(agent, forKey: .agent)
            try c.encode(narration, forKey: .narration)
        }
    }

    /// The state now. `duration` and `elapsed` are real seconds (the app's demo speed already applied).
    /// `agent`: the narrated agent state (`StreamMode.narratedState`), shown even while no timer runs.
    /// It is only the state, so nothing about the project (repo, branch, folder) can reach the page.
    static func snapshot(mode: TimerMode, phase: Phase, restIsLong: Bool, duration: Double, elapsed: Double, paused: Bool,
                         focusCount: Int, longEvery: Int, lang: Lang, agent: AgentState = .idle) -> Snapshot {
        var s = Snapshot()
        s.mode = mode.rawValue
        s.agent = agent.rawValue
        s.narration = StreamMode.narration(agent, lang: lang) ?? ""
        guard phase != .idle else { return s }
        func tenth(_ x: Double) -> Double { (max(x, 0) * 10).rounded() / 10 }
        let d = max(duration, 0), e = max(elapsed, 0)
        switch phase {
        case .idle, .focus: s.phase = "focus"
        case .rest: s.phase = restIsLong ? "long-break" : "break"
        case .arrived: s.phase = "arrived"
        }
        s.label = StreamMode.phaseName(mode: mode, phase: phase, restIsLong: restIsLong, lang: lang) ?? ""
        s.paused = paused
        s.duration = tenth(d)
        if phase == .arrived {   // home: the whole trail, the overtime counting up
            s.progress = 1
            s.clock = overtime(e)
        } else if mode == .stopwatch {
            let lap = d > 0 ? e.truncatingRemainder(dividingBy: d) : 0
            s.remaining = tenth(d - lap)
            s.progress = d > 0 ? min(lap / d, 1) : 0
            s.clock = elapsedClock(e)
        } else {
            s.remaining = tenth(d - e)
            s.progress = d > 0 ? min(e / d, 1) : 0
            s.clock = countdown(d - e)
        }
        s.progress = (s.progress * 10000).rounded() / 10000
        if paused { s.clock = StreamMode.pausedWord(lang) }
        if mode == .pomodoro {
            let n = StreamMode.session(focusCount: focusCount, every: longEvery)
            s.session = Session(n: n.n, of: n.of)
        }
        return s
    }

    /// One line of JSON with sorted keys, so the same state always reads the same.
    static func json<T: Encodable>(_ value: T) -> String {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let d = try? e.encode(value), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    // MARK: server-sent events

    /// Tells an EventSource to come back two seconds after the connection drops (OBS reloads, the app restarts).
    static let sseHello = "retry: 2000\n\n"

    /// One server-sent event: every line of `data` on its own `data:` line, ended by a blank line.
    /// CR, LF and CRLF all end a line in the protocol, so each becomes a line of its own here.
    static func sseEvent(_ data: String) -> String {
        var out = ""
        let lines = data.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        for line in lines { out += "data: " + line + "\n" }
        return out + "\n"
    }

    // MARK: escaping

    /// JSON made safe inside a `<script>` element: no `</script>`, `<!--` or line separators can
    /// end it early. Each is a valid JSON string escape, so the value reads the same.
    static func scriptJSON(_ json: String) -> String {
        var out = ""
        for u in json.unicodeScalars {
            switch u {
            case "<": out += "\\u003c"
            case ">": out += "\\u003e"
            case "&": out += "\\u0026"
            case "\u{2028}": out += "\\u2028"
            case "\u{2029}": out += "\\u2029"
            default: out.unicodeScalars.append(u)
            }
        }
        return out
    }

    // MARK: requests

    struct Request: Equatable {
        var method: String
        var path: String
        var host: String?
    }

    /// Longest request head (request line and headers) read before giving up on a client.
    static let maxHead = 8192

    /// The request line and Host header of a request head (up to the blank line), or nil when it is
    /// not HTTP/1.x with an origin-form target.
    static func parseRequest(_ head: String) -> Request? {
        let lines = head.components(separatedBy: "\r\n")
        let first = lines[0].split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard first.count == 3, first[1].hasPrefix("/"), first[2].hasPrefix("HTTP/1."),
              !first[0].isEmpty, first[0].allSatisfy({ $0.isASCII && $0.isUppercase }) else { return nil }
        let path = String(first[1].prefix { $0 != "?" })
        var host: String?
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            if line[..<colon].trimmingCharacters(in: .whitespaces).lowercased() == "host" {
                host = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return Request(method: first[0], path: path, host: host)
    }

    enum Route: Equatable {
        case overlay
        case events
        case notFound
        case methodNotAllowed
        case forbidden   // a Host header that is not this address: a web page rebinding its domain to 127.0.0.1
    }

    /// The only Host a request may name: the address OBS is given, at our port.
    static func allowsHost(_ host: String?, port: Int) -> Bool {
        host == "\(Self.host):\(port)"
    }

    static func route(_ r: Request, port: Int) -> Route {
        guard allowsHost(r.host, port: port) else { return .forbidden }
        guard r.method == "GET" else { return .methodNotAllowed }
        switch r.path {
        case "/overlay": return .overlay
        case "/events": return .events
        default: return .notFound
        }
    }

    // MARK: responses

    enum Reply: Equatable {
        case respond(Data)   // a whole response, then the connection closes
        case stream(Data)    // the head of the event stream and its first events; more follow
    }

    static let pagePolicy = "default-src 'none'; img-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'"

    static func reason(_ status: Int) -> String {
        [200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed",
         431: "Request Header Fields Too Large", 503: "Service Unavailable"][status] ?? "Error"
    }

    /// A complete response that closes the connection. Nothing is ever cached.
    static func response(_ status: Int, type: String = "text/plain; charset=utf-8", body: String, headers extra: [String] = []) -> Data {
        let body = Data(body.utf8)
        let head = ["HTTP/1.1 \(status) \(reason(status))", "Content-Type: \(type)", "Content-Length: \(body.count)",
                    "Cache-Control: no-store", "X-Content-Type-Options: nosniff", "Referrer-Policy: no-referrer", "Connection: close"]
            + extra
        return Data((head.joined(separator: "\r\n") + "\r\n\r\n").utf8) + body
    }

    /// The event stream's head plus the retry hint and the state now. It never ends by itself.
    static func streamHead(state: String) -> Data {
        let head = ["HTTP/1.1 200 OK", "Content-Type: text/event-stream; charset=utf-8", "Cache-Control: no-store",
                    "X-Content-Type-Options: nosniff", "Connection: keep-alive"]
        return Data((head.joined(separator: "\r\n") + "\r\n\r\n" + sseHello + sseEvent(state)).utf8)
    }

    /// What to send for a request head. `state`: the latest snapshot's JSON; `page`: the overlay page.
    static func reply(to head: String, port: Int, state: () -> String, page: () -> String) -> Reply {
        guard let r = parseRequest(head) else { return .respond(response(400, body: "Bad request\n")) }
        switch route(r, port: port) {
        case .forbidden: return .respond(response(403, body: "Forbidden\n"))
        case .methodNotAllowed: return .respond(response(405, body: "Method not allowed\n", headers: ["Allow: GET"]))
        case .notFound: return .respond(response(404, body: "Not found\n"))
        case .overlay: return .respond(response(200, type: "text/html; charset=utf-8", body: page(), headers: ["Content-Security-Policy: \(pagePolicy)"]))
        case .events: return .stream(streamHead(state: state()))
        }
    }

    // MARK: the page

    /// The character's frames, as `data:` URIs so the page needs nothing else from anywhere.
    struct Sprites: Codable, Equatable {
        struct Anim: Codable, Equatable { var fps: Double; var frames: [String] }
        var width = 0             // in sprite units
        var height = 0
        var pixelated = false     // pixel art: scaled without smoothing
        var anims: [String: Anim] = [:]
    }

    /// The animations the page uses: walking each edge, standing still, resting and arriving home.
    static let spriteAnims = ["walk", "climb", "cling", "slide", "idle", "rest", "ithaca"]

    /// A PNG as a `data:` URI.
    static func dataURI(png: Data) -> String { "data:image/png;base64," + png.base64EncodedString() }

    private struct PageConfig: Encodable {
        var sprites: Sprites
        var colors: [String: String]

        func encode(to e: Encoder) throws {
            enum K: String, CodingKey { case sprites, colors }
            var c = e.container(keyedBy: K.self)
            try c.encode(sprites, forKey: .sprites)
            try c.encode(colors, forKey: .colors)
        }
    }

    /// `#RRGGBB` for a palette colour.
    static func hex(_ rgb: UInt32) -> String { String(format: "#%06X", rgb & 0xFFFFFF) }

    /// The edge's colours on a camera scene: the dark palette, which reads on most video.
    static var colors: [String: String] {
        ["focus": hex(Tones.teal.dark), "warm": hex(Tones.brass.dark), "rest": hex(Tones.slate.dark),
         "surface": hex(Tones.surface.dark), "ink": hex(Tones.ink.dark), "track": hex(Tones.ink.dark),
         "signal": hex(Tones.signal.dark), "storm": hex(Tones.rust.dark)]
    }

    /// The overlay page: transparent, self-contained (inline style, script and frames), and drawn from
    /// the event stream. Text reaches it as escaped JSON and is set with `textContent`, never as HTML.
    static func page(sprites: Sprites) -> String {
        let config = PageConfig(sprites: sprites, colors: colors)
        return pageTemplate.replacingOccurrences(of: "%CONFIG%", with: scriptJSON(json(config)))
    }

    /// The route is the edge's: from the bottom-left corner right along the floor, up the right side,
    /// left along the top and down the left side; a focus fills it, a break drains it.
    static let pageTemplate = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Edge Odyssey overlay</title>
<style>
html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; width: 100%; height: 100%; }
canvas { position: fixed; left: 0; top: 0; width: 100vw; height: 100vh; }
#chips { position: fixed; right: 36px; bottom: 36px; display: flex; gap: 8px; align-items: center; }
#chips div { padding: 5px 11px; border-radius: 999px; border: 1.5px solid;
  font: 600 13px -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; font-variant-numeric: tabular-nums;
  white-space: nowrap; }
#chips div[hidden] { display: none; }
</style>
</head>
<body>
<canvas id="edge"></canvas>
<div id="chips"><div id="agent" hidden></div><div id="chip" hidden></div></div>
<script>
"use strict";
(function () {
  var CFG = %CONFIG%;
  var cv = document.getElementById("edge"), g = cv.getContext("2d"), chip = document.getElementById("chip");
  var agent = document.getElementById("agent");
  var st = null, got = 0, dpr = 1, es = null, stale = 5000;
  var C = CFG.colors, S = CFG.sprites;
  var imgs = {};
  Object.keys(S.anims).forEach(function (name) {
    imgs[name] = S.anims[name].frames.map(function (src) { var i = new Image(); i.src = src; return i; });
  });
  [chip, agent].forEach(function (c) { c.style.background = C.surface + "EB"; c.style.color = C.ink; });

  function fit() {
    dpr = window.devicePixelRatio || 1;
    cv.width = Math.round(window.innerWidth * dpr);
    cv.height = Math.round(window.innerHeight * dpr);
  }
  window.addEventListener("resize", function () { fit(); draw(); });
  fit();

  function connect() {
    if (es) es.close();
    es = new EventSource("/events");
    es.onmessage = function (e) {
      try { st = JSON.parse(e.data); got = performance.now(); } catch (err) { return; }
      draw();
    };
    es.onerror = function () {
      if (es.readyState === 2) setTimeout(connect, 3000);   // closed for good: try again; otherwise it retries by itself
    };
  }

  function labelFor(s) {
    var parts = [s.label, s.clock];
    if (s.session) parts.push(s.session.n + "/" + s.session.of);
    return parts.join(" · ");
  }

  // A point on the route at share f (0...1) of its length: where, and which way the sprite turns.
  function route(f, W, H, i) {
    var a = W - 2 * i, b = H - 2 * i, d = Math.max(0, Math.min(1, f)) * (2 * a + 2 * b);
    if (d <= a) return { x: i + d, y: H - i, r: 0, edge: 0 };
    d -= a;
    if (d <= b) return { x: W - i, y: H - i - d, r: -Math.PI / 2, edge: 1 };
    d -= b;
    if (d <= a) return { x: W - i - d, y: i, r: Math.PI, edge: 2 };
    d -= a;
    return { x: i, y: i + d, r: Math.PI / 2, edge: 3 };
  }

  function trail(f, W, H, i) {
    var corners = [[i, H - i], [W - i, H - i], [W - i, i], [i, i], [i, H - i]];
    var a = W - 2 * i, b = H - 2 * i, lens = [a, b, a, b], left = Math.max(0, Math.min(1, f)) * (2 * a + 2 * b);
    g.beginPath();
    g.moveTo(corners[0][0], corners[0][1]);
    for (var n = 0; n < 4 && left > 0; n++) {
      var u = Math.min(1, left / lens[n]);
      g.lineTo(corners[n][0] + (corners[n + 1][0] - corners[n][0]) * u, corners[n][1] + (corners[n + 1][1] - corners[n][1]) * u);
      left -= lens[n];
    }
    g.stroke();
  }

  function sprite(name, p, unit, now) {
    var frames = imgs[name] || imgs.walk;
    if (!frames || !frames.length) return;
    var anim = S.anims[name] || S.anims.walk;
    var img = frames[Math.floor(now / 1000 * anim.fps) % frames.length];
    if (!img.complete) return;
    var w = S.width * unit, h = S.height * unit;
    g.save();
    g.imageSmoothingEnabled = !S.pixelated;
    g.translate(p.x, p.y);
    g.rotate(p.r);
    g.drawImage(img, -w / 2, -h, w, h);
    g.restore();
  }

  // The agent's narration, beside the phase: text only (textContent), never markup.
  function narrate(fresh) {
    var line = fresh && typeof st.narration === "string" ? st.narration : "";
    if (!line) { agent.hidden = true; return; }
    if (agent.textContent !== line) agent.textContent = line;
    agent.style.borderColor = st.agent === "limit" ? C.storm : C.signal;
    agent.hidden = false;
  }

  function draw() {
    var now = performance.now();
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.clearRect(0, 0, cv.width, cv.height);
    var fresh = !!st && now - got <= stale;
    narrate(fresh);
    if (!fresh || st.phase === "idle") { chip.hidden = true; return; }
    var W = cv.width, H = cv.height, px = dpr, lw = 4 * px, i = lw / 2 + 2 * px;
    var live = !st.paused && st.phase !== "arrived";
    var dur = st.duration, w = live && dur > 0 ? (now - got) / 1000 : 0;
    var t = st.progress + (dur > 0 ? w / dur : 0);
    t = st.mode === "stopwatch" ? t % 1 : Math.min(t, 1);
    var rest = st.phase === "break" || st.phase === "long-break";
    var tone = st.phase === "arrived" ? C.warm : rest ? C.rest : (st.mode !== "stopwatch" && dur > 0 && st.remaining - w <= dur / 5) ? C.warm : C.focus;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.lineWidth = lw;
    g.strokeStyle = C.track + "2E";
    trail(1, W, H, i);
    g.strokeStyle = tone;
    trail(rest ? 1 - t : t, W, H, i);
    var unit = 2 * px, home = route(0, W, H, i);
    home.x += S.width * unit / 2 + i;
    if (st.phase === "arrived") sprite("ithaca", home, unit, now);
    else if (rest) sprite(st.paused ? "idle" : "rest", home, unit, now);
    else {
      var p = route(t, W, H, i);
      sprite(st.paused ? "idle" : ["walk", "climb", "cling", "slide"][p.edge], p, unit, now);
    }
    chip.textContent = labelFor(st);
    chip.style.borderColor = tone;
    chip.hidden = false;
  }

  function loop() { draw(); window.requestAnimationFrame(loop); }
  connect();
  window.requestAnimationFrame(loop);
})();
</script>
</body>
</html>
"""#
}
