import SwiftUI

// MARK: - The sitter

extension CritterPainter {
    /// How much bigger a young one's head is, and how short its legs: a
    /// baby's head is a fifth wider, and it grows into it by the grown stage.
    var babyness: Double { stage >= 6 ? 0 : max(0, 1 - Double(stage - 2) / 4) * 0.8 }

    func sitter(_ c: GraphicsContext) {
        // Dozing is a different animal on the floor: a curled-up one, not a
        // sitting one with its eyes shut. Between the two it is both, faded.
        let curl = Ink.smooth((0.3 - frame.mood) / 0.2)
        if curl < 0.995 {
            var s = c
            s.opacity = 1 - curl
            sit(s)
        }
        if curl > 0.005 {
            var s = c
            s.opacity = curl
            curled(s)
        }
    }

    // MARK: Sitting

    private func sit(_ c: GraphicsContext) {
        let g = CritterGeometry.sit(plan)
        let w = motion.weights
        let coat = look.coat, light = look.light, dark = look.dark, belly = look.belly, mark = look.mark
        let baby = babyness
        var b = c
        // A tired or wanting one sits lower and rounder; a bright one tall.
        let sink = motion.by(3, 2.4, 1.2, 0)
        b.translateBy(x: 0, y: sink)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1 + 0.01 * sink, y: 1 - 0.022 * sink - 0.1 * baby)
        b.translateBy(x: -60, y: -108)

        // The silhouette is furred from inside, more on the shadow side.
        let side = look.L.x > 0 ? 0 : 1

        // The far front leg.
        form(b, g.farLeg, centre: CGPoint(x: 56, y: 94), radius: 14, dark.shifted(4), dark, dark.shifted(-6), highlight: 0, core: 0, rim: false)
        b.fill(g.farPaw, with: .color(belly.shifted(-10).color()))

        // The body: a pear, heavier behind, the light on its shoulder.
        form(b, g.bodyFur[side], centre: g.bodyCentre, radius: 32, light, coat, dark, highlight: 0.62)
        hairs(b, g.hairs, dark: mark, light: look.lifted(light, 0.25), alpha: 0.28)
        if plan.marks == .tabby { hairs(b, g.stripes, dark: mark, light: light, alpha: 0.48) }

        // The chest, pale, where the head sits.
        // Soft all round: it fades to the coat at its rim, so no edge shows.
        b.fill(g.chest, with: .radialGradient(Gradient(stops: [.init(color: look.lifted(belly, 0.3).color(0.95), location: 0), .init(color: belly.color(0.8), location: 0.45),
                                                                .init(color: belly.color(0), location: 1)]),
                                              center: CGPoint(x: 51, y: 92), startRadius: 0, endRadius: 17))

        // The haunch, a round of its own, and the foot under it.
        form(b, g.haunch, centre: CGPoint(x: 77, y: 91), radius: 20, light, coat, dark.shifted(2), highlight: 0.5)
        hairs(b, g.haunchHairs, dark: mark, light: look.lifted(light, 0.25), alpha: 0.28)
        if plan.marks == .tabby { hairs(b, g.haunchBars, dark: mark, light: light, alpha: 0.5) }
        form(b, g.hindPaw, centre: CGPoint(x: 70, y: 107), radius: 15, look.lifted(belly, 0.3), belly, belly.shifted(-9, 3), highlight: 0.3, core: 0.5)
        b.stroke(g.hindToes, with: .color(dark.color(0.45)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))

        tail(b, w)

        // The near front leg, with its pale paw.
        form(b, g.nearLeg, centre: CGPoint(x: 43, y: 92), radius: 14, light, coat, dark, highlight: 0.4, core: 0.8)
        if plan.marks == .tabby { hairs(b, g.nearBars, dark: mark, light: light, alpha: 0.5) }
        // The pale is a sock at the paw only: the leg fades to cream from the ankle down.
        b.fill(g.nearLeg, with: .linearGradient(Gradient(stops: [.init(color: belly.color(0), location: 0), .init(color: belly.color(0), location: 0.62),
                                                                  .init(color: belly.color(0.95), location: 0.92)]),
                                                startPoint: CGPoint(x: 43, y: 79), endPoint: CGPoint(x: 43, y: 104)))
        // Where the leg meets the body it melts into the coat, with no seam.
        glow(b, Path(ellipseIn: CGRect(x: 33, y: 72, width: 24, height: 16)), coat, centre: CGPoint(x: 44, y: 80), radius: 10, alpha: 0.85)
        form(b, g.nearPaw, centre: CGPoint(x: 43.5, y: 106), radius: 9, look.lifted(belly, 0.3), belly, belly.shifted(-9, 3), highlight: 0.4, core: 0.5)
        b.stroke(g.nearToes, with: .color(dark.color(0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))

        // Where the head will rest: a soft shadow on the chest under the chin.
        let L = look.L
        glow(b, Path(ellipseIn: CGRect(x: 32 - L.x * 3, y: 58 - L.y * 2, width: 36, height: 24)), dark.mix(look.cool, 0.4), centre: CGPoint(x: 50 - L.x * 3, y: 70), radius: 15, alpha: 0.32)

        // The head, nodding forward when tired, tilting when it is playful,
        // and dropping and turning toward the bowl when it wants something.
        var h = b
        let glance = motion.beat(every: 6.5, lasting: 1.1, offset: 3) * w.thirst
        let tilt = motion.by(0.2, -0.17, 0.025, 0.1) + (frame.reduceMotion ? 0 : 0.045 * sin(time / 3.1 * .pi * 2) * w.bright) + 0.1 * glance
        h.translateBy(x: 46, y: 68)
        h.rotate(by: .radians(tilt))
        h.translateBy(x: -46, y: -68)
        h.translateBy(x: 47 + motion.by(0, -2.5, 0, 0) + 1.5 * glance, y: 49 + motion.by(2, 4.5, 1.2, -0.5) + 0.07 * baby * 30)
        let grow = 1 + baby * 0.5
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
        var b = c
        // It breathes about the floor: slow, deep, the whole round of it.
        let breath = frame.reduceMotion ? 0 : sin(time / 4.2 * .pi * 2)
        b.translateBy(x: 62, y: 109)
        b.scaleBy(x: 1 + 0.012 * breath, y: 1 + 0.03 * breath - 0.05 * babyness)
        b.translateBy(x: -62, y: -109)

        form(b, g.bodyFur[look.L.x > 0 ? 0 : 1], centre: CGPoint(x: 62, y: 94), radius: 36, light, coat, dark, highlight: 0.6)
        hairs(b, g.hairs, dark: mark, light: look.lifted(light, 0.25), alpha: 0.28)
        if plan.marks == .tabby { hairs(b, g.stripes, dark: mark, light: light, alpha: 0.55) }
        form(b, g.haunch, centre: CGPoint(x: 82, y: 95), radius: 18, light, coat, dark.shifted(2), highlight: 0.5)
        if plan.marks == .tabby { hairs(b, g.haunchBars, dark: mark, light: light, alpha: 0.5) }
        // The tail goes round the front, over the paws.
        curledTail(b)
        // The front paws, tucked under the chin.
        for (x, y) in [(27.5, 106.2), (41, 108.6)] {
            let paw = Path(ellipseIn: CGRect(x: x - 8.2, y: y - 4.2, width: 16.4, height: 8.4))
            form(b, paw, centre: CGPoint(x: x, y: y), radius: 8, look.lifted(belly, 0.3), belly, belly.shifted(-9, 3), highlight: 0.4, core: 0.5)
        }
        // The head, laid down and turned to the viewer.
        var h = b
        h.translateBy(x: 44, y: 91 + 0.4 * breath)
        h.rotate(by: .radians(-0.3))
        let grow = 0.96 + babyness * 0.35
        h.scaleBy(x: grow, y: grow)
        sitterHead(h, babyness: babyness, local: true, resting: true)
    }

    /// The tail wrapped round the front of a curled one, tip tucked by the
    /// paws, with its rings.
    private func curledTail(_ c: GraphicsContext) {
        let coat = look.coat, light = look.light, mark = look.mark, dark = look.dark
        let spine = PlantPainter.cubic(CGPoint(x: 98, y: 100), CGPoint(x: 107, y: 108), CGPoint(x: 62, y: 111), CGPoint(x: 28, y: 106), n: 16)
        let tail = PlantPainter.ribbon(spine, 9.5, 6.8, flat: false)
        form(c, tail, centre: CGPoint(x: 64, y: 112), radius: 38, light, coat, coat.shifted(-10, 4), highlight: 0.35, core: 0.7)
        if plan.marks == .tabby { c.fill(ringBands(spine, indices: [3, 6, 9, 12], width: 1.8, wide: 9, narrow: 7), with: .color(mark.color(0.6))) }
        c.fill(PlantPainter.ribbon(Array(spine.suffix(4)), 7.0, 6.8, flat: true), with: .color(dark.mix(mark, 0.4).color(0.88)))
    }

    // MARK: The tail

    /// The tail, acting: up with a curl and a flick when it is bright, round
    /// the feet when it is content, low and twitching at the tip when it
    /// wants something.
    private func tail(_ c: GraphicsContext, _ w: PetMotion.Weights) {
        guard plan.tail != .none else { return }
        let coat = look.coat, light = look.light, mark = look.mark, dark = look.dark, belly = look.belly
        let bright: [CGPoint] = plan.tail == .curl
            ? [CGPoint(x: 92, y: 100), CGPoint(x: 119, y: 98), CGPoint(x: 126, y: 64), CGPoint(x: 107, y: 55)]
            : [CGPoint(x: 92, y: 98), CGPoint(x: 104, y: 98), CGPoint(x: 108, y: 90), CGPoint(x: 104, y: 86)]
        let content: [CGPoint] = [CGPoint(x: 93, y: 102), CGPoint(x: 115, y: 104), CGPoint(x: 122, y: 92), CGPoint(x: 113, y: 83)]
        let thirst: [CGPoint] = [CGPoint(x: 93, y: 102), CGPoint(x: 111, y: 107), CGPoint(x: 121, y: 113), CGPoint(x: 127, y: 107)]
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
        }
        let spine = PlantPainter.cubic(p[0], p[1], p[2], p[3], n: 16)
        let baby = babyness
        let plume = plan.tail == .plume
        let tail = furRibbon(spine, (plume ? 15 : 9.8) + 2 * baby, (plume ? 10 : 6.4) + 1.4 * baby, fur: plan.fur)
        form(c, tail, centre: CGPoint(x: (p[0].x + p[3].x) / 2, y: (p[0].y + p[3].y) / 2), radius: 20, light, coat, coat.shifted(-10, 4), highlight: 0.35, core: 0.7)
        if plan.marks == .tabby {
            c.fill(ringBands(spine, indices: [4, 7, 10, 13], width: 1.9, wide: plume ? 15 : 9.8, narrow: plume ? 10 : 6.4), with: .color(mark.color(0.62)))
        }
        // The darker tip.
        let tip = spine[spine.count - 1]
        c.fill(PlantPainter.ribbon(Array(spine.suffix(4)), 6.9 + 1.4 * baby, 6.4 + 1.4 * baby, flat: true), with: .color(dark.mix(mark, 0.4).color(0.88)))
        c.fill(Path(ellipseIn: CGRect(x: tip.x - 1.8 + look.L.x * 1.2, y: tip.y - 2.6, width: 1.8, height: 1.2)), with: .color(belly.color(0.22)))
    }

    /// A tail's outline with the fur in it: a ribbon whose edge is pushed out
    /// at a few points along it and left alone between, so the tail is
    /// irregular without anything stuck on it.
    func furRibbon(_ spine: [CGPoint], _ w0: Double, _ w1: Double, fur: Double) -> Path {
        var left: [CGPoint] = [], right: [CGPoint] = []
        let bumps: [Int: Double] = [3: 0.9, 6: 1.3, 8: 0.7, 10: 1.2, 12: 0.8]
        for (i, point) in spine.enumerated() {
            let before = spine[max(0, i - 1)], after = spine[min(spine.count - 1, i + 1)]
            let a = atan2(after.y - before.y, after.x - before.x)
            let w = Ink.lerp(w0, w1, Double(i) / Double(spine.count - 1)) / 2
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
        return .loop(outline)
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
