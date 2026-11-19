import SwiftUI

// MARK: - The turtle

/// What each of the turtle's stages is made of. A hatchling is a soft, wet,
/// bright shell, flat as a coin, with an egg tooth, a head too big and legs
/// like paddles; a baby keeps that flat shell and its few big, bumpy scutes;
/// a little one's shell starts to rise and its scutes to ring; a young one
/// has a domed shell, two rings to every scute and a head that has grown
/// into its neck; the grown turtle's shell is high, ringed, scratched and
/// greened with algae, its skin wrinkled and scaled. `dome` is how high the
/// shell stands (1 is grown), `rings` and `rings2` how far its scutes have
/// ringed, `weather` how worn it is.
struct TurtleGrowth {
    var dome: Double
    var head: Double, eye: Double, leg: Double
    var rings: Double, rings2: Double, weather: Double, scales: Double
    var bump: Double

    static func of(_ stage: Int) -> TurtleGrowth {
        switch stage {
        case ...2: TurtleGrowth(dome: 0.6, head: 1.5, eye: 1.2, leg: 1.34, rings: 0, rings2: 0, weather: 0, scales: 0, bump: 1)
        case 3: TurtleGrowth(dome: 0.64, head: 1.4, eye: 1.18, leg: 1.3, rings: 0, rings2: 0, weather: 0, scales: 0, bump: 1)
        case 4: TurtleGrowth(dome: 0.78, head: 1.25, eye: 1.12, leg: 1.18, rings: 0.4, rings2: 0, weather: 0.1, scales: 0.4, bump: 0.7)
        case 5: TurtleGrowth(dome: 0.9, head: 1.1, eye: 1.06, leg: 1.07, rings: 1, rings2: 0.5, weather: 0.3, scales: 0.8, bump: 0)
        default: TurtleGrowth(dome: 1.04, head: 1, eye: 1, leg: 1, rings: 1, rings2: 1, weather: 1, scales: 1, bump: 0)
        }
    }
}

extension CritterPainter {
    /// A turtle on the shell's terms: the shell is the body, and what acts
    /// is the neck. Bright, it stretches up and walks on the spot, mouth
    /// open; content, the head sits out easy and blinks slowly; thirsty, the
    /// neck sags forward and the head hangs to the bowl; dozing, the head and
    /// the legs draw in under the rim, the shell settles on the floor, the
    /// nightcap goes on the shell. The stage decides what the shell and the
    /// head are (`TurtleGrowth`).
    func turtle(_ c: GraphicsContext) {
        let g = CritterGeometry.turtle(plan), s = CritterGeometry.turtleStages(plan)
        let k = TurtleGrowth.of(stage)
        let w = motion.weights
        let skin = look.coat, skinLight = look.light, skinDark = look.dark
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
            l.scaleBy(x: k.leg, y: k.leg * legScale)
            l.translateBy(x: 0, y: -max(0, lift) * 2.6)
            let tone = far ? skinDark.mix(skin, 0.3) : skin
            form(l, g.leg, centre: CGPoint(x: 0, y: 7), radius: 11, far ? tone : skinLight, tone, skinDark, highlight: far ? 0.3 * 0 : 0.3, core: far ? 0 : 0.7, rim: !far)
            if k.scales > 0.02 { l.stroke(s.legScales, with: .color(skinDark.color(0.32 * k.scales * (far ? 0.5 : 1))), style: StrokeStyle(lineWidth: 0.6, lineCap: .round)) }
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
        neckAndHead(b, g, k)

        // The rim, the dome, the scutes. The shell stands as high as the
        // stage says: a coin at first, a dome at the end.
        let L = look.L
        let weather = k.weather
        let shell = look.tone(plan.shell, dim: 0.5).mix(look.tone(0x3A2F20, dim: 0.5), 0.34 * weather)
        let plate = look.tone(plan.plates, dim: 0.5).mix(look.tone(0x8F7F4E, dim: 0.5), 0.3 * weather)
        let rim = look.belly.mix(skin, 0.25)
        form(b, g.skirt, centre: CGPoint(x: 74, y: 104), radius: 36, look.lifted(rim, 0.2), rim, rim.shifted(-10, 2), highlight: 0.2, core: 0.5, rim: false)
        var sc = b
        sc.translateBy(x: 73, y: 102)
        sc.scaleBy(x: 1, y: k.dome)
        sc.translateBy(x: -73, y: -102)
        form(sc, g.dome, centre: TurtleGeometry.shellCentre, radius: 38, shell.mix(plate, 0.25 + 0.1 * k.bump), shell, shell.shifted(-9, 3), highlight: 0.45, core: 0.9)
        // The scutes: lighter, lit from the sky, with their growth rings.
        let plates = stage <= 4 ? s.bigPlates : g.plates
        sc.fill(plates, with: ramp(TurtleGeometry.shellCentre, 40, look.lifted(plate, 0.18), plate, plate.shifted(-12, 2)))
        var lit = sc
        lit.translateBy(x: -L.x * 0.7, y: -L.y * 0.7)
        lit.stroke(plates, with: .color(shell.shifted(-14).color(0.5 + 0.2 * weather)), style: StrokeStyle(lineWidth: 0.8 + 0.5 * k.bump + 0.35 * weather, lineJoin: .round))
        if k.bump > 0.02 {
            // Bumpy: each scute a boss, lit on the sky's side.
            var boss = sc
            boss.translateBy(x: L.x * 1.0, y: L.y * 1.0)
            boss.fill(s.bigBumps, with: .color(look.lifted(plate, 0.5).color(0.32 * k.bump)))
            sc.fill(s.bigBumps.offsetBy(dx: -L.x * 0.8, dy: -L.y * 0.8), with: .color(plate.shifted(-16).color(0.22 * k.bump)))
            sc.fill(s.bigBumps, with: .linearGradient(Gradient(colors: [look.lifted(plate, 0.4).color(0.5 * k.bump), plate.color(0.2 * k.bump)]),
                                                      startPoint: CGPoint(x: 73 + L.x * 30, y: 70 + L.y * 20), endPoint: CGPoint(x: 73 - L.x * 30, y: 95 - L.y * 20)))
        }
        let rings = stage <= 4 ? s.bigRings : g.rings
        sc.stroke(rings, with: .color(shell.mix(plate, 0.3).shifted(-8).color(0.42 * k.rings)), style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))
        var hi = sc
        hi.translateBy(x: L.x * 0.7, y: L.y * 0.7)
        hi.stroke(rings, with: .color(look.lifted(plate, 0.5).color(0.28 * k.rings)), style: StrokeStyle(lineWidth: 0.6, lineJoin: .round))
        if k.rings2 > 0.02 {
            sc.stroke(s.rings2, with: .color(shell.mix(plate, 0.3).shifted(-8).color(0.38 * k.rings2)), style: StrokeStyle(lineWidth: 0.7, lineJoin: .round))
            hi.stroke(s.rings2, with: .color(look.lifted(plate, 0.5).color(0.24 * k.rings2)), style: StrokeStyle(lineWidth: 0.5, lineJoin: .round))
        }
        // A weathered shell: scratches across the scutes, algae at the rim.
        if weather > 0.25 {
            sc.stroke(s.scratches, with: .color(look.lifted(plate, 0.6).color(0.42 * weather)), style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
            sc.fill(s.algae, with: .color(look.tone(0x6F8F55, dim: 0.5).color(0.5 * weather)))
        }
        glow(sc, g.dome, look.cool, centre: CGPoint(x: 73 - L.x * 26, y: 80 - L.y * 20), radius: 40, alpha: look.coolAlpha * 0.9)
        glow(sc, g.dome, look.lifted(plate, 0.5), centre: CGPoint(x: 73 + L.x * 16, y: 66 + L.y * 10), radius: 26, alpha: 0.2)

        leg(46, far: false, lift: step)
        leg(88, far: false, lift: -step)

        // The nightcap on the shell while it sleeps.
        if tuck > 0.01 || frame.domeLift > 0 {
            var cap = b
            cap.translateBy(x: 70, y: 102 - 32 * k.dome)
            cap.rotate(by: .radians(0.12))
            cap.scaleBy(x: 1.25, y: 1.25)
            self.cap(cap, w)
        }
    }

    /// The neck as a ribbon from under the shell to the head, and the head
    /// at its end. Where the head is, and how it is held, is the mood.
    private func neckAndHead(_ b: GraphicsContext, _ g: TurtleGeometry, _ k: TurtleGrowth) {
        let w = motion.weights
        let s = CritterGeometry.turtleStages(plan)
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
        // A baby's neck is thick for its length, a grown one's longer and wrinkled.
        let neck = PlantPainter.ribbon(spine, 15, 11.5 + 5 * (k.head - 1))
        form(b, neck, centre: CGPoint(x: (base.x + hx) / 2, y: (base.y + hy) / 2), radius: 18, skinLight, skin, skinDark, highlight: 0.35, core: 0.8)
        // Folds in the skin of the neck: two, and more as it ages.
        var folds = Path()
        let at = k.scales > 0.6 ? [2, 3, 4, 5, 6] : k.scales > 0.2 ? [3, 4, 5] : [3, 5]
        for i in at where i < spine.count - 1 {
            let p = spine[i], q = spine[i + 1]
            let a = atan2(q.y - p.y, q.x - p.x) + .pi / 2
            folds.move(to: CGPoint(x: p.x - cos(a) * 4, y: p.y - sin(a) * 4))
            folds.addQuadCurve(to: CGPoint(x: p.x + cos(a) * 4, y: p.y + sin(a) * 4), control: CGPoint(x: p.x + 1.5, y: p.y + 0.4))
        }
        b.stroke(folds, with: .color(skinDark.color(0.35)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))

        var h = b
        h.translateBy(x: hx, y: hy)
        h.rotate(by: .radians(motion.by(0.12, 0.34, 0.02, -0.2) + 0.08 * glance))
        h.scaleBy(x: k.head, y: k.head)
        turtleHead(h, babyness: 1)
        _ = s
        // Round the neck, square to it, while the head is out.
        if w.doze < 0.5 {
            let along = atan2(hy - base.y, hx - base.x)
            neckwear(b, at: CGPoint(x: Ink.lerp(base.x, hx, 0.62), y: Ink.lerp(base.y, hy, 0.62) + 5), span: 8.5, tilt: along + .pi / 2, size: 0.62)
        }
    }

    /// The turtle's head about its own centre, looking left: a rounded wedge
    /// of skin, a pale chin, a nostril, spots on the crown, one big eye, a
    /// mouth that opens. A hatchling's has the egg tooth, a big eye shut for
    /// most of the day; an old one's has wrinkles.
    func turtleHead(_ c: GraphicsContext, babyness: Double) {
        let g = CritterGeometry.turtle(plan), s = CritterGeometry.turtleStages(plan)
        let k = TurtleGrowth.of(stage)
        let w = motion.weights
        let skin = look.coat, skinLight = look.light, skinDark = look.dark, belly = look.belly, mark = look.mark
        let L = look.L
        var h = c
        form(h, g.head, centre: CGPoint(x: 0, y: 0), radius: 14, skinLight, skin, skinDark, highlight: 0.5, core: 0.7)
        h.fill(g.chin, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.2).color(0.9), location: 0), .init(color: belly.color(0.6), location: 0.6),
                                                              .init(color: belly.color(0), location: 1)]), center: CGPoint(x: -5, y: 8), startRadius: 0, endRadius: 8.5))
        hairs(h, g.spots, dark: mark, light: look.lifted(skinLight, 0.2), alpha: 0.42)
        if k.scales > 0.5 { h.stroke(s.headWrinkles, with: .color(skinDark.color(0.3 * k.scales)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round)) }
        // Nostril.
        h.fill(Path(ellipseIn: CGRect(x: -13.6, y: -0.2, width: 1.5, height: 1.1)), with: .color(mark.color(0.8)))
        // The egg tooth, the white point on the snout it broke the egg with.
        if stage <= 3 { h.fill(Path(ellipseIn: CGRect(x: -16.4, y: 0.4, width: 3, height: 2.2)), with: .color(look.lifted(belly, 0.6).color(stage == 3 ? 0.6 : 0.95))) }

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
        let droop = stage <= 2 ? motion.by(1, 0.1, 0.6, 0.08) : motion.by(1, 0.05, 0.05, 0)
        eye(h, at: CGPoint(x: -4.6, y: -2.4), side: -1, rx: 4.4 * k.eye, ry: 4.9 * k.eye, gaze: gaze, droop: droop, lid: skin.mix(skinLight, 0.2))
        if w.thirst > 0.05 {
            var brow = Path()
            brow.move(to: CGPoint(x: -9.6, y: -8.8)); brow.addQuadCurve(to: CGPoint(x: 0.6, y: -8), control: CGPoint(x: -4.4, y: -11.4 - w.thirst))
            h.stroke(brow, with: .color(mark.color(0.5 * w.thirst)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        _ = L
        hat(h, foot: CGPoint(x: 1, y: -10.5), tilt: 0.1, scale: 0.6)
    }

    // MARK: Hatchling

    /// Hatching: a bright, wet, soft-shelled little turtle, flat as a coin,
    /// half out of a leathery egg that is sunk in sand: its head out to the
    /// left with the egg tooth, its eyes mostly shut, its legs paddling
    /// inside the torn shell. It is the baby's body at half the size, inside a
    /// cup of egg with a ragged rim.
    func turtleHatchling(_ c: GraphicsContext) {
        let s = CritterGeometry.turtleStages(plan)
        let shell = look.tone(0xF2EBD3, dim: 0.7)
        let lining = look.tone(0xE3CFAE, dim: 0.7)
        // The egg's back half, from inside, and the sand round its foot.
        c.fill(s.cupBack, with: .linearGradient(Gradient(colors: [lining.shifted(-8).color(), lining.color()]), startPoint: CGPoint(x: 78, y: 68), endPoint: CGPoint(x: 78, y: 106)))
        var inner = c
        inner.opacity = 0.9
        inner.stroke(s.cupBack, with: .color(shell.color()), lineWidth: 1.6)
        var t = c
        t.translateBy(x: 74, y: 104)
        t.scaleBy(x: 0.64, y: 0.64)
        t.translateBy(x: -74, y: -104)
        turtle(t)
        // The front lip, torn at its edge.
        form(c, s.cupFront, centre: CGPoint(x: 78, y: 98), radius: 26, shell.mix(RGB(255, 255, 255), 0.4), shell, shell.shifted(-13, 6), highlight: 0.3)
        c.stroke(s.cupRim, with: .color(lining.mix(RGB(255, 255, 255), 0.3).color(0.95)), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        c.stroke(s.cupRim.offsetBy(dx: 0, dy: -1.4), with: .color(Color.white.opacity(0.4)), style: StrokeStyle(lineWidth: 0.6, lineJoin: .round))
        // Sand, heaped at its foot.
        var mound = Path()
        mound.move(to: CGPoint(x: 38, y: 109))
        mound.addQuadCurve(to: CGPoint(x: 60, y: 104), control: CGPoint(x: 46, y: 104))
        mound.addQuadCurve(to: CGPoint(x: 106, y: 109), control: CGPoint(x: 90, y: 100))
        mound.closeSubpath()
        let sand = look.tone(0xE2C98F, dim: 0.6), dark = look.tone(0xB89A5E, dim: 0.6)
        form(c, mound, centre: CGPoint(x: 70, y: 106), radius: 30, look.lifted(sand, 0.3), sand, dark, highlight: 0.3, core: 0.6, rim: false)
    }
}
