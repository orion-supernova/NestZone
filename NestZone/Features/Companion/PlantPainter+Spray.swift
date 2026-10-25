import SwiftUI

// The spray: broad, thick leaves in a fan at the foot, silvery aerial roots
// that leave the crown and hang over the pot's rim, and one flower spike that
// rises between the leaves and arches over, carrying a row of blooms that open
// from the bottom up and end in a string of buds. A moth orchid is this rule.
//
// The blooms are drawn as layers merged across the whole spike (sepals, then
// petals, then the lip, then the column), so seven of them cost a dozen fills.
//
// Growth: the seed (a chip of bark with a root), leaves one by one (.1, .18,
// .28, .38, .46), roots (.3 to .5), the spike's nub (.52), the spike arching
// (.55 to .8), buds, blooms opening from the foot of the spike (.76 on). A
// thirsty one goes limp (leaves fold, roots shrivel, blooms close and nod); a
// dozing one has its blooms half shut.
extension PlantPainter {
    private struct Leaf {
        var angle, length, born, bend: Double
        var tier: Int
    }

    func spray(_ c: GraphicsContext?, _ m: inout Marks) {
        guard let flower = plan.flower else { return }
        let sx = seed.side, wilt = self.wilt
        let leaves = [
            Leaf(angle: -.pi + 0.5, length: 1.0, born: 0.1, bend: -0.5, tier: 1),
            Leaf(angle: -0.5, length: 0.94, born: 0.18, bend: 0.5, tier: 1),
            Leaf(angle: -.pi + 0.95, length: 0.84, born: 0.28, bend: -0.4, tier: 2),
            Leaf(angle: -0.95, length: 0.8, born: 0.38, bend: 0.4, tier: 2),
            Leaf(angle: -.pi / 2 - 0.1, length: 0.55, born: 0.46, bend: -0.2, tier: 0),
        ]
        var batches = [LeafBatch(), LeafBatch(), LeafBatch()]
        for (i, leaf) in leaves.enumerated() {
            let k = pop(leaf.born, over: 0.12)
            guard k > 0.02 else { continue }
            let s = (cos(leaf.angle) >= 0 ? 1.0 : -1.0) * sx
            let angle = sx > 0 ? leaf.angle : -.pi - leaf.angle
            let dir = cos(angle) >= 0 ? 1.0 : -1.0
            let len = plan.leafLength * leaf.length * k * (1 - 0.14 * wilt) * seed.between(i, 0.94, 1.06)
            let hung = angle + dir * wilt * 0.9
            let base = CGPoint(x: dir * 3, y: -2)
            if c != nil {
                batches[leaf.tier].add(.of(plan.leaf, bend: dir * (abs(leaf.bend) + 0.5 * wilt)), base: base, angle: hung, length: len, light: L,
                                       bright: bright(hung, luck: luck(i + 4), tier: leaf.tier), glossy: true)
            }
            _ = s
            m.note(CGPoint(x: base.x + cos(hung) * len * 0.8, y: base.y + sin(hung) * len * 0.8))
        }

        // Aerial roots: silver cords from the crown, out over the rim, each with
        // a green growing tip.
        var cords = Path(), tips = Path(), shine = Path()
        let roots: [(born: Double, dx: Double, reach: Double, drop: Double)] = [(0.3, -34, 50, 30), (0.38, 26, 58, 40), (0.46, -10, 40, 22), (0.5, 40, 36, 14)]
        for (i, r) in roots.enumerated() {
            let grow = Ink.smooth((p - r.born) / 0.22) * (1 - 0.3 * wilt)
            guard grow > 0.03 else { continue }
            let dx = r.dx * sx
            let a = CGPoint(x: dx * 0.1, y: -4)
            let end = CGPoint(x: dx + (dx > 0 ? 1 : -1) * r.reach * 0.3, y: r.drop)
            let c1 = CGPoint(x: dx * 0.9, y: -14 - 5 * Double(i)), c2 = CGPoint(x: end.x + dx * 0.15, y: end.y - 16)
            let line = Self.cubic(a, c1, c2, end, upTo: grow, n: 10)
            cords.addPath(Self.ribbon(line, 3.4 * (1 - 0.3 * wilt), 2))
            shine.addPath(Self.ribbon(line.map { CGPoint(x: $0.x + (L.x >= 0 ? -0.6 : 0.6), y: $0.y - 0.3) }, 1.2, 0.6))
            if let tip = line.last, grow > 0.4 { tips.addEllipse(in: CGRect(x: tip.x - 1.6, y: tip.y - 1.2, width: 3.2, height: 3.4)) }
        }

        // The spike: up out of the crown and over.
        let reach = grown([(0.52, 0), (0.56, 0.12), (0.72, 0.62), (0.88, 1)])
        let tipX = (64 - 10 * wilt) * sx, tipY = -118 + 34 * wilt
        let a = CGPoint(x: 3 * sx, y: -6)
        let spine = Self.cubic(a, CGPoint(x: 4 * sx, y: -84), CGPoint(x: 26 * sx, y: -(plan.height - 8) + 26 * wilt), CGPoint(x: tipX, y: tipY), upTo: max(0.001, reach), n: 20)

        if let c {
            // Back to front: the back leaves, the roots, the spike, the near leaves.
            batches[0].flush(c, inks[0], casting: false)
            c.fill(cords, with: .color(RGB.night(112, 14, 62, day: day, dim: 0.9).mix(ramp[1], 0.2 + 0.4 * M.thirst).color()))
            c.fill(shine, with: .color(RGB.night(110, 16, 80, day: day, dim: 0.9).color(0.6)))
            c.fill(tips, with: .color(ramp[4].mix(RGB(0xB8E070), 0.5).color(0.95)))
            batches[1].flush(c, inks[1])
            if reach > 0.02 {
                let w = 3.4 * (1 - 0.15 * wilt)
                paint(c, stem: Self.ribbon(spine, w, w * 0.5), along: spine, width: w, tier: 1, tint: 0x6C3A5C)
            }
            batches[2].flush(c, inks[2])
        }

        // The blooms and buds along the spike.
        let stations: [Double] = [0.36, 0.5, 0.63, 0.75, 0.86, 0.94, 1.0]
        let sizes: [Double] = [19, 18, 17, 15, 11, 8, 5.5]
        var field = BloomField()
        for (i, t) in stations.enumerated() where reach >= t - 0.01 {
            let at = Self.along(spine, t / max(0.01, reach)), head = Self.heading(spine, t / max(0.01, reach))
            let swell = since(0.7 + 0.015 * Double(i), over: 0.12)
            guard swell > 0.03 else { continue }
            let raw = Ink.smooth((p - (0.76 + 0.038 * Double(i))) / 0.1)
            let open = raw * (0.3 + 0.7 * M.open) * (1 - 0.3 * M.doze)
            // Each bloom hangs off the spike on a short pedicel, on alternate
            // sides, and faces out and a little down.
            let out = (i.isMultiple(of: 2) ? 1.0 : -1.0)
            let normal = head + out * .pi / 2
            let pedicel = (5 + 3 * Double(i < 5 ? 1 : 0)) * swell
            let bloomAt = CGPoint(x: at.x + cos(normal) * pedicel, y: at.y + sin(normal) * pedicel + 4)
            if c != nil { field.stem(from: at, to: bloomAt) }
            let radius = sizes[i] * (0.55 + 0.45 * swell) * (1 + 0.1 * Double(1 - i / 4))
            if c != nil { orchidBloom(&field, at: bloomAt, radius: radius, open: open, tilt: out * (0.12 + 0.5 * M.thirst) + wilt * out * 0.2) }
            m.note(CGPoint(x: bloomAt.x, y: bloomAt.y - radius * 0.3), reach: radius, hang: i < 5)
        }
        if let c { field.flush(c, ramp: ramp, flower: flower, painter: self) }
        if let c, p > 0.9 { fallenOrchid(c, flower: flower) }
        m.note(spine[spine.count - 1], reach: 4, hang: false)
    }

    /// A bloom or two that has dropped on the soil, more when the house is thirsty.
    private func fallenOrchid(_ c: GraphicsContext, flower: PlantPlan.Flower) {
        let tone = bloom(flower.mid, dim: 0.6)
        onSoil(c, x: -seed.side * 20, length: 9, width: 4.6, turn: 0.5 * seed.side, tone: tone.mix(bloom(flower.tint), 0.3), tip: bloom(flower.pale))
        if M.thirst > 0.3 {
            onSoil(c, x: seed.side * 16, length: 8, width: 4, turn: -0.7, tone: tone.mix(RGB(0x9A7A5A), 0.3))
        }
    }
}
