import SwiftUI

// MARK: - The turtle

extension CritterPainter {
    /// A turtle on the shell's terms: the shell is the body, and what acts
    /// is the neck. Bright, it stretches up and walks on the spot, mouth
    /// open; content, the head sits out easy and blinks slowly; thirsty, the
    /// neck sags forward and the head hangs to the bowl; dozing, the head and
    /// the legs draw in under the rim, the shell settles on the floor, the
    /// nightcap goes on the shell.
    func turtle(_ c: GraphicsContext) {
        let g = CritterGeometry.turtle(plan)
        let w = motion.weights
        let skin = look.coat, skinLight = look.light, skinDark = look.dark
        let baby = babyness
        let tuck = w.doze
        var b = c
        // The shell settles when it is tired and the legs fold away.
        let settle = motion.by(4, 2.4, 0.8, -1.4)
        b.translateBy(x: 0, y: settle)

        // Walking on the spot: opposite legs lift together.
        let step = frame.reduceMotion ? 0 : sin(time * 2 * .pi / 0.8) * w.bright
        let legScale = 1 - 0.7 * tuck
        func leg(_ x: Double, far: Bool, lift: Double) {
            var l = b
            l.translateBy(x: x, y: 94)
            l.scaleBy(x: 1, y: legScale)
            l.translateBy(x: 0, y: -max(0, lift) * 2.6)
            let tone = far ? skinDark.mix(skin, 0.3) : skin
            form(l, g.leg, centre: CGPoint(x: 0, y: 7), radius: 11, far ? tone : skinLight, tone, skinDark, highlight: far ? 0 : 0.3, core: far ? 0 : 0.7, rim: !far)
            l.fill(g.claws, with: .color(look.belly.shifted(-4).color(far ? 0.5 : 0.95)))
        }
        // The tail, behind the shell.
        let wag = frame.reduceMotion ? 0 : sin(time * 9) * 0.16 * w.bright + sin(time * 1.6) * 0.04
        var t = b
        t.translateBy(x: 104, y: 98)
        t.rotate(by: .radians(wag))
        t.translateBy(x: -104, y: -98)
        form(t, g.tail, centre: CGPoint(x: 110, y: 99), radius: 9, skinLight, skin, skinDark, highlight: 0.2, core: 0.6, rim: false)

        leg(58, far: true, lift: -step)
        leg(99, far: true, lift: step)

        // The neck and head, behind the shell's rim, so a tucked head
        // withdraws under it.
        neckAndHead(b, g, baby: baby)

        // The rim, the dome, the scutes.
        let L = look.L
        let shell = look.tone(plan.shell, dim: 0.5), plate = look.tone(plan.plates, dim: 0.5)
        let rim = look.belly.mix(skin, 0.25)
        form(b, g.skirt, centre: CGPoint(x: 74, y: 104), radius: 36, look.lifted(rim, 0.2), rim, rim.shifted(-10, 2), highlight: 0.2, core: 0.5, rim: false)
        form(b, g.dome, centre: TurtleGeometry.shellCentre, radius: 38, shell.mix(plate, 0.25), shell, shell.shifted(-9, 3), highlight: 0.45, core: 0.9)
        // The scutes: lighter, lit from the sky, with their growth rings.
        b.fill(g.plates, with: ramp(TurtleGeometry.shellCentre, 40, look.lifted(plate, 0.18), plate, plate.shifted(-12, 2)))
        var lit = b
        lit.translateBy(x: -L.x * 0.7, y: -L.y * 0.7)
        lit.stroke(g.plates, with: .color(shell.shifted(-14).color(0.5)), style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))
        b.stroke(g.rings, with: .color(shell.mix(plate, 0.3).shifted(-8).color(0.42)), style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))
        var hi = b
        hi.translateBy(x: L.x * 0.7, y: L.y * 0.7)
        hi.stroke(g.rings, with: .color(look.lifted(plate, 0.5).color(0.28)), style: StrokeStyle(lineWidth: 0.6, lineJoin: .round))
        glow(b, g.dome, look.cool, centre: CGPoint(x: 73 - L.x * 26, y: 80 - L.y * 20), radius: 40, alpha: look.coolAlpha * 0.9)
        glow(b, g.dome, look.lifted(plate, 0.5), centre: CGPoint(x: 73 + L.x * 16, y: 66 + L.y * 10), radius: 26, alpha: 0.2)

        leg(46, far: false, lift: step)
        leg(88, far: false, lift: -step)

        // The nightcap on the shell while it sleeps.
        if tuck > 0.01 || frame.domeLift > 0 {
            var cap = b
            cap.translateBy(x: 70, y: 70)
            cap.rotate(by: .radians(0.12))
            cap.scaleBy(x: 1.25, y: 1.25)
            self.cap(cap, w)
        }
    }

    /// The neck as a ribbon from under the shell to the head, and the head
    /// at its end. Where the head is, and how it is held, is the mood.
    private func neckAndHead(_ b: GraphicsContext, _ g: TurtleGeometry, baby: Double) {
        let w = motion.weights
        let skin = look.coat, skinLight = look.light, skinDark = look.dark
        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3) * w.thirst
        var hx = motion.by(32, 22.5, 28, 27)
        var hy = motion.by(91, 92, 77, 63)
        if !frame.reduceMotion {
            hx += sin(time / 3.1 * .pi * 2) * 1.2 * w.bright - 1.4 * glance
            hy += sin(time / 3.6 * .pi * 2) * 0.8 * (w.content + w.bright)
        }
        let base = CGPoint(x: 55, y: 90)
        let spine = PlantPainter.cubic(base, CGPoint(x: base.x - 9, y: base.y + 1), CGPoint(x: hx + 9, y: hy + 11 - 6 * w.bright), CGPoint(x: hx + 1, y: hy + 2), n: 9)
        let neck = PlantPainter.ribbon(spine, 15, 11.5 + 2 * baby)
        form(b, neck, centre: CGPoint(x: (base.x + hx) / 2, y: (base.y + hy) / 2), radius: 18, skinLight, skin, skinDark, highlight: 0.35, core: 0.8)
        // Folds in the skin of the neck.
        var folds = Path()
        for i in [3, 5] where i < spine.count - 1 {
            let p = spine[i], q = spine[i + 1]
            let a = atan2(q.y - p.y, q.x - p.x) + .pi / 2
            folds.move(to: CGPoint(x: p.x - cos(a) * 4, y: p.y - sin(a) * 4))
            folds.addQuadCurve(to: CGPoint(x: p.x + cos(a) * 4, y: p.y + sin(a) * 4), control: CGPoint(x: p.x + 1.5, y: p.y + 0.4))
        }
        b.stroke(folds, with: .color(skinDark.color(0.35)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))

        var h = b
        h.translateBy(x: hx, y: hy)
        h.rotate(by: .radians(motion.by(0.12, 0.34, 0.02, -0.2) + 0.08 * glance))
        let grow = 1 + 0.42 * baby
        h.scaleBy(x: grow, y: grow)
        turtleHead(h, babyness: baby)
    }

    /// The turtle's head about its own centre, looking left: a rounded wedge
    /// of skin, a pale chin, a nostril, spots on the crown, one big eye, a
    /// mouth that opens.
    func turtleHead(_ c: GraphicsContext, babyness: Double) {
        let g = CritterGeometry.turtle(plan)
        let w = motion.weights
        let skin = look.coat, skinLight = look.light, skinDark = look.dark, belly = look.belly, mark = look.mark
        let L = look.L
        var h = c
        form(h, g.head, centre: CGPoint(x: 0, y: 0), radius: 14, skinLight, skin, skinDark, highlight: 0.5, core: 0.7)
        h.fill(g.chin, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.2).color(0.9), location: 0), .init(color: belly.color(0.6), location: 0.6),
                                                              .init(color: belly.color(0), location: 1)]), center: CGPoint(x: -5, y: 8), startRadius: 0, endRadius: 8.5))
        hairs(h, g.spots, dark: mark, light: look.lifted(skinLight, 0.2), alpha: 0.42)
        // Nostril.
        h.fill(Path(ellipseIn: CGRect(x: -13.6, y: -0.2, width: 1.5, height: 1.1)), with: .color(mark.color(0.8)))

        // The mouth: a smile that opens (bright), a small "o" (wanting).
        let open = max(w.bright * 0.9, w.thirst * 0.5)
        var mouth = Path()
        mouth.move(to: CGPoint(x: -14.6, y: 4.4))
        mouth.addQuadCurve(to: CGPoint(x: -3.4, y: 5.8 - 0.4 * w.bright), control: CGPoint(x: -9, y: 7.4 + 3.2 * open))
        if open > 0.1 {
            var inside = mouth
            inside.addQuadCurve(to: CGPoint(x: -14.6, y: 4.4), control: CGPoint(x: -9, y: 4.6))
            h.fill(inside, with: .color(Color(red: 0.32, green: 0.12, blue: 0.14, opacity: Ink.clamp(open * 2))))
            if open > 0.4 { h.fill(Path(ellipseIn: CGRect(x: -11.4, y: 6.4, width: 5.6, height: 1.8 * open)), with: .color(look.tone(0xF08A9A).color(Ink.clamp(open)))) }
        }
        h.stroke(mouth, with: .color(look.dark.shifted(-18).color(0.75)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))

        let blush = Ink.lerp(0.15, 0.9, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.7 * w.thirst)
        h.fill(Path(ellipseIn: CGRect(x: -2, y: 0.4, width: 9, height: 6.4)), with: .radialGradient(
            Gradient(colors: [look.tone(0xFF8FA3).color(blush), look.tone(0xFF8FA3).color(0)]), center: CGPoint(x: 2.5, y: 3.6), startRadius: 0, endRadius: 4.4))

        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3)
        let gaze = CGPoint(x: Ink.lerp(-0.62 * w.thirst, 0.02, glance * w.thirst), y: Ink.lerp(0.78 * w.thirst, 0.02, glance * w.thirst) - 0.06 * w.bright)
        let size = 1 + 0.3 * babyness
        eye(h, at: CGPoint(x: -4.6, y: -2.4), side: -1, rx: 4.4 * size, ry: 4.9 * size, gaze: gaze, droop: motion.by(1, 0.05, 0.05, 0), lid: skin.mix(skinLight, 0.2))
        if w.thirst > 0.05 {
            var brow = Path()
            brow.move(to: CGPoint(x: -9.6, y: -8.8)); brow.addQuadCurve(to: CGPoint(x: 0.6, y: -8), control: CGPoint(x: -4.4, y: -11.4 - w.thirst))
            h.stroke(brow, with: .color(mark.color(0.5 * w.thirst)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        _ = L
    }
}
