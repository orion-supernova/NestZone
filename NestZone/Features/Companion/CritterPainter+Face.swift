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
        let species = plan.species
        // A hedgehog's face is pale; only its crown is spines and dark.
        let faced = species == .hedgehog
        let belly = look.belly, mark = look.mark
        let coat = faced ? belly.mix(look.coat, 0.12) : look.coat
        let light = faced ? look.lifted(belly, 0.12) : look.light
        let dark = faced ? belly.shifted(-14, 2).mix(look.dark, 0.25) : look.dark
        let L = look.L
        // The ears' own colour, where the plan has one: a puppy's darker
        // ones, the fox's black backs.
        let earTone = plan.earColour.map { look.tone($0, dim: 0.5) }

        // MARK: Ears. They stand up when it is bright, sit easy when it is
        // content, go flat and sideways when it wants something, and fall
        // back when it sleeps. One twitches now and then.
        func ears() {
            let twitchRight = Int(m.time / 5.3) % 2 == 0
            let twitch = m.beat(every: 5.3, lasting: 0.2, offset: 1.7) * m.awake
            for s in (plan.ears == .none ? [] : [-1.0, 1]) {
                var e = h
                let hang = plan.ears == .drop
                let long = plan.ears == .long
                var spread = (m.by(0.46, 1.04, 0.12, -0.03) + (s > 0 ? 0.1 * wt.thirst : 0)) * (hang ? 0.3 : 1) + (hang ? 0.25 : 0)
                if long { spread = m.by(0.7, 0.55, 0.1, -0.04) + (s > 0 ? 0.12 * wt.thirst : 0) + (s > 0 ? 0.05 : 0) }
                if hang {
                    // A pup's ears lift at the root when it is bright and flap a little.
                    let flap = frame.reduceMotion ? 0 : sin(m.time * 9 + (s > 0 ? 0.8 : 0)) * 0.1 * wt.bright
                    spread = 0.28 + m.by(0.12, 0.04, 0, -0.2) + flap
                }
                if plan.ears == .leaf { spread += 0.82 * (1 - wt.thirst) - 0.1 * wt.bright }
                let flick = (s > 0) == twitchRight ? twitch * (long ? 0.18 : 0.3) : 0
                e.translateBy(x: s * (hang ? 15.5 : (long ? 8.6 : 13.2)), y: (hang ? -9 : (long ? -14 : -11)) + 1.8 * wt.thirst)
                e.rotate(by: .radians(s * spread + s * flick))
                e.scaleBy(x: s * (1 + 0.1 * babyness), y: (hang || long ? 1 : m.by(0.9, 0.82, 1, 1.07)) * (1 + 0.18 * babyness))
                let eL = CGPoint(x: L.x * s, y: L.y)
                if long {
                    // Fully up when bright, a lazy lean when content, flopped
                    // when it wants water, laid back asleep: the two nearest
                    // of the five built bends, faded into one another.
                    let bend = min(4, max(0, m.by(4, 3, 1, 0)))
                    let lo = min(3, Int(bend)), f = bend - Double(lo)
                    for (i, weight) in [(lo, 1 - f), (lo + 1, f)] where weight > 0.02 {
                        var p = e
                        if weight < 0.98 { p.opacity = weight }
                        form(p, g.earBends[i], centre: CGPoint(x: 0, y: -g.earHeight * 0.4), radius: g.earHeight * 0.6, light, coat, dark, highlight: 0.4, core: 0.9, L: eL)
                        p.fill(g.earInnerBends[i], with: .radialGradient(Gradient(colors: [look.accent.shifted(7).color(), look.accent.color(), look.accent.shifted(-12, -4).color()]),
                                                                          center: CGPoint(x: 0.4, y: -g.earHeight * 0.45), startRadius: 0, endRadius: g.earHeight * 0.55))
                    }
                    continue
                }
                if hang, let tone = earTone {
                    // The pup's ear: its own, darker colour, furred at the edge, with the fold lit.
                    form(e, g.earFur, centre: CGPoint(x: 6, y: 10), radius: 17, tone.mix(light, 0.35), tone, tone.shifted(-10, 2), highlight: 0.3, core: 0.9, L: eL)
                    // The fold: a soft light along the inner edge, no line.
                    glow(e, g.ear, look.lifted(tone, 0.4), centre: CGPoint(x: 4, y: 8), radius: 8, alpha: 0.35)
                    continue
                }
                form(e, g.ear, centre: CGPoint(x: 0, y: -g.earHeight * 0.4), radius: g.earHeight * 0.6, light, coat, dark, highlight: 0.4, core: 0.9, L: eL)
                if let tone = earTone, !hang {
                    // The back of the ear shows dark at its tip.
                    e.fill(g.earTip, with: .linearGradient(Gradient(stops: [.init(color: tone.color(0.96), location: 0), .init(color: tone.color(0.9), location: 0.55),
                                                                            .init(color: tone.color(0), location: 1)]),
                                                           startPoint: CGPoint(x: 0, y: -g.earHeight * 1.05), endPoint: CGPoint(x: 0, y: -g.earHeight * 0.5)))
                }
                // The inner ear: pink, deepest at the base, with the cream hairs.
                e.fill(g.earInner, with: .radialGradient(Gradient(colors: [look.accent.shifted(7).color(), look.accent.color(), look.accent.shifted(-12, -4).color()]),
                                                          center: CGPoint(x: 0.4, y: -g.earHeight * 0.45), startRadius: 0, endRadius: g.earHeight * 0.55))
                if !hang { e.fill(g.earHairs, with: .color(belly.color(species == .fox ? 0.95 : 0.75))) }
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
        if plan.cheek > 0 {
            // Pouches: two round puffs of cream, soft at the rim.
            h.fill(g.pouches, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.25).color(0.95), location: 0), .init(color: belly.color(0.75), location: 0.55),
                                                                       .init(color: belly.color(0), location: 1)]),
                                                     center: CGPoint(x: 0, y: 7.5), startRadius: 0, endRadius: w * 0.95))
        }
        if plan.marks == .mask {
            // White from the eyes down, the ruff included; the dark tear lines from the eyes to the nose.
            h.fill(g.cheekWhite, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.3).color(), location: 0), .init(color: belly.color(), location: 0.7),
                                                                         .init(color: belly.shifted(-6, 3).color(), location: 1)]),
                                                       center: CGPoint(x: L.x * 3, y: 8), startRadius: 0, endRadius: w * 1.1))
        }

        if plan.species == .puppy {
            // The blaze, fading in from the crown.
            h.fill(g.blaze, with: .linearGradient(Gradient(stops: [.init(color: belly.color(0), location: 0), .init(color: belly.color(0.85), location: 0.55),
                                                                    .init(color: look.lifted(belly, 0.2).color(0.95), location: 1)]),
                                                  startPoint: CGPoint(x: 0, y: -17), endPoint: CGPoint(x: 0, y: 4)))
        }

        // Floppy ears hang in front of the head, not behind it.
        if plan.ears == .drop { ears() }

        // MARK: The muzzle: pale puffs with their whisker dots, the nose
        // leather with a glint, the little mouth. A long muzzle carries the
        // nose and the mouth down to its end (`drop`).
        let nz = species == .bunny ? noseJig() : 0
        h.fill(g.muzzle, with: .radialGradient(Gradient(colors: [look.lifted(belly, 0.35).color(), belly.color(), belly.shifted(-6, 3).color()]),
                                                center: CGPoint(x: L.x * 3, y: 4 + g.drop * 0.5), startRadius: 0, endRadius: 12 + g.drop))
        if plan.marks == .mask { h.fill(g.tears, with: .color(look.tone(plan.earColour ?? plan.mark, dim: 0.5).color(0.55))) }
        h.fill(g.whiskerDots, with: .color(dark.color(0.4)))
        var face = h
        face.translateBy(x: 0, y: nz)
        let ns = plan.noseSize
        face.fill(g.nose, with: .linearGradient(Gradient(colors: [look.lifted(look.nose, 0.3).color(), look.nose.color(), look.nose.shifted(-12).color()]),
                                                 startPoint: CGPoint(x: L.x * 2.5, y: 1.5 + g.drop), endPoint: CGPoint(x: -L.x * 2.5, y: 6.5 + g.drop + 2 * ns)))
        face.fill(Path(ellipseIn: CGRect(x: L.x * 1.1 * ns - 1.2 * ns, y: 2.5 + g.drop, width: 2.2 * ns, height: 1.1 * ns)), with: .color(Color.white.opacity(0.62)))
        mouth(face, weights: wt, babyness: babyness)

        // Blush, only when it is happy.
        let blush = Ink.lerp(0.12, 0.8, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.7 * wt.thirst) * (plan.marks == .mask ? 0.4 : 1)
        for s in [-1.0, 1] {
            h.fill(Path(ellipseIn: CGRect(x: s * 14.5 * plan.headWidth / 1.08 - 4, y: 4.5, width: 8, height: 5.2)), with: .radialGradient(
                Gradient(colors: [look.tone(0xFF8FA3).color(blush), look.tone(0xFF8FA3).color(0)]), center: CGPoint(x: s * 14.5 * plan.headWidth / 1.08, y: 7), startRadius: 0, endRadius: 4.4))
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
        let eyeY = species == .hedgehog ? -0.5 : -1.5
        if faced {
            // The dark of a hedgehog's mask, round each eye.
            for s in [-1.0, 1] {
                h.fill(Path(ellipseIn: CGRect(x: s * spread - 10, y: eyeY - 9, width: 20, height: 18)),
                       with: .radialGradient(Gradient(colors: [look.dark.color(0.7), look.dark.color(0.0)]), center: CGPoint(x: s * spread, y: eyeY), startRadius: 3, endRadius: 10))
            }
        }
        for s in [-1.0, 1] {
            eye(h, at: CGPoint(x: s * spread, y: eyeY), side: s, rx: 4.9 * plan.eyeSize * size, ry: 5.45 * plan.eyeSize * size, gaze: gaze, droop: droop)
        }

        // The hedgehog's spines come over the crown, in front of the ears.
        if species == .hedgehog { hood(h) }

        // Worried brows, only when it is wanting something: the inner ends raised.
        if wt.thirst > 0.05 {
            var brows = Path()
            for s in [-1.0, 1] {
                brows.move(to: CGPoint(x: s * (spread - 4.4), y: -9.6 * 1.0))
                brows.addQuadCurve(to: CGPoint(x: s * (spread + 4.6), y: -7.6), control: CGPoint(x: s * (spread + 0.4), y: -10.4))
            }
            h.stroke(brows, with: .color(mark.color(0.5 * wt.thirst)), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
        }
        var wh = h
        wh.translateBy(x: 0, y: g.drop * 0.55 + nz * 0.5)
        if plan.whiskers { whiskers(wh, weights: wt) }
        cap(h, wt)
    }

    /// A rabbit's nose never quite stops: a small quick shiver all the time,
    /// and now and then a short burst of it.
    private func noseJig() -> Double {
        guard !frame.reduceMotion else { return 0 }
        let burst = max(0.3, motion.beat(every: 3.1, lasting: 1.2, offset: 0.4))
        return sin(time * 21) * 0.5 * burst * motion.awake
    }

    // MARK: Mouth

    private func mouth(_ face: GraphicsContext, weights wt: PetMotion.Weights, babyness: Double) {
        var h = face
        h.translateBy(x: 0, y: CritterGeometry.head(plan).drop + 1.2 * (plan.noseSize - 1))
        defer {
            if plan.species == .puppy { pantingTongue(h, wt) }
            if plan.species == .hamster || plan.species == .bunny { buckTeeth(h, wt) }
        }
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

    /// A pup's tongue: out and panting when it wants water (it pulses), a
    /// bigger one in the happy smile.
    private func pantingTongue(_ h: GraphicsContext, _ wt: PetMotion.Weights) {
        let amount = max(wt.thirst, wt.bright * 0.9)
        guard amount > 0.05 else { return }
        let pant = frame.reduceMotion ? 0 : sin(time * 7.5) * 0.9 * wt.thirst
        let len = (4.5 + 4.5 * wt.thirst) * amount + pant
        let rim = look.dark.shifted(-26)
        h.fill(Path(ellipseIn: CGRect(x: -5, y: 8, width: 10, height: 3.6 + 2.4 * amount)), with: .color(Color(red: 0.32, green: 0.12, blue: 0.14, opacity: Ink.clamp(amount * 1.3))))
        var tongue = Path()
        tongue.move(to: CGPoint(x: -3, y: 8.8))
        tongue.addLine(to: CGPoint(x: -3, y: 9 + len))
        tongue.addQuadCurve(to: CGPoint(x: 3, y: 9 + len), control: CGPoint(x: 0, y: 9 + len + 4.6))
        tongue.addLine(to: CGPoint(x: 3, y: 8.8))
        tongue.closeSubpath()
        let pink = look.tone(0xF2808F)
        var t = h
        t.opacity = Ink.clamp(amount * 1.5)
        t.fill(tongue.offsetBy(dx: 0, dy: 0.5), with: .color(rim.color(0.35)))
        t.fill(tongue, with: .linearGradient(Gradient(colors: [pink.shifted(-4).color(), pink.color(), look.lifted(pink, 0.22).color()]),
                                              startPoint: CGPoint(x: 0, y: 9), endPoint: CGPoint(x: 0, y: 9 + len + 3)))
        var mid = Path()
        mid.move(to: CGPoint(x: 0, y: 9.4)); mid.addLine(to: CGPoint(x: 0, y: 9 + len * 0.8))
        t.stroke(mid, with: .color(pink.shifted(-16).color(0.6)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
    }

    /// The two front teeth of a hamster or a rabbit, under the nose, which
    /// show when the mouth is closed.
    private func buckTeeth(_ h: GraphicsContext, _ wt: PetMotion.Weights) {
        let a = (1 - wt.bright) * (1 - 0.8 * wt.doze)
        guard a > 0.05 else { return }
        let len = plan.species == .hamster ? 2.8 : 2.4
        for s in [-1.0, 1] {
            let tooth = Path(roundedRect: CGRect(x: s > 0 ? 0.15 : -1.85, y: 8.6, width: 1.7, height: len), cornerRadius: 0.7)
            h.fill(tooth, with: .color(look.lifted(look.belly, 0.4).color(a)))
            h.stroke(tooth, with: .color(look.dark.shifted(-10).color(0.35 * a)), lineWidth: 0.35)
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
        e.rotate(by: .radians(s * (m.by(0, 0.2, 0.05, -0.1) - plan.eyeTilt)))

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
