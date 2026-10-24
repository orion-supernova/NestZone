import SwiftUI

/// The pomegranate, drawn as itself. It grows from the same seed and the same
/// skeleton as every `Canopy` tree (the limbs, the clumps' places, the fruit
/// and flower places, all in the prototype's order), but where the other trees
/// paint a clump as a cut-paper blob of lobes, this one paints each clump as
/// sprigs of narrow, glossy, lance-shaped leaves, opposite on a twig, with a
/// light edge where the sun catches them. Its fruit hang from bending twigs
/// with a calyx crown, ripen from green-blush to red, and one is split open
/// on the grown tree. The rules this establishes for every species are in
/// `Docs/Companion/art/RULES.md`.
///
/// Like `CanopyPainter`, this is one still picture drawn only when the state
/// changes: no wind, no clock. The light is the one thing it takes that the
/// others do not: where the sun or moon stands across the scene.
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
            // Fruit sitting up in the leaves goes down before this tier's
            // clumps, so their own leaves hang over it.
            if tier > 0 { look.fruit(tree, tier, nested: true) }
            while n < order.count && canopy.clumps[order[n]].tier == tier {
                look.foliage(tree, order[n])
                n += 1
            }
            if tier == 0 {
                look.wood(tree)
            } else {
                look.fruit(tree, tier, nested: false)
                look.blossoms(tree, tier)
            }
        }
        look.seedLeaves(tree)
    }
}

// MARK: - One redraw's numbers

extension PomegranatePainter {
    typealias RGB = Canopy.RGB

    /// What a leaf is painted with in one tier: three classes of green (deep,
    /// middle, sunlit), each a gradient along the light, a lit half, and the
    /// edge, midrib and gloss that catch it.
    struct LeafInk {
        var near: [Color], far: [Color], lit: [Color]
        var edge: Color, gloss: Color, body: Color, twig: Color
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
        let seed: UInt32
        /// The share of leaves left off, curled short, and the posture.
        let drop, curl, lenK, wK, pull: Double

        init(_ painter: PomegranatePainter) {
            canopy = painter.canopy
            p = painter.growth
            day = painter.day
            night = 1 - painter.day
            M = Canopy.Mood(painter.mood)
            pose = Canopy.Pose(canopy, growth: painter.growth, mood: M)
            tones = Canopy.Tones(canopy.kind, M, day: painter.day, growth: painter.growth)
            seed = Ink.hash(canopy.seed)

            // Overhead noon would light a tree flat, so the light is never
            // quite above it: at least a quarter of the way to a side.
            let sx = abs(painter.light) < 0.25 ? (painter.light > 0 ? 0.25 : -0.25) : painter.light
            let sy = -(0.45 + 0.4 * painter.day)
            let len = (sx * sx * 0.81 + sy * sy).squareRoot()
            L = (sx * 0.9 / len, sy / len)

            drop = 0.12 * M.thirst + 0.18 * M.doze
            curl = 0.5 * M.thirst + 0.3 * M.doze
            lenK = 1 - 0.1 * M.wilt
            wK = 1 - 0.22 * M.wilt
            pull = 0.1 + 0.2 * M.wilt + 0.07 * M.doze - 0.05 * M.glow

            // Light on the leaf edge: a warm white by day, amber when the sun
            // is low, cool by the moon.
            let dusk = 4 * painter.day * (1 - painter.day)
            let moon = Ink.smooth((0.3 - painter.day) / 0.3)
            let rim = RGB(0xFFF3C4).mix(RGB(0xFF9A5C), Ink.clamp(dusk * 1.4)).mix(RGB(0xC4D2FF), moon)
            let bronze = RGB.tone(0xBE5A38, day: painter.day, dim: 0.9)
            let ramp = tones.ramp, thirst = M.thirst, doze = M.doze
            var inks: [LeafInk] = []
            for tier in 0..<3 {
                for fresh in [false, true] {
                    var base = [ramp[tier], ramp[tier + 1], ramp[tier + 1].mix(ramp[tier + 2], 0.32 * (1 - moon))]
                    if fresh { base = base.map { $0.mix(bronze, 0.4 * (1 - 0.5 * thirst)) } }
                    // By moonlight the lit side is a cool, deep green, not a pale one.
                    let hi = ramp[min(4, tier + 2)].mix(ramp[tier + 1], 0.8 * moon)
                    let edge = ramp[4].mix(rim, 0.65)
                    let edgeA = (0.45 + 0.2 * dusk + 0.25 * moon) * (1 - 0.35 * doze) * (tier == 0 ? 1.2 : 1)
                    inks.append(LeafInk(
                        near: base.map { $0.shifted(2 - 5 * moon, -3).color() },
                        far: base.map { $0.shifted(-5, 6).color() },
                        lit: base.map { $0.mix(hi, 0.42).shifted(1).color() },
                        edge: edge.color(min(1, edgeA)),
                        gloss: RGB(0xFFFFFF).mix(rim, 0.4).color(0.38 * (1 - 0.6 * thirst - 0.4 * doze)),
                        body: ramp[tier].mix(ramp[tier + 1], 0.45).color(),
                        twig: tones.bark.mix(ramp[tier + 1], 0.35).color(0.9)
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

        /// A generator of one clump's own, so its leaves are the same at every
        /// growth and the same on every redraw.
        func rng(_ i: Int, _ salt: UInt32 = 97) -> Ink.Random {
            Ink.Random(seed: seed &+ UInt32(truncatingIfNeeded: i) &* 2_654_435_761 &+ salt)
        }

        /// Which way a heading sags under its own weight: towards the side it points.
        func fall(_ h: Double) -> Double { cos(h) >= 0 ? 1 : -1 }
    }
}

// MARK: - Leaves

extension PomegranatePainter.Look {
    /// Everything one clump's leaves add, by class of green.
    struct Parts {
        var full = [Path(), Path(), Path()], lit = [Path(), Path(), Path()]
        var gloss = Path(), twig = Path()
    }

    /// One clump: a dark body for the depth between the leaves, then a few
    /// sprigs. Each sprig is a twig that bends as it goes, with a pair of lance
    /// leaves at every node and one at the tip. Leaves are filled by class,
    /// deep to sunlit, each class as one gradient along the light, with the
    /// half of every leaf that faces the light lifted, a thin edge where the
    /// light grazes it, and now and then a streak of gloss.
    func foliage(_ context: GraphicsContext, _ i: Int) {
        let c = canopy.clumps[i], q = pose.clumps[i]!, tier = c.tier
        // A young tip's whorl of leaves is drawn broader than its small clump.
        let R = q.R * (c.tuft ? 1.3 : 1)
        let fresh = c.tuft || p - c.birth < 0.05
        let ink = inks[tier * 2 + (fresh ? 1 : 0)]
        var r = rng(i)
        var parts = Parts()
        let sprigs = c.tuft ? 3 : (tier == 2 ? 5 : tier == 1 ? 4 : 3)
        let pairs = tier == 0 || c.tuft ? 2 : 3
        let hair = max(0.5, R * 0.03)

        func leaf(_ x: Double, _ y: Double, _ a: Double, _ len0: Double, _ cls0: Int) {
            let keep = r.next(), curlR = r.next(), glossR = r.next(), lenJ = r.next(), flip = r.next()
            if keep < drop { return }
            let curled = curlR < curl
            let len = len0 * Ink.lerp(0.88, 1.12, lenJ) * lenK * (curled ? 0.62 : 1)
            let hw = len * 0.155 * wK * (curled ? 0.8 : 1)
            let ca = cos(a), sa = sin(a)
            let bend = fall(a) * (0.08 + pull - 0.1 + (curled ? 0.2 : 0))
            // How far towards the light this leaf sits and points.
            let l = ((x - q.x) * L.x + (y - q.y) * L.y) / R + (ca * L.x + sa * L.y) * 0.5
            let cls = max(0, min(2, (l > 0.45 ? 2 : l > -0.1 ? 1 : 0) + (flip < 0.2 ? -1 : flip > 0.85 ? 1 : 0)))
            parts.full[cls].lance(x, y, ca, sa, len, hw, bend, 0)
            let nl = -sa * L.x + ca * L.y
            let side = nl >= 0 ? 1.0 : -1
            // Light costs fills, so it is spent where it shows: the front tier's
            // sunlit leaves get their lit half; every tier's light edge comes
            // from one shifted copy of its path (see below), not from a shape
            // per leaf.
            if tier == 2 && cls == 2 && l > -0.05 { parts.lit[cls].lance(x, y, ca, sa, len, hw, bend, side) }
            if glossR < 0.14 && l > 0.25 && cls == 2 && !curled { parts.gloss.lanceGloss(x, y, ca, sa, len, hw, bend, side) }
        }

        for s in 0..<(sprigs + 2) {
            let under = s >= sprigs
            let f = (Double(s) + 0.5) / Double(sprigs)
            let jitter = (r.next() - 0.5) * 0.3
            // A tuft is a whorl of leaves, so its sprigs spread wide.
            let arc = c.tuft ? 0.18 : 0.1
            var h = under ? (s == sprigs ? 0.18 : 0.82) * .pi + jitter : Ink.lerp(.pi * (1 + arc), .pi * (2 - arc), f) + jitter
            let reach = R * Ink.lerp(0.58, 0.86, r.next()) * (under ? 0.8 : 1)
            let step = reach / 4, lean = (r.next() - 0.5) * 0.16
            let ob = under ? 0.12 : 0.1
            var x = q.x + cos(h) * R * ob, y = q.y + sin(h) * R * ob + R * 0.04
            parts.twig.move(to: CGPoint(x: x, y: y))
            let cls0 = under ? 0 : 1
            for k in 1...4 {
                h += pull * 0.5 * fall(h) * abs(cos(h)) + lean
                let nx = x + cos(h) * step, ny = y + sin(h) * step
                parts.twig.addLine(to: CGPoint(x: nx, y: ny))
                x = nx
                y = ny
                let size = R * 0.52 * (1 - 0.06 * Double(k))
                if k < 4 && k <= pairs {
                    let spread = Ink.lerp(0.62, 0.95, r.next())
                    leaf(x, y, h - spread, size, cls0)
                    leaf(x, y, h + spread, size, cls0)
                } else if k == 4 {
                    leaf(x, y, h, size * 1.05, cls0)
                }
            }
        }

        // Now and then a long young shoot stands up out of the crown, which
        // breaks the dome's outline the way a real one is broken.
        if !c.tuft && tier >= 1 && r.next() < 0.4 {
            var h = -Double.pi / 2 + (r.next() - 0.5) * 0.7
            var x = q.x + (r.next() - 0.5) * R * 0.5, y = q.y - R * 0.3
            let step = R * 0.3
            parts.twig.move(to: CGPoint(x: x, y: y))
            for k in 1...4 {
                h += pull * 0.25 * fall(h) * abs(cos(h)) + 0.05 * fall(h)
                x += cos(h) * step
                y += sin(h) * step
                parts.twig.addLine(to: CGPoint(x: x, y: y))
                if k < 4 {
                    leaf(x, y, h - 0.8, R * 0.4, 2)
                    leaf(x, y, h + 0.8, R * 0.4, 2)
                } else {
                    leaf(x, y, h, R * 0.45, 2)
                }
            }
        }

        context.fill(bodyPath(q), with: .color(ink.body))
        if tier > 0 { context.stroke(parts.twig, with: .color(ink.twig), style: StrokeStyle(lineWidth: hair, lineCap: .round, lineJoin: .round)) }
        let a = CGPoint(x: q.x + L.x * R, y: q.y + L.y * R), b = CGPoint(x: q.x - L.x * R, y: q.y - L.y * R)
        for cls in 0..<3 where !parts.full[cls].isEmpty {
            // The light edge: the same leaves, shifted towards the light and
            // painted in the rim colour first, show as a sliver on every leaf's
            // lit side. On the back tier it is the rim light; elsewhere it
            // keeps to the leaves that face the light.
            if (tier == 2 && cls == 2) || (tier == 0 && cls >= 1) {
                var shifted = context
                shifted.translateBy(x: L.x * hair * 0.9, y: L.y * hair * 0.9)
                shifted.fill(parts.full[cls], with: .color(ink.edge))
            }
            context.fill(parts.full[cls], with: tier == 2 ? .linearGradient(Gradient(colors: [ink.near[cls], ink.far[cls]]), startPoint: a, endPoint: b)
                                                          : .color(ink.near[cls].opacity(1)))
            if !parts.lit[cls].isEmpty { context.fill(parts.lit[cls], with: .color(ink.lit[cls])) }
        }
        if !parts.gloss.isEmpty { context.stroke(parts.gloss, with: .color(ink.gloss), style: StrokeStyle(lineWidth: hair * 0.55, lineCap: .round)) }
    }

    /// The soft dark mass behind a clump's leaves.
    private func bodyPath(_ q: Canopy.Pose.Spot) -> Path {
        var body = Path()
        let k = 1 - 0.45 * (M.thirst + M.doze)
        body.oval(q.x, q.y + q.R * 0.08, q.R * 0.56 * k, q.R * 0.44 * k)
        return body
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
            addCurve(to: tip, control1: P(0.2, hw * 1.55), control2: P(0.68, hw * 1.3))
        } else {
            addQuadCurve(to: tip, control: P(0.5, 0))
        }
        if half == 0 {
            addCurve(to: base, control1: P(0.68, -hw * 1.3), control2: P(0.2, -hw * 1.55))
        } else if half > 0 {
            addQuadCurve(to: base, control: P(0.5, 0))
        } else {
            addCurve(to: base, control1: P(0.68, -hw * 1.3), control2: P(0.2, -hw * 1.55))
        }
        closeSubpath()
    }

    /// A short bright streak on the lit side of the midrib: a glossy leaf.
    mutating func lanceGloss(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ bend: Double, _ side: Double) {
        move(to: Self.lancePoint(x, y, ca, sa, len, bend, 0.3, side * hw * 0.42))
        addLine(to: Self.lancePoint(x, y, ca, sa, len, bend, 0.58, side * hw * 0.34))
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
