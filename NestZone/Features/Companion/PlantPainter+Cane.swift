import SwiftUI

// The cane: woody canes that arch out of the soil with thorns along them and
// compound leaves (a stalk with a terminal leaflet and two pairs, five in all,
// bronze while they are new) and a bloom at the tip of each. A rose is this
// rule; a bramble or a climbing rose is the same canes with more reach.
//
// Growth: the seed, two bronze seed leaves, one cane up with its first
// leaves (.12 to .55), a second arching out (.3 to .75), a short third with a
// bud (.5 to .8), buds swelling (.7), the first rose opening (.7 to .9), the
// second (.8 to 1), the third staying a bud. A thirsty one lets its leaves
// and its heads hang and drops petals; a dozing one keeps its roses closed.
extension PlantPainter {
    private struct Cane {
        var a, c1, c2, b: CGPoint
        var born, span: Double
        var width: Double
    }

    private struct Compound {
        var cane: Int
        var t, born: Double
        var side: Double
        var length: Double
        var tier: Int
    }

    func cane(_ c: GraphicsContext?, _ m: inout Marks) {
        guard plan.flower != nil else { return }
        let sx = seed.side, wilt = self.wilt
        func v(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y) }
        let sag = 1 + 0.18 * wilt
        let canes = [
            Cane(a: v(0, 1), c1: v(-6, -62), c2: v(-12 + 8 * wilt, -122), b: v(-4 + 22 * wilt, -166 * (1 - 0.1 * wilt)), born: 0.1, span: 0.45, width: 4.4),
            Cane(a: v(4, 1), c1: v(30, -40), c2: v(52, -84 * sag), b: v(48 + 8 * wilt, -122 * sag), born: 0.3, span: 0.45, width: 3.7),
            Cane(a: v(-2, -30), c1: v(-24, -58), c2: v(-40, -80 * sag), b: v(-40 - 4 * wilt, -100 * sag), born: 0.5, span: 0.3, width: 2.7),
        ]
        let leaves = [
            Compound(cane: 0, t: 0.18, born: 0.14, side: -1, length: 1.0, tier: 1),
            Compound(cane: 0, t: 0.4, born: 0.22, side: 1, length: 1.1, tier: 1),
            Compound(cane: 0, t: 0.62, born: 0.34, side: -1, length: 1.05, tier: 1),
            Compound(cane: 0, t: 0.82, born: 0.44, side: 1, length: 0.9, tier: 2),
            Compound(cane: 1, t: 0.3, born: 0.38, side: -1, length: 1.0, tier: 0),
            Compound(cane: 1, t: 0.58, born: 0.46, side: 1, length: 1.05, tier: 0),
            Compound(cane: 1, t: 0.84, born: 0.56, side: -1, length: 0.9, tier: 0),
            Compound(cane: 2, t: 0.45, born: 0.58, side: 1, length: 0.85, tier: 2),
            Compound(cane: 2, t: 0.8, born: 0.66, side: -1, length: 0.8, tier: 2),
        ]
        func reach(_ cane: Cane, _ i: Int) -> Double {
            i == 0 ? grown([(0.1, 0), (0.14, 0.12), (0.32, 0.45), (0.55, 0.9), (0.7, 1)]) : Ink.smooth((p - cane.born) / cane.span)
        }
        let paths = canes.enumerated().map { i, k in Self.cubic(k.a, k.c1, k.c2, k.b, upTo: max(0.001, reach(k, i)), n: 16) }

        // The seed leaves, bronze, before the first compound leaf.
        var tiers = [LeafBatch(), LeafBatch(), LeafBatch()]
        var young = LeafBatch()
        let seedLeaf = pop(0.1, over: 0.06) * (1 - Ink.smooth((p - 0.26) / 0.12))
        if seedLeaf > 0.02 {
            for s in [-1.0, 1] {
                let angle = s > 0 ? -0.35 + wilt * 0.8 : -.pi + 0.35 - wilt * 0.8
                if c != nil { young.add(.of(.leaflet, bend: s * 0.2), base: CGPoint(x: 0, y: -2), angle: angle, length: 15 * seedLeaf, light: L, bright: 0.6, glossy: true, shadowed: false) }
                m.note(CGPoint(x: cos(angle) * 14 * seedLeaf, y: -2 + sin(angle) * 14 * seedLeaf))
            }
        }

        // One compound leaf: its stalk and five leaflets, a pair at the lower
        // third of it, another nearer the tip, one at the end.
        for (n, leaf) in leaves.enumerated() {
            let r = reach(canes[leaf.cane], leaf.cane)
            let k = pop(leaf.born, over: 0.1)
            guard k > 0.03, r >= leaf.t - 0.001 else { continue }
            let path = paths[leaf.cane]
            let t = leaf.t / max(0.001, r)
            let at = Self.along(path, t)
            let s = leaf.side * sx
            let heading = (s > 0 ? -0.5 : -.pi + 0.5) + s * wilt * 1.0
            let rachis = 18 * leaf.length * k
            let end = CGPoint(x: at.x + cos(heading) * rachis, y: at.y + sin(heading) * rachis)
            let isYoung = p < leaf.born + 0.16 || n == 3
            let size = plan.leafLength * leaf.length * k * (1 - 0.1 * wilt)
            if c != nil {
                let stalk = Self.ribbon([at, CGPoint(x: (at.x + end.x) / 2, y: (at.y + end.y) / 2 - 1), end], 1.7, 1.2)
                var list: [(CGPoint, Double, Double)] = []
                list.append((end, heading, 1.0))
                for (f, spread) in [(0.42, 1.0), (0.72, 0.9)] {
                    let base = CGPoint(x: at.x + cos(heading) * rachis * f, y: at.y + sin(heading) * rachis * f)
                    for side in [-1.0, 1] { list.append((base, heading + side * spread * 1.0 + side * wilt * 0.2, 0.84 - 0.14 * f)) }
                }
                func put(_ batch: inout LeafBatch) {
                    batch.stalks.addPath(stalk)
                    for (i, item) in list.enumerated() {
                        let b = bright(item.1, luck: luck(n * 5 + i), tier: leaf.tier)
                        let bend = (item.1 > -.pi / 2 ? 1.0 : -1.0) * (0.12 + 0.45 * wilt)
                        // The back tier's shadow is never drawn (`flush(casting: false)`), so it is not built.
                        batch.add(.of(.leaflet, bend: bend), base: item.0, angle: item.1, length: size * item.2, light: L, bright: b, glossy: i == 0,
                                  shadowed: leaf.tier > 0 || isYoung)
                    }
                }
                if isYoung { put(&young) } else { put(&tiers[leaf.tier]) }
                for (i, item) in list.enumerated() {
                    m.note(CGPoint(x: item.0.x + cos(item.1) * size * item.2 * 0.8, y: item.0.y + sin(item.1) * size * item.2 * 0.8), hang: i == 0)
                }
            } else {
                m.note(CGPoint(x: end.x, y: end.y - size * 0.5))
            }
        }

        // Back to front: the arching cane and its leaves, the main cane, the
        // short third, then the blooms.
        var thorns = Path()
        func stem(_ i: Int) {
            guard reach(canes[i], i) > 0.02, let c else { return }
            let w = canes[i].width * (1 - 0.15 * wilt)
            woody(c, Self.ribbon(paths[i], w, w * 0.55), along: paths[i], width: w)
            // Thorns, alternating sides, pointing out and a little down.
            for (k, t) in stride(from: 0.14, through: 0.92, by: 0.11).enumerated() {
                let q = Self.along(paths[i], t), h = Self.heading(paths[i], t)
                let sgn = k.isMultiple(of: 2) ? 1.0 : -1.0
                let nx = -sin(h) * sgn, ny = cos(h) * sgn
                let from = CGPoint(x: q.x + nx * w * 0.4, y: q.y + ny * w * 0.4)
                thorns.spike(from: from, to: CGPoint(x: from.x + nx * 3.4 + cos(h) * -1.2, y: from.y + ny * 3.4 + sin(h) * -1.2), width: 1.7)
            }
        }
        stem(1)
        if let c { tiers[0].flush(c, inks[0], casting: false) }
        stem(0)
        if let c {
            tiers[1].flush(c, inks[1])
            stem(2)
            tiers[2].flush(c, inks[2])
            young.flush(c, fresh)
            c.fill(thorns, with: .color(RGB.night(8, 40, 36, day: day, dim: 0.85).color(0.95)))
        }

        // The blooms, one per cane, at their tips.
        let openAt: [Double] = [0.7, 0.8, 1.4]
        for (i, k) in canes.enumerated().reversed() {
            guard reach(k, i) > 0.9, p > 0.6 else { continue }
            let tip = paths[i][paths[i].count - 1], before = paths[i][paths[i].count - 3]
            let heading = atan2(tip.y - before.y, tip.x - before.x)
            let swell = since(0.6 + 0.05 * Double(i), over: 0.2)
            let raw = Ink.smooth((p - openAt[i]) / 0.2)
            let open = i == 2 ? 0.1 * swell : max(0.05 * swell, raw * (0.3 + 0.7 * M.open))
            let nod = (tip.x >= 0 ? 1.0 : -1.0) * (0.9 * M.thirst + 0.3 * M.doze) * 1.1
            let radius = (i == 0 ? 23.0 : i == 1 ? 19.0 : 14.0) * (0.6 + 0.4 * swell)
            if let c {
                // The cane runs on to the flower: a bud's sepals sit at the bloom's own centre,
                // a fifth of a bloom above the cane's end, and a bud with no stalk to it floated.
                let neck = CGPoint(x: tip.x, y: tip.y - radius * 0.35)
                if TreeAttach.on { c.fill(Self.ribbon([tip, CGPoint(x: (tip.x + neck.x) / 2, y: (tip.y + neck.y) / 2), neck], max(1.4, canes[i].width * 0.45), 1.3), with: .color(inks[1].stalk)) }
                roseBloom(c, at: neck, radius: radius, open: open, turn: (heading + .pi / 2) * 0.5 + nod)
            }
            m.note(CGPoint(x: tip.x, y: tip.y - radius * 0.6), reach: radius * 1.2, hang: false)
        }
        if let c, p > 0.88 { fallenRoses(c) }
        m.note(paths[0][paths[0].count - 1], reach: 3, hang: false)
    }

    /// A cane's wood: red-brown in the shade, green where the sun reaches it.
    private func woody(_ c: GraphicsContext, _ outline: Path, along points: [CGPoint], width: Double) {
        let box = outline.boundingRect
        let side = L.x >= 0 ? 1.0 : -1.0
        let lit = ramp[3].mix(RGB(0xA0574A), 0.35).mix(glow, 0.08 * (1 - night)), base = ramp[2].mix(RGB(0x7A3A32), 0.5), shade = ramp[0].mix(RGB(0x4A2024), 0.4)
        c.fill(outline, with: .linearGradient(Gradient(colors: [lit.color(), base.color(), shade.color()]),
                                              startPoint: CGPoint(x: box.midX + side * box.width * 0.5, y: box.midY),
                                              endPoint: CGPoint(x: box.midX - side * box.width * 0.5, y: box.midY)))
        guard points.count > 2 else { return }
        let edge = points.map { CGPoint(x: $0.x + side * width * 0.2, y: $0.y) }
        c.fill(Self.ribbon(edge, max(0.7, width * 0.18), 0.5), with: .color(rimTone.mix(lit, 0.4).color(0.45)))
    }

    /// A rose petal or two on the soil, more when the house is thirsty.
    private func fallenRoses(_ c: GraphicsContext) {
        guard let flower = plan.flower else { return }
        let tone = bloom(flower.mid, dim: 0.6)
        onSoil(c, x: -seed.side * 17, length: 8.5, width: 3.6, turn: 0.4 * seed.side, tone: tone)
        if M.thirst > 0.3 {
            onSoil(c, x: seed.side * 13, length: 7.5, width: 3.2, turn: -0.6, tone: tone.mix(RGB(0x5A2030), 0.3))
            onSoil(c, x: -seed.side * 5, length: 6.5, width: 2.8, turn: 1.0, tone: tone.mix(RGB(0x5A2030), 0.45))
        }
    }
}
