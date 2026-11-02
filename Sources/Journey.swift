import CoreGraphics
import Foundation

/// What the traveler is doing on an edge. The route runs counter-clockwise from the
/// bottom-left corner: crawl right along the floor, climb up the right wall, cling to the
/// ceiling while the wind carries it left, slide down the left wall and land.
enum EdgeKind: Int { case floor = 0, climb, ceiling, slide }

struct Edge {
    let kind: EdgeKind
    let start: CGPoint
    let end: CGPoint
    /// Sprite rotation (radians, counter-clockwise). The sprite is drawn facing +x with feet
    /// toward -y, so rotating it puts its feet on the screen edge it travels along.
    let angle: CGFloat
    var length: CGFloat { hypot(end.x - start.x, end.y - start.y) }
    func point(_ f: Double) -> CGPoint {
        CGPoint(x: start.x + (end.x - start.x) * f, y: start.y + (end.y - start.y) * f)
    }
}

/// Maps elapsed share of a session to a place on the route. Speed differs per edge
/// (climbing is slow, sliding is fast), but the mapping is monotonic and exact: the
/// traveler leaves each corner at a fixed time and arrives home exactly when time is up.
struct Journey {
    /// Relative slowness per edge kind; time share of an edge = length x weight / total.
    static let physicalWeights: [EdgeKind: Double] = [.floor: 1.0, .climb: 1.6, .ceiling: 1.1, .slide: 0.45]
    static let uniformWeights: [EdgeKind: Double] = [.floor: 1, .climb: 1, .ceiling: 1, .slide: 1]

    let edges: [Edge]
    /// Cumulative time fraction at the start of each edge, plus 1.0 at the end.
    let timeMarks: [Double]
    /// Cumulative length fraction at the start of each edge, plus 1.0 at the end.
    let lengthMarks: [Double]

    init(size: CGSize, inset i: CGFloat, weights: [EdgeKind: Double]) {
        let w = size.width, h = size.height
        edges = [
            Edge(kind: .floor, start: CGPoint(x: i, y: i), end: CGPoint(x: w - i, y: i), angle: 0),
            Edge(kind: .climb, start: CGPoint(x: w - i, y: i), end: CGPoint(x: w - i, y: h - i), angle: .pi / 2),
            Edge(kind: .ceiling, start: CGPoint(x: w - i, y: h - i), end: CGPoint(x: i, y: h - i), angle: .pi),
            Edge(kind: .slide, start: CGPoint(x: i, y: h - i), end: CGPoint(x: i, y: i), angle: 3 * .pi / 2),
        ]
        let lens = edges.map { Double($0.length) }
        let costs = zip(edges, lens).map { $1 * (weights[$0.kind] ?? 1) }
        func marks(_ v: [Double]) -> [Double] {
            let total = v.reduce(0, +)
            var acc = 0.0
            return v.map { x -> Double in defer { acc += x / total }; return acc } + [1.0]
        }
        timeMarks = marks(costs)
        lengthMarks = marks(lens)
    }

    /// Edge index and linear progress inside it for an elapsed time share in [0, 1].
    func locate(_ t: Double) -> (index: Int, local: Double) {
        let t = min(max(t, 0), 1)
        for k in 0..<edges.count where t < timeMarks[k + 1] || k == edges.count - 1 {
            let span = timeMarks[k + 1] - timeMarks[k]
            return (k, span > 0 ? (t - timeMarks[k]) / span : 1)
        }
        return (edges.count - 1, 1)
    }

    /// Fraction of the whole route length covered at time share `t` (for the trail stroke).
    func lengthFraction(_ t: Double) -> Double {
        let (k, local) = locate(t)
        return lengthMarks[k] + (lengthMarks[k + 1] - lengthMarks[k]) * local
    }

    /// The closed route path along the screen edge, starting at the bottom-left corner.
    static func borderPath(size: CGSize, inset i: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: i, y: i))
        p.addLine(to: CGPoint(x: size.width - i, y: i))
        p.addLine(to: CGPoint(x: size.width - i, y: size.height - i))
        p.addLine(to: CGPoint(x: i, y: size.height - i))
        p.addLine(to: CGPoint(x: i, y: i))
        return p
    }
}
