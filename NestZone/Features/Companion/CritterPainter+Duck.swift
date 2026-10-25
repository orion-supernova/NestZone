import SwiftUI

// MARK: - The waddler (the duckling)

extension CritterPainter {
    /// The duckling, on the kitten's terms: forms lit from the sky, down
    /// breaking the outline, an eye built in layers, a bill that opens. It
    /// bounces rather than breathes (it is a bird), and its moods are the
    /// same four: tall and bobbing when bright, easy when content, head
    /// down and turned to the bowl when thirsty, and when it dozes the head
    /// comes down onto the chest and the whole bird squashes into a round.
    func waddler(_ c: GraphicsContext) {
        if plan.species == .penguin { penguin(c); return }
        let g = CritterGeometry.duck(plan)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let baby = babyness
        var b = c
        // A sleepy one sits lower and rounder.
        let sink = motion.by(5, 2.4, 0.8, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.04 * w.doze, y: 1 - 0.07 * slump - 0.1 * baby)
        b.translateBy(x: -60, y: -108)
        let side = look.L.x > 0 ? 0 : 1

        // Feet: webbed, orange, toes forward.
        let orange = look.accent
        for (i, foot) in g.feet.enumerated() {
            let x = i == 0 ? 52.0 : 74.0
            form(b, foot, centre: CGPoint(x: x, y: 106.5), radius: 9, look.lifted(orange, 0.25), orange, orange.shifted(-12, -3), highlight: 0.3, core: 0.5, rim: false)
        }
        b.stroke(g.toes, with: .color(orange.shifted(-24).color(0.55)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))

        // The body: an egg of down, lit on its shoulder, with its down.
        form(b, g.body[side], centre: DuckGeometry.bodyCentre, radius: 32, light, coat, dark, highlight: 0.62)
        hairs(b, g.down, dark: dark, light: look.lifted(light, 0.3), alpha: 0.26)
        // The breast, paler, soft to the rim.
        b.fill(g.belly, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.3).color(0.9), location: 0), .init(color: belly.color(0.7), location: 0.45),
                                                                .init(color: belly.color(0), location: 1)]),
                                              center: CGPoint(x: 47, y: 90), startRadius: 0, endRadius: 21))

        // The little upturned tail.
        form(b, g.tail, centre: CGPoint(x: 93, y: 74), radius: 12, light, coat, mark.shifted(-4), highlight: 0.2, core: 0.6)
        b.stroke(g.tailLines, with: .color(mark.shifted(-14).color(0.35)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))

        // The wing droops when sleepy, lifts when bright and flutters, and
        // flaps on a hop.
        var wc = b
        wc.translateBy(x: 66, y: 78)
        var tilt = Ink.lerp(0.24, 0, motion.awake) + 0.2 * w.doze - max(0, frame.mood - 0.82) * 0.9
        if let hop, hop < 0.66 { tilt -= abs(sin(hop / 0.22 * .pi)) * 0.49 }
        if !frame.reduceMotion { tilt -= (0.5 + 0.5 * sin(time * 13)) * 0.12 * w.bright }
        wc.rotate(by: .radians(tilt))
        wc.translateBy(x: -66, y: -78)
        let wingC = mark
        form(wc, g.wing, centre: CGPoint(x: 72, y: 80), radius: 18, wingC.mix(light, 0.35), wingC, wingC.shifted(-12, -2), highlight: 0.3, core: 0.7)
        var lit = wc
        lit.translateBy(x: look.L.x * 0.6, y: look.L.y * 0.6)
        lit.stroke(g.wingFeathers, with: .color(look.lifted(light, 0.3).color(0.5)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        wc.stroke(g.wingFeathers, with: .color(wingC.shifted(-18).color(0.55)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))

        // The head: a sleepy one's comes down onto its chest, a thirsty one's
        // bows to the bowl, a bright one holds it up and sways.
        var h = b
        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3) * w.thirst
        let head = motion.by(-0.42, -0.28, 0.05, 0) + (frame.reduceMotion ? 0 : 0.05 * sin(time / 3.1 * .pi * 2) * w.bright) + 0.1 * glance
        h.translateBy(x: motion.by(9, -3, 0, 0) + 1.2 * glance, y: motion.by(10, 5, 0.5, -0.8))
        h.translateBy(x: 46, y: 68)
        h.rotate(by: .radians(head))
        h.translateBy(x: -46, y: -68)
        duckHead(h, babyness: baby)
    }

    /// The duckling's head, in the box: down on the cheek and the back, a
    /// tuft, a bill in two halves, the cheek's blush, the eye.
    func duckHead(_ c: GraphicsContext, babyness: Double) {
        if plan.species == .penguin { penguinHead(c, babyness: babyness); return }
        let g = CritterGeometry.duck(plan)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, mark = look.mark
        let accent = look.accent
        let L = look.L
        var h = c
        // A baby's head is big, and grows from the neck.
        let grow = 1 + 0.34 * babyness
        h.translateBy(x: 46, y: 68)
        h.scaleBy(x: grow, y: grow)
        h.translateBy(x: -46, y: -68)

        // The tuft stands behind the crown, then the head over its roots.
        form(h, g.tuft, centre: CGPoint(x: 48, y: 26), radius: 10, light, coat, mark.shifted(-6), highlight: 0.2, core: 0.5)
        form(h, g.headDown, centre: DuckGeometry.headCentre, radius: 24, light, coat, dark, highlight: 0.62)
        hairs(h, g.headHairs, dark: dark, light: look.lifted(light, 0.3), alpha: 0.26)

        // The bill: its lower half drops and a mouth shows when it is bright,
        // and a little when it wants water.
        let open = max(w.bright * 0.85, w.thirst * 0.4) * (frame.reduceMotion ? 0.6 : 1)
        var low = h
        low.translateBy(x: 36, y: 57.5)
        low.rotate(by: .radians(-0.4 * open))
        low.translateBy(x: -36, y: -57.5)
        if open > 0.08 {
            let hole = Path(ellipseIn: CGRect(x: 23, y: 55.6, width: 14.5, height: 2 + 4.4 * open))
            h.fill(hole, with: .color(Color(red: 0.32, green: 0.1, blue: 0.12, opacity: min(1, open * 2.2))))
            if open > 0.4 { h.fill(Path(ellipseIn: CGRect(x: 27, y: 58.6, width: 7, height: 1.8 * open)), with: .color(look.tone(0xF08A9A).color(Ink.clamp(open)))) }
        }
        form(low, g.lowerBill, centre: CGPoint(x: 30, y: 59.5), radius: 8, accent.shifted(-2), accent.shifted(-9, -1), accent.shifted(-22, -3), highlight: 0.15, core: 0.7, rim: false)
        form(h, g.upperBill, centre: CGPoint(x: 29, y: 55), radius: 11, look.lifted(accent, 0.3), accent, accent.shifted(-14, -3), highlight: 0.5, core: 0.6)
        h.fill(Path(ellipseIn: CGRect(x: 30.6, y: 53.6, width: 1.3, height: 1.1)), with: .color(look.ink.opacity(0.5)))
        h.fill(Path(ellipseIn: CGRect(x: 25.5 + L.x * 1.2, y: 52.9, width: 6, height: 1.1)), with: .color(Color.white.opacity(0.5)))

        // The cheek's blush, only when it is happy.
        let blush = Ink.lerp(0.2, 0.95, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.6 * w.thirst)
        h.fill(Path(ellipseIn: CGRect(x: 45.6, y: 54, width: 10, height: 7.4)), with: .radialGradient(
            Gradient(colors: [look.tone(0xFF8FA3).color(blush), look.tone(0xFF8FA3).color(0)]), center: CGPoint(x: 50.6, y: 57.7), startRadius: 0, endRadius: 5.4))

        // The eye: the kitten's, built in layers, with a round pupil, looking
        // at the bowl when it is thirsty.
        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3)
        let gaze = CGPoint(x: Ink.lerp(-0.62 * w.thirst, 0.02, glance * w.thirst), y: Ink.lerp(0.78 * w.thirst, 0.02, glance * w.thirst) - 0.06 * w.bright)
        let size = 1 + 0.3 * babyness
        eye(h, at: CGPoint(x: 41.4, y: 47.4), side: -1, rx: 4.5 * size, ry: 5.0 * size, gaze: gaze, droop: motion.by(1, 0.05, 0.05, 0), lid: coat.mix(light, 0.2))
        // A brow of down over it, raised at the inner end when it is wanting something.
        if w.thirst > 0.05 {
            var brow = Path()
            brow.move(to: CGPoint(x: 36.4, y: 40.2)); brow.addQuadCurve(to: CGPoint(x: 46.6, y: 41.4), control: CGPoint(x: 41, y: 38.4 - 1.2 * w.thirst))
            h.stroke(brow, with: .color(mark.shifted(-10).color(0.5 * w.thirst)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        motion.nightcap(h)
    }
}
