import SwiftUI

// MARK: - The fruit

extension LemonPainter {
    typealias Skin = PomegranatePainter.Look.Skin

    /// Green, then a pale yellow-green, then the three ways a lemon ripens: a
    /// clear yellow, a greener one and a golden one. A fruit goes through them
    /// in turn, so a tree in the middle of the season has all of them.
    private static let green = Skin(hi: RGB(0xE4EEA6), mid: RGB(0x9CBF4A), shade: RGB(0x4A7A2E))
    private static let pale = Skin(hi: RGB(0xF4F4A8), mid: RGB(0xD5D545), shade: RGB(0x86982A))
    private static let ripe = [Skin(hi: RGB(0xFFF7B4), mid: RGB(0xF7D234), shade: RGB(0xC48A12)),
                               Skin(hi: RGB(0xF6F5A0), mid: RGB(0xE6DA3A), shade: RGB(0x9A9A1C)),
                               Skin(hi: RGB(0xFFEFA0), mid: RGB(0xF2BE2A), shade: RGB(0xB97A10))]

    /// One lemon as it sits now: where, how big, how ripe, and how it leans.
    struct Hang {
        var f: Canopy.Fruit
        var index: Int
        var x, y, r, ripe, tilt, side: Double
        /// Sunk in the leaves, so the middle ones cover it too.
        var deep: Bool
        /// Cut in half.
        var hero: Bool
        var skin: Skin
    }

    private func skin(_ ripe: Double, _ variety: Int) -> Skin {
        let M = core.M, day = core.day
        let a: Skin, b: Skin
        if ripe < 0.5 { (a, b) = (Self.green, Self.pale) } else { (a, b) = (Self.pale, Self.ripe[variety]) }
        let t = Ink.smooth(ripe < 0.5 ? ripe * 2 : (ripe - 0.5) * 2)
        let s = Skin(hi: a.hi.mix(b.hi, t), mid: a.mid.mix(b.mid, t), shade: a.shade.mix(b.shade, t))
        // A thirsty or sleepy tree's fruit is duller, and a bright one's richer.
        let k = (0.62 + 0.38 * M.m) * (1 - 0.3 * M.doze), dull = RGB(0x8A7A4A)
        func tone(_ c: RGB, _ dim: Double) -> RGB {
            let c = c.mix(dull, 0.3 * M.thirst), (h, sat, l) = c.hsl
            return RGB.night(h, sat * k, l, day: day, dim: dim)
        }
        return Skin(hi: tone(s.hi, 0.8), mid: tone(s.mid, 0.7), shade: tone(s.shade, 0.6))
    }

    /// The lemons that live in one clump, as they sit now. Each is up in the
    /// clump's own leaves, a little out from its middle and low in it, so the
    /// bottom of the fruit shows beneath the sprigs and the top is under them.
    func hangings(_ i: Int, _ q: Canopy.Pose.Spot) -> [Hang] {
        let p = core.p, M = core.M
        guard p > 0.8 else { return [] }
        var list: [Hang] = []
        for index in core.art.crown.fruitsOf[i] {
            let f = canopy.fruits[index]
            // Set from the end of the bloom: a tiny green fruit, swelling, ripening.
            let set = 0.84 + f.born * 0.07
            let grow = Ink.back((p - set) / 0.1)
            guard grow > 0.02 else { continue }
            let hero = split == index && p > 0.94
            let ripe = hero ? 1 : Ink.smooth((p - (0.84 + f.born * 0.08)) / 0.07) * (0.8 + 0.2 * M.m)
            let luck = Double(Int(abs(f.tilt * 1000)) % 7) / 6
            let deep = !hero && (index % 5 == 1)
            var r = f.size * 1.12 * (0.4 + 0.6 * min(1, grow)) * (1 - 0.1 * M.thirst - 0.08 * M.doze) * (0.86 + 0.28 * luck)
            if deep { r *= 0.92 }
            let side = f.dx < 0 ? -1.0 : 1
            let x = q.x + f.dx * q.R * 0.66 + (hero ? side * q.R * 0.1 : 0)
            let y = q.y + q.R * ((deep ? 0.06 : 0.18) + (deep ? 0.55 : 1.05) * f.hang + (hero ? 0.1 : 0)) + r * 0.2
            // The weight of the fruit leans it out; a thirsty tree's lean more.
            let tilt = f.tilt * 0.9 + side * (0.12 + 0.2 * M.wilt)
            list.append(Hang(f: f, index: index, x: x, y: y, r: r, ripe: ripe, tilt: tilt, side: side, deep: deep, hero: hero,
                             skin: skin(ripe, hero ? 0 : [0, 1, 2, 0, 1][Int(abs(f.tilt * 1000)) % 5])))
        }
        return list
    }

    /// Where the dimples of the rind sit on a lemon, in its own frame, along
    /// its length and across it, -1 to 1.
    private static let dimples: [CGPoint] = (0..<15).map { (i: Int) -> CGPoint in
        let t = Double(i) * 2.399963, d = (Double(i) + 0.5).squareRoot() / 15.0.squareRoot() * 0.84
        return CGPoint(x: cos(t) * d, y: sin(t) * d)
    }

    /// The body of a lemon: an oval drawn out to a point at its far end, set
    /// along the axis `ang`. The same path is the nipple and the body, so one
    /// gradient lights both.
    func body(_ x: Double, _ y: Double, _ r: Double, _ ang: Double) -> Path {
        let ca = cos(ang), sa = sin(ang)
        var path = Path()
        path.oval(x, y, r * 1.18, r * 0.86, ang)
        path.oval(x + ca * r * 1.2, y + sa * r * 1.2, r * 0.22, r * 0.15, ang)
        return path
    }

    /// One lemon: the short sturdy stalk it hangs from, the oval body lit from
    /// the light with its nipple, the dimples of its rind, the green button
    /// where it joined the twig, a soft highlight and a bright dot.
    func fruit(_ tree: GraphicsContext, _ h: Hang) {
        let L = core.L, M = core.M, night = core.night, sk = h.skin, t = core.tones
        let r = h.r, x = h.x, y = h.y
        let ang = Double.pi / 2 + h.tilt, ca = cos(ang), sa = sin(ang)

        // The stalk: a short, thick stub of twig from inside the clump, set on
        // the fruit's shoulder.
        let top = CGPoint(x: x - ca * r * 1.14, y: y - sa * r * 1.14)
        let from = CGPoint(x: top.x - h.side * r * 0.35, y: top.y - r * 0.6)
        var stalk = Path()
        stalk.twig(from, top, r * 0.13, r * 0.11)
        tree.fill(stalk, with: .color(t.ramp[2].mix(t.barkDark, 0.35).color(0.95)))

        // The soft glow of a ripe fruit in a bright tree.
        if M.glow > 0.35 {
            let a = (0.05 + 0.08 * M.glow) * h.ripe * (1 + 0.3 * night)
            var disc = Path()
            disc.oval(x, y, r * 2.2, r * 2.2)
            let gc = sk.hi.mix(RGB(255, 250, 235), 0.4 * core.day)
            tree.fill(disc, with: .radialGradient(Gradient(colors: [gc.color(a), gc.color(0)]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.2))
        }

        tree.fill(body(x, y, r, ang), with: .radialGradient(
            Gradient(stops: [.init(color: sk.hi.mix(sk.mid, 0.3).color(), location: 0), .init(color: sk.mid.color(), location: 0.42),
                             .init(color: sk.shade.color(), location: 1)]),
            center: CGPoint(x: x + L.x * r * 0.42, y: y + L.y * r * 0.42), startRadius: r * 0.04, endRadius: r * 1.6))

        // The rind: a scatter of dimples, a little darker than the skin.
        var pits = Path()
        let nx = -sa, ny = ca
        for d in Self.dimples {
            pits.oval(x + ca * d.x * r * 1.1 + nx * d.y * r * 0.8, y + sa * d.x * r * 1.1 + ny * d.y * r * 0.8, r * 0.05, r * 0.035, ang)
        }
        tree.fill(pits, with: .color(sk.shade.color(0.3 + 0.1 * h.ripe)))

        // The button of the calyx at the top, the nipple's dark tip, a soft
        // highlight and a bright dot on the lit side.
        var button = Path(), glints = Path()
        button.oval(top.x + ca * r * 0.1, top.y + sa * r * 0.1, r * 0.2, r * 0.12, ang + .pi / 2)
        glints.oval(x + L.x * r * 0.52, y + L.y * r * 0.5, r * 0.24, r * 0.1, atan2(L.y, L.x) + .pi / 2)
        glints.oval(x + L.x * r * 0.64, y + L.y * r * 0.62, r * 0.055, r * 0.055)
        tree.fill(button, with: .color(t.fc.shifted(-2).color()))
        tree.fill(glints, with: .color(RGB(0xFFF8E4).color(0.6 * (1 - 0.4 * night))))
    }
}
