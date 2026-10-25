import SwiftUI

// MARK: - The blossom

extension CherryPainter {
    /// One clump's blossom, over its leaves: clusters of five-petal flowers in
    /// four classes by the light (a dusky pink in the shade, a pink, a pale pink
    /// and a white-pink on the sun's side), the red eye of each, the notch in each
    /// petal and the stamens of the sunlit ones. Before they open the same places
    /// are small deep-pink buds. Fades in with the tree's bloom.
    func blossoms(_ tree: GraphicsContext, _ i: Int, _ q: Canopy.Pose.Spot) {
        guard let bloom, core.p > 0.5 else { return }
        let open = self.open, buds = Ink.smooth((core.p - 0.52) / 0.1) * (1 - open)
        guard open > 0.02 || buds > 0.02 else { return }
        let art = bloom.clump(i)
        guard art.count > 0 else { return }
        let t = core.tones, moon = core.light.moon, L = core.L
        let cool = RGB(0xB8A8E0)
        func pink(_ c: RGB) -> RGB { c.mix(cool, 0.25 * moon).mix(RGB(0x2A2150), 0.32 * moon) }
        var g = tree
        g.translateBy(x: q.x, y: q.y)
        g.scaleBy(x: q.R, y: q.R)
        if buds > 0.02 {
            g.fill(art.buds, with: .color(pink(t.bc.mix(t.ba, 0.25)).color(buds)))
        }
        guard open > 0.02 else { return }
        // A hair of shade on the far side of every flower parts it from the next,
        // so a cluster reads as flowers and not a blob.
        var shade = g
        shade.translateBy(x: -L.x * 0.016, y: -L.y * 0.016)
        if !art.all.isEmpty { shade.fill(art.all, with: .color(pink(t.ba.mix(t.bc, 0.55)).color(open * 0.8))) }
        if !art.d.isEmpty { g.fill(art.d, with: .color(pink(t.ba.mix(t.bc, 0.34)).color(open))) }
        if !art.m.isEmpty { g.fill(art.m, with: .color(pink(t.ba.mix(t.bc, 0.12)).color(open))) }
        if !art.l.isEmpty { g.fill(art.l, with: .color(pink(t.ba).color(open))) }
        if !art.s.isEmpty { g.fill(art.s, with: .color(pink(t.bb).color(open))) }
        if !art.spots.isEmpty { g.fill(art.spots, with: .color(pink(t.bc).color(0.55 * open))) }
        if !art.hearts.isEmpty && !art.s.isEmpty { g.fill(art.hearts, with: .color(pink(t.bc.mix(RGB(0x8A1F3A), 0.3)).color(open))) }
        if !art.fine.isEmpty { g.fill(art.fine, with: .color(t.anther.color(0.9 * open))) }
    }
}

// MARK: - The cherries

extension CherryPainter {
    typealias Skin = PomegranatePainter.Look.Skin

    /// Two cherries on their long stalks, from one spur.
    struct Pair {
        var index: Int
        var spur: CGPoint
        var ripe, r, length, sway, luck: Double
        var skin: Skin
    }

    /// Yellow-green, then orange-red, then a deep glossy red: a pair is never both
    /// the same colour at once, and the season runs from the first to the last.
    /// From the tree's colourway (`TreeColours.cherry`).
    private static func stops(_ colourway: Int) -> [(at: Double, skin: Skin)] {
        TreeColours.cherry(colourway).map { ($0.at, Skin(hi: RGB($0.skin.hi), mid: RGB($0.skin.mid), shade: RGB($0.skin.shade))) }
    }

    private func skin(_ ripe: Double) -> Skin {
        let M = core.M, day = core.day
        let stops = Self.stops(core.canopy.colourway)
        var a = stops[0], b = stops[1]
        for k in 0..<(stops.count - 1) where ripe >= stops[k].at { (a, b) = (stops[k], stops[k + 1]) }
        let t = Ink.smooth((ripe - a.at) / (b.at - a.at))
        let s = Skin(hi: a.skin.hi.mix(b.skin.hi, t), mid: a.skin.mid.mix(b.skin.mid, t), shade: a.skin.shade.mix(b.skin.shade, t))
        let k = (0.62 + 0.38 * M.m) * (1 - 0.3 * M.doze), dull = RGB(0x7A5A52)
        func tone(_ c: RGB, _ dim: Double) -> RGB {
            let c = c.mix(dull, 0.3 * M.thirst), (h, sat, l) = c.hsl
            return RGB.night(h, sat * k, l, day: day, dim: dim)
        }
        return Skin(hi: tone(s.hi, 0.8), mid: tone(s.mid, 0.7), shade: tone(s.shade, 0.6))
    }

    /// The pairs hanging from one clump: from about half the clump's blossom
    /// sites, late in the season, on stalks as long as the clump is deep.
    func cherries(_ i: Int, _ q: Canopy.Pose.Spot) -> [Pair] {
        let p = core.p, M = core.M
        guard p > 0.82 else { return [] }
        var list: [Pair] = []
        for index in blossomsOf[i] {
            let b = canopy.blossoms[index]
            let h = Double(Int(abs(b.rot * 1000)) % 10) / 10
            guard h < 0.55 else { continue }
            let set = 0.84 + b.born * 0.08
            let grow = Ink.back((p - set) / 0.1)
            guard grow > 0.02 else { continue }
            let ripe = Ink.smooth((p - (0.86 + b.born * 0.1)) / 0.1) * (0.85 + 0.15 * M.m)
            let luck = Double(Int(abs(b.tilt * 1000)) % 7) / 6
            let r = 3.7 * (0.4 + 0.6 * min(1, grow)) * (0.9 + 0.2 * luck) * (1 - 0.1 * M.thirst - 0.08 * M.doze)
            let spur = CGPoint(x: q.x + b.dx * q.R * 0.72, y: q.y + q.R * (0.2 + 0.18 * luck))
            list.append(Pair(index: index, spur: spur, ripe: ripe, r: r, length: q.R * (0.5 + 0.22 * luck), sway: b.tilt * 0.35 + (b.dx < 0 ? -1.0 : 1) * 0.08 * (1 + M.wilt),
                             luck: luck, skin: skin(ripe)))
        }
        return list
    }

    /// Cherries in pairs: two long thin stalks that part from one spur, a
    /// round glossy fruit at the end of each with a dimple where the stalk goes
    /// in, and a dot of light.
    func cherries(_ tree: GraphicsContext, _ pairs: [Pair]) {
        let L = core.L, night = core.night, t = core.tones
        var stalks = Path(), dimples = Path(), glints = Path()
        var bodies: [(CGPoint, Double, Skin)] = []
        for pr in pairs {
            for side in [-1.0, 1] {
                let a = Double.pi / 2 + pr.sway + side * 0.17
                let end = CGPoint(x: pr.spur.x + cos(a) * pr.length, y: pr.spur.y + sin(a) * pr.length)
                let c = CGPoint(x: end.x + cos(a) * pr.r * 0.85, y: end.y + sin(a) * pr.r * 0.85)
                // The stalk bows a hair: two bits, the second a little off the first.
                let mid = CGPoint(x: (pr.spur.x + end.x) / 2 + side * pr.r * 0.12, y: (pr.spur.y + end.y) / 2)
                stalks.twig(pr.spur, mid, 0.34, 0.3)
                stalks.twig(mid, end, 0.3, 0.26)
                bodies.append((c, pr.r, pr.skin))
                dimples.oval(end.x, end.y, pr.r * 0.2, pr.r * 0.12, a + .pi / 2)
                glints.oval(c.x + L.x * pr.r * 0.45, c.y + L.y * pr.r * 0.45, pr.r * 0.2, pr.r * 0.09, atan2(L.y, L.x) + .pi / 2)
                glints.oval(c.x + L.x * pr.r * 0.56, c.y + L.y * pr.r * 0.56, pr.r * 0.06, pr.r * 0.06)
            }
        }
        tree.fill(stalks, with: .color(t.ramp[3].mix(t.barkHi, 0.45).color(0.95)))
        for (c, r, sk) in bodies {
            var body = Path()
            body.oval(c.x, c.y, r, r * 0.95)
            tree.fill(body, with: .radialGradient(
                Gradient(stops: [.init(color: sk.hi.mix(sk.mid, 0.3).color(), location: 0), .init(color: sk.mid.color(), location: 0.42),
                                 .init(color: sk.shade.color(), location: 1)]),
                center: CGPoint(x: c.x + L.x * r * 0.4, y: c.y + L.y * r * 0.4), startRadius: r * 0.04, endRadius: r * 1.5))
        }
        tree.fill(dimples, with: .color((pairs.first?.skin.shade ?? RGB(0x5A0A1A)).color(0.7)))
        tree.fill(glints, with: .color(RGB(0xFFF4F0).color(0.65 * (1 - 0.4 * night))))
    }
}
