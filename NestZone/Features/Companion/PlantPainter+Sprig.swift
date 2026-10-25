import SwiftUI

// The sprig: upright woody stems dressed along their upper two thirds in
// needles, with small two-lipped flowers in the leaf axils and a cluster of
// buds at the tip. Rosemary is this rule; thyme or sage would be the same stems
// with another leaf.
//
// A needle is a thin triangle, a fill and not a stroke (RULES.md section 8), in
// one of three greens by how it faces the light, with a silver line on the lit
// ones (rosemary's underside is white and shows where a needle turns). Pairs
// alternate: one seen side on, spreading, one turned towards us, short.
//
// Growth: the seed (a cutting) to .1, two seed needles, the first stem (.1 to
// .7), the others fanning out of the crown (.26, .3, .46, .52), needles as each
// stem reaches them, flowers on the three tallest from .8. A thirsty one lets
// its needles hang and its tips bow; a dozing one keeps its flowers in bud.
extension PlantPainter {
    private struct Wand {
        var a, c1, c2, b: CGPoint
        var born, span, width: Double
    }

    private struct Needles {
        var shade = Path(), mid = Path(), lit = Path(), silver = Path()
    }

    func sprig(_ c: GraphicsContext?, _ m: inout Marks) {
        guard let flower = plan.flower else { return }
        let sx = seed.side, wilt = self.wilt
        func v(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y) }
        let h = plan.height / 152
        let wands = [
            Wand(a: v(0, 1), c1: v(-2, -62 * h), c2: v(-7 + 6 * wilt, -112 * h), b: v(-5 + 20 * wilt, -148 * h * (1 - 0.08 * wilt)), born: 0.1, span: 0.5, width: 4.2),
            Wand(a: v(3, 1), c1: v(22, -46 * h), c2: v(32, -92 * h), b: v(40 + 12 * wilt, -126 * h * (1 - 0.06 * wilt)), born: 0.26, span: 0.46, width: 3.6),
            Wand(a: v(-3, 1), c1: v(-24, -42 * h), c2: v(-38, -84 * h), b: v(-46 - 12 * wilt, -116 * h * (1 - 0.06 * wilt)), born: 0.3, span: 0.46, width: 3.6),
            Wand(a: v(5, 1), c1: v(11, -40 * h), c2: v(12, -70 * h), b: v(19 + 6 * wilt, -98 * h), born: 0.46, span: 0.36, width: 3),
            Wand(a: v(-5, 1), c1: v(-12, -36 * h), c2: v(-17, -62 * h), b: v(-24 - 6 * wilt, -84 * h), born: 0.52, span: 0.32, width: 2.8),
            Wand(a: v(7, 1), c1: v(34, -28 * h), c2: v(52, -58 * h), b: v(60 + 10 * wilt, -88 * h), born: 0.56, span: 0.3, width: 2.6),
            Wand(a: v(-7, 1), c1: v(-34, -26 * h), c2: v(-52, -54 * h), b: v(-62 - 10 * wilt, -78 * h), born: 0.6, span: 0.28, width: 2.6),
        ]
        func reach(_ i: Int) -> Double {
            i == 0 ? grown([(0.09, 0), (0.14, 0.15), (0.3, 0.5), (0.52, 0.85), (0.7, 1)]) : Ink.smooth((p - wands[i].born) / wands[i].span)
        }
        let paths = wands.enumerated().map { i, w in Self.cubic(w.a, w.c1, w.c2, w.b, upTo: max(0.001, reach(i)), n: 16) }

        // The seed needles, a pair, before the first stem has any.
        var needles = [Needles(), Needles()]
        let seedLeaf = pop(0.1, over: 0.06) * (1 - Ink.smooth((p - 0.3) / 0.12))
        if seedLeaf > 0.02 {
            for s in [-1.0, 1.0] {
                let angle = (s > 0 ? -0.5 : -.pi + 0.5) + s * wilt * 0.9
                let len = 12 * seedLeaf
                needles[1].mid.spike(from: CGPoint(x: 0, y: -3), to: CGPoint(x: cos(angle) * len, y: -3 + sin(angle) * len), width: 2.4)
                m.note(CGPoint(x: cos(angle) * len, y: -3 + sin(angle) * len))
            }
        }

        // Needles, two to a node, up the stem as far as it has grown. The back
        // stems (the fourth and fifth, and the third) go in the first batch.
        let tierOf = [1, 1, 0, 1, 0, 1, 0]
        for (i, wand) in wands.enumerated() {
            let r = reach(i)
            guard r > 0.04 else { continue }
            let path = paths[i]
            var t = 0.2, node = 0
            while t <= min(r, 1) {
                let at = t / r
                let q = Self.along(path, at), head = Self.heading(path, at)
                let age = min(1, (r - t) * 6 + 0.3)
                let full = node.isMultiple(of: 2)
                let len = (18 - 5 * t) * age * (full ? 1 : 0.6) * (1 - 0.12 * wilt) * seed.between(i * 7 + node, 0.9, 1.1)
                let spread = full ? 1.05 : 0.45
                for side in [-1.0, 1.0] {
                    let angle = head + side * spread + side * wilt * 0.55
                    let tip = CGPoint(x: q.x + cos(angle) * len, y: q.y + sin(angle) * len)
                    let b = bright(angle, luck: luck(i * 9 + node * 2 + (side > 0 ? 1 : 0)), tier: tierOf[i] == 0 ? 0 : 1)
                    if c != nil {
                        if b < 0.36 { needles[tierOf[i]].shade.spike(from: q, to: tip, width: 2.7) }
                        else if b < 0.68 { needles[tierOf[i]].mid.spike(from: q, to: tip, width: 2.7) }
                        else { needles[tierOf[i]].lit.spike(from: q, to: tip, width: 2.7) }
                        if b > 0.5 {
                            needles[tierOf[i]].silver.spike(from: CGPoint(x: q.x + 0.4, y: q.y), to: CGPoint(x: q.x + (tip.x - q.x) * 0.85, y: q.y + (tip.y - q.y) * 0.85), width: 0.7)
                        }
                    }
                    if node.isMultiple(of: 3), full { m.note(tip) }
                }
                t += 0.034
                node += 1
            }
            _ = wand
        }

        if let c {
            func flush(_ n: Needles, _ ink: LeafInk) {
                c.fill(n.shade, with: .color(ink.d))
                c.fill(n.mid, with: .color(ink.m))
                c.fill(n.lit, with: .color(ink.l))
                c.fill(n.silver, with: .color(rimTone.mix(ramp[4], 0.5).color(0.5)))
            }
            let wood = 0x7A5A44 as UInt32
            for i in [2, 4, 6] where reach(i) > 0.02 {
                let w = wands[i].width * (1 - 0.15 * wilt)
                paint(c, stem: Self.ribbon(paths[i], w, w * 0.55), along: paths[i], width: w, tier: 0, tint: wood)
            }
            flush(needles[0], inks[0])
            for i in [0, 1, 3, 5] where reach(i) > 0.02 {
                let w = wands[i].width * (1 - 0.15 * wilt)
                paint(c, stem: Self.ribbon(paths[i], w, w * 0.55), along: paths[i], width: w, tier: 1, tint: wood)
            }
            flush(needles[1], inks[1])
            if p > 0.76 { flowers(c, flower: flower, paths: paths, reach: reach, &m) }
        } else {
            for i in 0..<wands.count where reach(i) > 0.5 { m.note(paths[i][paths[i].count - 1], reach: 3, hang: false) }
        }
        m.note(paths[0][paths[0].count - 1], reach: 4, hang: false)
    }

    /// Small flowers in the axils of the top third of the three tallest stems,
    /// and a cluster of buds at each tip: a hood and a lip, pale blue, a dab of
    /// violet on the lip. Green and shut while the house is quiet.
    private func flowers(_ c: GraphicsContext, flower: PlantPlan.Flower, paths: [[CGPoint]], reach: (Int) -> Double, _ m: inout Marks) {
        let open = Ink.smooth((p - 0.8) / 0.14) * (0.3 + 0.7 * M.open) * (1 - 0.35 * M.doze)
        let blue = bloom(flower.mid, dim: 0.5), pale = bloom(flower.pale, dim: 0.5), violet = bloom(flower.deep, dim: 0.5)
        let green = ramp[3].mix(ramp[4], 0.25)
        let toLit = L.x >= 0 ? 1.0 : -1.0
        var lit = Path(), shade = Path(), lip = Path(), dab = Path(), buds = Path()
        for i in 0..<3 {
            guard reach(i) > 0.9 else { continue }
            let path = paths[i]
            for (n, t) in [0.66, 0.76, 0.86, 0.95].enumerated() {
                let q = Self.along(path, t), head = Self.heading(path, t)
                let size = (5.6 - 0.5 * Double(n)) * (0.55 + 0.45 * open)
                for side in [-1.0, 1.0] {
                    guard (n + i + (side > 0 ? 1 : 0)) % 3 != 0 else { continue }
                    let a = head + side * 0.95
                    let at = CGPoint(x: q.x + cos(a) * 2.2, y: q.y + sin(a) * 2.2)
                    var hood = Path(), under = Path()
                    hood.leaf(at.x, at.y, cos(a - side * 0.35), sin(a - side * 0.35), size, size * 0.34, 0.5)
                    under.leaf(at.x, at.y, cos(a + side * 0.5), sin(a + side * 0.5), size * 0.72, size * 0.28, 0.5)
                    if side == toLit { lit.addPath(hood) } else { shade.addPath(hood) }
                    lip.addPath(under)
                    dab.addEllipse(in: CGRect(x: at.x + cos(a + side * 0.5) * size * 0.38 - 0.7, y: at.y + sin(a + side * 0.5) * size * 0.38 - 0.7, width: 1.4, height: 1.4))
                }
            }
            let tip = path[path.count - 1], head = Self.heading(path, 1)
            for s in [-1.0, 0.0, 1.0] {
                buds.leaf(tip.x, tip.y, cos(head + s * 0.35), sin(head + s * 0.35), 5.2 - 1.4 * abs(s), 1.5, 0.4)
            }
            m.note(CGPoint(x: tip.x, y: tip.y - 3), reach: 5, hang: false)
        }
        c.fill(buds, with: .color(green.mix(blue, open * 0.6).color()))
        c.fill(shade, with: .color(green.mix(blue.mix(violet, 0.3), open).color()))
        c.fill(lit, with: .color(green.mix(blue.mix(pale, 0.35), open).color()))
        c.fill(lip, with: .color(green.mix(pale, open).color()))
        c.fill(dab, with: .color(violet.color(0.85 * open)))
    }
}
