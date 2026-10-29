import SwiftUI

/// What the trees drawn the pomegranate's way share, once: the pose, the
/// light, the four classes of leaf, one clump painted back to front with room
/// for the species' own fruit between the classes, the soft pools of sun, the
/// whip of a young tree and the seed leaves. A species is a `TreeArt` that
/// holds one of these and adds what is its own: its wood, its blossoms, its
/// fruit and the small things on its soil.
///
/// The rules are in `Docs/Companion/art/RULES.md`.
struct TreeCore {
    typealias RGB = Canopy.RGB
    typealias Paint = PomegranatePainter.LeafInk

    let canopy: Canopy
    let p, day, night: Double
    let M: Canopy.Mood
    let pose: Canopy.Pose
    let tones: Canopy.Tones
    /// Towards the light, a unit vector, y up negative.
    let L: (x: Double, y: Double)
    let light: TreeInk.Light
    let inks: [Paint]
    let art: LeafArt
    let spec: LeafSpec
    /// The colour of a leaf turned over, by tier, for a tree whose leaves have
    /// another colour underneath. Empty when there is none.
    var under: [Color] = []

    /// `tones` are the species' own (an olive's leaf tops are a darker ramp than
    /// its silver undersides); `fresh` is the colour new growth leans towards.
    init(_ canopy: Canopy, growth: Double, mood: Double, day: Double, light lightSide: Double, tones: Canopy.Tones, M: Canopy.Mood, fresh: UInt32,
         rimBase: RGB? = nil, rimK: Double = 0.65) {
        self.canopy = canopy
        p = growth
        self.day = day
        night = 1 - day
        self.M = M
        let pose = Self.calmed(Canopy.Pose(canopy, growth: growth, mood: M), canopy, M)
        self.pose = canopy.kind.form.stems > 1 ? PomegranatePainter.Look.splayed(pose, growth: growth) : pose
        self.tones = tones
        light = TreeInk.Light(light: lightSide, day: day)
        L = light.L
        inks = TreeInk.leafInks(tones, M, day: day, light: light, fresh: fresh, rimBase: rimBase, rimK: rimK)
        art = LeafArt.of(canopy, mood: mood, light: lightSide, day: day)
        spec = art.spec
    }

    /// A thirsty or sleepy tree is the same tree: the limbs droop and the leaves pale, but the
    /// crown keeps most of its size and its place. The shared pose shrinks a clump by a fifth and
    /// lets it sink and slide, which for a crown of few leaves left bare limbs; this takes back
    /// three fifths of that.
    static func calmed(_ pose: Canopy.Pose, _ canopy: Canopy, _ M: Canopy.Mood) -> Canopy.Pose {
        guard canopy.species != .pomegranate, M.thirst + M.doze > 0.01 else { return pose }
        var pose = pose
        let was = 1 + 0.07 * M.glow - 0.2 * M.thirst - 0.16 * M.doze, now = 1 + 0.07 * M.glow - 0.08 * M.thirst - 0.064 * M.doze
        let sag = 0.26 * M.wilt + 0.1 * M.thirst + 0.22 * M.doze - 0.1 * M.glow, sideways = 0.2 * M.wilt + 0.08 * M.doze
        for (i, c) in canopy.clumps.enumerated() {
            guard var q = pose.clumps[i], let limb = pose.limbs[c.node] else { continue }
            let lean = limb.x1 + c.ox, side = lean > 0 ? 1.0 : lean < 0 ? -1 : 1
            q.R *= now / was
            q.y -= 0.6 * c.R * max(0, sag)
            q.x -= side * 0.6 * c.R * sideways
            pose.clumps[i] = q
        }
        return pose
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

    // MARK: One clump

    /// The disc a clump's shadow is poured into, in the clump's units.
    private static let shadowDisc: Path = {
        var disc = Path()
        disc.oval(0, 0.4, 0.85, 0.85)
        return disc
    }()

    /// What a species draws into a clump between its leaf classes: the fruit
    /// sunk deepest (after the shade), the ordinary fruit (after the middle
    /// leaves) and what goes over everything (the leaves across a fruit, a
    /// cloud of blossom).
    struct Between {
        var deep: ((Paint) -> Void)?
        var mid: ((Paint) -> Void)?
        var over: ((Paint) -> Void)?
    }

    /// One clump, back to front: the shade it casts on what is behind, a dark
    /// body, then the leaves by class, shade first. `scale` is how much of the
    /// clump's leaves are out (1 whole; a magnolia holds its leaves back while
    /// it flowers).
    func clump(_ tree: GraphicsContext, _ i: Int, scale: Double = 1, _ between: (Paint, Canopy.Pose.Spot) -> Between = { _, _ in Between() }) {
        guard let placed = pose.clumps[i] else { return }
        // With few leaves out the clump is on its limb's tip, not beside it.
        let q = settle(placed, leaf: scale)
        let c = canopy.clumps[i], tier = c.tier
        // The first tuft up a young stem would hide the bare cane: leave it out.
        if c.tuft && canopy.limbs[c.node].parent < 0 && canopy.limbs[c.node].depth == 0 && p < 0.55 { return }
        let fresh = c.tuft || p - c.birth < 0.05
        let ink = inks[tier * 2 + (fresh ? 1 : 0)]
        let leaves = art.clump(i)
        let hooks = between(ink, q)
        let k = scale

        var g = tree
        g.translateBy(x: q.x, y: q.y)
        g.scaleBy(x: q.R * k, y: q.R * k)
        if k > 0.05 {
            if leaves.casts {
                g.fill(Self.shadowDisc, with: .radialGradient(ink.shadow, center: CGPoint(x: 0, y: 0.4), startRadius: 0, endRadius: 0.85))
            }
            if !leaves.body.isEmpty { g.fill(leaves.body, with: .color(ink.body)) }
            g.fill(leaves.d, with: .color(ink.d))
        }
        hooks.deep?(ink)
        if k > 0.05 {
            g.fill(leaves.m, with: tier == 2
                   ? .linearGradient(Gradient(colors: [ink.mLit, ink.mShade]), startPoint: CGPoint(x: L.x * 0.9, y: L.y * 0.9), endPoint: CGPoint(x: -L.x * 0.9, y: -L.y * 0.9))
                   : .color(ink.m))
        }
        hooks.mid?(ink)
        if k > 0.05 {
            if !leaves.u.isEmpty, tier < under.count { g.fill(leaves.u, with: .color(under[tier])) }
            g.fill(leaves.l, with: .color(ink.l))
            if !leaves.s.isEmpty { g.fill(leaves.s, with: .color(ink.s)) }
            if !leaves.rim.isEmpty { g.fill(leaves.rim, with: .color(ink.rim)) }
        }
        hooks.over?(ink)
    }

    /// Patches of sun on the front of the crown: a soft pool of light poured
    /// over the sunniest of the front clumps, so the lit leaves under it read
    /// as one patch of light and not as a scatter of pale leaves.
    func dapple(_ tree: GraphicsContext) {
        let moon = light.moon
        let alpha = (0.11 * day + 0.1 * light.dusk + 0.08 * night * (1 - 0.56 * moon)) * (1 - 0.4 * M.doze) * (1 - 0.5 * M.thirst) * (0.6 + 0.4 * M.glow)
        guard alpha > 0.02, p > 0.85 else { return }
        let glow = light.glow
        for (i, off) in art.pools {
            guard let q = pose.clumps[i] else { continue }
            let centre = CGPoint(x: q.x + (L.x * 0.28 + off.x) * q.R, y: q.y + (L.y * 0.3 + off.y) * q.R)
            var pool = Path()
            pool.oval(centre.x, centre.y, q.R * 0.65, q.R * 0.55)
            tree.fill(pool, with: .radialGradient(Gradient(colors: [glow.color(alpha), glow.color(alpha * 0.4), glow.color(0)]),
                                                  center: centre, startRadius: 0, endRadius: q.R * 0.65))
        }
    }

    // MARK: The whip

    /// A young tree is a few slender canes with leaves along them, set well
    /// apart so the cane shows between, and a tuft at each tip. The leaves are
    /// drawn on the limbs themselves and shrink away as the crown's own clumps
    /// take over (from about .5 to .72).
    func youngSprigs(_ tree: GraphicsContext, from: Double = 0.5, span: Double = 0.22) {
        let young = 1 - Ink.smooth((p - from) / span)
        guard young > 0.02 else { return }
        let ink = inks[5]
        var shade = Path(), middle = Path(), lit = Path(), rim = Path(), flip = Path()
        let shape = spec.shape, hwK = spec.hw * 1.18
        func leaf(_ x: Double, _ y: Double, _ a: Double, _ len: Double, _ n: Int) {
            let ca = cos(a), sa = sin(a), face = ca * L.x + sa * L.y
            let bend = (ca >= 0 ? 1.0 : -1) * (0.1 + 0.2 * M.wilt)
            let side = (-sa * L.x + ca * L.y) >= 0 ? 1.0 : -1
            if spec.silver > 0 && (n * 7) % 5 < 2 {
                flip.blade(shape, x, y, ca, sa, len, len * hwK, bend)
            } else if face > 0.3 {
                lit.blade(shape, x, y, ca, sa, len, len * hwK, bend)
                rim.lanceEdge(x, y, ca, sa, len, len * hwK, bend, side)
            } else if face > -0.35 {
                middle.blade(shape, x, y, ca, sa, len, len * hwK, bend)
            } else {
                shade.blade(shape, x, y, ca, sa, len, len * hwK, bend)
            }
        }
        var count = 0
        for (i, node) in canopy.limbs.enumerated() {
            guard let q = pose.limbs[i] else { continue }
            let dx = q.x1 - q.x, dy = q.y1 - q.y, span = (dx * dx + dy * dy).squareRoot()
            guard span > 3 else { continue }
            let am = atan2(dy, dx)
            // Leaves shrink with the cane's growth and with the crown taking over.
            let size = max(7, min(16, span * 0.5)) * (0.45 + 0.55 * q.g) * young.squareRoot() * (spec.size / 0.72)
            let pairs = 2
            for n in 0..<pairs {
                let u = node.depth == 0 ? 0.5 + 0.34 * Double(n) : (Double(n) + 1) / (Double(pairs) + 0.6) * 0.9
                let c = TreeWood.along(q, u)
                let spread = 1.15 - 0.25 * u
                let s = size * (1 - 0.25 * u)
                count += 1
                if spec.alternate {
                    leaf(c.x, c.y, am + (n % 2 == 0 ? -spread : spread), s, count)
                } else {
                    leaf(c.x, c.y, am - spread, s, count)
                    leaf(c.x, c.y, am + spread + (n % 2 == 0 ? 0.1 : -0.1), s * 0.95, count + 1)
                }
            }
            // The cane's growing end: a pair and a leaf.
            leaf(q.x1, q.y1, am - 0.55, size * 0.8, count + 2)
            leaf(q.x1, q.y1, am + 0.55, size * 0.8, count + 3)
            leaf(q.x1, q.y1, am, size * 0.85, count + 4)
        }
        guard !(shade.isEmpty && middle.isEmpty && lit.isEmpty && flip.isEmpty) else { return }
        tree.fill(shade, with: .color(ink.d))
        tree.fill(middle, with: .color(ink.m))
        if !flip.isEmpty, let u = under.last { tree.fill(flip, with: .color(u)) }
        tree.fill(lit, with: .color(ink.l))
        tree.fill(rim, with: .color(ink.rim))
    }

    // MARK: The seed, and the seed leaves

    /// What a species' seed looks like on the soil.
    struct Seed {
        var hex: (UInt32, UInt32, UInt32)
        var rx = 4.6, ry = 3.2, rot = -0.5
    }

    /// The seed, early on, and the leaves a thirsty or sleepy tree has let go
    /// of, unscaled on the soil; then whatever else the species keeps there.
    func ground(_ context: GraphicsContext, seed style: Seed, leaf: (hw: Double, bend: Double), extras: (GraphicsContext) -> Void) {
        let t = tones
        let ks = 1 - Ink.smooth((p - 0.085) / 0.04)
        if ks > 0 {
            var seed = Path(), shine = Path()
            seed.oval(0, -3, style.rx * ks, style.ry * ks, style.rot)
            shine.oval(-style.rx * 0.28 * ks, -4 * ks, style.rx * 0.32 * ks, style.ry * 0.25 * ks, style.rot)
            let flesh = Gradient(colors: [RGB.tone(style.hex.0, day: day).color(), RGB.tone(style.hex.1, day: day).color()])
            context.fill(seed, with: .linearGradient(flesh, startPoint: CGPoint(x: -4, y: -6), endPoint: CGPoint(x: 4, y: 0)))
            context.fill(shine, with: .color(RGB.tone(style.hex.2, day: day).color(0.85)))
        }
        let strewn = Int((10 * Ink.clamp(0.55 * M.thirst + 0.12 * M.doze) + 0.5).rounded(.down))
        let count = max(strewn, p > 0.45 ? 1 : 0)
        var leaves = Path()
        for f in canopy.fallen.prefix(count) {
            let ca = cos(f.a), sa = sin(f.a)
            leaves.blade(spec.shape, f.x - ca * f.len / 2, f.y - sa * f.len / 2 * 0.4, ca, sa * 0.4, f.len, f.len * leaf.hw, leaf.bend)
        }
        if !leaves.isEmpty {
            let dry = Gradient(colors: [t.fallen.color(), t.fallen.shifted(-8, 6).color()])
            context.fill(leaves, with: .linearGradient(dry, startPoint: CGPoint(x: -40, y: -3), endPoint: CGPoint(x: 40, y: 3)))
        }
        extras(context)
    }

    /// Two seed leaves at the tip of the first stem, with a lit half each.
    /// `len` and `hw` are in points; `tint` colours them.
    func seedLeaves(_ context: GraphicsContext, len: Double, hw: Double, shape: LeafSpec.Shape, wide: Double = 1.15) {
        let kc = Ink.back((p - 0.09) / 0.05) * (1 - Ink.smooth((p - 0.3) / 0.1))
        guard kc > 0, let root = canopy.limbs.indices.first(where: { canopy.limbs[$0].parent < 0 && pose.limbs[$0] != nil }),
              let q = pose.limbs[root] else { return }
        let ink = inks[5]
        var full = Path(), lit = Path()
        for s in [-1.0, 1] {
            let a = -Double.pi / 2 + s * (wide + 0.4 * M.wilt - 0.15 * M.glow)
            full.blade(shape, q.x1, q.y1, cos(a), sin(a), len * kc, hw * kc, s * 0.1)
            lit.lance(q.x1, q.y1, cos(a), sin(a), len * kc, hw * kc, s * 0.1, (-sin(a) * L.x + cos(a) * L.y) >= 0 ? 1 : -1)
        }
        context.fill(full, with: .color(ink.m))
        context.fill(lit, with: .color(ink.s))
    }
}

// MARK: - Drawing a tree

/// A species drawn the pomegranate's way: its own wood, clumps, blossoms,
/// fruit and soil, in the order every tree is painted.
protocol TreeArt {
    var core: TreeCore { get }
    var canopy: Canopy { get }
    func ground(_ context: GraphicsContext)
    func wood(_ context: GraphicsContext)
    func clump(_ tree: GraphicsContext, _ i: Int)
    func blossoms(_ tree: GraphicsContext, _ tier: Int)
    /// After every clump of the front tier: the fruit that is cut open.
    func late(_ tree: GraphicsContext)
    /// Whether soft pools of sun are poured over the front of the crown.
    var dappled: Bool { get }
    /// What the species carries away from its leaves, to be held by a twig from
    /// the limb's tip (`TreeCore.hang`); also what the attach audit checks.
    func hung(_ s: inout TreeCore.Sprigs)
    /// How much of a clump's leaves are out (1 is all of them).
    var leafK: Double { get }
    /// The leaves along a young tree's canes.
    func young(_ tree: GraphicsContext)
    func seedLeaves(_ tree: GraphicsContext)
    /// Last, over the whole tree: a petal on its way down.
    func finish(_ tree: GraphicsContext)
}

extension TreeArt {
    func late(_ tree: GraphicsContext) {}
    var leafK: Double { 1 }
    /// A tree whose leaves are all out when it flowers and fruits (a lemon, an
    /// olive) hangs them within its leaves; the audit still checks them.
    func hung(_ s: inout TreeCore.Sprigs) { core.noteCrop(&s) }
    var dappled: Bool { true }
    func young(_ tree: GraphicsContext) { core.youngSprigs(tree) }
    func finish(_ tree: GraphicsContext) {}

    /// The caller's context sits at the trunk's base on the soil, up negative.
    func render(_ context: GraphicsContext) {
        ground(context)
        var tree = context
        tree.scaleBy(x: canopy.fit, y: canopy.fit)
        let order = core.order()
        var n = 0
        for tier in 0..<3 {
            while n < order.count && canopy.clumps[order[n]].tier == tier {
                clump(tree, order[n])
                n += 1
            }
            if tier == 0 {
                wood(tree)
                var sprigs = TreeCore.Sprigs()
                hung(&sprigs)
                core.twigs(tree, sprigs)
                young(tree)
            } else {
                if tier == 2 {
                    if dappled { core.dapple(tree) }
                    late(tree)
                }
                blossoms(tree, tier)
            }
        }
        seedLeaves(tree)
        finish(tree)
        #if DEBUG
        if TreeDebug.wood { TreeAudit.overlay(self, tree) }
        #endif
    }
}
