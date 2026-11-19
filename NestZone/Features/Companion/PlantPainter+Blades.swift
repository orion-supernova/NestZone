import SwiftUI

// The blades: a clump of sword leaves that rise straight out of the soil, each
// widest low down and tapering to a point, banded across with pale chevrons
// and edged in yellow, with two pups at the foot. A snake plant is this rule;
// an aloe or an agave are blades with other numbers.
//
// A blade is one outline from a sampled spine (`profile` says how wide it is
// at each point along it), a lit half, a dark line down its rib, chevrons
// across it and a margin along each edge. Every one of those is merged across
// the blades of a depth tier, so the whole clump is a few fills a tier.
//
// Growth: the seed (a rhizome) to .1, then a blade at a time (.1, .18, .26,
// .36, .44, .54, .62, pups at .72 and .8). A new blade is a narrow spear that
// rises first and then unfurls to its width. A thirsty one lets the blades
// lean out, fold in on themselves and bow at the tip; a dozing one is pale and
// leans a little. It never blooms.
extension PlantPainter {
    private struct Blade {
        var x, height, width, lean, born: Double
        var tier: Int
    }

    /// How wide a blade is at a share `t` of its height, as a share of its
    /// widest: a sheath at the foot, full by a quarter of the way, a long
    /// taper to the point.
    private static func profile(_ t: Double) -> Double {
        let foot = 0.72 + 0.28 * sin(min(1, t / 0.28) * .pi / 2)
        return foot * pow(1 - Ink.smooth((t - 0.3) / 0.7), 0.7)
    }

    func blades(_ c: GraphicsContext?, _ m: inout Marks) {
        let wilt = self.wilt, side = seed.side
        let list = [
            Blade(x: 0, height: 150, width: 18, lean: 0.02, born: 0.1, tier: 2),
            Blade(x: -14, height: 126, width: 16, lean: -0.1, born: 0.18, tier: 1),
            Blade(x: 15, height: 118, width: 16, lean: 0.12, born: 0.26, tier: 1),
            Blade(x: -28, height: 96, width: 15, lean: -0.24, born: 0.36, tier: 0),
            Blade(x: 30, height: 90, width: 15, lean: 0.26, born: 0.44, tier: 0),
            Blade(x: -6, height: 108, width: 15, lean: -0.05, born: 0.54, tier: 2),
            Blade(x: 9, height: 76, width: 13, lean: 0.1, born: 0.62, tier: 2),
            Blade(x: -42, height: 34, width: 9, lean: -0.5, born: 0.72, tier: 2),
            Blade(x: 44, height: 30, width: 8, lean: 0.5, born: 0.8, tier: 2),
        ]
        var tiers = [LeafBatch(), LeafBatch(), LeafBatch()]
        var bands = [Path(), Path(), Path()], margins = [Path(), Path(), Path()], grooves = [Path(), Path(), Path()]
        let litRight = L.x >= 0
        let n = 18

        for (i, b) in list.enumerated() {
            let grow = Ink.smooth((p - b.born) / 0.42)
            guard grow > 0.02 else { continue }
            let h = b.height * (plan.height / 150) * grow * (1 - 0.1 * wilt)
            // A new blade is a spear; it widens as it unfurls.
            let wide = (0.3 + 0.7 * Ink.smooth((p - b.born - 0.06) / 0.32)) * (1 - 0.3 * wilt)
            let lean = b.lean * side
            let dir = lean >= 0 ? 1.0 : -1.0
            let x0 = b.x * side * (plan.reach / 54)
            let tip = CGPoint(x: x0 + lean * h * 0.5 + dir * wilt * 0.4 * h, y: -h * (1 - 0.12 * wilt))
            let wobble = seed.between(i, -3, 3)
            let spine = Self.cubic(CGPoint(x: x0, y: 1), CGPoint(x: x0 + lean * h * 0.08, y: -h * 0.34),
                                   CGPoint(x: x0 + lean * h * 0.34 + wobble, y: -h * 0.7), tip, n: n)
            var left: [CGPoint] = [], right: [CGPoint] = []
            for k in 0...n {
                let before = spine[max(0, k - 1)], after = spine[min(n, k + 1)]
                let a = atan2(after.y - before.y, after.x - before.x)
                let w = Self.profile(Double(k) / Double(n)) * b.width / 2 * wide
                // The left and right of a blade standing up: the normal.
                left.append(CGPoint(x: spine[k].x + sin(a) * w, y: spine[k].y - cos(a) * w))
                right.append(CGPoint(x: spine[k].x - sin(a) * w, y: spine[k].y + cos(a) * w))
            }
            let outline = Self.closed(left + right.reversed())
            let tier = b.tier
            let bri = bright(Self.heading(spine, 0.6), luck: luck(i + 12), tier: tier)
            if c != nil {
                if bri < 0.36 { tiers[tier].shade.addPath(outline) }
                else if bri < 0.68 { tiers[tier].mid.addPath(outline) }
                else { tiers[tier].lit.addPath(outline) }
                tiers[tier].shadow.addPath(outline.offsetBy(dx: 0.8, dy: 1.3))
                // The half that faces the light.
                let edge = litRight ? left : right
                tiers[tier].halves.addPath(Self.closed(edge + spine.reversed()))
                grooves[tier].addPath(Self.ribbon(Array(spine.dropFirst(2).dropLast(3)), 1.2 * wide + 0.3, 0.3))
                // The chevrons: each a band across the blade bowed towards the tip.
                var t = 0.06
                while t < 0.9 {
                    let f = t * Double(n), k = Int(f), u = f - Double(k)
                    func at(_ list: [CGPoint], _ tt: Double) -> CGPoint {
                        let g = tt * Double(n), j = min(n - 1, Int(g)), uu = g - Double(j)
                        return CGPoint(x: Ink.lerp(list[j].x, list[j + 1].x, uu), y: Ink.lerp(list[j].y, list[j + 1].y, uu))
                    }
                    _ = (k, u)
                    let dt = 0.05
                    let l0 = at(left, t), r0 = at(right, t), c0 = at(spine, t + dt * 0.9)
                    let l1 = at(left, t + dt * 0.45), r1 = at(right, t + dt * 0.45), c1 = at(spine, t + dt * 1.4)
                    bands[tier].addLines([l0, c0, r0, r1, c1, l1])
                    bands[tier].closeSubpath()
                    t += 0.075 + 0.01 * Double(i % 3)
                }
                // The yellow margin: a thin strip down each edge.
                for edge in [left, right] {
                    var outer: [CGPoint] = [], inner: [CGPoint] = []
                    for k in 1..<(n - 1) {
                        outer.append(edge[k])
                        inner.append(CGPoint(x: Ink.lerp(spine[k].x, edge[k].x, 0.86), y: Ink.lerp(spine[k].y, edge[k].y, 0.86)))
                    }
                    margins[tier].addPath(Self.closed(outer + inner.reversed()))
                }
            }
            m.note(tip, reach: 2)
            m.note(Self.along(spine, 0.55), reach: b.width * 0.3, hang: tier > 0)
        }

        guard let c else { return }
        let band = ramp[4].mix(ramp[2], 0.4).mix(glow, 0.1 * (1 - night))
        let margin = RGB.tone(plan.spine, day: day, dim: 0.9).mix(ramp[3], 0.15 * (M.thirst + M.doze))
        for tier in 0..<3 {
            tiers[tier].flush(c, inks[tier], casting: tier > 0)
            c.fill(bands[tier], with: .color(band.color(0.34 + 0.06 * Double(tier))))
            c.fill(grooves[tier], with: .color(ramp[0].shifted(-4).color(0.5)))
            c.fill(margins[tier], with: .color(margin.color(0.9 - 0.2 * M.thirst)))
        }
    }

    /// A closed polygon.
    private static func closed(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}
