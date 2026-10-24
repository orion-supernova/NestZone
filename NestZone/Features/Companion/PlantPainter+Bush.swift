import SwiftUI

// The bush: a stem that grows by pairs of leaves, each pair turned a quarter
// from the one below, two branches that start low and make the plant wide, a
// tuft of young leaves at the top, and a spike of small flowers once it is
// grown. Basil is this rule; mint and rosemary change the leaf, lavender the
// spike.
//
// Growth: the seed, two seed leaves (.1), the first pair (.12), a new pair
// about every tenth, the branches (.4 and .5), the spike (.9). A thirsty one
// shows it first: its leaves roll and hang from the node and its tip nods; a
// dozing one is folded down.
extension PlantPainter {
    /// Pairs up the main stem: height, birth.
    private static let pairs: [(height: Double, born: Double)] = [
        (14, 0.12), (27, 0.2), (40, 0.28), (53, 0.36), (66, 0.45), (79, 0.55), (92, 0.65),
    ]

    private struct Branch {
        var spine: [CGPoint]
        var side: Double
        var born: Double
        var length: Double
    }

    func bush(_ c: GraphicsContext?, _ m: inout Marks) {
        let side = seed.side, wilt = self.wilt
        let rise = grown([(0.09, 0), (0.12, 10), (0.3, 44), (0.52, 84), (0.76, 108), (1, 118)]) * (plan.height - 26) / 118
        let tip = CGPoint(x: seed.lean * 6 + side * wilt * 0.2 * rise, y: -rise * (1 - 0.08 * wilt))
        let spine = Self.quad(CGPoint(x: 0, y: 1), CGPoint(x: seed.lean * 2, y: -rise * 0.55), tip, n: 16)
        let width = Ink.lerp(2.6, 4.2, Ink.smooth(p / 0.7))

        // The seed leaves, which the first pairs outgrow.
        let seedLeaf = pop(0.1, over: 0.06) * (1 - Ink.smooth((p - 0.34) / 0.12))
        if seedLeaf > 0.02 {
            for s in [-1.0, 1] {
                place(c, &m, at: CGPoint(x: 0, y: -3), side: s, lift: 0.3, length: 15 * seedLeaf, tier: 1, petiole: 0, curl: 0.2, slim: 1.2, hang: 0.9)
            }
        }

        // Two branches from low on the stem, one each way, that start out
        // sideways and then climb.
        var branches: [Branch] = []
        for (k, (height, born, length)) in [(22.0, 0.4, 56.0), (34.0, 0.5, 48.0)].enumerated() {
            let grow = Ink.smooth((p - born) / 0.34)
            guard grow > 0.02, rise > height else { continue }
            let s = k == 0 ? -side : side
            let base = Self.height(spine, height)
            let l = length * grow
            let end = CGPoint(x: base.x + s * l * 0.72, y: base.y - l * 0.82 + wilt * l * 0.5)
            let control = CGPoint(x: base.x + s * l * 0.66, y: base.y - l * 0.1 + wilt * l * 0.2)
            branches.append(Branch(spine: Self.quad(base, control, end, n: 10), side: s, born: born, length: l))
        }

        /// One pair of leaves at a node. Alternate pairs are seen side on,
        /// opening out like a pair of hands, and turned a quarter, coming at
        /// us shorter and overlapping the stem.
        func pair(_ base: CGPoint, _ index: Int, born: Double, length: Double, front: Bool) {
            let k = pop(born, over: 0.08)
            guard k > 0.02 else { return }
            let l = length * k * seed.between(index + 3, 0.92, 1.08)
            for s in [-1.0, 1] {
                if front {
                    place(c, &m, at: base, side: s, lift: 1.12, length: l * 0.82, tier: 2, petiole: 2, curl: 0.1, slim: 1.1, hang: 1.2)
                } else {
                    place(c, &m, at: base, side: s, lift: 0.72 + seed.between(index, -0.1, 0.1), length: l, tier: s == side ? 1 : 0)
                }
            }
        }

        let nodes = Self.pairs.enumerated().filter { rise > $0.element.height + 4 }
        // Behind the stem: the branches and the pairs seen side on.
        for branch in branches {
            if let c {
                let w = width * 0.8
                paint(c, stem: Self.ribbon(branch.spine, w, w * 0.7), along: branch.spine, width: w, tier: 1)
            }
            for (n, t) in [0.55, 1.0].enumerated() where p > branch.born + 0.1 * Double(n + 1) {
                pair(Self.along(branch.spine, t), n + 1, born: branch.born + 0.1 * Double(n + 1), length: 27 - Double(n) * 5, front: false)
            }
        }
        for (i, node) in nodes where i.isMultiple(of: 2) {
            pair(Self.height(spine, node.height), i, born: node.born, length: Ink.lerp(40, 25, Double(i) / 6), front: false)
        }
        if let c { paint(c, stem: Self.ribbon(spine, width, width * 0.62), along: spine, width: width) }
        for (i, node) in nodes where !i.isMultiple(of: 2) {
            pair(Self.height(spine, node.height), i, born: node.born, length: Ink.lerp(40, 25, Double(i) / 6), front: true)
        }

        // The tuft at the top, lighter, and then the spike that replaces it.
        let tuft = pop(0.3, over: 0.1)
        if tuft > 0.02, rise > 60 {
            for s in [-1.0, 1] {
                place(c, &m, at: tip, side: s, lift: 1.2, length: Ink.lerp(9, 15, Ink.smooth((p - 0.3) / 0.5)) * tuft, tier: 2,
                      petiole: 1, curl: 0.15, slim: 1.15, hang: 1.2, young: 1)
            }
        }
        let spikeK = Ink.smooth((p - 0.88) / 0.1)
        if spikeK > 0.02, let flower = plan.flower {
            let height = 26 * spikeK
            let base = CGPoint(x: tip.x, y: tip.y - 2)
            let top = CGPoint(x: tip.x + seed.lean * 1.5 + side * wilt * 6, y: tip.y - height - wilt * 4)
            if let c {
                let stalk = Self.quad(base, CGPoint(x: tip.x, y: (base.y + top.y) / 2), top, n: 6)
                c.fill(Self.ribbon(stalk, 2.4, 1.6), with: .color(ramp[2].color()))
                let open = M.open * (1 - 0.3 * M.doze)
                let petal = bloom(flower.mid, dim: 0.4), deep = bloom(flower.deep, dim: 0.4)
                let green = ramp[3].mix(ramp[4], 0.3)
                var calyx = Path(), florets = Path(), marks = Path()
                for w in 0..<4 {
                    let t = (Double(w) + 0.6) / 4.4
                    let y = Ink.lerp(base.y, top.y, t)
                    let x = Ink.lerp(base.x, top.x, t)
                    let k = Ink.smooth(spikeK * 2 - t) * (1 - 0.18 * Double(w))
                    guard k > 0.05 else { continue }
                    for s in [-1.0, 1] {
                        let a = s > 0 ? -0.35 : -.pi + 0.35
                        let len = 7.5 * k
                        calyx.leaf(x, y + 1.6, cos(a), sin(a), len * 0.6, len * 0.26, 0)
                        // Closed buds are green and small; open florets are pale with a dab of lilac.
                        florets.leaf(x + s * 0.6, y, cos(a), sin(a), len * (0.5 + 0.55 * open), len * (0.2 + 0.18 * open), 0.5)
                        marks.addEllipse(in: CGRect(x: x + s * len * 0.55 - 0.9, y: y - len * 0.2 - 0.9, width: 1.8, height: 1.8))
                    }
                }
                c.fill(calyx, with: .color(green.color()))
                c.fill(florets, with: .color(green.mix(petal, open).color()))
                c.fill(marks, with: .color(deep.color(0.8 * open)))
                c.fill(Path(ellipseIn: CGRect(x: top.x - 1.7, y: top.y - 3.4, width: 3.4, height: 4.6)), with: .color(green.mix(petal, open * 0.6).color()))
            }
            m.note(top, reach: 6, hang: false)
        }
        m.note(tip, reach: 4, hang: false)
    }
}

extension PlantPainter {
    /// The point on a sampled stem at a share of its way along.
    static func along(_ points: [CGPoint], _ t: Double) -> CGPoint {
        let f = Ink.clamp(t) * Double(points.count - 1)
        let i = min(Int(f), points.count - 2), u = f - Double(i)
        return CGPoint(x: Ink.lerp(points[i].x, points[i + 1].x, u), y: Ink.lerp(points[i].y, points[i + 1].y, u))
    }

    /// The point on a sampled stem at a height above its first point.
    static func height(_ points: [CGPoint], _ height: Double) -> CGPoint {
        for i in 1..<points.count where points[0].y - points[i].y >= height {
            let a = points[i - 1], b = points[i]
            let t = (height - (points[0].y - a.y)) / max(0.001, a.y - b.y)
            return CGPoint(x: Ink.lerp(a.x, b.x, t), y: Ink.lerp(a.y, b.y, t))
        }
        return points[points.count - 1]
    }
}
