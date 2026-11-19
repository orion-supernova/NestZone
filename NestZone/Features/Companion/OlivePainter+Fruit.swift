import SwiftUI

// MARK: - The olives

extension OlivePainter {
    typealias Skin = PomegranatePainter.Look.Skin

    /// What an olive goes through: green, a yellow-green, a rose-violet and at
    /// last a purple that is nearly black. A cluster is never all one colour,
    /// because its olives were set a few days apart.
    /// From the tree's colourway (`TreeColours.olive`).
    private static func stops(_ colourway: Int) -> [(at: Double, skin: Skin)] {
        TreeColours.olive(colourway).stops.map { ($0.at, Skin(hi: RGB($0.skin.hi), mid: RGB($0.skin.mid), shade: RGB($0.skin.shade))) }
    }

    /// One olive as it hangs now.
    struct Drupe {
        var index: Int
        var x, y, r, ripe, tilt: Double
        /// Sunk in the leaves, so the middle ones cover it too.
        var deep: Bool
        /// Where the cluster's stalks meet, up in the leaves.
        var anchor: CGPoint
        var skin: Skin
    }

    private func skin(_ ripe: Double) -> Skin {
        let M = core.M, day = core.day
        let stops = Self.stops(core.canopy.colourway)
        var a = stops[0], b = stops[1]
        for k in 0..<(stops.count - 1) where ripe >= stops[k].at {
            (a, b) = (stops[k], stops[k + 1])
        }
        let t = Ink.smooth((ripe - a.at) / (b.at - a.at))
        let s = Skin(hi: a.skin.hi.mix(b.skin.hi, t), mid: a.skin.mid.mix(b.skin.mid, t), shade: a.skin.shade.mix(b.skin.shade, t))
        let k = (0.62 + 0.38 * M.m) * (1 - 0.3 * M.doze), dull = RGB(0x6E6A52)
        func tone(_ c: RGB, _ dim: Double) -> RGB {
            let c = c.mix(dull, 0.3 * M.thirst), (h, sat, l) = c.hsl
            return RGB.night(h, sat * k, l, day: day, dim: dim)
        }
        return Skin(hi: tone(s.hi, 0.8), mid: tone(s.mid, 0.7), shade: tone(s.shade, 0.6))
    }

    /// The olives of one clump: a little cluster of two or three, hung close
    /// together under the leaves from stalks that meet in one place.
    func hangings(_ i: Int, _ q: Canopy.Pose.Spot) -> [Drupe] {
        let p = core.p, M = core.M
        guard p > 0.8 else { return [] }
        let all = core.art.crown.fruitsOf[i]
        guard !all.isEmpty else { return [] }
        var mean = 0.0
        for index in all { mean += q.x + canopy.fruits[index].dx * q.R * 0.66 }
        let anchor = CGPoint(x: mean / Double(all.count), y: q.y + q.R * 0.02)
        var list: [Drupe] = []
        for index in all {
            let f = canopy.fruits[index]
            let set = 0.82 + f.born * 0.06
            let grow = Ink.back((p - set) / 0.1)
            guard grow > 0.02 else { continue }
            let ripe = Ink.clamp((p - (0.82 + f.born * 0.1)) / 0.18) * (0.85 + 0.15 * M.m)
            let luck = Double(Int(abs(f.tilt * 1000)) % 7) / 6
            let deep = index % 3 == 1
            var r = f.size * 1.3 * (0.4 + 0.6 * min(1, grow)) * (1 - 0.1 * M.thirst - 0.08 * M.doze) * (0.9 + 0.2 * luck)
            if deep { r *= 0.92 }
            let x = q.x + f.dx * q.R * 0.66
            let y = q.y + q.R * ((deep ? 0.12 : 0.24) + 2.4 * f.hang) + r * 0.3
            list.append(Drupe(index: index, x: x, y: y, r: r, ripe: ripe, tilt: f.tilt * 0.8 + (x < anchor.x ? -0.12 : 0.12) * (1 + M.wilt),
                              deep: deep, anchor: anchor, skin: skin(ripe)))
        }
        return list
    }

    /// A few olives: the stalks that hold them (fills, not strokes), each
    /// olive lit from the light with a dull bloom on its lit side, and a dot
    /// of light.
    func cluster(_ tree: GraphicsContext, _ olives: [Drupe]) {
        guard !olives.isEmpty else { return }
        let L = core.L, night = core.night, t = core.tones
        var stalks = Path(), glints = Path(), blooms = Path(), tips = Path()
        for o in olives {
            let ang = Double.pi / 2 + o.tilt, ca = cos(ang), sa = sin(ang), r = o.r
            let top = CGPoint(x: o.x - ca * r * 0.95, y: o.y - sa * r * 0.95)
            stalks.twig(o.anchor, top, r * 0.07, r * 0.06)
        }
        tree.fill(stalks, with: .color(t.ramp[2].mix(t.barkDark, 0.45).color(0.95)))
        for o in olives {
            let ang = Double.pi / 2 + o.tilt, ca = cos(ang), sa = sin(ang), r = o.r, sk = o.skin
            var body = Path()
            body.oval(o.x, o.y, r * 0.95, r * 0.7, ang)
            tree.fill(body, with: .radialGradient(
                Gradient(stops: [.init(color: sk.hi.mix(sk.mid, 0.35).color(), location: 0), .init(color: sk.mid.color(), location: 0.45),
                                 .init(color: sk.shade.color(), location: 1)]),
                center: CGPoint(x: o.x + L.x * r * 0.4, y: o.y + L.y * r * 0.4), startRadius: r * 0.04, endRadius: r * 1.4))
            tips.oval(o.x + ca * r * 0.93, o.y + sa * r * 0.93, r * 0.1, r * 0.08, ang)
            blooms.oval(o.x + L.x * r * 0.32, o.y + L.y * r * 0.3, r * 0.34, r * 0.14, atan2(L.y, L.x) + .pi / 2)
            glints.oval(o.x + L.x * r * 0.5, o.y + L.y * r * 0.48, r * 0.1, r * 0.1)
        }
        // The waxy bloom on a ripe olive is pale and dull; the light is a dot.
        let bloom = olives[0].skin.hi.mix(RGB(0xCFD6E6), 0.4)
        tree.fill(blooms, with: .color(bloom.color(0.3)))
        tree.fill(tips, with: .color(t.fc.color(0.9)))
        tree.fill(glints, with: .color(RGB(0xFFF8F0).color(0.6 * (1 - 0.4 * night))))
    }
}
