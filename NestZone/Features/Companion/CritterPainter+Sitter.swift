import SwiftUI

// MARK: - The sitter

extension CritterPainter {
    /// How much bigger a young one's head is, and how short its legs: a
    /// baby's head is a fifth wider, and it grows into it by the grown stage.
    var babyness: Double { stage >= 6 ? 0 : [1, 1, 1, 0.8, 0.5, 0.15][max(0, stage)] }

    func sitter(_ c: GraphicsContext) {
        // Dozing is a different animal on the floor: a curled-up one, not a
        // sitting one with its eyes shut. Between the two it is both, faded.
        let curl = Ink.smooth((0.3 - frame.mood) / 0.2)
        let hedgehog = plan.species == .hedgehog
        if curl < 0.995 {
            var s = c
            s.opacity = 1 - curl
            if hedgehog { hedgehogSit(s) } else { sit(s) }
        }
        if curl > 0.005 {
            var s = c
            s.opacity = curl
            if hedgehog { hedgehogBall(s) } else { curled(s) }
        }
    }

    /// What a paw is coloured: the cream of the belly, or the plan's socks.
    var pawTone: RGB { plan.socks.map { look.tone($0, dim: 0.5) } ?? look.belly }

    // MARK: Sitting

    private func sit(_ c: GraphicsContext) {
        let g = CritterGeometry.sit(plan)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let baby = babyness
        let species = plan.species
        let socks = plan.socks != nil
        let paw = pawTone
        var b = c
        // A tired or wanting one sits lower and rounder; a bright one tall.
        let sink = motion.by(3, 2.4, 1.2, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.01 * sink, y: (1 - 0.022 * sink) * plan.bodyHeight)
        b.translateBy(x: -60, y: -108)
        // What stands on the legs (the body, the tail, the head) rides on them:
        // a young one's long legs lift it, a baby's stubs leave it on the floor.
        var u = b
        u.translateBy(x: 0, y: -g.lift)
        agePose(&u, w)
        let strength = plan.markStrength

        // The silhouette is furred from inside, more on the shadow side.
        let side = look.L.x > 0 ? 0 : 1

        // The far front leg.
        if species != .hamster {
            form(b, g.farLeg, centre: CGPoint(x: 56, y: 94), radius: 14, dark.shifted(4), dark, dark.shifted(-6), highlight: 0, core: 0, rim: false)
            if socks { b.fill(g.farSock, with: .color(paw.shifted(-4).color())) }
            if let t = crossTone { b.fill(g.farLeg, with: legFade(t, from: 82, to: 105)) }
            b.fill(g.farPaw, with: .color((socks ? paw : belly.shifted(-10)).color()))
        }

        // The body: a pear, heavier behind, the light on its shoulder.
        form(u, g.bodyFur[side], centre: g.bodyCentre, radius: 32, light, coat, dark, highlight: 0.62)
        hairs(u, g.hairs, dark: mark, light: look.lifted(light, 0.25), alpha: 0.28)
        patches(u, g.patchA, g.patchB, centre: g.bodyCentre, radius: 32)
        if let t = crossTone { crossMarks(u, g, t) }
        if plan.marks == .tabby { hairs(u, g.stripes, dark: mark, light: light, alpha: 0.48 * strength) }
        if plan.marks == .spots, strength > 0.02 { hairs(u, g.spots, dark: spotDark, light: spotLight, alpha: 0.9 * min(1, strength)) }

        // The chest, pale, where the head sits.
        // Soft all round: it fades to the coat at its rim, so no edge shows.
        u.fill(g.chest, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.3).color(0.95), location: 0), .init(color: belly.color(0.8), location: 0.45),
                                                                .init(color: belly.color(0), location: 1)]),
                                              center: CGPoint(x: 51, y: 92), startRadius: 0, endRadius: 17 * (1 + 0.35 * (plan.bib - 1))))
        // A cross fox's chest is dark.
        if let t = crossTone {
            u.fill(g.chest, with: .radialGradient(Gradient(stops: [.init(color: t.color(0.9), location: 0), .init(color: t.color(0.7), location: 0.5), .init(color: t.color(0), location: 1)]),
                                                  center: CGPoint(x: 51, y: 92), startRadius: 0, endRadius: 17 * (1 + 0.35 * (plan.bib - 1))))
        }

        // The haunch, a round of its own, and the foot under it.
        form(b, g.haunch, centre: CGPoint(x: 77, y: 91), radius: 20, light, coat, dark.shifted(2), highlight: 0.5)
        hairs(u, g.haunchHairs, dark: mark, light: look.lifted(light, 0.25), alpha: 0.28)
        patches(u, g.haunchPatchA, g.haunchPatchB, centre: CGPoint(x: 77, y: 91), radius: 20)
        if plan.marks == .tabby { hairs(u, g.haunchBars, dark: mark, light: light, alpha: 0.5 * strength) }
        if plan.marks == .spots, strength > 0.02 { hairs(u, g.haunchSpots, dark: spotDark, light: spotLight, alpha: 0.9 * min(1, strength)) }
        if species == .hamster {
            // Small round feet, the colour of the coat's underside.
            let foot = Path(ellipseIn: CGRect(x: 66, y: 102.8, width: 19, height: 7.6))
            form(b, foot, centre: CGPoint(x: 75, y: 106.5), radius: 9, look.lifted(belly, 0.15), belly.mix(coat, 0.35), belly.mix(coat, 0.35).shifted(-9, 3), highlight: 0.3, core: 0.5)
        } else {
            // The fox's hind foot is dark, but softer than its socks.
            let hind = socks ? paw.mix(coat, 0.45) : paw
            form(b, g.hindPaw, centre: CGPoint(x: 70, y: 107), radius: 15, look.lifted(hind, 0.3), hind, hind.shifted(-9, 3), highlight: 0.3, core: 0.5)
            b.stroke(g.hindToes, with: .color(dark.color(0.45)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        }

        tail(u, w)

        if species == .hamster {
            // No standing legs: two feet forward, and the paws held up.
            let tint = belly.mix(coat, 0.2)
            for foot in [Path(ellipseIn: CGRect(x: 34, y: 102.6, width: 14, height: 7.4)), Path(ellipseIn: CGRect(x: 49, y: 103.6, width: 12.5, height: 6.6))] {
                form(b, foot, centre: CGPoint(x: 46, y: 106), radius: 9, look.lifted(tint, 0.3), tint, tint.shifted(-9, 3), highlight: 0.4, core: 0.5)
            }
            hamsterHands(u, g)
        } else {
            // The near front leg, with its pale paw.
            form(b, g.nearLeg, centre: CGPoint(x: 43, y: 92), radius: 14, light, coat, dark, highlight: 0.4, core: 0.8)
            if plan.marks == .tabby { hairs(b, g.nearBars, dark: mark, light: light, alpha: 0.5 * strength) }
            // The pale is a sock at the paw only: the leg fades to cream (or, for a
            // fox, to black) from the ankle down.
            b.fill(g.nearLeg, with: .linearGradient(Gradient(stops: [.init(color: paw.color(0), location: 0), .init(color: paw.color(socks ? 0.2 : 0), location: socks ? 0.38 : 0.62),
                                                                      .init(color: paw.color(socks ? 1 : 0.95), location: socks ? 0.72 : 0.92)]),
                                                    startPoint: CGPoint(x: 43, y: 79), endPoint: CGPoint(x: 43, y: 104)))
            // Where the leg meets the body it melts into the coat, with no seam (a
            // splayed baby's leg is out to the side, not under the shoulder).
            glow(u, Path(ellipseIn: CGRect(x: 33, y: 72, width: 24, height: 16)), coat, centre: CGPoint(x: 44, y: 80), radius: 10, alpha: 0.85 * (1 - plan.splay))
            if let t = crossTone { b.fill(g.nearLeg, with: legFade(t, from: 79, to: 104)) }
            form(b, g.nearPaw, centre: CGPoint(x: 43.5, y: 106), radius: 9, look.lifted(paw, 0.3), paw, paw.shifted(-9, 3), highlight: 0.4, core: 0.5)
            b.stroke(g.nearToes, with: .color((socks ? look.lifted(paw, 0.35) : dark).color(socks ? 0.35 : 0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        }

        // Where the head will rest: a soft shadow on the chest under the chin.
        let L = look.L
        glow(u, Path(ellipseIn: CGRect(x: 32 - L.x * 3, y: 58 - L.y * 2, width: 36, height: 24)), dark.mix(look.cool, 0.4), centre: CGPoint(x: 50 - L.x * 3, y: 70), radius: 15, alpha: 0.32)

        neckwear(u, at: CGPoint(x: 47, y: 70), span: 15 * plan.headWidth.squareRoot() * (1 + 0.25 * baby), size: 0.9 + 0.15 * baby)
        placedHead(u, w, baby: baby)
    }

    /// How each age sits and moves, on top of the mood: a baby's sit is a wobble
    /// (it leans, and sways about its feet, a head too heavy for its neck); a
    /// little one rocks and bounces when it is happy; a young one play-bows when
    /// it is bright, its chest low and its rump up, and wiggles before the
    /// pounce. Rotations about the paws (the legs stay put), small because the
    /// body is drawn over the legs. Still under Reduce Motion, in the same
    /// lean, so the pose reads without moving.
    func agePose(_ u: inout GraphicsContext, _ w: PetMotion.Weights) {
        let t = frame.reduceMotion ? 0 : time
        switch plan.life {
        case 3:
            let sway = sin(t / 1.9 * .pi * 2) * 0.045 * (1 - 0.6 * w.doze) + sin(t / 0.7 * .pi * 2) * 0.012 * w.bright
            u.translateBy(x: 60, y: 108); u.rotate(by: .radians(-0.05 + sway)); u.translateBy(x: -60, y: -108)
        case 4:
            let rock = sin(t / 1.2 * .pi * 2) * 0.04 * (w.bright + 0.4 * w.content)
            u.translateBy(x: 60, y: 108); u.rotate(by: .radians(0.015 + rock)); u.translateBy(x: -60, y: -108)
        case 5:
            let bow = w.bright + 0.25 * w.content
            let wiggle = sin(t * 9) * 0.035 * w.bright
            u.translateBy(x: 76, y: 106); u.rotate(by: .radians(-0.17 * bow + wiggle)); u.translateBy(x: -76, y: -106)
        default:
            break
        }
    }

    /// The head, nodding forward when tired, tilting when it is playful, and
    /// dropping and turning toward the bowl when it wants something.
    func placedHead(_ b: GraphicsContext, _ w: PetMotion.Weights, baby: Double) {
        var h = b
        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3) * w.thirst
        let tilt = motion.by(0.2, -0.17, 0.025, 0.1) + (frame.reduceMotion ? 0 : 0.045 * sin(time / 3.1 * .pi * 2) * w.bright) + 0.1 * glance
        h.translateBy(x: 46, y: 68)
        h.rotate(by: .radians(tilt))
        h.translateBy(x: -46, y: -68)
        h.translateBy(x: 47 + motion.by(0, -2.5, 0, 0) + 1.5 * glance, y: 49 + motion.by(2, 4.5, 1.2, -0.5) + 0.07 * baby * 30 * (plan.headScale > 1 ? 1 : 0))
        let grow = plan.headScale
        h.translateBy(x: 0, y: 17)
        h.scaleBy(x: grow, y: grow)
        h.translateBy(x: 0, y: -17)
        sitterHead(h, babyness: baby, local: true)
    }

    // MARK: Curled up

    /// Asleep: a round of fur on the floor, the head laid on the front paws,
    /// the tail wrapped over the nose end, breathing slowly. The same parts
    /// as the sitting one, arranged.
    private func curled(_ c: GraphicsContext) {
        let g = CritterGeometry.curl(plan)
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let paw = pawTone
        var b = c
        // It breathes about the floor: slow, deep, the whole round of it.
        let breath = frame.reduceMotion ? 0 : sin(time / 4.2 * .pi * 2)
        b.translateBy(x: 62, y: 109)
        b.scaleBy(x: 1 + 0.012 * breath, y: 1 + 0.03 * breath)
        b.translateBy(x: -62, y: -109)
        // A baby sleeps in a tight round ball; a young one is sprawled, longer
        // and flatter, with its tail trailing and its head flopped.
        let (curlW, curlH) = plan.life == 3 ? (0.74, 1.12) : plan.life == 4 ? (0.88, 1.05) : plan.life == 5 ? (1.06, 0.88) : (1.0, 1.0)
        var bb = b
        bb.translateBy(x: 62, y: 109); bb.scaleBy(x: curlW, y: curlH); bb.translateBy(x: -62, y: -109)

        form(bb, g.bodyFur[look.L.x > 0 ? 0 : 1], centre: CGPoint(x: 62, y: 94), radius: 36, light, coat, dark, highlight: 0.6)
        hairs(bb, g.hairs, dark: mark, light: look.lifted(light, 0.25), alpha: 0.28)
        patches(bb, g.patchA, g.patchB, centre: CGPoint(x: 62, y: 94), radius: 36)
        if let t = crossTone { bb.fill(g.crossMark, with: .color(t.color(0.9))) }
        if plan.marks == .tabby { hairs(bb, g.stripes, dark: mark, light: light, alpha: 0.55 * plan.markStrength) }
        form(bb, g.haunch, centre: CGPoint(x: 82, y: 95), radius: 18, light, coat, dark.shifted(2), highlight: 0.5)
        patches(bb, g.haunchPatchA, g.haunchPatchB, centre: CGPoint(x: 82, y: 95), radius: 18)
        if plan.marks == .tabby { hairs(bb, g.haunchBars, dark: mark, light: light, alpha: 0.5 * plan.markStrength) }
        if plan.marks == .spots, plan.markStrength > 0.02 { hairs(bb, g.spots, dark: spotDark, light: spotLight, alpha: 0.9 * min(1, plan.markStrength)) }
        let overHead = plan.tail == .plume
        // The tail goes round the front, over the paws; a fox's goes over its
        // nose as well, so its head is laid down first.
        if !overHead { curledTail(bb) }
        if plan.tail == .cotton { cottonTail(bb, at: CGPoint(x: 104, y: 99), size: plan.tailSize, tuck: true) }
        // The front paws, tucked under the chin.
        for (px, y) in [(27.5, 106.2), (41, 108.6)] {
            let x = 62 + (px - 62) * curlW, ps = plan.pawSize
            let pawPath = Path(ellipseIn: CGRect(x: x - 8.2 * ps, y: y - 4.2 * ps, width: 16.4 * ps, height: 8.4 * ps))
            form(b, pawPath, centre: CGPoint(x: x, y: y), radius: 8, look.lifted(paw, 0.3), paw, paw.shifted(-9, 3), highlight: 0.4, core: 0.5)
        }
        // The head, laid down and turned to the viewer.
        var h = b
        h.translateBy(x: 44 + (1 - curlW) * 20, y: 91 + 0.4 * breath + (plan.life == 5 ? 2 : 0))
        h.rotate(by: .radians(plan.life == 5 ? -0.16 : -0.3))
        let grow = 0.96 * plan.headScale
        h.scaleBy(x: grow, y: grow)
        sitterHead(h, babyness: babyness, local: true, resting: true)
        // Asleep, the throat is where the head meets the body: the band turned to run up and down.
        neckwear(b, at: CGPoint(x: 55.5, y: 93), span: 13, tilt: .pi / 2 - 0.35, size: 0.9)
        if overHead { curledTail(bb) }
    }

    /// The tail wrapped round the front of a curled one, tip tucked by the
    /// paws, with its rings.
    private func curledTail(_ c: GraphicsContext) {
        guard plan.tail == .curl || plan.tail == .wag || plan.tail == .plume else { return }
        let coat = look.coat, light = look.light, mark = look.mark, dark = look.dark
        let plume = plan.tail == .plume
        // A young one sprawled asleep lets its tail trail out along the floor.
        let trailing = plan.life == 5 && !plume
        let spine = trailing
            ? PlantPainter.cubic(CGPoint(x: 96, y: 102), CGPoint(x: 106, y: 109), CGPoint(x: 116, y: 111), CGPoint(x: 124, y: 107), n: 16)
            : plume
            ? PlantPainter.cubic(CGPoint(x: 100, y: 97), CGPoint(x: 112, y: 114), CGPoint(x: 66, y: 118), CGPoint(x: 24, y: 108), n: 16)
            : PlantPainter.cubic(CGPoint(x: 98, y: 100), CGPoint(x: 107, y: 108), CGPoint(x: 62, y: 111), CGPoint(x: 28, y: 106), n: 16)
        let (w0, w1) = plume ? (14.0, 8.0) : (9.5 * plan.tailWidth, 6.8 * plan.tailWidth)
        let parts = furRibbonParts(spine, w0, w1, fur: plan.fur, tipFrom: plume ? 12 : nil, bulge: plume ? 5 : 0)
        form(c, parts.body, centre: CGPoint(x: 64, y: 112), radius: 38, light, coat, coat.shifted(-10, 4), highlight: 0.35, core: 0.7)
        if plan.marks == .tabby { c.fill(ringBands(spine, indices: [3, 6, 9, 12], width: 1.8, wide: 9, narrow: 7), with: .color(mark.color(0.6))) }
        if plume {
            plumeTip(c, parts.tip)
        } else {
            c.fill(PlantPainter.ribbon(Array(spine.suffix(4)), 7.0, 6.8, flat: true), with: .color(dark.mix(mark, 0.4).color(0.88)))
        }
    }

    // MARK: The tail

    /// The tail, acting: up with a curl and a flick when it is bright, round
    /// the feet when it is content, low and twitching at the tip when it
    /// wants something. A pup's wags; a rabbit's is a cotton ball.
    private func tail(_ c: GraphicsContext, _ w: PetMotion.Weights) {
        guard plan.tail != .none, plan.tail != .stub else { return }
        if plan.tail == .cotton { cottonTail(c, at: CGPoint(x: 95, y: 95), size: plan.tailSize, tuck: false); return }
        let coat = look.coat, light = look.light, mark = look.mark, dark = look.dark, belly = look.belly
        let kind = plan.tail
        let bright: [CGPoint], content: [CGPoint], thirst: [CGPoint]
        switch kind {
        case .plume:
            // A brush: it is raised and held out behind when bright, laid out low and curled up at the end when content.
            bright = [CGPoint(x: 92, y: 98), CGPoint(x: 113, y: 93), CGPoint(x: 125, y: 72), CGPoint(x: 119, y: 52)]
            content = [CGPoint(x: 92, y: 102), CGPoint(x: 114, y: 107), CGPoint(x: 128, y: 98), CGPoint(x: 126, y: 82)]
            thirst = [CGPoint(x: 92, y: 102), CGPoint(x: 112, y: 109), CGPoint(x: 128, y: 111), CGPoint(x: 136, y: 107)]
        case .wag:
            bright = [CGPoint(x: 92, y: 98), CGPoint(x: 108, y: 94), CGPoint(x: 117, y: 82), CGPoint(x: 117, y: 66)]
            content = [CGPoint(x: 93, y: 101), CGPoint(x: 110, y: 102), CGPoint(x: 119, y: 95), CGPoint(x: 120, y: 85)]
            thirst = [CGPoint(x: 93, y: 102), CGPoint(x: 108, y: 106), CGPoint(x: 116, y: 111), CGPoint(x: 119, y: 112)]
        default:
            bright = [CGPoint(x: 92, y: 100), CGPoint(x: 119, y: 98), CGPoint(x: 126, y: 64), CGPoint(x: 107, y: 55)]
            content = [CGPoint(x: 93, y: 102), CGPoint(x: 115, y: 104), CGPoint(x: 122, y: 92), CGPoint(x: 113, y: 83)]
            thirst = [CGPoint(x: 93, y: 102), CGPoint(x: 111, y: 107), CGPoint(x: 121, y: 113), CGPoint(x: 127, y: 107)]
        }
        // The poses blend by mood; the doze pose is the content one here (a
        // dozing cat is the curled one, with its own tail).
        let wc = w.content + w.doze
        var p: [CGPoint] = (0..<4).map { i in
            CGPoint(x: bright[i].x * w.bright + content[i].x * wc + thirst[i].x * w.thirst,
                    y: bright[i].y * w.bright + content[i].y * wc + thirst[i].y * w.thirst)
        }
        if !frame.reduceMotion {
            // A sway that grows towards the tip, quick when bright, lazy when
            // not; the tip flicks now and then; a wanting one twitches it.
            let sway = sin(time * motion.by(1, 1.4, 1.1, 3.4)) * motion.by(0, 0.5, 1.1, 1.0)
            let flick = motion.beat(every: 3.4, lasting: 0.5) * w.bright
            let lift = motion.beat(every: 6.5, lasting: 1.4, offset: 1) * w.content
            let twitch = motion.beat(every: 3.8, lasting: 0.9, offset: 0.5) * sin(time * 22) * w.thirst
            for i in 1..<4 {
                p[i].x += sway * Double(i) * 1.7 + (i == 3 ? flick * 5 : 0)
                p[i].y += (i == 3 ? -lift * 6 + twitch * 1.5 : 0)
            }
            if kind == .wag {
                // A wag: the whole tail swings about its root, fast and wide when bright, a slow
                // swish when content.
                let swing = sin(time * 13) * 0.34 * w.bright + sin(time * 4.2) * 0.1 * w.content
                let (s, k) = (sin(swing), cos(swing))
                for i in 1..<4 {
                    let dx = p[i].x - p[0].x, dy = p[i].y - p[0].y
                    p[i] = CGPoint(x: p[0].x + dx * k - dy * s, y: p[0].y + dx * s + dy * k)
                }
            }
        }
        if plan.tailLength != 1 {
            for i in 1..<4 { p[i] = CGPoint(x: p[0].x + (p[i].x - p[0].x) * plan.tailLength, y: p[0].y + (p[i].y - p[0].y) * plan.tailLength) }
        }
        let spine = PlantPainter.cubic(p[0], p[1], p[2], p[3], n: 16)
        let baby = babyness
        let plume = kind == .plume
        let fluff = plume ? plan.tailFluff : 1
        let (bw0, bw1) = plume ? ((15.0 + 2 * baby) * fluff, (7.0 + 1.4 * baby) * fluff) : kind == .wag ? (11.5 + 2 * baby, 7.5 + 1.4 * baby) : (9.8 + 2 * baby, 6.4 + 1.4 * baby)
        let (w0, w1) = (bw0 * plan.tailWidth, bw1 * plan.tailWidth)
        let parts = furRibbonParts(spine, w0, w1, fur: plan.fur, tipFrom: plume ? 11 : nil, bulge: plume ? 6 * fluff : 0)
        form(c, parts.body, centre: CGPoint(x: (p[0].x + p[3].x) / 2, y: (p[0].y + p[3].y) / 2), radius: 20, light, coat, coat.shifted(-10, 4), highlight: 0.35, core: 0.7)
        if plan.marks == .tabby {
            c.fill(ringBands(spine, indices: [4, 7, 10, 13], width: 1.9, wide: w0, narrow: w1), with: .color(mark.color(0.62)))
        }
        if plume {
            // The brush: a darker underside along the root, the white tip.
            plumeTip(c, parts.tip)
            return
        }
        // The darker tip.
        let tip = spine[spine.count - 1]
        let tipColour = kind == .wag ? belly.mix(coat, 0.25) : dark.mix(mark, 0.4)
        c.fill(PlantPainter.ribbon(Array(spine.suffix(4)), w1 + 0.5, w1, flat: true), with: .color(tipColour.color(0.9)))
        c.fill(Path(ellipseIn: CGRect(x: tip.x - 1.8 + look.L.x * 1.2, y: tip.y - 2.6, width: 1.8, height: 1.2)), with: .color(belly.color(0.22)))
    }

    /// The white tip of a fox's brush: its own fill over the end of the tail,
    /// lit like a form, soft where it joins the orange.
    private func plumeTip(_ c: GraphicsContext, _ tip: Path) {
        // A kit's tail has no white tip yet; it starts to show as it grows.
        guard plan.tipShown else { return }
        let white = plan.tailTip.map { look.tone($0, dim: 0.5) } ?? look.belly
        let box = tip.boundingRect
        c.fill(tip, with: ramp(CGPoint(x: box.midX, y: box.midY), max(8, box.width * 0.6), look.lifted(white, 0.25), white, white.shifted(-9, 3)))
    }

    /// A rabbit's tail: a ball of white fur on the rump that twitches now
    /// and then, and rocks with a hop.
    private func cottonTail(_ c: GraphicsContext, at p: CGPoint, size: Double, tuck: Bool) {
        let g = CritterGeometry.sit(plan)
        let belly = look.belly
        var t = c
        let twitch = frame.reduceMotion ? 0 : motion.beat(every: 4.4, lasting: 0.35, offset: 1.1) * sin(time * 30) * 0.12 * motion.awake
        let wiggle = frame.reduceMotion ? 0 : sin(time * 2.6) * 0.03 * (1 - 0.7 * motion.weights.doze)
        t.translateBy(x: p.x, y: p.y)
        t.rotate(by: .radians(twitch + wiggle))
        t.scaleBy(x: size, y: size)
        form(t, g.cotton, centre: CGPoint(x: 0, y: 0), radius: 10, look.lifted(belly, 0.35), belly, belly.shifted(-9, 4), highlight: 0.55, core: 0.8)
    }

    /// A tail's outline with the fur in it: a ribbon whose edge is pushed out
    /// at a few points along it and left alone between, so the tail is
    /// irregular without anything stuck on it. `tipFrom` also returns the
    /// outline of the part of it from that point of the spine to the end.
    func furRibbonParts(_ spine: [CGPoint], _ w0: Double, _ w1: Double, fur: Double, tipFrom: Int? = nil, bulge: Double = 0) -> (body: Path, tip: Path) {
        var left: [CGPoint] = [], right: [CGPoint] = []
        let bumps: [Int: Double] = [3: 0.9, 6: 1.3, 8: 0.7, 10: 1.2, 12: 0.8]
        for (i, point) in spine.enumerated() {
            let before = spine[max(0, i - 1)], after = spine[min(spine.count - 1, i + 1)]
            let a = atan2(after.y - before.y, after.x - before.x)
            let u = Double(i) / Double(spine.count - 1)
            let w = (Ink.lerp(w0, w1, u) + bulge * sin(u * .pi)) / 2
            let outer = (bumps[i] ?? 0) * fur, inner = (bumps[i + 1] ?? 0) * 0.5 * fur
            left.append(CGPoint(x: point.x - sin(a) * (w + outer), y: point.y + cos(a) * (w + outer)))
            right.append(CGPoint(x: point.x + sin(a) * (w + inner), y: point.y - cos(a) * (w + inner)))
        }
        let tip = spine[spine.count - 1], prev = spine[spine.count - 2]
        let a = atan2(tip.y - prev.y, tip.x - prev.x)
        let cap = CGPoint(x: tip.x + cos(a) * w1 * 0.5, y: tip.y + sin(a) * w1 * 0.5)
        let first = spine[0], next = spine[1]
        let b = atan2(first.y - next.y, first.x - next.x)
        let outline = left + [cap] + right.reversed() + [CGPoint(x: first.x + cos(b) * w0 * 0.5, y: first.y + sin(b) * w0 * 0.5)]
        var tipPath = Path()
        if let k = tipFrom, k < spine.count - 1 {
            tipPath = .loop(Array(left[k...]) + [cap] + Array(right[k...]).reversed())
        }
        return (.loop(outline), tipPath)
    }

    func furRibbon(_ spine: [CGPoint], _ w0: Double, _ w1: Double, fur: Double) -> Path {
        furRibbonParts(spine, w0, w1, fur: fur).body
    }

    /// Rings round a tail, as quads between its two edges, so they end at
    /// the fur exactly and taper with it.
    func ringBands(_ spine: [CGPoint], indices: [Int], width: Double, wide: Double, narrow: Double) -> Path {
        var path = Path()
        for i in indices where i + 1 < spine.count {
            func edge(_ k: Int) -> (CGPoint, CGPoint) {
                let a = spine[max(0, k - 1)], b = spine[min(spine.count - 1, k + 1)]
                let ang = atan2(b.y - a.y, b.x - a.x)
                let hw = Ink.lerp(wide, narrow, Double(k) / Double(spine.count - 1)) / 2 + 0.3
                return (CGPoint(x: spine[k].x - sin(ang) * hw, y: spine[k].y + cos(ang) * hw),
                        CGPoint(x: spine[k].x + sin(ang) * hw, y: spine[k].y - cos(ang) * hw))
            }
            let (a0, a1) = edge(i), (b0, b1) = edge(min(spine.count - 1, i + Int(width.rounded(.up)) / 2 + 1))
            path.move(to: a0)
            path.addQuadCurve(to: b0, control: CGPoint(x: (a0.x + b0.x) / 2, y: (a0.y + b0.y) / 2))
            path.addLine(to: b1)
            path.addQuadCurve(to: a1, control: CGPoint(x: (a1.x + b1.x) / 2, y: (a1.y + b1.y) / 2))
            path.closeSubpath()
        }
        return path
    }
}
