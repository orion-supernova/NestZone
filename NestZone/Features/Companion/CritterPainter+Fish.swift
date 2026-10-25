import SwiftUI

// MARK: - The goldfish

extension CritterPainter {
    /// A goldfish in its bowl. The bowl is built once (`BowlGeometry`) and
    /// only filled; the fish and the weed are what move. Bright, the fish
    /// swims wide loops and turns at the glass, bubbles rising; content, it
    /// drifts and blinks; thirsty, the water has gone down and it hangs at
    /// the surface, head up, mouth gulping, looking out; dozing, it settles
    /// on the gravel with its eyes shut and the nightcap on.
    ///
    /// Refraction is what water and glass do to what is in them, and each is
    /// drawn once: the fish is magnified a little and squeezed where it
    /// swims close to the curved side, the gravel is seen through the water
    /// and tinted by it, the glass takes the light as a rim and a window, and
    /// the bowl throws a pool of bright light on the floor, on the side away
    /// from the sun.
    func fish(_ c: GraphicsContext) {
        let bowl = CritterGeometry.bowlArt
        let li = waterIndex
        bowlBack(c, bowl, li)
        swimmer(c, bowl, li)
        bowlFront(c, bowl, li)
    }

    /// The egg of a goldfish: a jelly bead on the gravel, in the water.
    func fishEgg(_ c: GraphicsContext) {
        let bowl = CritterGeometry.bowlArt
        // The bowl stands as large before the fish as after it.
        var c = c
        c.translateBy(x: 60, y: 108)
        c.scaleBy(x: 1.12, y: 1.12)
        c.translateBy(x: -60, y: -108)
        bowlBack(c, bowl, 0)
        var e = c
        e.translateBy(x: 60, y: 103)
        e.scaleBy(x: 0.5, y: 0.5)
        e.translateBy(x: -60, y: -104)
        wrapped(e)
        bowlFront(c, bowl, 0)
    }

    private var waterIndex: Int {
        let level = motion.by(45, 62, 45, 45)
        return min(BowlGeometry.levels.count - 1, max(0, Int(((level - 45) / 3).rounded())))
    }

    // MARK: The bowl, behind the fish

    private func bowlBack(_ c: GraphicsContext, _ bowl: BowlGeometry, _ li: Int) {
        let L = look.L
        let top = BowlGeometry.levels[li]
        let waterLight = look.tone(0xB4E6F2, dim: 0.5), waterDeep = look.tone(0x4FAAC8, dim: 0.5)

        // The pool of light on the floor, away from the sun.
        let px = 60 - L.x * 27
        c.fill(Path(ellipseIn: CGRect(x: px - 21, y: 105.2, width: 42, height: 5.6)), with: .radialGradient(
            Gradient(colors: [look.lifted(waterLight, 0.4).color(0.6 * look.day + 0.3), waterLight.color(0)]), center: CGPoint(x: px, y: 108), startRadius: 0, endRadius: 20))
        c.fill(Path(ellipseIn: CGRect(x: px - 8, y: 106.9, width: 16, height: 2.2)), with: .color(Color.white.opacity(0.3)))

        // The water behind, deeper toward the bottom.
        c.fill(bowl.water(li), with: .linearGradient(Gradient(colors: [waterLight.color(0.42), waterDeep.color(0.62)]),
                                                     startPoint: CGPoint(x: 60, y: top), endPoint: CGPoint(x: 60, y: 106)))

        // The gravel, seen through the water: its colours cooled by it.
        let sand = look.tone(0xE8CDA2, dim: 0.5), lilac = look.tone(0xCDB9E2, dim: 0.5), coral = look.tone(0xF2A79E, dim: 0.5)
        var litPebbles = c
        litPebbles.translateBy(x: L.x * 0.5, y: L.y * 0.5 - 0.3)
        litPebbles.fill(bowl.allPebbles, with: .color(look.lifted(sand, 0.45).color(0.6)))
        for (path, tone) in zip(bowl.pebbles, [sand, lilac, coral]) {
            c.fill(path, with: .color(tone.mix(waterDeep, 0.22).color(0.95)))
        }

        // The weed, swaying with the water.
        let sway = frame.reduceMotion ? 0 : 1.0
        let green = look.tone(0x5DB070, dim: 0.5), greenLight = look.tone(0x92D58A, dim: 0.5)
        for (x, height, phase, tone) in [(36.0, 30.0, 0.0, green), (80.0, 22.0, 1.7, greenLight), (86.0, 27.0, 3.1, green)] {
            var pts: [CGPoint] = []
            for j in 0...6 {
                let u = Double(j) / 6
                pts.append(CGPoint(x: x + (2.6 * sin(time * 0.9 + phase - 3 * u) * u + 3 * u * u * (x < 60 ? 1 : -1)) * sway, y: 103 - height * u))
            }
            c.fill(PlantPainter.ribbon(pts, 5.4, 0.6), with: .color(tone.mix(waterDeep, 0.2).color(0.92)))
        }
    }

    // MARK: The fish

    private func swimmer(_ c: GraphicsContext, _ bowl: BowlGeometry, _ li: Int) {
        let geometry = CritterGeometry.fishArt
        let w = motion.weights
        let L = look.L
        let top = BowlGeometry.levels[li]
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let fin = coat.mix(light, 0.55)
        let baby = babyness
        let t = time
        // How big: the fry is a speck, and it grows into the bowl.
        let fs = (stage == 2 ? 0.4 : PetMotion.scales[stage]) * 1.1

        // Where it is: the four moods are four places.
        let swimB = 19.0, swimC = 10.0
        var fx = 60 + motion.by(-2, -4 + 3 * sin(t * 0.5), -swimC * sin(t * 0.35), -swimB * sin(t * 0.8))
        var fy = motion.by(99 - 11 * fs, top + 8 + 1.2 * sin(t * 1.3), 69 + 2.6 * sin(t * 0.7), 66 + 6 * sin(t * 1.6))
        // Nothing crosses the glass: the dorsal fin is the highest thing on the fish,
        // so below the surface it keeps that far under it. Thirsty may break it, on purpose.
        fy = max(fy, top + 3 + 21 * fs * (1 - w.thirst))
        let face = motion.by(1, 1, max(-1, min(1, 5 * cos(t * 0.35))), max(-1, min(1, 5 * cos(t * 0.8))))
        // Nor does the tail or the nose: keep both ends inside the glass, whichever
        // way it faces (blended through the turn, so nothing jumps).
        let k = (face + 1) / 2
        let leftReach = (17 * k + 29 * (1 - k)) * fs, rightReach = (29 * k + 17 * (1 - k)) * fs
        fx = min(max(fx, 27 + leftReach), 93.5 - rightReach)
        let angle = motion.by(0.1, 0.62, 0.05 * sin(t * 0.7), 0.16 + 0.12 * sin(t * 1.6))
        // Close to the curved side it is seen foreshortened.
        let wall = 1 - 0.26 * Ink.smooth((abs(fx - 60) - 12) / 8)
        let ph = t * motion.by(1.4, 2.2, 3.4, 8.5)
        let amp = motion.by(1.4, 2.4, 3.4, 6.2)

        var f = c
        f.translateBy(x: fx, y: fy + (frame.reduceMotion ? 0 : (w.doze * 0.7 * sin(t / 4.2 * .pi * 2))))
        f.scaleBy(x: fs * face * wall, y: fs)
        f.rotate(by: .radians(angle))
        let eL = CGPoint(x: L.x * (face >= 0 ? 1 : -1), y: L.y)

        // The tail: a veil of three flowing lobes, one fill.
        var veil = Path(), veins = Path()
        for lobe in -1...1 {
            var pts: [CGPoint] = []
            for j in 0...7 {
                let u = Double(j) / 7
                pts.append(CGPoint(x: 11.5 + 14 * u * (lobe == 0 ? 1 : 0.9), y: Double(lobe) * (9.6 + 3.2 * w.bright) * u + amp * sin(ph - 2.4 * u) * u))
            }
            veil.addPath(PlantPainter.ribbon(pts, 5, 10))
            veins.addLines(Array(pts.dropFirst(1)))
        }
        f.fill(veil, with: .linearGradient(Gradient(colors: [fin.color(0.96), light.mix(fin, 0.4).color(0.78)]), startPoint: CGPoint(x: 12, y: 0), endPoint: CGPoint(x: 29, y: 0)))
        f.stroke(veins, with: .color(dark.mix(coat, 0.4).color(0.32)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round, lineJoin: .round))

        // The dorsal fin, behind the back.
        var dorsal: [CGPoint] = []
        for j in 0...6 {
            let u = Double(j) / 6
            dorsal.append(CGPoint(x: -4 + 19 * u, y: -10.4 - (5.6 + 1.6 * w.bright) * sin(.pi * (0.12 + 0.7 * u)) + amp * 0.35 * sin(ph - 2 * u) * u))
        }
        f.fill(PlantPainter.ribbon(dorsal, 8, 2.4), with: .color(fin.color(0.92)))

        // The belly fin.
        var pv = f
        pv.translateBy(x: 2, y: 10)
        pv.rotate(by: .radians(0.3 * sin(ph * 0.5)))
        pv.fill(geometry.pelvic, with: .color(fin.shifted(-6).color(0.9)))

        // The body, lit by the sky, its belly pale, its scales in rows.
        form(f, geometry.body, centre: CGPoint(x: 0, y: 0), radius: 18, light, coat, dark, highlight: 0.55, L: eL)
        f.fill(geometry.belly, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.2).color(0.9), location: 0), .init(color: belly.color(0.55), location: 0.55),
                                                                      .init(color: belly.color(0), location: 1)]), center: CGPoint(x: 0, y: 8.4), startRadius: 0, endRadius: 14))
        var litScales = f
        litScales.translateBy(x: eL.x * 0.6, y: eL.y * 0.6)
        litScales.stroke(geometry.scales, with: .color(look.lifted(light, 0.35).color(0.4)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        f.stroke(geometry.scales, with: .color(mark.color(0.3)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        f.stroke(geometry.gill.offsetBy(dx: eL.x * 0.5, dy: eL.y * 0.5), with: .color(look.lifted(light, 0.4).color(0.4)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        f.stroke(geometry.gill, with: .color(mark.color(0.32)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))

        // The side fin, beating.
        var pf = f
        pf.translateBy(x: -3.6, y: 4.4)
        pf.rotate(by: .radians(-0.35 + 0.4 * sin(ph * 0.8 + 1) * (0.4 + 0.6 * w.bright)))
        form(pf, geometry.pectoral, centre: CGPoint(x: 5, y: 3), radius: 8, look.lifted(fin, 0.2), fin, fin.shifted(-8, 2), highlight: 0.2, core: 0.5, rim: false, L: eL)

        // The face: a mouth that gulps when it wants water, a blush, the eye.
        let gulp = motion.by(0, 0.5 + 0.5 * sin(t * 5), 0.08, 0.55)
        var m = Path()
        m.move(to: CGPoint(x: -15.8, y: 0.6)); m.addQuadCurve(to: CGPoint(x: -13.6, y: 4.4), control: CGPoint(x: -16.6, y: 3.4))
        f.fill(Path(ellipseIn: CGRect(x: -16.6, y: 1.4, width: 3.2, height: 1.2 + 2.6 * gulp)), with: .color(Color(red: 0.4, green: 0.1, blue: 0.12, opacity: min(1, 0.3 + gulp))))
        f.stroke(m, with: .color(mark.shifted(-6).color(0.7)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        let blush = Ink.lerp(0.1, 0.7, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.7 * w.thirst)
        f.fill(Path(ellipseIn: CGRect(x: -12.4, y: 1.4, width: 8, height: 6)), with: .radialGradient(
            Gradient(colors: [look.tone(0xFF8FA3).color(blush), look.tone(0xFF8FA3).color(0)]), center: CGPoint(x: -8.4, y: 4.4), startRadius: 0, endRadius: 4))
        var e = f
        e.translateBy(x: -9.2, y: -2.6)
        if face < 0 { e.scaleBy(x: -1, y: 1) }
        let look_ = motion.beat(every: 6.5, lasting: 1.1, offset: 3)
        let gaze = CGPoint(x: Ink.lerp(-0.2 * w.thirst, 0.02, look_ * w.thirst), y: Ink.lerp(-0.7 * w.thirst, 0.02, look_ * w.thirst) - 0.06 * w.bright)
        let size = 1 + 0.32 * baby
        eye(e, at: .zero, side: -1, rx: 4.3 * size, ry: 4.5 * size, gaze: gaze, droop: motion.by(1, 0.05, 0.05, 0), lid: coat.mix(light, 0.2))

        // The nightcap, small, on the fish's head.
        if w.doze > 0.02 || frame.domeLift > 0, stage >= 3 {
            var cap = f
            cap.translateBy(x: -8, y: -8.5)
            cap.rotate(by: .radians(-0.15))
            cap.scaleBy(x: 0.6, y: 0.6)
            self.cap(cap, w)
        }

        // Bubbles: a stream when it is bright, now and then when it is easy.
        guard !frame.reduceMotion else { return }
        let mouthX = fx - 15 * fs * (face >= 0 ? 1 : -1), mouthY = fy + 2
        let count = w.bright > 0.5 ? 3 : (w.content > 0.5 || w.thirst > 0.5 ? 1 : 0)
        let speed = w.bright > 0.5 ? 0.55 : 0.2
        for i in 0..<count {
            let u = (t * speed + Double(i) / Double(max(1, count))).truncatingRemainder(dividingBy: 1)
            let y = mouthY - u * (mouthY - top - 3)
            let x = mouthX + sin(u * 9 + Double(i) * 2) * 1.6
            let r = (0.9 + 1.2 * u) * (0.8 + 0.2 * Double(i % 2))
            let a = min(1, u * 6) * min(1, (1 - u) * 4)
            c.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color.white.opacity(0.7 * a)), lineWidth: 0.6)
            c.fill(Path(ellipseIn: CGRect(x: x - r * 0.1, y: y - r * 0.6, width: r * 0.55, height: r * 0.45)), with: .color(Color.white.opacity(0.8 * a)))
        }
    }

    // MARK: The bowl, in front of the fish

    private func bowlFront(_ c: GraphicsContext, _ bowl: BowlGeometry, _ li: Int) {
        let L = look.L
        let top = BowlGeometry.levels[li]
        let waterLight = look.tone(0xB4E6F2, dim: 0.5), waterDeep = look.tone(0x4FAAC8, dim: 0.5)
        let lit = L.x > 0 ? 1 : 0

        // The water in front: it tints what is behind it, lighter on the lit side.
        c.fill(bowl.water(li), with: .linearGradient(Gradient(colors: [waterLight.color(0.2), waterDeep.color(0.26)]),
                                                     startPoint: CGPoint(x: 60 + L.x * 36, y: 60 + L.y * 30), endPoint: CGPoint(x: 60 - L.x * 36, y: 80 - L.y * 30)))
        // The far side of the glass is in shadow, cool.
        c.fill(bowl.glass, with: .radialGradient(Gradient(colors: [look.cool.color(look.coolAlpha * 1.1), look.cool.color(0)]),
                                                 center: CGPoint(x: 60 - L.x * 30, y: 72 - L.y * 24), startRadius: 0, endRadius: 46))

        // The surface: a lens of lighter water, a bright meniscus on the near edge.
        let hw = bowl.halfWidths[li] - 0.5
        let bob = frame.reduceMotion ? 0 : sin(time * 1.9) * 0.35
        let surface = Path(ellipseIn: CGRect(x: 60 - hw, y: top - 3.4 + bob, width: hw * 2, height: 6.8))
        c.fill(surface, with: .linearGradient(Gradient(colors: [waterDeep.color(0.3), waterLight.color(0.6)]), startPoint: CGPoint(x: 60, y: top - 3.4), endPoint: CGPoint(x: 60, y: top + 3.4)))
        c.stroke(surface, with: .color(look.lifted(waterLight, 0.6).color(0.7)), lineWidth: 0.9)
        // Where the water was, a dry line on the glass.
        if li > 0 {
            let dry = Path(ellipseIn: CGRect(x: 60 - bowl.halfWidths[0] + 0.6, y: BowlGeometry.levels[0] - 3.2, width: (bowl.halfWidths[0] - 0.6) * 2, height: 6.4))
            c.stroke(dry, with: .color(look.lifted(waterLight, 0.5).color(0.28 * Ink.clamp(Double(li) / 3))), style: StrokeStyle(lineWidth: 0.7, dash: [2.4, 2.2]))
        }

        // The glass: a thin body, the rim of the sky's light, the window.
        c.stroke(bowl.glass, with: .color(look.lifted(waterLight, 0.5).color(0.34)), lineWidth: 1.5)
        c.stroke(bowl.glass, with: .color(waterDeep.color(0.22)), lineWidth: 0.6)
        c.stroke(bowl.rimArc[lit], with: .color(look.rim.color(min(1, look.rimAlpha * 2.2))), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
        c.stroke(bowl.rimArc[lit], with: .color(Color.white.opacity(0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        c.fill(bowl.streak[lit], with: .linearGradient(Gradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.08)]), startPoint: CGPoint(x: 60, y: 46), endPoint: CGPoint(x: 60, y: 72)))
        c.fill(bowl.streak[1 - lit], with: .color(Color.white.opacity(0.07)))
        c.fill(bowl.dots, with: .color(Color.white.opacity(0.45)))

        // The lip of the mouth, and the thick glass of the foot.
        c.stroke(bowl.mouth, with: .color(look.lifted(waterLight, 0.6).color(0.6)), lineWidth: 1.5)
        c.stroke(bowl.mouth, with: .color(waterDeep.color(0.3)), lineWidth: 0.5)
        c.fill(Path(ellipseIn: CGRect(x: 40, y: 103.6, width: 40, height: 5)), with: .color(waterDeep.color(0.2)))
    }
}
