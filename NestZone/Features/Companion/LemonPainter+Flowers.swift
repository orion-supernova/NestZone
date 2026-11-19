import SwiftUI

// MARK: - The blossoms

extension LemonPainter {
    /// Everything the blossoms of one tier add, one path each, so a tier's
    /// flowers are a handful of fills however many there are.
    private struct Bloom {
        var backs = Path(), petals = Path(), veins = Path(), centres = Path(), anthers = Path()
        var buds = Path(), tips = Path(), cups = Path()
    }

    /// Buds from the growing stage: pointed, a blush of purple on a white
    /// tip. Then white star blossoms, five petals with the purple of their
    /// backs showing at the edge and a mark of it down the middle, a gold
    /// heart of stamens. A lemon flowers while it fruits, so about half the
    /// flowers stay beside the fruit.
    func blossoms(_ context: GraphicsContext, _ tier: Int) {
        let p = core.p, M = core.M, night = core.night, day = core.day
        guard p > 0.55 else { return }
        var bloom = Bloom()
        for b in canopy.blossoms where canopy.clumps[b.clump].tier == tier {
            guard let q = core.pose.clumps[b.clump] else { continue }
            let first = 0.56 + b.born * 0.12
            let appear = Ink.back((p - first) / 0.04)
            guard appear > 0 else { continue }
            let stays = b.born < 0.5
            let gone = stays ? 1 : 1 - Ink.smooth((p - (0.86 + b.born * 0.06)) / 0.03)
            guard gone > 0.03 else { continue }

            let x = q.x + b.dx * q.R, y = q.y + b.dy * q.R
            let side = b.dx < 0 ? -1.0 : 1
            var a = -Double.pi / 2 + b.tilt + side * 0.35
            a += Canopy.wrap(.pi / 2 - a) * M.wilt * 0.5
            let size = b.size * 1.35 * appear * gone * (1 + 0.1 * M.glow)
            let open = Ink.smooth((p - first - 0.05) / 0.06) * Ink.smooth((M.open - 0.12) / 0.5)
            if open > 0.5 {
                flower(context, &bloom, x, y, size * (0.7 + 0.3 * open), b.rot)
            } else {
                bud(&bloom, x, y, size * (0.6 + 0.4 * Ink.smooth((p - first) / 0.08)), a)
            }
        }
        let t = core.tones, lilac = RGB.tone(0xC9A6D4, day: day, dim: 0.55), mark = RGB.tone(0xA8559A, day: day, dim: 0.55)
        context.fill(bloom.backs, with: .color(lilac.color(0.8)))
        context.fill(bloom.petals, with: .color(t.bb.mix(t.ba, 0.25).color()))
        context.fill(bloom.veins, with: .color(mark.color(0.45)))
        context.fill(bloom.centres, with: .color(t.bc.color()))
        context.fill(bloom.anthers, with: .color(t.anther.color()))
        let bud = lilac.mix(mark, 0.35).mix(t.ramp[3], 0.4 * M.thirst + 0.25 * M.doze)
        context.fill(bloom.buds, with: .color(bud.color()))
        context.fill(bloom.tips, with: .color(t.bb.color(0.9 * (1 - 0.3 * night))))
        context.fill(bloom.cups, with: .color(t.ramp[2].color()))
    }

    private func bud(_ bloom: inout Bloom, _ x: Double, _ y: Double, _ s: Double, _ a: Double) {
        guard s > 0.4 else { return }
        let ca = cos(a), sa = sin(a)
        bloom.buds.lance(x, y, ca, sa, s * 1.15, s * 0.3, 0.1, 0)
        bloom.tips.lance(x + ca * s * 0.7, y + sa * s * 0.7, ca, sa, s * 0.45, s * 0.1, 0, 0)
        bloom.cups.oval(x, y, s * 0.22, s * 0.17, a)
    }

    private func flower(_ context: GraphicsContext, _ bloom: inout Bloom, _ x: Double, _ y: Double, _ s: Double, _ rot: Double) {
        guard s > 0.5 else { return }
        let M = core.M, night = core.night, t = core.tones
        // A glow behind it at dusk and by the moon, and in a bright mood.
        let glow = (0.14 * M.glow + 0.2 * night) * M.open
        if glow > 0.03 {
            let gc = t.bglow.mix(RGB(255, 250, 240), 0.35 * core.day)
            var disc = Path()
            disc.oval(x, y, s * 2, s * 2)
            context.fill(disc, with: .radialGradient(Gradient(colors: [gc.color(glow), gc.color(0)]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: s * 2))
        }
        // Five petals, each a long oval, the purple of their backs a hair
        // wider behind them.
        for i in 0..<5 {
            let a = rot + Double(i) * 2 * .pi / 5, ca = cos(a), sa = sin(a)
            bloom.backs.oval(x + ca * s * 0.5, y + sa * s * 0.5, s * 0.535, s * 0.225, a)
            bloom.petals.oval(x + ca * s * 0.5, y + sa * s * 0.5, s * 0.5, s * 0.2, a)
            bloom.veins.move(to: CGPoint(x: x + ca * s * 0.22, y: y + sa * s * 0.22))
            bloom.veins.addQuadCurve(to: CGPoint(x: x + ca * s * 0.84, y: y + sa * s * 0.84),
                                     control: CGPoint(x: x + ca * s * 0.55 - sa * s * 0.035, y: y + sa * s * 0.55 + ca * s * 0.035))
            bloom.veins.addQuadCurve(to: CGPoint(x: x + ca * s * 0.22, y: y + sa * s * 0.22),
                                     control: CGPoint(x: x + ca * s * 0.55 + sa * s * 0.01, y: y + sa * s * 0.55 - ca * s * 0.01))
            bloom.veins.closeSubpath()
        }
        // A heart of stamens: a ring of anthers round a green-gold middle.
        bloom.centres.oval(x, y, s * 0.17, s * 0.17)
        for i in 0..<9 {
            let a = rot * 1.3 + Double(i) * 2 * .pi / 9
            bloom.anthers.oval(x + cos(a) * s * 0.27, y + sin(a) * s * 0.27, s * 0.05, s * 0.045)
        }
    }
}
