import SwiftUI

// MARK: - The fruit

extension PomegranatePainter.Look {
    private typealias RGB = Canopy.RGB

    /// The three tones of one ripeness of skin, light to shade.
    struct Skin { var hi, mid, shade: PomegranatePainter.RGB }

    /// Green with a blush, then the three ways a pomegranate ripens: deep red,
    /// rose, and a yellow sun-blushed one. A fruit goes green, then blush, then
    /// its own colour, so a tree in the middle of the season has all of them.
    /// The skins come from the tree's colourway (`TreeColours.pomegranate`); the original's are the ones below.
    private static func skin(_ s: TreeColours.Skin) -> Skin { Skin(hi: RGB(s.hi), mid: RGB(s.mid), shade: RGB(s.shade)) }

    /// One fruit as it sits now: where, how big, how ripe, and how it leans.
    struct Hanging {
        var f: Canopy.Fruit
        var index: Int
        var x, y, r, ripe, tilt, side: Double
        /// Sunk in the leaves, so the middle ones cover it too.
        var deep: Bool
        var split: Bool
        var skin: Skin
    }

    private func skin(_ ripe: Double, _ variety: Int) -> Skin {
        let set = TreeColours.pomegranate(canopy.colourway)
        let to = Self.skin(set.ripe[variety])
        let green = Self.skin(set.green), blush = Self.skin(set.blush)
        let a = ripe < 0.5 ? green : blush, b = ripe < 0.5 ? blush : to
        let t = Ink.smooth(ripe < 0.5 ? ripe * 2 : (ripe - 0.5) * 2)
        let s = Skin(hi: a.hi.mix(b.hi, t), mid: a.mid.mix(b.mid, t), shade: a.shade.mix(b.shade, t))
        // A thirsty or sleepy tree's fruit is duller, and a bright one's richer.
        let k = (0.62 + 0.38 * M.m) * (1 - 0.3 * M.doze), dull = RGB(0x7A4A44)
        func tone(_ c: RGB, _ dim: Double) -> RGB {
            let c = c.mix(dull, 0.3 * M.thirst), (h, sat, l) = c.hsl
            return RGB.night(h, sat * k, l, day: day, dim: dim)
        }
        return Skin(hi: tone(s.hi, 0.8), mid: tone(s.mid, 0.7), shade: tone(s.shade, 0.6))
    }

    /// The fruit that opens: among the front tier's, the lowest and most
    /// central, which the leaves leave most of in view.
    static func splitIndex(_ canopy: Canopy, _ pose: Canopy.Pose) -> Int? {
        var best: (index: Int, score: Double)?
        for (i, f) in canopy.fruits.enumerated() where canopy.clumps[f.clump].tier == 2 {
            guard let q = pose.clumps[f.clump] else { continue }
            let score = q.y - abs(q.x) * 0.4 + f.size + f.hang * 20
            if best == nil || score > best!.score { best = (i, score) }
        }
        return best?.index
    }

    /// The fruit that lives in one clump, as it sits now. Each is up in the
    /// clump's own leaves, a little out from its middle and low in it, so the
    /// bottom of the fruit shows beneath the sprigs and the top is under them.
    /// Sizes and angles differ from one to the next, and about a third are
    /// sunk deeper still.
    func hangings(_ i: Int, _ q: Canopy.Pose.Spot) -> [Hanging] {
        guard p > 0.8 else { return [] }
        var list: [Hanging] = []
        for index in art.crown.fruitsOf[i] {
            let f = canopy.fruits[index]
            // Set from the end of the bloom: a tiny green fruit, swelling, ripening.
            let set = 0.84 + f.born * 0.07
            let grow = Ink.back((p - set) / 0.1)
            guard grow > 0.02 else { continue }
            let ripe = Ink.smooth((p - (0.84 + f.born * 0.09)) / 0.07) * (0.8 + 0.2 * M.m)
            let luck = Double(Int(abs(f.tilt * 1000)) % 7) / 6
            let isSplit = split == index && ripe > 0.85 && p > 0.94
            let deep = !isSplit && (index % 3 == 1)
            var r = f.size * 1.25 * (0.4 + 0.6 * min(1, grow)) * (1 - 0.1 * M.thirst - 0.08 * M.doze) * (0.86 + 0.28 * luck)
            if deep { r *= 0.92 }
            let side = f.dx < 0 ? -1.0 : 1
            let x = q.x + f.dx * q.R * 0.66 + (isSplit ? side * q.R * 0.1 : 0)
            let y = q.y + q.R * ((deep ? 0.06 : 0.14) + (deep ? 0.55 : 0.95) * f.hang + (isSplit ? 0.1 : 0)) + r * 0.2
            // The weight of the fruit leans it out; a thirsty tree's lean more.
            let tilt = f.tilt * 0.9 + side * (0.2 + 0.25 * M.wilt)
            list.append(Hanging(f: f, index: index, x: x, y: y, r: r, ripe: ripe, tilt: tilt, side: side, deep: deep, split: isSplit,
                                skin: skin(ripe, [0, 1, 2, 0, 1][Int(abs(f.tilt * 1000)) % 5])))
        }
        return list
    }

    /// One fruit: the short sturdy stalk it hangs from, the round body lit
    /// from the light, the crown of the calyx, a soft highlight and the warm
    /// light bounced up from below. The split one is cut open.
    func fruit(_ tree: GraphicsContext, _ h: Hanging, _ q: Canopy.Pose.Spot) {
        let r = h.r * (h.split ? 1.2 : 1), sk = h.skin
        let x = h.x, y = h.y + (h.split ? h.r * 0.15 : 0)
        let lx = L.x, ly = L.y
        let down = CGPoint(x: sin(h.tilt), y: cos(h.tilt))

        // The stalk: a short, thick stub of twig from inside the clump, set on
        // the fruit's shoulder and bent a little where it meets the leaves.
        let top = CGPoint(x: x - down.x * r * 0.92, y: y - down.y * r * 0.92)
        let stub = h.split ? 0.4 : 1.0
        let from = CGPoint(x: top.x - h.side * r * 0.4 * stub, y: top.y - r * 0.62 * stub)
        var stalk = Path()
        stalk.twig(from, top, r * 0.17, r * 0.15)
        tree.fill(stalk, with: .color(tones.barkDark.mix(tones.bark, 0.4).color(0.95)))

        // The soft glow of a ripe fruit in a bright tree.
        if M.glow > 0.35 {
            let a = (0.05 + 0.08 * M.glow) * h.ripe * (1 + 0.3 * night)
            var disc = Path()
            disc.oval(x, y, r * 2.2, r * 2.2)
            let gc = sk.hi.mix(RGB(255, 250, 235), 0.4 * day)
            tree.fill(disc, with: .radialGradient(Gradient(colors: [gc.color(a), gc.color(0)]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.2))
        }

        // Lit like a sphere from the light: bright near it, deepening to the
        // shade on the far side. One radial gradient from the highlight.
        var body = Path()
        body.oval(x, y, r, r * 0.95)
        tree.fill(body, with: .radialGradient(
            Gradient(stops: [.init(color: sk.hi.mix(sk.mid, 0.3).color(), location: 0), .init(color: sk.mid.color(), location: 0.4),
                             .init(color: sk.shade.color(), location: 1)]),
            center: CGPoint(x: x + lx * r * 0.4, y: y + ly * r * 0.4), startRadius: r * 0.04, endRadius: r * 1.55))
        if h.split { cutaway(tree, x, y, r, h) }

        // Light bounced up onto the shadow side; the crown of the calyx at
        // the lower end; a soft highlight and a bright dot on the lit side.
        var sepals = Path(), glints = Path()
        crown(x, y, r, h.tilt, down, &sepals)
        glints.oval(x + lx * r * 0.5, y + ly * r * 0.48, r * 0.26, r * 0.12, atan2(ly, lx) + .pi / 2)
        glints.oval(x + lx * r * 0.62, y + ly * r * 0.6, r * 0.065, r * 0.065)
        let calyx = tones.fc.shifted(-2)
        tree.fill(sepals, with: .color(calyx.color()))
        tree.fill(glints, with: .color(RGB(0xFFF4EC).color(0.62 * (1 - 0.4 * night))))
    }

    /// The calyx: a collar and a crown of five pointed sepals on the fruit's
    /// lower end.
    private func crown(_ x: Double, _ y: Double, _ r: Double, _ tilt: Double, _ down: CGPoint, _ path: inout Path) {
        let dx = down.x, dy = down.y
        let bx = x + dx * r * 0.9, by = y + dy * r * 0.9
        let nx = -dy, ny = dx
        path.oval(bx, by, r * 0.24, r * 0.1, atan2(dy, dx) + .pi / 2)
        for (i, v) in [-0.3, -0.15, 0.0, 0.15, 0.3].enumerated() {
            let spread = v * 1.5, len = r * (i == 2 ? 0.32 : 0.25)
            let bxv = bx + nx * v * r, byv = by + ny * v * r
            let w = r * 0.06
            path.move(to: CGPoint(x: bxv - nx * w, y: byv - ny * w))
            path.addLine(to: CGPoint(x: bxv + (dx + nx * spread) * len, y: byv + (dy + ny * spread) * len))
            path.addLine(to: CGPoint(x: bxv + nx * w, y: byv + ny * w))
            path.closeSubpath()
        }
    }

    /// Leaves in front of a fruit: one or two across its shoulders or over its
    /// top, a different few for each, so it is seen between them and not hung
    /// on them. The one that is cut open has none, so the cut shows.
    func cover(_ tree: GraphicsContext, _ h: Hanging, _ ink: PomegranatePainter.LeafInk) {
        let r = h.r * (h.split ? 1.2 : 1)
        var full = Path(), lit = Path()
        let y0 = h.y + (h.split ? h.r * 0.15 : 0)
        // Which leaves hang over it varies from fruit to fruit: one over a
        // shoulder, or two meeting over the top, or a low one across its side.
        var specs: [(Double, Double, Double, Double)]
        let pick = h.index % 4
        if h.split {
            specs = []
        } else if pick == 0 {
            specs = [(-0.95, -1.15, 0.85, 1.05), (0.95, -1.1, Double.pi - 0.8, 1.0)]
        } else if pick == 1 {
            specs = [(-1.05, -0.85, 0.7, 1.1), (0.1, -1.4, Double.pi / 2 + 0.3, 0.85)]
        } else if pick == 2 {
            specs = [(1.05, -0.95, Double.pi - 0.75, 1.15), (-0.2, -1.35, Double.pi / 2 - 0.35, 0.8)]
        } else {
            specs = [(-0.9, -1.1, 0.95, 1.0), (1.2, -0.3, Double.pi - 0.25, 0.9)]
        }
        if h.deep { specs.append((-0.3, -0.35, 0.3, 1.1)) }
        for (dx, dy, a, len) in specs {
            let x = h.x + dx * r, y = y0 + dy * r, ca = cos(a), sa = sin(a)
            let bend = 0.1 * (ca < 0 ? -1 : 1)
            full.lance(x, y, ca, sa, r * len, r * len * 0.17, bend, 0)
            lit.lance(x, y, ca, sa, r * len, r * len * 0.17, bend, (-sa * L.x + ca * L.y) >= 0 ? 1 : -1)
        }
        tree.fill(full, with: .color(ink.m))
        tree.fill(lit, with: .color(ink.l))
    }
}
