import SwiftUI

// MARK: - The goldfish

/// What each of the goldfish's stages is made of. A fry is a glassy tadpole
/// in a bubble. A juvenile is bronze and slim, with a short forked tail and
/// short fins; real goldfish are dull brown for the first months. A fish that
/// is turning has gold breaking through the bronze in blotches, its fins
/// taking colour; the grown one is its full colour (or its colourway's, and
/// the colourway's marks come only now) with deep body and long, flowing,
/// trailing fins. `size` is how big it stands in the bowl, `fin` the length
/// of tail and fins, `turn` how much gold has come through, `fins` how far
/// its fins have taken colour.
struct FishGrowth {
    var size: Double
    var body: CGSize
    var fin: Double, finH: Double
    var lobes: Int
    var eye: Double, scales: Double
    var fleck: Double, turn: Double, fins: Double
    var sway: Double, flow: Double

    static func of(_ stage: Int) -> FishGrowth {
        switch stage {
        case ...3: FishGrowth(size: 0.58, body: CGSize(width: 1.14, height: 0.8), fin: 0.5, finH: 0.55, lobes: 2, eye: 1.45, scales: 0.35, fleck: 0, turn: 0, fins: 0, sway: 0.8, flow: 0)
        case 4: FishGrowth(size: 0.7, body: CGSize(width: 1.08, height: 0.88), fin: 0.68, finH: 0.72, lobes: 2, eye: 1.3, scales: 0.6, fleck: 1, turn: 0, fins: 0, sway: 0.9, flow: 0)
        case 5: FishGrowth(size: 0.86, body: CGSize(width: 1.02, height: 0.95), fin: 0.9, finH: 0.92, lobes: 3, eye: 1.12, scales: 0.85, fleck: 0, turn: 0.62, fins: 0.5, sway: 1, flow: 0)
        default: FishGrowth(size: 1, body: CGSize(width: 1, height: 1), fin: 1.28, finH: 1.12, lobes: 3, eye: 1, scales: 1, fleck: 0, turn: 0, fins: 0, sway: 1.2, flow: 1)
        }
    }
}

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

    /// The eggs of a goldfish: a clutch of clear jelly beads on the gravel,
    /// each with a golden yolk, a few catching the light. The wobbly one has
    /// an embryo in its biggest bead, curled round the yolk with two dark
    /// eyes, that twitches.
    func fishEgg(_ c: GraphicsContext) {
        let bowl = CritterGeometry.bowlArt
        // The bowl stands as large before the fish as after it.
        var c = c
        c.translateBy(x: 60, y: 108)
        c.scaleBy(x: 1.12, y: 1.12)
        c.translateBy(x: -60, y: -108)
        bowlBack(c, bowl, 0)
        let water = look.tone(0xCDEAF0, dim: 0.5), yolk = look.tone(0xF2B65A, dim: 0.6), L = look.L
        let beads: [(Double, Double, Double)] = [(56, 99.4, 2.9), (62, 100.4, 3.2), (68.4, 99.6, 3.0), (74, 100.6, 2.6), (59, 95.6, 3.0), (65.2, 96.4, 4.6), (71.6, 95.2, 3.0), (62, 91.4, 2.6), (69, 91.2, 2.4)]
        var discs = Path(), yolks = Path(), shines = Path()
        let wobble = frame.reduceMotion || stage < 1 ? 0 : sin(time * 5) * 0.5
        for (i, (x, y, r)) in beads.enumerated() {
            let big = i == 5
            let dx = big ? wobble : 0
            discs.addEllipse(in: CGRect(x: x + dx - r, y: y - r, width: r * 2, height: r * 2))
            if !(big && stage == 1) { yolks.addEllipse(in: CGRect(x: x - r * 0.34, y: y - r * 0.3, width: r * 0.68, height: r * 0.68)) }
            shines.addEllipse(in: CGRect(x: x + L.x * r * 0.35 - r * 0.28, y: y - r * 0.5, width: r * 0.55, height: r * 0.4))
        }
        c.fill(discs, with: .linearGradient(Gradient(colors: [look.lifted(water, 0.5).color(0.55), water.color(0.3)]), startPoint: CGPoint(x: 60, y: 88), endPoint: CGPoint(x: 70, y: 104)))
        c.fill(yolks, with: .radialGradient(Gradient(colors: [look.lifted(yolk, 0.35).color(0.95), yolk.color(0.95), yolk.shifted(-10).color(0.9)]), center: CGPoint(x: 66, y: 98), startRadius: 0, endRadius: 14))
        c.stroke(discs, with: .color(look.lifted(water, 0.7).color(0.7)), lineWidth: 0.6)
        if stage == 1 {
            // The embryo: a curl of body round a yolk, two eyes, a flick of tail.
            let (x, y, r) = beads[5]
            var e = c
            e.translateBy(x: x + wobble, y: y)
            e.rotate(by: .radians(wobble * 0.3))
            e.fill(Path(ellipseIn: CGRect(x: -r * 0.5, y: -r * 0.1, width: r, height: r * 0.8)), with: .color(yolk.color(0.95)))
            var body = Path()
            body.move(to: CGPoint(x: -r * 0.2, y: -r * 0.2))
            body.addQuadCurve(to: CGPoint(x: r * 0.7, y: r * 0.2), control: CGPoint(x: r * 0.5, y: -r * 0.7))
            body.addQuadCurve(to: CGPoint(x: r * 0.3, y: r * 0.9), control: CGPoint(x: r * 1.0, y: r * 0.7))
            e.stroke(body, with: .color(look.tone(0x7A5A3A, dim: 0.6).color(0.9)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            e.fill(Path(ellipseIn: CGRect(x: -r * 0.55, y: -r * 0.55, width: 1.4, height: 1.4)), with: .color(look.ink))
            e.fill(Path(ellipseIn: CGRect(x: -r * 0.12, y: -r * 0.62, width: 1.4, height: 1.4)), with: .color(look.ink))
        }
        c.fill(shines, with: .color(Color.white.opacity(0.85)))
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
        if stage == 2 { fry(c, bowl, li); return }
        let geometry = CritterGeometry.fishArt, stages = CritterGeometry.fishStages
        let k = FishGrowth.of(stage)
        let w = motion.weights
        let L = look.L
        let top = BowlGeometry.levels[li]
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        // What it will be: a juvenile is bronze, and the gold comes through it.
        let growing = stage < 6
        let grown = growing ? grownPlan : plan
        let goldLight = growing ? look.tone(grown.light) : light, gold = growing ? look.tone(grown.coat) : coat, goldDark = growing ? look.tone(grown.shade) : dark
        let fin = growing ? coat.mix(light, 0.55).mix(gold.mix(goldLight, 0.55), k.fins) : coat.mix(light, 0.55)
        let t = time
        // How big: the fish grows into the bowl, and its shape changes as it does.
        let fs = k.size * 1.1

        // Where it is: the four moods are four places.
        let swimB = 19.0, swimC = 10.0
        var fx = 60 + motion.by(-2, -4 + 3 * sin(t * 0.5), -swimC * sin(t * 0.35), -swimB * sin(t * 0.8))
        var fy = motion.by(99 - 11 * fs, top + 8 + 1.2 * sin(t * 1.3), 69 + 2.6 * sin(t * 0.7), 66 + 6 * sin(t * 1.6))
        // Nothing crosses the glass: the dorsal fin is the highest thing on the fish,
        // so below the surface it keeps that far under it. Thirsty may break it, on purpose.
        fy = max(fy, top + 3 + 21 * fs * k.finH * (1 - w.thirst))
        let face = motion.by(1, 1, max(-1, min(1, 5 * cos(t * 0.35))), max(-1, min(1, 5 * cos(t * 0.8))))
        // Nor does the tail or the nose: keep both ends inside the glass, whichever
        // way it faces (blended through the turn, so nothing jumps).
        let kk = (face + 1) / 2
        let tailReach = 15.5 + 13.5 * k.fin * (1 + 0.12 * k.flow)
        let leftReach = (17 * kk + tailReach * (1 - kk)) * fs, rightReach = (tailReach * kk + 17 * (1 - kk)) * fs
        fx = min(max(fx, 27 + leftReach), 93.5 - rightReach)
        let angle = motion.by(0.1, 0.62, 0.05 * sin(t * 0.7), 0.16 + 0.12 * sin(t * 1.6))
        // Close to the curved side it is seen foreshortened.
        let wall = 1 - 0.26 * Ink.smooth((abs(fx - 60) - 12) / 8)
        let ph = t * motion.by(1.4, 2.2, 3.4, 8.5)
        let amp = motion.by(1.4, 2.4, 3.4, 6.2) * k.sway

        var f = c
        f.translateBy(x: fx, y: fy + (frame.reduceMotion ? 0 : (w.doze * 0.7 * sin(t / 4.2 * .pi * 2))))
        f.scaleBy(x: fs * face * wall, y: fs)
        f.rotate(by: .radians(angle))
        // A juvenile is long and slim; the deep, round body comes later.
        f.scaleBy(x: k.body.width, y: k.body.height)
        let eL = CGPoint(x: L.x * (face >= 0 ? 1 : -1), y: L.y)

        // The tail: a veil of flowing lobes, one fill. A juvenile's is a short
        // fork, a grown fish's long and trailing, with a second, fainter veil
        // streaming behind it (the same path, stretched: a transform of the
        // context, not a second drawing).
        var veil = Path(), veins = Path()
        let lobes = k.lobes == 2 ? [-1, 1] : [-1, 0, 1]
        for lobe in lobes {
            var pts: [CGPoint] = []
            for j in 0...7 {
                let u = Double(j) / 7
                pts.append(CGPoint(x: 11.5 + 14 * k.fin * u * (lobe == 0 ? 1 : 0.9), y: Double(lobe) * (9.6 + 3.2 * w.bright) * u * (0.7 + 0.3 * k.fin) + amp * sin(ph - 2.4 * u) * u))
            }
            veil.addPath(PlantPainter.ribbon(pts, 5 * (0.6 + 0.4 * k.fin), 10 * (0.5 + 0.5 * k.fin)))
            veins.addLines(Array(pts.dropFirst(1)))
        }
        if k.flow > 0.02 {
            var ghost = f
            ghost.translateBy(x: 11.5, y: 0)
            ghost.scaleBy(x: 1 + 0.16 * k.flow, y: 1 + 0.08 * k.flow)
            ghost.translateBy(x: -11.5, y: 0)
            ghost.fill(veil, with: .color(light.mix(fin, 0.4).color(0.32)))
        }
        f.fill(veil, with: .linearGradient(Gradient(colors: [fin.color(0.96), light.mix(fin, 0.4).color(0.78)]), startPoint: CGPoint(x: 12, y: 0), endPoint: CGPoint(x: 12 + 17 * k.fin, y: 0)))
        f.stroke(veins, with: .color(dark.mix(coat, 0.4).color(0.32)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round, lineJoin: .round))

        // The dorsal fin, behind the back.
        var dorsal: [CGPoint] = []
        for j in 0...6 {
            let u = Double(j) / 6
            dorsal.append(CGPoint(x: -4 + 19 * u, y: -10.4 - (5.6 + 1.6 * w.bright) * k.finH * sin(.pi * (0.12 + 0.7 * u)) + amp * 0.35 * sin(ph - 2 * u) * u))
        }
        f.fill(PlantPainter.ribbon(dorsal, 8, 2.4), with: .color(fin.color(0.92)))

        // The belly fin.
        var pv = f
        pv.translateBy(x: 2, y: 10)
        pv.rotate(by: .radians(0.3 * sin(ph * 0.5)))
        pv.scaleBy(x: 0.6 + 0.4 * k.fin, y: 0.6 + 0.4 * k.fin)
        pv.fill(geometry.pelvic, with: .color(fin.shifted(-6).color(0.9)))

        // The body, lit by the sky, its belly pale, its scales in rows.
        form(f, geometry.body, centre: CGPoint(x: 0, y: 0), radius: 18, light, coat, dark, highlight: 0.55, L: eL)
        // The gold coming through the bronze: first a few flecks, then
        // blotches over the back and the flank, never all at once.
        if k.fleck > 0.02 { f.fill(stages.flecks, with: .color(gold.color(0.85 * k.fleck))) }
        if k.turn > 0.02 {
            let index = min(stages.turn.count - 1, max(0, Int((k.turn * Double(stages.turn.count)).rounded(.up)) - 1))
            f.fill(stages.turn[index], with: ramp(.zero, 18, look.lifted(goldLight, 0.1), gold, goldDark, L: eL))
            var edge = f
            edge.translateBy(x: eL.x * 0.5, y: eL.y * 0.5)
            edge.stroke(stages.turn[index], with: .color(look.lifted(goldLight, 0.4).color(0.4)), style: StrokeStyle(lineWidth: 0.6))
        }
        patches(f, geometry.patchA, geometry.patchB, centre: .zero, radius: 18, L: eL)
        if let tone = plan.face {
            // An oranda's cap: the head in its own colour, soft where it meets the body.
            let cap = look.tone(tone, dim: 0.5)
            f.fill(geometry.cap, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(cap, 0.2).color(0.98), location: 0), .init(color: cap.color(0.94), location: 0.6),
                                                                        .init(color: cap.color(0), location: 1)]), center: CGPoint(x: -10, y: -5), startRadius: 0, endRadius: 11))
        }
        f.fill(geometry.belly, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.2).color(0.9), location: 0), .init(color: belly.color(0.55), location: 0.55),
                                                                      .init(color: belly.color(0), location: 1)]), center: CGPoint(x: 0, y: 8.4), startRadius: 0, endRadius: 14))
        var litScales = f
        litScales.translateBy(x: eL.x * 0.6, y: eL.y * 0.6)
        litScales.stroke(geometry.scales, with: .color(look.lifted(light, 0.35).color(0.4 * k.scales)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        f.stroke(geometry.scales, with: .color(mark.color(0.3 * k.scales)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        f.stroke(geometry.gill.offsetBy(dx: eL.x * 0.5, dy: eL.y * 0.5), with: .color(look.lifted(light, 0.4).color(0.4)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        f.stroke(geometry.gill, with: .color(mark.color(0.32)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))

        // The side fin, beating.
        var pf = f
        pf.translateBy(x: -3.6, y: 4.4)
        pf.rotate(by: .radians(-0.35 + 0.4 * sin(ph * 0.8 + 1) * (0.4 + 0.6 * w.bright)))
        pf.scaleBy(x: 0.6 + 0.4 * k.fin, y: 0.6 + 0.4 * k.fin)
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
        e.scaleBy(x: 1 / k.body.width, y: 1 / k.body.height)
        if face < 0 { e.scaleBy(x: -1, y: 1) }
        let look_ = motion.beat(every: 6.5, lasting: 1.1, offset: 3)
        let gaze = CGPoint(x: Ink.lerp(-0.2 * w.thirst, 0.02, look_ * w.thirst), y: Ink.lerp(-0.7 * w.thirst, 0.02, look_ * w.thirst) - 0.06 * w.bright)
        eye(e, at: .zero, side: -1, rx: 4.3 * k.eye, ry: 4.5 * k.eye, gaze: gaze, droop: motion.by(1, 0.05, 0.05, 0), lid: coat.mix(light, 0.2))

        // The nightcap, small, on the fish's head.
        if w.doze > 0.02 || frame.domeLift > 0, stage >= 3 {
            var cap = f
            cap.translateBy(x: -8, y: -8.5)
            cap.rotate(by: .radians(-0.15))
            cap.scaleBy(x: 0.6, y: 0.6)
            self.cap(cap, w)
        }
        // A hat on the head, and a collar behind the gill.
        hat(f, foot: CGPoint(x: -8, y: -9.5), tilt: -0.15, scale: 0.55)
        neckwear(f, at: CGPoint(x: -5.5, y: 3), span: 10, tilt: .pi / 2 - 0.1, size: 0.55)

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

    // MARK: The fry

    /// A fry: barely a day old, a glassy tadpole that cannot swim yet, so it
    /// hangs head up in a nursery bubble at the surface, living off the
    /// golden yolk sac under its throat, its spine and its two huge dark eyes
    /// showing through. Bright, it wriggles and the bubble bobs; content, it
    /// hangs and its tail ticks over; thirsty, the water is low and it hangs
    /// at the surface gulping, looking out; dozing, it hangs limp and still.
    private func fry(_ c: GraphicsContext, _ bowl: BowlGeometry, _ li: Int) {
        let s = CritterGeometry.fishStages
        let w = motion.weights
        let top = BowlGeometry.levels[li]
        let t = time
        let L = look.L
        let calm = frame.reduceMotion ? 0.0 : 1.0
        let bx = 48 + calm * motion.by(0, 0.5 * sin(t * 1.1), 1.6 * sin(t * 0.6), 2.4 * sin(t * 1.4))
        let by = top + 13.5 + calm * motion.by(0, 0.3 * sin(t * 0.9), 0.7 * sin(t * 0.8), -1.4 + 1.4 * sin(t * 2.2))
        let r = 12.4
        let water = look.tone(0xCDEAF0, dim: 0.5)
        // The nursery: a bubble among two smaller ones.
        let disc = Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2))
        c.fill(disc, with: .radialGradient(Gradient(stops: [.init(color: water.color(0.04), location: 0), .init(color: look.lifted(water, 0.5).color(0.16), location: 0.8),
                                                            .init(color: look.lifted(water, 0.7).color(0.34), location: 1)]), center: CGPoint(x: bx, y: by), startRadius: 0, endRadius: r))

        let sway = calm * motion.by(0, 0.05 * sin(t * 1.4), 0.1 * sin(t * 1.3), 0.22 * sin(t * 3))
        let theta = Double.pi / 2 + 0.12 + sway - 0.4 * w.thirst
        var f = c
        f.translateBy(x: bx - 1.5, y: by + 1)
        f.rotate(by: .radians(theta))
        f.scaleBy(x: 0.74, y: 0.74)
        f.opacity = 0.7 + 0.2 * (1 - w.doze * 0.3)
        let skin = look.tone(0xD8C9A4, dim: 0.5), skinLight = look.lifted(skin, 0.4), skinDark = skin.shifted(-18)
        let amberLight = look.tone(0xF8CF78, dim: 0.5), amber = look.tone(0xE9A24A, dim: 0.5)
        // The tail beats, quick when it is bright.
        let beat = calm * motion.by(0.04 * sin(t * 2), 0.14 * sin(t * 6), 0.2 * sin(t * 5), 0.5 * sin(t * 16))
        var tc = f
        tc.translateBy(x: 7, y: 0)
        tc.rotate(by: .radians(beat))
        tc.translateBy(x: -7, y: 0)
        tc.fill(s.fryTail, with: .linearGradient(Gradient(colors: [skin.color(0.6), skinLight.color(0.18)]), startPoint: CGPoint(x: 7, y: 0), endPoint: CGPoint(x: 19, y: 0)))
        f.fill(s.fryFold, with: .color(skinLight.color(0.3)))
        form(f, s.fryBody, centre: CGPoint(x: -2, y: 0), radius: 11, skinLight, skin, skinDark, highlight: 0.4, core: 0.6, rim: false, L: CGPoint(x: -L.y, y: L.x))
        // The yolk sac, amber and full, under the throat.
        f.fill(s.frySac, with: .radialGradient(Gradient(colors: [look.lifted(amberLight, 0.3).color(0.95), amberLight.color(0.9), amber.color(0.88)]), center: CGPoint(x: -4.4, y: 4.4), startRadius: 0, endRadius: 7))
        f.stroke(s.frySpine, with: .color(skinDark.color(0.55)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [1.2, 1.4]))
        // The eye, huge for its head, kept upright whatever way the fry hangs.
        var e = f
        e.translateBy(x: -7.4, y: -1.4)
        e.rotate(by: .radians(-theta))
        let look_ = motion.beat(every: 6.5, lasting: 1.1, offset: 3)
        let gaze = CGPoint(x: Ink.lerp(-0.2 * w.thirst, 0.02, look_ * w.thirst), y: Ink.lerp(-0.7 * w.thirst, 0.02, look_ * w.thirst))
        eye(e, at: .zero, side: -1, rx: 3.5, ry: 3.7, gaze: gaze, droop: motion.by(1, 0.05, 0.3, 0), lid: skin)
        // A hat on its head, a collar at its throat: it hangs head up, so
        // both turn with it.
        hat(f, foot: CGPoint(x: -12, y: -1), tilt: -.pi / 2, scale: 0.36)
        neckwear(f, at: CGPoint(x: -5.4, y: 0.4), span: 7, tilt: .pi / 2, size: 0.34)
        // The two smaller bubbles, and the ring and shine of the big one.
        for (dx, dy, rr) in [(15.0, -5.0, 4.0), (9.0, 13.0, 3.0)] {
            let small = Path(ellipseIn: CGRect(x: bx + dx - rr, y: by + dy - rr, width: rr * 2, height: rr * 2))
            c.fill(small, with: .color(water.color(0.14)))
            c.stroke(small, with: .color(Color.white.opacity(0.55)), lineWidth: 0.6)
            c.fill(Path(ellipseIn: CGRect(x: bx + dx - rr * 0.5, y: by + dy - rr * 0.6, width: rr * 0.7, height: rr * 0.5)), with: .color(Color.white.opacity(0.7)))
        }
        c.stroke(disc, with: .color(Color.white.opacity(0.55)), lineWidth: 0.8)
        let side = L.x > 0 ? 1.0 : -1.0
        var shine = Path()
        shine.move(to: CGPoint(x: bx + side * 8.6, y: by - 3))
        shine.addQuadCurve(to: CGPoint(x: bx + side * 3.4, y: by - 9.4), control: CGPoint(x: bx + side * 7.6, y: by - 8))
        c.stroke(shine, with: .color(Color.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: bx - side * 7.4 - 0.8, y: by + 6.2, width: 1.8, height: 1.2)), with: .color(Color.white.opacity(0.5)))
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
