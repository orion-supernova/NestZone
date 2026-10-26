import SwiftUI

// MARK: - What only one species does

extension CritterPainter {
    // MARK: The hamster's hands

    /// Two short arms and two small paws held up under the chin, and, when it
    /// is bright, the sunflower seed it is holding: a hamster does not stand on
    /// its front feet, it eats.
    func hamsterHands(_ b: GraphicsContext, _ g: SitGeometry) {
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly
        let w = motion.weights
        form(b, g.arms, centre: CGPoint(x: 47, y: 90), radius: 14, light, coat, dark, highlight: 0.3, core: 0.7)
        // The seed, in front of the arms and under the paws that hold it.
        let a = Ink.smooth(w.bright / 0.6)
        if a > 0.02 {
            let nibble = frame.reduceMotion ? 0 : sin(time * 8) * 0.35 * w.bright
            var s = b
            s.opacity = a
            s.translateBy(x: 47, y: 74.4 + nibble)
            s.rotate(by: .radians(-0.28))
            s.scaleBy(x: 1.75, y: 1.75)
            let shell = look.tone(0x4A4640, dim: 0.5), stripe = look.tone(0xEDE6D6, dim: 0.5)
            s.fill(g.seed, with: .linearGradient(Gradient(colors: [look.lifted(shell, 0.28).color(), shell.color(), shell.shifted(-8).color()]),
                                                  startPoint: CGPoint(x: look.L.x * 3, y: -3), endPoint: CGPoint(x: -look.L.x * 3, y: 3)))
            s.stroke(g.seedStripes, with: .color(stripe.color(0.72)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
            s.fill(Path(ellipseIn: CGRect(x: -3.6 + look.L.x * 1.4, y: -2.6, width: 3.4, height: 1)), with: .color(Color.white.opacity(0.4)))
        }
        form(b, g.handPaws, centre: CGPoint(x: 47, y: 78), radius: 8, look.lifted(belly, 0.3), belly, belly.shifted(-9, 3), highlight: 0.4, core: 0.5)
        b.stroke(g.handToes, with: .color(dark.color(0.5)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
    }

    // MARK: The hedgehog

    /// Sitting: a dome of spines combed back from the face, the pale belly
    /// and two small feet in front, the head low with a hood of spines over
    /// the crown. The spines are the new fur kind (`SpineField`): rows of
    /// dabs from the rim in, each row a little lighter, every spine with a
    /// pale tip.
    func hedgehogSit(_ c: GraphicsContext) {
        let g = CritterGeometry.sit(plan)
        let hg = CritterGeometry.hedgehog(plan)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly
        let baby = babyness
        var b = c
        let sink = motion.by(3, 2.4, 1.2, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.01 * sink, y: (1 - 0.022 * sink) * plan.bodyHeight)
        b.translateBy(x: -60, y: -108)
        let L = look.L
        let foot = belly.mix(look.accent, 0.4)

        // The feet: small and pale, the far ones darker.
        b.fill(Path(ellipseIn: CGRect(x: 52, y: 103.4, width: 12, height: 6.4)), with: .color(foot.shifted(-12).color()))
        form(b, Path(ellipseIn: CGRect(x: 69, y: 104, width: 14, height: 6.4)), centre: CGPoint(x: 76, y: 107), radius: 8, look.lifted(foot, 0.2), foot.shifted(-6), foot.shifted(-12, 3), highlight: 0.3, core: 0.5)

        // The dome, dark between the spines, and the spines on it.
        form(b, hg.dome, centre: CGPoint(x: 68, y: 80), radius: 34, dark.mix(coat, 0.3), dark, dark.shifted(-8), highlight: 0, core: 0.5, rim: false)
        spineRows(b, hg.coat.rows)
        // The cool of the far side and the light on the near one, over the whole mass.
        glow(b, hg.dome, look.cool, centre: CGPoint(x: 68 - L.x * 22, y: 80 - L.y * 18), radius: 34, alpha: look.coolAlpha * 0.9)
        glow(b, hg.dome, look.lifted(light, 0.4), centre: CGPoint(x: 68 + L.x * 14, y: 80 + L.y * 12), radius: 26, alpha: 0.22)

        // The belly, pale, under the face, fading into the spines.
        b.fill(hg.belly, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.25).color(0.97), location: 0), .init(color: belly.color(0.9), location: 0.5),
                                                                 .init(color: belly.color(0), location: 1)]),
                                               center: CGPoint(x: 52, y: 98), startRadius: 0, endRadius: 21))
        form(b, Path(ellipseIn: CGRect(x: 36, y: 102.6, width: 14, height: 7.4)), centre: CGPoint(x: 43, y: 106), radius: 8, look.lifted(foot, 0.3), foot, foot.shifted(-9, 3), highlight: 0.4, core: 0.5)
        var toes = Path()
        for x in [39.4, 42.6, 45.8] { toes.move(to: CGPoint(x: x, y: 106.8)); toes.addLine(to: CGPoint(x: x, y: 109.4)) }
        b.stroke(toes, with: .color(dark.color(0.4)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        glow(b, Path(ellipseIn: CGRect(x: 32 - L.x * 3, y: 58 - L.y * 2, width: 36, height: 24)), dark.mix(look.cool, 0.4), centre: CGPoint(x: 50 - L.x * 3, y: 70), radius: 15, alpha: 0.3)

        neckwear(b, at: CGPoint(x: 48, y: 72), span: 14, size: 0.9)
        placedHead(b, w, baby: baby)
    }

    /// The rows of a `SpineField`: blades from the darkest outer row to the
    /// lightest inner one, then their pale tips, each lit on the side of the
    /// sky.
    func spineRows(_ c: GraphicsContext, _ rows: [SpineField.Row]) {
        let dark = look.dark, coat = look.coat, light = look.light
        let tip = look.lifted(light, 0.12).mix(look.belly, 0.3)
        let L = look.L
        for (i, row) in rows.enumerated() {
            let t = Double(i) / Double(max(1, rows.count - 1))
            c.fill(row.blades, with: .color(dark.mix(coat, 0.15 + 0.65 * t).color()))
            c.fill(row.tips, with: .color(tip.shifted(-8 + 6 * t).color(0.92)))
            var lit = c
            lit.translateBy(x: L.x * 0.55, y: L.y * 0.55)
            lit.fill(row.tips, with: .color(look.lifted(tip, 0.45).color(0.3)))
        }
    }

    /// The hood: spines that come over the crown between the ears, in head
    /// space, in front of the ears and behind the eyes.
    func hood(_ h: GraphicsContext) {
        let hg = CritterGeometry.hedgehog(plan)
        h.fill(hg.hoodBase, with: .linearGradient(Gradient(stops: [.init(color: look.dark.mix(look.coat, 0.3).color(), location: 0), .init(color: look.dark.color(0.95), location: 0.55),
                                                                    .init(color: look.dark.color(0), location: 1)]),
                                                  startPoint: CGPoint(x: 0, y: -18), endPoint: CGPoint(x: 0, y: -3)))
        spineRows(h, hg.hood.rows)
    }

    /// Asleep, it is a ball: rings of spines from the rim to the middle, a
    /// pale snout and one shut eye in the gap low on the left, the nightcap
    /// on top.
    func hedgehogBall(_ c: GraphicsContext) {
        let hg = CritterGeometry.hedgehog(plan)
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly
        let L = look.L
        var b = c
        let breath = frame.reduceMotion ? 0 : sin(time / 4.2 * .pi * 2)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.01 * breath, y: 1 + 0.026 * breath)
        b.translateBy(x: -60, y: -108)
        let ball = Path(ellipseIn: CGRect(x: 29, y: 50, width: 62, height: 57))
        form(b, ball, centre: CGPoint(x: 60, y: 78), radius: 34, dark.mix(coat, 0.3), dark, dark.shifted(-8), highlight: 0, core: 0.5, rim: false)
        spineRows(b, hg.ball.rows)
        glow(b, ball, look.cool, centre: CGPoint(x: 60 - L.x * 22, y: 78 - L.y * 18), radius: 34, alpha: look.coolAlpha * 0.9)
        glow(b, ball, look.lifted(light, 0.4), centre: CGPoint(x: 60 + L.x * 14, y: 78 + L.y * 12), radius: 26, alpha: 0.22)

        // The face in the gap: a snout, a nose, a closed eye, a little ear.
        let foot = belly.mix(look.accent, 0.4)
        var f = b
        f.translateBy(x: 36, y: 98)
        f.rotate(by: .radians(-0.16))
        let ear = Path(ellipseIn: CGRect(x: 4, y: -13.2, width: 9, height: 8.4))
        form(f, ear, centre: CGPoint(x: 8.5, y: -9), radius: 6, look.lifted(look.accent, 0.2), look.accent, look.accent.shifted(-12), highlight: 0.3, core: 0.6)
        let snout = Path(ellipseIn: CGRect(x: -12, y: -7.2, width: 27, height: 15))
        form(f, snout, centre: CGPoint(x: 2, y: 0), radius: 14, look.lifted(belly, 0.2), belly, belly.shifted(-10, 3), highlight: 0.4, core: 0.7)
        f.fill(Path(ellipseIn: CGRect(x: -13.6, y: -2.6, width: 5.6, height: 5)), with: .color(look.nose.color()))
        f.fill(Path(ellipseIn: CGRect(x: -12.4 + L.x * 0.6, y: -2.2, width: 2, height: 1.1)), with: .color(Color.white.opacity(0.6)))
        var lid = Path()
        lid.move(to: CGPoint(x: -1.4, y: -2.6)); lid.addQuadCurve(to: CGPoint(x: 5.6, y: -3.2), control: CGPoint(x: 2.2, y: 0.2))
        f.stroke(lid, with: .color(look.ink.opacity(0.85)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        var lash = Path()
        lash.move(to: CGPoint(x: 5.4, y: -3.1)); lash.addLine(to: CGPoint(x: 7, y: -4.4))
        f.stroke(lash, with: .color(look.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))

        // The cap, on the top of the ball.
        var cap = b
        cap.translateBy(x: 54, y: 66)
        cap.rotate(by: .radians(-0.2))
        self.cap(cap, motion.weights)
        // The hat takes the cap's place on top of the ball, and the neck piece goes round the
        // gap the face looks out of.
        hat(b, foot: CGPoint(x: 56, y: 53), tilt: -0.2, scale: 0.95)
        neckwear(b, at: CGPoint(x: 49, y: 94), span: 13, tilt: -0.9, size: 0.85)
    }
}
