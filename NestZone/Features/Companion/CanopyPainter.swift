import SwiftUI

/// A household's tree in layered gouache: overlapping leaf-shaped lobes in
/// three depth tiers, cool and dark at the back, warm and light in front, like
/// cut paper, with every part lit from the upper left. The prototype is
/// `Docs/Companion/art/gouache/tree.html` and its `SPEC.md`; this is its port to
/// `Canvas`, number for number.
///
/// Everything the seed decides is grown once, here. The seed is read in exactly
/// the prototype's order, draw for draw — the draws only its wind used included,
/// though a still never needs them — so a household's id grows the same tree in
/// the app as in the HTML. A picture is then a function of growth, mood and the
/// light (`CanopyPainter`).
struct Canopy: Equatable, Sendable {
    let seed: String
    let species: Species
    /// The one scale that fits the grown tree into the scene, measured on it
    /// fully grown and content: at most the species' height tall and its
    /// half-width either side of the trunk.
    let fit: Double

    fileprivate let kind: Kind
    fileprivate let limbs: [Limb]
    fileprivate let clumps: [Clump]
    fileprivate let blossoms: [Blossom]
    fileprivate let fruits: [Fruit]
    fileprivate let fallen: [Fallen]
    fileprivate let sparks: [Spark]
    /// Which way the trunk leans, so a wilting tree slumps the way it already
    /// leans.
    fileprivate let leanSign: Double

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.seed == rhs.seed && lhs.species == rhs.species }

    init(seed: String, species: Species) {
        let kind = Kind(species)
        var grower = Grower(kind: kind, seed: seed)
        grower.grow()

        // Depth: the low, central clumps come forward (tier 2), the high and
        // outer ones sit behind (tier 1), scored on the grown, content tree.
        // The pose does not read the tiers, so the same one also gives the fit.
        let grown = Pose(limbs: grower.limbs, clumps: grower.clumps, leanSign: grower.leanSign, growth: 1, mood: Mood(0.62))
        let front = grower.clumps.indices.filter { !grower.clumps[$0].tuft && grower.clumps[$0].tier > 0 && grown.clumps[$0] != nil }
        if !front.isEmpty {
            var y0 = Double.infinity, y1 = -Double.infinity, xm = 1.0
            for i in front {
                let q = grown.clumps[i]!
                y0 = min(y0, q.y)
                y1 = max(y1, q.y)
                xm = max(xm, abs(q.x))
            }
            var score: [Double] = []
            for i in front {
                let q = grown.clumps[i]!
                let low = (q.y - y0) / max(1, y1 - y0) * 0.62
                let central = (1 - abs(q.x) / xm) * 0.38
                score.append(low + central + (grower.r.next() - 0.5) * 0.22)
            }
            // The prototype's sort is stable: equal scores keep the clumps' order.
            let ranked = score.indices.sorted { score[$0] != score[$1] ? score[$0] > score[$1] : $0 < $1 }
            let count = max(1, Int((Double(front.count) * kind.can.front + 0.5).rounded(.down)))
            for (rank, j) in ranked.enumerated() { grower.clumps[front[j]].tier = rank < count ? 2 : 1 }
        }

        self.seed = seed
        self.species = species
        self.kind = kind
        fit = min(kind.H / max(1, -grown.top), kind.HW / max(1, -grown.left, grown.right))
        limbs = grower.limbs
        clumps = grower.clumps
        blossoms = grower.blossoms
        fruits = grower.fruits
        fallen = grower.fallen
        sparks = grower.sparks
        leanSign = grower.leanSign
    }
}

// MARK: - The model

extension Canopy {
    /// A piece of wood, a trunk segment or a limb. Its angle is relative to its
    /// parent's, so a bend low down carries everything above it.
    fileprivate struct Limb: Sendable {
        /// -1 for the first segment of a stem.
        var parent: Int
        var rel, len: Double
        var depth: Int
        var birth, dur, bend, w0, w1, side: Double
    }

    /// One leaf-shaped piece of a clump: a lobe of its outline, an under-lobe,
    /// or an accent that breaks the outline.
    fileprivate struct Lobe: Sendable {
        var a, r0, len, hw, keep: Double
        var under: Bool
        /// Where it sits on the clump, as `cos a` and `sin a`.
        var dx, dy: Double
        /// How it leans, like a roof shingle: which way, and how far round the
        /// clump it is as a share of the full sweep. The top lobe stands up,
        /// the side ones lie down along the outline.
        var shingle, share: Double
        /// How far round it is as a share of the full sag, which slides a
        /// tired clump's lobes down its sides.
        var slide: Double

        init(_ a: Double, _ r0: Double, _ len: Double, _ hw: Double, _ keep: Double, under: Bool) {
            (self.a, self.r0, self.len, self.hw, self.keep, self.under) = (a, r0, len, hw, keep, under)
            dx = cos(a)
            dy = sin(a)
            (shingle, share) = Canopy.shingle(a)
            slide = min(1, abs(Canopy.wrap(a - Canopy.up)) / 1.2)
        }
    }

    /// A leaf cut out of a clump's light, in the clump's own units.
    fileprivate struct Cut: Sendable {
        var x, y, a, len, keep: Double
        var shingle, share: Double
    }

    fileprivate struct Clump: Sendable {
        var node: Int
        var R, ox, oy, birth, die: Double
        var tier: Int
        /// Young foliage riding a growing tip, gone once the next part grows.
        var tuft: Bool
        var lobes: [Lobe]
        var accents: [Lobe]
        var cuts: [Cut]
        var ph: Double
    }

    fileprivate struct Blossom: Sendable {
        var clump: Int
        var dx, dy, size, rot, tilt, born, birth: Double
    }

    fileprivate struct Fruit: Sendable {
        var clump: Int
        var dx, hang, size, born, tilt, birth: Double
    }

    /// A leaf lying on the soil, in the scene's own units: the fit never
    /// scales it.
    fileprivate struct Fallen: Sendable {
        var x, y, a, len: Double
    }

    /// A glint round a bright crown.
    fileprivate struct Spark: Sendable {
        var u, v, s, ph: Double
    }

    fileprivate static let up = -Double.pi / 2
    fileprivate static let tau = Double.pi * 2
    /// Towards the light, for every part: the upper left.
    fileprivate static let light = (x: -0.62, y: -0.78)

    /// Any angle into [-π, π), the prototype's `wrap`.
    fileprivate static func wrap(_ a: Double) -> Double {
        ((a.truncatingRemainder(dividingBy: tau)) + tau * 1.5).truncatingRemainder(dividingBy: tau) - .pi
    }

    fileprivate static func shingle(_ a: Double) -> (Double, Double) {
        let dev = wrap(a - up)
        return (dev > 0 ? 1 : dev < 0 ? -1 : 1, min(1, abs(dev) / 1.1))
    }

    /// The tree grown from the seed, in the prototype's order.
    fileprivate struct Grower {
        let kind: Kind
        var r: Ink.Random
        var limbs: [Limb] = []
        var clumps: [Clump] = []
        var blossoms: [Blossom] = []
        var fruits: [Fruit] = []
        var fallen: [Fallen] = []
        var sparks: [Spark] = []
        var leanSign = 1.0
        /// Flips with every limb tip, so their clumps alternate tiers.
        private var alt = 0

        init(kind: Kind, seed: String) {
            self.kind = kind
            r = Ink.Random(seed)
        }

        private func width(_ depth: Int) -> Double { kind.form.trunkW * pow(kind.form.taper, Double(depth)) }

        mutating func grow() {
            let F = kind.form
            let lean = (r.next() - 0.5) * 2 * F.lean
            alt = r.next() < 0.5 ? 1 : 0
            for s in 0..<F.stems { stem(s, lean: lean) }

            // Every birth squeezed into the growth window: the seed 0–.08,
            // wood and leaves .08–.84, blossom .86–.96, fruit .9–.97.
            var end = -Double.infinity
            for n in limbs { end = max(end, n.birth + n.dur) }
            for c in clumps { end = max(end, c.birth + 0.2) }
            let k = 0.76 / end
            for i in limbs.indices {
                limbs[i].birth = 0.08 + limbs[i].birth * k
                limbs[i].dur *= k
            }
            for i in clumps.indices {
                clumps[i].birth = 0.08 + clumps[i].birth * k
                if clumps[i].die < 99 { clumps[i].die = 0.08 + clumps[i].die * k }
            }
            for i in blossoms.indices { blossoms[i].birth = 0.86 + blossoms[i].born * 0.1 }
            for i in fruits.indices { fruits[i].birth = 0.9 + fruits[i].born * 0.07 }

            for i in 0..<10 {
                let x = (i % 2 == 1 ? 1.0 : -1) * Ink.lerp(11, 40, r.next())
                let y = Ink.lerp(-2.4, 1.8, r.next())
                let tilt = (r.next() - 0.5) * 0.6
                let a = tilt + (r.next() < 0.5 ? 0 : .pi)
                fallen.append(Fallen(x: x, y: y, a: a, len: Ink.lerp(7, 10, r.next())))
            }
            for _ in 0..<6 {
                let u = r.next(), v = r.next(), s = Ink.lerp(1.6, 2.6, r.next())
                _ = r.next() // how fast it twinkles: only the wind's clock used it
                sparks.append(Spark(u: u, v: v, s: s, ph: r.next() * tau))
            }
            leanSign = lean > 0 ? 1 : lean < 0 ? -1 : 1
            // The prototype's last draw placed one falling leaf partway down.
            // A still would hang it in mid-air for good, so the scene lets a
            // leaf fall for real instead (`ScenePainter.fallingLeaf`).
        }

        private mutating func stem(_ s: Int, lean: Double) {
            let F = kind.form, C = kind.can
            let multi = F.stems > 1
            let f = multi ? Double(s) / Double(F.stems - 1) * 2 - 1 : 0
            let sw = multi ? (1 - 0.22 * abs(f)) * 0.9 : 1
            var heading = up + lean + f * F.stemSpread + (multi ? (r.next() - 0.5) * 0.12 : 0)
            let tl = F.trunk * (multi ? Ink.lerp(0.8, 1, r.next()) * (1 - 0.25 * abs(f)) : Ink.lerp(0.92, 1.08, r.next()))
            var parent = -1
            var birth = multi ? r.next() * 0.25 : 0
            var w = width(0) * sw
            let sign = r.next() < 0.5 ? -1.0 : 1
            let b0 = sign * F.bend * Ink.lerp(0.6, 1.2, r.next())
            for k in 0..<F.segs {
                let last = k == F.segs - 1
                var rel = heading - up
                if k > 0 {
                    let back = -(heading - up) * (0.45 + 0.3 * r.next())
                    rel = back + (r.next() - 0.5) * 0.1 * (1 + F.gnarl * 2.5)
                }
                let w1 = last ? width(1) * sw * 1.25 : w * Ink.lerp(0.8, 0.88, r.next())
                let len = tl / Double(F.segs) * Ink.lerp(0.85, 1.15, r.next())
                let bend = (k % 2 == 1 ? -1.0 : 1) * b0 * (1 + F.gnarl * 0.8)
                let lean = heading - up
                let n = node(parent, rel, len, 0, birth, w, w1, bend, lean > 0 ? 1 : lean < 0 ? -1 : 1)
                if k > 0 { heading += rel }
                // Young foliage rides the growing tip until the next part takes over.
                let dur = limbs[n].dur
                clump(n, C.R * (0.36 + 0.08 * Double(k)), 0, -C.R * 0.12, birth + dur * 0.35, 2,
                      die: birth + dur * (last ? 0.95 : 1.25), tuft: true)
                birth += dur * 0.82
                parent = n
                w = w1
            }
            let reach = F.limbLen * (multi ? Ink.lerp(0.8, 1, r.next()) : 1)
            let kb = fan(parent, heading, 1, reach, birth - 0.1, sw)
            clump(parent, C.R * 0.55, 0, -C.R * 0.2, birth - 0.2, 2, die: kb + 0.6, tuft: true)
        }

        /// The limbs off one node, and theirs, down to the species' depth.
        /// Returns the earliest birth among them.
        private mutating func fan(_ parent: Int, _ heading: Double, _ depth: Int, _ len: Double, _ birth: Double, _ sw: Double) -> Double {
            let F = kind.form, C = kind.can
            let n = depth == 1 ? F.limbs + (r.next() < F.limbsJ ? 1 : 0) : (r.next() < F.fork3 ? 3 : 2)
            let spread = depth == 1 ? F.spread : F.forkAng
            var first = 99.0
            for i in 0..<n {
                let f = n == 1 ? 0 : Double(i) / Double(n - 1) * 2 - 1
                var a = heading + f * spread * Ink.lerp(0.82, 1.15, r.next()) + (r.next() - 0.5) * 0.18
                a = Ink.lerp(a, up, F.upright)
                a = Ink.clamp(a, up - F.maxDev, up + F.maxDev)
                let L = len * Ink.lerp(0.86, 1.08, r.next()) * (1 - F.dome * abs(f))
                let last = depth >= F.depth
                let b = birth + r.next() * 0.22
                let side = a - up > 0 ? 1.0 : a - up < 0 ? -1 : (i % 2 == 1 ? 1 : -1)
                let w1 = last ? width(depth) * sw * 0.34 : width(depth + 1) * sw * 1.15
                let bend = side * F.cup * Ink.lerp(0.5, 1.1, r.next())
                let nd = node(parent, a - heading, L, depth, b, width(depth) * sw, w1, bend, side)
                let dur = limbs[nd].dur
                first = min(first, b)
                if !last {
                    let kb = fan(nd, a, depth + 1, L * F.decay, b + dur * 0.78, sw)
                    clump(nd, C.R * 0.6, 0, -C.R * 0.2, b + dur * 0.4, 2, die: kb + 0.5, tuft: true)
                    if r.next() < C.inner {
                        let R = C.R * Ink.lerp(0.78, 0.92, r.next())
                        perm(nd, R, b + dur * 0.85, 2)
                    }
                } else {
                    alt ^= 1
                    let R = C.R * Ink.lerp(1 - C.Rj, 1 + C.Rj, r.next())
                    let tier = r.next() < 0.2 ? 2 - alt : 1 + alt
                    perm(nd, R, b + dur * 0.7, tier)
                }
            }
            return first
        }

        private mutating func node(_ parent: Int, _ rel: Double, _ len: Double, _ depth: Int, _ birth: Double,
                                   _ w0: Double, _ w1: Double, _ bend: Double, _ side: Double) -> Int {
            let dur = Ink.lerp(0.8, 1.1, r.next())
            _ = r.next() // its sway phase: only the wind used it
            limbs.append(Limb(parent: parent, rel: rel, len: len, depth: depth, birth: birth, dur: dur,
                              bend: bend, w0: w0, w1: w1, side: side))
            return limbs.count - 1
        }

        /// A clump: a soft body, a crown of leaf-shaped lobes round its top, a
        /// few longer accent leaves that break the outline, and leaf cut-outs
        /// inside the light.
        @discardableResult
        private mutating func clump(_ node: Int, _ R: Double, _ ox: Double, _ oy: Double, _ birth: Double, _ tier: Int,
                                    die: Double = 99, tuft: Bool = false) -> Int {
            let C = kind.can
            let n = C.lobes + (r.next() < 0.5 ? 0 : 1)
            var lobes: [Lobe] = []
            lobes.reserveCapacity(n + 2)
            for i in 0..<n {
                let f = (Double(i) + 0.5) / Double(n)
                let a = Ink.lerp(.pi * 0.83, .pi * 2.17, f) + (r.next() - 0.5) * 0.26
                let r0 = C.r0 * Ink.lerp(0.9, 1.1, r.next())
                let len = C.len * Ink.lerp(0.8, 1.15, r.next())
                let hw = C.w * Ink.lerp(0.85, 1.1, r.next())
                let keep = r.next()
                _ = r.next() // flutter
                lobes.append(Lobe(a, r0, len, hw, keep, under: false))
            }
            for base in [Double.pi * 0.62, .pi * 0.38] {
                let a = base + (r.next() - 0.5) * 0.24
                let keep = r.next()
                _ = r.next() // flutter
                lobes.append(Lobe(a, C.r0 * 0.9, C.len * 0.72, C.w * 0.95, keep, under: true))
            }
            var accents: [Lobe] = []
            for _ in 0..<C.acc {
                let a = Ink.lerp(.pi * 0.55, .pi * 2.45, r.next())
                let r0 = Ink.lerp(0.62, 0.78, r.next())
                let len = C.len * Ink.lerp(0.8, 1.05, r.next())
                let keep = r.next()
                _ = r.next() // flutter
                accents.append(Lobe(a, r0, len, C.w * 0.62, keep, under: false))
            }
            var cuts: [Cut] = []
            for _ in 0..<C.tex {
                let a = r.next() * tau
                let d = Ink.lerp(0.15, 0.5, r.next().squareRoot())
                let x = -0.1 + cos(a) * d, y = -0.12 + sin(a) * d * 0.75
                let angle = atan2(y, x) + (r.next() - 0.5) * 0.6
                let len = Ink.lerp(0.2, 0.3, r.next())
                let (shingle, share) = Canopy.shingle(angle)
                cuts.append(Cut(x: x, y: y, a: angle, len: len, keep: r.next(), shingle: shingle, share: share))
            }
            clumps.append(Clump(node: node, R: R, ox: ox, oy: oy, birth: birth, die: die, tier: tier, tuft: tuft,
                                lobes: lobes, accents: accents, cuts: cuts, ph: r.next() * tau))
            return clumps.count - 1
        }

        /// A clump that stays: maybe a darker one behind it, its blossoms, its
        /// fruit.
        private mutating func perm(_ node: Int, _ R: Double, _ birth: Double, _ tier: Int) {
            let C = kind.can
            let ox = (r.next() - 0.5) * R * 0.3
            let c = clump(node, R, ox, -R * C.lift, birth, tier)
            if r.next() < C.rear {
                let s = r.next() < 0.5 ? -1.0 : 1
                let rr = R * Ink.lerp(0.85, 1.05, r.next())
                let dx = s * R * Ink.lerp(0.25, 0.6, r.next())
                let dy = -R * Ink.lerp(0.7, 1.05, r.next())
                clump(node, rr, dx, dy, birth + 0.05, 0)
            }
            let B = kind.flower
            let nb = B.per.0 + Int((r.next() * Double(B.per.1 - B.per.0 + 1)).rounded(.down))
            let cup = B.kind == .cup
            for _ in 0..<nb {
                let a = cup ? Ink.lerp(.pi * 1.2, .pi * 1.8, r.next()) : Ink.lerp(.pi * 1.05, .pi * 1.95, r.next())
                let rad = cup ? Ink.lerp(0.62, 0.86, r.next()) : Ink.lerp(0.25, 0.8, r.next())
                let size = B.size * Ink.lerp(0.82, 1.16, r.next())
                let rot = r.next() * tau
                let tilt = (r.next() - 0.5) * 0.5
                let born = r.next()
                _ = r.next() // sway
                blossoms.append(Blossom(clump: c, dx: cos(a) * rad - 0.06, dy: sin(a) * rad * 0.85 - 0.08,
                                        size: size, rot: rot, tilt: tilt, born: born, birth: 0))
            }
            guard let crop = kind.crop, r.next() < crop.share else { return }
            let olive = crop.kind == .olive
            let n = olive ? 2 + (r.next() < 0.5 ? 1 : 0) : 1 + (r.next() < 0.3 ? 1 : 0)
            let dx0 = (r.next() - 0.5) * 1.05
            for k in 0..<n {
                let dx = olive ? dx0 + (Double(k) - Double(n - 1) / 2) * 0.2 : (r.next() - 0.5) * 1.05
                let hang = olive ? Ink.lerp(0.02, 0.14, r.next()) : Ink.lerp(0.12, 0.38, r.next())
                let size = crop.size * Ink.lerp(0.85, 1.15, r.next())
                _ = r.next() // swing
                let born = r.next()
                let tilt = (r.next() - 0.5) * 0.6
                fruits.append(Fruit(clump: c, dx: dx, hang: hang, size: size, born: born, tilt: tilt, birth: 0))
            }
        }
    }
}

// MARK: - Mood and pose

extension Canopy {
    /// One mood in, the five things it moves out.
    fileprivate struct Mood {
        let m: Double
        /// Colour drains, lobes shrink and fall: 0 at .6 and above, 1 at .3 and below.
        let thirst: Double
        /// Paler, sparser, asleep: 0 at .3 and above, 1 at .05 and below.
        let doze: Double
        /// Saturated, lifted, luminous: 0 at .7 and below, 1 at .98 and above.
        let glow: Double
        /// Posture: branches and lobes hang.
        let wilt: Double
        /// Blossoms: open above about .6, buds below about .3.
        let open: Double

        init(_ m: Double) {
            self.m = m
            thirst = Ink.smooth((0.6 - m) / 0.3)
            doze = Ink.smooth((0.3 - m) / 0.25)
            glow = Ink.smooth((m - 0.7) / 0.28)
            wilt = Ink.smooth((0.66 - m) / 0.42)
            open = Ink.smooth((m - 0.22) / 0.4)
        }
    }

    /// Where everything is for one growth and mood: each limb as a tapered
    /// quadratic, each clump's centre and size, and the box round them all.
    /// Parents come before their children, so a limb is placed from its
    /// parent's end.
    fileprivate struct Pose {
        struct Span { var x, y, x1, y1, cx, cy, a1, w0, w1, g: Double }
        struct Spot { var x, y, R, k: Double }

        var limbs: [Span?]
        var clumps: [Spot?]
        var top = 0.0, left = 0.0, right = 0.0, bottom = -1e9

        init(limbs nodes: [Limb], clumps groups: [Clump], leanSign: Double, growth p: Double, mood M: Mood) {
            limbs = Array(repeating: nil, count: nodes.count)
            clumps = Array(repeating: nil, count: groups.count)
            let posture = M.wilt * 0.62 + M.doze * 0.18 - M.glow * 0.16
            let slump = leanSign * (M.wilt * 0.05 + M.doze * 0.03)
            for (i, n) in nodes.enumerated() {
                var sx = 0.0, sy = 0.0, sa = up
                if n.parent >= 0 {
                    guard let q = limbs[n.parent] else { continue }
                    (sx, sy, sa) = (q.x1, q.y1, q.a1)
                }
                let g = Ink.ease((p - n.birth) / n.dur)
                if g <= 0 { continue }
                let m = Ink.clamp((p - n.birth) / (1 - n.birth)), d = Double(n.depth)
                let droop = n.side * (d * 0.2 + 0.04) * posture + (n.depth == 0 ? slump : 0)
                let a = sa + n.rel * Ink.lerp(0.35, 1, g) + droop
                let len = n.len * g * (0.8 + 0.2 * p)
                let ca = cos(a), sa1 = sin(a)
                let x1 = sx + ca * len, y1 = sy + sa1 * len
                let cx = (sx + x1) / 2 - sa1 * n.bend * len, cy = (sy + y1) / 2 + ca * n.bend * len
                let wg = Ink.lerp(0.3, 1, m) * (0.55 + 0.45 * g)
                limbs[i] = Span(x: sx, y: sy, x1: x1, y1: y1, cx: cx, cy: cy, a1: atan2(y1 - cy, x1 - cx),
                                w0: n.w0 * wg, w1: max(0.5, n.w1 * wg), g: g)
            }
            let size = 1 + 0.07 * M.glow - 0.2 * M.thirst - 0.16 * M.doze
            let sideways = 0.2 * M.wilt + 0.08 * M.doze
            let sag = 0.26 * M.wilt + 0.1 * M.thirst + 0.22 * M.doze - 0.1 * M.glow
            for (i, c) in groups.enumerated() {
                guard let q = limbs[c.node] else { continue }
                var k = Ink.back((p - c.birth) / 0.07)
                if c.die < 99 { k *= 1 - Ink.smooth((p - c.die) / 0.1) }
                if k <= 0.01 { continue }
                let mat = 0.6 + 0.4 * Ink.smooth((p - c.birth) / 0.3)
                let sc = k * mat * size, R = c.R * sc
                let lean = q.x1 + c.ox
                let side = lean > 0 ? 1.0 : lean < 0 ? -1 : 1
                let x = q.x1 + c.ox * sc + side * c.R * sideways
                let y = q.y1 + c.oy * sc + c.R * sag
                clumps[i] = Spot(x: x, y: y, R: R, k: k)
                top = min(top, y - R * 1.3)
                left = min(left, x - R * 1.25)
                right = max(right, x + R * 1.25)
                bottom = max(bottom, y + R * 0.8)
            }
            for case let q? in limbs {
                top = min(top, q.y1)
                left = min(left, q.x1)
                right = max(right, q.x1)
            }
            if bottom < -1e8 { bottom = 0 }
        }

        init(_ canopy: Canopy, growth: Double, mood: Mood) {
            self.init(limbs: canopy.limbs, clumps: canopy.clumps, leanSign: canopy.leanSign, growth: growth, mood: mood)
        }
    }
}

// MARK: - Colour

extension Canopy {
    /// A colour as the prototype holds one: red, green and blue in 0…255,
    /// unrounded until it is drawn. Mood moves are made in HSL, night is a
    /// filter in RGB.
    fileprivate struct RGB {
        var r, g, b: Double

        init(_ r: Double, _ g: Double, _ b: Double) { (self.r, self.g, self.b) = (r, g, b) }
        init(_ hex: UInt32) { self.init(Double((hex >> 16) & 255), Double((hex >> 8) & 255), Double(hex & 255)) }

        /// From hue in degrees and saturation and lightness in percent.
        init(h: Double, s: Double, l: Double) {
            let h = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let s = Ink.clamp(s / 100), l = Ink.clamp(l / 100)
            let a = s * min(l, 1 - l)
            func f(_ n: Double) -> Double {
                let k = (n + h / 30).truncatingRemainder(dividingBy: 12)
                return (l - a * max(-1, min(k - 3, 9 - k, 1))) * 255
            }
            self.init(f(0), f(8), f(4))
        }

        var hsl: (h: Double, s: Double, l: Double) {
            let r = self.r / 255, g = self.g / 255, b = self.b / 255
            let mx = max(r, g, b), mn = min(r, g, b), l = (mx + mn) / 2
            var h = 0.0, s = 0.0
            if mx != mn {
                let d = mx - mn
                s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
                if mx == r {
                    h = (g - b) / d + (g < b ? 6 : 0)
                } else if mx == g {
                    h = (b - r) / d + 2
                } else {
                    h = (r - g) / d + 4
                }
                h *= 60
            }
            return (h, s * 100, l * 100)
        }

        func mix(_ o: RGB, _ t: Double) -> RGB { RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t) }

        func shifted(_ dl: Double, _ dh: Double = 0) -> RGB {
            let (h, s, l) = hsl
            return RGB(h: h + dh, s: s, l: l + dl)
        }

        /// Rounded to whole steps, as a CSS colour is.
        func color(_ alpha: Double = 1) -> Color {
            Color(.sRGB, red: (r + 0.5).rounded(.down) / 255, green: (g + 0.5).rounded(.down) / 255,
                  blue: (b + 0.5).rounded(.down) / 255, opacity: (alpha * 1000).rounded() / 1000)
        }

        func cgColor(_ alpha: Double = 1) -> CGColor {
            CGColor(srgbRed: (r + 0.5).rounded(.down) / 255, green: (g + 0.5).rounded(.down) / 255,
                    blue: (b + 0.5).rounded(.down) / 255, alpha: alpha)
        }

        /// Night: desaturate a little, then a cool filter in RGB, reds and
        /// greens dropping more than blue. No hue rotation, so a lemon stays
        /// yellow.
        static func night(_ h: Double, _ s: Double, _ l: Double, day: Double, dim: Double = 1) -> RGB {
            let n = (1 - day) * dim
            let c = RGB(h: h, s: s * (1 - 0.25 * n), l: l)
            return RGB(c.r * (1 - 0.46 * n), c.g * (1 - 0.4 * n), c.b * (1 - 0.14 * n))
        }

        static func tone(_ hex: UInt32, day: Double, dim: Double = 1) -> RGB {
            let (h, s, l) = RGB(hex).hsl
            return night(h, s, l, day: day, dim: dim)
        }
    }

    /// Where a thirsty canopy is heading, ramp step by ramp step: olive.
    fileprivate static let dry: [UInt32] = [0x4D4B31, 0x646039, 0x7F7B44, 0x9D9652, 0xC9C07C]
    /// Where a dozing one is heading: pale straw, with little contrast.
    fileprivate static let dozy: [UInt32] = [0x8B8466, 0xA29A78, 0xBAB08B, 0xCFC59F, 0xE4DBB9]
    /// How much each ramp step dims at night: the highlights hold up least.
    fileprivate static let dim = [1, 0.96, 0.92, 0.86, 0.74]

    /// One ramp step in this mood and light. Thirsty and dozing are RGB mixes
    /// towards `dry` and `dozy`, so they pass through olive rather than
    /// rotating through odd hues.
    fileprivate static func leafTone(_ c: RGB, _ i: Int, _ M: Mood, day: Double) -> RGB {
        let c = c.mix(RGB(dry[i]), M.thirst * (i < 2 ? 0.75 : 0.85)).mix(RGB(dozy[i]), M.doze * 0.8)
        var (h, s, l) = c.hsl
        s *= 1 + 0.34 * M.glow
        if i >= 2 {
            l += 5 * M.glow
            h -= 8 * M.glow
        } else {
            l += 1.5 * M.glow
        }
        return RGB.night(h, s, l, day: day, dim: dim[i])
    }

    /// Every colour one redraw uses.
    fileprivate struct Tones {
        /// How far each ramp step is lifted towards a pale blush halfway into
        /// bloom, deep to highlight.
        static let haze = [0.18, 0.3, 0.45, 0.55, 0.55]

        /// Five leaf tones, deep to highlight. Tier n takes its shadow from
        /// step n and its light from n + 1, with n + 2 mixed in for the sun.
        var ramp: [RGB]
        let bark, barkHi, barkDark: RGB
        let ba, bb, bc, bglow: RGB
        var fa = RGB(0, 0, 0), fs = RGB(0, 0, 0), fh = RGB(0, 0, 0), fc = RGB(0, 0, 0)
        let fallen, anther: RGB

        init(_ kind: Kind, _ M: Mood, day: Double, growth p: Double) {
            let n = 1 - day
            let bk = kind.bloomRamp == nil ? 0 : Ink.smooth((p - 0.86) / 0.1) * (0.2 + 0.8 * M.open)
            var ramp: [RGB] = []
            ramp.reserveCapacity(5)
            for i in 0..<5 {
                var c = RGB(kind.ramp[i])
                if bk > 0, let pink = kind.bloomRamp {
                    // Straight from green to pink is grey halfway, and a cherry
                    // spent a couple of days looking ashen on its way into
                    // bloom. A tree coming into blossom looks hazy and pale,
                    // so the middle of the way is lifted towards a pale blush,
                    // more in the light than in the shade.
                    let t = bk * kind.bloomW[i]
                    c = c.mix(RGB(pink[i]), t).mix(RGB(0xF8E4EC), 4 * t * (1 - t) * Tones.haze[i])
                }
                ramp.append(leafTone(c, i, M, day: day))
            }
            // Moonlight on the lit rim.
            ramp[4] = ramp[4].mix(RGB(0xCDD6FF), 0.3 * n)
            self.ramp = ramp

            func wood(_ hex: UInt32) -> RGB {
                let (h, s, l) = RGB(hex).hsl
                return RGB.night(h, s * (1 - 0.25 * M.thirst - 0.35 * M.doze), l + 4 * M.thirst + 7 * M.doze, day: day, dim: 0.9)
            }
            bark = wood(kind.bark.base)
            barkHi = wood(kind.bark.hi)
            barkDark = wood(kind.bark.dark)

            let open = (0.5 + 0.5 * M.open) * (1 + 0.12 * M.glow) * (1 - 0.4 * M.doze)
            func bloom(_ hex: UInt32, _ dim: Double = 0.5) -> RGB {
                let (h, s, l) = RGB(hex).hsl
                return RGB.night(h, s * open, l, day: day, dim: dim)
            }
            let B = kind.flower
            ba = bloom(B.a)
            bb = bloom(B.b)
            bc = bloom(B.c)
            bglow = bloom(B.glow, 0.2)

            if let F = kind.crop {
                let ripe = (0.62 + 0.38 * M.m) * (1 - 0.3 * M.doze)
                func fruit(_ hex: UInt32) -> RGB {
                    let (h, s, l) = RGB(hex).hsl
                    return RGB.night(h, s * ripe, l, day: day, dim: 0.7)
                }
                fa = fruit(F.a)
                fs = fruit(F.shade)
                fh = fruit(F.hi)
                fc = fruit(F.crown)
            }
            let (h, s, l) = RGB(0xB9A25C).mix(RGB(0xD6C79C), M.doze).hsl
            fallen = RGB.night(h, s, l, day: day, dim: 0.9)
            anther = RGB.tone(B.anther, day: day, dim: 0.5)
        }
    }
}

// MARK: - Painting

/// Where decorations go on a tree, in the painter's space (trunk base at the
/// origin, up negative, the fit applied).
struct CanopyAnchors: Equatable, Sendable {
    /// The crown's box: the clumps showing, y up negative.
    var left: Double, right: Double, top: Double, bottom: Double
    /// The top of the highest clump showing: where a star sits.
    var crownTop: CGPoint
    /// Points just inside the lower and outer edges of the front clumps
    /// showing, spread left to right: where ornaments and light bulbs hang.
    var hangs: [CGPoint]
    /// Points on bare wood below the clumps, or the foliage's lower edge where
    /// no wood shows: where paper wish notes hang.
    var notes: [CGPoint]
}

/// One still picture of a `Canopy`: no wind and one fixed instant (the
/// prototype's t = 0), because it is drawn only when the state changes and a
/// GPU shader adds the sway.
///
/// The caller's context sits at the trunk's base on the soil line, up
/// negative. `draw` puts the seed and the fallen leaves down unscaled, where
/// they lie on the scene's soil, then applies the fit and draws the tree back
/// to front: the far clumps under a rim of light, the wood with the canopy's
/// shade over it, then the middle and front tiers. Each of those first casts
/// its shadow onto what is behind it, clipped to it, and ends with its own
/// fruit and blossoms so the clumps in front can cover them. Each clump is
/// filled on its own, shadow, light and sun in turn: per-clump fills in depth
/// order are what make the canopy read as volume, and a batched version looked
/// flat. A tree in full bloom is about two hundred and thirty fills and three
/// clips.
struct CanopyPainter {
    let canopy: Canopy
    /// 0…1: seed .04, sprout .12, sapling .3, young tree .52, tree .76, in bloom .97.
    var growth: Double
    /// 0…1: 1 bright, .62 content, .3 thirsty, .05 dozing.
    var mood: Double
    /// 1 at noon, 0 at night.
    var day: Double
    /// The bright-mood glints round the crown. Off in the app, whose scene
    /// draws its own.
    var twinkles = false

    func draw(_ context: GraphicsContext) {
        let still = Still(self)
        still.ground(context)
        var tree = context
        tree.scaleBy(x: canopy.fit, y: canopy.fit)
        still.halo(tree)
        var crown = still.crown()
        var n = 0
        for tier in 0..<3 {
            still.cast(tree, tier, crown)
            still.rim(tree, tier, crown)
            while n < crown.order.count && canopy.clumps[crown.order[n]].tier == tier {
                still.clump(tree, crown.order[n], crown.shapes[n])
                n += 1
            }
            if tier == 0 {
                still.wood(tree, &crown)
            } else {
                still.fruit(tree, tier)
                still.blossoms(tree, tier)
            }
        }
        still.seedLeaves(tree)
        if twinkles { still.glints(tree) }
    }
}

extension CanopyPainter {
    fileprivate typealias RGB = Canopy.RGB

    /// One redraw's numbers, worked out once: the pose, the mood's five
    /// factors, this light's colours, and the shape every clump shares.
    fileprivate struct Still {
        /// One depth tier's paint: the shadow shape runs light to dark along the
        /// light, the lit shape is radial from its upper left; the split halves,
        /// the sunny patch and the cut-outs are solid.
        struct Tier {
            let shade, lit: Gradient
            let sh0, li0, vein, sun, cut: Color
        }

        /// One clump's shapes for this redraw: its outline, the lit copy up and
        /// left of it, the darker halves of the lit lobes, the sunny patch and
        /// the cut-outs.
        struct Shapes {
            var x, y, lx, ly, R: Double
            var outline = Path(), lit = Path(), veins = Path(), sun = Path(), cuts = Path()
        }

        /// Every clump showing, built once, and what the tiers share: the
        /// outlines behind a tier, which its cast shadow is clipped to, the
        /// rims, the cast shadows, and the canopy's shade on the wood.
        struct Crown {
            /// The clumps showing, back to front, and their shapes.
            var order: [Int] = []
            var shapes: [Shapes] = []
            var count = [0, 0, 0]
            /// Tier 0's outlines: what tier 1 casts onto.
            var below = Path()
            /// Tiers 0 and 1 and the wood: what tier 2 casts onto.
            var behind = Path()
            var rims = [Path(), Path(), Path()]
            var casts = [Path(), Path(), Path()]
            var woodShade = Path()
        }

        let canopy: Canopy
        let p, day, night: Double
        let M: Canopy.Mood
        let pose: Canopy.Pose
        let tones: Canopy.Tones
        let tiers: [Tier]
        /// Cut-outs whose `keep` is under this are not drawn, so a quiet
        /// tree's light thins out. Its clumps stay whole: they shrink, sag and
        /// curl, but never break into confetti.
        let drop: Double
        /// Lobes whose `keep` is under this curl up short: a softly ragged,
        /// tired outline.
        let curl: Double
        let bodyK, lenK, wK: Double
        /// How far the side lobes lie down along the outline: the main mood knob.
        let sweep: Double
        /// Tired leaves fold to rounder tips, so a quiet tree has no spikes.
        let blunt: Double
        /// How far a tired clump's lobes slide down its sides.
        let sag: Double
        /// The lit copy's size, and the sunny patch's: they shrink as the tree
        /// tires, so more shadow shows.
        let litK, sunK: Double
        /// The shadows the tree casts on itself, in its own deepest tone: a
        /// pink cherry gets a rose shadow, not grey.
        let shade: Color
        /// A rim of light round the back tier, and round every tier by
        /// moonlight.
        let rim: Color, rimSoft: Color

        init(_ painter: CanopyPainter) {
            let canopy = painter.canopy, M = Canopy.Mood(painter.mood), Cn = canopy.kind.can
            let night = 1 - painter.day
            self.canopy = canopy
            p = painter.growth
            day = painter.day
            self.night = night
            self.M = M
            pose = Canopy.Pose(canopy, growth: painter.growth, mood: M)
            let tones = Canopy.Tones(canopy.kind, M, day: painter.day, growth: painter.growth)
            self.tones = tones
            drop = 0.2 * M.thirst + 0.42 * M.doze
            curl = 0.12 * M.thirst + 0.2 * M.doze
            bodyK = 1 - 0.06 * M.thirst - 0.1 * M.doze
            lenK = 1 - 0.14 * M.wilt
            wK = 1 - 0.3 * M.wilt
            sweep = Cn.sweep + 0.32 * M.wilt + 0.1 * M.doze - 0.3 * M.glow
            blunt = min(1, Cn.blunt + 0.35 * M.thirst + 0.2 * M.doze)
            sag = 0.42 * M.thirst + 0.2 * M.doze
            litK = 0.74 - 0.04 * M.thirst - 0.04 * M.doze
            sunK = 0.42 * (1 + 0.14 * M.glow) * (1 - 0.3 * M.thirst - 0.3 * M.doze)

            var tiers: [Tier] = []
            for k in 0..<3 {
                let base = tones.ramp[k], lit = tones.ramp[k + 1], sun = tones.ramp[k + 2]
                let sh0 = base.shifted(4, -4), sh1 = base.shifted(-4, 6)
                let li0 = lit.mix(sun, (0.34 + 0.18 * M.glow) * (1 - 0.45 * night) * (1 - 0.35 * M.doze))
                let li2 = lit.shifted(-4, 5)
                let patch = lit.mix(sun, (0.5 + 0.18 * M.glow) * (1 - 0.35 * night) * (1 - 0.4 * M.thirst))
                tiers.append(Tier(
                    shade: Gradient(colors: [sh0.color(), sh1.color()]),
                    lit: Gradient(stops: [.init(color: li0.color(), location: 0), .init(color: lit.color(), location: 0.55),
                                          .init(color: li2.color(), location: 1)]),
                    sh0: sh0.color(), li0: li0.color(), vein: lit.mix(base, 0.38).color(0.85),
                    sun: patch.color((k == 2 ? 1 : 0.8) * (1 - 0.4 * M.doze)),
                    cut: base.mix(lit, 0.5).color(0.9)
                ))
            }
            self.tiers = tiers
            let shadeA = (0.3 + 0.05 * M.glow) * (1 - 0.35 * M.thirst - 0.3 * M.doze) * (1 - 0.25 * night)
            shade = tones.ramp[0].mix(RGB(0x122027), 0.35).shifted(-10).color(shadeA)
            let rim = night > 0.5 ? tones.ramp[4].mix(RGB(0xD9E2FF), 0.6) : tones.ramp[4].mix(RGB(0xFFF8E2), 0.5)
            let rimA = (0.18 + 0.12 * M.glow) * (1 - 0.3 * M.doze) * (1 + 2 * night)
            self.rim = rim.color(rimA)
            rimSoft = rim.color(rimA * 0.55)
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

        /// Where a lobe sits on its clump, as a unit vector: slid down the
        /// clump's side by the sag.
        func seat(_ lb: Canopy.Lobe) -> (x: Double, y: Double) {
            guard sag != 0 else { return (lb.dx, lb.dy) }
            let a = lb.a + lb.shingle * sag * lb.slide
            return (cos(a), sin(a))
        }

        // MARK: On the soil

        /// The seed, early on, and the leaves a thirsty or sleepy tree has let
        /// go of, unscaled on the soil. When thirsty one is still on its way
        /// down, where it is at the prototype's t = 0.
        func ground(_ context: GraphicsContext) {
            let ks = 1 - Ink.smooth((p - 0.085) / 0.04)
            if ks > 0 {
                var seed = Path(), shine = Path()
                seed.oval(0, -3.2, 7 * ks, 4.6 * ks, -0.3)
                shine.oval(-2.2 * ks, -4.6 * ks, 2.6 * ks, 1.2 * ks, -0.3)
                let husk = Gradient(colors: [RGB.tone(0xA98159, day: day).color(), RGB.tone(0x6E4F35, day: day).color()])
                context.fill(seed, with: .linearGradient(husk, startPoint: CGPoint(x: -6, y: -7), endPoint: CGPoint(x: 5, y: 1)))
                context.fill(shine, with: .color(RGB.tone(0xE2C49C, day: day).color(0.8)))
            }
            let count = Int((10 * Ink.clamp(0.55 * M.thirst + 0.45 * M.doze) + 0.5).rounded(.down))
            var leaves = Path()
            for f in canopy.fallen.prefix(count) {
                let ca = cos(f.a), sa = sin(f.a)
                leaves.leaf(f.x - ca * f.len / 2, f.y - sa * f.len / 2 * 0.4, ca, sa, f.len, f.len * 0.26, 0.3)
            }
            guard !leaves.isEmpty else { return }
            let dry = Gradient(colors: [tones.fallen.color(), tones.fallen.shifted(-8, 6).color()])
            context.fill(leaves, with: .linearGradient(dry, startPoint: CGPoint(x: -40, y: -3), endPoint: CGPoint(x: 40, y: 3)))
        }

        // MARK: The crown

        /// Light behind the crown: a bright mood by day, the blossoms by night.
        func halo(_ context: GraphicsContext) {
            let halo = 0.4 * M.glow * (0.4 + 0.6 * day) + 0.16 * night * Ink.smooth((p - 0.86) / 0.1) * M.open
            guard halo > 0.01 && p > 0.3 else { return }
            let cx = (pose.left + pose.right) / 2, cy = (pose.top + pose.bottom) / 2
            let rr = max(pose.right - pose.left, pose.bottom - pose.top) * 0.66
            let hc = day > 0.5 ? RGB(0xFFF4CC) : tones.bglow
            var disc = Path()
            disc.oval(cx, cy, rr, rr)
            context.fill(disc, with: .radialGradient(Gradient(colors: [hc.color(halo), hc.color(0)]),
                                                     center: CGPoint(x: cx, y: cy), startRadius: 4, endRadius: rr))
        }

        /// Every clump's shapes, in one pass so each lobe's angles are worked
        /// out once. Its outline goes to its own path, to the union behind the
        /// next tier, and moved towards the light as a rim and away from it as
        /// the shadow it casts: the same points each time, rather than copies
        /// of a finished path.
        func crown() -> Crown {
            var crown = Crown()
            crown.order = order()
            crown.shapes.reserveCapacity(crown.order.count)
            let Cn = canopy.kind.can, moonlit = night > 0.3, light = Canopy.light
            var split = false
            for i in crown.order {
                let c = canopy.clumps[i], q = pose.clumps[i]!, R = q.R, tier = c.tier
                crown.count[tier] += 1
                if tier > 0 && !split {
                    crown.behind = crown.below
                    split = true
                }
                var s = Shapes(x: q.x, y: q.y, lx: q.x + R * -0.15, ly: q.y + R * -0.19, R: R)
                let hx = q.x + R * -0.32, hy = q.y + R * -0.4
                let rimmed = tier == 0 || moonlit
                let rx = -0.055 * R, ry = -0.07 * R, cx = 0.07 * R, cy = 0.11 * R

                func outline(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ blunt: Double) {
                    s.outline.leaf(x, y, ca, sa, len, hw, blunt)
                    if tier == 0 {
                        crown.below.leaf(x, y, ca, sa, len, hw, blunt)
                    } else if tier == 1 {
                        crown.behind.leaf(x, y, ca, sa, len, hw, blunt)
                    }
                    if rimmed { crown.rims[tier].leaf(x + rx, y + ry, ca, sa, len, hw, blunt) }
                    if tier > 0 { crown.casts[tier].leaf(x + cx, y + cy, ca, sa, len, hw, blunt) }
                }

                let bx = R * Cn.body * bodyK, by = R * Cn.body * Cn.flat * bodyK, oy = q.y + R * 0.04
                s.outline.oval(q.x, oy, bx, by)
                if tier == 0 {
                    crown.below.oval(q.x, oy, bx, by)
                } else if tier == 1 {
                    crown.behind.oval(q.x, oy, bx, by)
                }
                if rimmed { crown.rims[tier].oval(q.x + rx, oy + ry, bx, by) }
                if tier > 0 { crown.casts[tier].oval(q.x + cx, oy + cy, bx, by) }
                s.lit.oval(s.lx, s.ly + R * 0.04 * litK, bx * litK, by * litK)
                if tier > 0 { s.sun.oval(hx, hy + R * 0.04 * sunK, bx * sunK, by * sunK) }

                for lb in c.lobes {
                    let (px, py) = seat(lb)
                    let a = lb.a + lb.shingle * sweep * lb.share, ca = cos(a), sa = sin(a)
                    let curled = lb.keep < curl
                    let len = R * lb.len * lenK * (curled ? 0.55 : 1), hw = R * lb.hw * wK
                    let ux = px * R * lb.r0, uy = py * R * lb.r0
                    outline(q.x + ux, q.y + uy, ca, sa, len, hw, blunt)
                    if lb.under { continue }
                    let lx = s.lx + ux * litK, ly = s.ly + uy * litK
                    s.lit.leaf(lx, ly, ca, sa, len * litK, hw * litK, blunt)
                    if tier == 2 && !curled {
                        // The half that faces away from the light, split at the midrib.
                        let away = -sa * light.x + ca * light.y > 0
                        s.veins.halfLeaf(lx, ly, ca, sa, len * litK, hw * litK, blunt, away ? -1 : 1)
                    }
                    if tier > 0 { s.sun.leaf(hx + ux * sunK, hy + uy * sunK, ca, sa, len * sunK, hw * sunK, blunt) }
                }
                for ac in c.accents {
                    let (px, py) = seat(ac)
                    let a = ac.a + ac.shingle * sweep * ac.share
                    outline(q.x + px * R * ac.r0, q.y + py * R * ac.r0, cos(a), sin(a), R * ac.len * lenK, R * ac.hw * wK, 0)
                }
                if tier == 2 {
                    for cut in c.cuts where cut.keep >= drop {
                        let a = cut.a + cut.shingle * sweep * cut.share
                        s.cuts.leaf(s.lx + cut.x * R * 0.9, s.ly + cut.y * R * 0.9, cos(a), sin(a), cut.len * R * lenK, cut.len * R * 0.24 * wK, 0)
                    }
                }
                if tier > 0 && !c.tuft {
                    crown.woodShade.oval(q.x + R * 0.08, q.y + R * 0.42, R * Cn.body * 1.02, R * Cn.body * Cn.flat * 0.95)
                }
                crown.shapes.append(s)
            }
            if !split { crown.behind = crown.below }
            return crown
        }

        /// The shadow a tier casts on what is behind it, clipped to that. The
        /// front tier's falls on the wood too.
        func cast(_ context: GraphicsContext, _ tier: Int, _ crown: Crown) {
            guard tier > 0, crown.count[tier] > 0, tier == 2 || crown.count[0] > 0 else { return }
            let behind = tier == 1 ? crown.below : crown.behind
            guard !behind.isEmpty else { return }
            var c = context
            c.clip(to: behind)
            c.fill(crown.casts[tier], with: .color(shade))
        }

        /// The back tier's rim of light, always; the others' only by moonlight.
        func rim(_ context: GraphicsContext, _ tier: Int, _ crown: Crown) {
            guard crown.count[tier] > 0, tier == 0 || night > 0.3 else { return }
            context.fill(crown.rims[tier], with: .color(tier == 0 ? rim : rimSoft))
        }

        /// One clump: its shadow shape, the lit shape up and left of it, on the
        /// front tier the darker halves of the lit lobes, a sunny patch further
        /// up and smaller again, and on the front tier leaf cut-outs.
        func clump(_ context: GraphicsContext, _ i: Int, _ s: Shapes) {
            let tier = canopy.clumps[i].tier, paint = tiers[tier], R = s.R, light = Canopy.light
            context.fill(s.outline, with: .linearGradient(paint.shade,
                                                          startPoint: CGPoint(x: s.x + light.x * R, y: s.y + light.y * R),
                                                          endPoint: CGPoint(x: s.x - light.x * R * 0.8, y: s.y - light.y * R * 0.8)))
            context.fill(s.lit, with: .radialGradient(paint.lit, center: CGPoint(x: s.lx - R * 0.3, y: s.ly - R * 0.36),
                                                      startRadius: 0, endRadius: R * 1.1))
            guard tier > 0 else { return }
            if !s.veins.isEmpty { context.fill(s.veins, with: .color(paint.vein)) }
            context.fill(s.sun, with: .color(paint.sun))
            if !s.cuts.isEmpty { context.fill(s.cuts, with: .color(paint.cut)) }
        }

        // MARK: The wood

        private static let grooves = [-0.16, 0.12], fibres = [-0.1]

        /// One silhouette with the root flare, a core shadow on the far side, a
        /// lit edge on the near side, a glint on smooth bark, the bark's marks
        /// and an olive's knots; then the canopy's shade over it, so branches
        /// sit under the leaves rather than beside them. The stems stand flat on
        /// the soil: a round foot would show below it. The silhouette also goes
        /// into what the front tier casts onto.
        func wood(_ context: GraphicsContext, _ crown: inout Crown) {
            let bark = canopy.kind.bark, mark = bark.mark, light = Canopy.light
            let castOn = crown.count[2] > 0
            var outline = Path(), edge = Path(), core = Path(), glint = Path(), marks = Path(), knots = Path()
            var flare = 0.0, any = false
            for (i, nd) in canopy.limbs.enumerated() {
                guard let q = pose.limbs[i] else { continue }
                any = true
                let root = nd.parent < 0
                if root { flare = max(flare, q.w0) }
                outline.limb(q, q.w0, q.w1, 0, flat: root)
                if castOn { crown.behind.limb(q, q.w0, q.w1, 0, flat: root) }
                let am = atan2(q.y1 - q.y, q.x1 - q.x)
                let side: Double = sin(am) * light.x - cos(am) * light.y > 0 ? -1 : 1
                edge.limb(q, q.w0 * 0.28, q.w1 * 0.22, side * 0.32, flat: root)
                core.limb(q, q.w0 * 0.34, q.w1 * 0.3, -side * 0.3, flat: root)
                if bark.glint && nd.depth <= 1 && q.w0 > 2.5 { glint.limb(q, q.w0 * 0.07, q.w1 * 0.05, side * 0.2, flat: root) }
                guard nd.depth <= 1 && q.w0 > 3 else { continue }
                let nx = -sin(am), ny = cos(am)
                switch mark {
                case .groove, .fibre:
                    for f in mark == .groove ? Self.grooves : Self.fibres {
                        let mid = f * (q.w0 + q.w1) * 0.5
                        marks.move(to: CGPoint(x: q.x + nx * f * q.w0, y: q.y + ny * f * q.w0))
                        marks.addQuadCurve(to: CGPoint(x: q.x1 + nx * f * q.w1, y: q.y1 + ny * f * q.w1),
                                           control: CGPoint(x: q.cx + nx * mid + nx * q.w0 * 0.06, y: q.cy + ny * mid))
                    }
                case .band:
                    var u = 0.12
                    while u < 0.92 {
                        let ux = Ink.lerp(Ink.lerp(q.x, q.cx, u), Ink.lerp(q.cx, q.x1, u), u)
                        let uy = Ink.lerp(Ink.lerp(q.y, q.cy, u), Ink.lerp(q.cy, q.y1, u), u)
                        let w = Ink.lerp(q.w0, q.w1, u)
                        marks.move(to: CGPoint(x: ux - nx * w * 0.3, y: uy - ny * w * 0.3))
                        marks.addLine(to: CGPoint(x: ux + nx * w * 0.12, y: uy + ny * w * 0.12))
                        u += 0.17
                    }
                case .none:
                    break
                }
                if mark == .groove && nd.depth == 0 && !root && q.g > 0.9 {
                    let u = 0.45
                    let ux = Ink.lerp(Ink.lerp(q.x, q.cx, u), Ink.lerp(q.cx, q.x1, u), u)
                    let uy = Ink.lerp(Ink.lerp(q.y, q.cy, u), Ink.lerp(q.cy, q.y1, u), u)
                    let w = Ink.lerp(q.w0, q.w1, u)
                    knots.oval(ux + nx * w * 0.08, uy + ny * w * 0.08, w * 0.13, w * 0.2, am)
                }
            }
            guard any else { return }
            // The root flare, part of the same silhouette, as wide as the widest
            // stem grown so far: on a shrub a later stem may not be up yet.
            outline.flare(flare)
            if castOn { crown.behind.flare(flare) }

            let t = tones
            let fade = Gradient(stops: [.init(color: t.barkDark.color(), location: 0), .init(color: t.bark.color(), location: 0.55),
                                        .init(color: t.bark.shifted(3).color(), location: 1)])
            context.fill(outline, with: .linearGradient(fade, startPoint: CGPoint(x: 0, y: pose.bottom * 0.65 + pose.top * 0.35), endPoint: .zero))
            context.fill(core, with: .color(t.barkDark.color(0.55)))
            let shine = Gradient(stops: [.init(color: t.barkHi.color(0.35), location: 0), .init(color: t.barkHi.color(0.75), location: 0.5),
                                         .init(color: t.barkHi.color(0.95), location: 1)])
            context.fill(edge, with: .linearGradient(shine, startPoint: CGPoint(x: 0, y: pose.top), endPoint: .zero))
            if !glint.isEmpty { context.fill(glint, with: .color(t.barkHi.shifted(10).color(0.55 * (1 - 0.5 * M.doze)))) }
            if !marks.isEmpty {
                let band = mark == .band
                context.stroke(marks, with: .color((band ? t.barkHi : t.barkDark).color(0.5)),
                               style: StrokeStyle(lineWidth: band ? 1.1 : 0.9, lineCap: .round))
            }
            if !knots.isEmpty { context.fill(knots, with: .color(t.barkDark.color(0.85))) }
            guard !crown.woodShade.isEmpty else { return }
            let deep = t.ramp[0].mix(RGB(0x122027), 0.35).shifted(-10)
            let under = Gradient(colors: [deep.color(0.42 * (1 - 0.3 * M.doze)), deep.color(0.12)])
            var c = context
            c.clip(to: outline)
            c.fill(crown.woodShade, with: .linearGradient(under, startPoint: CGPoint(x: 0, y: (pose.top + pose.bottom) / 2),
                                                          endPoint: CGPoint(x: 0, y: pose.bottom + 20)))
        }

        // MARK: Fruit and blossoms

        /// Where one fruit hangs: from the clump's underside, on a stem that
        /// swings a little outward as the tree wilts.
        private func hang(_ f: Canopy.Fruit, _ q: Canopy.Pose.Spot, _ k: Double) -> (ax: Double, ay: Double, x: Double, y: Double, r: Double, sw: Double) {
            let ax = q.x + f.dx * q.R, ay = q.y + q.R * 0.38
            let r = f.size * k * (1 - 0.12 * M.thirst - 0.1 * M.doze)
            let sw = M.wilt * 0.1 * (f.dx < 0 ? -1 : 1)
            let reach = f.hang * q.R + r
            return (ax, ay, ax + sin(sw) * reach, ay + cos(sw) * reach, r, sw)
        }

        /// One tier's fruit: a glow behind each, the stems, round bodies lit
        /// from the upper left, a highlight, and the crowns or nubs.
        func fruit(_ context: GraphicsContext, _ tier: Int) {
            guard let crop = canopy.kind.crop, p > 0.88 else { return }
            var stems = Path(), shine = Path(), crowns = Path(), any = false
            let glow = (0.08 + 0.14 * M.glow) * (1 + 0.3 * night) * (0.4 + 0.6 * M.m)
            let gc = tones.fh.mix(RGB(255, 250, 235), 0.4 * day)
            let halo = Gradient(colors: [gc.color(glow), gc.color(0)])
            for f in canopy.fruits where canopy.clumps[f.clump].tier == tier {
                guard let q = pose.clumps[f.clump] else { continue }
                let k = Ink.back((p - f.birth) / 0.05)
                if k <= 0 { continue }
                let (ax, ay, x, y, r, sw) = hang(f, q, k)
                any = true
                stems.move(to: CGPoint(x: ax, y: ay))
                stems.addQuadCurve(to: CGPoint(x: x, y: y - r * 0.85), control: CGPoint(x: ax + (x - ax) * 0.2, y: (ay + y) / 2))
                switch crop.kind {
                case .lemon:
                    let rot = .pi / 2 + f.tilt + sw * 0.5
                    crowns.oval(x + cos(rot) * r * 1.15, y + sin(rot) * r * 1.15, r * 0.2, r * 0.17, rot)
                case .olive:
                    break
                case .pom:
                    crowns.move(to: CGPoint(x: x - r * 0.3, y: y + r * 0.8))
                    crowns.addLine(to: CGPoint(x: x - r * 0.24, y: y + r * 1.18))
                    crowns.addLine(to: CGPoint(x: x - r * 0.09, y: y + r * 0.95))
                    crowns.addLine(to: CGPoint(x: x, y: y + r * 1.22))
                    crowns.addLine(to: CGPoint(x: x + r * 0.09, y: y + r * 0.95))
                    crowns.addLine(to: CGPoint(x: x + r * 0.24, y: y + r * 1.18))
                    crowns.addLine(to: CGPoint(x: x + r * 0.3, y: y + r * 0.8))
                    crowns.closeSubpath()
                }
                shine.oval(x - r * 0.36, y - r * 0.4, r * 0.24, r * 0.13, -0.75)
                if glow > 0.02 {
                    let gr = r * 2.4
                    var disc = Path()
                    disc.oval(x, y, gr, gr)
                    context.fill(disc, with: .radialGradient(halo, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: gr))
                }
            }
            guard any else { return }
            context.stroke(stems, with: .color(tones.barkDark.color(0.9)), lineWidth: 0.9)
            let round = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                   colors: [tones.fa.mix(tones.fh, 0.45).cgColor(), tones.fa.cgColor(), tones.fs.cgColor()] as CFArray,
                                   locations: [0, 0.42, 1])
            for f in canopy.fruits where canopy.clumps[f.clump].tier == tier {
                guard let q = pose.clumps[f.clump] else { continue }
                let k = Ink.back((p - f.birth) / 0.05)
                if k <= 0 { continue }
                let (_, _, x, y, r, sw) = hang(f, q, k)
                var body = Path()
                switch crop.kind {
                case .lemon: body.oval(x, y, r * 1.18, r * 0.86, .pi / 2 + f.tilt + sw * 0.5)
                case .olive: body.oval(x, y, r * 0.92, r * 0.68, f.tilt * 0.5 + .pi / 2)
                case .pom: body.oval(x, y, r, r)
                }
                // Lit like a sphere: the light spreads from a small circle at
                // the upper left out to a large one nearer the middle. A
                // gradient between two circles is Core Graphics', not one
                // `GraphicsContext` can describe.
                guard let round else { continue }
                context.withCGContext { cg in
                    cg.addPath(body.cgPath)
                    cg.clip()
                    cg.drawRadialGradient(round, startCenter: CGPoint(x: x - r * 0.38, y: y - r * 0.42), startRadius: r * 0.05,
                                          endCenter: CGPoint(x: x - r * 0.1, y: y - r * 0.1), endRadius: r * 1.25,
                                          options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
            }
            context.fill(shine, with: .color(tones.fh.color(0.9)))
            if !crowns.isEmpty { context.fill(crowns, with: .color(tones.fc.color())) }
        }

        /// What every flower of a tier adds to the shared fills: the
        /// pomegranate's tubes, centres and calyxes, throat spots, stamens,
        /// anthers, and the olive's dots.
        struct Pieces {
            var tubes = Path(), centres = Path(), spots = Path(), stamens = Path(), anthers = Path(), dots = Path()
        }

        /// One tier's blossoms: a soft glow behind each open flower, the
        /// pomegranate's tubes under their ruffles, each flower's petals with
        /// a gradient of its own, deep at the heart and pale at the tips, then
        /// the centres, spots, stamens and anthers, the buds and their sepals.
        func blossoms(_ context: GraphicsContext, _ tier: Int) {
            guard p > 0.85 else { return }
            let B = canopy.kind.flower, cup = B.kind == .cup, t = tones
            var pieces = Pieces(), buds = Path(), sepals = Path(), open = 0
            let glow = (0.16 + 0.2 * M.glow) * (1 + 0.25 * night) * M.open
            let gc = t.bglow.mix(RGB(255, 250, 240), 0.35 * day).mix(t.ba, 0.45 * night)
            let halo = Gradient(stops: [.init(color: gc.color(glow), location: 0), .init(color: gc.color(glow * 0.45), location: 0.45),
                                        .init(color: gc.color(0), location: 1)])
            let size = (0.35 + 0.65 * M.open) * (1 + 0.14 * M.glow)
            for b in canopy.blossoms where canopy.clumps[b.clump].tier == tier {
                guard let q = pose.clumps[b.clump] else { continue }
                let k = Ink.back((p - b.birth) / 0.05)
                if k <= 0 { continue }
                let x = q.x + b.dx * q.R, y = q.y + b.dy * q.R
                if M.open > 0.12 {
                    let s = b.size * k * size
                    open += 1
                    if !B.dense || b.born < 0.35 {
                        let gy = y - (cup ? s * 0.45 : 0), gr = s * 2.3
                        var disc = Path()
                        disc.oval(x, gy, gr, gr)
                        context.fill(disc, with: .radialGradient(halo, center: CGPoint(x: x, y: gy), startRadius: 0, endRadius: gr))
                    }
                    Self.pieces(B.kind, x, y, s, b.tilt, b.rot, &pieces)
                }
                if M.open < 0.6 && (b.born < (B.dense ? 0.3 : 0.6) || cup) {
                    let s = b.size * k * (1 - M.open) * 0.95
                    let a0 = Canopy.up + b.tilt * 0.6
                    let a = a0 + Canopy.wrap(.pi / 2 - a0) * M.wilt * 0.7
                    let ca = cos(a), sa = sin(a)
                    buds.leaf(x, y, ca, sa, s * 1.15, s * 0.36, 0)
                    sepals.leaf(x, y, ca, sa, s * 0.42, s * 0.3, 0)
                }
            }
            if open > 0 {
                if !pieces.tubes.isEmpty { context.fill(pieces.tubes, with: .color(t.bc.shifted(-4).color())) }
                let (first, second) = petalGradients(B.kind)
                for b in canopy.blossoms where canopy.clumps[b.clump].tier == tier {
                    guard let q = pose.clumps[b.clump] else { continue }
                    let k = Ink.back((p - b.birth) / 0.05)
                    if k <= 0 { continue }
                    petals(context, B.kind, q.x + b.dx * q.R, q.y + b.dy * q.R, b.size * k * size, b.tilt, b.rot, first, second)
                }
                if !pieces.dots.isEmpty { context.fill(pieces.dots, with: .color(t.ba.color())) }
                if !pieces.centres.isEmpty { context.fill(pieces.centres, with: .color(t.bc.color())) }
                if !pieces.spots.isEmpty { context.fill(pieces.spots, with: .color(t.bc.shifted(-10).color(0.8))) }
                if !pieces.stamens.isEmpty {
                    context.stroke(pieces.stamens, with: .color(t.bc.mix(t.ba, 0.3).color(0.85)), style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
                }
                if !pieces.anthers.isEmpty { context.fill(pieces.anthers, with: .color(t.anther.color())) }
            }
            if !buds.isEmpty {
                let bud = t.bc.mix(t.ba, 0.55).mix(t.ramp[3], 0.4 * M.thirst + 0.25 * M.doze)
                context.fill(buds, with: .color(bud.color()))
                context.fill(sepals, with: .color(t.ramp[1].shifted(-2).color()))
            }
        }

        /// Each kind's petal gradients for this redraw: the magnolia's inner
        /// and outer petals, the others' one.
        private func petalGradients(_ kind: Canopy.FlowerKind) -> (Gradient, Gradient) {
            let t = tones, a = t.ba, b = t.bb, c = t.bc
            func stops(_ s: [(Double, RGB)]) -> Gradient { Gradient(stops: s.map { .init(color: $0.1.color(), location: $0.0) }) }
            switch kind {
            case .cup:
                return (stops([(0, c.mix(b, 0.5)), (0.5, a.mix(b, 0.6)), (1, b)]), stops([(0, c), (0.45, a), (1, a.mix(b, 0.7))]))
            case .sakura:
                let g = stops([(0, c.mix(a, 0.4)), (0.4, a), (1, b)])
                return (g, g)
            case .azalea:
                let g = stops([(0, c), (0.32, c.mix(a, 0.6)), (0.6, a), (1, a.mix(RGB(255, 255, 255), 0.22))])
                return (g, g)
            case .flame:
                let g = stops([(0, b), (0.45, a), (1, a.mix(c, 0.45))])
                return (g, g)
            case .star:
                let g = stops([(0, b.mix(c, 0.3)), (0.35, a), (1, b)])
                return (g, g)
            case .tiny:
                return (Gradient(colors: []), Gradient(colors: []))
            }
        }

        /// One flower's petals, each part filled on its own with its gradient.
        private func petals(_ context: GraphicsContext, _ kind: Canopy.FlowerKind, _ x: Double, _ y: Double, _ s: Double,
                            _ tilt: Double, _ rot: Double, _ first: Gradient, _ second: Gradient) {
            let fifth = Canopy.tau / 5, centre = CGPoint(x: x, y: y)
            var petals = Path()
            switch kind {
            case .cup:
                // Magnolia: a tall pale inner petal, then two pink ones cupping it.
                let a = Canopy.up + tilt * 0.6, sp = 0.26 + 0.26 * M.open, ca = cos(a), sa = sin(a)
                petals.leaf(x, y, ca, sa, s * 1.3, s * 0.42, 0)
                context.fill(petals, with: .linearGradient(first, startPoint: centre, endPoint: CGPoint(x: x + ca * s * 1.3, y: y + sa * s * 1.3)))
                var outer = Path()
                outer.leaf(x - s * 0.07, y, cos(a - sp), sin(a - sp), s * 1.14, s * 0.4, 0)
                outer.leaf(x + s * 0.07, y, cos(a + sp), sin(a + sp), s * 1.14, s * 0.4, 0)
                context.fill(outer, with: .linearGradient(second, startPoint: centre, endPoint: CGPoint(x: x + ca * s * 1.14, y: y + sa * s * 1.14)))
            case .sakura:
                for i in 0..<5 {
                    let a = rot + Double(i) * fifth
                    petals.oval(x + cos(a) * s * 0.5, y + sin(a) * s * 0.5, s * 0.52, s * 0.43, a)
                }
                context.fill(petals, with: .radialGradient(first, center: centre, startRadius: 0, endRadius: s * 1.05))
            case .azalea:
                for i in 0..<5 {
                    let a = rot + Double(i) * fifth
                    petals.leaf(x, y, cos(a), sin(a), s, s * 0.56, 0.8)
                }
                context.fill(petals, with: .radialGradient(first, center: centre, startRadius: 0, endRadius: s))
            case .flame:
                // Pomegranate: an orange ruffle over the tube.
                let a = Canopy.up + tilt, ca = cos(a), sa = sin(a)
                for v in [-0.42, -0.14, 0.14, 0.42] {
                    let u = s * (0.72 + 0.08 * (0.42 - abs(v))), w = s * v
                    petals.oval(x + ca * u - sa * w, y + sa * u + ca * w, s * 0.3, s * 0.27, a)
                }
                let heart = CGPoint(x: x + ca * s * 0.8, y: y + sa * s * 0.8)
                context.fill(petals, with: .radialGradient(first, center: heart, startRadius: 0, endRadius: s * 0.62))
            case .star:
                for i in 0..<5 {
                    let a = rot + Double(i) * fifth
                    petals.leaf(x, y, cos(a), sin(a), s * 0.9, s * 0.26, 0)
                }
                context.fill(petals, with: .radialGradient(first, center: centre, startRadius: 0, endRadius: s * 0.9))
            case .tiny:
                break
            }
        }

        /// What one flower adds to the tier's shared fills.
        private static func pieces(_ kind: Canopy.FlowerKind, _ x: Double, _ y: Double, _ s: Double, _ tilt: Double, _ rot: Double,
                                   _ into: inout Pieces) {
            func stamens(_ n: Int, _ len: Double, _ a0: Double, _ spread: Double, _ dot: Double) {
                for i in 0..<n {
                    let a = a0 + (n > 1 ? (Double(i) / Double(n - 1) - 0.5) * spread : 0)
                    let ex = x + cos(a) * len, ey = y + sin(a) * len
                    into.stamens.move(to: CGPoint(x: x, y: y))
                    into.stamens.addQuadCurve(to: CGPoint(x: ex, y: ey), control: CGPoint(x: x + cos(a - 0.25) * len * 0.55, y: y + sin(a - 0.25) * len * 0.55))
                    into.anthers.oval(ex, ey, dot, dot)
                }
            }
            switch kind {
            case .cup:
                into.centres.oval(x, y + s * 0.04, s * 0.24, s * 0.18)
            case .sakura:
                for i in 0..<7 {
                    let a = rot + 0.3 + Double(i) * Canopy.tau / 7
                    let ex = x + cos(a) * s * 0.42, ey = y + sin(a) * s * 0.42
                    into.stamens.move(to: CGPoint(x: x, y: y))
                    into.stamens.addLine(to: CGPoint(x: ex, y: ey))
                    into.anthers.oval(ex, ey, s * 0.06, s * 0.06)
                }
                into.centres.oval(x, y, s * 0.12, s * 0.12)
            case .azalea:
                // The throat spots and the stamens sit on the petal nearest the top.
                var up = 0.0, best = 9.0
                for i in 0..<5 {
                    let a = rot + Double(i) * Canopy.tau / 5, d = abs(Canopy.wrap(a - Canopy.up))
                    if d < best {
                        best = d
                        up = a
                    }
                }
                for i in 1...4 {
                    let along = s * (0.18 + 0.12 * Double(i)), across = s * 0.06 * (i % 2 == 1 ? 1 : -1)
                    into.spots.oval(x + cos(up) * along + cos(up + 1.57) * across, y + sin(up) * along + sin(up + 1.57) * across,
                                    s * 0.045, s * 0.045)
                }
                stamens(5, s * 1.05, up + 0.9, 0.9, s * 0.05)
            case .flame:
                let a = Canopy.up + tilt, ca = cos(a), sa = sin(a)
                into.tubes.leaf(x, y, ca, sa, s * 0.78, s * 0.24, 0)
                for v in [-0.2, 0, 0.2] {
                    let u = s * 0.98, w = s * v
                    into.anthers.oval(x + ca * u - sa * w, y + sa * u + ca * w, s * 0.06, s * 0.06)
                }
            case .star:
                stamens(5, s * 0.36, rot + 0.6, Canopy.tau * 0.8, s * 0.05)
                into.centres.oval(x, y, s * 0.15, s * 0.15)
            case .tiny:
                for i in 0..<3 {
                    let a = rot + Double(i) * Canopy.tau / 3
                    into.dots.oval(x + cos(a) * s * 0.42, y + sin(a) * s * 0.42, s * 0.32, s * 0.32)
                }
            }
        }

        // MARK: Last

        /// The two seed leaves of a sprout, at the tip of the first stem grown.
        func seedLeaves(_ context: GraphicsContext) {
            let kc = Ink.back((p - 0.09) / 0.05) * (1 - Ink.smooth((p - 0.3) / 0.1))
            guard kc > 0, let root = canopy.limbs.indices.first(where: { canopy.limbs[$0].parent < 0 && pose.limbs[$0] != nil }),
                  let q = pose.limbs[root] else { return }
            var outer = Path(), inner = Path()
            for s in [-1.0, 1] {
                let a = Canopy.up + s * (1.05 + 0.45 * M.wilt - 0.15 * M.glow), b = a - s * 0.12
                outer.leaf(q.x1, q.y1, cos(a), sin(a), 11 * kc, 4.4 * kc, 0.3)
                inner.leaf(q.x1 - 0.8, q.y1 - 1.1, cos(b), sin(b), 8.2 * kc, 2.6 * kc, 0.3)
            }
            context.fill(outer, with: .color(tiers[2].sh0))
            context.fill(inner, with: .color(tiers[2].li0))
        }

        /// A bright tree's glints round the crown.
        func glints(_ context: GraphicsContext) {
            guard M.glow > 0.05 && p > 0.5 else { return }
            var path = Path()
            for s in canopy.sparks.prefix(4) {
                let r = s.s * 0.75 * max(0, sin(s.ph)) * M.glow
                if r < 0.35 { continue }
                let x = Ink.lerp(pose.left + 10, pose.right - 10, s.u)
                let y = Ink.lerp(pose.top + 6, Ink.lerp(pose.top, pose.bottom, 0.55), s.v)
                let c = CGPoint(x: x, y: y), d = r * 2.4
                path.move(to: CGPoint(x: x, y: y - d))
                path.addQuadCurve(to: CGPoint(x: x + d, y: y), control: c)
                path.addQuadCurve(to: CGPoint(x: x, y: y + d), control: c)
                path.addQuadCurve(to: CGPoint(x: x - d, y: y), control: c)
                path.addQuadCurve(to: CGPoint(x: x, y: y - d), control: c)
                path.closeSubpath()
            }
            if !path.isEmpty { context.fill(path, with: .color(RGB(0xFFF6D6).color(0.92))) }
        }
    }
}

// MARK: - Anchors

extension CanopyPainter {
    /// Where decorations go, worked out from the same pose and mood `draw`
    /// uses, so a bauble hangs from the clump it is drawn under.
    func anchors() -> CanopyAnchors {
        let still = Still(self), pose = still.pose, fit = canopy.fit, Cn = canopy.kind.can
        let order = still.order()

        // Each clump showing, as drawn: its outline's reach, its solid body,
        // and an ellipse that stands in for it when asking what covers what.
        // Only clumps later in the drawing order can cover a point on one.
        var left = Double.infinity, right = -Double.infinity, top = Double.infinity, bottom = -Double.infinity
        var crown = CGPoint.zero
        var cover: [(x: Double, y: Double, rx: Double, up: Double, down: Double, bx: Double, by: Double)] = []
        cover.reserveCapacity(order.count)
        for i in order {
            let c = canopy.clumps[i], q = pose.clumps[i]!, R = q.R
            let bx = R * Cn.body * still.bodyK, by = R * Cn.body * Cn.flat * still.bodyK, cy = q.y + R * 0.04
            var l = q.x - bx, r = q.x + bx, t = cy - by, b = cy + by, peak = CGPoint(x: q.x, y: t)
            for lb in c.lobes {
                let (px, py) = still.seat(lb)
                let a = lb.a + lb.shingle * still.sweep * lb.share
                let len = R * lb.len * still.lenK * (lb.keep < still.curl ? 0.55 : 1)
                let x1 = q.x + px * R * lb.r0 + cos(a) * len, y1 = q.y + py * R * lb.r0 + sin(a) * len
                l = min(l, x1)
                r = max(r, x1)
                b = max(b, y1)
                if y1 < t {
                    t = y1
                    peak = CGPoint(x: x1, y: y1)
                }
            }
            left = min(left, l)
            right = max(right, r)
            bottom = max(bottom, b)
            if t < top {
                top = t
                crown = peak
            }
            cover.append((q.x, cy, (r - l) / 2 * 0.86, (cy - t) * 0.8, (b - cy) * 0.86, bx, by))
        }
        guard !order.isEmpty else {
            let tip = pose.limbs.compactMap { $0 }.min { $0.y1 < $1.y1 }
            let point = CGPoint(x: (tip?.x1 ?? 0) * fit, y: (tip?.y1 ?? 0) * fit)
            return CanopyAnchors(left: point.x, right: point.x, top: point.y, bottom: point.y, crownTop: point, hangs: [], notes: [])
        }
        func covered(_ x: Double, _ y: Double, after rank: Int, margin: Double = 0) -> Bool {
            for j in cover.indices where j > rank {
                let e = cover[j], ry = (y < e.y ? e.up : e.down) + margin
                let u = (x - e.x) / (e.rx + margin), v = (y - e.y) / ry
                if u * u + v * v < 1 { return true }
            }
            return false
        }

        let width = (right - left) * fit

        // Notes first: they have far fewer places to go than the ornaments.
        // On wood no clump covers, high enough that the paper clears the
        // pot's rim; where too little wood shows, from the foliage's lower
        // edge.
        var wood: [(x: Double, y: Double)] = []
        for case let q? in pose.limbs {
            for step in 0..<11 {
                let t = 0.2 + 0.075 * Double(step), u = 1 - t
                let x = u * u * q.x + 2 * u * t * q.cx + t * t * q.x1, y = u * u * q.y + 2 * u * t * q.cy + t * t * q.y1
                guard Ink.lerp(q.w0, q.w1, t) * fit >= 1.6, y * fit < -24, !covered(x, y, after: -1, margin: 2) else { continue }
                wood.append((x * fit, y * fit))
            }
        }
        var notes = Self.spread([wood], keep: 4...6, gap: width / 6, floor: 10, upright: 0.5)
        if notes.count < 4 {
            var edge: [(x: Double, y: Double)] = []
            for (rank, _) in order.enumerated() {
                let e = cover[rank]
                for step in -4...4 {
                    let a = Double.pi / 2 + Double(step) * 0.25
                    let x = e.x + cos(a) * e.bx * 0.92, y = e.y + sin(a) * e.by * 0.92
                    if !covered(x, y, after: rank) { edge.append((x * fit, y * fit)) }
                }
            }
            notes = Self.spread([wood, edge], keep: 4...6, gap: width / 6, floor: 10, upright: 0.5)
        }

        // Ornaments: just inside the lower and outer edge of the front clumps'
        // solid bodies, never in a gap between drooping lobes, where nothing
        // in front covers it; the tiers behind only fill in. All four tree
        // decorations can be up at once, so they keep clear of the notes.
        var tiers: [[(x: Double, y: Double)]] = [[], [], []]
        for (rank, i) in order.enumerated() {
            let e = cover[rank]
            for step in 0...10 {
                let a = 0.1 + Double(step) * (Double.pi - 0.2) / 10
                let x = e.x + cos(a) * e.bx * 0.88, y = e.y + sin(a) * e.by * 0.88
                let point = (x: x * fit, y: y * fit)
                guard !covered(x, y, after: rank), notes.allSatisfy({ hypot($0.x - point.x, $0.y - point.y) >= 9 }) else { continue }
                tiers[canopy.clumps[i].tier].append(point)
            }
        }
        let hangs = Self.spread(tiers.reversed(), keep: 8...14, gap: width / 8, floor: 12)
        return CanopyAnchors(
            left: left * fit, right: right * fit, top: top * fit, bottom: bottom * fit,
            crownTop: CGPoint(x: crown.x * fit, y: crown.y * fit),
            hangs: hangs.map { CGPoint(x: $0.x, y: $0.y) },
            notes: notes.map { CGPoint(x: $0.x, y: $0.y) }
        )
    }

    /// Thins candidate points to an even spread. Groups are taken in order and
    /// each lowest first; a point is kept only if it is clear of those already
    /// kept, the gap shrinking (never below `floor`, so a small tree gets fewer
    /// rather than a pile) until enough are. Then evenly sampled down to the
    /// most wanted, left to right. A note hangs below its point, so for notes
    /// a vertical gap counts for less (`upright`) than a sideways one.
    private static func spread(_ groups: [[(x: Double, y: Double)]], keep: ClosedRange<Int>, gap: Double,
                               floor: Double, upright: Double = 1) -> [(x: Double, y: Double)] {
        let order = groups.flatMap { $0.sorted { $0.y > $1.y } }
        var gap = max(gap, floor), kept: [(x: Double, y: Double)] = []
        while true {
            kept = []
            for q in order where kept.allSatisfy({ hypot($0.x - q.x, ($0.y - q.y) * upright) >= gap }) { kept.append(q) }
            if kept.count >= keep.lowerBound || gap <= floor { break }
            gap = max(floor, gap * 0.85)
        }
        kept.sort { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard kept.count > keep.upperBound else { return kept }
        let n = keep.upperBound
        return (0..<n).map { kept[Int((Double($0) + 0.5) * Double(kept.count) / Double(n))] }
    }
}

// MARK: - Shapes

/// The four path pieces, all wound clockwise on screen, so a union of
/// overlapping pieces filled nonzero never punches a hole. Circles are four
/// cubics rather than `Path(ellipseIn:)`, whose direction would have to be
/// checked against the leaves'.
private extension Path {
    /// An ellipse about (cx, cy), turned by `rot`: four cubics from +rx,
    /// going clockwise.
    mutating func oval(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ rot: Double = 0) {
        let k = 0.5523, c = cos(rot), s = sin(rot)
        func p(_ u: Double, _ v: Double) -> CGPoint { CGPoint(x: cx + c * u - s * v, y: cy + s * u + c * v) }
        move(to: p(rx, 0))
        addCurve(to: p(0, ry), control1: p(rx, k * ry), control2: p(k * rx, ry))
        addCurve(to: p(-rx, 0), control1: p(-k * rx, ry), control2: p(-rx, k * ry))
        addCurve(to: p(0, -ry), control1: p(-rx, -k * ry), control2: p(-k * rx, -ry))
        addCurve(to: p(rx, 0), control1: p(k * rx, -ry), control2: p(rx, -k * ry))
        closeSubpath()
    }

    /// A leaf-shaped lobe from its base at (x, y), its tip `len` along the
    /// direction (ca, sa): round at the base, widest a third of the way out.
    /// `blunt` 0 is a pointed leaf, 1 a rounded petal.
    mutating func leaf(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ blunt: Double) {
        let u1 = len * 0.08, v1 = hw * 1.32
        let u2 = len * (0.56 + 0.3 * blunt), v2 = hw * (1.22 - 0.22 * blunt)
        move(to: CGPoint(x: x, y: y))
        addCurve(to: CGPoint(x: x + ca * len, y: y + sa * len),
                 control1: CGPoint(x: x + ca * u1 + sa * v1, y: y + sa * u1 - ca * v1),
                 control2: CGPoint(x: x + ca * u2 + sa * v2, y: y + sa * u2 - ca * v2))
        addCurve(to: CGPoint(x: x, y: y),
                 control1: CGPoint(x: x + ca * u2 - sa * v2, y: y + sa * u2 + ca * v2),
                 control2: CGPoint(x: x + ca * u1 - sa * v1, y: y + sa * u1 + ca * v1))
        closeSubpath()
    }

    /// One half of a `leaf`, split at a midrib that bows a little to the
    /// leaf's left: side -1 the left half, 1 the right. Both are wound
    /// clockwise, like every other piece.
    mutating func halfLeaf(_ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ blunt: Double, _ side: Double) {
        let u1 = len * 0.08, v1 = hw * 1.32
        let u2 = len * (0.56 + 0.3 * blunt), v2 = hw * (1.22 - 0.22 * blunt)
        let um = len * 0.5, vm = hw * 0.12
        let base = CGPoint(x: x, y: y), tip = CGPoint(x: x + ca * len, y: y + sa * len)
        let rib = CGPoint(x: x + ca * um + sa * vm, y: y + sa * um - ca * vm)
        move(to: base)
        if side < 0 {
            addCurve(to: tip, control1: CGPoint(x: x + ca * u1 + sa * v1, y: y + sa * u1 - ca * v1),
                     control2: CGPoint(x: x + ca * u2 + sa * v2, y: y + sa * u2 - ca * v2))
            addQuadCurve(to: base, control: rib)
        } else {
            addQuadCurve(to: tip, control: rib)
            addCurve(to: base, control1: CGPoint(x: x + ca * u2 - sa * v2, y: y + sa * u2 + ca * v2),
                     control2: CGPoint(x: x + ca * u1 - sa * v1, y: y + sa * u1 + ca * v1))
        }
        closeSubpath()
    }

    /// An arc as cubics in pieces of at most a quarter turn, by increasing
    /// angle, continuing the current sub-path.
    mutating func arc(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double) {
        let n = max(1, Int(((a1 - a0) / (.pi / 2) - 1e-6).rounded(.up)))
        let da = (a1 - a0) / Double(n), k = 4 / 3 * tan(da / 4)
        for i in 0..<n {
            let s = a0 + da * Double(i), e = s + da
            let cs = cos(s), ss = sin(s), ce = cos(e), se = sin(e)
            addCurve(to: CGPoint(x: cx + r * ce, y: cy + r * se),
                     control1: CGPoint(x: cx + r * (cs - k * ss), y: cy + r * (ss + k * cs)),
                     control2: CGPoint(x: cx + r * (ce + k * se), y: cy + r * (se - k * ce)))
        }
    }

    /// A limb: a quadratic centre line, its width tapering from w0 to w1,
    /// round at both ends, or square at the base when `flat`: a stem standing
    /// on the soil must not show a round foot below it. `off` slides it
    /// sideways by that share of the limb's own width, for the lit edge and
    /// the core shadow.
    mutating func limb(_ q: Canopy.Pose.Span, _ w0: Double, _ w1: Double, _ off: Double, flat: Bool) {
        var (x, y, x1, y1, cx, cy) = (q.x, q.y, q.x1, q.y1, q.cx, q.cy)
        let a0 = atan2(cy - y, cx - x), a1 = atan2(y1 - cy, x1 - cx), am = atan2(y1 - y, x1 - x), wm = (w0 + w1) / 4
        let n0 = (x: -sin(a0), y: cos(a0)), n1 = (x: -sin(a1), y: cos(a1)), nm = (x: -sin(am), y: cos(am))
        if off != 0 {
            let mid = off * (q.w0 + q.w1) / 2
            x += n0.x * off * q.w0
            y += n0.y * off * q.w0
            cx += nm.x * mid
            cy += nm.y * mid
            x1 += n1.x * off * q.w1
            y1 += n1.y * off * q.w1
        }
        move(to: CGPoint(x: x - n0.x * w0 / 2, y: y - n0.y * w0 / 2))
        addQuadCurve(to: CGPoint(x: x1 - n1.x * w1 / 2, y: y1 - n1.y * w1 / 2), control: CGPoint(x: cx - nm.x * wm, y: cy - nm.y * wm))
        arc(x1, y1, w1 / 2, a1 - .pi / 2, a1 + .pi / 2)
        addQuadCurve(to: CGPoint(x: x + n0.x * w0 / 2, y: y + n0.y * w0 / 2), control: CGPoint(x: cx + nm.x * wm, y: cy + nm.y * wm))
        if !flat { arc(x, y, w0 / 2, a0 + .pi / 2, a0 + .pi * 1.5) }
        closeSubpath()
    }

    /// The root flare where the stems meet the soil, w wide.
    mutating func flare(_ w: Double) {
        let h = w * 0.9, fw = w * 0.98
        move(to: CGPoint(x: -fw, y: 1.4))
        addCurve(to: CGPoint(x: -w * 0.5, y: -h), control1: CGPoint(x: -w * 0.6, y: 0.6), control2: CGPoint(x: -w * 0.5, y: -h * 0.3))
        addLine(to: CGPoint(x: w * 0.5, y: -h))
        addCurve(to: CGPoint(x: fw, y: 1.4), control1: CGPoint(x: w * 0.5, y: -h * 0.3), control2: CGPoint(x: w * 0.6, y: 0.6))
        closeSubpath()
    }
}

// MARK: - The species

extension Canopy {
    fileprivate enum FlowerKind { case cup, sakura, flame, azalea, star, tiny }
    fileprivate enum CropKind { case pom, lemon, olive }
    fileprivate enum BarkMark { case none, band, groove, fibre }

    /// What the seed cannot change: the prototype's `SP` table, verbatim.
    fileprivate struct Kind: Sendable {
        /// The wood: stems, the trunk's segments, how limbs fan and fork.
        struct Form: Sendable {
            var stems: Int, stemSpread: Double, segs: Int, trunk, trunkW, taper: Double, limbs: Int, limbsJ, spread, limbLen: Double
            var depth: Int, decay, forkAng, fork3, upright, maxDev, dome, cup, lean, gnarl, bend: Double
        }

        /// The clumps: size, lobes, the outline's droop, how many sit behind
        /// and in front.
        struct Crown: Sendable {
            var R, Rj: Double, lobes: Int, len, w, r0, blunt, body, flat, sweep, rear, inner, lift: Double, acc, tex: Int, front: Double
        }

        struct Bark: Sendable {
            var base, hi, dark: UInt32
            var mark = BarkMark.none
            /// A thin bright strip down smooth bark.
            var glint = false
        }

        struct Flower: Sendable {
            var kind: FlowerKind, per: (Int, Int), size: Double, a, b, c, glow: UInt32
            var anther: UInt32 = 0xF2CF6B
            /// So many flowers that only a few glow and a few stay in bud.
            var dense = false
        }

        struct Crop: Sendable {
            var kind: CropKind, share, size: Double, a, shade, hi, crown: UInt32
        }

        var form: Form
        var can: Crown
        /// Five leaf tones, deep to highlight.
        var ramp: [UInt32]
        /// Cherry's canopy turning to blossom from growth .86, step by step
        /// and weighted, which is where "lots of blossom" comes from without a
        /// thousand flowers.
        var bloomRamp: [UInt32]? = nil
        var bloomW: [Double] = []
        var bark: Bark
        var flower: Flower
        var crop: Crop? = nil
        /// The grown tree's height, and its reach either side of the trunk.
        var H, HW: Double

        // swiftlint:disable line_length
        init(_ species: Species) {
            switch species {
            case .magnolia, .duckling:
                self.init(form: Form(stems: 1, stemSpread: 0, segs: 2, trunk: 44, trunkW: 12.5, taper: 0.62, limbs: 3, limbsJ: 0.5, spread: 0.68, limbLen: 48, depth: 2, decay: 0.78, forkAng: 0.55, fork3: 0.45, upright: 0.08, maxDev: 1.1, dome: 0.12, cup: 0.14, lean: 0.06, gnarl: 0, bend: 0.08),
                          can: Crown(R: 36, Rj: 0.14, lobes: 6, len: 0.7, w: 0.31, r0: 0.52, blunt: 0.45, body: 0.86, flat: 0.78, sweep: 0.55, rear: 0.35, inner: 0.2, lift: 0.3, acc: 1, tex: 1, front: 0.4),
                          ramp: [0x22404A, 0x2D5B4F, 0x3F7A50, 0x659C55, 0xA9C979],
                          bark: Bark(base: 0x5D4B4D, hi: 0xBBA79F, dark: 0x382C31, glint: true),
                          flower: Flower(kind: .cup, per: (1, 2), size: 11, a: 0xEEA2BC, b: 0xFDE6EE, c: 0xC2557F, glow: 0xFFE2EC),
                          H: 226, HW: 200)
            case .cherry:
                self.init(form: Form(stems: 1, stemSpread: 0, segs: 2, trunk: 40, trunkW: 13, taper: 0.62, limbs: 4, limbsJ: 0, spread: 1.0, limbLen: 52, depth: 2, decay: 0.78, forkAng: 0.6, fork3: 0.3, upright: 0, maxDev: 1.3, dome: 0.08, cup: 0.18, lean: 0.05, gnarl: 0.15, bend: 0.1),
                          can: Crown(R: 31, Rj: 0.16, lobes: 7, len: 0.54, w: 0.34, r0: 0.56, blunt: 0.9, body: 0.88, flat: 0.7, sweep: 0.6, rear: 0.4, inner: 0, lift: 0.32, acc: 1, tex: 2, front: 0.36),
                          ramp: [0x2B4550, 0x3F6455, 0x5D8A5B, 0x8AB36A, 0xCFE4A0],
                          bloomRamp: [0x8A4866, 0xC06D8F, 0xE59BB5, 0xF6C3D2, 0xFFF1F5], bloomW: [0.85, 0.95, 1, 1, 1],
                          bark: Bark(base: 0x553739, hi: 0xA07C74, dark: 0x33222A, mark: .band, glint: true),
                          flower: Flower(kind: .sakura, per: (1, 2), size: 7.5, a: 0xFDE4EB, b: 0xFFF6F8, c: 0xD4607F, glow: 0xFFF0F4, anther: 0xF2CF6B),
                          H: 210, HW: 228)
            case .pomegranate:
                self.init(form: Form(stems: 3, stemSpread: 0.26, segs: 2, trunk: 40, trunkW: 8, taper: 0.66, limbs: 2, limbsJ: 0.4, spread: 0.45, limbLen: 40, depth: 2, decay: 0.8, forkAng: 0.5, fork3: 0.2, upright: 0.08, maxDev: 1.1, dome: 0.1, cup: 0.1, lean: 0.05, gnarl: 0.25, bend: 0.08),
                          can: Crown(R: 32, Rj: 0.14, lobes: 8, len: 0.56, w: 0.22, r0: 0.54, blunt: 0.25, body: 0.82, flat: 0.84, sweep: 0.45, rear: 0.55, inner: 0.35, lift: 0.3, acc: 2, tex: 2, front: 0.4),
                          ramp: [0x132B2A, 0x1D4336, 0x2A5F40, 0x408046, 0x93BF6C],
                          bark: Bark(base: 0x4F3B35, hi: 0x9A7C6C, dark: 0x2C201D, mark: .fibre),
                          flower: Flower(kind: .flame, per: (0, 2), size: 9, a: 0xF25A2C, b: 0xFFA060, c: 0xA8281F, glow: 0xFFD0B0, anther: 0xFFD25A),
                          crop: Crop(kind: .pom, share: 0.4, size: 8.5, a: 0xCD2C3F, shade: 0x7C1426, hi: 0xFFB0B0, crown: 0x8D1C2B),
                          H: 204, HW: 190)
            case .azalea:
                self.init(form: Form(stems: 3, stemSpread: 0.5, segs: 2, trunk: 18, trunkW: 7, taper: 0.7, limbs: 2, limbsJ: 0.5, spread: 0.6, limbLen: 34, depth: 2, decay: 0.84, forkAng: 0.6, fork3: 0.35, upright: 0, maxDev: 1.3, dome: 0.12, cup: 0.1, lean: 0.04, gnarl: 0.3, bend: 0.1),
                          can: Crown(R: 34, Rj: 0.12, lobes: 7, len: 0.52, w: 0.32, r0: 0.56, blunt: 0.6, body: 0.92, flat: 0.72, sweep: 0.4, rear: 0.5, inner: 0.5, lift: 0.25, acc: 1, tex: 2, front: 0.42),
                          ramp: [0x16302C, 0x21483B, 0x2F6446, 0x4A874D, 0x8DBB68],
                          bark: Bark(base: 0x4C3B36, hi: 0x927666, dark: 0x2C211E, mark: .fibre),
                          flower: Flower(kind: .azalea, per: (1, 2), size: 9.5, a: 0xD6478F, b: 0xF7A8CD, c: 0xA0275F, glow: 0xFFD6EA, anther: 0xE8A24A, dense: true),
                          H: 172, HW: 210)
            case .lemon:
                self.init(form: Form(stems: 1, stemSpread: 0, segs: 2, trunk: 64, trunkW: 9.5, taper: 0.64, limbs: 3, limbsJ: 0.4, spread: 0.65, limbLen: 32, depth: 2, decay: 0.85, forkAng: 0.65, fork3: 0.3, upright: 0, maxDev: 1.35, dome: 0.06, cup: 0.06, lean: 0.04, gnarl: 0.05, bend: 0.06),
                          can: Crown(R: 36, Rj: 0.1, lobes: 7, len: 0.58, w: 0.3, r0: 0.56, blunt: 0.45, body: 0.92, flat: 0.9, sweep: 0.5, rear: 0.7, inner: 0.7, lift: 0.25, acc: 1, tex: 2, front: 0.4),
                          ramp: [0x1E4A3C, 0x2A6A45, 0x3D8746, 0x5FA24A, 0xB0D06E],
                          bark: Bark(base: 0x5F4C3E, hi: 0xAD9679, dark: 0x382D25, glint: true),
                          flower: Flower(kind: .star, per: (0, 2), size: 6, a: 0xFFF8E6, b: 0xFFFDF5, c: 0xF0C43C, glow: 0xFFF6DC, anther: 0xF0B93C),
                          crop: Crop(kind: .lemon, share: 0.85, size: 8, a: 0xF7D234, shade: 0xD99C10, hi: 0xFFF8C0, crown: 0xA4B43C),
                          H: 214, HW: 180)
            case .olive:
                self.init(form: Form(stems: 1, stemSpread: 0, segs: 3, trunk: 58, trunkW: 16, taper: 0.56, limbs: 3, limbsJ: 0.3, spread: 0.75, limbLen: 40, depth: 2, decay: 0.8, forkAng: 0.6, fork3: 0.25, upright: 0, maxDev: 1.3, dome: 0.08, cup: 0.05, lean: 0.12, gnarl: 1, bend: 0.14),
                          can: Crown(R: 34, Rj: 0.16, lobes: 14, len: 0.46, w: 0.13, r0: 0.62, blunt: 0, body: 0.8, flat: 0.72, sweep: 0.7, rear: 0.5, inner: 0.3, lift: 0.3, acc: 3, tex: 3, front: 0.36),
                          ramp: [0x33463F, 0x4A6057, 0x6A8375, 0x97AD9F, 0xDAE4DB],
                          bark: Bark(base: 0x5D5047, hi: 0xB2A493, dark: 0x382F2A, mark: .groove),
                          flower: Flower(kind: .tiny, per: (0, 1), size: 4, a: 0xF4F0D6, b: 0xFFFBE8, c: 0xD4C77C, glow: 0xFFFBE8),
                          crop: Crop(kind: .olive, share: 0.75, size: 5.6, a: 0x3E2C45, shade: 0x20162A, hi: 0xA796BB, crown: 0x4D5A2A),
                          H: 214, HW: 210)
            }
        }
        // swiftlint:enable line_length

        private init(form: Form, can: Crown, ramp: [UInt32], bloomRamp: [UInt32]? = nil, bloomW: [Double] = [],
                     bark: Bark, flower: Flower, crop: Crop? = nil, H: Double, HW: Double) {
            (self.form, self.can, self.ramp, self.bloomRamp, self.bloomW) = (form, can, ramp, bloomRamp, bloomW)
            (self.bark, self.flower, self.crop, self.H, self.HW) = (bark, flower, crop, H, HW)
        }
    }
}
