import SwiftUI

// MARK: - The goblets

extension MagnoliaPainter {
    /// Everything the blossoms of one tier add, one path each, so a tier's
    /// flowers are a dozen fills however many there are.
    private struct Bloom {
        var backs = Path(), mids = Path(), fronts = Path(), tips = Path(), bases = Path(), veins = Path(), edges = Path()
        var fur = Path(), furLit = Path(), scales = Path(), centres = Path()
    }

    /// Buds from the growing stage: silver and downy, a scaled cup at the foot.
    /// They swell, and open as goblets: three layers of petals, the back two
    /// deepest, the front one tallest and palest, each a cupped blade with a
    /// pale translucent tip, a deeper base and a vein up the middle. A magnolia
    /// flowers on bare wood, so the blossoms come before the leaves and a few
    /// stay when they are in.
    func blossoms(_ context: GraphicsContext, _ tier: Int) {
        let gather = self.gather
        let p = core.p, M = core.M, night = core.night, t = core.tones
        guard p > 0.5 else { return }
        var bloom = Bloom()
        for b in canopy.blossoms where canopy.clumps[b.clump].tier == tier {
            guard let q = core.pose.clumps[b.clump] else { continue }
            let first = 0.5 + b.born * 0.14
            let appear = Ink.back((p - first) / 0.06)
            guard appear > 0 else { continue }
            let stays = b.born < 0.45
            let gone = stays ? 1 : 1 - Ink.smooth((p - (0.88 + b.born * 0.06)) / 0.03)
            guard gone > 0.03 else { continue }

            let at = core.site(q, leaf: leafy, gather: gather, b.dx, b.dy)
            let x = at.x, y = at.y
            let side = b.dx < 0 ? -1.0 : 1
            var a = -Double.pi / 2 + b.tilt * 0.7 + side * 0.12
            a += Canopy.wrap(.pi / 2 - a) * M.wilt * 0.4
            let size = b.size * 1.4 * appear * gone * (1 + 0.08 * M.glow)
            let open = Ink.smooth((p - first - 0.1) / 0.12) * Ink.smooth((M.open - 0.1) / 0.45)
            guard size > 0.8 else { continue }
            // A glow behind it at dusk and by the moon, and in a bright mood.
            let glow = (0.12 * M.glow + 0.2 * night) * open
            if glow > 0.03 {
                let gc = t.bglow.mix(RGB(255, 250, 240), 0.35 * core.day), mid = CGPoint(x: x + cos(a) * size * 0.7, y: y + sin(a) * size * 0.7)
                var disc = Path()
                disc.oval(mid.x, mid.y, size * 2, size * 2)
                context.fill(disc, with: .radialGradient(Gradient(colors: [gc.color(glow), gc.color(0)]), center: mid, startRadius: 0, endRadius: size * 2))
            }
            if open < 0.3 {
                bud(&bloom, x, y, size * (0.75 + 0.35 * open), a, side)
            } else {
                goblet(&bloom, x, y, size, a, open, side)
            }
        }
        context.fill(bloom.scales, with: .color(t.barkDark.mix(t.ramp[1], 0.3).color(0.9)))
        context.fill(bloom.fur, with: .color(t.barkHi.mix(t.bb, 0.3).color()))
        context.fill(bloom.furLit, with: .color(t.bb.color(0.55 * (1 - 0.4 * night))))
        context.fill(bloom.backs, with: .color(t.bc.mix(t.ba, 0.35).color()))
        context.fill(bloom.mids, with: .color(t.ba.color(0.97)))
        context.fill(bloom.fronts, with: .color(t.ba.mix(t.bb, 0.4).color(0.94)))
        context.fill(bloom.bases, with: .color(t.bc.color(0.5)))
        context.fill(bloom.tips, with: .color(t.bb.mix(RGB(0xFFFFFF), 0.4).color(0.62)))
        context.fill(bloom.veins, with: .color(t.bc.color(0.38)))
        context.fill(bloom.edges, with: .color(t.bb.mix(RGB(0xFFFFFF), 0.5).color(0.6 * (1 - 0.4 * night))))
        context.fill(bloom.centres, with: .color(RGB.tone(0xF4E4B0, day: core.day, dim: 0.5).color()))
    }

    /// How far the blossoms spread from the limb tips: all of their grown reach
    /// once the crown is in leaf, half of it on bare wood, where a twig holds
    /// each (`hung`).
    var gather: Double { core.gather(leafy) }

    /// The blossoms showing at this growth, each held on its clump's limb.
    func hung(_ s: inout TreeCore.Sprigs) {
        let p = core.p, gather = self.gather
        guard p > 0.5 else { return }
        for b in canopy.blossoms {
            guard let q = core.pose.clumps[b.clump] else { continue }
            let first = 0.5 + b.born * 0.14
            guard Ink.back((p - first) / 0.06) > 0 else { continue }
            let stays = b.born < 0.45
            let gone = stays ? 1 : 1 - Ink.smooth((p - (0.88 + b.born * 0.06)) / 0.03)
            guard gone > 0.03 else { continue }
            core.hang(&s, "blossom", clump: b.clump, at: core.site(q, leaf: leafy, gather: gather, b.dx, b.dy), leaf: leafy)
        }
    }

    /// A bud: a pointed silver cup of down, a lit side, and a few brown scales
    /// at its foot.
    private func bud(_ bloom: inout Bloom, _ x: Double, _ y: Double, _ s: Double, _ a: Double, _ side: Double) {
        let ca = cos(a), sa = sin(a), L = core.L
        bloom.fur.blade(.glossy, x, y, ca, sa, s * 1.25, s * 0.27, 0.06 * side)
        let lit = (-sa * L.x + ca * L.y) >= 0 ? 1.0 : -1
        bloom.furLit.blade(.glossy, x - sa * lit * s * 0.07, y + ca * lit * s * 0.07, ca, sa, s * 0.8, s * 0.11, 0.06 * side)
        for k in -1...1 {
            let aa = a + Double(k) * 0.6
            bloom.scales.lance(x, y, cos(aa), sin(aa), s * 0.55, s * 0.12, 0, 0)
        }
    }

    /// A goblet: seven cupped petals fanned about the flower's axis, as wide as
    /// `open` allows.
    private func goblet(_ bloom: inout Bloom, _ x: Double, _ y: Double, _ s: Double, _ a: Double, _ open: Double, _ side: Double) {
        let L = core.L
        let spread = 0.1 + 0.52 * open
        let lateral = CGPoint(x: -sin(a), y: cos(a))
        // Petals from the back to the front: where each leans, how long and how
        // broad, which fill it goes in.
        let petals: [(Double, Double, Double, Int)] = [
            (-1.0, 1.1, 0.46, 0), (1.0, 1.1, 0.46, 0),
            (-0.55, 1.26, 0.5, 1), (0.55, 1.26, 0.5, 1),
            (-0.8, 1.2, 0.48, 2), (0.8, 1.2, 0.48, 2),
            (0, 1.4, 0.52, 2)]
        for (k, spec) in petals.enumerated() {
            let (lean, len, wid, layer) = spec
            let psi = lean * spread, aa = a + psi, ca = cos(aa), sa = sin(aa)
            let bx = x + lateral.x * lean * s * 0.16, by = y + lateral.y * lean * s * 0.16
            let L1 = s * len, hw = s * wid * 0.5, bend = -psi * 0.3
            switch layer {
            case 0: bloom.backs.blade(.round, bx, by, ca, sa, L1, hw, bend)
            case 1: bloom.mids.blade(.round, bx, by, ca, sa, L1, hw, bend)
            default: bloom.fronts.blade(.round, bx, by, ca, sa, L1, hw, bend)
            }
            if layer > 0 {
                // The pale translucent tip, a deeper base, and the vein.
                bloom.tips.blade(.round, bx + ca * L1 * 0.46, by + sa * L1 * 0.46, ca, sa, L1 * 0.56, hw * 0.78, bend * 0.6)
                bloom.bases.blade(.round, bx, by, ca, sa, L1 * 0.4, hw * 0.55, bend * 0.4)
                bloom.veins.lance(bx + ca * L1 * 0.08, by + sa * L1 * 0.08, ca, sa, L1 * 0.8, hw * 0.1, bend, 0)
                if k == 6 || (lean * (-sa * L.x + ca * L.y) > 0 && layer == 2) {
                    bloom.edges.lanceEdge(bx, by, ca, sa, L1 * 0.96, hw * 0.92, bend, (-sa * L.x + ca * L.y) >= 0 ? 1 : -1)
                }
            }
        }
        // The stamens show in the mouth of a goblet that is wide open.
        if open > 0.75 {
            bloom.centres.oval(x + cos(a) * s * 0.98, y + sin(a) * s * 0.98, s * 0.16, s * 0.09, a + .pi / 2)
        }
        for k in -1...1 {
            let aa = a + Double(k) * 0.9 + .pi
            bloom.scales.lance(x, y, cos(aa), sin(aa), s * 0.3, s * 0.08, 0, 0)
        }
    }
}
