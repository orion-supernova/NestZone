import SwiftUI

/// The cherry, drawn as itself. Small glossy leaves come in as the tree goes
/// into bloom, and over them it is covered in clusters of five-petal sakura
/// blossoms, lit like the leaves (drifts of bright blossom on the sun's side, a
/// dusky pink inside). Petals are on their way down and have come down; and late
/// in the season, among what is left of the blossom, cherries hang in pairs on
/// long stalks. The bark is the glossy red-brown of a cherry with its pale
/// lenticels. Painted the way the pomegranate is (`TreeCore`), a still picture
/// drawn only when the state changes.
struct CherryPainter: TreeArt {
    typealias RGB = Canopy.RGB

    let canopy: Canopy
    let core: TreeCore
    let bloom: BloomArt?
    /// The blossoms that sit in each clump, by index.
    let blossomsOf: [[Int]]

    init(canopy: Canopy, growth: Double, mood: Double, day: Double, light: Double) {
        let M = Canopy.Mood(mood)
        self.canopy = canopy
        // The leaves stay green: the tree's own turn to pink (`bloomRamp`) is the
        // old painter's way of drawing a blossom, and this one paints the
        // blossoms themselves.
        let tones = Canopy.Tones(canopy.kind, M, day: day, growth: min(growth, 0.85))
        core = TreeCore(canopy, growth: growth, mood: mood, day: day, light: light, tones: tones, M: M, fresh: 0xC8D87C)
        bloom = BloomArt.of(canopy, leaves: core.art, mood: mood, light: light, day: day)
        var of = Array(repeating: [Int](), count: canopy.clumps.count)
        for (i, b) in canopy.blossoms.enumerated() { of[b.clump].append(i) }
        blossomsOf = of
    }

    func draw(_ context: GraphicsContext) { render(context) }

    var dappled: Bool { false }

    /// The blossom is part of each clump (`blossoms(_:_:_:)`).
    func blossoms(_ tree: GraphicsContext, _ tier: Int) {}

    func wood(_ context: GraphicsContext) {
        TreeWood(canopy: canopy, pose: core.pose, L: core.L, tones: core.tones, M: core.M, style: .lenticel).paint(context)
    }

    /// How open the flowers are: they open from about .6 and thin a little as
    /// the fruit sets; a tree that is thirsty keeps them shut.
    var open: Double {
        Ink.smooth((core.p - 0.6) / 0.22) * (1 - 0.32 * Ink.smooth((core.p - 0.93) / 0.07)) * Ink.smooth((core.M.open - 0.12) / 0.5)
    }

    /// How much of a clump's leaves are out: the blossom comes first.
    var leafy: Double { 0.3 + 0.45 * Ink.smooth((core.p - 0.68) / 0.26) }

    func clump(_ tree: GraphicsContext, _ i: Int) {
        core.clump(tree, i, scale: leafy) { ink, q in
            let pairs = cherries(i, q)
            return TreeCore.Between(mid: pairs.isEmpty ? nil : { _ in self.cherries(tree, pairs) })
        }
    }

    /// The blossom of every clump, back to front, over the whole crown: a
    /// cherry in bloom is flowers first and leaves seen between them.
    func late(_ tree: GraphicsContext) {
        for i in core.order() {
            if let q = core.pose.clumps[i] { blossoms(tree, i, q) }
        }
    }

    // MARK: On the soil, and a sprout

    /// The seed, a stone, early on; then the small things a pot collects: a
    /// leaf, and the petals that have come down.
    func ground(_ context: GraphicsContext) {
        let p = core.p, t = core.tones
        let open = self.open
        core.ground(context, seed: TreeCore.Seed(hex: (0xD2AA70, 0x8A6638, 0xF2DDB0), rx: 3.8, ry: 3.2, rot: -0.3), leaf: (0.2, 0.1)) { context in
            guard p > 0.74, open > 0.15 else { return }
            var petals = Path(), notch = Path()
            for k in 0..<5 where canopy.fallen.count > 3 + k {
                let f = canopy.fallen[3 + k]
                let x = f.x * (0.35 + 0.12 * Double(k)), y = f.y * 0.6 - 0.8 + Double(k % 2) * 0.5, rot = sin(f.a) * 0.6 + Double(k)
                petals.oval(x, y, 2.6, 1.5, rot)
                notch.oval(x + cos(rot) * 2.3, y + sin(rot) * 2.3 * 0.2, 0.35, 0.28)
            }
            context.fill(petals, with: .color(t.ba.mix(t.bc, 0.12).color(0.95 * min(1, open * 2))))
            context.fill(notch, with: .color(t.bc.color(0.5)))
        }
    }

    func seedLeaves(_ tree: GraphicsContext) {
        core.seedLeaves(tree, len: 11, hw: 3.6, shape: .glossy, wide: 1.1)
    }

    /// Petals on their way down through the air between the crown and the
    /// soil, a few, each turned a different way.
    func finish(_ tree: GraphicsContext) {
        let open = self.open, p = core.p
        guard p > 0.8, open > 0.2, canopy.fallen.count > 9 else { return }
        let pose = core.pose, t = core.tones
        let cx = (pose.left + pose.right) / 2, span = pose.right - pose.left
        var petals = Path(), notch = Path()
        for k in 0..<5 where Double(k) < 5 * open {
            let f = canopy.fallen[5 + k % 5]
            let drop = 0.22 + 0.17 * Double(k)
            let x = cx + (Double(k) - 2) * span * 0.13 + sin(f.a) * span * 0.04 + Double(k) * 3
            let y = pose.bottom * (1 - drop) - 2
            let rot = f.a * 0.5 + Double(k) * 1.1, s = 3.6 - 0.3 * Double(k % 3)
            petals.oval(x, y, s, s * 0.6, rot)
            notch.oval(x + cos(rot) * s * 0.9, y + sin(rot) * s * 0.9 * 0.6, s * 0.14, s * 0.11)
        }
        tree.fill(petals, with: .color(t.ba.mix(t.bb, 0.3).color(0.92)))
        tree.fill(notch, with: .color(t.bc.color(0.5)))
    }
}
