import SwiftUI

/// The lemon, drawn as itself. It grows from the same seed and skeleton as every
/// `Canopy` tree, and is painted the way the pomegranate is (`TreeCore`): glossy
/// oval leaves alternate on their twigs and are sorted by the light into classes,
/// so the crown has a dark interior and lit sprigs on the sun's side. White star
/// blossoms with a breath of purple on their backs open among fruit that goes
/// from green to yellow, each skin dimpled, each hung on a short stalk in the
/// leaves. One lemon is cut in half. A still picture, drawn only when the state
/// changes.
struct LemonPainter: TreeArt {
    typealias RGB = Canopy.RGB

    let canopy: Canopy
    let core: TreeCore
    /// The fruit that is cut open, if any: its index among the tree's.
    let split: Int?

    init(canopy: Canopy, growth: Double, mood: Double, day: Double, light: Double) {
        let M = Canopy.Mood(mood)
        self.canopy = canopy
        let tones = Canopy.Tones(canopy.kind, M, day: day, growth: growth)
        core = TreeCore(canopy, growth: growth, mood: mood, day: day, light: light, tones: tones, M: M, fresh: 0xC4D45A)
        split = Self.heroIndex(canopy, core.pose)
    }

    func draw(_ context: GraphicsContext) { render(context) }

    /// The lemon that is cut: among the front tier's, a low one well out to a
    /// side, where it hangs from a limb in the open and not over the trunk.
    static func heroIndex(_ canopy: Canopy, _ pose: Canopy.Pose) -> Int? {
        var best: (index: Int, score: Double)?
        for (i, f) in canopy.fruits.enumerated() where canopy.clumps[f.clump].tier == 2 {
            guard let q = pose.clumps[f.clump] else { continue }
            let score = q.y * 0.7 + abs(q.x) * 0.55 + f.size + f.hang * 20
            if best == nil || score > best!.score { best = (i, score) }
        }
        return best?.index
    }

    func wood(_ context: GraphicsContext) {
        TreeWood(canopy: canopy, pose: core.pose, L: core.L, tones: core.tones, M: core.M, style: .smooth).paint(context)
    }

    func clump(_ tree: GraphicsContext, _ i: Int) {
        core.clump(tree, i) { ink, q in
            let fruit = hangings(i, q)
            guard !fruit.isEmpty else { return TreeCore.Between() }
            return TreeCore.Between(
                deep: { _ in for h in fruit where h.deep { self.fruit(tree, h) } },
                mid: { _ in for h in fruit where !h.deep && !h.hero { self.fruit(tree, h) } },
                over: { ink in core.cover(tree, fruit.map { TreeCore.Cover(x: $0.x, y: $0.y, r: $0.r, index: $0.index, deep: $0.deep, skip: $0.hero) }, ink, lean: true) })
        }
    }

    /// The lemon that is cut in half, after every clump of the front tier: the
    /// others are nestled in the leaves, but this is the one a person looks at
    /// closely, and no leaf lies across the cut.
    func late(_ tree: GraphicsContext) {
        guard let index = split, let q = core.pose.clumps[canopy.fruits[index].clump] else { return }
        for h in hangings(canopy.fruits[index].clump, q) where h.hero { cutHalf(tree, h) }
    }

    // MARK: On the soil, and a sprout

    /// The seed, a pale pointed one, early on; then the small things a pot
    /// collects: a leaf, a fallen petal while it flowers, and when thirsty more
    /// leaves and a lemon that has dropped.
    func ground(_ context: GraphicsContext) {
        let day = core.day, p = core.p, M = core.M, t = core.tones
        core.ground(context, seed: TreeCore.Seed(hex: (0xEBDDA6, 0xB59B5C, 0xFFF6D6), rx: 4.2, ry: 2.4, rot: -0.35), leaf: (0.2, 0.1)) { context in
            // A white petal that has come down, with a blush of purple.
            if p > 0.62 && p < 0.98 && M.open > 0.3, canopy.fallen.count > 4 {
                let f = canopy.fallen[4], x = f.x * 0.55, y = f.y * 0.8 - 1
                var petal = Path(), streak = Path()
                petal.oval(x, y, 3.6, 1.5, sin(f.a) * 0.4)
                streak.oval(x, y, 2.2, 0.3, sin(f.a) * 0.4)
                context.fill(petal, with: .color(t.bb.color()))
                context.fill(streak, with: .color(RGB.tone(0xB07AB4, day: day, dim: 0.6).color(0.5)))
            }
            // A thirsty tree has let a lemon fall.
            if M.thirst > 0.5 && p > 0.9, canopy.fallen.count > 1 {
                let f = canopy.fallen[1], x = f.x * 0.6, y = f.y * 0.4 - 3.4, r = 4.6
                var shadow = Path(), body = Path(), tip = Path()
                shadow.oval(x + 0.6, y + r * 0.7, r * 1.25, r * 0.26)
                body.oval(x, y, r * 1.15, r * 0.82, 0.15)
                tip.oval(x + r * 1.2, y + 0.3, r * 0.2, r * 0.15, 0.15)
                context.fill(shadow, with: .color(SceneInk.shadow))
                let sk = RGB.tone(0xC7B038, day: day), dk = RGB.tone(0x7A6A1C, day: day)
                body.addPath(tip)
                context.fill(body, with: .radialGradient(Gradient(colors: [sk.mix(RGB(0xFFFFFF), 0.25).color(), sk.color(), dk.color()]),
                                                          center: CGPoint(x: x - 1.5, y: y - 1.5), startRadius: 0, endRadius: r * 1.5))
            }
        }
    }

    func seedLeaves(_ tree: GraphicsContext) {
        core.seedLeaves(tree, len: 11, hw: 3.4, shape: .glossy, wide: 1.1)
    }
}
