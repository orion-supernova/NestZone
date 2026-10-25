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
            // A branch along the middle with needles that sweep down and out,
            // and a shorter row standing up along its top.
            let count = 58
            for i in 0..<count {
                let x = (Double(i) / Double(count - 1) * 2 - 1) * 0.96 + (r.next() - 0.5) * 0.04
                let upper = r.next() < 0.28
                let axisY = -0.06 + 0.1 * abs(x)
                let lean = x * (upper ? 0.5 : 0.9) + (r.next() - 0.5) * 0.4
                let len = (upper ? 0.26 : 0.46 + 0.3 * (1 - abs(x))) * (0.8 + 0.4 * r.next())
                let dy = upper ? -1.0 : 1.0
                let tip = CGPoint(x: x + lean * len, y: axisY + dy * len * 0.95)
                let from = CGPoint(x: x, y: axisY)
                shape.shade.spike(from: from, to: tip, width: 0.22)
                if upper || x > -0.3 { shape.mid.spike(from: CGPoint(x: x, y: axisY - 0.03), to: CGPoint(x: tip.x, y: tip.y - 0.05), width: 0.12) }
                if upper && x > -0.4 { shape.lit.spike(from: CGPoint(x: x + 0.02, y: axisY - 0.04), to: CGPoint(x: tip.x + 0.02, y: tip.y - 0.06), width: 0.045) }
                if !upper, x > 0, r.next() < 0.3 { shape.top.spike(from: CGPoint(x: x + 0.02, y: axisY - 0.02), to: CGPoint(x: tip.x * 0.98 + 0.03, y: axisY + len * 0.5), width: 0.035) }
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
