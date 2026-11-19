import SwiftUI

// The stalk: one stem that climbs and puts out leaves in turn, a bud at its
// tip, then a bloom that opens. A sunflower is this rule.
//
// Growth: the seed (to .1), two seed leaves and a shoot (.1), the first true
// leaves (.28), a leaf at every hand's width (.5), the bud (.6 to .8), petals
// showing (.82), the head opening (.84 to .98). A thirsty one bends at the top
// and lets its leaves hang and its head hang forward; a dozing one is bowed.
//
// The stem is furry (short hairs, lit on the sun's side and dark on the
// other, two fills for the lot), the leaves are big veined hearts in three
// depth tiers merged into a few fills each (`LeafBatch`), and the head is in
// `PlantPainter+Sunflower.swift`.
extension PlantPainter {
    /// Leaves up the stem: how high, when it is born, how long.
    private static let nodes: [(height: Double, born: Double, length: Double)] = [
        (20, 0.15, 46), (46, 0.27, 58), (70, 0.36, 60), (94, 0.47, 56), (120, 0.6, 50), (142, 0.72, 42),
    ]

    func stalk(_ c: GraphicsContext?, _ m: inout Marks) {
        let side = seed.side, wilt = self.wilt
        let rise = grown([(0.09, 0), (0.12, 14), (0.3, 58), (0.52, 105), (0.76, 150), (0.9, 168), (1, 172)]) * (plan.height - 33) / 172
        // A young stem stands straight. As it tires it bends over at the top,
        // the way it leans: the control stays high, the tip goes out and down.
        let bendIn = Ink.smooth((p - 0.28) / 0.3)
        let tip = CGPoint(x: seed.lean * 5 * bendIn + side * wilt * 0.46 * rise, y: -rise * (1 - 0.3 * wilt))
        let control = CGPoint(x: seed.lean * 3 * bendIn, y: -rise * 0.82)
        let spine = Self.quad(CGPoint(x: 0, y: 1), control, tip, n: 22)
        let width = Ink.lerp(3.2, 7.2, Ink.smooth(p / 0.9)) * (1 - 0.18 * wilt)
        let stem = Self.ribbon(spine, width, width * 0.62)

        /// The stem's point at a height above the soil.
        func onStem(_ height: Double) -> CGPoint {
            for i in 1..<spine.count where -spine[i].y >= height {
                let a = spine[i - 1], b = spine[i]
                let t = (height + a.y) / max(0.001, a.y - b.y)
                return CGPoint(x: Ink.lerp(a.x, b.x, t), y: -height)
            }
            return spine[spine.count - 1]
        }

        // The seed leaves, which give way to the true ones.
        let seedLeaf = pop(0.1, over: 0.06) * (1 - Ink.smooth((p - 0.3) / 0.12))
        if seedLeaf > 0.02 {
            var cotyledons = LeafBatch()
            for s in [-1.0, 1] {
                let angle = s > 0 ? -0.3 + wilt * 0.8 : -.pi + 0.3 - wilt * 0.8
                if c != nil {
                    cotyledons.add(.of(.ovate, bend: s * (0.25 + wilt * 0.7)), base: CGPoint(x: 0, y: -2), angle: angle, length: 19 * seedLeaf, light: L,
                                   bright: bright(angle, luck: 0.5 + 0.2 * s, tier: 2), glossy: true)
                }
                m.note(CGPoint(x: cos(angle) * 17 * seedLeaf, y: -2 + sin(angle) * 17 * seedLeaf))
            }
            if let c { cotyledons.flush(c, inks[2], casting: false) }
        }

        // Leaves behind the stem, the stem, then the leaves in front of it.
        for tier in 0..<3 {
            if tier == 1, let c {
                paint(c, stem: stem, along: spine, width: width)
                furr(c, spine, width: width)
            }
            var batch = LeafBatch()
            for (i, node) in Self.nodes.enumerated() where i % 3 == tier {
                let k = pop(node.born, over: 0.09)
                guard k > 0.02, rise > node.height else { continue }
                let s = (i.isMultiple(of: 2) ? 1.0 : -1.0) * side
                let base = onStem(node.height)
                let length = node.length * k * (1 - 0.14 * wilt) * seed.between(i, 0.92, 1.08)
                let out = s > 0 ? -0.5 : -.pi + 0.5
                let angle = out + s * (wilt * 1.45 + seed.between(i + 8, -0.12, 0.12))
                let direction = CGPoint(x: cos(angle), y: sin(angle))
                let petiole = CGPoint(x: base.x + direction.x * 7 * k, y: base.y + direction.y * 7 * k)
                if c != nil {
                    let bend = s * (0.3 + 0.8 * wilt)
                    batch.add(.of(.heart, bend: bend), base: petiole, angle: angle, length: length, light: L,
                              bright: bright(angle, luck: luck(i + 3), tier: tier), glossy: i % 2 == 0)
                    batch.stalks.addPath(Self.ribbon([base, petiole], 2.4 * k, 2 * k))
                }
                let end = CGPoint(x: petiole.x + direction.x * length * 0.9, y: petiole.y + direction.y * length * 0.9)
                m.note(end)
                m.note(CGPoint(x: (petiole.x + end.x) / 2, y: (petiole.y + end.y) / 2), reach: length * 0.2, hang: false)
            }
            if let c { batch.flush(c, inks[tier], casting: tier > 0) }
        }
        m.note(CGPoint(x: spine[spine.count - 1].x, y: spine[spine.count - 1].y), reach: 4, hang: false)

        // The bud, and then the head.
        let budK = since(0.6, over: 0.24)
        guard budK > 0.02, rise > 100 else { return }
        let tangent = atan2(tip.y - control.y, tip.x - control.x)
        let heading = CGPoint(x: cos(tangent), y: sin(tangent))
        let open = Ink.smooth((p - 0.84) / 0.14)
        let petal = open * (0.55 + 0.45 * M.open)
        let discR = Ink.lerp(4.5 + 5 * budK, 19, Ink.smooth((p - 0.8) / 0.18))
        let centre = CGPoint(x: tip.x + heading.x * discR * 0.7, y: tip.y + heading.y * discR * 0.7)
        let reach = discR + 35 * petal + 2
        m.note(CGPoint(x: centre.x, y: centre.y), reach: reach, hang: false)
        if let c {
            head(c, at: centre, radius: discR, petal: petal, bud: budK)
            if p > 0.86 { fallen(c) }
        }
    }

    /// The stem's fur: short hairs along it, the lit side's pale and the other's
    /// dark, one fill each.
    private func furr(_ c: GraphicsContext, _ spine: [CGPoint], width: Double) {
        var lit = Path(), dark = Path()
        let toLit = L.x >= 0 ? 1.0 : -1.0
        for i in stride(from: 1, to: spine.count - 1, by: 1) {
            let q = spine[i]
            for s in [-1.0, 1] {
                let n = luck(i * 2 + (s > 0 ? 1 : 0))
                guard n > 0.2 else { continue }
                let from = CGPoint(x: q.x + s * width * 0.42, y: q.y)
                let to = CGPoint(x: from.x + s * (1.6 + 1.6 * n), y: from.y - 1.4 - 1.6 * n)
                if s == toLit { lit.spike(from: from, to: to, width: 0.7) } else { dark.spike(from: from, to: to, width: 0.7) }
            }
        }
        c.fill(dark, with: .color(ramp[0].shifted(-2).color(0.5)))
        c.fill(lit, with: .color(rimTone.mix(ramp[4], 0.4).color(0.62)))
    }
}
