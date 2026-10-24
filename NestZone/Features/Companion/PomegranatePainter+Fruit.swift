import SwiftUI

// MARK: - The fruit

extension PomegranatePainter.Look {
    private typealias RGB = Canopy.RGB

    /// The three tones of one ripeness of skin, light to shade.
    private struct Skin { var hi, mid, shade: RGB }

    /// Green with a blush, then the three ways a pomegranate ripens: deep red,
    /// rose, and a yellow sun-blushed one. A fruit goes green, then blush, then
    /// its own colour, so a tree in the middle of the season has all of them.
    private static let green = Skin(hi: RGB(0xD9E49C), mid: RGB(0x8DB45A), shade: RGB(0x3C6A3A))
    private static let blush = Skin(hi: RGB(0xFCEBB0), mid: RGB(0xF0B062), shade: RGB(0xB8503A))
    private static let ripe = [Skin(hi: RGB(0xF07C84), mid: RGB(0xCD2C3F), shade: RGB(0x6C1223)),
                               Skin(hi: RGB(0xF8A4AE), mid: RGB(0xDC536E), shade: RGB(0x8C2346)),
                               Skin(hi: RGB(0xFCDCA0), mid: RGB(0xEE8E4C), shade: RGB(0xB93C2C))]

    /// One fruit as it hangs now: where, how big, how ripe.
    private struct Hanging {
        var f: Canopy.Fruit
        var index: Int
        var nested: Bool
        var ax, ay, x, y, r, ripe, side: Double
        var variety: Int
        var skin: Skin
    }

    private func skin(_ ripe: Double, _ variety: Int) -> Skin {
        let to = Self.ripe[variety]
        let a = ripe < 0.5 ? Self.green : Self.blush, b = ripe < 0.5 ? Self.blush : to
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

    /// A fruit that sits up in the leaves rather than hanging below them.
    private func isNested(_ f: Canopy.Fruit) -> Bool { f.born > 0.55 }

    private func hanging(_ f: Canopy.Fruit, _ q: Canopy.Pose.Spot, _ index: Int) -> Hanging? {
        // Set from the end of the bloom: a tiny green fruit, swelling, ripening.
        let set = 0.84 + f.born * 0.07
        let grow = Ink.back((p - set) / 0.1)
        guard grow > 0.02 else { return nil }
        let ripe = Ink.smooth((p - (0.84 + f.born * 0.09)) / 0.07) * (0.8 + 0.2 * M.m)
        let r = f.size * 1.12 * (0.4 + 0.6 * min(1, grow)) * (1 - 0.1 * M.thirst - 0.08 * M.doze)
        let nested = isNested(f)
        let ax = q.x + f.dx * q.R, ay = q.y + q.R * (nested ? 0.2 : 0.36)
        let side = f.dx < 0 ? -1.0 : 1
        // The weight of the fruit lets the twig arch out and hook down.
        let sway = M.wilt * 0.12 * side
        let x = ax + side * (r * 0.9 + q.R * 0.1) + sin(sway) * r * 2
        let y = ay + r * 0.9 + f.hang * q.R * 0.6
        let variety = [0, 1, 2, 0, 1][Int(abs(f.tilt * 1000)) % 5]
        return Hanging(f: f, index: index, nested: nested, ax: ax, ay: ay, x: x, y: y, r: r, ripe: ripe, side: side, variety: variety, skin: skin(ripe, variety))
    }

    /// One tier's fruit: the twig that bends under each, a pair of small
    /// leaves at its elbow, the round body lit from the light, the crown of
    /// the calyx, a soft highlight and the warm light bounced up from below.
    /// On the grown tree the most exposed ripe one is split open.
    func fruit(_ context: GraphicsContext, _ tier: Int, nested: Bool) {
        guard p > 0.8 else { return }
        var list: [Hanging] = []
        for (i, f) in canopy.fruits.enumerated() where canopy.clumps[f.clump].tier == tier && isNested(f) == nested {
            guard let q = pose.clumps[f.clump], let h = hanging(f, q, i) else { continue }
            list.append(h)
        }
        guard !list.isEmpty else { return }
        let ink = inks[4]
        var twigs = Path(), leaves = Path()
        for h in list {
            let top = CGPoint(x: h.x, y: h.y - h.r * 0.96)
            twigs.move(to: CGPoint(x: h.ax, y: h.ay))
            twigs.addQuadCurve(to: top, control: CGPoint(x: top.x - h.side * h.r * 0.15, y: h.ay - h.r * 0.5))
            // A pair of small leaves where the twig turns.
            let ex = (h.ax + top.x) / 2 + h.side * h.r * 0.1, ey = h.ay - h.r * 0.2
            for s in [-1.0, 1] {
                let a = -Double.pi / 2 + s * 0.9 + h.side * 0.5
                leaves.lance(ex, ey, cos(a), sin(a), h.r * 1.5, h.r * 0.23, h.side * 0.12, 0)
            }
        }
        context.fill(leaves, with: .color(ink.near[1]))
        context.stroke(twigs, with: .color(tones.barkDark.color(0.95)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        context.stroke(twigs, with: .color(tones.barkHi.color(0.45)), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))

        let split = splitIndex()
        // Everything the fruit share is added to one path each and filled once
        // per tier: the crowns, the highlights, the bounce light, the leaves
        // in front. Only the round bodies (and the open one) are filled singly.
        var batch = Batch()
        for h in list {
            let isSplit = split == h.index && h.ripe > 0.85 && p > 0.94
            body(context, h, big: isSplit, &batch)
            if h.nested { cover(h, &batch) }
        }
        let crown = tones.fc.shifted(-2)
        context.fill(batch.teeth, with: .color(crown.color()))
        context.fill(batch.collars, with: .color(crown.mix(RGB(0xC85A4A), 0.25).color()))
        context.stroke(batch.arcs, with: .color(RGB(0xFFC890).mix(RGB(0xB8C8FF), night).color(0.16)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        context.fill(batch.shines, with: .color(RGB(0xFFF4EC).color(0.5 * (1 - 0.4 * night))))
        context.fill(batch.dots, with: .color(Color.white.opacity(0.8 * (1 - 0.5 * night))))
        if !batch.coverFull.isEmpty {
            context.fill(batch.coverFull, with: .color(ink.near[1]))
            context.fill(batch.coverLit, with: .color(ink.lit[1]))
        }
    }

    private struct Batch {
        var teeth = Path(), collars = Path(), arcs = Path(), shines = Path(), dots = Path()
        var coverFull = Path(), coverLit = Path()
    }

    /// A fruit up in the foliage has leaves in front of it: three, across its
    /// shoulders, so it is seen between them rather than hung on them.
    private func cover(_ h: Hanging, _ batch: inout Batch) {
        let r = h.r
        for (dx, dy, a, len) in [(-1.05, -0.95, 0.5, 1.5), (1.1, -0.9, Double.pi - 0.55, 1.4), (0.1, -1.35, Double.pi / 2 + 0.2, 1.0)] {
            let x = h.x + dx * r, y = h.y + dy * r, ca = cos(a), sa = sin(a)
            batch.coverFull.lance(x, y, ca, sa, r * len, r * len * 0.15, 0.1 * (ca < 0 ? -1 : 1), 0)
            batch.coverLit.lance(x, y, ca, sa, r * len, r * len * 0.15, 0.1 * (ca < 0 ? -1 : 1), (-sa * L.x + ca * L.y) >= 0 ? 1 : -1)
        }
    }

    /// The fruit that opens: among the front tier's, the lowest and most
    /// central, which nothing hangs in front of.
    private func splitIndex() -> Int? {
        var best: (index: Int, score: Double)?
        for (i, f) in canopy.fruits.enumerated() where canopy.clumps[f.clump].tier == 2 && !isNested(f) {
            guard let q = pose.clumps[f.clump] else { continue }
            let score = q.y - abs(q.x) * 0.4 + f.size
            if best == nil || score > best!.score { best = (i, score) }
        }
        return best?.index
    }

    private func body(_ context: GraphicsContext, _ h: Hanging, big: Bool, _ batch: inout Batch) {
        let r = h.r * (big ? 1.2 : 1), sk = h.skin
        let x = h.x, y = h.y + (big ? h.r * 0.15 : 0)
        let lx = L.x, ly = L.y

        // The soft glow of a ripe fruit in a bright tree, or by moonlight.
        if M.glow > 0.2 || night > 0.5 {
            let a = (0.08 + 0.12 * M.glow) * h.ripe * (1 + 0.4 * night)
            var disc = Path()
            disc.oval(x, y, r * 2.2, r * 2.2)
            let gc = sk.hi.mix(RGB(255, 250, 235), 0.4 * day)
            context.fill(disc, with: .radialGradient(Gradient(colors: [gc.color(a), gc.color(0)]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.2))
        }

        // Lit like a sphere from the light: bright near it, deepening to the
        // shade on the far side. One radial gradient from the highlight.
        var body = Path()
        body.oval(x, y, r, r * 0.95)
        context.fill(body, with: .radialGradient(
            Gradient(stops: [.init(color: sk.hi.mix(sk.mid, 0.3).color(), location: 0), .init(color: sk.mid.color(), location: 0.4),
                             .init(color: sk.shade.color(), location: 1)]),
            center: CGPoint(x: x + lx * r * 0.4, y: y + ly * r * 0.4), startRadius: r * 0.04, endRadius: r * 1.55))
        if big { openMouth(context, x, y, r, h) }

        // Light bounced up onto the shadow side; the crown of the calyx at
        // the lower end; a soft highlight and a bright dot on the lit side.
        let away = atan2(-ly, -lx)
        batch.arcs.move(to: CGPoint(x: x + cos(away - 0.7) * r * 0.84, y: y + sin(away - 0.7) * r * 0.84))
        batch.arcs.arc(x, y, r * 0.84, away - 0.7, away + 0.7)
        crown(x, y, r, h.f.tilt * 0.6, &batch)
        batch.shines.oval(x + lx * r * 0.5, y + ly * r * 0.48, r * 0.26, r * 0.12, atan2(ly, lx) + .pi / 2)
        batch.dots.oval(x + lx * r * 0.62, y + ly * r * 0.6, r * 0.065, r * 0.065)
    }

    /// The calyx: a collar and a crown of five pointed sepals on the fruit's
    /// lower end.
    private func crown(_ x: Double, _ y: Double, _ r: Double, _ tilt: Double, _ batch: inout Batch) {
        let dx = sin(tilt), dy = cos(tilt)
        let bx = x + dx * r * 0.9, by = y + dy * r * 0.9
        let nx = -dy, ny = dx
        batch.collars.oval(bx, by, r * 0.3, r * 0.13, atan2(dy, dx) + .pi / 2)
        for (i, v) in [-0.3, -0.15, 0.0, 0.15, 0.3].enumerated() {
            let spread = v * 1.5, len = r * (i == 2 ? 0.34 : 0.27)
            let bxv = bx + nx * v * r, byv = by + ny * v * r
            let w = r * 0.075
            batch.teeth.move(to: CGPoint(x: bxv - nx * w, y: byv - ny * w))
            batch.teeth.addLine(to: CGPoint(x: bxv + (dx + nx * spread) * len, y: byv + (dy + ny * spread) * len))
            batch.teeth.addLine(to: CGPoint(x: bxv + nx * w, y: byv + ny * w))
            batch.teeth.closeSubpath()
        }
    }

    /// The split: a lipped opening in the skin, the cream pith, and a cluster
    /// of jewel arils, two of them loose over the lip.
    private func openMouth(_ context: GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ h: Hanging) {
        let rot = -0.5, cx = x + r * 0.04, cy = y - r * 0.08
        let deep = h.skin.shade.mix(RGB(0x3A0A14), 0.35)
        func oval(_ rx: Double, _ ry: Double, dx: Double = 0, dy: Double = 0) -> Path {
            var path = Path()
            path.oval(cx + dx, cy + dy, r * rx, r * ry, rot)
            return path
        }
        context.fill(oval(0.82, 0.54), with: .color(deep.color()))
        context.fill(oval(0.75, 0.47), with: .color(RGB(0xF4E1B8).mix(h.skin.shade, 0.15).color()))
        context.fill(oval(0.68, 0.4), with: .color(RGB(0x8E1030).mix(deep, 0.25 + 0.4 * night).color()))

        // Arils: two rows packed in the cavity, then two over the lip.
        var arils = Path(), shines = Path()
        let ca = cos(rot), sa = sin(rot)
        func aril(_ u: Double, _ v: Double, _ rad: Double) {
            let ax = cx + (ca * u - sa * v) * r, ay = cy + (sa * u + ca * v) * r
            arils.oval(ax, ay, r * rad, r * rad * 0.94)
            shines.oval(ax + L.x * r * rad * 0.35, ay + L.y * r * rad * 0.35, r * rad * 0.22, r * rad * 0.16)
        }
        for (u, v, rad) in [(-0.44, -0.04, 0.12), (-0.22, -0.13, 0.12), (0.02, -0.15, 0.12), (0.26, -0.12, 0.12), (0.46, -0.03, 0.11),
                            (-0.33, 0.1, 0.12), (-0.1, 0.05, 0.12), (0.14, 0.04, 0.12), (0.36, 0.1, 0.11), (-0.2, 0.2, 0.1), (0.04, 0.19, 0.1), (0.24, 0.21, 0.09)] {
            aril(u, v, rad)
        }
        aril(0.12, 0.5, 0.12)
        aril(-0.14, 0.56, 0.1)
        let jewel = Gradient(stops: [.init(color: RGB(0xFF6F82).mix(RGB(0x7C0C26), 0.5 * night).color(), location: 0),
                                     .init(color: RGB(0xD21E41).mix(RGB(0x5A0A22), 0.5 * night).color(), location: 0.5),
                                     .init(color: RGB(0x8A0E2C).mix(RGB(0x3C0818), 0.4 * night).color(), location: 1)])
        let reach = r * 0.75
        context.fill(arils, with: .linearGradient(jewel, startPoint: CGPoint(x: cx + L.x * reach, y: cy + L.y * reach),
                                                  endPoint: CGPoint(x: cx - L.x * reach, y: cy - L.y * reach)))
        context.stroke(arils, with: .color(RGB(0x4A0820).color(0.5)), lineWidth: r * 0.03)
        context.fill(shines, with: .color(RGB(0xFFFFFF).color(0.85 * (1 - 0.5 * night))))
    }
}
