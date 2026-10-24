import SwiftUI

/// The pomegranate, drawn as itself. It grows from the same seed and the same
/// skeleton as every `Canopy` tree (the limbs, the clumps' places, the fruit
/// and flower places, all in the prototype's order), but where the other trees
/// paint a clump as a cut-paper blob of lobes, this one paints each clump as
/// sprigs of narrow, glossy, lance-shaped leaves, opposite on a twig. The
/// leaves are sorted by light into four classes (the shade, the middle, the lit
/// and the sunstruck), so a crown has dark interior and underside, lit sprigs
/// on the sun's side and dappled patches between. The fruit sits in the leaves
/// on short stalks, overlapped by them, and one is split open. The rules this
/// establishes for every species are in `Docs/Companion/art/RULES.md`.
///
/// Like `CanopyPainter`, this is one still picture drawn only when the state
/// changes: no wind, no clock. The light is the one thing it takes that the
/// others do not: where the sun or moon stands across the scene.
///
/// A clump's leaves are worked out once in the clump's own units and kept
/// (`LeafArt`, in `+Art.swift`), so a redraw while the tree grows is a
/// translate, a scale and a few fills per clump, not a few hundred leaves
/// built again.
struct PomegranatePainter {
    let canopy: Canopy
    /// 0…1, as for any tree: the seed .04, a sprout .16, young .38, growing
    /// .62, budding .8, grown .97.
    var growth: Double
    /// 0…1: 1 bright, .62 content, .3 thirsty, .05 dozing.
    var mood: Double
    /// 1 at noon, 0 at night.
    var day: Double
    /// Where the sun (or at night the moon) stands across the scene: -1 the
    /// far left, 1 the far right. Every highlight, shadow and rim comes from it.
    var light = -0.5

    /// The caller's context sits at the trunk's base on the soil, up negative.
    func draw(_ context: GraphicsContext) {
        let look = Look(self)
        look.ground(context)
        var tree = context
        tree.scaleBy(x: canopy.fit, y: canopy.fit)
        let order = look.order()
        var n = 0
        for tier in 0..<3 {
            while n < order.count && canopy.clumps[order[n]].tier == tier {
                look.clump(tree, order[n])
                n += 1
            }
            if tier == 0 {
                look.wood(tree)
                look.youngSprigs(tree)
            } else {
                if tier == 2 {
                    look.dapple(tree)
                    look.splitFruit(tree)
                }
                look.blossoms(tree, tier)
            }
        }
        look.seedLeaves(tree)
    }
}

// MARK: - One redraw's numbers

extension PomegranatePainter {
    typealias RGB = Canopy.RGB

    /// What a leaf is painted with in one tier: four classes of green (the
    /// shade, the middle, the lit and the sunstruck), and the edge light, the
    /// dark body and the shadow it casts round them.
    struct LeafInk {
        var d, m, l, s: Color
        var mLit, mShade: Color
        var rim, body: Color
        var shadow: Gradient
    }

    struct Look {
        let canopy: Canopy
        let p, day, night: Double
        let M: Canopy.Mood
        let pose: Canopy.Pose
        let tones: Canopy.Tones
        /// Towards the light, a unit vector, y up negative.
        let L: (x: Double, y: Double)
        /// Tier 0, 1, 2, each plain then fresh (bronze new growth).
        let inks: [LeafInk]
        let art: LeafArt
        /// The fruit that is opened, if any: its index among the tree's.
        let split: Int?
        /// The warm (or amber, or cool) of a patch of light on the leaves.
        let glow: RGB
        let dusk: Double

        init(_ painter: PomegranatePainter) {
            canopy = painter.canopy
            p = painter.growth
            day = painter.day
            night = 1 - painter.day
            M = Canopy.Mood(painter.mood)
            pose = Self.splayed(Canopy.Pose(canopy, growth: painter.growth, mood: M), growth: painter.growth)
            tones = Canopy.Tones(canopy.kind, M, day: painter.day, growth: painter.growth)
            split = Self.splitIndex(canopy, pose)
            L = LeafArt.sun(light: painter.light, day: painter.day)
            art = LeafArt.of(canopy, mood: painter.mood, light: painter.light, day: painter.day)

            // Light on the leaf edge: a warm white by day, amber when the sun
            // is low, cool by the moon.
            let dusk = 4 * painter.day * (1 - painter.day)
            self.dusk = dusk
            let moon = Ink.smooth((0.3 - painter.day) / 0.3)
            let rim = RGB(0xFFF3C4).mix(RGB(0xFF9A5C), Ink.clamp(dusk * 1.4)).mix(RGB(0xC4D2FF), moon)
            glow = RGB(0xFFE9A8).mix(RGB(0xFFB070), Ink.clamp(dusk * 1.4)).mix(RGB(0xB8C8FF), moon)
            let bronze = RGB.tone(0xBE5A38, day: painter.day, dim: 0.9)
            let ramp = tones.ramp, thirst = M.thirst, doze = M.doze
            var inks: [LeafInk] = []
            for tier in 0..<3 {
                for fresh in [false, true] {
                    // Where the four classes sit on the ramp, tier by tier: the
                    // back is a step down the ramp from the front.
                    var d, m, l, s: RGB
                    switch tier {
                    case 0:
                        d = ramp[0].mix(ramp[1], 0.6)
                        m = ramp[1].mix(ramp[2], 0.3)
                        l = ramp[1].mix(ramp[2], 0.7)
                        s = ramp[2].mix(ramp[3], 0.1)
                    case 1:
                        d = ramp[1].mix(ramp[2], 0.1)
                        m = ramp[1].mix(ramp[2], 0.7)
                        l = ramp[2].mix(ramp[3], 0.45)
                        s = ramp[2].mix(ramp[3], 0.95)
                    default:
                        d = ramp[1].mix(ramp[2], 0.55)
                        m = ramp[2].mix(ramp[3], 0.55)
                        l = ramp[3].mix(ramp[4], 0.15)
                        s = ramp[3].mix(ramp[4], 0.4)
                    }
                    // The shade leans cool and the light warm, as it does in paint.
                    d = d.mix(RGB(0x143A44), 0.22)
                    if fresh {
                        let k = 0.3 * (1 - 0.5 * thirst)
                        d = d.mix(bronze, k * 0.6)
                        m = m.mix(bronze, k)
                        l = l.mix(bronze, k)
                        s = s.mix(bronze, k)
                    }
                    // By moonlight the lit side is a cool, deep green, not a
                    // pale one; by day the sunstruck leaves take the sun's warmth.
                    d = d.mix(m, 0.3 * moon)
                    l = l.mix(m, 0.75 * moon)
                    s = s.mix(m, 0.6 * moon).mix(glow, 0.16 * (1 - moon) * (0.6 + 0.4 * day))
                    if fresh {
                        // New leaves are a fresh yellow-green with bronze at the tip.
                        m = m.mix(ramp[3], 0.25)
                        l = l.mix(ramp[4], 0.2)
                    }
                    let deep = ramp[0].mix(RGB(0x0B1A1C), 0.4)
                    let edgeA = (0.34 + 0.06 * dusk - 0.16 * moon) * (1 - 0.35 * doze)
                    inks.append(LeafInk(
                        d: d.color(), m: m.color(), l: l.color(), s: s.color(),
                        mLit: m.shifted(2 - 5 * moon, -3).color(), mShade: m.shifted(-5, 6).color(),
                        rim: ramp[4].mix(rim, 0.65).color(min(1, edgeA)),
                        body: ramp[tier].mix(deep, 0.35).color(),
                        shadow: Gradient(colors: [deep.color(0.4 * (1 - 0.3 * doze)), deep.color(0.16), deep.color(0)])
                    ))
                }
            }
            self.inks = inks
        }

        /// The clumps showing, back to front: by tier, and within a tier top
        /// first, so a lower clump covers the one above it.
        func order() -> [Int] {
            var order = pose.clumps.indices.filter { pose.clumps[$0] != nil }
            order.sort { a, b in
                let ta = canopy.clumps[a].tier, tb = canopy.clumps[b].tier
                if ta != tb { return ta < tb }
                let ya = pose.clumps[a]!.y, yb = pose.clumps[b]!.y
                return ya != yb ? ya < yb : a < b
            }
            return order
        }
    }
}

// MARK: - One clump

extension PomegranatePainter.Look {
    /// The disc a clump's shadow is poured into, in the clump's units.
    private static let shadowDisc: Path = {
        var disc = Path()
        disc.oval(0, 0.4, 0.85, 0.85)
        return disc
    }()

    /// One clump, back to front: the shade it casts on what is behind, a dark
    /// body, then the leaves by class, shade first. The fruit that lives in it
    /// goes between the classes, so the lit leaves are over it: the ones sunk
    /// deepest after the shade (and then covered by the middle leaves too),
    /// the rest after the middle.
    func clump(_ tree: GraphicsContext, _ i: Int) {
        guard let q = pose.clumps[i] else { return }
        let c = canopy.clumps[i], tier = c.tier
        // The first tuft up a young stem would hide the bare cane: leave it out.
        if c.tuft && canopy.limbs[c.node].parent < 0 && canopy.limbs[c.node].depth == 0 && p < 0.55 { return }
        let fresh = c.tuft || p - c.birth < 0.05
        let ink = inks[tier * 2 + (fresh ? 1 : 0)]
        let leaves = art.clump(i)
        let fruit = tier > 0 ? hangings(i, q) : []

        var g = tree
        g.translateBy(x: q.x, y: q.y)
        g.scaleBy(x: q.R, y: q.R)
        if leaves.casts {
            g.fill(Self.shadowDisc, with: .radialGradient(ink.shadow, center: CGPoint(x: 0, y: 0.4), startRadius: 0, endRadius: 0.85))
        }
        if !leaves.body.isEmpty { g.fill(leaves.body, with: .color(ink.body)) }
        g.fill(leaves.d, with: .color(ink.d))
        for h in fruit where h.deep { self.fruit(tree, h, q) }
        g.fill(leaves.m, with: tier == 2
               ? .linearGradient(Gradient(colors: [ink.mLit, ink.mShade]), startPoint: CGPoint(x: L.x * 0.9, y: L.y * 0.9), endPoint: CGPoint(x: -L.x * 0.9, y: -L.y * 0.9))
               : .color(ink.m))
        for h in fruit where !h.deep && !h.split { self.fruit(tree, h, q) }
        g.fill(leaves.l, with: .color(ink.l))
        if !leaves.s.isEmpty { g.fill(leaves.s, with: .color(ink.s)) }
        if !leaves.rim.isEmpty { g.fill(leaves.rim, with: .color(ink.rim)) }
        for h in fruit { cover(tree, h, ink) }
    }

    /// The fruit that is cut open, after every clump of the front tier: the
    /// others are nestled in the leaves, but this is the one a person looks at
    /// closely, and no leaf lies across the cut.
    func splitFruit(_ tree: GraphicsContext) {
        guard let index = split, let q = pose.clumps[canopy.fruits[index].clump] else { return }
        for h in hangings(canopy.fruits[index].clump, q) where h.split { fruit(tree, h, q) }
    }

    /// Patches of sun on the front of the crown: a soft pool of light poured
    /// over the sunniest of the front clumps, so the lit leaves under it read
    /// as one patch of light and not as a scatter of pale leaves.
    func dapple(_ tree: GraphicsContext) {
        let alpha = (0.11 * day + 0.1 * dusk + 0.08 * night) * (1 - 0.4 * M.doze) * (1 - 0.5 * M.thirst) * (0.6 + 0.4 * M.glow)
        guard alpha > 0.02, p > 0.85 else { return }
        for (i, off) in art.pools {
            guard let q = pose.clumps[i] else { continue }
            let centre = CGPoint(x: q.x + (L.x * 0.28 + off.x) * q.R, y: q.y + (L.y * 0.3 + off.y) * q.R)
            var pool = Path()
            pool.oval(centre.x, centre.y, q.R * 0.65, q.R * 0.55)
            tree.fill(pool, with: .radialGradient(Gradient(colors: [glow.color(alpha), glow.color(alpha * 0.4), glow.color(0)]),
                                                  center: centre, startRadius: 0, endRadius: q.R * 0.65))
        }
    }
}

// MARK: - Leaf shapes

extension Path {
    /// The point `u` of the way along a leaf and `v` across it, on a midrib
    /// that bends by `bend` of the leaf's length, like a leaf under its own weight.
    private static func lancePoint(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ bend: Double,
                                   _ u: Double, _ v: Double) -> CGPoint {
        let w = v + bend * len * u * u, l = len * u
        return CGPoint(x: x + ca * l - sa * w, y: y + sa * l + ca * w)
    }

    /// A lance leaf, narrow and pointed at both ends, widest a third of the
    /// way out. `half` 0 is the whole leaf, 1 or -1 one side of the midrib.
    /// Wound the same way whole or half, so a union never punches a hole.
    mutating func lance(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ bend: Double, _ half: Double) {
        func P(_ u: Double, _ v: Double) -> CGPoint { Self.lancePoint(x, y, ca, sa, len, bend, u, v) }
        let base = P(0, 0), tip = P(1, 0)
        move(to: base)
        if half >= 0 {
            addQuadCurve(to: tip, control: P(0.42, hw * 2.2))
        } else {
            addQuadCurve(to: tip, control: P(0.5, 0))
        }
        if half == 0 {
            addQuadCurve(to: base, control: P(0.42, -hw * 2.2))
        } else if half > 0 {
            addQuadCurve(to: base, control: P(0.5, 0))
        } else {
            addQuadCurve(to: base, control: P(0.42, -hw * 2.2))
        }
        closeSubpath()
    }

    /// A short bright lens on the lit side of the midrib: a glossy leaf. A fill
    /// and not a stroke, because the simulator's GPU charges dearly for strokes.
    mutating func lanceGloss(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ bend: Double, _ side: Double) {
        move(to: Self.lancePoint(x, y, ca, sa, len, bend, 0.3, side * hw * 0.4))
        addQuadCurve(to: Self.lancePoint(x, y, ca, sa, len, bend, 0.6, side * hw * 0.33),
                     control: Self.lancePoint(x, y, ca, sa, len, bend, 0.45, side * hw * 0.58))
        addQuadCurve(to: Self.lancePoint(x, y, ca, sa, len, bend, 0.3, side * hw * 0.4),
                     control: Self.lancePoint(x, y, ca, sa, len, bend, 0.45, side * hw * 0.3))
        closeSubpath()
    }

    /// The edge of a leaf on one side, base to tip, as a thin sliver of the
    /// leaf itself: where the light grazes it.
    mutating func lanceEdge(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ bend: Double, _ side: Double) {
        move(to: Self.lancePoint(x, y, ca, sa, len, bend, 0, 0))
        addQuadCurve(to: Self.lancePoint(x, y, ca, sa, len, bend, 1, 0),
                     control: Self.lancePoint(x, y, ca, sa, len, bend, 0.42, side * hw * 2.2))
        addQuadCurve(to: Self.lancePoint(x, y, ca, sa, len, bend, 0, 0),
                     control: Self.lancePoint(x, y, ca, sa, len, bend, 0.42, side * hw * 1.7))
        closeSubpath()
    }

    /// A leaf's midrib: a thin lens down its middle.
    mutating func lanceVein(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ bend: Double) {
        move(to: Self.lancePoint(x, y, ca, sa, len, bend, 0.08, 0))
        addQuadCurve(to: Self.lancePoint(x, y, ca, sa, len, bend, 0.82, 0), control: Self.lancePoint(x, y, ca, sa, len, bend, 0.45, hw * 0.34))
        addQuadCurve(to: Self.lancePoint(x, y, ca, sa, len, bend, 0.08, 0), control: Self.lancePoint(x, y, ca, sa, len, bend, 0.45, -hw * 0.14))
        closeSubpath()
    }

    /// A tapered bit of twig from one point to the next, as a thin filled quad.
    mutating func twig(_ a: CGPoint, _ b: CGPoint, _ w0: Double, _ w1: Double) {
        let dx = b.x - a.x, dy = b.y - a.y, d = max(1e-6, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / d, ny = dx / d
        move(to: CGPoint(x: a.x + nx * w0, y: a.y + ny * w0))
        addLine(to: CGPoint(x: b.x + nx * w1, y: b.y + ny * w1))
        addLine(to: CGPoint(x: b.x - nx * w1, y: b.y - ny * w1))
        addLine(to: CGPoint(x: a.x - nx * w0, y: a.y - ny * w0))
        closeSubpath()
    }

    /// A frilled blob, for crinkled petals: an ellipse whose edge ripples,
    /// smoothed through its midpoints. `phase` makes each one different.
    mutating func frill(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ rot: Double, _ phase: Double, _ ripple: Double = 0.13) {
        let n = 14, c = cos(rot), s = sin(rot)
        func pt(_ j: Int) -> CGPoint {
            let t = Double(j) * .pi * 2 / Double(n)
            let w = 1 + ripple * sin(5 * t + phase) + ripple * 0.5 * sin(9 * t + phase * 1.7)
            let u = cos(t) * rx * w, v = sin(t) * ry * w
            return CGPoint(x: cx + c * u - s * v, y: cy + s * u + c * v)
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        move(to: mid(pt(0), pt(1)))
        for j in 1...n { addQuadCurve(to: mid(pt(j), pt(j + 1)), control: pt(j)) }
        closeSubpath()
    }
}
