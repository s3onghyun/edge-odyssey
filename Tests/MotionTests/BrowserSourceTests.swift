import Foundation
import Testing
@testable import EdgeMotion

// The browser-source overlay (Sources/BrowserSource.swift): the state it pushes, the event framing,
// the escaping, the routing and the page. OverlayServerTests covers the listener itself.

@Suite struct BrowserSourceTests {
    func decode(_ json: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func focus(elapsed: Double = 90.5, paused: Bool = false, lang: Lang = .en) -> BrowserSource.Snapshot {
        BrowserSource.snapshot(mode: .pomodoro, phase: .focus, restIsLong: false, duration: 1500, elapsed: elapsed, paused: paused,
                               focusCount: 2, longEvery: 4, agent: .idle, lang: lang)
    }

    @Test func idleStateEncodesEveryKeyInOrder() {
        let s = BrowserSource.snapshot(mode: .timer, phase: .idle, restIsLong: false, duration: 600, elapsed: 0, paused: false,
                                       focusCount: 0, longEvery: 4, agent: .idle, lang: .ko)
        #expect(BrowserSource.json(s) == #"{"agent":"idle","clock":"","duration":0,"elapsed":0,"label":"","lang":"ko","mode":"timer","#
            + #""paused":false,"phase":"idle","progress":0,"remaining":0,"session":null,"v":1}"#)
    }

    @Test func focusCarriesTheHUDsState() throws {
        let s = focus()
        #expect(s.phase == "focus" && s.label == "Focus" && s.clock == "23:30" && s.session == .init(n: 2, of: 4))
        let d = try decode(BrowserSource.json(s))
        #expect(Set(d.keys) == ["v", "phase", "mode", "label", "clock", "duration", "elapsed", "remaining", "progress", "paused", "session", "agent", "lang"])
        #expect(d["duration"] as? Double == 1500 && d["elapsed"] as? Double == 90.5 && d["remaining"] as? Double == 1409.5)
        #expect(d["progress"] as? Double == 0.0603)
        #expect((d["session"] as? [String: Int]) == ["n": 2, "of": 4])
        // The HUD's own words for the same moment.
        #expect(StreamMode.hudText(mode: .pomodoro, phase: .focus, restIsLong: false, clock: s.clock, paused: false, session: (2, 4), lang: .en)
                == "\(s.label) · \(s.clock) · 2/4")
        #expect(focus(paused: true).paused)
        #expect(focus(lang: .ja).label == "集中")
    }

    @Test func breaksArrivalTimersAndStopwatches() {
        let rest = BrowserSource.snapshot(mode: .pomodoro, phase: .rest, restIsLong: false, duration: 300, elapsed: 60, paused: false,
                                          focusCount: 1, longEvery: 4, agent: .idle, lang: .en)
        #expect(rest.phase == "break" && rest.label == "Break" && rest.clock == "4:00" && rest.progress == 0.2)
        let long = BrowserSource.snapshot(mode: .pomodoro, phase: .rest, restIsLong: true, duration: 900, elapsed: 0, paused: false,
                                          focusCount: 4, longEvery: 4, agent: .idle, lang: .zh)
        #expect(long.phase == "long-break" && long.label == "长休息" && long.session == .init(n: 4, of: 4))
        let home = BrowserSource.snapshot(mode: .pomodoro, phase: .arrived, restIsLong: false, duration: 1500, elapsed: 42, paused: false,
                                          focusCount: 1, longEvery: 4, agent: .working, lang: .en)
        #expect(home.phase == "arrived" && home.clock == "+0:42" && home.progress == 1 && home.remaining == 0 && home.agent == "working")
        let timer = BrowserSource.snapshot(mode: .timer, phase: .focus, restIsLong: false, duration: 600, elapsed: 1, paused: false,
                                           focusCount: 3, longEvery: 4, agent: .idle, lang: .en)
        #expect(timer.label == "Timer" && timer.clock == "9:59" && timer.session == nil)   // no sessions outside Pomodoro
        let watch = BrowserSource.snapshot(mode: .stopwatch, phase: .focus, restIsLong: false, duration: 720, elapsed: 723, paused: false,
                                           focusCount: 0, longEvery: 4, agent: .idle, lang: .en)
        #expect(watch.clock == "12:03" && watch.elapsed == 723 && watch.remaining == 717 && watch.progress == 0.0042)   // the second lap
        let over = focus(elapsed: 1600)
        #expect(over.remaining == 0 && over.progress == 1 && over.clock == "0:00")
    }

    @Test func eventsAreFramedLineByLine() {
        #expect(BrowserSource.sseEvent(#"{"a":1}"#) == "data: {\"a\":1}\n\n")
        #expect(BrowserSource.sseEvent("a\nb\r\nc\rd") == "data: a\ndata: b\ndata: c\ndata: d\n\n")
        #expect(BrowserSource.sseEvent("x", event: "state\nid: 9") == "event: stateid: 9\ndata: x\n\n")
        #expect(BrowserSource.sseEvent("") == "data: \n\n")
        let json = BrowserSource.json(focus())
        let head = String(decoding: BrowserSource.streamHead(state: json), as: UTF8.self)
        let parts = head.components(separatedBy: "\r\n\r\n")
        #expect(parts.count == 2)
        let headers = parts[0].components(separatedBy: "\r\n")
        #expect(headers[0] == "HTTP/1.1 200 OK")
        #expect(headers.contains("Content-Type: text/event-stream; charset=utf-8") && headers.contains("Cache-Control: no-store"))
        #expect(!headers.contains { $0.lowercased().hasPrefix("content-length") })   // it never ends by itself
        #expect(parts[1] == "retry: 2000\n\ndata: \(json)\n\n")
    }

    @Test func escapesHTMLAndScripts() throws {
        #expect(BrowserSource.escapeHTML(#"<script>alert("x") & 'y'</script>"#)
                == "&lt;script&gt;alert(&quot;x&quot;) &amp; &#39;y&#39;&lt;/script&gt;")
        #expect(BrowserSource.escapeHTML("<\u{301}b>") == "&lt;\u{301}b&gt;")   // a combining mark cannot hide the bracket
        #expect(BrowserSource.escapeHTML("집중 · 18:32") == "집중 · 18:32")
        let hostile = BrowserSource.json(["label": "</script><script>alert(1)</script><!-- \u{2028}&"])
        let safe = BrowserSource.scriptJSON(hostile)
        #expect(!safe.contains("<") && !safe.contains(">") && !safe.contains("&") && !safe.contains("\u{2028}"))
        #expect(try decode(safe)["label"] as? String == "</script><script>alert(1)</script><!-- \u{2028}&")   // the same value
    }

    @Test func thePageIsSelfContainedAndEscaped() {
        var sprites = BrowserSource.Sprites(width: 32, height: 26)
        sprites.anims["walk"] = .init(fps: 5, frames: [BrowserSource.dataURI(png: Data([0x89, 0x50, 0x4E, 0x47])), "</script><b>x"])
        let page = BrowserSource.page(.init(lang: .ko, scale: 2), sprites: sprites)
        #expect(page.hasPrefix("<!doctype html>"))
        #expect(page.contains(#"<html lang="ko">"#))
        #expect(page.components(separatedBy: "<script").count == 2 && page.components(separatedBy: "</script>").count == 2)
        #expect(page.contains("data:image/png;base64,iVBORw=="))
        #expect(!page.contains("%CONFIG%") && !page.contains("%LANG%"))
        for remote in ["http://", "https://", "//cdn", "@import", "src=\"/", "url("] { #expect(!page.contains(remote), "\(remote)") }
        #expect(page.contains(#""lang":"ko""#) && page.contains(#""scale":2"#))
        #expect(BrowserSource.page(.init(), sprites: sprites).contains(#""lang":null"#))   // follows the app's language
    }

    @Test func labelsCoverEveryLanguageAndPhase() {
        let all = BrowserSource.labels()
        #expect(Set(all.keys) == Set(Lang.allCases.map(\.rawValue)))
        for (_, l) in all {
            #expect(Set(l.keys) == ["focus", "break", "long-break", "arrived", "timer", "stopwatch", "paused"])
            #expect(l.values.allSatisfy { !$0.isEmpty })
        }
        #expect(all["ko"]?["focus"] == "집중" && all["en"]?["long-break"] == "Long break" && all["zh"]?["paused"] == "暂停")
    }

    func request(_ line: String, host: String? = "127.0.0.1:47213") -> String {
        line + "\r\n" + (host.map { "Host: \($0)\r\n" } ?? "") + "User-Agent: OBS\r\n"
    }

    @Test func routesOnlyThreeReadOnlyPaths() throws {
        func route(_ line: String, host: String? = "127.0.0.1:47213") throws -> BrowserSource.Route {
            BrowserSource.route(try #require(BrowserSource.parseRequest(request(line, host: host))), port: 47213)
        }
        #expect(try route("GET /overlay HTTP/1.1") == .overlay(.init()))
        #expect(try route("GET /overlay?lang=KO&scale=2.5&x=1 HTTP/1.1") == .overlay(.init(lang: .ko, scale: 2.5)))
        for bad in ["9", "0.1", "-1", "nan", "inf", "1e309", "2,5", "", "1.0000000001"] {
            #expect(try route("GET /overlay?scale=\(bad)&lang=xx HTTP/1.1") == .overlay(.init()), "scale=\(bad)")
        }
        #expect(try route("GET /events HTTP/1.1") == .events)
        #expect(try route("GET /state.json HTTP/1.1") == .state)
        #expect(try route("GET /state.json?cmd=stop HTTP/1.1") == .state)   // a query never does anything
        for path in ["/", "/overlay/", "/overlay/../state.json", "/OVERLAY", "/favicon.ico", "/sprites/walk-0.svg"] {
            #expect(try route("GET \(path) HTTP/1.1") == .notFound, "\(path)")
        }
        for method in ["POST", "PUT", "DELETE", "HEAD", "OPTIONS"] { #expect(try route("\(method) /state.json HTTP/1.1") == .methodNotAllowed) }
        #expect(try route("GET /overlay HTTP/1.1", host: "localhost:47213") == .overlay(.init()))
        for host in ["evil.example:47213", "127.0.0.1:47214", "127.0.0.1", "192.168.1.5:47213", ""] {
            #expect(try route("GET /overlay HTTP/1.1", host: host) == .forbidden, "\(host)")   // DNS rebinding
        }
        #expect(try route("GET /overlay HTTP/1.1", host: nil) == .forbidden)
        for junk in ["", "GET", "GET /overlay", "GET overlay HTTP/1.1", "get /overlay HTTP/1.1", "GET /overlay HTTP/2", "GET  /overlay HTTP/1.1"] {
            #expect(BrowserSource.parseRequest(request(junk)) == nil, "\(junk)")
        }
    }

    @Test func everyReplyIsUncachedAndNamesNothingPrivate() throws {
        let state = BrowserSource.json(focus())
        let sprites = BrowserSource.Sprites(width: 32, height: 26)
        func reply(_ line: String, host: String = "127.0.0.1:47213") -> (status: String, headers: [String], body: String) {
            let r = BrowserSource.reply(to: request(line, host: host), port: 47213, state: { state }, page: { BrowserSource.page($0, sprites: sprites) })
            let data: Data
            switch r { case .respond(let d), .stream(let d): data = d }
            let parts = String(decoding: data, as: UTF8.self).components(separatedBy: "\r\n\r\n")
            let headers = parts[0].components(separatedBy: "\r\n")
            return (headers[0], headers, parts.dropFirst().joined(separator: "\r\n\r\n"))
        }
        let cases = [("GET /overlay HTTP/1.1", "HTTP/1.1 200 OK"), ("GET /state.json HTTP/1.1", "HTTP/1.1 200 OK"),
                     ("GET /events HTTP/1.1", "HTTP/1.1 200 OK"), ("GET /nope HTTP/1.1", "HTTP/1.1 404 Not Found"),
                     ("POST /state.json HTTP/1.1", "HTTP/1.1 405 Method Not Allowed"), ("nonsense", "HTTP/1.1 400 Bad Request")]
        var bodies = ""
        for (line, status) in cases {
            let r = reply(line)
            #expect(r.status == status, "\(line)")
            #expect(r.headers.contains("Cache-Control: no-store"), "\(line)")
            #expect(!r.headers.contains { $0.lowercased().hasPrefix("access-control-") }, "\(line)")   // no other site may read it
            bodies += r.headers.joined() + r.body
        }
        #expect(reply("GET /overlay HTTP/1.1", host: "evil.example:47213").status == "HTTP/1.1 403 Forbidden")
        #expect(reply("GET /overlay HTTP/1.1").headers.contains("Content-Security-Policy: \(BrowserSource.pagePolicy)"))
        #expect(reply("GET /state.json HTTP/1.1").body == state + "\n")
        // No user, host, home folder or path in anything served.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for secret in [NSUserName(), ProcessInfo.processInfo.hostName, home, NSFullUserName()] where secret.count >= 4 {
            #expect(!bodies.contains(secret), "\(secret)")
        }
        #expect(!bodies.contains("/Users/") && !bodies.contains("/home/"))
    }

    @Test func portsAndTheURL() {
        #expect(BrowserSource.port("47213") == 47213 && BrowserSource.port(" 8080 ") == 8080)
        for bad in ["80", "1023", "49152", "65535", "0", "-1", "abc", "", "4721 3"] { #expect(BrowserSource.port(bad) == nil, "\(bad)") }
        #expect(BrowserSource.ports.contains(BrowserSource.defaultPort))
        #expect(BrowserSource.url(port: 47213) == "http://127.0.0.1:47213/overlay")
    }
}
