import CoreGraphics
import Testing
@testable import EdgeMotion

// Even pace (the default): the traveler's place on the route is the elapsed share of the
// session, so halfway round the screen is halfway through, on any display shape.

let evenScreens: [CGSize] = [
    CGSize(width: 1728, height: 1117),   // MacBook Pro 16"
    CGSize(width: 1440, height: 900),
    CGSize(width: 2560, height: 1440),
    CGSize(width: 1080, height: 1920),   // a display turned vertical
    CGSize(width: 800, height: 800),
]

/// Distance travelled along the route (counter-clockwise from the bottom-left corner) to `p`.
func routeDistance(_ j: Journey, edge k: Int, _ p: CGPoint) -> Double {
    j.edges[..<k].reduce(0) { $0 + Double($1.length) } + Double(hypot(p.x - j.edges[k].start.x, p.y - j.edges[k].start.y))
}

@Test(arguments: evenScreens)
func evenPacePositionIsElapsedShare(screen: CGSize) {
    let j = Journey(size: screen, inset: 13, weights: Journey.weights(physical: false))
    let perimeter = j.edges.reduce(0) { $0 + Double($1.length) }
    for t in [0.25, 0.5, 0.75] {
        let (k, u) = j.locate(t)
        // even pace places the traveler with no per-edge profile (Overlay.applyTraveler)
        #expect(abs(routeDistance(j, edge: k, j.edges[k].point(u)) / perimeter - t) < 1e-9)
        #expect(abs(j.lengthFraction(t) - t) < 1e-9)   // the trail ends at the same place
    }
}

@Test(arguments: evenScreens)
func evenPaceAnimationStaysOnSchedule(screen: CGSize) {
    // The keyframed route (what Core Animation plays) is on schedule between keyframes too.
    let j = Journey(size: screen, inset: 13, weights: Journey.weights(physical: false))
    let perimeter = j.edges.reduce(0) { $0 + Double($1.length) }
    for t0 in [0.0, 0.1, 0.6] {
        let r = routeSamples(j, from: t0, zip: true, profiled: false)
        for t in [0.25, 0.5, 0.75] where t > t0 {
            let tt = (t - t0) / (1 - t0)
            let a = r.lastIndex { $0.time <= tt }!, b = min(a + 1, r.count - 1)
            let f = b == a ? 0 : (tt - r[a].time) / (r[b].time - r[a].time)
            let da = routeDistance(j, edge: r[a].edge, j.edges[r[a].edge].point(r[a].u))
            let db = routeDistance(j, edge: r[b].edge, j.edges[r[b].edge].point(r[b].u))
            #expect(abs((da + (db - da) * f) / perimeter - t) < 1e-9)
        }
    }
}

@Test func physicalPaceIsStillAvailable() {
    let j = Journey(size: evenScreens[0], inset: 13, weights: Journey.weights(physical: true))
    #expect(abs(j.lengthFraction(0.5) - 0.5) > 0.01)   // physical: position no longer reads as time
}
