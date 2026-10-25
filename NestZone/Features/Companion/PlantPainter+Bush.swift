import SwiftUI

// The bush: a stem that grows by pairs of leaves, each pair turned a quarter
// from the one below, two branches that start low and make the plant wide, a
// tuft of young leaves at the top, and a spike of small white flowers once it
// is grown. Basil is this rule; mint and rosemary change the leaf, lavender
// the spike.
//
// Fewer and fuller than the first drawing: five pairs and two short branches,
// each leaf a cupped, glossy oval with its veins (`LeafShape.ovate`), the half
// that faces the light a tone lighter and a glint beside the rib.
//
// Growth: the seed, two seed leaves (.1), the first pair (.12), a new pair
// about every tenth, the branches (.4 and .5), the spike (.88). A thirsty one
// shows it first: its leaves roll and hang from the node and its tip nods; a
// dozing one is folded down.
extension PlantPainter {
    /// Pairs up the main stem: height, birth.
    private static let pairs: [(height: Double, born: Double)] = [
        (15, 0.12), (30, 0.22), (45, 0.34), (60, 0.48), (75, 0.62),
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
        let width = Ink.lerp(2.8, 4.6, Ink.smooth(p / 0.7))
        var tiers = [LeafBatch(), LeafBatch(), LeafBatch()]
        var young = LeafBatch()

        /// One leaf on a short stalk from `base`, pointing out to one `side` and
        /// `lift` radians above level. It hangs and curls as the house goes quiet.
        func leaf(_ base: CGPoint, side s: Double, lift: Double, length: Double, tier: Int, n: Int, petiole: Double = 5,
                  curl: Double = 0.3, hang: Double = 1.4, fresh: Bool = false) {
            let angle = (s > 0 ? -lift : -.pi + lift) + s * wilt * hang
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let start = CGPoint(x: base.x + direction.x * petiole, y: base.y + direction.y * petiole)
            if c != nil {
                let shape = LeafShape.of(.ovate, bend: s * (curl + 0.8 * wilt))
                let b = bright(angle, luck: luck(n), tier: tier)
                if fresh {
                    young.add(shape, base: start, angle: angle, length: length, light: L, bright: b, glossy: true)
                    young.stalks.addPath(Self.ribbon([base, start], 2, 1.6))
                } else {
                    tiers[tier].add(shape, base: start, angle: angle, length: length, light: L, bright: b, glossy: true)
                    if petiole > 0.5 { tiers[tier].stalks.addPath(Self.ribbon([base, start], 2.2, 1.8)) }
                }
            }
            m.note(CGPoint(x: start.x + direction.x * length * 0.9, y: start.y + direction.y * length * 0.9))
        }

        // The seed leaves, which the first pairs outgrow.
        let seedLeaf = pop(0.1, over: 0.06) * (1 - Ink.smooth((p - 0.34) / 0.12))
        if seedLeaf > 0.02 {
            for s in [-1.0, 1] {
                leaf(CGPoint(x: 0, y: -3), side: s, lift: 0.3, length: 17 * seedLeaf, tier: 1, n: 30 + Int(s + 1), petiole: 0, curl: 0.2, hang: 0.9)
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
                let n = index * 2 + (s > 0 ? 1 : 0)
                if front {
                    leaf(base, side: s, lift: 1.12, length: l * 0.84, tier: 2, n: n, petiole: 2, curl: 0.12, hang: 1.2)
                } else {
                    leaf(base, side: s, lift: 0.72 + seed.between(index, -0.1, 0.1), length: l, tier: s == side ? 1 : 0, n: n)
                }
            }
        }

        let nodes = Self.pairs.enumerated().filter { rise > $0.element.height + 4 }
        // Behind the stem: the branches and the pairs seen side on.
        var branchStems = Path()
        for branch in branches {
            let w = width * 0.8
            branchStems.addPath(Self.ribbon(branch.spine, w, w * 0.7))
            for (n, t) in [0.6, 1.0].enumerated() where p > branch.born + 0.1 * Double(n + 1) {
                pair(Self.along(branch.spine, t), n + 11 + (branch.side > 0 ? 3 : 0), born: branch.born + 0.1 * Double(n + 1), length: 31 - Double(n) * 6, front: false)
            }
        }
        for (i, node) in nodes where i.isMultiple(of: 2) {
            pair(Self.height(spine, node.height), i, born: node.born, length: Ink.lerp(46, 30, Double(i) / 4), front: false)
        }
        if let c {
            for tier in 0..<2 {
                if tier == 1 {
                    if !branchStems.isEmpty { c.fill(branchStems, with: .linearGradient(Gradient(colors: [ramp[2].color(), ramp[1].color()]), startPoint: CGPoint(x: -20, y: 0), endPoint: CGPoint(x: 20, y: 0))) }
                }
                tiers[tier].flush(c, inks[tier], casting: tier > 0)
            }
            paint(c, stem: Self.ribbon(spine, width, width * 0.62), along: spine, width: width)
        }
        for (i, node) in nodes where !i.isMultiple(of: 2) {
            pair(Self.height(spine, node.height), i, born: node.born, length: Ink.lerp(46, 30, Double(i) / 4), front: true)
        }

        // The tuft at the top, lighter, and then the spike that replaces it.
        let tuft = pop(0.3, over: 0.1) * (1 - Ink.smooth((p - 0.84) / 0.1))
        if tuft > 0.02, rise > 60 {
            for (n, s) in [-1.0, 1.0].enumerated() {
                leaf(tip, side: s, lift: 1.2, length: Ink.lerp(11, 18, Ink.smooth((p - 0.3) / 0.5)) * tuft, tier: 2, n: 20 + n,
                     petiole: 1, curl: 0.15, hang: 1.2, fresh: true)
            }
        }
        if let c {
            tiers[2].flush(c, inks[2])
            young.flush(c, fresh)
        }
        let spikeK = Ink.smooth((p - 0.88) / 0.1)
        if spikeK > 0.02, plan.flower != nil {
            let top = CGPoint(x: tip.x + seed.lean * 1.5 + side * wilt * 6, y: tip.y - 50 * spikeK - wilt * 5)
            if let c { spike(c, from: CGPoint(x: tip.x, y: tip.y - 2), to: top, grow: spikeK) }
            m.note(top, reach: 6, hang: false)
        }
        m.note(tip, reach: 4, hang: false)
    }

    /// The flower spike: whorls of small white flowers up a green stalk, each
    /// two-lipped with a dab of lilac, in a green cup, a pair of small leaves
    /// under it, and a cluster of buds at the top. Pale by the sun's side and
    /// lilac-grey in its own shade.
    private func spike(_ c: GraphicsContext, from base: CGPoint, to top: CGPoint, grow: Double) {
        guard let flower = plan.flower else { return }
        let stalk = Self.quad(base, CGPoint(x: base.x, y: (base.y + top.y) / 2), top, n: 6)
        c.fill(Self.ribbon(stalk, 2.6, 1.8), with: .color(ramp[2].color()))
        let open = M.open * (1 - 0.3 * M.doze)
        let white = bloom(flower.pale, dim: 0.4), tone = bloom(flower.mid, dim: 0.4), dab = bloom(flower.deep, dim: 0.4)
        let green = ramp[3].mix(ramp[4], 0.3)
        var calyx = Path(), bracts = Path(), lit = Path(), shaded = Path(), marks = Path()
        let toLit = L.x >= 0 ? 1.0 : -1.0
        for w in 0..<6 {
            let t = (Double(w) + 0.6) / 6.4
            let at = CGPoint(x: Ink.lerp(base.x, top.x, t), y: Ink.lerp(base.y, top.y, t))
            let k = Ink.smooth(grow * 2.2 - t * 1.1) * (1 - 0.12 * Double(w))
            guard k > 0.05 else { continue }
            for s in [-1.0, 1] {
                let a = s > 0 ? -0.35 : -.pi + 0.35
                let len = 12.5 * k
                // The little leaves under a whorl, then the cup, then the flower.
                bracts.leaf(at.x, at.y + 2.4, cos(a + s * 0.5), sin(a + s * 0.5), len * 0.7, len * 0.2, 0)
                calyx.leaf(at.x, at.y + 1.6, cos(a), sin(a), len * 0.55, len * 0.26, 0)
                let flowerLen = len * (0.5 + 0.55 * open)
                var floret = Path()
                // The upper hood and the lower lip.
                floret.leaf(at.x + s * 0.6, at.y, cos(a - s * 0.18), sin(a - s * 0.18), flowerLen, len * (0.2 + 0.18 * open), 0.5)
                floret.leaf(at.x + s * 0.6, at.y + 0.6, cos(a + s * 0.4), sin(a + s * 0.4), flowerLen * 0.62, len * 0.16 * (0.5 + open), 0.5)
                if s == toLit { lit.addPath(floret) } else { shaded.addPath(floret) }
                marks.addEllipse(in: CGRect(x: at.x + s * len * 0.55 - 0.9, y: at.y - len * 0.18 - 0.9, width: 1.8, height: 1.8))
            }
        }
        c.fill(bracts, with: .color(ramp[3].color()))
        c.fill(calyx, with: .color(green.mix(ramp[4], 0.3).color()))
        // Closed buds are green and small; open florets are white.
        c.fill(shaded, with: .color(green.mix(tone.mix(dab, 0.25), open).color()))
        c.fill(lit, with: .color(green.mix(white, open).color()))
        c.fill(marks, with: .color(dab.color(0.8 * open)))
        var buds = Path()
        buds.leaf(top.x, top.y + 1, 0, -1, 5 * grow, 1.8 * grow, 0.4)
        buds.leaf(top.x - 1.2, top.y + 1.6, -0.4, -0.9, 3.8 * grow, 1.4 * grow, 0.4)
        buds.leaf(top.x + 1.2, top.y + 1.6, 0.4, -0.9, 3.8 * grow, 1.4 * grow, 0.4)
        c.fill(buds, with: .color(green.mix(white, open * 0.5).color()))
    }
}
