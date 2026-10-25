import SwiftUI

/// The azalea, drawn as itself: a dense, low shrub with small glossy leaves,
/// and over it so many funnel flowers that the leaves are glimpsed between
/// them. Each flower is five rounded lobes round a paler throat that is spotted
/// with dark, with stamens standing out of it; they are lit like the leaves, so
/// the sun's side of the shrub is bright and the inside of it is a dusky
/// magenta. Painted the way the pomegranate is (`TreeCore`), a still picture
/// drawn only when the state changes.
struct AzaleaPainter: TreeArt {
    typealias RGB = Canopy.RGB

    let canopy: Canopy
    let core: TreeCore
    let bloom: BloomArt?

    init(canopy: Canopy, growth: Double, mood: Double, day: Double, light: Double) {
        let M = Canopy.Mood(mood)
        self.canopy = canopy
        let tones = Canopy.Tones(canopy.kind, M, day: day, growth: growth)
        core = TreeCore(canopy, growth: growth, mood: mood, day: day, light: light, tones: tones, M: M, fresh: 0xB4C86A)
        bloom = BloomArt.of(canopy, leaves: core.art, mood: mood, light: light, day: day)
    }

    func draw(_ context: GraphicsContext) { render(context) }

    /// The flowers are the light on this shrub; a wash of sun over them is a haze.
    var dappled: Bool { false }

    func wood(_ context: GraphicsContext) {
        TreeWood(canopy: canopy, pose: core.pose, L: core.L, tones: core.tones, M: core.M, style: .fine).paint(context)
    }

    func blossoms(_ tree: GraphicsContext, _ tier: Int) {}

    /// How open the flowers are: from about .55, all through the budding stage;
    /// a thirsty shrub keeps them shut.
    var open: Double { Ink.smooth((core.p - 0.55) / 0.28) * Ink.smooth((core.M.open - 0.12) / 0.5) }

    func clump(_ tree: GraphicsContext, _ i: Int) {
        core.clump(tree, i)
    }

    /// The flowers of every clump, back to front, over the whole shrub: it is
    /// covered in them, and its leaves are seen between.
    func late(_ tree: GraphicsContext) {
        for i in core.order() {
            if let q = core.pose.clumps[i] { flowers(tree, i, q) }
        }
    }

    // MARK: The flowers

    /// One clump's flowers, over its leaves: four classes of the corolla by the
    /// light, the pale throat of each, its dark spots, and on the sunlit ones the
    /// stamens. Before they open the same places are small pointed buds.
    func flowers(_ tree: GraphicsContext, _ i: Int, _ q: Canopy.Pose.Spot) {
        guard let bloom, core.p > 0.45 else { return }
        let open = self.open, buds = Ink.smooth((core.p - 0.45) / 0.1) * (1 - open)
        guard open > 0.02 || buds > 0.02 else { return }
        let art = bloom.clump(i)
        guard art.count > 0 else { return }
        let t = core.tones, moon = core.light.moon, L = core.L
        let cool = RGB(0xB8A0E0)
        func tint(_ c: RGB) -> RGB { c.mix(cool, 0.22 * moon).mix(RGB(0x2A1A4A), 0.28 * moon) }
        var g = tree
        g.translateBy(x: q.x, y: q.y)
        g.scaleBy(x: q.R, y: q.R)
        if buds > 0.02 { g.fill(art.buds, with: .color(tint(t.bc.mix(t.ba, 0.2)).color(buds * (1 - 0.4 * core.M.thirst)))) }
        guard open > 0.02 else { return }
        // A hair of shade on the far side of every flower parts it from the next.
        var shade = g
        shade.translateBy(x: -L.x * 0.011, y: -L.y * 0.011)
        if !art.all.isEmpty { shade.fill(art.all, with: .color(tint(t.bc.mix(t.ba, 0.55)).color(open * 0.85))) }
        if !art.d.isEmpty { g.fill(art.d, with: .color(tint(t.bc.mix(t.ba, 0.45)).color(open))) }
        if !art.m.isEmpty { g.fill(art.m, with: .color(tint(t.ba.mix(t.bc, 0.1)).color(open))) }
        if !art.l.isEmpty { g.fill(art.l, with: .color(tint(t.ba.mix(t.bb, 0.5)).color(open))) }
        if !art.s.isEmpty { g.fill(art.s, with: .color(tint(t.bb).color(open))) }
        if !art.hearts.isEmpty { g.fill(art.hearts, with: .color(tint(t.bb.mix(RGB(0xFFFFFF), 0.35)).color(0.38 * open))) }
        if !art.heartsLit.isEmpty { g.fill(art.heartsLit, with: .color(tint(t.bc.mix(t.ba, 0.3)).color(0.5 * open))) }
        if !art.spots.isEmpty { g.fill(art.spots, with: .color(tint(t.bc.mix(RGB(0x5A0F34), 0.35)).color(0.9 * open))) }
        if !art.fine.isEmpty { g.fill(art.fine, with: .color(t.anther.mix(t.bb, 0.25).color(0.92 * open))) }
    }

    // MARK: On the soil, and a sprout

    /// The seed, a dark speck, early on; then the small things a pot collects:
    /// a leaf, and a whole flower that has come down, spotted throat up.
    func ground(_ context: GraphicsContext) {
        let day = core.day, p = core.p, t = core.tones
        let open = self.open
        core.ground(context, seed: TreeCore.Seed(hex: (0x5A483C, 0x2E221A, 0xA89684), rx: 2.6, ry: 1.7, rot: -0.3), leaf: (0.22, 0.1)) { context in
            guard p > 0.72, open > 0.3, canopy.fallen.count > 4 else { return }
            let f = canopy.fallen[4], x = f.x * 0.5, y = f.y * 0.6 - 0.8, r = 4.2
            var corolla = Path(), throat = Path(), spots = Path()
            corolla.lobed(x, y, r, f.a * 0.5)
            // Seen from above on the soil, squashed flat.
            var flat = Path()
            flat = corolla.applying(CGAffineTransform(translationX: -x, y: -y).scaledBy(x: 1, y: 0.42).translatedBy(x: x, y: y))
            throat.oval(x, y, r * 0.38, r * 0.17)
            for k in 0..<3 { spots.oval(x + Double(k - 1) * r * 0.2, y - r * 0.08, r * 0.05, r * 0.03) }
            context.fill(flat, with: .color(t.ba.mix(t.bc, 0.1).color()))
            context.fill(throat, with: .color(t.bb.color(0.8)))
            context.fill(spots, with: .color(RGB.tone(0x7A1E4E, day: day, dim: 0.6).color(0.9)))
        }
    }

    func seedLeaves(_ tree: GraphicsContext) {
        core.seedLeaves(tree, len: 9, hw: 3.1, shape: .glossy, wide: 1.0)
    }
}
