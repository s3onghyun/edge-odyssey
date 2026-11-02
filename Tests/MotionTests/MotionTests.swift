import CoreGraphics
import Testing
@testable import EdgeMotion

// Display-independent checks of the motion math: the traveler is always where the clock says,
// arrives home exactly on time, and re-applying a scene never makes him jump.

let size = CGSize(width: 1728, height: 1117), inset: CGFloat = 13
let journey = Journey(size: size, inset: inset, weights: Journey.physicalWeights)

func exact(_ t: Double, zip: Bool) -> CGPoint {
    let (k, u) = journey.locate(t)
    return journey.edges[k].point(edgeProfile(journey.edges[k].kind, zip: zip)(u))
}

func point(_ s: (time: Double, edge: Int, u: Double)) -> CGPoint { journey.edges[s.edge].point(s.u) }

/// Where a keyframe animation built from `r` is at share `tt` of its duration (linear mode).
func interpolate(_ r: [(time: Double, edge: Int, u: Double)], _ tt: Double) -> CGPoint {
    let a = r.lastIndex { $0.time <= tt }!, b = min(a + 1, r.count - 1)
    let f = b == a ? 0 : (tt - r[a].time) / (r[b].time - r[a].time)
    let pa = point(r[a]), pb = point(r[b])
    return CGPoint(x: pa.x + (pb.x - pa.x) * f, y: pa.y + (pb.y - pa.y) * f)
}

func dist(_ a: CGPoint, _ b: CGPoint) -> Double { Double(hypot(a.x - b.x, a.y - b.y)) }

@Test func timeMarksAreMonotonicAndEndAtOne() {
    #expect(journey.timeMarks.first == 0)
    #expect(journey.timeMarks.last == 1)
    #expect(zip(journey.timeMarks, journey.timeMarks.dropFirst()).allSatisfy { $0 < $1 })
    // climbing is slower than sliding per point of edge
    let perPoint = (0..<4).map { (journey.timeMarks[$0 + 1] - journey.timeMarks[$0]) / Double(journey.edges[$0].length) }
    #expect(perPoint[1] > perPoint[0] && perPoint[0] > perPoint[3])
}

@Test func locateHitsCornersExactly() {
    for k in 0..<4 {
        let (i, u) = journey.locate(journey.timeMarks[k])
        #expect(i == k && abs(u) < 1e-12)
    }
    let end = journey.locate(1)
    #expect(end.index == 3 && end.local == 1)
}

@Test(arguments: [false, true])
func routeEndsHomeOnTimeFromAnyStart(zip: Bool) {
    for t0 in stride(from: 0.0, to: 0.999, by: 0.0371) {
        let r = routeSamples(journey, from: t0, zip: zip, profiled: true)
        #expect(r.first!.time == 0)
        #expect(abs(r.last!.time - 1) < 1e-9)
        #expect(Swift.zip(r, r.dropFirst()).allSatisfy { $0.time <= $1.time })
        #expect(dist(point(r.last!), CGPoint(x: inset, y: inset)) < 1e-6)
        for k in 1..<4 where journey.timeMarks[k] > t0 {   // corners are keyframes at their exact time
            let want = (journey.timeMarks[k] - t0) / (1 - t0)
            #expect(r.contains { abs($0.time - want) < 1e-9 })
        }
    }
}

@Test(arguments: [false, true])
func reapplyingMidRouteNeverJumps(zip: Bool) {
    for t0 in stride(from: 0.0, to: 0.999, by: 0.0371) {
        let r = routeSamples(journey, from: t0, zip: zip, profiled: true)
        for dt in [0.0013, 0.0291, 0.1] where t0 + dt < 1 {
            let t1 = t0 + dt
            let old = interpolate(r, (t1 - t0) / (1 - t0))
            let new = point(routeSamples(journey, from: t1, zip: zip, profiled: true)[0])
            #expect(dist(old, new) < 1e-6, "t0 \(t0) t1 \(t1)")
        }
    }
}

@Test(arguments: [false, true])
func keyframedPathStaysCloseToTheExactCurve(zip: Bool) {
    let r = routeSamples(journey, from: 0, zip: zip, profiled: true)
    let worst = (0..<2000).map { i -> Double in
        let t = Double(i) / 2000
        return dist(interpolate(r, t), exact(t, zip: zip))
    }.max()!
    #expect(worst < 2.5)   // measured: 0.47 pt (slide), 2.12 pt (zipline)
}

@Test func profilesStartAndEndOnTheCorners() {
    for kind in [EdgeKind.floor, .climb, .ceiling, .slide] {
        for zip in [false, true] {
            let f = edgeProfile(kind, zip: zip)
            #expect(f(0) == 0 && f(1) == 1)
            #expect(profilePeak(kind, zip: zip) >= 1)
        }
    }
}

@Test(arguments: [1.5, 2, 2.5, 3, 4, 5, 6, 8, 4 / 1.6, 6 / 1.6])
func spriteFlipsLandOnDisplayRefreshes(fps: Double) {
    let f = flipTiming(fps: fps)
    let per60 = f.frame * 60, perRate = f.frame * Double(f.rate)
    #expect(abs(per60 - per60.rounded()) < 1e-9)
    #expect(abs(perRate - perRate.rounded()) < 1e-9)
    #expect(60.0.truncatingRemainder(dividingBy: Double(f.rate)) == 0)
}

@Test func episodePlanIsDeterministicAndAlwaysHasTheOwl() {
    let a = EpisodePlanner.plan(seed: 42, journey: journey, focusSeconds: 1500, lastFiveShare: 0.2, forced: nil)
    let b = EpisodePlanner.plan(seed: 42, journey: journey, focusSeconds: 1500, lastFiveShare: 0.2, forced: nil)
    #expect(a.map(\.0) == b.map(\.0))
    #expect(a.contains { $0.0 == .owl })   // Athena guides him home every lap
    #expect(zip(a, a.dropFirst()).allSatisfy { $0.1 <= $1.1 })
    #expect(a.allSatisfy { $0.1 > 0 && $0.1 < 1 })
}

@Test(arguments: [15.0, 25, 45, 50, 90, 1, 240])
func episodesStayInsideTheLapForAnyFocusLength(minutes: Double) {
    let seconds = minutes * 60
    for seed in UInt64(0)..<20 {
        let plan = EpisodePlanner.plan(seed: seed, journey: journey, focusSeconds: seconds,
                                       lastFiveShare: 300 / seconds, forced: nil)
        #expect(plan.allSatisfy { $0.1 > 0 && $0.1 < 1 })
        #expect(plan.contains { $0.0 == .owl })
    }
}
