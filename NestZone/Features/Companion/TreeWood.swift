import SwiftUI

/// How a tree's bark is marked. Every mark runs with the grain, along the
/// stem, as a thin lens: a mark across it, tilted, is what made the
/// pomegranate's bark read as crisscross X marks in a close-up.
enum BarkStyle {
    /// Long grey-brown strips that shred, a few short flakes lifted pale, knots.
    case shredded
    /// Smooth, with two fine strands and a lit edge. A lemon's.
    case smooth
    /// Twisted ridges, burls in the outline and hollows. An olive's, ancient
    /// from the first stage.
    case gnarled
    /// Smooth with short pale lenticels that wrap round the stem. A cherry's
    /// and, fainter, a magnolia's.
    case lenticel
    /// Fine fibres, a shrub's.
    case fine
}

/// The stems and limbs of a tree: one silhouette with a root flare, a core
/// shadow on the side away from the light and a lit edge on the side towards
/// it, then the bark, then the crown's shade over it. Shared by every tree
/// drawn the pomegranate's way.
struct TreeWood {
    typealias RGB = Canopy.RGB
    let canopy: Canopy
    let pose: Canopy.Pose
    let L: (x: Double, y: Double)
    let tones: Canopy.Tones
    let M: Canopy.Mood
    let style: BarkStyle

    /// The part of a limb from a share `t` of the way along it to its end.
    static func from(_ q: Canopy.Pose.Span, _ t: Double) -> Canopy.Pose.Span {
        var r = q
        let p = along(q, t)
        r.x = p.x
        r.y = p.y
        r.cx = (1 - t) * q.cx + t * q.x1
        r.cy = (1 - t) * q.cy + t * q.y1
        r.w0 = Ink.lerp(q.w0, q.w1, t)
        return r
    }

    /// A point a share `u` of the way along a limb's centre line.
    static func along(_ q: Canopy.Pose.Span, _ u: Double) -> CGPoint {
        let v = 1 - u
        return CGPoint(x: v * v * q.x + 2 * u * v * q.cx + u * u * q.x1, y: v * v * q.y + 2 * u * v * q.cy + u * u * q.y1)
    }

    /// The bark's marks on one limb, in the order they are laid down, each
    /// into the path of its colour.
    private struct Marks {
        var dark = Path(), pale = Path(), flakes = Path(), knots = Path(), hollows = Path(), rims = Path()
    }

    /// One stem and everything that grows from it. A tree of several stems
    /// paints them one after the other, each over the last, because a lit edge
    /// or a bark strand of one drawn across another stem, as the stems cross
    /// low down, reads as a cross.
    private struct Stem {
        var outline = Path(), edge = Path(), core = Path()
        var marks = Marks()
    }

    func paint(_ context: GraphicsContext) {
        let t = tones
        var stems: [Stem] = []
        var owner = Array(repeating: 0, count: canopy.limbs.count)
        var shade = Path(), union = Path()
        // A limb whose end another leaves from keeps its grain short of that end.
        var forks = Set<Int>()
        for nd in canopy.limbs where nd.parent >= 0 { forks.insert(nd.parent) }
        var flare = 0.0, any = false
        for (i, nd) in canopy.limbs.enumerated() {
            guard let q = pose.limbs[i] else { continue }
            any = true
            let root = nd.parent < 0
            if root {
                owner[i] = stems.count
                stems.append(Stem())
            } else {
                owner[i] = owner[nd.parent]
            }
            let k = owner[i]
            if root { flare = max(flare, q.w0) }
            stems[k].outline.limb(q, q.w0, q.w1, 0, flat: root)
            let am = atan2(q.y1 - q.y, q.x1 - q.x)
            let side: Double = sin(am) * L.x - cos(am) * L.y > 0 ? -1 : 1
            // A limb's own light and shade start a little way out from the fork, so they
            // do not lie across the stem it leaves in a cross or a thread.
            let lit = nd.depth >= 1 ? Self.from(q, 0.3) : q
            stems[k].edge.limb(lit, lit.w0 * 0.26, lit.w1 * 0.2, side * 0.34, flat: root)
            stems[k].core.limb(lit, lit.w0 * 0.34, lit.w1 * 0.3, -side * 0.3, flat: root)
            if style == .gnarled && nd.depth == 0 && q.g > 0.5 { burls(&stems[k].outline, q, i, am) }
            guard nd.depth <= 1 && q.w0 > 2.2 else { continue }
            grain(&stems[k].marks, q, nd, i, am, side, root: root, forks: forks.contains(i))
        }
        guard any else { return }
        stems[0].outline.flare(flare)
        for (j, spot) in pose.clumps.enumerated() {
            guard let q = spot, !canopy.clumps[j].tuft, canopy.clumps[j].tier > 0 else { continue }
            shade.oval(q.x + q.R * 0.08, q.y + q.R * 0.42, q.R * 0.8, q.R * 0.7)
        }

        let fade = Gradient(stops: [.init(color: t.barkDark.color(), location: 0), .init(color: t.bark.color(), location: 0.55),
                                    .init(color: t.bark.shifted(3).color(), location: 1)])
        let shine = Gradient(stops: [.init(color: t.barkHi.color(0.35), location: 0), .init(color: t.barkHi.color(0.75), location: 0.5),
                                     .init(color: t.barkHi.color(0.95), location: 1)])
        let inner = t.barkDark.mix(RGB(0x120C0A), 0.55)
        for stem in stems {
            union.addPath(stem.outline)
            context.fill(stem.outline, with: .linearGradient(fade, startPoint: CGPoint(x: 0, y: pose.bottom * 0.65 + pose.top * 0.35), endPoint: .zero))
            context.fill(stem.core, with: .color(t.barkDark.color(0.55)))
            context.fill(stem.edge, with: .linearGradient(shine, startPoint: CGPoint(x: 0, y: pose.top), endPoint: .zero))
            let m = stem.marks
            if !m.dark.isEmpty { context.fill(m.dark, with: .color(t.barkDark.color(style == .gnarled ? 0.7 : 0.55))) }
            if !m.pale.isEmpty { context.fill(m.pale, with: .color(t.barkHi.color(0.5))) }
            if !m.flakes.isEmpty { context.fill(m.flakes, with: .color(t.barkHi.shifted(6).color(0.42))) }
            if !m.knots.isEmpty { context.fill(m.knots, with: .color(t.barkDark.color(0.85))) }
            if !m.hollows.isEmpty {
                // A hollow is the darkest thing on the tree, with a lit lip below.
                context.fill(m.hollows, with: .color(inner.color(0.96)))
                context.fill(m.rims, with: .color(t.barkHi.shifted(4).color(0.62)))
            }
        }
        guard !shade.isEmpty else { return }
        let deep = t.ramp[0].mix(RGB(0x122027), 0.35).shifted(-10)
        let under = Gradient(colors: [deep.color(0.42 * (1 - 0.3 * M.doze)), deep.color(0.12)])
        var c = context
        c.clip(to: union)
        c.fill(shade, with: .linearGradient(under, startPoint: CGPoint(x: 0, y: (pose.top + pose.bottom) / 2), endPoint: CGPoint(x: 0, y: pose.bottom + 20)))
    }

    // MARK: The grain

    /// A point on a limb: `u` along it, `f` of its width across it.
    private func spot(_ q: Canopy.Pose.Span, _ u: Double, _ f: Double, _ n: CGPoint) -> CGPoint {
        let c = Self.along(q, u), w = Ink.lerp(q.w0, q.w1, u)
        return CGPoint(x: c.x + n.x * f * w, y: c.y + n.y * f * w)
    }

    /// A thin lens along the grain from `u0` to `u1`, at `f0` across at the
    /// start and `f1` at the end, `half` of a unit thick at its belly.
    private func strand(_ span: ClosedRange<Double>, _ into: inout Path, _ q: Canopy.Pose.Span, _ n: CGPoint, _ u0: Double, _ u1: Double, _ f0: Double, _ f1: Double, _ half: Double) {
        // Where a limb leaves its parent the two sets of grain would cross, and a
        // cross is what the eye reads: a limb's own marks start a little way out.
        let u0 = max(u0, span.lowerBound), u1 = min(u1, span.upperBound)
        guard u1 - u0 > 0.05 else { return }
        let a = spot(q, u0, f0, n), b = spot(q, u1, f1, n), m = spot(q, (u0 + u1) / 2, (f0 + f1) / 2, n)
        let dx = b.x - a.x, dy = b.y - a.y, d = max(1e-6, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / d * half, ny = dx / d * half
        into.move(to: a)
        into.addQuadCurve(to: b, control: CGPoint(x: m.x + nx, y: m.y + ny))
        into.addQuadCurve(to: a, control: CGPoint(x: m.x - nx * 0.7, y: m.y - ny * 0.7))
        into.closeSubpath()
    }

    private func grain(_ m: inout Marks, _ q: Canopy.Pose.Span, _ nd: Canopy.Limb, _ i: Int, _ am: Double, _ side: Double, root: Bool, forks: Bool) {
        let n = CGPoint(x: -sin(am), y: cos(am))
        let thick = q.w0 > 4
        // Where grain may run along this limb: not up to the fork it leaves, nor into the one at its end.
        let lo = (root ? 0.0 : nd.depth >= 1 ? 0.28 : 0.16)...(forks ? 0.84 : 0.97)
        // Every limb is marked a little differently, from its own number.
        let h = Double((i * 37 + 11) % 17) / 17
        func into(_ f: Double) -> WritableKeyPath<Marks, Path> { (f < 0) == (side < 0) ? \.pale : \.dark }
        switch style {
        case .shredded:
            // Long strips, a little wavy, in broken lengths that overlap, so
            // the bark looks shredded along the stem and never cross-hatched.
            for (k, f) in [-0.3, 0.02, 0.3].enumerated() where thick || k == 1 {
                let lead = (h + Double(k) * 0.31).truncatingRemainder(dividingBy: 1) * 0.16
                var u = lead
                var j = 0
                while u < 0.94 {
                    let len = 0.3 + 0.1 * Double((j + k) % 3)
                    let u1 = min(0.98, u + len), drift = 0.05 * sin(Double(j) * 2.1 + h * 6)
                    strand(lo, &m[keyPath: into(f)], q, n, u, u1, f + drift, f - drift * 0.6, 0.42)
                    u = u1 + 0.05 + 0.06 * Double((j + i) % 2)
                    j += 1
                }
            }
            // Short flakes, lifted: along the grain, never across it.
            var u = 0.12 + 0.05 * h
            var j = 0
            while u < 0.88 {
                let f = Double((j * 5 + i) % 7 - 3) * 0.11
                strand(lo, &m.flakes, q, n, u, u + 0.09, f, f + 0.05, 0.5)
                u += thick ? 0.17 : 0.3
                j += 1
            }
            if nd.depth == 0 && !root && q.g > 0.9 && thick {
                let c = Self.along(q, 0.46), w = Ink.lerp(q.w0, q.w1, 0.46)
                m.knots.oval(c.x + n.x * w * 0.1, c.y + n.y * w * 0.1, w * 0.14, w * 0.22, am)
            }
        case .smooth:
            // Fine strands in broken lengths, pale on the lit side and dark on the
            // other, the way a smooth bark splits into long fissures as it ages.
            for (k, f) in [-0.34, -0.12, 0.14, 0.34].enumerated() where thick || k % 2 == 1 {
                var u = 0.04 + 0.12 * ((h + Double(k) * 0.27).truncatingRemainder(dividingBy: 1))
                var j = 0
                while u < 0.92 {
                    let u1 = min(0.97, u + 0.22 + 0.12 * Double((j + k) % 3) / 2)
                    strand(lo, &m[keyPath: into(f)], q, n, u, u1, f, f + 0.03 * Double(j % 3 - 1), 0.34)
                    u = u1 + 0.05 + 0.05 * Double((j + i) % 2)
                    j += 1
                }
            }
            if nd.depth == 0 && !root && q.g > 0.9 && thick && i % 2 == 0 {
                let c = Self.along(q, 0.5), w = Ink.lerp(q.w0, q.w1, 0.5)
                m.knots.oval(c.x + n.x * w * 0.12, c.y + n.y * w * 0.12, w * 0.09, w * 0.14, am)
            }
        case .gnarled:
            // Ridges that twist: strands that wander across the stem and come
            // back, three of them out of step.
            for (k, f) in [-0.3, 0.0, 0.3].enumerated() where thick || k != 0 {
                var u = 0.04 + 0.1 * Double((k + i) % 3) / 3
                var j = 0
                while u < 0.94 {
                    let u1 = min(0.97, u + 0.26 + 0.06 * Double(j % 2))
                    let w0 = f + 0.2 * sin(u * 7 + Double(k) * 2 + h * 5), w1 = f + 0.2 * sin(u1 * 7 + Double(k) * 2 + h * 5)
                    strand(lo, &m[keyPath: into(f)], q, n, u, u1, max(-0.42, min(0.42, w0)), max(-0.42, min(0.42, w1)), 0.55)
                    u = u1 + 0.04
                    j += 1
                }
            }
            // The trunk has one hollow, and a second on the thickest stem; the
            // limbs have none.
            if nd.depth == 0 && q.g > 0.55 {
                if root && q.w0 > 6 {
                    hollow(&m, q, n, am, side, 0.45, 1)
                } else if !root && nd.parent >= 0 && canopy.limbs[nd.parent].parent < 0 && q.w0 > 5 {
                    hollow(&m, q, n, am, -side, 0.5, 0.55)
                }
            }
        case .lenticel:
            // Short pale marks that wrap round the stem, a few at a time and
            // never all at one height.
            var u = max(lo.lowerBound, 0.1 + 0.05 * h)
            var j = 0
            while u < min(0.92, lo.upperBound) {
                let w = Ink.lerp(q.w0, q.w1, u), half = 0.28 + 0.12 * Double(j % 2)
                let c = Self.along(q, u), off = (j % 2 == 0 ? -0.12 : 0.14)
                let a = CGPoint(x: c.x + n.x * w * (off - half) , y: c.y + n.y * w * (off - half))
                let b = CGPoint(x: c.x + n.x * w * (off + half), y: c.y + n.y * w * (off + half))
                let dx = b.x - a.x, dy = b.y - a.y
                // Bowed with the surface: the middle sits a hair further along.
                let along = CGPoint(x: -n.y * 0.9, y: n.x * 0.9)
                m.pale.move(to: a)
                m.pale.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 + along.x + dy * 0.02, y: (a.y + b.y) / 2 + along.y - dx * 0.02))
                m.pale.addQuadCurve(to: a, control: CGPoint(x: (a.x + b.x) / 2 - along.x * 0.2, y: (a.y + b.y) / 2 - along.y * 0.2))
                m.pale.closeSubpath()
                u += thick ? 0.12 : 0.2
                j += 1
            }
            if thick { strand(lo, &m.dark, q, n, 0.1, 0.9, side * 0.3, side * 0.3, 0.3) }
        case .fine:
            strand(lo, &m.dark, q, n, 0.06, 0.94, -side * 0.2, -side * 0.24, 0.3)
            if thick { strand(lo, &m.pale, q, n, 0.1, 0.8, side * 0.2, side * 0.18, 0.28) }
        }
    }

    /// Bulges in the silhouette of an old stem: the olive is never a straight,
    /// smooth pipe, however young.
    private func burls(_ outline: inout Path, _ q: Canopy.Pose.Span, _ i: Int, _ am: Double) {
        let n = CGPoint(x: -sin(am), y: cos(am))
        for (k, u) in [0.22, 0.5, 0.78].enumerated() {
            let w = Ink.lerp(q.w0, q.w1, u), c = Self.along(q, u)
            let s = (k + i) % 2 == 0 ? 1.0 : -1
            let ox = c.x + n.x * s * w * 0.34, oy = c.y + n.y * s * w * 0.34
            outline.oval(ox, oy, w * 0.22, w * (0.26 + 0.06 * Double((i + k) % 3)), am)
        }
    }

    /// A hollow in the trunk: an arched opening, pointed at the top and wide at
    /// the foot, with a lit lip along its lower edge where the wood has grown
    /// round it.
    private func hollow(_ m: inout Marks, _ q: Canopy.Pose.Span, _ n: CGPoint, _ am: Double, _ side: Double, _ u: Double, _ size: Double) {
        let c = Self.along(q, u), w = Ink.lerp(q.w0, q.w1, u)
        let A = CGPoint(x: cos(am), y: sin(am))
        let bw = w * 0.2 * size, hh = w * 0.38 * size
        // A point `a` along the stem from the hollow's middle and `v` across.
        func P(_ a: Double, _ v: Double) -> CGPoint {
            CGPoint(x: c.x + n.x * w * 0.04 + A.x * a + n.x * v, y: c.y + n.y * w * 0.04 + A.y * a + n.y * v)
        }
        m.hollows.move(to: P(-hh * 0.8, -bw))
        m.hollows.addQuadCurve(to: P(hh, side * bw * 0.15), control: P(hh * 0.1, -bw * 1.7))
        m.hollows.addQuadCurve(to: P(-hh * 0.8, bw), control: P(hh * 0.1, bw * 1.7))
        m.hollows.addQuadCurve(to: P(-hh * 0.8, -bw), control: P(-hh * 1.15, 0))
        m.hollows.closeSubpath()
        // The lip: a thin crescent hugging the foot of the opening.
        m.rims.move(to: P(-hh * 0.78, -bw * 1.02))
        m.rims.addQuadCurve(to: P(-hh * 0.78, bw * 1.02), control: P(-hh * 1.3, 0))
        m.rims.addQuadCurve(to: P(-hh * 0.78, -bw * 1.02), control: P(-hh * 1.08, 0))
        m.rims.closeSubpath()
    }
}
