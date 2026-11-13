import Testing
@testable import EdgeMotion

@Test func urlStartRoutesThroughExistingControls() {
    let url = "edge-odyssey://start?minutes=50&label=fix-auth"
    #expect(URLScheme.route(url) == .controls(["focus:50", "label:fix-auth", "start"]))
}

@Test func urlStartClampsMinutesToFocusRange() {
    #expect(URLScheme.route("edge-odyssey://start?minutes=0") == .controls(["focus:1", "start"]))
    #expect(URLScheme.route("edge-odyssey://start?minutes=999") == .controls(["focus:240", "start"]))
}

@Test func urlRoutesTimerActionsAndFinish() {
    #expect(URLScheme.route("edge-odyssey://pause") == .controls(["pause"]))
    #expect(URLScheme.route("edge-odyssey://resume") == .controls(["resume"]))
    #expect(URLScheme.route("edge-odyssey://finish") == .controls(["stop"]))
    #expect(URLScheme.route("edge-odyssey://focus-mode") == .controls(["focus-mode"]))
}

@Test func urlIgnoresUnknownCommandsAndBadParameters() {
    #expect(URLScheme.route("edge-odyssey://teleport") == .ignored("unknown command teleport"))
    #expect(URLScheme.route("edge-odyssey://start?minutes=soon") == .ignored("invalid minutes"))
    #expect(URLScheme.route("edge-odyssey://start?speed=fast") == .ignored("unknown start parameter"))
    #expect(URLScheme.route("https://example.com/start") == .ignored("wrong scheme"))
}
