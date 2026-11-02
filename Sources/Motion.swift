import Foundation

// Pure motion math (no AppKit), shared by the overlay and the tests in Tests/.

/// Within-edge speed profile: the share of an edge covered at a given share of its time.
/// Gravity on the slide (accelerate), speed-up-and-brake on a zipline; linear elsewhere.
/// Edge start and end times never change, so the session still ends exactly on time.
func edgeProfile(_ kind: EdgeKind, zip: Bool) -> (Double) -> Double {
    switch kind {
    case .slide: return { u in u * u }
    case .ceiling where zip: return { u in u * u * (3 - 2 * u) }
    default: return { u in u }
    }
}

/// The rest of the route from time share `t`, as keyframes: (share of the remaining time,
/// edge index, position inside that edge after its speed profile). Corners are keyframes, so
/// one animation runs the whole way and never waits for the app at a corner. Curved edges
/// (slide, zipline) are sampled on a fixed grid of 24 steps and the start point lies on the
/// chord between grid points, so the path is the same whenever it is rebuilt: re-applying a
/// scene mid-edge continues exactly where the previous animation was.
func routeSamples(_ j: Journey, from t: Double, zip: Bool, profiled: Bool) -> [(time: Double, edge: Int, u: Double)] {
    let (k0, u0) = j.locate(t)
    func steps(_ k: Int) -> Int {
        profiled && (j.edges[k].kind == .slide || (zip && j.edges[k].kind == .ceiling)) ? 24 : 1
    }
    func shape(_ k: Int, _ u: Double) -> Double {   // the keyframed (chord) profile
        guard profiled else { return u }
        let f = edgeProfile(j.edges[k].kind, zip: zip), n = Double(steps(k))
        let g = min(floor(u * n), n - 1) / n
        return f(g) + (f(g + 1 / n) - f(g)) * (u - g) * n
    }
    func time(_ k: Int, _ u: Double) -> Double {
        (j.timeMarks[k] + (j.timeMarks[k + 1] - j.timeMarks[k]) * u - t) / max(1 - t, 1e-9)
    }
    var out = [(time: 0.0, edge: k0, u: shape(k0, u0))]
    for k in k0..<j.edges.count {
        let n = steps(k)
        for i in 1...n {
            let u = Double(i) / Double(n)
            if k == k0 && u <= u0 { continue }
            out.append((time: time(k, u), edge: k, u: shape(k, u)))
        }
    }
    return out
}

/// Peak speed factor of an edge profile (peak / average speed): u^2 -> 2, smoothstep -> 1.5.
func profilePeak(_ kind: EdgeKind, zip: Bool) -> Double {
    switch kind {
    case .slide: return 2
    case .ceiling where zip: return 1.5
    default: return 1
    }
}

/// Sprite flips that land exactly on display refreshes: every frame lasts a whole number of
/// 1/60 s ticks (so 60 Hz and 120 Hz panels agree), and the layer composites at 60/g fps,
/// g = the largest of 4, 3, 2, 1 that divides the tick count. E.g. 5 fps -> 12 ticks at 15 fps;
/// 4 fps -> 15 ticks at 20 fps; 8 fps -> 8 ticks (7.5 fps) at 15 fps.
func flipTiming(fps: Double) -> (frame: Double, rate: Float) {
    let ticks = max(1, (60 / fps).rounded())
    let g = [4.0, 3, 2, 1].first { ticks.truncatingRemainder(dividingBy: $0) == 0 } ?? 1
    return (ticks / 60, Float(60 / g))
}
