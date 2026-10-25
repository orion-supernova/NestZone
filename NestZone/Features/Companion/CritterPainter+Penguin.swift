import SwiftUI

// MARK: - The penguin

extension CritterPainter {
    /// A penguin on the waddler's terms (the same moods, bowl, eye and cap),
    /// upright: it does not bounce, it rocks from foot to foot, a foot
    /// lifting as the body leans over the other. Bright, it waves a flipper;
    /// content, it stands easy and sways a hair; thirsty, the head bows to the
    /// bowl; dozing, the head sinks to the shoulder and the flippers hug in.
    func penguin(_ c: GraphicsContext) {
        let g = CritterGeometry.penguin(plan)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly
        let orange = look.accent
        let baby = babyness
        let side = look.L.x > 0 ? 0 : 1
        var b = c
        let sink = motion.by(3.5, 2.2, 0.8, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.03 * w.doze, y: 1 - 0.05 * slump - 0.08 * baby)
        b.translateBy(x: -60, y: -108)

        // The rock, and which foot it is that lifts.
        let step = frame.reduceMotion ? 0 : sin(time * 2 * .pi / 0.9)
        let lift = 2.6 * w.bright

        // Feet.
        for (i, foot) in g.feet.enumerated() {
            var f = b
            f.translateBy(x: 0, y: -lift * max(0, i == 0 ? step : -step))
            form(f, foot, centre: CGPoint(x: i == 0 ? 49 : 69, y: 107.5), radius: 9, look.lifted(orange, 0.25), orange, orange.shifted(-12, -3), highlight: 0.3, core: 0.5, rim: false)
            f.stroke(g.toes, with: .color(orange.shifted(-24).color(0.55)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }
        form(b, g.tail, centre: CGPoint(x: 88, y: 104), radius: 10, light, coat, dark, highlight: 0.2, core: 0.6, rim: false)

        // The body, dark, and the white front over it.
        form(b, g.body[side], centre: PenguinGeometry.bodyCentre, radius: 34, light, coat, dark, highlight: 0.5)
        let white = belly
        form(b, g.bellyFur, centre: CGPoint(x: 50, y: 82), radius: 30, look.lifted(white, 0.2), white, white.mix(look.cool, 0.35).shifted(-6, 2), highlight: 0.35, core: 0.5, rim: false)

        // The flipper: it hangs from the shoulder, waves when it is bright,
        // hugs in when it dozes.
        var fc = b
        fc.translateBy(x: 61, y: 61)
        var swing = motion.by(-0.1, 0.12, 0.06, -0.3)
        if !frame.reduceMotion { swing -= (0.5 + 0.5 * sin(time * 7)) * 0.55 * w.bright; swing += 0.03 * sin(time * 1.7) * w.content }
        if let hop, hop < 0.66 { swing -= abs(sin(hop / 0.22 * .pi)) * 0.7 }
        fc.rotate(by: .radians(swing))
        form(fc, g.flipper, centre: CGPoint(x: 2, y: 16), radius: 20, light, coat.mix(light, 0.3), coat.shifted(-4), highlight: 0.2, core: 0.7)
        fc.stroke(g.flipperEdge, with: .color(look.lifted(light, 0.45).color(0.7)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        // The head, over all of it.
        var h = b
        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3) * w.thirst
        let tilt = motion.by(-0.34, -0.3, 0.04, 0) + (frame.reduceMotion ? 0 : 0.05 * sin(time / 3.1 * .pi * 2) * w.bright) + 0.1 * glance
        h.translateBy(x: motion.by(7, -3, 0, 0) + 1.2 * glance, y: motion.by(9, 5, 0.5, -0.8))
        h.translateBy(x: 46, y: 68)
        h.rotate(by: .radians(tilt))
        h.translateBy(x: -46, y: -68)
        penguinHead(h, babyness: baby)
    }

    /// The penguin's head, at the duckling's place: dark crown, a white face
    /// with the eye in it, a patch of gold at the neck, a bill that opens.
    func penguinHead(_ c: GraphicsContext, babyness: Double) {
        let g = CritterGeometry.penguin(plan)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let accent = look.accent
        let L = look.L
        let side = L.x > 0 ? 0 : 1
        var h = c
        let grow = 1 + 0.34 * babyness
        h.translateBy(x: 46, y: 68)
        h.scaleBy(x: grow, y: grow)
        h.translateBy(x: -46, y: -68)

        form(h, g.headFur[side], centre: PenguinGeometry.headCentre, radius: 24, light, coat, dark, highlight: 0.55)
        // The gold at the side of the neck, soft to its edge.
        let gold = look.tone(0xFFC857, dim: 0.5)
        var patch = Path()
        patch.move(to: CGPoint(x: -9, y: 0))
        patch.addQuadCurve(to: CGPoint(x: 9, y: 0.4), control: CGPoint(x: 0, y: -10.5))
        patch.addQuadCurve(to: CGPoint(x: -9, y: 0), control: CGPoint(x: 0, y: 1.2))
        h.fill(patch.applying(CGAffineTransform(translationX: 56, y: 56.5).rotated(by: 0.95)), with: .linearGradient(
            Gradient(stops: [.init(color: gold.color(0), location: 0), .init(color: look.lifted(gold, 0.12).color(), location: 0.35), .init(color: gold.color(), location: 0.7),
                             .init(color: gold.color(0), location: 1)]), startPoint: CGPoint(x: 51, y: 50), endPoint: CGPoint(x: 61, y: 63)))
        // The white face: a disc, soft at the rim, lit like the rest.
        h.fill(Path(ellipseIn: CGRect(x: 30, y: 39, width: 22, height: 20)), with: .radialGradient(
            Gradient(stops: [.init(color: look.lifted(belly, 0.25).color(), location: 0), .init(color: belly.color(), location: 0.62), .init(color: belly.shifted(-8, 3).color(0.9), location: 0.84),
                             .init(color: belly.color(0), location: 1)]),
            center: CGPoint(x: 41.4 + L.x * 1.5, y: 49 + L.y * 1.5), startRadius: 0, endRadius: 11.5))

        // The bill: its lower half drops when it is bright, a little when it wants water.
        let open = max(w.bright * 0.8, w.thirst * 0.4) * (frame.reduceMotion ? 0.6 : 1)
        var low = h
        low.translateBy(x: 34, y: 55.4)
        low.rotate(by: .radians(-0.36 * open))
        low.translateBy(x: -34, y: -55.4)
        if open > 0.08 {
            h.fill(Path(ellipseIn: CGRect(x: 17, y: 54.4, width: 16, height: 2 + 4.2 * open)), with: .color(Color(red: 0.32, green: 0.1, blue: 0.12, opacity: min(1, open * 2.2))))
            if open > 0.4 { h.fill(Path(ellipseIn: CGRect(x: 22, y: 57.4, width: 7, height: 1.8 * open)), with: .color(look.tone(0xF08A9A).color(Ink.clamp(open)))) }
        }
        form(low, g.lowerBill, centre: CGPoint(x: 26, y: 58), radius: 9, accent.shifted(-4), accent.shifted(-10, -1), accent.shifted(-22, -3), highlight: 0.15, core: 0.7, rim: false)
        form(h, g.upperBill, centre: CGPoint(x: 24, y: 53), radius: 12, look.lifted(accent, 0.3), accent, accent.shifted(-14, -3), highlight: 0.5, core: 0.6)
        h.fill(Path(ellipseIn: CGRect(x: 29.4, y: 51.4, width: 1.3, height: 1.1)), with: .color(look.ink.opacity(0.5)))
        h.fill(Path(ellipseIn: CGRect(x: 21 + L.x * 1.2, y: 50.9, width: 7, height: 1.1)), with: .color(Color.white.opacity(0.5)))

        let blush = Ink.lerp(0.2, 0.95, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.6 * w.thirst)
        h.fill(Path(ellipseIn: CGRect(x: 43, y: 53, width: 10, height: 7)), with: .radialGradient(
            Gradient(colors: [look.tone(0xFF8FA3).color(blush), look.tone(0xFF8FA3).color(0)]), center: CGPoint(x: 48, y: 56.5), startRadius: 0, endRadius: 5))

        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3)
        let gaze = CGPoint(x: Ink.lerp(-0.62 * w.thirst, 0.02, glance * w.thirst), y: Ink.lerp(0.78 * w.thirst, 0.02, glance * w.thirst) - 0.06 * w.bright)
        let size = 1 + 0.3 * babyness
        eye(h, at: CGPoint(x: 41.4, y: 47.4), side: -1, rx: 4.6 * size, ry: 5.1 * size, gaze: gaze, droop: motion.by(1, 0.05, 0.05, 0), lid: belly.shifted(-6))
        if w.thirst > 0.05 {
            var brow = Path()
            brow.move(to: CGPoint(x: 36.2, y: 40)); brow.addQuadCurve(to: CGPoint(x: 46.8, y: 41.2), control: CGPoint(x: 41, y: 38.2 - 1.2 * w.thirst))
            h.stroke(brow, with: .color(mark.color(0.55 * w.thirst)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        motion.nightcap(h)
    }
}
