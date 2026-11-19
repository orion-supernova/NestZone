import SwiftUI

// MARK: - The flowers

extension PomegranatePainter.Look {
    private typealias RGB = Canopy.RGB

    /// Everything the flowers of one tier add, one path each, so a tier's
    /// flowers are a dozen fills however many there are.
    private struct Bloom {
        var tubes = Path(), streaks = Path(), teeth = Path()
        var backs = Path(), mids = Path(), fronts = Path(), folds = Path(), lights = Path()
        var filaments = Path(), anthers = Path()
        var buds = Path(), twists = Path()
    }

    /// Buds from the growing stage, red-orange trumpets through budding, and
    /// as the fruit sets most of them drop; a third stay on beside it. A bud
    /// is a waxy calyx with a twisted red tip; a flower is the same calyx
    /// flared open, with a ruffle of crinkled petals standing out of its mouth
    /// and a brush of gold stamens.
    func blossoms(_ context: GraphicsContext, _ tier: Int) {
        guard p > 0.55 else { return }
        var bloom = Bloom()
        for b in canopy.blossoms where canopy.clumps[b.clump].tier == tier {
            guard let q = pose.clumps[b.clump] else { continue }
            let first = 0.56 + b.born * 0.12
            let appear = Ink.back((p - first) / 0.04)
            guard appear > 0 else { continue }
            let stays = b.born < 0.32
            let gone = stays ? 1 : 1 - Ink.smooth((p - (0.86 + b.born * 0.06)) / 0.03)
            guard gone > 0.03 else { continue }

            let x = q.x + b.dx * q.R, y = q.y + b.dy * q.R
            let side = b.dx < 0 ? -1.0 : 1
            var a = -Double.pi / 2 + b.tilt + side * 0.35
            a += Canopy.wrap(.pi / 2 - a) * M.wilt * 0.5
            let size = b.size * appear * gone * (1 + 0.1 * M.glow)
            let open = Ink.smooth((p - first - 0.05) / 0.06) * Ink.smooth((M.open - 0.12) / 0.5)
            if open > 0.5 {
                flower(context, &bloom, x, y, size * (0.7 + 0.3 * open), a, b.rot)
            } else {
                bud(&bloom, x, y, size * (0.55 + 0.4 * Ink.smooth((p - first) / 0.08)), a, side)
            }
        }
        let t = tones
        let hair = 0.5
        context.fill(bloom.tubes, with: .color(t.ba.mix(t.bc, 0.3).color()))
        context.stroke(bloom.streaks, with: .color(t.bb.mix(RGB(0xFFFFFF), 0.5).color(0.55 * (1 - 0.4 * night))), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        context.fill(bloom.backs, with: .color(t.ba.mix(t.bc, 0.5).color()))
        context.fill(bloom.mids, with: .color(t.ba.color()))
        context.fill(bloom.fronts, with: .color(t.ba.mix(t.bb, 0.4).color()))
        context.stroke(bloom.folds, with: .color(t.bc.color(0.5)), style: StrokeStyle(lineWidth: hair, lineCap: .round))
        context.stroke(bloom.lights, with: .color(t.bb.mix(RGB(0xFFFFFF), 0.35).color(0.65 * (1 - 0.4 * night))), style: StrokeStyle(lineWidth: hair * 1.4, lineCap: .round))
        context.fill(bloom.teeth, with: .color(t.ba.mix(t.bc, 0.7).color()))
        context.stroke(bloom.filaments, with: .color(t.anther.mix(t.ba, 0.3).color(0.85)), style: StrokeStyle(lineWidth: hair, lineCap: .round))
        context.fill(bloom.anthers, with: .color(t.anther.color()))
        let red = t.ba.mix(t.bc, 0.25).mix(t.ramp[3], 0.4 * M.thirst + 0.25 * M.doze)
        context.fill(bloom.buds, with: .color(red.color()))
        context.stroke(bloom.twists, with: .color(t.bb.color(0.7)), style: StrokeStyle(lineWidth: hair, lineCap: .round))
    }

    private func spot(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double) -> (Double, Double) -> CGPoint {
        { u, v in CGPoint(x: x + ca * u - sa * v, y: y + sa * u + ca * v) }
    }

    /// The calyx: a waxy trumpet with a streak of light down the lit side and
    /// sepal teeth round its rim.
    private func calyx(_ bloom: inout Bloom, _ P: (Double, Double) -> CGPoint, _ s: Double, flare: Double, length: Double, lit: Double) {
        bloom.tubes.move(to: P(0, -s * 0.16))
        bloom.tubes.addCurve(to: P(s * length, -s * flare), control1: P(s * 0.3, -s * 0.2), control2: P(s * length * 0.62, -s * flare * 0.85))
        bloom.tubes.addLine(to: P(s * length, s * flare))
        bloom.tubes.addCurve(to: P(0, s * 0.16), control1: P(s * length * 0.62, s * flare * 0.85), control2: P(s * 0.3, s * 0.2))
        bloom.tubes.closeSubpath()
        bloom.streaks.move(to: P(s * 0.16, -lit * s * 0.12))
        bloom.streaks.addQuadCurve(to: P(s * length * 0.78, -lit * s * flare * 0.55), control: P(s * length * 0.5, -lit * s * flare * 0.3))
        for v in [-0.9, 0, 0.9] {
            let tip = P(s * length * 1.14, s * flare * v * 1.12), w = s * 0.12
            bloom.teeth.move(to: P(s * length * 0.9, s * flare * v - w))
            bloom.teeth.addLine(to: tip)
            bloom.teeth.addLine(to: P(s * length * 0.9, s * flare * v + w))
            bloom.teeth.closeSubpath()
        }
    }

    private func bud(_ bloom: inout Bloom, _ x: Double, _ y: Double, _ s: Double, _ a: Double, _ side: Double) {
        let ca = cos(a), sa = sin(a), P = spot(x, y, ca, sa)
        guard s > 0.4 else { return }
        calyx(&bloom, P, s, flare: 0.3, length: 0.62, lit: (-sa * L.x + ca * L.y) >= 0 ? 1 : -1)
        // The twisted tip: a pointed red spire coming out of the calyx.
        let o = P(s * 0.58, 0)
        bloom.buds.lance(o.x, o.y, ca, sa, s * 0.72, s * 0.19, 0.12 * side, 0)
        bloom.twists.move(to: P(s * 0.66, -s * 0.06))
        bloom.twists.addQuadCurve(to: P(s * 1.14, s * 0.04), control: P(s * 0.9, s * 0.12))
    }

    private func flower(_ context: GraphicsContext, _ bloom: inout Bloom, _ x: Double, _ y: Double, _ s: Double, _ a: Double, _ rot: Double) {
        let ca = cos(a), sa = sin(a), P = spot(x, y, ca, sa), t = tones
        guard s > 0.5 else { return }
        let litSide = (-sa * L.x + ca * L.y) >= 0 ? 1.0 : -1
        // A glow behind it, at dusk and by the moon, and in a bright mood.
        let glow = (0.14 * M.glow + 0.2 * night) * M.open
        if glow > 0.03 {
            let gc = t.bglow.mix(RGB(255, 250, 240), 0.35 * day), centre = P(s * 0.9, 0)
            var disc = Path()
            disc.oval(centre.x, centre.y, s * 2, s * 2)
            context.fill(disc, with: .radialGradient(Gradient(colors: [gc.color(glow), gc.color(0)]), center: centre, startRadius: 0, endRadius: s * 2))
        }

        calyx(&bloom, P, s, flare: 0.36, length: 0.86, lit: litSide)

        // Petals: crinkled, standing out of the mouth in a fan. The two at the
        // back are deepest, the front one brightest.
        let mouth = P(s * 0.84, 0)
        for (n, off) in [-1.05, 1.05, -0.5, 0.5, 0.0].enumerated() {
            let ra = a + off * 0.95, len = s * (n < 2 ? 0.8 : n < 4 ? 0.92 : 0.95), wid = s * (n < 2 ? 0.34 : 0.4)
            let cx = mouth.x + cos(ra) * len * 0.5, cy = mouth.y + sin(ra) * len * 0.5
            let ph = rot + Double(n) * 1.9
            if n < 2 { bloom.backs.frill(cx, cy, len * 0.52, wid, ra, ph) } else if n < 4 { bloom.mids.frill(cx, cy, len * 0.52, wid, ra, ph) } else { bloom.fronts.frill(cx, cy, len * 0.55, wid * 1.05, ra, ph) }
            // The crinkles: a fold or two from the base towards the tip.
            let nx = -sin(ra), ny = cos(ra)
            for v in (n < 2 ? [0.0] : [-0.4, 0.4]) {
                bloom.folds.move(to: CGPoint(x: mouth.x + nx * v * wid * 0.3, y: mouth.y + ny * v * wid * 0.3))
                bloom.folds.addQuadCurve(to: CGPoint(x: mouth.x + cos(ra) * len * 0.82 + nx * v * wid * 0.9, y: mouth.y + sin(ra) * len * 0.82 + ny * v * wid * 0.9),
                                         control: CGPoint(x: mouth.x + cos(ra) * len * 0.45 + nx * v * wid * 0.7, y: mouth.y + sin(ra) * len * 0.45 + ny * v * wid * 0.7))
            }
            // Light along the lit edge of the front petals.
            if n == 4 || n == (litSide > 0 ? 3 : 2) {
                bloom.lights.move(to: CGPoint(x: mouth.x + cos(ra) * len * 0.7 - sin(ra) * litSide * wid * 0.7, y: mouth.y + sin(ra) * len * 0.7 + cos(ra) * litSide * wid * 0.7))
                bloom.lights.addQuadCurve(to: CGPoint(x: mouth.x + cos(ra) * len * 1.0, y: mouth.y + sin(ra) * len * 1.0),
                                          control: CGPoint(x: mouth.x + cos(ra) * len * 0.92 - sin(ra) * litSide * wid * 0.5, y: mouth.y + sin(ra) * len * 0.92 + cos(ra) * litSide * wid * 0.5))
            }
        }

        // A brush of gold stamens in the throat.
        for v in -3...3 {
            let ra = a + Double(v) * 0.17, ln = s * (0.42 + 0.08 * Double(abs(v) % 2))
            let o = P(s * 0.9, Double(v) * s * 0.04)
            let e = CGPoint(x: o.x + cos(ra) * ln, y: o.y + sin(ra) * ln)
            bloom.filaments.move(to: o)
            bloom.filaments.addQuadCurve(to: e, control: CGPoint(x: o.x + cos(ra - 0.3) * ln * 0.6, y: o.y + sin(ra - 0.3) * ln * 0.6))
            bloom.anthers.oval(e.x, e.y, s * 0.055, s * 0.045)
        }
    }
}
