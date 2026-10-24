import SwiftUI

/// Fur that breaks an edge from inside the body's own colour: the outline of a
/// form is walked and, every few units, pushed out into a small pointed tuft
/// that sweeps one way, so the silhouette itself is irregular. A tuft is never
/// a separate shape (a leaf stuck on the edge read as a fleck floating off the
/// cat); it is one fill with the form it belongs to. Built once per plan.
enum FurEdge {
    /// The outline of `path` as points about `step` units apart (a closed
    /// path made of lines, quads and cubics, as the pets' forms are).
    static func outline(_ path: Path, step: Double = 1.3) -> [CGPoint] {
        var points: [CGPoint] = []
        var current = CGPoint.zero
        var start = CGPoint.zero
        path.forEach { element in
            switch element {
            case let .move(to):
                current = to; start = to; points.append(to)
            case let .line(to):
                let n = max(1, Int((hypot(to.x - current.x, to.y - current.y) / step).rounded(.up)))
                for i in 1...n { let t = Double(i) / Double(n); points.append(CGPoint(x: current.x + (to.x - current.x) * t, y: current.y + (to.y - current.y) * t)) }
                current = to
            case let .quadCurve(to, c):
                let len = hypot(c.x - current.x, c.y - current.y) + hypot(to.x - c.x, to.y - c.y)
                let n = max(2, Int((len / step).rounded(.up)))
                for i in 1...n {
                    let t = Double(i) / Double(n), u = 1 - t
                    points.append(CGPoint(x: u * u * current.x + 2 * u * t * c.x + t * t * to.x, y: u * u * current.y + 2 * u * t * c.y + t * t * to.y))
                }
                current = to
            case let .curve(to, c1, c2):
                let len = hypot(c1.x - current.x, c1.y - current.y) + hypot(c2.x - c1.x, c2.y - c1.y) + hypot(to.x - c2.x, to.y - c2.y)
                let n = max(3, Int((len / step).rounded(.up)))
                for i in 1...n {
                    let t = Double(i) / Double(n), u = 1 - t
                    let k0 = u * u * u, k1 = 3 * u * u * t, k2 = 3 * u * t * t, k3 = t * t * t
                    points.append(CGPoint(x: k0 * current.x + k1 * c1.x + k2 * c2.x + k3 * to.x, y: k0 * current.y + k1 * c1.y + k2 * c2.y + k3 * to.y))
                }
                current = to
            case .closeSubpath:
                if hypot(current.x - start.x, current.y - start.y) > 0.01 { points.append(start) }
                current = start
            }
        }
        if let first = points.first, let last = points.last, hypot(first.x - last.x, first.y - last.y) < 0.01 { points.removeLast() }
        return points
    }

    /// The same outline with tufts: one every `gap` units (random in the range),
    /// `height` tall (random in the range, times `mask` at that point: 0 leaves
    /// the edge alone), about `width` units across, leaning along the edge.
    static func furry(_ path: Path, seed: String, gap: ClosedRange<Double> = 5...10, height: ClosedRange<Double> = 1.5...3,
                      width: Double = 3.6, mask: (CGPoint) -> Double = { _ in 1 }) -> Path {
        let p = outline(path)
        let n = p.count
        guard n > 8 else { return path }
        // Which way is out: the sign of the area.
        var area = 0.0
        for i in 0..<n { let a = p[i], b = p[(i + 1) % n]; area += a.x * b.y - b.x * a.y }
        let sign = area > 0 ? 1.0 : -1.0
        func tangent(_ i: Int) -> CGPoint {
            let a = p[(i + n - 2) % n], b = p[(i + 2) % n]
            let l = max(0.0001, hypot(b.x - a.x, b.y - a.y))
            return CGPoint(x: (b.x - a.x) / l, y: (b.y - a.y) / l)
        }
        var rand = Ink.Random(seed)
        var out = [Double](repeating: 0, count: n)
        var lean = [Double](repeating: 0, count: n)
        var travelled = 0.0
        var next = rand.between(gap.lowerBound, gap.upperBound) * 0.5
        let half = max(1, Int((width / 1.3 / 2).rounded()))
        for i in 0..<n {
            travelled += hypot(p[(i + 1) % n].x - p[i].x, p[(i + 1) % n].y - p[i].y)
            guard travelled >= next else { continue }
            travelled = 0
            next = rand.between(gap.lowerBound, gap.upperBound)
            let m = mask(p[i])
            guard m > 0.05 else { continue }
            let h = rand.between(height.lowerBound, height.upperBound) * m
            let dir = rand.next() < 0.7 ? 1.0 : -1.0
            for j in -half...half {
                let k = (i + j + n) % n
                let w = 1 - Double(abs(j)) / Double(half + 1)
                if h * w > out[k] { out[k] = h * w; lean[k] = 0.9 * h * w * dir }
            }
        }
        var path = Path()
        for i in 0..<n {
            let t = tangent(i)
            let nx = t.y * sign, ny = -t.x * sign
            let q = CGPoint(x: p[i].x + nx * out[i] + t.x * lean[i] * 0.6, y: p[i].y + ny * out[i] + t.y * lean[i] * 0.6)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        path.closeSubpath()
        return path
    }
}
