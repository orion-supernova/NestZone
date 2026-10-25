import SwiftUI

// The sculpt: a trunk with branches that end in pads of foliage, grown for its
// shape and not its flowers. A bonsai, a potted maple and a potted pine are
// this rule; what differs is the trunk, where the branches leave it and what a
// pad is made of (`PlantPlan.Pad`, `PadArt`).
//
// - bonsai: a thick, curving trunk that flares into roots at the soil, three
//   branches and a crown, each ending in a flat cloud of small round leaves, a
//   pale stub of deadwood (a jin) and a patch of moss at the foot.
// - maple: a slender trunk that forks, with layers of red and orange palmate
//   leaves, and a few fallen on the soil.
// - pine: a straight trunk with whorls of drooping needle sprays that make a
//   cone, a leader with new growth at the top and a couple of cones.
//
// Pads are merged by depth into four fills each: the whole, the upper part, the
// sunward part and the glints. The shadows under them are one fill.
//
// Growth: the seed, a thin shoot with one pad at its tip (.1 to .28), the trunk
// thickening and rising (.12 to .72), a branch and its pad at a time from .3,
// the last pads at about .8. A thirsty one lets its pads sag and shrink and
// leans the trunk; a dozing one is pale.
extension PlantPainter {
    private struct Limb {
        /// A cubic, as the plant grows full size and leaning to the right.
        var a, c1, c2, b: CGPoint
        var born, span, w0, w1: Double
        /// Behind (0) or in front of (1) the trunk.
        var z: Int
        /// Where on the trunk it leaves, 0 for the trunk itself.
        var from = 0.0
    }

    private struct PadSpec {
        var limb: Int
        var t: Double
        var size, squash, born: Double
        var variant, z: Int
    }

    func sculpt(_ c: GraphicsContext?, _ m: inout Marks) {
        let sx = seed.side, wilt = self.wilt
        func v(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y) }
        let kind: PadArt.Kind = plan.pad == .maple ? .maple : plan.pad == .conifer ? .conifer : .leafy

        // The form of each: a trunk, branches off it, pads on them.
        var limbs: [Limb] = []
        var pads: [PadSpec] = []
        let trunk: Limb
        switch plan.pad {
        case .conifer:
            trunk = Limb(a: v(0, 1), c1: v(0, -60), c2: v(1.5, -118), b: v(seed.lean * 3, -plan.height + 24), born: 0.1, span: 0.62, w0: 9, w1: 2.4, z: 1)
            limbs.append(trunk)
            for k in 0..<8 {
                let kk = Double(k)
                let y = -(26 + 17 * kk), half = 50 - 5.4 * kk
                let born = 0.16 + 0.07 * kk
                let sag = wilt * 5
                for s in [-1.0, 1.0] {
                    limbs.append(Limb(a: v(0, 0), c1: v(s * half * 0.3, -1), c2: v(s * half * 0.6, 4), b: v(s * half * 0.8, 9 + sag), born: born, span: 0.14, w0: 3, w1: 1.4, z: 0, from: -y / Double(plan.height - 24)))
                    pads.append(PadSpec(limb: limbs.count - 1, t: 1, size: half * 0.66, squash: 1, born: born + 0.03, variant: k + Int(s + 1), z: s > 0 ? 0 : 0))
                }
                if k < 6 {
                    pads.append(PadSpec(limb: 0, t: -y / Double(plan.height - 24), size: half * 0.56, squash: 0.9, born: born + 0.05, variant: k + 1, z: 1))
                }
            }
            pads.append(PadSpec(limb: 0, t: 1, size: 11, squash: 1, born: 0.7, variant: 2, z: 1))
        case .maple:
            trunk = Limb(a: v(0, 1), c1: v(4, -40), c2: v(-6, -90), b: v(2, -124), born: 0.1, span: 0.6, w0: 12, w1: 3.4, z: 1)
            limbs.append(trunk)
            let forks: [(t: Double, dx: Double, dy: Double, born: Double, z: Int, size: Double)] = [
                (0.4, -50, -42, 0.3, 0, 35), (0.5, 48, -48, 0.36, 0, 35), (0.66, -26, -42, 0.46, 1, 30), (0.76, 28, -32, 0.54, 1, 29),
            ]
            for (i, f) in forks.enumerated() {
                limbs.append(Limb(a: v(0, 0), c1: v(f.dx * 0.15, -4), c2: v(f.dx * 0.7, f.dy * 0.4), b: v(f.dx, f.dy + wilt * 8), born: f.born, span: 0.26, w0: 4.2, w1: 1.8, z: f.z, from: f.t))
                pads.append(PadSpec(limb: limbs.count - 1, t: 1, size: f.size, squash: 0.95, born: f.born + 0.1, variant: i, z: f.z))
                pads.append(PadSpec(limb: limbs.count - 1, t: 0.55, size: f.size * 0.6, squash: 0.95, born: f.born + 0.2, variant: i + 1, z: 0))
            }
            pads.append(PadSpec(limb: 0, t: 1, size: 30, squash: 0.95, born: 0.14, variant: 2, z: 1))
        default:
            trunk = Limb(a: v(0, 1), c1: v(-16, -28), c2: v(22, -60), b: v(-6, -98), born: 0.1, span: 0.6, w0: 20, w1: 6, z: 1)
            limbs.append(trunk)
            let forks: [(t: Double, dx: Double, dy: Double, born: Double, z: Int, size: Double)] = [
                (0.3, -48, -30, 0.3, 0, 37), (0.52, 46, -26, 0.4, 1, 36), (0.76, -30, -22, 0.52, 1, 29),
            ]
            for (i, f) in forks.enumerated() {
                limbs.append(Limb(a: v(0, 0), c1: v(f.dx * 0.35, -2), c2: v(f.dx * 0.7, f.dy * 0.5), b: v(f.dx, f.dy + wilt * 8), born: f.born, span: 0.26, w0: 6.4, w1: 2.4, z: f.z, from: f.t))
                pads.append(PadSpec(limb: limbs.count - 1, t: 1, size: f.size, squash: 1, born: f.born + 0.1, variant: i, z: f.z))
            }
            pads.append(PadSpec(limb: 1, t: 0.5, size: 17, squash: 1, born: 0.5, variant: 1, z: 0))
            pads.append(PadSpec(limb: 0, t: 1, size: 34, squash: 1, born: 0.14, variant: 2, z: 1))
        }

        // How far each limb has grown, and the sampled path of it, trimmed.
        func reach(_ i: Int) -> Double {
            i == 0 ? grown([(0.09, 0), (0.12, 0.14), (0.3, 0.42), (0.5, 0.78), (0.72, 1)]) : Ink.smooth((p - limbs[i].born) / limbs[i].span)
        }
        let whole = Self.cubic(trunk.a, trunk.c1, trunk.c2, trunk.b, n: 24)
        let slant = seed.lean * 0.01 + sx * wilt * 0.04
        // The wilt leans the whole trunk about its foot.
        func lean(_ q: CGPoint) -> CGPoint { CGPoint(x: q.x - slant * q.y, y: q.y) }
        let trunkPath = Self.cubic(trunk.a, trunk.c1, trunk.c2, trunk.b, upTo: max(0.001, reach(0)), n: 20).map(lean)
        var paths: [[CGPoint]] = [trunkPath]
        for i in 1..<limbs.count {
            let l = limbs[i]
            // A limb leaves the trunk where it has got to.
            let from = Self.along(whole, l.from)
            let at = lean(from)
            let a = CGPoint(x: at.x + l.a.x, y: at.y + l.a.y)
            let shifted: (CGPoint) -> CGPoint = { CGPoint(x: at.x + $0.x, y: at.y + $0.y) }
            paths.append(Self.cubic(a, shifted(l.c1), shifted(l.c2), shifted(l.b), upTo: max(0.001, reach(i)), n: 10))
        }
        func point(_ pad: PadSpec) -> CGPoint {
            if pad.limb == 0 {
                let r = max(0.001, reach(0))
                return pad.t >= 1 ? paths[0][paths[0].count - 1] : Self.along(paths[0], min(1, pad.t / r))
            }
            return Self.along(paths[pad.limb], pad.t)
        }

        var back = PadBatch(), front = PadBatch()
        let flip = L.x >= 0 ? 1.0 : -1.0
        for (i, pad) in pads.enumerated() {
            let k = pop(pad.born, over: 0.12)
            guard k > 0.03, reach(pad.limb) > 0.02, pad.limb != 0 || reach(0) > 0.12 || pad.t >= 1 else { continue }
            if pad.limb != 0, reach(pad.limb) < 0.7 * pad.t { continue }
            if pad.limb == 0, pad.t < 1, reach(0) < pad.t { continue }
            let at = point(pad)
            let size = pad.size * k * (1 - 0.14 * wilt) * (0.5 + 0.5 * Ink.smooth((p - 0.1) / 0.3)) * seed.between(i, 0.94, 1.06)
            let sy = size * pad.squash * (1 - 0.18 * wilt) * (kind == .conifer ? 1.0 : 0.92)
            let centre = CGPoint(x: at.x, y: at.y + (kind == .conifer ? 0 : sy * 0.12) + wilt * size * 0.1)
            if c != nil {
                let shape = PadArt.of(kind, variant: pad.variant)
                let t = CGAffineTransform(translationX: centre.x, y: centre.y).scaledBy(x: size, y: sy)
                let tl = CGAffineTransform(translationX: centre.x, y: centre.y).scaledBy(x: size * flip, y: sy)
                if pad.z == 0 { back.add(shape, t, tl) } else { front.add(shape, t, tl) }
            }
            m.note(CGPoint(x: centre.x, y: centre.y + sy * 0.15), reach: size * 0.8, hang: pad.z == 1 || kind != .conifer)
        }

        guard let c else {
            m.note(trunkPath[trunkPath.count - 1], reach: 3, hang: false)
            return
        }
        // Shadows of the foliage on the foliage behind it, then the back limbs
        // and pads, the trunk, and the front.
        // A pine's sixteen branches are one fill; the others are each painted.
        if kind == .conifer {
            var twigs = Path()
            for i in 1..<limbs.count where reach(i) > 0.02 { twigs.addPath(Self.ribbon(paths[i], limbs[i].w0, limbs[i].w1)) }
            c.fill(twigs, with: .color(ramp[1].mix(RGB.tone(barkTint, day: day, dim: 0.85), 0.6).color()))
        }
        for i in 1..<limbs.count where limbs[i].z == 0 && reach(i) > 0.02 && kind != .conifer { limb(c, i, limbs, paths, reach(i)) }
        back.flush(c, ink: inks[0], top: inks[1].l, glow: glow, night: night)
        if reach(0) > 0.02 {
            limb(c, 0, limbs, paths, reach(0))
            bark(c, trunkPath, width: trunk.w0 * Ink.lerp(0.4, 1, Ink.smooth(p / 0.7)))
        }
        for i in 1..<limbs.count where limbs[i].z == 1 && reach(i) > 0.02 { limb(c, i, limbs, paths, reach(i)) }
        front.flush(c, ink: inks[1], top: inks[2].l, glow: glow, night: night)

        if plan.pad == .leafy, p > 0.4 { jinAndMoss(c, trunkPath) }
        if plan.pad == .conifer, p > 0.78 { cones(c, trunkPath) }
        if plan.pad != .conifer, p > 0.82 { fallenLeaves(c) }
        m.note(trunkPath[trunkPath.count - 1], reach: 3, hang: false)
    }

    /// A limb as a tapered ribbon in wood, grown to its reach.
    private func limb(_ c: GraphicsContext, _ i: Int, _ limbs: [Limb], _ paths: [[CGPoint]], _ r: Double) {
        let l = limbs[i]
        let grow = Ink.lerp(0.55, 1, Ink.smooth(p / 0.7))
        let w0 = l.w0 * (i == 0 ? grow : 0.5 + 0.5 * r), w1 = l.w1 * (i == 0 ? grow : 1)
        paint(c, stem: Self.ribbon(paths[i], w0, w1, flat: false), along: paths[i], width: w0, tier: 1, tint: barkTint)
    }

    private var barkTint: UInt32 { plan.pad == .conifer ? 0x7A4A36 : plan.pad == .maple ? 0x6E4A3C : 0x6C5442 }

    /// The trunk's bark: a few dark fissures down its length, a lit ridge, and
    /// for a thick trunk a flare of roots across the soil.
    private func bark(_ c: GraphicsContext, _ path: [CGPoint], width w: Double) {
        guard path.count > 3 else { return }
        var fissures = Path(), ridge = Path()
        for k in 0..<5 {
            let t0 = 0.04 + 0.16 * Double(k) + seed.between(k, 0, 0.05), t1 = t0 + 0.12 + seed.between(k + 5, 0, 0.08)
            guard t1 < 0.96 else { continue }
            let off = (seed.between(k + 9, -0.35, 0.35)) * w
            let a = Self.along(path, t0), b = Self.along(path, t1)
            fissures.lens(from: CGPoint(x: a.x + off, y: a.y), to: CGPoint(x: b.x + off * 0.8, y: b.y), width: 0.9)
            if k.isMultiple(of: 2) {
                let side = L.x >= 0 ? 1.0 : -1.0
                ridge.lens(from: CGPoint(x: a.x + side * w * 0.26, y: a.y), to: CGPoint(x: b.x + side * w * 0.2, y: b.y), width: 0.8)
            }
        }
        c.fill(fissures, with: .color(ramp[0].mix(RGB(0x2A1A14), 0.7).color(0.55)))
        c.fill(ridge, with: .color(rimTone.mix(RGB(0xB89A7C), 0.4).color(0.4 + 0.2 * dusk)))
        guard plan.pad == .leafy, w > 8 else { return }
        // Roots over the soil.
        var roots = Path()
        for (dx, len) in [(-1.0, 17.0), (-0.45, 12.0), (0.5, 13.0), (1.0, 18.0)] {
            roots.addPath(Self.ribbon([CGPoint(x: dx * 3, y: -5), CGPoint(x: dx * len * 0.7, y: -1), CGPoint(x: dx * len, y: 2)], 5, 1.6))
        }
        c.fill(roots, with: .color(ramp[1].mix(RGB(0x5A4432), 0.55).color()))
    }

    /// Deadwood on a bonsai's trunk, and moss at its foot.
    private func jinAndMoss(_ c: GraphicsContext, _ trunk: [CGPoint]) {
        guard trunk.count > 6 else { return }
        let at = Self.along(trunk, 0.45), side = seed.side
        var jin = Path()
        jin.lens(from: CGPoint(x: at.x, y: at.y), to: CGPoint(x: at.x + side * 14, y: at.y + 6), width: 3.4)
        c.fill(jin, with: .color(RGB.tone(0xC9BBA6, day: day, dim: 0.9).color(0.95)))
        var moss = Path()
        for (x, rx) in [(-6.0, 5.0), (3.0, 6.0), (10.0, 3.6)] { moss.oval(x * side, -2.5, rx, 2.4) }
        c.fill(moss, with: .color(ramp[3].mix(RGB(0x8AB84A), 0.3).color(0.9)))
    }

    /// Two cones hanging among the lower needles.
    private func cones(_ c: GraphicsContext, _ trunk: [CGPoint]) {
        let k = Ink.smooth((p - 0.78) / 0.12)
        var body = Path(), scales = Path()
        for (x, y) in [(-26.0, -70.0), (22.0, -52.0)] {
            let at = CGPoint(x: x * seed.side, y: y)
            body.oval(at.x, at.y + 6 * k, 3.6 * k, 6.4 * k, 0.1)
            for r in 0..<3 { scales.addEllipse(in: CGRect(x: at.x - 2.8 * k, y: at.y + (1 + 3.4 * Double(r)) * k, width: 5.6 * k, height: 1.1 * k)) }
        }
        c.fill(body, with: .color(RGB.tone(0x8A5A34, day: day, dim: 0.85).color()))
        c.fill(scales, with: .color(RGB.tone(0x5A3820, day: day, dim: 0.85).color(0.7)))
    }

    /// A few leaves on the soil.
    private func fallenLeaves(_ c: GraphicsContext) {
        let tone = ramp[plan.pad == .maple ? 2 : 3]
        onSoil(c, x: -seed.side * 20, length: 8, width: 3.6, turn: 0.5 * seed.side, tone: tone)
        if plan.pad == .maple || M.thirst > 0.3 {
            onSoil(c, x: seed.side * 15, length: 7, width: 3.2, turn: -0.7, tone: tone.mix(ramp[1], 0.4))
            onSoil(c, x: -seed.side * 4, length: 6, width: 2.8, turn: 1.0, tone: tone.mix(ramp[4], 0.3))
        }
    }
}

/// Pads gathered by depth into the four paths each is drawn in.
struct PadBatch {
    var shade = Path(), mid = Path(), lit = Path(), top = Path()

    mutating func add(_ shape: PadShape, _ t: CGAffineTransform, _ tl: CGAffineTransform) {
        shade.addPath(shape.shade, transform: t)
        mid.addPath(shape.mid, transform: t)
        lit.addPath(shape.lit, transform: tl)
        top.addPath(shape.top, transform: tl)
    }

    func flush(_ c: GraphicsContext, ink: PlantPainter.LeafInk, top glint: Color, glow: PlantPainter.RGB, night: Double) {
        c.fill(shade, with: .color(ink.d))
        c.fill(mid, with: .color(ink.m))
        c.fill(lit, with: .color(ink.l))
        c.fill(top, with: .color(glint))
    }
}
