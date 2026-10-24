import SwiftUI

// The vine: stems that climb, arch and trail, each with its leaves at fixed
// places along it and a young leaf unrolling at its tip. A monstera is this
// rule. Its leaves are whole when they are young and cut themselves into lobes
// as they age (`split`), which is what makes the growth readable: the first
// leaf is a heart, the last is a hand. A pothos or an ivy is the same stems
// with `heart` leaves that stay whole.
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
        /// How far it can cut itself into lobes, 0…1.
        var split: Double
        var tier: Int
        var petiole: Double
    }

    func vine(_ c: GraphicsContext?, _ m: inout Marks) {
        let sx = seed.side, wilt = self.wilt
        func v(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y) }
        let sag = 1 + 0.2 * wilt
        let stems: [Stem] = [
            Stem(a: v(0, 1), c1: v(-4, -52), c2: v(-14 + 12 * wilt, -108), b: v(2 + 26 * wilt, -148 * (1 - 0.16 * wilt)), born: 0.09, span: 0.5, width: 5.4),
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

        /// One leaf, at its place on its stem.
        func leaf(_ f: Foliage) {
            let k = pop(f.born, over: 0.1)
            guard k > 0.02, reach(stems[f.stem], f.stem) >= f.t - 0.001 else { return }
            let path = paths[f.stem]
            let anchor = Self.along(path, f.t / max(0.001, reach(stems[f.stem], f.stem)))
            let ahead = Self.along(path, min(1, f.t / max(0.001, reach(stems[f.stem], f.stem)) + 0.04))
            let behind = Self.along(path, max(0, f.t / max(0.001, reach(stems[f.stem], f.stem)) - 0.04))
            let heading = atan2(ahead.y - behind.y, ahead.x - behind.x)
            var angle = f.side == 0 ? heading : (f.side > 0 ? -f.lift : -.pi + f.lift)
            // A leaf at the tip carries on the way its stem goes, but not so
            // far over that it faces the ground: tired, it hangs from its stalk.
            if f.side == 0 { angle = angle + (-.pi / 2 - angle) * 0.35 }
            let down = f.side == 0 ? sx : (f.side > 0 ? 1.0 : -1.0)
            angle += down * wilt * 1.25
            let split = f.split * Ink.smooth((p - f.born) / 0.32)
            let length = f.length * 1.2 * k * (1 - 0.14 * wilt) * seed.between(f.stem * 3 + Int(f.t * 9), 0.93, 1.07)
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let start = CGPoint(x: anchor.x + direction.x * f.petiole * k, y: anchor.y + direction.y * f.petiole * k)
            let blade = splitLeaf(at: start, angle: angle, length: length, split: split)
            if let c {
                let stalk = Self.quad(anchor, CGPoint(x: (anchor.x + start.x) / 2, y: min(anchor.y, start.y) - 3), start, n: 4)
                c.fill(Self.ribbon(stalk, 2.6, 2), with: .color(ramp[1].color()))
                paint(c, leaf: blade, tier: f.tier)
            }
            m.note(blade.tip)
            m.note(CGPoint(x: (start.x + blade.tip.x) / 2, y: (start.y + blade.tip.y) / 2), reach: length * 0.3, hang: false)
        }

        // Back to front: the second stem, the main stem's low leaves, the main
        // stem, then its leaves in front and the leaf unrolling at its tip.
        stem(1)
        for f in foliage where f.stem == 1 { leaf(f) }
        for f in foliage where f.stem == 0 && f.tier == 0 { leaf(f) }
        stem(0)
        for f in foliage where f.stem == 0 && f.tier > 0 { leaf(f) }
        if let c, p > 0.1, p < 0.6 {
            let end = paths[0][paths[0].count - 1], before = paths[0][paths[0].count - 3]
            let heading = atan2(end.y - before.y, end.x - before.x)
            let unroll = pop(0.12, over: 0.06) * (1 - Ink.smooth((p - 0.46) / 0.14))
            let furl = Self.blade(at: end, angle: heading + wilt * sx, length: 20 * unroll, halfWidth: 3.6 * unroll, widest: 0.4, bend: -0.2 * sx)
            paint(c, leaf: furl, tier: 2, shadow: false)
            c.fill(furl.outline, with: .color(ramp[4].color(0.35)))
            m.note(furl.tip, reach: 4, hang: false)
        }
        // In front of the pot's rim: the trailing stem and its leaves.
        stem(2)
        for f in foliage where f.stem == 2 { leaf(f) }
        m.note(whole[0][whole[0].count - 1], reach: 3, hang: false)
    }

    /// A monstera leaf: lobes radiating from the midrib, fat and overlapping
    /// while it is young, a heart; slim with the sky showing between them once
    /// it has split. All the lobes are one path, the lit copy and the ribs
    /// are the same shapes again, so it is cheap however cut it is.
    private func splitLeaf(at base: CGPoint, angle a: Double, length L: Double, split s: Double) -> (outline: Path, rib: Path, tip: CGPoint) {
        let ca = cos(a), sa = sin(a)
        func loc(_ u: Double, _ v: Double) -> CGPoint { CGPoint(x: base.x + ca * u - sa * v, y: base.y + sa * u + ca * v) }
        var outline = Path(), ribs = Path()
        // Rows of lobes down the midrib, nearest the stalk first. The first
        // pair point back, which makes the heart's rounded base.
        let rows: [(u: Double, psi: Double, len: Double)] = [
            (0.1, 1.85, 0.42), (0.27, 1.38, 0.6), (0.45, 1.18, 0.58), (0.63, 0.98, 0.42),
        ]
        for side in [-1.0, 1] {
            for row in rows {
                let len = L * row.len * Ink.lerp(0.9, 1.04, s)
                let hw = len * Ink.lerp(0.85, 0.25, pow(s, 1.3))
                let ux = cos(row.psi), vy = side * sin(row.psi)
                let dx = ca * ux - sa * vy, dy = sa * ux + ca * vy
                let origin = loc(row.u * L, 0)
                outline.leaf(origin.x, origin.y, dx, dy, len, hw, 0.55)
                ribs.move(to: origin)
                ribs.addLine(to: CGPoint(x: origin.x + dx * len * 0.78, y: origin.y + dy * len * 0.78))
            }
        }
        // The tip lobe, down the middle.
        let start = loc(0.3 * L, 0)
        outline.leaf(start.x, start.y, ca, sa, L * 0.7, L * Ink.lerp(0.34, 0.2, s), 0.5)
        ribs.move(to: base)
        let tip = loc(L * 0.98, 0)
        ribs.addLine(to: tip)
        // A young leaf is one fat heart: a lobe on each side of the stalk and a point.
        return (outline, ribs, loc(L, 0))
    }
}
