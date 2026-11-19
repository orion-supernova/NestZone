import SwiftUI

// MARK: - The waddler (the duckling)

/// What each of the duckling's stages is made of. Not a scale: the body goes
/// from a ball to a long boat, the head from a third too big to small, the
/// neck from none to a swan-ish stretch, the legs from none to a stalk, and
/// the down gives way to feathers that come in as pins, then patches, then a
/// sleek coat. Numbers are for stages 2...6.
struct DuckGrowth {
    /// The body's width and height about its base (a round ball, then a boat).
    var body: CGSize
    var head: Double
    /// How far the body stands up on its legs, and how far the head is raised on its neck.
    var lift: Double, neck: Double
    var wing: Double, tail: Double
    /// How much down shows (0...1) and how many feather tips have come in (0...1).
    var fluff: Double, feathers: Double
    /// Pin feathers: 0 none, then three levels.
    var pins: Int
    /// The dark stripe through the eye, the bill's length, the eye's size, the crown's tuft.
    var stripe: Double, bill: Double, eye: Double, tuft: Double
    /// Wet from the egg, and how much the body is squashed round.
    var wet: Double, squash: Double

    static func of(_ stage: Int) -> DuckGrowth {
        switch stage {
        case ...2: DuckGrowth(body: CGSize(width: 1, height: 1), head: 1.32, lift: 0, neck: 0, wing: 0.6, tail: 0.3, fluff: 1, feathers: 0, pins: 0,
                               stripe: 0.5, bill: 0.82, eye: 1.36, tuft: 0, wet: 1.4, squash: 0.1)
        case 3: DuckGrowth(body: CGSize(width: 0.92, height: 1), head: 1.3, lift: 0, neck: 0, wing: 0.7, tail: 0.45, fluff: 1, feathers: 0, pins: 0,
                           stripe: 0.8, bill: 0.9, eye: 1.3, tuft: 1, wet: 0, squash: 0.06)
        case 4: DuckGrowth(body: CGSize(width: 0.97, height: 0.99), head: 1.14, lift: 1.5, neck: 2.5, wing: 0.85, tail: 0.7, fluff: 0.9, feathers: 0, pins: 1,
                           stripe: 0.65, bill: 1.0, eye: 1.15, tuft: 0.9, wet: 0, squash: 0.04)
        case 5: DuckGrowth(body: CGSize(width: 0.96, height: 0.95), head: 1.02, lift: 6, neck: 12, wing: 0.92, tail: 0.85, fluff: 0.5, feathers: 0.62, pins: 3,
                           stripe: 0.35, bill: 1.08, eye: 1.02, tuft: 0.55, wet: 0, squash: 0.02)
        default: DuckGrowth(body: CGSize(width: 1.14, height: 0.87), head: 0.88, lift: 6, neck: 11, wing: 1, tail: 1, fluff: 0, feathers: 1, pins: 0,
                            stripe: 0, bill: 1.28, eye: 0.9, tuft: 0, wet: 0, squash: 0)
        }
    }
}

extension CritterPainter {
    /// The duckling, on the kitten's terms: forms lit from the sky, down
    /// breaking the outline, an eye built in layers, a bill that opens. It
    /// bounces rather than breathes (it is a bird), and its moods are the
    /// same four: tall and bobbing when bright, easy when content, head
    /// down and turned to the bowl when thirsty, and when it dozes the head
    /// comes down onto the chest and the whole bird squashes into a round.
    /// What stage it is in decides what it is made of (`DuckGrowth`).
    func waddler(_ c: GraphicsContext) {
        if plan.species == .penguin { penguin(c); return }
        let g = CritterGeometry.duck(plan), s = CritterGeometry.duckStages(plan)
        let k = DuckGrowth.of(stage)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        var b = c
        // A sleepy one sits lower and rounder.
        let sink = motion.by(5, 2.4, 0.8, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.04 * w.doze, y: 1 - 0.07 * slump - k.squash)
        b.translateBy(x: -60, y: -108)
        let side = look.L.x > 0 ? 0 : 1

        // Feet: webbed, orange, toes forward; and, once it stands up on them, the legs.
        let orange = look.accent
        if k.lift > 0.5 {
            var legs = Path()
            for x in [59.0, 81] { legs.move(to: CGPoint(x: x, y: 96 - k.lift)); legs.addLine(to: CGPoint(x: x - 0.4, y: 105.4)) }
            let width = 3.6 - 0.9 * Ink.clamp((k.lift - 4) / 3)
            var lit = b
            lit.translateBy(x: look.L.x * 0.7, y: 0)
            lit.stroke(legs, with: .color(look.lifted(orange, 0.3).color(0.8)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            b.stroke(legs, with: .color(orange.shifted(-4).color()), style: StrokeStyle(lineWidth: width * 0.8, lineCap: .round))
        }
        for (i, foot) in g.feet.enumerated() {
            let x = i == 0 ? 52.0 : 74.0
            form(b, foot, centre: CGPoint(x: x, y: 106.5), radius: 9, look.lifted(orange, 0.25), orange, orange.shifted(-12, -3), highlight: 0.3, core: 0.5, rim: false)
        }
        b.stroke(g.toes, with: .color(orange.shifted(-24).color(0.55)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))

        // Everything above the legs stands on them.
        var bl = b
        bl.translateBy(x: 0, y: -k.lift)

        // The head's whole pose first, because the neck follows it: a sleepy
        // one's comes down onto its chest, a thirsty one's bows to the bowl, a
        // bright one holds it up and sways.
        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3) * w.thirst
        let head = motion.by(-0.42, -0.28, 0.05, 0) + (frame.reduceMotion ? 0 : 0.05 * sin(time / 3.1 * .pi * 2) * w.bright) + 0.1 * glance
        let dx = motion.by(9, -3, 0, 0) + 1.2 * glance
        let drop = motion.by(0.85, 0.45, 0, 0) * k.neck
        let dy = motion.by(10, 5, 0.5, -0.8)

        // The neck, behind the body so its root is under the shoulder, and
        // drawn shorter and leaning as the head comes down.
        if let neck = s.necks[stage] {
            let length = 26 + k.neck
            var n = bl
            n.translateBy(x: 46, y: 88)
            n.concatenate(CGAffineTransform(a: 1, b: 0, c: -(dx * 0.8) / length, d: max(0.25, (length - drop) / length), tx: 0, ty: 0))
            n.translateBy(x: -46, y: -88)
            // The neck is the body's own colour: its feathers once they are in.
            let nf = coat.mix(mark.shifted(isAdult ? -6 : -18), isAdult ? 0.34 : 0.3 + 0.38 * k.feathers)
            form(n, neck.shape, centre: CGPoint(x: 46, y: 74), radius: 24, look.lifted(light, 0.05).mix(nf, 0.45), nf, dark.mix(nf, 0.3), highlight: 0.12, core: 1.1)
            n.fill(neck.barbs, with: .color(dark.color(0.1 + 0.1 * k.fluff)))
        }

        // The body: an egg of down (a ball, a boat), lit on its shoulder.
        var bb = bl
        bb.translateBy(x: 62, y: 104)
        bb.scaleBy(x: k.body.width, y: k.body.height)
        bb.translateBy(x: -62, y: -104)
        form(bb, stage >= 6 ? s.bodySleek[side] : g.body[side], centre: DuckGeometry.bodyCentre, radius: 32, light, coat, dark, highlight: 0.62)
        if k.fluff > 0.02 { hairs(bb, g.down, dark: dark, light: look.lifted(light, 0.3), alpha: 0.26 * k.fluff) }
        // The feathers that are in: tips over the down, in the plan's own
        // deeper tone (a juvenile's ochre, a mallard's brown).
        let feather = coat.mix(mark.shifted(isAdult ? -8 : -18), isAdult ? 0.5 : 0.68)
        feathers(bb, s.scallops, coverage: k.feathers, centre: DuckGeometry.bodyCentre, radius: 32,
                 look.lifted(light, 0.05).mix(feather, 0.45), feather, feather.shifted(-14, -2))
        if k.pins > 0, !isAdult {
            let q = s.backQuills[k.pins - 1]
            bb.stroke(q.shafts, with: .color(mark.shifted(-10).color(0.8)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
            bb.fill(q.sheaths, with: .color(look.lifted(belly, 0.15).color(0.95)))
        }
        // The breast, paler, soft to the rim.
        let softBelly = 1 - 0.45 * k.feathers
        bb.fill(g.belly, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.3).color(0.9 * softBelly), location: 0), .init(color: belly.color(0.7 * softBelly), location: 0.45),
                                                                .init(color: belly.color(0), location: 1)]),
                                              center: CGPoint(x: 47, y: 90), startRadius: 0, endRadius: 21))
        if isAdult, plan.colourway == 3 {
            // A blue Swedish duck's white bib, which only a grown one has.
            bb.fill(s.bib, with: .radialGradient(Gradient(stops: [.init(color: look.tone(0xFFFFFF).color(0.95), location: 0), .init(color: look.tone(0xF4F6FA).color(0.8), location: 0.5),
                                                                  .init(color: look.tone(0xF4F6FA).color(0), location: 1)]), center: CGPoint(x: 40, y: 82), startRadius: 0, endRadius: 14))
        }

        // The tail: three soft feathers of down; a few pins; then, grown, turned up.
        var tc = bb
        tc.translateBy(x: 88, y: 77.5)
        tc.scaleBy(x: k.tail, y: k.tail)
        tc.translateBy(x: -88, y: -77.5)
        if isAdult {
            form(tc, s.adultTail, centre: CGPoint(x: 95, y: 70), radius: 14, light, coat.mix(mark, 0.2), mark.shifted(-4), highlight: 0.2, core: 0.6)
            tc.stroke(s.adultTailLines, with: .color(mark.shifted(-14).color(0.35)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        } else {
            form(tc, g.tail, centre: CGPoint(x: 93, y: 74), radius: 12, light, coat, mark.shifted(-4), highlight: 0.2, core: 0.6)
            tc.stroke(g.tailLines, with: .color(mark.shifted(-14).color(0.35)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
            if k.pins > 0 { quills(bb, s.tailQuills[k.pins - 1]) }
        }

        // The wing droops when sleepy, lifts when bright and flutters, and
        // flaps on a hop. A little one's is a stub; a grown one's lies
        // along the flank with its tip over the tail and the colourway's mark.
        var wc = bb
        wc.translateBy(x: 66, y: 78)
        var tilt = Ink.lerp(0.24, 0, motion.awake) + 0.2 * w.doze - max(0, frame.mood - 0.82) * 0.9
        if let hop, hop < 0.66 { tilt -= abs(sin(hop / 0.22 * .pi)) * 0.49 }
        if !frame.reduceMotion { tilt -= (0.5 + 0.5 * sin(time * 13)) * 0.12 * w.bright }
        wc.rotate(by: .radians(tilt))
        wc.scaleBy(x: k.wing, y: k.wing)
        wc.translateBy(x: -66, y: -78)
        let wingC = mark.mix(coat, isAdult ? 0.25 : 0)
        form(wc, isAdult ? s.adultWing : g.wing, centre: CGPoint(x: 72, y: 80), radius: 18, wingC.mix(light, 0.35), wingC, wingC.shifted(-12, -2), highlight: 0.3, core: 0.7)
        if isAdult, let tone = speculum {
            let spec = look.tone(tone, dim: 0.5)
            wc.fill(s.speculum, with: .linearGradient(Gradient(colors: [look.lifted(spec, 0.25).color(), spec.color(), spec.shifted(-12).color()]), startPoint: CGPoint(x: 72, y: 78), endPoint: CGPoint(x: 92, y: 86)))
            wc.stroke(s.speculumBorders, with: .color(look.tone(0xFFFFFF).color(0.9)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        var lit = wc
        lit.translateBy(x: look.L.x * 0.6, y: look.L.y * 0.6)
        let feathersPath = isAdult ? s.adultFeathers : g.wingFeathers
        lit.stroke(feathersPath, with: .color(look.lifted(light, 0.3).color(0.5)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        wc.stroke(feathersPath, with: .color(wingC.shifted(-18).color(0.55)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        if k.pins > 0, !isAdult { quills(wc, s.wingQuills[k.pins - 1]) }

        // The head, raised on its neck and lowered with it.
        var h = bl
        h.translateBy(x: dx, y: dy * (1 - 0.6 * Ink.clamp(k.neck / 10)))
        h.translateBy(x: 46, y: 72)
        h.rotate(by: .radians(head))
        h.translateBy(x: -46, y: -72)
        h.translateBy(x: 0, y: -(k.neck - drop))
        duckHead(h, babyness: 1)
        neckwear(bl, at: CGPoint(x: 49 + dx * 0.25, y: 74 - 0.4 * (k.neck - drop)), span: 14 - 3 * Ink.clamp(k.neck / 13), size: 0.9)
    }

    /// The mark a grown bird's speculum is in this colourway: a mallard's is
    /// blue. The others have none.
    private var speculum: UInt32? { plan.colourway == 1 ? 0x3D6FC2 : nil }

    private func quills(_ c: GraphicsContext, _ q: (shafts: Path, sheaths: Path)) {
        c.stroke(q.shafts, with: .color(look.mark.shifted(-8).color(0.85)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        c.fill(q.sheaths, with: .color(look.lifted(look.belly, 0.2).color(0.95)))
    }

    /// The duckling's head, in the box: down on the cheek and the back, a
    /// tuft, a bill in two halves, the cheek's blush, the eye. Its size, its
    /// bill and its colours are the stage's (`DuckGrowth`), and the hatchling's
    /// is wet.
    func duckHead(_ c: GraphicsContext, babyness: Double) {
        if plan.species == .penguin { penguinHead(c, babyness: babyness); return }
        let g = CritterGeometry.duck(plan), s = CritterGeometry.duckStages(plan)
        let k = DuckGrowth.of(stage)
        let w = motion.weights
        let coat = wetTone(look.coat, k.wet), light = wetTone(look.light, k.wet * 0.6), dark = wetTone(look.dark, k.wet), mark = look.mark
        let accent = look.accent
        let L = look.L
        var h = c
        // A baby's head is big, and grows from the neck.
        h.translateBy(x: 46, y: 68)
        h.scaleBy(x: k.head, y: k.head)
        h.translateBy(x: -46, y: -68)

        // The tuft stands behind the crown, then the head over its roots. A
        // hatchling has wisps instead, long and thin and still stuck down.
        if k.tuft > 0.02 {
            var t = h
            t.translateBy(x: 48, y: 33)
            t.scaleBy(x: 1, y: k.tuft)
            t.translateBy(x: -48, y: -33)
            form(t, g.tuft, centre: CGPoint(x: 48, y: 26), radius: 10, light, coat, mark.shifted(-6), highlight: 0.2, core: 0.5)
        }
        form(h, stage <= 2 ? s.hatchHead : stage >= 6 ? s.headSleek : g.headDown, centre: DuckGeometry.headCentre, radius: 24, light, coat, dark, highlight: 0.62)
        hairs(h, g.headHairs, dark: dark, light: look.lifted(light, 0.3), alpha: 0.26 * (stage >= 6 ? 0 : 1))
        if stage <= 2 {
            h.fill(s.hatchWisps, with: .color(coat.shifted(-6).color(0.9)))
            // Wet down shines: a streak of the sky on the crown.
            h.fill(Path(ellipseIn: CGRect(x: 44 + L.x * 4, y: 36, width: 11, height: 3.2)), with: .color(Color.white.opacity(0.34)))
        }
        if let tone = plan.face {
            // The face is its own colour, fading into the crown: a soft rim, never a mask.
            let face = look.tone(tone, dim: 0.5)
            h.fill(g.face, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(face, 0.2).color(0.98), location: 0), .init(color: face.color(0.95), location: 0.55),
                                                                  .init(color: face.color(0), location: 1)]),
                                                 center: CGPoint(x: 36, y: 55), startRadius: 0, endRadius: 22))
        }
        // The stripe through the eye that a duckling has and a duck mostly loses.
        let stripe = k.stripe + (isAdult && plan.colourway == 1 ? 0.45 : 0)
        if stripe > 0.02 { h.fill(s.stripe, with: .color(mark.shifted(-22).color(0.6 * stripe))) }

        // The bill: its lower half drops and a mouth shows when it is bright,
        // and a little when it wants water. A hatchling peeps, wide and fast.
        let peep = stage <= 2 ? (frame.reduceMotion ? 0.7 : 0.55 + 0.45 * sin(time * 9)) : 1
        let open = stage <= 2 ? max(w.bright * 0.75, w.thirst * 0.9 * peep) * (frame.reduceMotion ? 0.7 : 1)
                              : max(w.bright * 0.85, w.thirst * 0.4) * (frame.reduceMotion ? 0.6 : 1)
        var bh = h
        bh.translateBy(x: 38, y: 55)
        bh.scaleBy(x: k.bill, y: 1 - (k.bill - 1) * 0.55)
        bh.translateBy(x: -38, y: -55)
        var low = bh
        low.translateBy(x: 36, y: 57.5)
        low.rotate(by: .radians(-0.4 * open))
        low.translateBy(x: -36, y: -57.5)
        if open > 0.08 {
            let hole = Path(ellipseIn: CGRect(x: 23, y: 55.6, width: 14.5, height: 2 + 4.4 * open))
            bh.fill(hole, with: .color(Color(red: 0.32, green: 0.1, blue: 0.12, opacity: min(1, open * 2.2))))
            if open > 0.4 { bh.fill(Path(ellipseIn: CGRect(x: 27, y: 58.6, width: 7, height: 1.8 * open)), with: .color(look.tone(0xF08A9A).color(Ink.clamp(open)))) }
        }
        form(low, g.lowerBill, centre: CGPoint(x: 30, y: 59.5), radius: 8, accent.shifted(-2), accent.shifted(-9, -1), accent.shifted(-22, -3), highlight: 0.15, core: 0.7, rim: false)
        form(bh, g.upperBill, centre: CGPoint(x: 29, y: 55), radius: 11, look.lifted(accent, 0.3), accent, accent.shifted(-14, -3), highlight: 0.5, core: 0.6)
        bh.fill(Path(ellipseIn: CGRect(x: 30.6, y: 53.6, width: 1.3, height: 1.1)), with: .color(look.ink.opacity(0.5)))
        bh.fill(Path(ellipseIn: CGRect(x: 25.5 + L.x * 1.2, y: 52.9, width: 6, height: 1.1)), with: .color(Color.white.opacity(0.5)))
        // The egg tooth, a white bump on the tip of the bill that it hatched
        // with and loses within a few days.
        if stage <= 3 {
            bh.fill(Path(ellipseIn: CGRect(x: 18.6, y: 53.4, width: 3.2, height: 2.3)), with: .color(look.lifted(accent, 0.8).color(stage == 3 ? 0.55 : 0.95)))
        }

        // The cheek's blush, only when it is happy.
        let blush = Ink.lerp(0.2, 0.95, Ink.smooth((frame.mood - 0.3) / 0.7)) * (1 - 0.6 * w.thirst)
        h.fill(Path(ellipseIn: CGRect(x: 45.6, y: 54, width: 10, height: 7.4)), with: .radialGradient(
            Gradient(colors: [look.tone(0xFF8FA3).color(blush), look.tone(0xFF8FA3).color(0)]), center: CGPoint(x: 50.6, y: 57.7), startRadius: 0, endRadius: 5.4))

        // The eye: the kitten's, built in layers, with a round pupil, looking
        // at the bowl when it is thirsty. A hatchling looks up, calling.
        let look_ = motion.beat(every: 6.5, lasting: 1.1, offset: 3)
        var gaze = CGPoint(x: Ink.lerp(-0.62 * w.thirst, 0.02, look_ * w.thirst), y: Ink.lerp(0.78 * w.thirst, 0.02, look_ * w.thirst) - 0.06 * w.bright)
        if stage <= 2 { gaze = CGPoint(x: -0.3 * w.thirst, y: -0.7 * w.thirst - 0.06 * w.bright) }
        let droop = stage <= 2 ? motion.by(1, 0.1, 0.62, 0.08) : motion.by(1, 0.05, 0.05, 0)
        eye(h, at: CGPoint(x: 41.4, y: 47.4), side: -1, rx: 4.5 * k.eye, ry: 5.0 * k.eye, gaze: gaze, droop: droop, lid: coat.mix(light, 0.2))
        // A brow of down over it, raised at the inner end when it is wanting something.
        if w.thirst > 0.05 {
            var brow = Path()
            brow.move(to: CGPoint(x: 36.4, y: 40.2)); brow.addQuadCurve(to: CGPoint(x: 46.6, y: 41.4), control: CGPoint(x: 41, y: 38.4 - 1.2 * w.thirst))
            h.stroke(brow, with: .color(mark.shifted(-10).color(0.5 * w.thirst)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        motion.nightcap(h)
        hat(h, foot: CGPoint(x: 47, y: 29.5), tilt: 0.12, scale: 0.9)
    }

    // MARK: Hatchling

    /// Just out of the egg: a wet, squat blob of clumped down sitting in the
    /// lower half of its shell, splayed, the head far too big and nodding on
    /// a neck that cannot hold it, the eyes mostly shut because a hatchling
    /// sleeps nearly all day, a little wing like a wet leaf. When it is
    /// thirsty it is cold and wants feeding: it trembles and peeps, bill wide,
    /// looking up; bright, it flaps both stubs and holds its head up; dozing,
    /// the head sinks onto the body.
    func duckHatchling(_ c: GraphicsContext) {
        let g = CritterGeometry.duck(plan), s = CritterGeometry.duckStages(plan)
        let k = DuckGrowth.of(2)
        let w = motion.weights
        let side = look.L.x > 0 ? 0 : 1
        let coat = wetTone(look.coat, 1.25), light = wetTone(look.light, 0.8), dark = wetTone(look.dark, 1.2), mark = look.mark, belly = wetTone(look.belly, 0.8)
        let orange = look.accent
        hatchShell(c, front: false)
        var b = c
        let shiver = frame.reduceMotion ? 0 : sin(time * 38) * 0.5 * w.thirst
        b.translateBy(x: shiver, y: motion.by(2.2, 0.8, 0.3, -1.2))

        // Splayed feet, one pointing out each side.
        for (i, foot) in g.feet.enumerated() {
            var f = b
            f.translateBy(x: i == 0 ? -11 : 9, y: i == 0 ? 0 : -1)
            form(f, foot, centre: CGPoint(x: i == 0 ? 52 : 74, y: 106.5), radius: 9, look.lifted(orange, 0.2), orange.shifted(-3), orange.shifted(-14, -3), highlight: 0.2, core: 0.5, rim: false)
        }
        // The body, wet: clumped down, slicked strokes, a belly that is pale.
        form(b, s.hatchBody[side], centre: DuckStages.hatchCentre, radius: 26, light, coat, dark, highlight: 0.5)
        hairs(b, s.hatchHairs, dark: dark.shifted(-6), light: look.lifted(light, 0.35), alpha: 0.3)
        b.fill(Path(ellipseIn: CGRect(x: 36, y: 90, width: 30, height: 18)), with: .radialGradient(
            Gradient(colors: [look.lifted(belly, 0.2).color(0.8), belly.color(0)]), center: CGPoint(x: 46, y: 100), startRadius: 0, endRadius: 15))
        b.fill(s.hatchWisps, with: .color(coat.shifted(-6).color(0.8)))
        // A wing like a wet leaf, flapping when it is bright, shivering when it is not.
        var wc = b
        wc.translateBy(x: 62, y: 86)
        wc.rotate(by: .radians(0.35 - (frame.reduceMotion ? 0.35 * w.bright : sin(time * 15) * 0.5 * w.bright) + shiver * 0.4))
        wc.scaleBy(x: k.wing, y: k.wing)
        wc.translateBy(x: -66, y: -78)
        form(wc, g.wing, centre: CGPoint(x: 72, y: 80), radius: 18, mark.mix(light, 0.3), mark, mark.shifted(-12, -2), highlight: 0.3, core: 0.7)

        // The head: too heavy, so it nods and sags and rises when it calls.
        var h = b
        let tilt = motion.by(0.5, -0.2, 0.13, -0.1) + (frame.reduceMotion ? 0 : sin(time / 2.3 * .pi * 2) * 0.03 * (w.content + w.bright))
        h.translateBy(x: motion.by(7, 0, 0, 0), y: 9 + motion.by(5, -1, 1, -4))
        h.translateBy(x: 46, y: 76)
        h.rotate(by: .radians(tilt))
        h.translateBy(x: -46, y: -76)
        duckHead(h, babyness: 1)
        neckwear(b, at: CGPoint(x: 52 + motion.by(5, 0, 0, 0), y: 84), span: 13, size: 0.85)
        hatchShell(c, front: true)
    }
}
