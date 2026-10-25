import SwiftUI

/// The olive, drawn as itself. Narrow leaves in pairs on thin twigs, dark
/// grey-green on top and silver underneath, and here and there one turned over
/// so the crown shimmers; a gnarled, ancient trunk with hollows and twisted
/// ridges even when it is small; little clusters of olives that go from green
/// through rose to purple-black; tiny cream flowers in sprays. Painted the way
/// the pomegranate is (`TreeCore`), a still picture drawn only when the state
/// changes.
struct OlivePainter: TreeArt {
    typealias RGB = Canopy.RGB

    let canopy: Canopy
    let core: TreeCore

    init(canopy: Canopy, growth: Double, mood: Double, day: Double, light: Double) {
        let M = Canopy.Mood(mood)
        self.canopy = canopy
        var tones = Canopy.Tones(canopy.kind, M, day: day, growth: growth)
        // The leaf tops are the dark half of the ramp; the silver is kept back
        // for the undersides, so a leaf turned over is the brightest thing in
        // the crown.
        let r = tones.ramp
        tones.ramp = [r[0], r[0].mix(r[1], 0.55), r[1].mix(r[2], 0.3), r[1].mix(r[2], 0.85), r[2].mix(r[3], 0.45)]
        var core = TreeCore(canopy, growth: growth, mood: mood, day: day, light: light, tones: tones, M: M, fresh: 0xB9C98A, rimBase: r[4].mix(RGB(0xFFFFFF), 0.15), rimK: 0.22)
        let moon = core.light.moon
        let cool = RGB(0x3A5578)
        core.under = [r[3].mix(r[2], 0.5), r[3].mix(r[4], 0.15), r[3].mix(r[4], 0.6).mix(RGB(0xFFFFFF), 0.08)].map { $0.mix(cool, 0.45 * moon).color() }
        self.core = core
    }

    func draw(_ context: GraphicsContext) { render(context) }

    func wood(_ context: GraphicsContext) {
        TreeWood(canopy: canopy, pose: core.pose, L: core.L, tones: core.tones, M: core.M, style: .gnarled).paint(context)
    }

    func clump(_ tree: GraphicsContext, _ i: Int) {
        core.clump(tree, i) { _, q in
            let fruit = hangings(i, q)
            guard !fruit.isEmpty else { return TreeCore.Between() }
            return TreeCore.Between(
                deep: { _ in self.cluster(tree, fruit.filter { $0.deep }) },
                mid: { _ in self.cluster(tree, fruit.filter { !$0.deep }) },
                over: { ink in core.cover(tree, fruit.map { TreeCore.Cover(x: $0.x, y: $0.y, r: $0.r * 1.3, index: $0.index, deep: $0.deep) }, ink, lean: true) })
        }
    }

    // MARK: On the soil, and a sprout

    /// The seed, a pitted stone, early on; then the small things a pot
    /// collects: a silver leaf, and when thirsty more leaves and an olive that
    /// has dropped.
    func ground(_ context: GraphicsContext) {
        let day = core.day, p = core.p, M = core.M
        core.ground(context, seed: TreeCore.Seed(hex: (0xC9AA78, 0x7E5E3C, 0xEBD6A8), rx: 5, ry: 2.8, rot: -0.25), leaf: (0.09, 0.08)) { context in
            // An olive on the soil: a thirsty tree lets go of fruit early.
            if (M.thirst > 0.5 && p > 0.88) || (p > 0.96 && M.thirst > 0.2), canopy.fallen.count > 1 {
                let f = canopy.fallen[1], x = f.x * 0.6, y = f.y * 0.4 - 2.6, r = 3.4
                var shadow = Path(), body = Path()
                shadow.oval(x + 0.5, y + r * 0.6, r * 1.2, r * 0.25)
                body.oval(x, y, r * 1.05, r * 0.78, 0.2)
                context.fill(shadow, with: .color(SceneInk.shadow))
                let sk = RGB.tone(0x6E4F7C, day: day), dk = RGB.tone(0x2A1A36, day: day)
                context.fill(body, with: .radialGradient(Gradient(colors: [sk.mix(RGB(0xFFFFFF), 0.25).color(), sk.color(), dk.color()]),
                                                          center: CGPoint(x: x - 1.2, y: y - 1.2), startRadius: 0, endRadius: r * 1.4))
            }
        }
    }

    func seedLeaves(_ tree: GraphicsContext) {
        core.seedLeaves(tree, len: 12, hw: 1.9, shape: .lance, wide: 1.0)
    }
}
