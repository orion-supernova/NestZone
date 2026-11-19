import SwiftUI

// MARK: - The lemon that is cut in half

extension LemonPainter {
    /// A lemon cut across: the rind round it, the thick white pith under the
    /// rind, nine juicy segments divided by pale walls and packed with
    /// vesicles, the seeds in two of them, a gleam of juice over the lot and a
    /// drop on the rind's lowest point. The other half of the lemon is a
    /// crescent of skin behind the cut face, and its nipple shows past the
    /// edge. Drawn at the size of the fruit it was, a little larger so the
    /// cut reads.
    func cutHalf(_ tree: GraphicsContext, _ h: Hang) {
        let L = core.L, day = core.day, night = core.night, sk = h.skin, t = core.tones
        let Rf = h.r * 1.32
        let rot = h.tilt * 0.4 + 0.15, ca = cos(rot), sa = sin(rot)
        let cx = h.x, cy = h.y + h.r * 0.2
        let squash = 0.95

        /// A point in the face's own frame: `rho` of the way out at angle `theta`.
        func face(_ theta: Double, _ rho: Double, dx: Double = 0, dy: Double = 0) -> CGPoint {
            let u = cos(theta) * Rf * rho, v = sin(theta) * Rf * rho * squash
            return CGPoint(x: cx + dx + ca * u - sa * v, y: cy + dy + sa * u + ca * v)
        }

        // The stalk, into the leaves above.
        var stalk = Path()
        stalk.twig(CGPoint(x: cx - h.side * Rf * 0.25, y: cy - Rf * 1.4), CGPoint(x: cx - L.x * Rf * 0.1, y: cy - Rf * 0.92), Rf * 0.1, Rf * 0.085)
        tree.fill(stalk, with: .color(t.ramp[2].mix(t.barkDark, 0.35).color(0.95)))

        // The rest of the lemon, behind: a crescent of skin on the shadow side
        // and the nipple past the edge.
        var back = Path()
        // It runs back from the face, away from the light, a lemon's length.
        let away = atan2(-L.y, -L.x)
        let bx = cx + cos(away) * Rf * 0.5, by = cy + sin(away) * Rf * 0.42
        back.oval(bx, by, Rf * 1.22, Rf * 0.98, away)
        back.oval(bx + cos(away) * Rf * 1.28, by + sin(away) * Rf * 1.28, Rf * 0.24, Rf * 0.17, away)
        tree.fill(back, with: .radialGradient(
            Gradient(stops: [.init(color: sk.mid.color(), location: 0), .init(color: sk.shade.color(), location: 1)]),
            center: CGPoint(x: bx + L.x * Rf * 0.5, y: by + L.y * Rf * 0.5), startRadius: Rf * 0.2, endRadius: Rf * 1.7))

        // The rind, then the pith inside it.
        let set = TreeColours.lemon(canopy.colourway)
        let pith = RGB.tone(set.pith, day: day, dim: 0.8).mix(sk.hi, 0.12).mix(RGB(0xC9C09A), 0.35 * core.M.thirst)
        var rind = Path(), inner = Path()
        rind.oval(cx, cy, Rf, Rf * squash, rot)
        inner.oval(cx, cy, Rf * 0.925, Rf * 0.925 * squash, rot)
        tree.fill(rind, with: .color(sk.mid.mix(sk.shade, 0.15).color()))
        tree.fill(inner, with: .color(pith.color()))

        // Nine segments, each a wedge rounded at its outer end, with a pale
        // wall between each and the next.
        let n = 9, half = Double.pi / Double(n) * 0.84
        var flesh = Path(), vesicles = Path(), seeds = Path(), seedShade = Path()
        for k in 0..<n {
            let th = Double(k) * 2 * .pi / Double(n) + 0.3
            flesh.move(to: face(th - half * 0.5, 0.1))
            flesh.addLine(to: face(th - half, 0.76))
            flesh.addQuadCurve(to: face(th + half, 0.76), control: face(th, 0.9))
            flesh.addLine(to: face(th + half * 0.5, 0.1))
            flesh.closeSubpath()
            // Vesicles: long juicy cells, pale, pointing into the middle.
            for j in -2...2 {
                let a = th + Double(j) * half * 0.36, r0 = 0.3 + 0.05 * Double((k + j) % 3), r1 = 0.7 - 0.04 * Double(abs(j))
                let p0 = face(a, r0), p1 = face(a, r1)
                let dx = p1.x - p0.x, dy = p1.y - p0.y, d = max(1e-6, (dx * dx + dy * dy).squareRoot())
                let nx = -dy / d * Rf * 0.018, ny = dx / d * Rf * 0.018
                vesicles.move(to: p0)
                vesicles.addQuadCurve(to: p1, control: CGPoint(x: (p0.x + p1.x) / 2 + nx, y: (p0.y + p1.y) / 2 + ny))
                vesicles.addQuadCurve(to: p0, control: CGPoint(x: (p0.x + p1.x) / 2 - nx, y: (p0.y + p1.y) / 2 - ny))
                vesicles.closeSubpath()
            }
            // Seeds lie in two of the segments, pointing at the middle.
            if k == 1 || k == 5 {
                for (s, rho) in [0.36, 0.55].enumerated() {
                    let a = th + (s == 0 ? -0.08 : 0.1), c = face(a, rho)
                    let toward = atan2(cy - c.y, cx - c.x) + .pi
                    seeds.oval(c.x, c.y, Rf * 0.075, Rf * 0.045, toward)
                    seedShade.oval(c.x - L.x * Rf * 0.018, c.y - L.y * Rf * 0.018 + Rf * 0.01, Rf * 0.075, Rf * 0.045, toward)
                }
            }
        }
        let reach = Rf * 0.75
        func juice(_ a: UInt32, _ b: UInt32, _ c: UInt32) -> GraphicsContext.Shading {
            .linearGradient(Gradient(stops: [.init(color: RGB.tone(a, day: day, dim: 0.85).color(), location: 0),
                                             .init(color: RGB.tone(b, day: day, dim: 0.8).color(), location: 0.5),
                                             .init(color: RGB.tone(c, day: day, dim: 0.75).color(), location: 1)]),
                            startPoint: CGPoint(x: cx + L.x * reach, y: cy + L.y * reach), endPoint: CGPoint(x: cx - L.x * reach, y: cy - L.y * reach))
        }
        tree.fill(flesh, with: juice(set.juice.hi, set.juice.mid, set.juice.shade))
        tree.fill(vesicles, with: .color(RGB.tone(set.vesicles, day: day, dim: 0.8).color(0.5 * (1 - 0.3 * night))))
        // The core, where the walls meet.
        var heart = Path()
        heart.oval(cx, cy, Rf * 0.085, Rf * 0.075, rot)
        tree.fill(heart, with: .color(pith.color()))
        tree.fill(seedShade, with: .color(RGB.tone(0xB8962C, day: day, dim: 0.8).color(0.5)))
        tree.fill(seeds, with: .color(RGB.tone(0xF4E8BC, day: day, dim: 0.85).color()))

        // A gleam of juice over the lit side, a light along the rind, and a drop
        // on the rind's lowest point.
        var sheen = Path()
        sheen.oval(cx + L.x * Rf * 0.22, cy + L.y * Rf * 0.22, Rf * 0.5, Rf * 0.4, rot)
        tree.fill(sheen, with: .radialGradient(Gradient(colors: [Color.white.opacity(0.26 * (1 - 0.5 * night)), Color.white.opacity(0)]),
                                               center: CGPoint(x: cx + L.x * Rf * 0.22, y: cy + L.y * Rf * 0.22), startRadius: 0, endRadius: Rf * 0.5))
        let lightAngle = atan2(L.y, L.x)
        var edge = Path()
        edge.move(to: face(lightAngle - 0.5, 0.965))
        edge.addQuadCurve(to: face(lightAngle + 0.5, 0.965), control: face(lightAngle, 1.03))
        edge.addQuadCurve(to: face(lightAngle - 0.5, 0.965), control: face(lightAngle, 0.93))
        edge.closeSubpath()
        tree.fill(edge, with: .color(sk.hi.mix(RGB(0xFFFFFF), 0.5).color(0.55 * (1 - 0.4 * night))))
        let foot = face(.pi / 2 - rot * 0.4, 1)
        var drop = Path(), shine = Path()
        drop.oval(foot.x, foot.y + Rf * 0.16, Rf * 0.065, Rf * 0.085)
        drop.move(to: CGPoint(x: foot.x - Rf * 0.03, y: foot.y - Rf * 0.005))
        drop.addLine(to: CGPoint(x: foot.x + Rf * 0.03, y: foot.y - Rf * 0.005))
        drop.addLine(to: CGPoint(x: foot.x, y: foot.y + Rf * 0.12))
        drop.closeSubpath()
        shine.oval(foot.x + L.x * Rf * 0.02, foot.y + Rf * 0.155 + L.y * Rf * 0.02, Rf * 0.02, Rf * 0.026)
        tree.fill(drop, with: .color(RGB.tone(set.drop, day: day, dim: 0.8).color(0.95)))
        tree.fill(shine, with: .color(Color.white.opacity(0.9)))
    }
}
