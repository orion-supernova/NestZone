import SwiftUI

// MARK: - The flowers

extension OlivePainter {
    /// An olive's flowers are tiny and cream, held in loose sprays on a thin
    /// stem: a handful of dots up a twig, each on its own short stalk. Closed,
    /// they are the same sprays in green-white buds. One spray costs a few
    /// ovals and a lens, and every spray of a tier shares two fills.
    func blossoms(_ context: GraphicsContext, _ tier: Int) {
        let p = core.p, M = core.M, night = core.night, t = core.tones
        guard p > 0.55 else { return }
        var stems = Path(), dots = Path(), buds = Path()
        for b in canopy.blossoms where canopy.clumps[b.clump].tier == tier {
            guard let q = core.pose.clumps[b.clump] else { continue }
            let first = 0.56 + b.born * 0.12
            let appear = Ink.back((p - first) / 0.04)
            guard appear > 0 else { continue }
            let stays = b.born < 0.4
            let gone = stays ? 1 : 1 - Ink.smooth((p - (0.86 + b.born * 0.06)) / 0.03)
            guard gone > 0.03 else { continue }
            let s = b.size * 1.4 * appear * gone * (1 + 0.1 * M.glow)
            guard s > 0.8 else { continue }
            let open = Ink.smooth((p - first - 0.05) / 0.06) * Ink.smooth((M.open - 0.12) / 0.5)
            let x = q.x + b.dx * q.R, y = q.y + b.dy * q.R
            let side = b.dx < 0 ? -1.0 : 1
            // A soft glow behind the sprays by the moon and in a bright mood.
            let glow = (0.12 * M.glow + 0.16 * night) * M.open
            if glow > 0.03 && open > 0.5 {
                let gc = t.bglow.mix(RGB(255, 250, 240), 0.35 * core.day)
                var disc = Path()
                disc.oval(x, y - s, s * 2.2, s * 2.2)
                context.fill(disc, with: .radialGradient(Gradient(colors: [gc.color(glow), gc.color(0)]), center: CGPoint(x: x, y: y - s), startRadius: 0, endRadius: s * 2.2))
            }
            // Two sprays from the same twig, leaning apart.
            for k in 0..<2 {
                let a = -Double.pi / 2 + b.tilt * 0.8 + side * 0.6 + (k == 0 ? -0.5 : 0.6) + M.wilt * 0.5 * side
                let big = s * (k == 0 ? 1 : 0.82)
                if open > 0.5 {
                    spray(&stems, &dots, x, y, a, big, open: true, seed: b.rot + Double(k))
                } else {
                    spray(&stems, &buds, x, y, a, big, open: false, seed: b.rot + Double(k))
                }
            }
        }
        context.fill(stems, with: .color(t.ramp[2].mix(t.barkDark, 0.3).color(0.9)))
        context.fill(buds, with: .color(t.ramp[3].mix(t.ba, 0.55).color()))
        context.fill(dots, with: .color(t.ba.color()))
    }

    /// One spray: a stem, three pairs of short stalks up it, a dot at the end
    /// of each and one at the top.
    private func spray(_ stems: inout Path, _ dots: inout Path, _ x: Double, _ y: Double, _ a: Double, _ s: Double, open: Bool, seed: Double) {
        let len = s * 2.2, ca = cos(a), sa = sin(a)
        func at(_ u: Double, _ v: Double) -> CGPoint { CGPoint(x: x + ca * len * u - sa * len * v, y: y + sa * len * u + ca * len * v) }
        stems.move(to: at(0, 0))
        stems.addQuadCurve(to: at(1, 0), control: at(0.5, 0.03))
        stems.addQuadCurve(to: at(0, 0), control: at(0.5, -0.03))
        stems.closeSubpath()
        let r = s * (open ? 0.3 : 0.19)
        // A flower is a tiny cross of four petals; a bud is a dot.
        func flower(_ at: CGPoint, _ scale: Double, _ rot: Double) {
            if open {
                dots.oval(at.x, at.y, r * scale * 1.05, r * scale * 0.42, rot)
                dots.oval(at.x, at.y, r * scale * 1.05, r * scale * 0.42, rot + .pi / 2)
            } else {
                dots.oval(at.x, at.y, r * scale, r * scale * 0.9)
            }
        }
        for (n, u) in [0.34, 0.58, 0.8].enumerated() {
            for side in [-1.0, 1] {
                let jig = 0.05 * sin(seed * 3 + Double(n) * 2 + side * 1.7)
                let from = at(u, 0), to = at(u + 0.05 + jig, side * (0.17 + 0.05 * Double((n + (side > 0 ? 1 : 0)) % 2)))
                var stalk = Path()
                stalk.twig(from, to, s * 0.035, s * 0.025)
                stems.addPath(stalk)
                flower(to, 1 - 0.1 * Double(n), seed + Double(n) + side)
            }
        }
        flower(at(1.0, 0), 1.1, seed)
    }
}
