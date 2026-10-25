import SwiftUI
import Synchronization

/// A pad of foliage worked out once in its own units (about two across, the
/// middle at the origin, up negative) and kept, as `LeafShape` keeps a leaf: a
/// sculpted plant puts one at the end of every branch with a transform and an
/// `addPath`, and a pad is four fills however many leaves it holds.
///
/// Four layers, back to front, drawn in four tones: all of it (`shade`), the
/// upper part of it moved up a little (`mid`), the sunward part (`lit`, built
/// for the sun on the right and mirrored for the left) and a few glints (`top`).
/// It is how a gouache tree is built (RULES.md section 8), at pad size.
struct PadShape: Sendable {
    var shade = Path(), mid = Path(), lit = Path(), top = Path()
}

enum PadArt {
    /// How a pad is built: a dome of small round leaves, a dome of small
    /// palmate leaves, or a drooping spray of needles.
    enum Kind: Int, Sendable { case leafy, maple, conifer }

    private static let cache = Mutex<[Int: PadShape]>([:])

    static func of(_ kind: Kind, variant: Int) -> PadShape {
        let key = kind.rawValue * 10 + variant % 3
        return cache.withLock { cache in
            if let found = cache[key] { return found }
            let made = make(kind, variant: variant % 3)
            cache[key] = made
            return made
        }
    }

    private static func make(_ kind: Kind, variant: Int) -> PadShape {
        var r = Ink.Random(seed: UInt32(101 + kind.rawValue * 17 + variant * 5))
        var shape = PadShape()
        switch kind {
        case .leafy, .maple:
            let n = kind == .leafy ? 70 : 46
            var items: [(x: Double, y: Double, a: Double, s: Double)] = []
            while items.count < n {
                let x = (r.next() * 2 - 1) * 0.94
                let lift = kind == .maple ? 0.78 : 0.5
                let top = -lift * (1 - x * x).squareRoot(), bottom = 0.16 * (1 - x * x).squareRoot()
                let y = top + (bottom - top) * pow(r.next(), 0.85)
                items.append((x, y, (r.next() - 0.5) * 3.2, 0.8 + 0.5 * r.next()))
            }
            // Back to front: lower leaves first, so the upper ones overlap them.
            items.sort { $0.y > $1.y }
            // A solid mass under the leaves, so the pad is a cloud and not a scatter.
            if kind == .leafy {
                shape.shade.oval(0, -0.14, 0.88, 0.36)
                shape.mid.oval(0.02, -0.2, 0.7, 0.26)
            } else {
                for (x, y, rx, ry) in [(-0.4, -0.1, 0.45, 0.3), (0.38, -0.12, 0.46, 0.32), (0, -0.3, 0.5, 0.34)] { shape.shade.oval(x, y, rx, ry) }
                shape.mid.oval(0, -0.32, 0.4, 0.26)
            }
            for item in items {
                let size = (kind == .leafy ? 0.25 : 0.22) * item.s
                add(&shape.shade, kind, item.x, item.y, item.a, size * 1.18)
                if item.y < 0.02 { add(&shape.mid, kind, item.x, item.y - 0.04, item.a, size) }
                if item.y < -0.12, item.x > -0.35 { add(&shape.lit, kind, item.x + 0.03, item.y - 0.07, item.a, size * 0.86) }
                if item.y < -0.28, item.x > -0.1, r.next() < 0.7 { add(&shape.top, kind, item.x + 0.05, item.y - 0.09, item.a, size * 0.5) }
            }
        case .conifer:
            // Tufts of fine needles along a drooping branch: at each tuft a
            // burst of thin needles radiating over the upper half-circle and
            // a few below, so a pad is a row of clear stars, not a shag.
            let tufts = 6
            for i in 0..<tufts {
                let x = (Double(i) / Double(tufts - 1) * 2 - 1) * 0.84
                // The branch droops towards its tip; the middle tuft is the fullest.
                let centre = CGPoint(x: x, y: -0.02 + 0.2 * pow(abs(x), 1.5))
                let reach = (0.34 + 0.12 * (1 - abs(x))) * (0.9 + 0.2 * r.next())
                let needles = 11
                for k in 0..<needles {
                    // Over the upper half-circle, turned outward with the droop.
                    let f = Double(k) / Double(needles - 1)
                    let a = -.pi * 0.96 + f * .pi * 0.92 + x * 0.42 + (r.next() - 0.5) * 0.12
                    let len = reach * (0.78 + 0.22 * sin(f * .pi)) * (0.92 + 0.16 * r.next())
                    let tip = CGPoint(x: centre.x + cos(a) * len, y: centre.y + sin(a) * len * 0.9)
                    shape.shade.spike(from: centre, to: tip, width: 0.072)
                    // The sunward half of the burst, thinner, a little shorter and higher.
                    if f > 0.25 && f < 0.95 && x > -0.5 {
                        shape.mid.spike(from: CGPoint(x: centre.x, y: centre.y - 0.02), to: CGPoint(x: centre.x + (tip.x - centre.x) * 0.92, y: centre.y + (tip.y - centre.y) * 0.92 - 0.02), width: 0.048)
                    }
                    if f > 0.45 && f < 0.9 && x > -0.2 {
                        shape.lit.spike(from: CGPoint(x: centre.x + 0.01, y: centre.y - 0.03), to: CGPoint(x: centre.x + (tip.x - centre.x) * 0.84, y: centre.y + (tip.y - centre.y) * 0.84 - 0.03), width: 0.03)
                    }
                }
                // A few needles hanging below the branch.
                for k in 0..<3 {
                    let a = .pi * (0.3 + 0.2 * Double(k)) + x * 0.3
                    let len = reach * 0.7
                    shape.shade.spike(from: centre, to: CGPoint(x: centre.x + cos(a) * len, y: centre.y + sin(a) * len), width: 0.09)
                }
                if x > -0.2 { shape.top.spike(from: CGPoint(x: centre.x, y: centre.y - 0.05), to: CGPoint(x: centre.x + 0.1, y: centre.y - reach * 0.88), width: 0.034) }
            }
        }
        return shape
    }

    /// One small leaf into a pad: a round lens (bonsai) or a five-pointed
    /// palmate leaf (maple), about `size` long, turned `angle`.
    private static func add(_ path: inout Path, _ kind: Kind, _ x: Double, _ y: Double, _ angle: Double, _ size: Double) {
        if kind == .leafy {
            path.leaf(x - cos(angle) * size * 0.5, y - sin(angle) * size * 0.5, cos(angle), sin(angle), size, size * 0.46, 0.55)
        } else {
            var points: [CGPoint] = []
            for k in 0..<10 {
                let a = angle + Double(k) * .pi / 5
                let rad = size * (k.isMultiple(of: 2) ? 0.62 : 0.26)
                points.append(CGPoint(x: x + cos(a) * rad, y: y + sin(a) * rad))
            }
            path.addLines(points)
            path.closeSubpath()
        }
    }
}
