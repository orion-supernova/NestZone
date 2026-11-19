import SwiftUI

/// The magnolia, drawn as itself. It flowers on bare wood, as a magnolia does:
/// silver, downy buds sit on the twigs early, then open into big goblet
/// blossoms, pink-white, their petals veined and a little translucent, while
/// the crown is still hardly in leaf; only then do the leathery leaves come in,
/// broad, glossy and dark. Painted the way the pomegranate is (`TreeCore`), a
/// still picture drawn only when the state changes.
struct MagnoliaPainter: TreeArt {
    typealias RGB = Canopy.RGB

    let canopy: Canopy
    let core: TreeCore

    init(canopy: Canopy, growth: Double, mood: Double, day: Double, light: Double) {
        let M = Canopy.Mood(mood)
        self.canopy = canopy
        let tones = Canopy.Tones(canopy.kind, M, day: day, growth: growth)
        core = TreeCore(canopy, growth: growth, mood: mood, day: day, light: light, tones: tones, M: M, fresh: 0xC08A58)
    }

    func draw(_ context: GraphicsContext) { render(context) }

    func wood(_ context: GraphicsContext) {
        TreeWood(canopy: canopy, pose: core.pose, L: core.L, tones: core.tones, M: core.M, style: .lenticel).paint(context)
    }

    /// How much of a clump's leaves are out. The wood flowers first: until about
    /// .74 the crown is bare wood and a few small first leaves, then the broad
    /// ones come in as the blossoms go.
    var leafy: Double { 0.1 + 0.9 * Ink.smooth((core.p - 0.74) / 0.22) }
    var leafK: Double { leafy }

    /// The young tree's leaves are gone from its canes before it flowers.
    func young(_ tree: GraphicsContext) { core.youngSprigs(tree, from: 0.4, span: 0.18) }

    func clump(_ tree: GraphicsContext, _ i: Int) {
        core.clump(tree, i, scale: leafy)
    }

    // MARK: On the soil, and a sprout

    /// The seed, a red one, early on; then the small things a pot collects: a
    /// big leaf, a petal that has come down while it flowers, curled and
    /// browning at its edge.
    func ground(_ context: GraphicsContext) {
        let day = core.day, p = core.p, M = core.M, t = core.tones
        core.ground(context, seed: TreeCore.Seed(hex: (0xE96A48, 0xA02C1C, 0xFFC9AE), rx: 3.8, ry: 3, rot: -0.4), leaf: (0.22, 0.12)) { context in
            guard p > 0.62 && p < 0.99 && M.open > 0.25 else { return }
            for (k, idx) in [4, 8].enumerated() where canopy.fallen.count > idx && (k == 0 || p > 0.88) {
                let f = canopy.fallen[idx], x = f.x * (k == 0 ? 0.5 : 0.8), y = f.y * 0.8 - 1.2
                let rot = sin(f.a) * 0.5 + Double(k) * 0.8
                var petal = Path(), brown = Path(), vein = Path()
                petal.blade(.round, x - cos(rot) * 5, y - sin(rot) * 1.8, cos(rot), sin(rot) * 0.4, 10, 2.6, 0.2)
                brown.blade(.round, x + cos(rot) * 1.5, y + sin(rot) * 0.5, cos(rot), sin(rot) * 0.4, 3.6, 1.9, 0.2)
                vein.blade(.lance, x - cos(rot) * 4, y - sin(rot) * 1.5, cos(rot), sin(rot) * 0.4, 7.5, 0.28, 0.2)
                context.fill(petal, with: .linearGradient(Gradient(colors: [t.bc.mix(t.ba, 0.4).color(), t.bb.color()]),
                                                           startPoint: CGPoint(x: x - 5, y: y), endPoint: CGPoint(x: x + 5, y: y)))
                context.fill(brown, with: .color(RGB.tone(0x9A6B4E, day: day, dim: 0.7).color(0.55)))
                context.fill(vein, with: .color(t.bc.color(0.35)))
            }
        }
    }

    func seedLeaves(_ tree: GraphicsContext) {
        core.seedLeaves(tree, len: 14, hw: 4.4, shape: .glossy, wide: 1.1)
    }
}
