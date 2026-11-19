import SwiftUI

// MARK: - Before it hatches

/// The eggs of the birds and the turtle, which are not the same egg: a duck's
/// is smooth and pale, an owl's round and chalk white, a penguin's long and
/// greenish and kept on its parent's feet, a turtle's leathery, dented and
/// half buried in sand. Stage 0 is the egg and stage 1 the same egg with its
/// pip (a star of cracks, a hole, the tip of a bill, the egg tooth) and its
/// wobble (`PetMotion.offsets` turns it). The goldfish's is its own, in
/// `CritterPainter+Fish`.
extension CritterPainter {
    /// The tint of the shell this species' egg has, and of the pieces it
    /// leaves: a colourway tints it (a mallard's is olive, a Swedish blue's
    /// has a cool cast).
    private var eggBase: UInt32 {
        switch (plan.species, plan.colourway) {
        case (.duckling, 1): 0xDCE6BE
        case (.duckling, 3): 0xD2E6E4
        case (.owl, _): 0xFBF8F1
        case (.penguin, _): 0xE9F3E5
        case (.turtle, _): 0xF2EBD3
        default: plan.wrap
        }
    }

    /// The egg, in the box, standing on the floor.
    func eggArt(_ c: GraphicsContext) {
        let shell = look.tone(eggBase, dim: 0.7)
        let L = look.L
        var e = c
        let shape: Path
        let centre: CGPoint
        switch plan.species {
        case .owl:
            shape = Path(ellipseIn: CGRect(x: 34, y: 47, width: 52, height: 58)); centre = CGPoint(x: 60, y: 76)
        case .penguin:
            // A long egg, narrower at the top, held up on the feet.
            shape = Path.loop([CGPoint(x: 60, y: 36), CGPoint(x: 73, y: 48), CGPoint(x: 83, y: 68), CGPoint(x: 80, y: 90), CGPoint(x: 66, y: 101), CGPoint(x: 52, y: 101),
                               CGPoint(x: 38, y: 90), CGPoint(x: 36, y: 68), CGPoint(x: 46, y: 48)]).applying(CGAffineTransform(translationX: 0, y: 3))
            centre = CGPoint(x: 60, y: 71)
        case .turtle:
            shape = Path(ellipseIn: CGRect(x: 37, y: 58, width: 46, height: 48)); centre = CGPoint(x: 60, y: 84)
        default:
            shape = Path(ellipseIn: CGRect(x: 36, y: 40, width: 48, height: 64)); centre = CGPoint(x: 60, y: 72)
        }
        form(e, shape, centre: centre, radius: 32, shell.mix(RGB(255, 255, 255), 0.4), shell, shell.shifted(-13, plan.species == .penguin ? 8 : 6), highlight: 0.4)
        // The surface: chalk bloom on a bird's, dents and wrinkles in a turtle's.
        var specks = Path()
        var rand = Ink.Random("egg-\(plan.key)")
        for _ in 0..<(plan.species == .turtle ? 5 : 16) {
            let a = rand.between(0, .pi * 2), d = rand.between(0.15, 0.85)
            let rx = shape.boundingRect.width / 2 * d, ry = shape.boundingRect.height / 2 * d
            let r = rand.between(0.5, plan.species == .turtle ? 2.6 : 1.1)
            specks.addEllipse(in: CGRect(x: centre.x + cos(a) * rx - r, y: centre.y + sin(a) * ry - r * 0.8, width: r * 2, height: r * 1.6))
        }
        e.fill(specks, with: .color(look.tone(plan.species == .turtle ? 0xC9BC9C : 0xB8AE98, dim: 0.7).color(plan.species == .turtle ? 0.3 : 0.28)))
        e.ellipse(60 + L.x * 9, centre.y - 12 + L.y * 8, plan.species == .penguin ? 4 : 5, 9, .color(Color.white.opacity(0.5)))
        if plan.species == .penguin {
            // Held up on its parent's feet: the feet in front of the egg's foot.
            for (i, foot) in CritterGeometry.penguin(plan).feet.enumerated() {
                let fx = i == 0 ? 53.0 : 63.0
                var fp = e
                fp.translateBy(x: fx, y: 108)
                fp.scaleBy(x: 1.3, y: 1.3)
                fp.translateBy(x: -fx, y: -108)
                fp.fill(foot.applying(CGAffineTransform(translationX: i == 0 ? 4 : -6, y: 0.5)), with: .color(look.accent.color()))
            }
        }
        if plan.species == .turtle {
            // Leathery: a few soft dents.
            var dents = Path()
            for (x, y, w) in [(47.0, 70.0, 9.0), (66.0, 66.0, 8.0), (55.0, 84.0, 10.0), (71.0, 80.0, 7.0)] {
                dents.move(to: CGPoint(x: x, y: y)); dents.addQuadCurve(to: CGPoint(x: x + w, y: y + 1.5), control: CGPoint(x: x + w * 0.5, y: y + 4))
            }
            e.stroke(dents, with: .color(look.tone(0xB5A585, dim: 0.7).color(0.3)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            sand(e, shell)
        }
        if stage == 1 { pip(e, on: shape, shell: shell, at: CGPoint(x: plan.species == .penguin ? 56 : 57, y: centre.y - 9)) }
    }

    /// The mound of sand a turtle's egg is in, over its lower third, with
    /// grains.
    private func sand(_ c: GraphicsContext, _ shell: RGB) {
        let sand = look.tone(0xE2C98F, dim: 0.6), dark = look.tone(0xB89A5E, dim: 0.6)
        var mound = Path()
        mound.move(to: CGPoint(x: 26, y: 108))
        mound.addQuadCurve(to: CGPoint(x: 48, y: 93), control: CGPoint(x: 34, y: 96))
        mound.addQuadCurve(to: CGPoint(x: 72, y: 94), control: CGPoint(x: 60, y: 99))
        mound.addQuadCurve(to: CGPoint(x: 96, y: 108), control: CGPoint(x: 86, y: 96))
        mound.closeSubpath()
        form(c, mound, centre: CGPoint(x: 60, y: 100), radius: 34, look.lifted(sand, 0.3), sand, dark, highlight: 0.3, core: 0.6, rim: false)
        var grains = Path()
        for (x, y) in [(34.0, 103.0), (42, 98.5), (52, 101.5), (63, 99.5), (74, 100.5), (84, 103), (90, 106), (58, 105), (70, 105.5)] {
            grains.addEllipse(in: CGRect(x: x - 0.8, y: y - 0.6, width: 1.6, height: 1.2))
        }
        c.fill(grains, with: .color(dark.color(0.55)))
    }

    /// The pip: a star of cracks round a small hole with a dark inside, the
    /// tip of a bill in it and its tooth, and two chips of shell lifted.
    private func pip(_ c: GraphicsContext, on shape: Path, shell: RGB, at p: CGPoint) {
        let crack = look.tone(0xA8946C, dim: 0.7).shifted(-8)
        var cracks = Path()
        for (a, len) in [(2.6, 9.0), (3.6, 6.5), (0.4, 9.5), (-0.5, 6.0), (1.7, 7.5)] {
            cracks.move(to: p)
            cracks.addLine(to: CGPoint(x: p.x + cos(a + 0.28) * len * 0.5, y: p.y + sin(a + 0.28) * len * 0.5))
            cracks.addLine(to: CGPoint(x: p.x + cos(a - 0.16) * len, y: p.y + sin(a - 0.16) * len))
        }
        c.stroke(cracks, with: .color(crack.color(0.8)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
        // The hole and what is in it.
        let hole = Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 2.8, width: 8, height: 5.6))
        c.fill(hole, with: .radialGradient(Gradient(colors: [look.tone(0x3A2A1E, dim: 0.8).color(), look.tone(0x6A5238, dim: 0.8).color()]),
                                           center: p, startRadius: 0, endRadius: 5))
        let billTone: RGB = plan.species == .turtle ? look.tone(0xF6F0DE) : look.accent
        c.fill(Path(ellipseIn: CGRect(x: p.x - 2.6, y: p.y - 0.4, width: 4.8, height: 2.4)), with: .color(billTone.color()))
        c.fill(Path(ellipseIn: CGRect(x: p.x - 3.2, y: p.y - 1.2, width: 1.8, height: 1.5)), with: .color(Color.white.opacity(0.9)))
        // A chip of shell lifted at the edge of the hole.
        let chip = look.lifted(shell, 0.35)
        var chips = Path()
        chips.move(to: CGPoint(x: p.x + 3.6, y: p.y - 3.0)); chips.addLine(to: CGPoint(x: p.x + 8, y: p.y - 5)); chips.addLine(to: CGPoint(x: p.x + 6.6, y: p.y - 0.6))
        chips.closeSubpath()
        c.fill(chips, with: .color(chip.color()))
        c.stroke(chips, with: .color(crack.color(0.6)), lineWidth: 0.6)
    }

    // MARK: What is left of the shell

    /// The lower half of the egg a hatchling sits in (behind it, with a
    /// jagged rim and a pale lining) or, in front, the pieces lying about it.
    func hatchShell(_ c: GraphicsContext, front: Bool) {
        let shell = look.tone(eggBase, dim: 0.7)
        let lining = look.tone(0xF6EAD8, dim: 0.7)
        let L = look.L
        if front {
            var shards = Path()
            shards.move(to: CGPoint(x: 21, y: 105)); shards.addLine(to: CGPoint(x: 29, y: 98.6)); shards.addLine(to: CGPoint(x: 37, y: 105.6))
            shards.addLine(to: CGPoint(x: 32, y: 109.6)); shards.addLine(to: CGPoint(x: 23, y: 109.2)); shards.closeSubpath()
            shards.move(to: CGPoint(x: 91, y: 108.4)); shards.addLine(to: CGPoint(x: 97, y: 103)); shards.addLine(to: CGPoint(x: 103, y: 109)); shards.closeSubpath()
            form(c, shards, centre: CGPoint(x: 60, y: 104), radius: 40, look.lifted(shell, 0.3), shell, shell.shifted(-12, 6), highlight: 0.3, core: 0.5)
            return
        }
        var cup = Path()
        cup.move(to: CGPoint(x: 24, y: 90))
        for (x, y) in [(31.0, 79.0), (38, 88), (46, 77), (54, 86), (63, 75), (72, 86), (81, 77), (89, 87), (96, 79), (99, 91)] { cup.addLine(to: CGPoint(x: x, y: y)) }
        cup.addLine(to: CGPoint(x: 97, y: 100))
        cup.addQuadCurve(to: CGPoint(x: 26, y: 100), control: CGPoint(x: 61, y: 122))
        cup.closeSubpath()
        form(c, cup, centre: CGPoint(x: 60, y: 98), radius: 34, shell.mix(RGB(255, 255, 255), 0.4), shell, shell.shifted(-13, 6), highlight: 0.3)
        var rimLine = Path()
        rimLine.move(to: CGPoint(x: 24, y: 91.5))
        for (x, y) in [(31.0, 80.5), (38, 89.5), (46, 78.5), (54, 87.5), (63, 76.5), (72, 87.5), (81, 78.5), (89, 88.5), (96, 80.5), (99, 92.5)] { rimLine.addLine(to: CGPoint(x: x, y: y)) }
        c.stroke(rimLine, with: .color(lining.color(0.95)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
        c.fill(Path(ellipseIn: CGRect(x: 40 + L.x * 3, y: 97, width: 14, height: 4)), with: .color(Color.white.opacity(0.2)))
    }
}
