import SwiftUI

/// The moss pole's texture in its own units (x across, -1 to 1; y up the pole,
/// 0 to -1), built once: clumps of darker and lighter moss, small and wide.
enum MossArt {
    static let (dark, light): (Path, Path) = {
        var dark = Path(), light = Path()
        var r = Ink.Random(seed: 11)
        for i in 0..<150 {
            let x = (r.next() * 2 - 1) * 0.94, y = -r.next()
            let rx = 0.12 + 0.2 * r.next(), ry = 0.006 + 0.012 * r.next()
            let rot = (r.next() - 0.5) * 0.6
            if i % 5 < 2 { dark.oval(x, y, rx, ry, rot) } else { light.oval(x - 0.04, y - 0.004, rx * 0.8, ry * 0.7, rot) }
        }
        return (dark, light)
    }()
}

// The vine: stems that climb, arch and trail, each with its leaves at fixed
// places along it and a young leaf unrolling at its tip. A monstera is this
// rule. Its leaves are whole when they are young and cut themselves into
// slits and holes as they age (`LeafShape.Kind.monstera0…3`), which is what
// makes the growth readable: the first leaf is a heart, the last is a hand.
// A pothos or an ivy is the same stems with `heart` leaves that stay whole.
//
// The main stem climbs a moss pole (put in at .3, tied with twine, its moss
// lit from the sun's side) and sends aerial roots down it from its nodes.
//
// Growth: the seed, one small whole leaf (.12), the main stem climbing and
// putting out leaves on alternate sides (.3 to .56), a second stem arching out
// (.3 to .75), and a third that climbs out over the pot's rim and trails down
// its front (.5 to .88), whose leaves are smaller. A thirsty one lets its
// leaves hang from their stalks and its stems sag; a dozing one hangs limp.
extension PlantPainter {
    private struct Stem {
        /// A cubic, in a plant that leans to the right.
        var a, c1, c2, b: CGPoint
        var born, span: Double
        var width: Double
    }

    private struct Foliage {
        var stem: Int
        /// Where along the stem, and when it is born.
        var t, born: Double
        var length: Double
        /// 0 points out along the stem's own heading, otherwise to one side.
        var side: Double
        var lift: Double
        /// How far it can cut itself into slits, 0…1.
        var split: Double
        var tier: Int
        var petiole: Double
    }

    func vine(_ c: GraphicsContext?, _ m: inout Marks) {
        let sx = seed.side, wilt = self.wilt
        func v(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y) }
        let sag = 1 + 0.2 * wilt
        let stems: [Stem] = [
            Stem(a: v(0, 1), c1: v(-2, -52), c2: v(-4 + 8 * wilt, -108), b: v(1 + 24 * wilt, -148 * (1 - 0.16 * wilt)), born: 0.09, span: 0.5, width: 5.4),
            Stem(a: v(5, 1), c1: v(24, -26), c2: v(54, -46 * sag), b: v(82, -64 * sag), born: 0.3, span: 0.46, width: 4.4),
            Stem(a: v(-4, 0), c1: v(-34, -54), c2: v(-76, -46), b: v(-64, 58), born: 0.5, span: 0.4, width: 3.4),
        ]
        let foliage: [Foliage] = [
            Foliage(stem: 0, t: 0.16, born: 0.12, length: 32, side: -1, lift: 0.7, split: 0.3, tier: 1, petiole: 12),
            Foliage(stem: 0, t: 0.38, born: 0.3, length: 46, side: 1, lift: 0.55, split: 0.62, tier: 0, petiole: 14),
            Foliage(stem: 0, t: 0.62, born: 0.42, length: 54, side: -1, lift: 0.5, split: 0.88, tier: 1, petiole: 16),
            Foliage(stem: 0, t: 1, born: 0.56, length: 62, side: 0, lift: 0, split: 1, tier: 2, petiole: 6),
            Foliage(stem: 1, t: 0.52, born: 0.46, length: 46, side: -1, lift: 0.9, split: 0.85, tier: 0, petiole: 12),
            Foliage(stem: 1, t: 1, born: 0.62, length: 52, side: 0, lift: 0, split: 1, tier: 1, petiole: 6),
            Foliage(stem: 2, t: 0.34, born: 0.64, length: 30, side: -1, lift: 0.9, split: 0.55, tier: 2, petiole: 8),
            Foliage(stem: 2, t: 0.62, born: 0.72, length: 32, side: -1, lift: 0.2, split: 0.6, tier: 2, petiole: 8),
            Foliage(stem: 2, t: 0.92, born: 0.8, length: 30, side: 1, lift: 0.5, split: 0.55, tier: 2, petiole: 7),
        ]
        /// How far along its final path a stem has got.
        func reach(_ stem: Stem, _ index: Int) -> Double {
            index == 0
                ? grown([(0.09, 0), (0.12, 0.1), (0.3, 0.38), (0.52, 0.7), (0.76, 0.92), (0.9, 1)])
                : Ink.smooth((p - stem.born) / stem.span)
        }
        let paths = stems.enumerated().map { i, s in Self.cubic(s.a, s.c1, s.c2, s.b, upTo: max(0.001, reach(s, i)), n: 18) }
        let whole = stems.map { Self.cubic($0.a, $0.c1, $0.c2, $0.b, n: 24) }

        // The stems, thinnest and youngest at the back, and the trailing one
        // last: it hangs over the pot.
        func stem(_ i: Int) {
            guard reach(stems[i], i) > 0.02, let c else { return }
            let s = stems[i], w = s.width * (1 - 0.2 * wilt)
            paint(c, stem: Self.ribbon(paths[i], w, w * 0.6), along: paths[i], width: w, tier: i == 0 ? 1 : 0)
        }

        /// One leaf, at its place on its stem: a cut and holed heart on its
        /// stalk, drawn on its own because its holes want an even-odd fill.
        func leaf(_ f: Foliage, _ n: Int) {
            let k = pop(f.born, over: 0.1)
            let r = reach(stems[f.stem], f.stem)
            guard k > 0.02, r >= f.t - 0.001 else { return }
            let path = paths[f.stem]
            let t = f.t / max(0.001, r)
            let anchor = Self.along(path, t)
            let heading = Self.heading(path, t)
            var angle = f.side == 0 ? heading : (f.side > 0 ? -f.lift : -.pi + f.lift)
            // A leaf at the tip carries on the way its stem goes, but not so
            // far over that it faces the ground: tired, it hangs from its stalk.
            if f.side == 0 { angle = angle + (-.pi / 2 - angle) * 0.35 }
            let down = f.side == 0 ? sx : (f.side > 0 ? 1.0 : -1.0)
            angle += down * wilt * 1.25
            let split = f.split * Ink.smooth((p - f.born) / 0.32)
            let length = f.length * 1.12 * k * (1 - 0.14 * wilt) * seed.between(f.stem * 3 + Int(f.t * 9), 0.93, 1.07)
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let start = CGPoint(x: anchor.x + direction.x * f.petiole * k, y: anchor.y + direction.y * f.petiole * k)
            if let c {
                let kind: LeafShape.Kind = split < 0.22 ? .monstera0 : split < 0.5 ? .monstera1 : split < 0.8 ? .monstera2 : .monstera3
                let shape = LeafShape.of(kind, bend: down * (0.3 + 0.5 * wilt))
                var batch = LeafBatch()
                batch.add(shape, base: start, angle: angle, length: length, light: L, bright: bright(angle, luck: luck(n + 5), tier: f.tier), glossy: true, vary: plan.variegation)
                let stalk = Self.quad(anchor, CGPoint(x: (anchor.x + start.x) / 2, y: min(anchor.y, start.y) - 3), start, n: 4)
                batch.stalks.addPath(Self.ribbon(stalk, 2.8, 2.1))
                batch.flush(c, inks[f.tier], holes: shape.holes)
            }
            let end = CGPoint(x: start.x + direction.x * length * 0.9, y: start.y + direction.y * length * 0.9)
            m.note(end)
            m.note(CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2), reach: length * 0.3, hang: false)
        }

        // Back to front: the second stem, the main stem's low leaves, the pole
        // and its roots, the main stem, then its leaves in front and the leaf
        // unrolling at its tip.
        stem(1)
        for (n, f) in foliage.enumerated() where f.stem == 1 { leaf(f, n) }
        for (n, f) in foliage.enumerated() where f.stem == 0 && f.tier == 0 { leaf(f, n) }
        let pole = since(0.3, over: 0.12)
        if pole > 0.02, let c {
            mossPole(c, x: -3.5 * sx, height: 126 * Ink.back(pole))
            roots(c, stemPath: paths[0], reach: reach(stems[0], 0), pole: -3.5 * sx)
        }
        stem(0)
        for (n, f) in foliage.enumerated() where f.stem == 0 && f.tier > 0 { leaf(f, n) }
        if let c, p > 0.1, p < 0.6 {
            let end = paths[0][paths[0].count - 1], before = paths[0][paths[0].count - 3]
            let heading = atan2(end.y - before.y, end.x - before.x)
            let unroll = pop(0.12, over: 0.06) * (1 - Ink.smooth((p - 0.46) / 0.14))
            var furl = LeafBatch()
            furl.add(.of(.ovate, bend: -0.2 * sx), base: end, angle: heading + wilt * sx, length: 22 * unroll, light: L, bright: 0.8, glossy: true, shadowed: false)
            furl.flush(c, fresh, casting: false)
            m.note(CGPoint(x: end.x + cos(heading) * 20 * unroll, y: end.y + sin(heading) * 20 * unroll), reach: 4, hang: false)
        }
        // In front of the pot's rim: the trailing stem and its leaves.
        stem(2)
        for (n, f) in foliage.enumerated() where f.stem == 2 { leaf(f, n) }
        m.note(whole[0][whole[0].count - 1], reach: 3, hang: false)
    }

    /// A pole of sphagnum moss the main stem climbs, tied with twine: a lit and a
    /// shaded side, clumps of darker and lighter moss, two ties, a mound of
    /// earth at its foot and a tuft of moss at its top. Seven fills.
    private func mossPole(_ c: GraphicsContext, x: Double, height h: Double) {
        guard h > 4 else { return }
        let w = 17.0
        let side = L.x >= 0 ? 1.0 : -1.0
        let body = Path(roundedRect: CGRect(x: x - w / 2, y: -h, width: w, height: h + 2), cornerSize: CGSize(width: w / 2, height: w * 0.45))
        let lit = ramp[3].mix(RGB(0xC2B068), 0.6).mix(glow, 0.1 * (1 - night)), mid = ramp[2].mix(RGB(0x8A7440), 0.42)
        let shade = ramp[0].mix(RGB(0x3A3220), 0.3)
        c.fill(body, with: .linearGradient(Gradient(colors: [lit.color(), mid.color(), shade.color()]),
                                           startPoint: CGPoint(x: x + side * w / 2, y: -h / 2), endPoint: CGPoint(x: x - side * w / 2, y: -h / 2)))
        var moss = c
        moss.translateBy(x: x, y: 0)
        moss.scaleBy(x: w / 2, y: h)
        moss.fill(MossArt.dark, with: .color(ramp[1].mix(shade, 0.3).color(0.8)))
        moss.fill(MossArt.light, with: .color(ramp[4].mix(lit, 0.4).mix(glow, 0.1 * (1 - night)).color(0.6)))
        // A line of light down the sun's edge.
        var edge = Path()
        edge.lens(from: CGPoint(x: x + side * w * 0.36, y: -2), to: CGPoint(x: x + side * w * 0.36, y: -h + w * 0.4), width: 0.9)
        c.fill(edge, with: .color(rimTone.color(0.2 + 0.25 * dusk + 0.2 * moon)))
        // Twine: two ties, each with its own little shadow.
        let twine = RGB.night(38, 38, 62, day: day, dim: 0.85)
        var ties = Path(), tieShade = Path()
        for y in [30.0, 74.0] where y < h - 8 {
            ties.addRoundedRect(in: CGRect(x: x - w / 2 - 0.4, y: -y - 1.1, width: w + 0.8, height: 2.2), cornerSize: CGSize(width: 1, height: 1))
            tieShade.addRect(CGRect(x: x - w / 2, y: -y + 1.2, width: w, height: 1.6))
        }
        c.fill(tieShade, with: .color(shade.mix(RGB(0x000000), 0.3).color(0.5)))
        c.fill(ties, with: .color(twine.color()))
        // A tuft of moss at the top, and the earth heaped round the foot.
        var tuft = Path()
        for (i, dx) in [-4.0, -1.5, 1.5, 4.0].enumerated() {
            tuft.leaf(x + dx, -h + 2, Double(dx) * 0.08, -1, 4 + Double(i % 2) * 1.6, 1.1, 0.2)
        }
        c.fill(tuft, with: .color(ramp[3].mix(lit, 0.4).color(0.9)))
        let earth = RGB.night(28, 34, 24, day: day, dim: 0.9)
        c.ellipse(x, 0.6, 11, 3.2, .color(earth.color()))
        c.ellipse(x - 1.4, -0.4, 8, 2.2, .color(RGB.night(30, 34, 36, day: day, dim: 0.9).color()))
    }

    /// Aerial roots: stiff brown cords out of the main stem's nodes that run
    /// down the pole, one hanging free, each with a green growing tip.
    private func roots(_ c: GraphicsContext, stemPath: [CGPoint], reach: Double, pole: Double) {
        let sx = seed.side
        let specs: [(t: Double, born: Double, dx: Double, drop: Double)] = [(0.2, 0.34, 6, 40), (0.34, 0.44, -9, 54), (0.5, 0.54, 15, 46)]
        var cords = Path(), shine = Path(), tips = Path()
        for spec in specs {
            let grow = Ink.smooth((p - spec.born) / 0.2)
            guard grow > 0.03, reach >= spec.t else { continue }
            let a = Self.along(stemPath, spec.t / max(0.001, reach))
            let dx = spec.dx * sx
            let end = CGPoint(x: pole + dx * 0.6, y: min(-5, a.y + spec.drop))
            let c1 = CGPoint(x: a.x + dx * 0.9, y: a.y + spec.drop * 0.25), c2 = CGPoint(x: end.x + dx * 0.3, y: end.y - spec.drop * 0.35)
            let line = Self.cubic(a, c1, c2, end, upTo: grow, n: 8)
            cords.addPath(Self.ribbon(line, 3.0, 1.2))
            let lit = line.map { CGPoint(x: $0.x + (L.x >= 0 ? -0.5 : 0.5), y: $0.y) }
            shine.addPath(Self.ribbon(lit, 1.1, 0.5))
            if let tip = line.last, grow > 0.5 { tips.addEllipse(in: CGRect(x: tip.x - 1.1, y: tip.y - 1, width: 2.2, height: 2.6)) }
        }
        c.fill(cords, with: .color(RGB.night(26, 42, 40, day: day, dim: 0.85).color()))
        c.fill(shine, with: .color(RGB.night(28, 44, 58, day: day, dim: 0.85).mix(rimTone, 0.15).color(0.7)))
        c.fill(tips, with: .color(ramp[4].mix(RGB(0xDDE8A0), 0.4).color(0.9)))
    }
}
