import SwiftUI

// The tuft: a rosette of leaves at the foot and flower stems that rise out of
// it, each with a bloom of its own that opens in its own time. Daisy, tulip and
// peony are this rule: the plan's `stems` say where each stands, how tall it
// grows and when its bloom opens, the flower says what the bloom is
// (`PlantPainter+Blooms.swift`), and the leaf says what the rosette is made of.
//
// Lavender and snowdrop are tufts too: five thin stems that end in a spike of
// florets (`lavenderSpike`) and three that hook over so a bell hangs from each
// (`snowdropBloom`); a stem's `arch` says which.
//
// Growth: the seed (to .1), the rosette's leaves one after another (.1 on), the
// stems rising out of it (each from its `born`), buds swelling at their tips,
// and the blooms opening one by one (`opens`), the tallest first; the last stem
// stays a bud. A thirsty one lets its leaves and stems lean out and its heads
// nod, with a petal on the soil; a dozing one shuts its blooms half way.
extension PlantPainter {
    func tuft(_ c: GraphicsContext?, _ m: inout Marks) {
        guard let flower = plan.flower else { return }
        let side = seed.side, wilt = self.wilt
        var tiers = [LeafBatch(), LeafBatch(), LeafBatch()]
        let strap = plan.leaf == .strap

        // The rosette.
        for i in 0..<plan.basal {
            let born = 0.1 + (strap ? 0.05 : 0.032) * Double(i)
            let k = pop(born, over: 0.09) * (0.55 + 0.45 * Ink.smooth((p - born) / 0.4))
            guard k > 0.03 else { continue }
            let n = Double(plan.basal)
            let a: Double
            if strap { a = -.pi / 2 + (Double(i) - (n - 1) / 2) * 0.42 * side + seed.between(i, -0.08, 0.08) }
            else { a = -.pi + 0.16 + (Double(i) + 0.5) / n * (.pi - 0.32) + seed.between(i, -0.1, 0.1) }
            let dir = cos(a) > 0.02 ? 1.0 : cos(a) < -0.02 ? -1.0 : (i.isMultiple(of: 2) ? 1.0 : -1.0)
            let angle = a + dir * wilt * (strap ? 0.5 : 0.8)
            let len = plan.basalLength * k * seed.between(i + 6, 0.88, 1.1) * (1 - 0.12 * wilt)
            let tier = i % 3
            let base = CGPoint(x: cos(a) * 2.5, y: 1)
            if c != nil {
                let bend = dir * (strap ? 0.5 + 0.6 * wilt : 0.28 + 0.6 * wilt)
                if plan.leaf == .needle {
                    // A grass-thin leaf has no veins or glint to draw.
                    tiers[tier].addLite(.of(plan.leaf, bend: bend), base: base, angle: angle, length: len, light: L, bright: bright(angle, luck: luck(i + 9), tier: tier), lightHalf: tier > 0)
                } else {
                    tiers[tier].add(.of(plan.leaf, bend: bend), base: base, angle: angle, length: len, light: L,
                                    bright: bright(angle, luck: luck(i + 9), tier: tier), glossy: true)
                }
            }
            m.note(CGPoint(x: base.x + cos(angle) * len * 0.85, y: base.y + sin(angle) * len * 0.85))
        }

        // Each flower stem: where its spine runs, and its bloom.
        struct Rise {
            var spine: [CGPoint]
            var width: Double
            var stem: PlantPlan.Stem
            var index: Int
            var rise: Double
        }
        var rises: [Rise] = []
        let thick = flower.bloom == .peony ? 4.4 : flower.bloom == .tulip ? 3.6 : flower.bloom == .lavender ? 2.3 : flower.bloom == .snowdrop ? 2.1 : 2.8
        for (j, st) in plan.stems.enumerated() {
            let rise = st.height * Ink.smooth((p - st.born) / 0.36) * (1 - 0.06 * M.thirst)
            guard rise > 6 else { continue }
            let x0 = st.x * side
            let dir = x0 >= 0 ? 1.0 : -1.0
            let tip = CGPoint(x: x0 * 1.3 + seed.lean * 3 + dir * wilt * 0.36 * rise, y: -rise * (1 - 0.3 * wilt))
            let control = CGPoint(x: x0 * 1.15, y: -rise * 0.72)
            // A stem that hooks over (a snowdrop's) goes up, peaks and curls down
            // so that its bloom hangs; the others are one quadratic.
            let spine: [CGPoint]
            if st.arch > 0 {
                let hook = CGPoint(x: tip.x + dir * 13 * Ink.smooth((rise / st.height - 0.5) * 2), y: tip.y + (13 + 8 * wilt) * Ink.smooth((rise / st.height - 0.5) * 2))
                spine = Self.cubic(CGPoint(x: x0 * 0.4, y: 1), CGPoint(x: x0 * 1.1, y: -rise * 0.7), CGPoint(x: tip.x + dir * 4, y: tip.y - 7), hook, n: 16)
            } else {
                spine = Self.quad(CGPoint(x: x0 * 0.4, y: 1), control, tip, n: 14)
            }
            rises.append(Rise(spine: spine, width: thick * (0.8 + 0.2 * st.size) * (1 - 0.15 * wilt), stem: st, index: j, rise: rise))
        }

        if let c { tiers[0].flush(c, inks[0], casting: false) }
        // Leaves up the stems (a peony's), behind the blooms and in front of the stems.
        for rise in rises {
            if let c { paint(c, stem: Self.ribbon(rise.spine, rise.width, rise.width * 0.7), along: rise.spine, width: rise.width, tier: 1) }
            guard plan.stemLeaves > 0 else { continue }
            for k in 0..<plan.stemLeaves {
                let born = rise.stem.born + 0.12 + 0.08 * Double(k)
                let lk = pop(born, over: 0.1)
                guard lk > 0.03 else { continue }
                let t = 0.34 + 0.27 * Double(k)
                let at = Self.along(rise.spine, t)
                let dir = (k + rise.index).isMultiple(of: 2) ? 1.0 : -1.0
                let angle = (dir > 0 ? -0.6 : -.pi + 0.6) + dir * wilt * 0.9
                let len = plan.leafLength * 0.74 * lk * seed.between(rise.index * 3 + k, 0.9, 1.08)
                if c != nil {
                    tiers[1].add(.of(plan.leaf, bend: dir * (0.3 + 0.5 * wilt)), base: at, angle: angle, length: len, light: L,
                                 bright: bright(angle, luck: luck(rise.index * 4 + k + 2), tier: 1), glossy: true)
                }
                m.note(CGPoint(x: at.x + cos(angle) * len * 0.85, y: at.y + sin(angle) * len * 0.85))
            }
        }
        if let c {
            tiers[1].flush(c, inks[1])
            tiers[2].flush(c, inks[2])
        }

        // The blooms, the lowest first so the higher ones sit on top.
        for rise in rises.sorted(by: { $0.spine[$0.spine.count - 1].y > $1.spine[$1.spine.count - 1].y }) {
            let st = rise.stem
            let tip = rise.spine[rise.spine.count - 1], before = rise.spine[rise.spine.count - 3]
            let heading = atan2(tip.y - before.y, tip.x - before.x)
            let grow = Ink.smooth(rise.rise / max(1, st.height * 0.8))
            let budK = since(st.born + 0.12, over: 0.2)
            guard budK > 0.03 else { continue }
            // Opening: bud until near its day, then each ring in turn; a thirsty
            // or dozing house keeps it shut part way.
            let raw = Ink.smooth((p - (st.opens - 0.08)) / 0.16)
            let open = raw * (0.35 + 0.65 * M.open)
            let nod = (tip.x >= 0 ? 1.0 : -1.0) * (0.9 * M.thirst + 0.35 * M.doze) * 1.2
            let size = st.size * (0.5 + 0.5 * grow) * Ink.lerp(0.55, 1, budK)
            let turn = (heading + .pi / 2) * 0.7 + nod
            var radius = 0.0
            if let c {
                switch flower.bloom {
                case .daisy:
                    radius = 19 * size
                    daisyBloom(c, at: tip, radius: radius, open: open, turn: (heading + .pi / 2) * 0.5 + nod * 0.5, squash: 0.9 - 0.3 * M.thirst)
                case .lavender:
                    radius = 30 * size
                    lavenderSpike(c, from: CGPoint(x: tip.x, y: tip.y + 2), heading: heading, length: 46 * size * (0.4 + 0.6 * budK), open: open, nod: nod * 0.5)
                case .snowdrop:
                    radius = 12 * size
                    snowdropBloom(c, at: tip, size: size * 1.3, open: open, turn: heading + .pi / 2 + nod * 0.3)
                case .tulip:
                    radius = 15 * size
                    tulipBloom(c, at: CGPoint(x: tip.x, y: tip.y + 1), size: size * 1.55, open: open, turn: turn)
                default:
                    radius = 31 * size
                    peonyBloom(c, at: CGPoint(x: tip.x, y: tip.y - radius * 0.2), radius: radius, open: open, turn: turn * 0.6)
                }
            } else {
                radius = flower.bloom == .peony ? 31 * size : flower.bloom == .daisy ? 19 * size : flower.bloom == .lavender ? 30 * size : 15 * size
            }
            m.note(CGPoint(x: tip.x, y: tip.y - radius * 0.5), reach: radius * (flower.bloom == .tulip ? 0.8 : 1.4), hang: false)
        }
        if let c { fallenPetals(c, flower: flower) }
    }

    /// A petal on the soil once the first bloom has opened, and when the house is
    /// thirsty a couple more.
    private func fallenPetals(_ c: GraphicsContext, flower: PlantPlan.Flower) {
        guard p > 0.82 else { return }
        let tone = bloom(flower.mid, dim: 0.6)
        let size: Double = flower.bloom == .peony ? 14 : flower.bloom == .tulip ? 14 : flower.bloom == .lavender ? 4 : flower.bloom == .snowdrop ? 8 : 9
        onSoil(c, x: -seed.side * 19, length: size, width: size * 0.36, turn: 0.4 * seed.side, tone: tone)
        if M.thirst > 0.3 {
            onSoil(c, x: seed.side * 14, length: size * 0.85, width: size * 0.3, turn: -0.6, tone: tone.mix(RGB(0x9A7A5A), 0.3))
        }
    }
}
