import SwiftUI

// MARK: - The wood

extension PomegranatePainter.Look {
    private typealias RGB = Canopy.RGB

    /// A point a share `u` of the way along a limb's centre line.
    func along(_ q: Canopy.Pose.Span, _ u: Double) -> CGPoint {
        let v = 1 - u
        return CGPoint(x: v * v * q.x + 2 * u * v * q.cx + u * u * q.x1, y: v * v * q.y + 2 * u * v * q.cy + u * u * q.y1)
    }

    /// The stems and limbs. A pomegranate's bark is grey-brown and shreds in
    /// long strips along the stem (`BarkStyle.shredded`).
    func wood(_ context: GraphicsContext) {
        TreeWood(canopy: canopy, pose: pose, L: L, tones: tones, M: M, style: .shredded).paint(context)
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
