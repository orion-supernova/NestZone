import SwiftUI
import Synchronization

/// A whole fern frond worked out once in its own units and kept, as `LeafShape`
/// keeps a leaf: the base at the origin, the rachis curving away along +x
/// (towards +y for a positive `bend`, -y for a negative one) to a length of 1,
/// and on either side of it a pinna at every step, closely packed, longest
/// about a third of the way up and shortening to a fine tip, each one a
/// narrow, serrated lance swept forward.
///
/// A plant places a frond with a transform and four `addPath`s: the body, the
/// pinnae on the side the light is on, the pinnae on the other, and the rachis.
/// The frond is not built from loose leaflets any more (which read as a sprig
/// of eucalyptus): it is one shape, and the cost of a fern is the number of its
/// fronds and not of its pinnae.
///
/// `reach` is how much of the frond has unrolled (a young one is a short
/// frond with a coil at its tip), in six steps; `bend` is how far the rachis
/// arches (the total turn of its heading, in steps of 0.2).
struct FrondShape: Sendable {
    /// Every pinna and the tip.
    var body = Path()
    /// The pinnae on the outer side of the arch (the upper surface of a bowing
    /// frond) and on the inner side (its underside).
    var upper = Path(), lower = Path()
    var rachis = Path()
    /// Where the unrolled part ends, and the way the rachis points there.
    var tip = CGPoint.zero
    var tipHeading = 0.0
    /// The reach this shape was built for (the step, not the request).
    var reach = 1.0

    static let reaches: [Double] = [0.16, 0.3, 0.5, 0.7, 0.86, 1]

    private static let cache = Mutex<[Int: FrondShape]>([:])

    static func of(bend: Double, reach: Double) -> FrondShape {
        let step = Int((max(-2.6, min(2.6, bend)) / 0.2).rounded())
        let r = reaches.firstIndex { $0 >= reach - 0.02 } ?? reaches.count - 1
        let key = (step + 20) * 10 + r
        return cache.withLock { cache in
            if let found = cache[key] { return found }
            let made = FrondShape(bend: Double(step) * 0.2, reach: reaches[r])
            cache[key] = made
            return made
        }
    }

    private init(bend: Double, reach: Double) {
        self.reach = reach
        func heading(_ u: Double) -> Double { bend * u }
        func centre(_ u: Double) -> CGPoint {
            guard abs(bend) > 0.01 else { return CGPoint(x: u, y: 0) }
            let phi = bend * u
            return CGPoint(x: sin(phi) / bend, y: (1 - cos(phi)) / bend)
        }
        /// A closed polygon, wound one way whatever order it was given in.
        func poly(_ points: [CGPoint]) -> Path {
            var area = 0.0
            for i in 0..<points.count {
                let p = points[i], q = points[(i + 1) % points.count]
                area += p.x * q.y - q.x * p.y
            }
            var path = Path()
            path.addLines(area < 0 ? Array(points.reversed()) : points)
            path.closeSubpath()
            return path
        }

        // The edge of a pinna from its base to its tip, as (along, across)
        // shares of its length and of its width: a lance with three teeth.
        let edge: [(u: Double, v: Double)] = [(0, 0.5), (0.3, 0.52), (0.42, 0.44), (0.62, 0.46), (0.74, 0.35), (0.88, 0.2), (1, 0)]
        let convex = bend >= 0 ? -1.0 : 1.0
        let pairs = 24
        for k in 0..<pairs {
            let tt = Double(k) / Double(pairs - 1)
            let u = (0.04 + 0.95 * tt) * reach
            let at = centre(u), h = heading(u)
            // Longest a third of the way up, a fine point at the end.
            let len = 0.23 * pow(max(0.02, 1 - pow(tt, 1.6)), 0.85) * min(1, 0.4 + tt * 5)
            let width = 0.038 * (0.55 + 0.45 * len / 0.23)
            let tangent = CGPoint(x: cos(h), y: sin(h))
            for side in [-1.0, 1.0] {
                let angle = h + side * (1.4 - 0.45 * tt)
                let along = CGPoint(x: cos(angle), y: sin(angle))
                let across = CGPoint(x: -along.y, y: along.x)
                func place(_ e: (u: Double, v: Double), _ s: Double) -> CGPoint {
                    // Swept forward towards the frond's tip as it goes out.
                    let sweep = e.u * e.u * len * 0.22
                    return CGPoint(x: at.x + along.x * e.u * len + across.x * s * e.v * width + tangent.x * sweep,
                                   y: at.y + along.y * e.u * len + across.y * s * e.v * width + tangent.y * sweep)
                }
                let outline = edge.map { place($0, 1) } + edge.dropLast().dropFirst().reversed().map { place($0, -1) } + [place(edge[0], -1)]
                let pinna = poly(outline)
                body.addPath(pinna)
                if side == convex { upper.addPath(pinna) } else { lower.addPath(pinna) }
            }
        }

        // The rachis, a thin ribbon that tapers, and the last stretch of it
        // as the fine tip of the frond.
        var left: [CGPoint] = [], right: [CGPoint] = []
        let steps = 14
        for i in 0...steps {
            let u = Double(i) / Double(steps) * reach
            let p = centre(u), h = heading(u)
            let w = 0.014 * (1 - 0.8 * Double(i) / Double(steps))
            left.append(CGPoint(x: p.x - sin(h) * w, y: p.y + cos(h) * w))
            right.append(CGPoint(x: p.x + sin(h) * w, y: p.y - cos(h) * w))
        }
        rachis = poly(left + right.reversed())
        tip = centre(reach)
        tipHeading = heading(reach)
        let end = CGPoint(x: tip.x + cos(tipHeading) * 0.05, y: tip.y + sin(tipHeading) * 0.05)
        body.addPath(poly([CGPoint(x: tip.x - sin(tipHeading) * 0.012, y: tip.y + cos(tipHeading) * 0.012), end,
                           CGPoint(x: tip.x + sin(tipHeading) * 0.012, y: tip.y - cos(tipHeading) * 0.012)]))
    }
}
