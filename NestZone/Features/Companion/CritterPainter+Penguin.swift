import SwiftUI

// MARK: - The penguin

/// What each of the penguin's stages is made of. A chick is a ball of grey
/// down with a dark cap and stub flippers; it keeps the down until it
/// moults, and a moulting juvenile wears its new tuxedo with tufts of the old
/// coat still stuck on it; the grown bird is sleek, upright, long in the
/// flipper and the bill. `down` is how much of the body is still the chick's
/// grey (0...1), `tufts` how much of the old coat clings, `gold` how much of
/// the adult's patch of colour has come in.
struct PenguinGrowth {
    var body: CGSize
    var head: Double, flipper: Double
    var down: Double, tufts: Double
    var bill: Double, eye: Double, feet: Double
    var gold: Double, face: Double, squash: Double

    static func of(_ stage: Int) -> PenguinGrowth {
        switch stage {
        case ...2: PenguinGrowth(body: CGSize(width: 1, height: 1), head: 1.3, flipper: 0.4, down: 1, tufts: 0, bill: 0.8, eye: 1.36, feet: 1.2, gold: 0, face: 1.1, squash: 0.1)
        case 3: PenguinGrowth(body: CGSize(width: 1.14, height: 0.82), head: 1.2, flipper: 0.55, down: 1, tufts: 0, bill: 0.82, eye: 1.3, feet: 1.2, gold: 0, face: 1.0, squash: 0.05)
        case 4: PenguinGrowth(body: CGSize(width: 1.0, height: 0.98), head: 1.12, flipper: 0.8, down: 0.88, tufts: 0, bill: 0.92, eye: 1.18, feet: 1.1, gold: 0, face: 1.05, squash: 0.03)
        case 5: PenguinGrowth(body: CGSize(width: 1, height: 0.99), head: 1, flipper: 0.96, down: 0, tufts: 1, bill: 1, eye: 1, feet: 1, gold: 0.35, face: 1, squash: 0.01)
        default: PenguinGrowth(body: CGSize(width: 0.95, height: 1.04), head: 0.9, flipper: 1.12, down: 0, tufts: 0, bill: 1.2, eye: 0.92, feet: 1, gold: 1, face: 0.92, squash: 0)
        }
    }
}

extension CritterPainter {
    /// The grey of a chick's down: the white front and the blue-black coat
    /// in between, so a colourway's chick is its own grey.
    private var down: RGB { look.belly.mix(look.light, 0.5) }

    /// A penguin on the waddler's terms (the same moods, bowl, eye and cap),
    /// upright: it does not bounce, it rocks from foot to foot, a foot
    /// lifting as the body leans over the other. Bright, it waves a flipper;
    /// content, it stands easy and sways a hair; thirsty, the head bows to the
    /// bowl; dozing, the head sinks to the shoulder and the flippers hug in.
    /// What stage it is in decides what it is made of (`PenguinGrowth`).
    func penguin(_ c: GraphicsContext) {
        let g = CritterGeometry.penguin(plan), s = CritterGeometry.penguinStages(plan)
        let k = PenguinGrowth.of(stage)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly
        let orange = look.accent
        let side = look.L.x > 0 ? 0 : 1
        var b = c
        let sink = motion.by(3.5, 2.2, 0.8, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.03 * w.doze, y: 1 - 0.05 * slump - k.squash)
        b.translateBy(x: -60, y: -108)

        // The rock, and which foot it is that lifts.
        let step = frame.reduceMotion ? 0 : sin(time * 2 * .pi / 0.9)
        let lift = 2.6 * w.bright

        // Feet: a chick's are big for it.
        for (i, foot) in g.feet.enumerated() {
            var f = b
            f.translateBy(x: 0, y: -lift * max(0, i == 0 ? step : -step))
            let fx = i == 0 ? 49.0 : 69.0
            f.translateBy(x: fx, y: 108)
            f.scaleBy(x: k.feet, y: k.feet)
            f.translateBy(x: -fx, y: -108)
            form(f, foot, centre: CGPoint(x: fx, y: 107.5), radius: 9, look.lifted(orange, 0.25), orange, orange.shifted(-12, -3), highlight: 0.3, core: 0.5, rim: false)
            f.stroke(g.toes, with: .color(orange.shifted(-24).color(0.55)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }

        // What colour the body is: the chick's grey, the tuxedo, or between.
        let grey = down
        let bodyLight = light.mix(look.lifted(grey, 0.2), k.down), bodyMid = coat.mix(grey, k.down), bodyDark = dark.mix(grey.shifted(-18), k.down)
        var bb = b
        bb.translateBy(x: 60, y: 108)
        bb.scaleBy(x: k.body.width, y: k.body.height)
        bb.translateBy(x: -60, y: -108)
        form(bb, g.tail, centre: CGPoint(x: 88, y: 104), radius: 10, bodyLight, bodyMid, bodyDark, highlight: 0.2, core: 0.6, rim: false)

        // The body, and the white front over it.
        let edge = stage >= 6 ? s.sleekBody[side] : stage >= 5 ? g.body[side] : s.chickBody[side]
        form(bb, edge, centre: PenguinGeometry.bodyCentre, radius: 34, bodyLight, bodyMid, bodyDark, highlight: 0.5)
        if k.down > 0.02 { hairs(bb, s.downHairs, dark: bodyDark, light: look.lifted(bodyLight, 0.3), alpha: 0.3 * k.down) }
        let white = belly.mix(look.lifted(grey, 0.5), k.down * 0.55)
        form(bb, g.bellyFur, centre: CGPoint(x: 50, y: 82), radius: 30, look.lifted(white, 0.2), white, white.mix(look.cool, 0.35).shifted(-6, 2), highlight: 0.35, core: 0.5, rim: false)

        // The old coat, in tufts, on a bird that is moulting.
        if k.tufts > 0.02 {
            var t = bb
            t.opacity = k.tufts
            let tone = grey
            let lit = t
            var shifted = lit
            shifted.translateBy(x: look.L.x * 0.8, y: look.L.y * 0.8)
            shifted.fill(s.bodyTufts, with: .color(look.lifted(tone, 0.5).color()))
            let shade = ramp(CGPoint(x: 72, y: 80), 30, look.lifted(tone, 0.25), tone, tone.shifted(-16))
            t.fill(s.bodyTufts, with: shade)
            t.fill(s.bodyTuftCores, with: shade)
            t.fill(s.tuftHairs, with: .color(tone.shifted(-22).color(0.4)))
        }

        // The flipper: it hangs from the shoulder, waves when it is bright,
        // hugs in when it dozes. A chick's is a downy stub; the new
        // tuxedo shows on it first.
        var fc = b
        fc.translateBy(x: 61, y: 61)
        var swing = motion.by(-0.1, 0.12, 0.06, -0.3)
        if !frame.reduceMotion { swing -= (0.5 + 0.5 * sin(time * 7)) * 0.55 * w.bright; swing += 0.03 * sin(time * 1.7) * w.content }
        if let hop, hop < 0.66 { swing -= abs(sin(hop / 0.22 * .pi)) * 0.7 }
        fc.rotate(by: .radians(swing))
        fc.scaleBy(x: k.flipper, y: k.flipper)
        let flipperDown = stage == 3 ? 0.75 : stage == 4 ? 0.25 : 0
        let fm = coat.mix(grey, flipperDown)
        form(fc, g.flipper, centre: CGPoint(x: 2, y: 16), radius: 20, light.mix(grey, flipperDown), fm.mix(light, 0.3), fm.shifted(-4), highlight: 0.2, core: 0.7)
        fc.stroke(g.flipperEdge, with: .color(look.lifted(light, 0.45).color(0.7)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        // The head, over all of it.
        var h = bb
        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3) * w.thirst
        let tilt = motion.by(-0.34, -0.3, 0.04, 0) + (frame.reduceMotion ? 0 : 0.05 * sin(time / 3.1 * .pi * 2) * w.bright) + 0.1 * glance
        h.translateBy(x: motion.by(7, -3, 0, 0) + 1.2 * glance, y: motion.by(9, 5, 0.5, -0.8))
        h.translateBy(x: 46, y: 68)
        h.rotate(by: .radians(tilt))
        h.translateBy(x: -46, y: -68)
        penguinHead(h, babyness: 1)
        neckwear(bb, at: CGPoint(x: 49, y: 72 + (stage <= 4 ? 2 : 0)), span: 14, size: 0.9)
    }

    /// The penguin's head, at the duckling's place: dark crown, a white face
    /// with the eye in it, a patch of gold at the neck, a bill that opens.
    /// A chick's is bigger, with a soft fringe of down; a moulting bird's
    /// has a tuft on the crown; the grown bird's is smooth, with the gold and
    /// (a rockhopper's) the crest that come with it.
    func penguinHead(_ c: GraphicsContext, babyness: Double) {
        let g = CritterGeometry.penguin(plan), s = CritterGeometry.penguinStages(plan)
        let k = PenguinGrowth.of(stage)
        let w = motion.weights
        let hatch = stage <= 2
        let skin = look.tone(0xD7B7B1, dim: 0.6)
        let grey = hatch ? look.belly.mix(look.light, 0.4).mix(skin, 0.35) : down
        let coat = hatch ? grey.shifted(-4) : look.coat.mix(grey, 0.12 * k.down), light = hatch ? look.lifted(grey, 0.2) : look.light, dark = hatch ? grey.shifted(-16) : look.dark
        let belly = look.belly, mark = look.mark
        let accent = look.accent
        let L = look.L
        let side = L.x > 0 ? 0 : 1
        var h = c
        h.translateBy(x: 46, y: 68)
        h.scaleBy(x: k.head, y: k.head)
        h.translateBy(x: -46, y: -68)

        form(h, hatch ? s.hatchHead : stage >= 6 ? s.sleekHead[side] : stage >= 5 ? g.headFur[side] : s.chickHead[side], centre: PenguinGeometry.headCentre, radius: 24, light, coat, dark, highlight: 0.55)
        if hatch {
            h.fill(s.hatchWisps, with: .color(grey.shifted(-8).color(0.8)))
            h.fill(Path(ellipseIn: CGRect(x: 44 + L.x * 4, y: 36, width: 10, height: 3)), with: .color(Color.white.opacity(0.3)))
        }
        if k.tufts > 0.02 {
            var t = h
            t.opacity = k.tufts
            let shade = ramp(CGPoint(x: 46, y: 40), 20, look.lifted(grey, 0.25), grey, grey.shifted(-16))
            t.fill(s.headTufts, with: shade)
            t.fill(s.headTuftCores, with: shade)
        }
        // The gold at the side of the neck, soft to its edge: a grown bird's,
        // a hint on a moulting one's, none on a chick.
        if k.gold > 0.02 {
            let gold = look.tone(plan.gold, dim: 0.5)
            var patch = Path()
            patch.move(to: CGPoint(x: -9, y: 0))
            patch.addQuadCurve(to: CGPoint(x: 9, y: 0.4), control: CGPoint(x: 0, y: -10.5))
            patch.addQuadCurve(to: CGPoint(x: -9, y: 0), control: CGPoint(x: 0, y: 1.2))
            var gp = h
            gp.opacity = k.gold
            gp.fill(patch.applying(CGAffineTransform(translationX: 56, y: 56.5).rotated(by: 0.95)), with: .linearGradient(
                Gradient(stops: [.init(color: gold.color(0), location: 0), .init(color: look.lifted(gold, 0.12).color(), location: 0.35), .init(color: gold.color(), location: 0.7),
                                 .init(color: gold.color(0), location: 1)]), startPoint: CGPoint(x: 51, y: 50), endPoint: CGPoint(x: 61, y: 63)))
        }
        // The white face: a disc, soft at the rim, lit like the rest.
        let face = hatch ? look.lifted(grey, 0.35) : belly.mix(look.lifted(grey, 0.5), k.down * 0.5)
        var fd = h
        fd.translateBy(x: 41, y: 49)
        fd.scaleBy(x: k.face, y: k.face)
        fd.translateBy(x: -41, y: -49)
        fd.fill(Path(ellipseIn: CGRect(x: 30, y: 39, width: 22, height: 20)), with: .radialGradient(
            Gradient(stops: [.init(color: look.lifted(face, 0.25).color(), location: 0), .init(color: face.color(), location: 0.62), .init(color: face.shifted(-8, 3).color(0.9), location: 0.84),
                             .init(color: face.color(0), location: 1)]),
            center: CGPoint(x: 41.4 + L.x * 1.5, y: 49 + L.y * 1.5), startRadius: 0, endRadius: 11.5))

        // The bill: its lower half drops when it is bright, a little when it wants water.
        let peep = hatch ? (frame.reduceMotion ? 0.7 : 0.55 + 0.45 * sin(time * 9)) : 1
        let open = hatch ? max(w.bright * 0.7, w.thirst * 0.9 * peep) * (frame.reduceMotion ? 0.7 : 1) : max(w.bright * 0.8, w.thirst * 0.4) * (frame.reduceMotion ? 0.6 : 1)
        var bh = h
        bh.translateBy(x: 34, y: 54)
        bh.scaleBy(x: k.bill, y: 1 - (k.bill - 1) * 0.5)
        bh.translateBy(x: -34, y: -54)
        var low = bh
        low.translateBy(x: 34, y: 55.4)
        low.rotate(by: .radians(-0.36 * open))
        low.translateBy(x: -34, y: -55.4)
        if open > 0.08 {
            bh.fill(Path(ellipseIn: CGRect(x: 17, y: 54.4, width: 16, height: 2 + 4.2 * open)), with: .color(Color(red: 0.32, green: 0.1, blue: 0.12, opacity: min(1, open * 2.2))))
            if open > 0.4 { bh.fill(Path(ellipseIn: CGRect(x: 22, y: 57.4, width: 7, height: 1.8 * open)), with: .color(look.tone(0xF08A9A).color(Ink.clamp(open)))) }
        }
        form(low, g.lowerBill, centre: CGPoint(x: 26, y: 58), radius: 9, accent.shifted(-4), accent.shifted(-10, -1), accent.shifted(-22, -3), highlight: 0.15, core: 0.7, rim: false)
        form(bh, g.upperBill, centre: CGPoint(x: 24, y: 53), radius: 12, look.lifted(accent, 0.3), accent, accent.shifted(-14, -3), highlight: 0.5, core: 0.6)
        bh.fill(Path(ellipseIn: CGRect(x: 29.4, y: 51.4, width: 1.3, height: 1.1)), with: .color(look.ink.opacity(0.5)))
        bh.fill(Path(ellipseIn: CGRect(x: 21 + L.x * 1.2, y: 50.9, width: 7, height: 1.1)), with: .color(Color.white.opacity(0.5)))
        // The egg tooth, a white bump a hatchling cuts its way out with.
        if stage <= 3 {
            bh.fill(Path(ellipseIn: CGRect(x: 12.6, y: 50.4, width: 3.4, height: 2.4)), with: .color(look.lifted(accent, 0.8).color(stage == 3 ? 0.55 : 0.95)))
        }

        let blush = Ink.lerp(0.2, 0.95, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.6 * w.thirst)
        h.fill(Path(ellipseIn: CGRect(x: 43, y: 53, width: 10, height: 7)), with: .radialGradient(
            Gradient(colors: [look.tone(0xFF8FA3).color(blush), look.tone(0xFF8FA3).color(0)]), center: CGPoint(x: 48, y: 56.5), startRadius: 0, endRadius: 5))

        // A rockhopper's plumes, which a grown one grows.
        if isAdult, plan.colourway == 2 {
            let gold = look.tone(plan.gold, dim: 0.5)
            h.fill(s.crest, with: .linearGradient(Gradient(colors: [look.lifted(gold, 0.2).color(), gold.color(), gold.shifted(-8).color()]), startPoint: CGPoint(x: 36, y: 36), endPoint: CGPoint(x: 56, y: 44)))
            h.stroke(s.crestLines, with: .color(look.dark.color(0.45)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }

        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3)
        var gaze = CGPoint(x: Ink.lerp(-0.62 * w.thirst, 0.02, glance * w.thirst), y: Ink.lerp(0.78 * w.thirst, 0.02, glance * w.thirst) - 0.06 * w.bright)
        if hatch { gaze = CGPoint(x: -0.3 * w.thirst, y: -0.7 * w.thirst - 0.06 * w.bright) }
        let droop = hatch ? motion.by(1, 0.1, 0.62, 0.08) : motion.by(1, 0.05, 0.05, 0)
        eye(h, at: CGPoint(x: 41.4, y: 47.4), side: -1, rx: 4.6 * k.eye, ry: 5.1 * k.eye, gaze: gaze, droop: droop, lid: hatch ? grey : belly.shifted(-6))
        if w.thirst > 0.05 {
            var brow = Path()
            brow.move(to: CGPoint(x: 36.2, y: 40)); brow.addQuadCurve(to: CGPoint(x: 46.8, y: 41.2), control: CGPoint(x: 41, y: 38.2 - 1.2 * w.thirst))
            h.stroke(brow, with: .color(mark.color(0.55 * w.thirst)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        motion.nightcap(h)
        hat(h, foot: CGPoint(x: 46, y: 29.5), tilt: 0.12, scale: 0.9)
    }

    // MARK: Hatchling

    /// Just out of the egg: a nearly bare, wet, pinkish-grey blob with a few
    /// thin strands of down, lying on its belly in the lower half of its
    /// shell, flipper stubs at its sides, the feet splayed out in front, the
    /// head too heavy to hold up and the eyes shut for most of the day. Thirsty,
    /// it is cold and calling (it trembles, bill open, looking up); bright, it
    /// lifts its head and its flippers paddle; dozing, the head rests on it.
    func penguinHatchling(_ c: GraphicsContext) {
        let g = CritterGeometry.penguin(plan), s = CritterGeometry.penguinStages(plan)
        let w = motion.weights
        let side = look.L.x > 0 ? 0 : 1
        let skin = look.tone(0xD7B7B1, dim: 0.6)
        let grey = look.belly.mix(look.light, 0.4).mix(skin, 0.35)
        let orange = look.accent
        hatchShell(c, front: false)
        var b = c
        let shiver = frame.reduceMotion ? 0 : sin(time * 38) * 0.5 * w.thirst
        b.translateBy(x: shiver, y: motion.by(2.2, 0.8, 0.3, -1.2))
        for (i, foot) in g.feet.enumerated() {
            var f = b
            f.translateBy(x: i == 0 ? -10 : 8, y: i == 0 ? 0.5 : -0.5)
            f.translateBy(x: i == 0 ? 49 : 69, y: 108)
            f.scaleBy(x: 1.2, y: 1.2)
            f.translateBy(x: i == 0 ? -49 : -69, y: -108)
            form(f, foot, centre: CGPoint(x: i == 0 ? 49 : 69, y: 107), radius: 9, look.lifted(orange, 0.2), orange.shifted(-3), orange.shifted(-14, -3), highlight: 0.2, core: 0.5, rim: false)
        }
        form(b, s.hatchBody[side], centre: PenguinStages.hatchCentre, radius: 26, look.lifted(grey, 0.25), grey, grey.shifted(-16), highlight: 0.5)
        hairs(b, s.hatchHairs, dark: grey.shifted(-22), light: look.lifted(grey, 0.5), alpha: 0.4)
        let white = look.lifted(grey, 0.5)
        b.fill(Path(ellipseIn: CGRect(x: 38, y: 91, width: 30, height: 17)), with: .radialGradient(
            Gradient(colors: [look.lifted(white, 0.2).color(0.7), white.color(0)]), center: CGPoint(x: 47, y: 100), startRadius: 0, endRadius: 15))
        // Flipper stubs paddle when it is bright and tremble when it is not.
        for (i, x) in [60.0, 76.0].enumerated() {
            var fc = b
            fc.translateBy(x: x, y: 88)
            fc.rotate(by: .radians(0.7 + (frame.reduceMotion ? -0.3 * w.bright : sin(time * 12 + Double(i)) * 0.45 * w.bright) + shiver * 0.5))
            fc.scaleBy(x: 0.42, y: 0.42)
            form(fc, g.flipper, centre: CGPoint(x: 2, y: 16), radius: 20, look.lifted(grey, 0.15), grey, grey.shifted(-14), highlight: 0.2, core: 0.6, rim: false)
        }
        var h = b
        let tilt = motion.by(0.5, -0.2, 0.13, -0.1) + (frame.reduceMotion ? 0 : sin(time / 2.3 * .pi * 2) * 0.03 * (w.content + w.bright))
        h.translateBy(x: motion.by(7, 0, 0, 0), y: 12 + motion.by(5, -1, 1, -4))
        h.translateBy(x: 46, y: 76)
        h.rotate(by: .radians(tilt))
        h.translateBy(x: -46, y: -76)
        penguinHead(h, babyness: 1)
        neckwear(b, at: CGPoint(x: 52 + motion.by(5, 0, 0, 0), y: 84), span: 13, size: 0.85)
        hatchShell(c, front: true)
    }
}
