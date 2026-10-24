import SwiftUI

// MARK: - The sitter's face

extension CritterPainter {
    /// The head and face, centred on its own origin when `local`, otherwise
    /// (for a hatchling) drawn where the duckling's head is. `resting` is the
    /// curled-up one's, laid on its paws.
    func sitterHead(_ c: GraphicsContext, babyness: Double, local: Bool = false, resting: Bool = false) {
        var h = c
        if !local { h.translateBy(x: 47, y: 49) }
        let g = CritterGeometry.head(plan)
        let w = g.w
        let m = motion
        let wt = m.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let L = look.L

        // MARK: Ears. They stand up when it is bright, sit easy when it is
        // content, go flat and sideways when it wants something, and fall
        // back when it sleeps. One twitches now and then.
        func ears() {
            let twitchRight = Int(m.time / 5.3) % 2 == 0
            let twitch = m.beat(every: 5.3, lasting: 0.2, offset: 1.7) * m.awake
            for s in (plan.ears == .none ? [] : [-1.0, 1]) {
                var e = h
                let hang = plan.ears == .drop
                let spread = (m.by(0.46, 1.04, 0.12, -0.03) + (s > 0 ? 0.1 * wt.thirst : 0)) * (hang ? 0.3 : 1) + (hang ? 0.25 : 0)
                let flick = (s > 0) == twitchRight ? twitch * 0.3 : 0
                e.translateBy(x: s * (hang ? 15.5 : 13.2), y: (hang ? -9 : -11) + 1.8 * wt.thirst)
                e.rotate(by: .radians(s * spread + s * flick))
                e.scaleBy(x: s * (1 + 0.1 * babyness), y: (hang ? 1 : m.by(0.9, 0.82, 1, 1.07)) * (1 + 0.18 * babyness))
                let eL = CGPoint(x: L.x * s, y: L.y)
                form(e, g.ear, centre: CGPoint(x: 0, y: -g.earHeight * 0.4), radius: g.earHeight * 0.6, light, coat, dark, highlight: 0.4, core: 0.9, L: eL)
                // The inner ear: pink, deepest at the base, with the cream hairs.
                e.fill(g.earInner, with: .radialGradient(Gradient(colors: [look.accent.shifted(7).color(), look.accent.color(), look.accent.shifted(-12, -4).color()]),
                                                          center: CGPoint(x: 0.4, y: -g.earHeight * 0.45), startRadius: 0, endRadius: g.earHeight * 0.55))
                if !hang { e.fill(g.earHairs, with: .color(belly.color(0.75))) }
            }
        }
        if plan.ears != .drop { ears() }

        // MARK: The head: cheek fur first, then the form, lit from the sky.
        form(h, g.headFur, centre: CGPoint(x: 0, y: 0), radius: w * 1.35, light, coat, coat.shifted(-7, 3), highlight: 0.5, core: 0.6)
        if plan.marks == .tabby {
            hairs(h, g.brow, dark: mark, light: light, alpha: 0.62)
            h.fill(g.liner, with: .color(mark.color(0.55)))
            h.fill(g.cheekStripes, with: .color(mark.color(0.5)))
        }

        // Floppy ears hang in front of the head, not behind it.
        if plan.ears == .drop { ears() }

        // MARK: The muzzle: pale puffs with their whisker dots, the nose
        // leather with a glint, the little mouth.
        h.fill(g.muzzle, with: .radialGradient(Gradient(colors: [look.lifted(belly, 0.35).color(), belly.color(), belly.shifted(-6, 3).color()]),
                                                center: CGPoint(x: L.x * 3, y: 4), startRadius: 0, endRadius: 12))
        h.fill(g.whiskerDots, with: .color(dark.color(0.4)))
        h.fill(g.nose, with: .linearGradient(Gradient(colors: [look.lifted(look.nose, 0.3).color(), look.nose.color(), look.nose.shifted(-12).color()]),
                                              startPoint: CGPoint(x: L.x * 2.5, y: 1.5), endPoint: CGPoint(x: -L.x * 2.5, y: 6.5)))
        h.fill(Path(ellipseIn: CGRect(x: L.x * 1.1 - 1.2, y: 2.5, width: 2.2, height: 1.1)), with: .color(Color.white.opacity(0.62)))
        mouth(h, weights: wt, babyness: babyness)

        // Blush, only when it is happy.
        let blush = Ink.lerp(0.12, 0.8, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.7 * wt.thirst)
        for s in [-1.0, 1] {
            h.fill(Path(ellipseIn: CGRect(x: s * 14.5 - 4, y: 4.5, width: 8, height: 5.2)), with: .radialGradient(
                Gradient(colors: [look.tone(0xFF8FA3).color(blush), look.tone(0xFF8FA3).color(0)]), center: CGPoint(x: s * 14.5, y: 7), startRadius: 0, endRadius: 4.4))
        }

        // MARK: Eyes. They look at the bowl when it wants water, and at you
        // for a moment now and then.
        let glance = m.beat(every: 6.5, lasting: 1.1, offset: 3)
        let toBowl = CGPoint(x: -0.62, y: 0.78)
        let drift = frame.reduceMotion ? 0 : sin(m.time * 0.37) * 0.12 * (1 - wt.thirst)
        let gaze = CGPoint(x: Ink.lerp(toBowl.x * wt.thirst, 0.02, glance * wt.thirst) + drift, y: Ink.lerp(toBowl.y * wt.thirst, 0.02, glance * wt.thirst) - 0.06 * wt.bright)
        let droop = m.by(1, 0.05, 0.05, 0)
        let size = (1 + 0.32 * babyness)
        let spread = 9.6 * plan.eyeSpread * (1 + 0.08 * babyness)
        for s in [-1.0, 1] {
            eye(h, at: CGPoint(x: s * spread, y: -1.5), side: s, rx: 4.9 * plan.eyeSize * size, ry: 5.45 * plan.eyeSize * size, gaze: gaze, droop: droop)
        }

        // Worried brows, only when it is wanting something: the inner ends raised.
        if wt.thirst > 0.05 {
            var brows = Path()
            for s in [-1.0, 1] {
                brows.move(to: CGPoint(x: s * (spread - 4.4), y: -9.6 * 1.0))
                brows.addQuadCurve(to: CGPoint(x: s * (spread + 4.6), y: -7.6), control: CGPoint(x: s * (spread + 0.4), y: -10.4))
            }
            h.stroke(brows, with: .color(mark.color(0.5 * wt.thirst)), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
        }
        whiskers(h, weights: wt)
        cap(h, wt)
    }

    // MARK: Mouth

    private func mouth(_ h: GraphicsContext, weights wt: PetMotion.Weights, babyness: Double) {
        let ink = look.dark.shifted(-16)
        var line = Path()
        line.move(to: CGPoint(x: 0, y: 6.3)); line.addLine(to: CGPoint(x: 0, y: 8.1))
        let open = Ink.clamp(wt.bright)
        let lick = motion.beat(every: 7, lasting: 1.0, offset: 4.2) * wt.thirst
        if open > 0.12 {
            // Open: a small smile with a tongue in it (bright), or a little "o" (wanting).
            let depth = 0.8 + 3.8 * open
            var mouth = Path()
            mouth.move(to: CGPoint(x: -4.3, y: 8.6))
            mouth.addQuadCurve(to: CGPoint(x: 4.3, y: 8.6), control: CGPoint(x: 0, y: 7.6))
            mouth.addQuadCurve(to: CGPoint(x: -4.3, y: 8.6), control: CGPoint(x: 0, y: 8.6 + depth * 2.2))
            h.fill(mouth, with: .color(Color(red: 0.32, green: 0.12, blue: 0.14)))
            h.fill(Path(ellipseIn: CGRect(x: -2.1, y: 8.6 + depth * 0.62, width: 4.2, height: depth * 0.7)), with: .color(look.tone(0xF08A9A).color()))
            h.stroke(line, with: .color(ink.color(0.7)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        } else {
            // Wanting something: the mouth just parted, a little "o".
            if wt.thirst > 0.02 {
                h.fill(Path(ellipseIn: CGRect(x: -1.9, y: 8.4, width: 3.8, height: 2.6 + 0.6 * lick)), with: .color(Color(red: 0.32, green: 0.12, blue: 0.14, opacity: min(1, wt.thirst * 1.2))))
            }
            var w = Path()
            w.move(to: CGPoint(x: -4.4, y: 9.4))
            w.addQuadCurve(to: CGPoint(x: 0, y: 8.1), control: CGPoint(x: -2.3, y: 10.9))
            w.addQuadCurve(to: CGPoint(x: 4.4, y: 9.4), control: CGPoint(x: 2.3, y: 10.9))
            w.addPath(line)
            h.stroke(w, with: .color(ink.color(0.72 * (1 - 0.7 * wt.thirst))), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
            // A lick, when it is wanting: the tongue's tip for a moment.
            if lick > 0.05 {
                h.fill(Path(ellipseIn: CGRect(x: -1.6, y: 9.6, width: 3.2, height: 1.4 + 2.4 * lick)), with: .color(look.tone(0xF08A9A).color(Double(lick))))
            }
        }
    }

    // MARK: Whiskers

    private func whiskers(_ h: GraphicsContext, weights wt: PetMotion.Weights) {
        let sway = frame.reduceMotion ? 0 : sin(time * 2.3) * 0.6
        // They sag when it is wanting or sleepy, and fan out when it is bright.
        let sag = motion.by(1.4, 1.9, 0, -0.9)
        var path = Path()
        for s in [-1.0, 1] {
            for i in 0..<3 {
                let dy = [-2.4, 0.4, 3.2][i]
                path.move(to: CGPoint(x: s * 10.6, y: 7.2 + Double(i) * 1.3))
                path.addQuadCurve(to: CGPoint(x: s * (24.5 + Double(i) * 0.6), y: 5.2 + dy * 2 + sway + sag * (0.6 + Double(i) * 0.3)),
                                  control: CGPoint(x: s * 17.5, y: 4.6 + dy + Double(i) * 0.4 + sag * 0.2))
            }
        }
        h.stroke(path.offsetBy(dx: 0.3, dy: 0.7), with: .color(look.dark.color(0.22)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        h.stroke(path, with: .color(look.lifted(look.belly, 0.4).color(0.92)), style: StrokeStyle(lineWidth: 0.65, lineCap: .round))
    }

    // MARK: Eyes

    /// An eye built the way the plants are: a socket in shadow, the opening in
    /// the iris's darkest tone, the iris lit from below (the far side from the
    /// light, where it comes through), a pupil that answers the light (a slit
    /// by day, round at night and when excited), a catchlight from the sky's
    /// side and a small one opposite, the upper lid's line, and a lid that
    /// comes down: asleep, on a blink, heavy when content, with its inner end
    /// raised when it is wanting something. `gaze` is where it looks, -1 to 1.
    func eye(_ c: GraphicsContext, at p: CGPoint, side s: Double, rx: Double, ry: Double, gaze: CGPoint, droop: Double, lid lidColour: RGB? = nil) {
        let m = motion
        let lids = m.lids()
        let closed = 1 - (1 - droop) * (1 - lids)
        let ink = look.ink
        let irisC = look.iris
        let L = look.L
        var e = c
        e.translateBy(x: p.x, y: p.y)
        e.rotate(by: .radians(s * m.by(0, 0.2, 0.05, -0.1)))

        if closed > 0.9 {
            // Shut: a soft curve, the lid's own light above it, a lash.
            var lid = Path()
            lid.move(to: CGPoint(x: -rx * 0.95, y: 0.1))
            lid.addQuadCurve(to: CGPoint(x: rx * 0.95, y: 0.1), control: CGPoint(x: 0, y: ry * 0.62))
            e.stroke(lid.offsetBy(dx: 0, dy: -1.1), with: .color(look.lifted(look.light, 0.3).color(0.5)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            e.stroke(lid, with: .color(ink.opacity(0.9)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            var lash = Path()
            lash.move(to: CGPoint(x: s * rx * 0.9, y: 0.4)); lash.addLine(to: CGPoint(x: s * (rx + 1.3), y: 1.7))
            e.stroke(lash, with: .color(ink.opacity(0.7)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            return
        }

        let opening = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        e.fill(Path(ellipseIn: CGRect(x: -rx - 1.0, y: -ry - 0.5, width: rx * 2 + 2, height: ry * 2 + 2)), with: .color(look.dark.shifted(-10).color(0.3)))
        e.fill(opening, with: .color(irisC.shifted(-30).color()))

        // The iris and pupil move with the gaze; the opening and the lights do not.
        var i = e
        i.translateBy(x: gaze.x * rx * 0.27, y: gaze.y * ry * 0.2)
        let ir = (rx * 0.92, ry * 0.93)
        i.fill(Path(ellipseIn: CGRect(x: -ir.0, y: -ir.1, width: ir.0 * 2, height: ir.1 * 2)), with: .radialGradient(
            Gradient(colors: [look.lifted(irisC, 0.4).color(), irisC.color(), irisC.shifted(-14).color()]),
            center: CGPoint(x: 0, y: ry * 0.42), startRadius: 0, endRadius: ry * 1.35))
        // The dark of the iris's ring, and the glow where light passes through.
        i.stroke(Path(ellipseIn: CGRect(x: -ir.0, y: -ir.1, width: ir.0 * 2, height: ir.1 * 2)), with: .color(irisC.shifted(-26).color(0.55)), lineWidth: 0.7)
        let night = 1 - Ink.clamp(look.day * 1.5)
        let wt = m.weights
        let pupilW: Double, pupilH: Double
        if plan.pupil == .slit {
            pupilW = min(0.92, 0.34 + 0.56 * night + 0.2 * wt.bright + 0.12 * wt.thirst)
            pupilH = 0.97 - 0.1 * pupilW
        } else {
            pupilW = 0.5 + 0.26 * night + 0.12 * wt.bright
            pupilH = pupilW * (rx / ry)
        }
        i.fill(Path(ellipseIn: CGRect(x: -ir.0 * pupilW, y: -ir.1 * pupilH, width: ir.0 * 2 * pupilW, height: ir.1 * 2 * pupilH)), with: .color(ink))
        // The glow: the lower edge of the iris is lit.
        i.fill(Path(ellipseIn: CGRect(x: -ir.0 * 0.62, y: ir.1 * 0.32, width: ir.0 * 1.24, height: ir.1 * 0.5)), with: .color(look.lifted(irisC, 0.5).color(0.28)))

        // Catchlights: the sky's, large, on the side the light is; a small
        // one opposite. They stay put while the eye looks about.
        let cl = max(0.9, rx * 0.4)
        e.fill(Path(ellipseIn: CGRect(x: L.x * rx * 0.42 - cl, y: -ry * 0.42 - cl, width: cl * 2, height: cl * 2.05)), with: .color(.white))
        e.fill(Path(ellipseIn: CGRect(x: -L.x * rx * 0.4 - cl * 0.36, y: ry * 0.42 - cl * 0.36, width: cl * 0.72, height: cl * 0.72)), with: .color(Color.white.opacity(0.7)))

        // The lid.
        if closed > 0.03 {
            let edge = -ry + 2 * ry * closed
            var cover = Path()
            cover.move(to: CGPoint(x: -rx - 1, y: -ry - 2))
            cover.addLine(to: CGPoint(x: rx + 1, y: -ry - 2))
            cover.addLine(to: CGPoint(x: rx + 1, y: edge))
            cover.addQuadCurve(to: CGPoint(x: -rx - 1, y: edge), control: CGPoint(x: 0, y: edge + 1.6 * closed + 0.4))
            cover.closeSubpath()
            var clipped = e
            clipped.clip(to: opening)
            clipped.fill(cover, with: .color((lidColour ?? look.coat.mix(look.light, 0.25)).color()))
            var lash = Path()
            lash.move(to: CGPoint(x: -rx, y: edge))
            lash.addQuadCurve(to: CGPoint(x: rx, y: edge), control: CGPoint(x: 0, y: edge + 1.6 * closed + 0.4))
            if closed > 0.14 { e.stroke(lash, with: .color(ink.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round)) }
        }
        // The upper lid's line, always: what makes a cat's eye read at small size.
        var liner = Path()
        liner.move(to: CGPoint(x: -rx - 0.2, y: -ry * 0.3))
        liner.addQuadCurve(to: CGPoint(x: rx + 0.2, y: -ry * 0.3), control: CGPoint(x: 0, y: -ry * 1.5))
        if closed < 0.2 { e.stroke(liner, with: .color(ink.opacity(0.26)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round)) }
    }

    // MARK: The cap

    /// The nightcap, worn while it dozes: it flies off as the cat wakes.
    /// Drawn on the head, so it nods and tilts with it.
    func cap(_ h: GraphicsContext, _ wt: PetMotion.Weights) {
        let shown = frame.mood < 0.15 || frame.domeLift > 0
        guard shown, stage >= 3 else { return }
        let off = frame.domeLift
        var c = h
        c.opacity = 1 - off
        c.translateBy(x: 30 * off, y: -60 * off)
        c.rotate(by: .radians(off * 1.1))
        let cloth = look.tone(0x7C8BE8, dim: 0.5), L = look.L
        var crown = Path()
        crown.move(to: CGPoint(x: -11.5, y: -11))
        crown.addQuadCurve(to: CGPoint(x: 11, y: -12.5), control: CGPoint(x: 0, y: -20))
        crown.addQuadCurve(to: CGPoint(x: 23, y: -22), control: CGPoint(x: 15, y: -17))
        crown.addQuadCurve(to: CGPoint(x: 0, y: -26), control: CGPoint(x: 13, y: -30))
        crown.addQuadCurve(to: CGPoint(x: -11.5, y: -11), control: CGPoint(x: -9, y: -21))
        crown.closeSubpath()
        form(c, crown, centre: CGPoint(x: 4, y: -19), radius: 14, look.lifted(cloth, 0.25), cloth, cloth.shifted(-14, 4), highlight: 0.3, core: 0.7)
        // Knit stripes across the crown.
        var stripes = Path()
        for (x, y) in [(-5.0, -17.0), (3, -21), (11, -22.5)] {
            stripes.move(to: CGPoint(x: x, y: y)); stripes.addQuadCurve(to: CGPoint(x: x + 5, y: y + 8), control: CGPoint(x: x + 5.5, y: y + 2))
        }
        c.stroke(stripes, with: .color(look.lifted(cloth, 0.5).color(0.5)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        // The fluffy band, and the pompom on its droop.
        var band = Path()
        band.move(to: CGPoint(x: -12, y: -10.5))
        band.addQuadCurve(to: CGPoint(x: 11.8, y: -12.2), control: CGPoint(x: 0, y: -15.5))
        c.stroke(band, with: .color(look.lifted(look.belly, 0.4).color()), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
        c.stroke(band.offsetBy(dx: L.x * 0.4, dy: L.y * 0.5), with: .color(Color.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: 19.5, y: -25, width: 7.4, height: 7.4)), with: .radialGradient(
            Gradient(colors: [Color.white, look.lifted(look.belly, 0.3).color()]), center: CGPoint(x: 22.5 + L.x, y: -22.5 + L.y), startRadius: 0, endRadius: 5))
    }
}
