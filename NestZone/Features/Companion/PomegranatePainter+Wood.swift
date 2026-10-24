import SwiftUI

// MARK: - The wood

extension PomegranatePainter.Look {
    private typealias RGB = Canopy.RGB

    /// A point a share `u` of the way along a limb's centre line.
    func along(_ q: Canopy.Pose.Span, _ u: Double) -> CGPoint {
        let v = 1 - u
        return CGPoint(x: v * v * q.x + 2 * u * v * q.cx + u * u * q.x1, y: v * v * q.y + 2 * u * v * q.cy + u * u * q.y1)
    }

    /// The stems and limbs: one silhouette with a root flare, a core shadow on
    /// the side away from the light and a lit edge on the side towards it, then
    /// the bark. A pomegranate's bark is grey-brown and shreds in long
    /// strips, so thick wood gets long streaks, a few short flakes lifted
    /// pale, and knots where it is gnarled. A young whip is smooth, and only
    /// gets its bark as it thickens. The crown's shade falls over it last.
    func wood(_ context: GraphicsContext) {
        let t = tones
        var outline = Path(), edge = Path(), core = Path()
        var dark = Path(), pale = Path(), flakes = Path(), knots = Path(), shade = Path()
        var flare = 0.0, any = false
        for (i, nd) in canopy.limbs.enumerated() {
            guard let q = pose.limbs[i] else { continue }
            any = true
            let root = nd.parent < 0
            if root { flare = max(flare, q.w0) }
            outline.limb(q, q.w0, q.w1, 0, flat: root)
            let am = atan2(q.y1 - q.y, q.x1 - q.x)
            let side: Double = sin(am) * L.x - cos(am) * L.y > 0 ? -1 : 1
            edge.limb(q, q.w0 * 0.26, q.w1 * 0.2, side * 0.34, flat: root)
            core.limb(q, q.w0 * 0.34, q.w1 * 0.3, -side * 0.3, flat: root)
            guard nd.depth <= 1 && q.w0 > 2.2 else { continue }
            let nx = -sin(am), ny = cos(am)
            let thick = q.w0 > 4

            // Long strips, a little wavy, running with the grain.
            for (n, f) in [-0.3, 0.02, 0.3].enumerated() where thick || n == 1 {
                let w0 = f * q.w0, w1 = f * q.w1, mid = f * (q.w0 + q.w1) * 0.5 + nx * 0 + (n == 1 ? q.w0 * 0.07 : -q.w0 * 0.05)
                var path = Path()
                path.move(to: CGPoint(x: q.x + nx * w0, y: q.y + ny * w0))
                path.addQuadCurve(to: CGPoint(x: q.x1 + nx * w1, y: q.y1 + ny * w1), control: CGPoint(x: q.cx + nx * mid, y: q.cy + ny * mid))
                if (f < 0) == (side < 0) { pale.addPath(path) } else { dark.addPath(path) }
            }
            // Short strips and flakes across the grain, tilted: the shreds.
            var u = 0.14
            var n = 0
            while u < 0.9 {
                let c = along(q, u), w = Ink.lerp(q.w0, q.w1, u)
                let sx = Double((n * 5) % 7 - 3) * 0.1
                let a = CGPoint(x: c.x + nx * w * (sx - 0.22), y: c.y + ny * w * (sx - 0.22))
                let b = CGPoint(x: c.x + nx * w * (sx + 0.12) - ny * w * 0.3, y: c.y + ny * w * (sx + 0.12) + nx * w * 0.3)
                if n % 4 == 0 { flakes.move(to: a); flakes.addLine(to: b) } else { dark.move(to: a); dark.addLine(to: b) }
                u += thick ? 0.11 : 0.19
                n += 1
            }
            if nd.depth == 0 && !root && q.g > 0.9 && thick {
                let c = along(q, 0.46), w = Ink.lerp(q.w0, q.w1, 0.46)
                knots.oval(c.x + nx * w * 0.1, c.y + ny * w * 0.1, w * 0.14, w * 0.22, am)
            }
        }
        guard any else { return }
        outline.flare(flare)
        for (j, spot) in pose.clumps.enumerated() {
            guard let q = spot, !canopy.clumps[j].tuft, canopy.clumps[j].tier > 0 else { continue }
            shade.oval(q.x + q.R * 0.08, q.y + q.R * 0.42, q.R * 0.8, q.R * 0.7)
        }

        let fade = Gradient(stops: [.init(color: t.barkDark.color(), location: 0), .init(color: t.bark.color(), location: 0.55),
                                    .init(color: t.bark.shifted(3).color(), location: 1)])
        context.fill(outline, with: .linearGradient(fade, startPoint: CGPoint(x: 0, y: pose.bottom * 0.65 + pose.top * 0.35), endPoint: .zero))
        context.fill(core, with: .color(t.barkDark.color(0.55)))
        let shine = Gradient(stops: [.init(color: t.barkHi.color(0.35), location: 0), .init(color: t.barkHi.color(0.75), location: 0.5),
                                     .init(color: t.barkHi.color(0.95), location: 1)])
        context.fill(edge, with: .linearGradient(shine, startPoint: CGPoint(x: 0, y: pose.top), endPoint: .zero))
        if !dark.isEmpty { context.stroke(dark, with: .color(t.barkDark.color(0.55)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round)) }
        if !pale.isEmpty { context.stroke(pale, with: .color(t.barkHi.color(0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round)) }
        if !flakes.isEmpty { context.stroke(flakes, with: .color(t.barkHi.shifted(6).color(0.4)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round)) }
        if !knots.isEmpty { context.fill(knots, with: .color(t.barkDark.color(0.85))) }
        guard !shade.isEmpty else { return }
        let deep = t.ramp[0].mix(RGB(0x122027), 0.35).shifted(-10)
        let under = Gradient(colors: [deep.color(0.42 * (1 - 0.3 * M.doze)), deep.color(0.12)])
        var c = context
        c.clip(to: outline)
        c.fill(shade, with: .linearGradient(under, startPoint: CGPoint(x: 0, y: (pose.top + pose.bottom) / 2), endPoint: CGPoint(x: 0, y: pose.bottom + 20)))
    }
}

// MARK: - On the soil, and a sprout

extension PomegranatePainter.Look {
    /// The seed, a ruby one, early on; then the small things a pot collects:
    /// a leaf, a fallen petal once it flowers, one loose aril once a fruit is
    /// open, and when thirsty more leaves and a fruit that has dropped.
    /// Unscaled, on the soil.
    func ground(_ context: GraphicsContext) {
        let t = tones
        let ks = 1 - Ink.smooth((p - 0.085) / 0.04)
        if ks > 0 {
            var seed = Path(), shine = Path()
            seed.oval(0, -3, 4.6 * ks, 3.2 * ks, -0.5)
            shine.oval(-1.3 * ks, -4 * ks, 1.5 * ks, 0.8 * ks, -0.5)
            let flesh = Gradient(colors: [RGB.tone(0xE0566A, day: day).color(), RGB.tone(0x8E1E36, day: day).color()])
            context.fill(seed, with: .linearGradient(flesh, startPoint: CGPoint(x: -4, y: -6), endPoint: CGPoint(x: 4, y: 0)))
            context.fill(shine, with: .color(RGB.tone(0xFFD0D6, day: day).color(0.85)))
        }

        let strewn = Int((10 * Ink.clamp(0.55 * M.thirst + 0.45 * M.doze) + 0.5).rounded(.down))
        let count = max(strewn, p > 0.45 ? 1 : 0)
        var leaves = Path()
        for f in canopy.fallen.prefix(count) {
            let ca = cos(f.a), sa = sin(f.a)
            leaves.lance(f.x - ca * f.len / 2, f.y - sa * f.len / 2 * 0.4, ca, sa * 0.4, f.len, f.len * 0.17, 0.1, 0)
        }
        if !leaves.isEmpty {
            let dry = Gradient(colors: [t.fallen.color(), t.fallen.shifted(-8, 6).color()])
            context.fill(leaves, with: .linearGradient(dry, startPoint: CGPoint(x: -40, y: -3), endPoint: CGPoint(x: 40, y: 3)))
        }

        // A petal that has come down, crumpled and curled.
        if p > 0.78 && p < 0.97 + 0.01 && M.open > 0.3, canopy.fallen.count > 4 {
            let f = canopy.fallen[4]
            var petal = Path(), fold = Path()
            petal.frill(f.x * 0.55, f.y * 0.8 - 1, 4.4, 2.3, f.a * 0.5, 1.3, 0.1)
            fold.move(to: CGPoint(x: f.x * 0.55 - 2.2, y: f.y * 0.8 - 1))
            fold.addLine(to: CGPoint(x: f.x * 0.55 + 2.4, y: f.y * 0.8 - 1.4))
            context.fill(petal, with: .linearGradient(Gradient(colors: [t.bb.color(), t.ba.color()]),
                                                       startPoint: CGPoint(x: f.x * 0.55, y: f.y * 0.8 - 3), endPoint: CGPoint(x: f.x * 0.55, y: f.y * 0.8)))
            context.stroke(fold, with: .color(t.bc.color(0.5)), lineWidth: 0.4)
        }
        // One aril that rolled out of the split fruit.
        if p > 0.94 && M.thirst < 0.5, canopy.fallen.count > 7 {
            let f = canopy.fallen[7]
            var aril = Path()
            aril.oval(f.x * 0.45, f.y - 0.4, 1.7, 1.55)
            context.fill(aril, with: .radialGradient(Gradient(colors: [RGB(0xFF7A8C).color(), RGB(0xB8183A).color(), RGB(0x7C0C26).color()]),
                                                      center: CGPoint(x: f.x * 0.45 - 0.6, y: f.y - 1), startRadius: 0, endRadius: 2.4))
            var dot = Path()
            dot.oval(f.x * 0.45 - 0.6, f.y - 1, 0.45, 0.35)
            context.fill(dot, with: .color(Color.white.opacity(0.85)))
        }
        // A thirsty tree has let a fruit fall.
        if M.thirst > 0.5 && p > 0.9, canopy.fallen.count > 1 {
            let f = canopy.fallen[1], x = f.x * 0.6, y = f.y * 0.4 - 4.2, r = 5.0
            var shadow = Path(), body = Path(), crown = Path()
            shadow.oval(x + 0.6, y + r * 0.95, r * 1.05, r * 0.28)
            body.oval(x, y, r, r * 0.92, 0.2)
            crown.oval(x + r * 0.7, y - r * 0.15, r * 0.28, r * 0.22)
            context.fill(shadow, with: .color(SceneInk.shadow))
            let sk = RGB.tone(0x9A3A44, day: day), dk = RGB.tone(0x5A1E2A, day: day)
            context.fill(body, with: .radialGradient(Gradient(colors: [sk.mix(RGB(0xFFFFFF), 0.2).color(), sk.color(), dk.color()]),
                                                      center: CGPoint(x: x - 1.6, y: y - 1.8), startRadius: 0, endRadius: r * 1.5))
            context.fill(crown, with: .color(dk.color()))
        }
    }

    /// Two narrow seed leaves at the tip of the first stem, bronze as new
    /// pomegranate leaves are, with a lit half each.
    func seedLeaves(_ context: GraphicsContext) {
        let kc = Ink.back((p - 0.09) / 0.05) * (1 - Ink.smooth((p - 0.3) / 0.1))
        guard kc > 0, let root = canopy.limbs.indices.first(where: { canopy.limbs[$0].parent < 0 && pose.limbs[$0] != nil }),
              let q = pose.limbs[root] else { return }
        let ink = inks[5]
        var full = Path(), lit = Path()
        for s in [-1.0, 1] {
            let a = -Double.pi / 2 + s * (1.15 + 0.4 * M.wilt - 0.15 * M.glow)
            full.lance(q.x1, q.y1, cos(a), sin(a), 12 * kc, 2.7 * kc, s * 0.1, 0)
            lit.lance(q.x1, q.y1, cos(a), sin(a), 12 * kc, 2.7 * kc, s * 0.1, (-sin(a) * L.x + cos(a) * L.y) >= 0 ? 1 : -1)
        }
        context.fill(full, with: .color(ink.m))
        context.fill(lit, with: .color(ink.s))
    }
}
