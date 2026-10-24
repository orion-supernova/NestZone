import SwiftUI

/// A pet on one of two body plans (`CritterPlan`), in the duckling's 120-unit
/// box with its feet at (60, 108): the same stages, the same motion
/// (`PetMotion`), the same moods, and the gouache of the plants — every part
/// a shade shape with a lit copy up and left of it, and small leaf-shaped dabs
/// of fur along its edge.
///
/// Like the duckling it is drawn whole every frame, about thirty fills; what
/// it spends is the same order as the duck's. The plan decides which body is
/// built (`sitter`, `perched`) and with what; nothing here is a species.
struct CritterPainter {
    typealias RGB = Canopy.RGB

    let plan: CritterPlan
    let frame: SceneFrame
    /// 0–6: egg or bundle, wobbling, hatchling, baby, little one, young, grown.
    let stage: Int
    let hop: Double?
    let wiggle: Double?
    let waking: Double?

    private var motion: PetMotion { PetMotion(frame: frame, stage: stage, hop: hop, wiggle: wiggle, waking: waking) }
    private var time: Double { motion.time }
    private var awake: Double { motion.awake }
    private var slump: Double { 1 - awake }

    /// Draws the pet standing on the floor at `x`, `size` points tall.
    func draw(_ context: GraphicsContext, x: Double, floor: Double, size: Double) {
        var c = context
        let k = size / 120
        c.translateBy(x: x - 60 * k, y: floor - 108 * k)
        c.scaleBy(x: k, y: k)
        shadow(c)
        var body = c
        // Everything moves about the feet.
        body.translateBy(x: 60, y: 108)
        let (dx, dy, sx, sy, turn) = motion.offsets()
        body.translateBy(x: dx, y: dy)
        body.rotate(by: .radians(turn))
        body.scaleBy(x: sx, y: sy)
        body.translateBy(x: -60, y: -108)
        if stage < 2 { wrapped(body); return }
        let scale = PetMotion.scales[stage]
        body.translateBy(x: 60, y: 108)
        body.scaleBy(x: scale, y: scale)
        body.translateBy(x: -60, y: -108)
        if stage == 2 { hatchling(body); return }
        switch plan.body {
        case .sitter: sitter(body)
        case .perched: perched(body)
        }
    }

    /// Where a hat sits and where a bow or scarf is tied, in the box, for
    /// this stage: the head's top between the ears, and under the chin.
    static func wearing(_ plan: CritterPlan, stage: Int) -> (top: CGPoint, neck: CGPoint) {
        var top = plan.body == .sitter ? CGPoint(x: 47, y: 31) : CGPoint(x: 60, y: 33)
        var neck = plan.body == .sitter ? CGPoint(x: 47, y: 67) : CGPoint(x: 60, y: 72)
        if stage < 2 {
            top = CGPoint(x: 60, y: 46)
            neck = CGPoint(x: 60, y: 90)
        } else if stage == 2 {
            top = CGPoint(x: 60, y: 66)
            neck = CGPoint(x: 60, y: 90)
        }
        let scale = stage < 2 ? 1 : PetMotion.scales[stage]
        func scaled(_ p: CGPoint) -> CGPoint { CGPoint(x: 60 + (p.x - 60) * scale, y: 108 + (p.y - 108) * scale) }
        return (scaled(top), scaled(neck))
    }

    // MARK: Colour

    /// One of the plan's colours as this mood and light leave it: a quiet
    /// pet goes paler and greyer, and the evening cools it a little.
    private func tone(_ hex: UInt32, dim: Double = 0.55) -> RGB {
        let (h, s, l) = RGB(hex).hsl
        return RGB.night(h, s * Ink.lerp(1, 0.55, slump), l + 7 * slump * (1 - l / 100), day: frame.day, dim: dim)
    }

    private func shadow(_ c: GraphicsContext) {
        let scale = stage < 2 ? 1 : PetMotion.scales[stage]
        let wide = plan.body == .sitter ? 38.0 : 30
        c.ellipse(60, 108, stage < 2 ? 24 : wide * scale, stage < 2 ? 5 : 5 * scale + 1, .color(SceneInk.shadow))
    }

    /// A linear shade across a part, light to dark along the light.
    private func shade(_ from: CGPoint, _ to: CGPoint, _ light: RGB, _ mid: RGB, _ dark: RGB) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: [.init(color: light.color(), location: 0), .init(color: mid.color(), location: 0.5),
                                         .init(color: dark.color(), location: 1)]), startPoint: from, endPoint: to)
    }

    private func lit(_ c: GraphicsContext, _ path: Path, _ light: RGB, centre: CGPoint, radius: Double, alpha: Double = 0.8) {
        c.fill(path, with: .radialGradient(Gradient(colors: [light.color(alpha), light.color(0)]), center: centre, startRadius: 0, endRadius: radius))
    }

    /// Small leaf-shaped dabs along a part's edge: the fur, as the tree's
    /// leaves are the canopy. Each is (x, y, angle, length, width).
    private func dabs(_ c: GraphicsContext, _ list: [(Double, Double, Double, Double, Double)], _ colour: RGB, alpha: Double = 1) {
        var path = Path()
        for (x, y, a, len, hw) in list { path.leaf(x, y, cos(a), sin(a), len, hw, 0.2) }
        c.fill(path, with: .color(colour.color(alpha)))
    }

    // MARK: Before it is a pet

    /// The bundle or the egg it starts as: a knitted blanket tied at the top
    /// for a mammal, a speckled egg for a bird. The wobbly one has ears or a
    /// crack.
    private func wrapped(_ c: GraphicsContext) {
        let wrap = tone(plan.wrap, dim: 0.7)
        if plan.origin == .egg {
            let egg = Path(ellipseIn: CGRect(x: 36, y: 40, width: 48, height: 64))
            c.fill(egg, with: shade(CGPoint(x: 40, y: 44), CGPoint(x: 80, y: 100), wrap.mix(RGB(255, 255, 255), 0.3), wrap, wrap.shifted(-12, 6)))
            var speckles = Path()
            for (x, y, r) in [(50.0, 60.0, 1.8), (66, 52, 1.4), (70, 70, 2.0), (54, 82, 1.6), (62, 94, 1.5), (46, 72, 1.2), (74, 86, 1.3), (60, 66, 1.1)] {
                speckles.addEllipse(in: CGRect(x: x - r, y: y - r * 0.8, width: r * 2, height: r * 1.6))
            }
            c.fill(speckles, with: .color(tone(plan.mark, dim: 0.7).color(0.55)))
            c.ellipse(51, 60, 5, 9, .color(Color.white.opacity(0.6)))
            if stage == 1 {
                var crack = Path()
                crack.move(to: CGPoint(x: 44, y: 66))
                for point in [(50.0, 71.0), (55, 65), (61, 71), (67, 66)] { crack.addLine(to: CGPoint(x: point.0, y: point.1)) }
                c.stroke(crack, with: .color(tone(0xD9C39A, dim: 0.7).color()), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            return
        }
        // A bundle: a soft dome, a knot at the top, the weave in rows.
        if stage >= 1 {
            // Ears and a nose looking out of the top.
            for s in [-1.0, 1] {
                var ear = Path.smooth([CGPoint(x: 60 + s * 8, y: 52), CGPoint(x: 60 + s * 10, y: 41), CGPoint(x: 60 + s * 19, y: 40), CGPoint(x: 60 + s * 22, y: 54)])
                ear.closeSubpath()
                c.fill(ear, with: .color(tone(plan.coat).color()))
                var inner = Path.smooth([CGPoint(x: 60 + s * 12, y: 52), CGPoint(x: 60 + s * 13.5, y: 45), CGPoint(x: 60 + s * 18, y: 45), CGPoint(x: 60 + s * 19.5, y: 52)])
                inner.closeSubpath()
                c.fill(inner, with: .color(tone(plan.accent).color()))
            }
        }
        var dome = Path.smooth([CGPoint(x: 34, y: 106), CGPoint(x: 30, y: 82), CGPoint(x: 42, y: 56), CGPoint(x: 60, y: 50), CGPoint(x: 78, y: 56),
                                CGPoint(x: 90, y: 82), CGPoint(x: 86, y: 106), CGPoint(x: 60, y: 111)])
        dome.closeSubpath()
        c.fill(dome, with: shade(CGPoint(x: 38, y: 56), CGPoint(x: 88, y: 108), wrap.mix(RGB(255, 255, 255), 0.35), wrap, wrap.shifted(-14, 8)))
        lit(c, dome, RGB(255, 255, 255), centre: CGPoint(x: 48, y: 68), radius: 24, alpha: 0.35)
        var rows = Path()
        for (i, y) in [66.0, 78, 90, 101].enumerated() {
            let w = 22 + Double(i) * 3.5
            rows.move(to: CGPoint(x: 60 - w, y: y))
            rows.addQuadCurve(to: CGPoint(x: 60 + w, y: y), control: CGPoint(x: 60, y: y + 6))
        }
        c.stroke(rows, with: .color(wrap.shifted(-16, 6).color(0.5)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [3, 3.6]))
        // The knot, like two bunny ears of cloth.
        var knot = Path()
        knot.move(to: CGPoint(x: 60, y: 54))
        knot.addQuadCurve(to: CGPoint(x: 48, y: 42), control: CGPoint(x: 49, y: 54))
        knot.addQuadCurve(to: CGPoint(x: 58, y: 50), control: CGPoint(x: 55, y: 40))
        knot.move(to: CGPoint(x: 60, y: 54))
        knot.addQuadCurve(to: CGPoint(x: 72, y: 43), control: CGPoint(x: 71, y: 55))
        knot.addQuadCurve(to: CGPoint(x: 62, y: 50), control: CGPoint(x: 65, y: 41))
        c.fill(knot, with: .color(wrap.shifted(-6, 4).color()))
        c.circle(60, 53, 3.4, .color(wrap.shifted(-14, 6).color()))
    }

    /// The head out of its wrapping: the egg's cracked shell, or the blanket
    /// folded back round it.
    private func hatchling(_ c: GraphicsContext) {
        var h = c
        h.translateBy(x: plan.body == .sitter ? 14 : 0, y: plan.body == .sitter ? 34 : 0)
        switch plan.body {
        case .sitter: sitterHead(h, babyness: 1)
        case .perched: perchedHead(h, babyness: 1, drop: 18)
        }
        let wrap = tone(plan.wrap, dim: 0.7)
        var edge = Path()
        edge.move(to: CGPoint(x: 28, y: 86))
        if plan.origin == .egg {
            for point in [(35.0, 76.0), (43, 85), (51, 74), (60, 85), (69, 75), (77, 84), (85, 74), (92, 86), (92, 98)] {
                edge.addLine(to: CGPoint(x: point.0, y: point.1))
            }
        } else {
            for i in 0..<5 {
                let x = 28 + Double(i) * 16
                edge.addQuadCurve(to: CGPoint(x: x + 16, y: 86), control: CGPoint(x: x + 8, y: 74))
            }
            edge.addLine(to: CGPoint(x: 92, y: 98))
        }
        edge.addQuadCurve(to: CGPoint(x: 28, y: 98), control: CGPoint(x: 60, y: 128))
        edge.closeSubpath()
        c.fill(edge, with: shade(CGPoint(x: 30, y: 76), CGPoint(x: 90, y: 110), wrap.mix(RGB(255, 255, 255), 0.3), wrap, wrap.shifted(-14, 6)))
        c.fill(Path(ellipseIn: CGRect(x: 36, y: 80, width: 14, height: 5)), with: .color(Color.white.opacity(0.25)))
    }
}

// MARK: - The sitter

extension CritterPainter {
    /// How much bigger a young one's head is: a baby's is a fifth wider, and
    /// it grows into it by the grown stage.
    private var babyness: Double { stage >= 6 ? 0 : max(0, 1 - Double(stage - 2) / 4) * 0.8 }

    fileprivate func sitter(_ c: GraphicsContext) {
        var b = c
        // A sleepy one sits lower and rounder.
        b.translateBy(x: 0, y: 3 * slump)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1, y: 1 - 0.05 * slump)
        b.translateBy(x: -60, y: -108)

        let coat = tone(plan.coat), light = tone(plan.light), dark = tone(plan.shade), belly = tone(plan.belly), mark = tone(plan.mark)
        let bw = plan.bodyWidth
        func wide(_ x: Double) -> Double { 66 + (x - 66) * bw }

        // The tail, behind: up and curling when awake, wrapped round the feet
        // when not, swishing as it goes.
        tail(b, coat: coat, light: light, belly: belly, mark: mark)

        // The far front leg.
        b.fill(Path(roundedRect: CGRect(x: 52, y: 82, width: 9, height: 24), cornerRadius: 4.5), with: .color(dark.color()))
        b.ellipse(56.5, 106.5, 6.8, 3.6, .color(belly.shifted(-8).color()))

        // The body: a pear, heavier behind, with the light on its shoulder.
        var body = Path.smooth([(40, 66), (58, 57), (82, 62), (96, 84), (93, 103), (68, 109), (44, 109), (34, 90)].map { CGPoint(x: wide($0.0), y: $0.1) })
        body.closeSubpath()
        b.fill(body, with: shade(CGPoint(x: 44, y: 58), CGPoint(x: 98, y: 108), light, coat, dark))
        lit(b, body, light.mix(RGB(255, 255, 255), 0.25), centre: CGPoint(x: 54, y: 68), radius: 22, alpha: 0.7)
        if plan.marks == .tabby {
            var stripes = Path()
            for (x, y, a, len) in [(58.0, 59.0, 1.85, 12.0), (66, 58, 1.8, 14), (74, 60, 1.7, 14), (82, 64, 1.55, 14), (90, 74, 1.35, 12)] {
                stripes.leaf(wide(x), y, cos(a), sin(a), len, 2.4, 0.2)
            }
            b.fill(stripes, with: .color(mark.color(0.55)))
        }
        // The chest, pale, where the head sits.
        b.fill(Path(ellipseIn: CGRect(x: 36, y: 74, width: 20, height: 32)), with: .radialGradient(
            Gradient(colors: [belly.mix(RGB(255, 255, 255), 0.25).color(), belly.color()]), center: CGPoint(x: 44, y: 84), startRadius: 0, endRadius: 18))

        // The haunch, a round of its own, and the foot under it.
        b.ellipse(77, 91, 19, 17, .radialGradient(
            Gradient(colors: [light.color(), coat.color(), dark.shifted(2).color()]), center: CGPoint(x: 71, y: 83), startRadius: 0, endRadius: 24))
        if plan.marks == .tabby {
            var bars = Path()
            for (x, y, a) in [(84.0, 82.0, 2.3), (88, 91, 2.55), (84, 99, 2.8)] { bars.leaf(wide(x), y, cos(a), sin(a), 11, 2.2, 0.2) }
            b.fill(bars, with: .color(mark.color(0.5)))
        }
        b.ellipse(72, 107.5, 15, 4.6, .color(belly.color()))
        b.ellipse(66, 106.6, 6, 2, .color(Color.white.opacity(0.3)))
        dabs(b, [(94, 84, -0.1, 7, 2.4), (96, 92, 0.2, 7, 2.4), (93, 99, 0.5, 6, 2.2)], coat)

        // The near front leg, with its pale paw.
        b.fill(Path(roundedRect: CGRect(x: 38, y: 78, width: 11, height: 28), cornerRadius: 5.5), with: shade(CGPoint(x: 38, y: 80), CGPoint(x: 49, y: 100), light, coat, dark))
        b.ellipse(43.6, 105.8, 8, 4.2, .color(belly.color()))
        b.ellipse(41.5, 104.6, 3, 1.4, .color(Color.white.opacity(0.4)))
        var toes = Path()
        for x in [40.5, 43.6, 46.7] { toes.move(to: CGPoint(x: x, y: 106.4)); toes.addLine(to: CGPoint(x: x, y: 108.4)) }
        b.stroke(toes, with: .color(dark.color(0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))

        // The head, nodding forward when tired.
        var h = b
        h.translateBy(x: 46, y: 68)
        h.rotate(by: .radians(slump * 0.2))
        h.translateBy(x: -46, y: -68)
        h.translateBy(x: 47, y: 49)
        let grow = 1 + babyness * 0.25
        h.translateBy(x: 0, y: 17)
        h.scaleBy(x: grow, y: grow)
        h.translateBy(x: 0, y: -17)
        sitterHead(h, babyness: babyness, local: true)
        PetMotion(frame: frame, stage: stage, hop: hop, wiggle: wiggle, waking: waking).nightcap(b)
    }

    private func tail(_ c: GraphicsContext, coat: RGB, light: RGB, belly: RGB, mark: RGB) {
        guard plan.tail != .none else { return }
        let up = plan.tail == .curl ? [CGPoint(x: 92, y: 102), CGPoint(x: 116, y: 102), CGPoint(x: 120, y: 72), CGPoint(x: 104, y: 62)]
            : [CGPoint(x: 92, y: 98), CGPoint(x: 104, y: 98), CGPoint(x: 108, y: 90), CGPoint(x: 104, y: 86)]
        let rest = [CGPoint(x: 92, y: 104), CGPoint(x: 112, y: 110), CGPoint(x: 100, y: 114), CGPoint(x: 74, y: 112)]
        let swish = frame.reduceMotion ? 0 : sin(time * (frame.mood > 0.82 ? 3.4 : 1.8)) * awake
        let p = (0..<4).map { i in
            CGPoint(x: Ink.lerp(rest[i].x, up[i].x, awake) + swish * Double(i) * 1.7, y: Ink.lerp(rest[i].y, up[i].y, awake))
        }
        let spine = PlantPainter.cubic(p[0], p[1], p[2], p[3], n: 14)
        let outline = PlantPainter.ribbon(spine, 9.5, 6.4, flat: false)
        c.fill(outline, with: shade(CGPoint(x: 96, y: 62), CGPoint(x: 116, y: 108), light, coat, coat.shifted(-10, 4)))
        var rings = Path()
        for i in [4, 7, 10] {
            let q = spine[i], r = spine[i + 1]
            let a = atan2(r.y - q.y, r.x - q.x) + .pi / 2
            rings.move(to: CGPoint(x: q.x - cos(a) * 4, y: q.y - sin(a) * 4))
            rings.addLine(to: CGPoint(x: q.x + cos(a) * 4, y: q.y + sin(a) * 4))
        }
        if plan.marks == .tabby { c.stroke(rings, with: .color(mark.color(0.55)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round)) }
        let tip = spine[spine.count - 1]
        c.circle(tip.x, tip.y, 3.3, .color(belly.color()))
    }

    /// The kitten's head and face, centred on its own origin when `local`,
    /// otherwise (for a hatchling) drawn where the duckling's head is.
    private func sitterHead(_ c: GraphicsContext, babyness: Double, local: Bool = false) {
        var h = c
        if !local { h.translateBy(x: 47, y: 49) }
        let coat = tone(plan.coat), light = tone(plan.light), dark = tone(plan.shade), belly = tone(plan.belly), mark = tone(plan.mark)
        let accent = tone(plan.accent), nose = tone(plan.nose)
        let w = 21 * plan.headWidth
        // Ears: they stand up when it is bright and fold out when it is tired.
        let perk = Ink.smooth((frame.mood - 0.7) / 0.28)
        let flick = frame.reduceMotion ? 0 : sin(time * 5.1) * max(0, sin(time * 0.6)) * 0.05 * awake
        for s in [-1.0, 1] {
            var e = h
            e.translateBy(x: s * 13, y: -11)
            e.rotate(by: .radians(s * (0.1 + 0.42 * slump - 0.08 * perk) + (s > 0 ? flick : 0)))
            let eh = 24 * plan.earHeight
            var outer = Path.smooth([CGPoint(x: -8.5, y: 3), CGPoint(x: -6, y: -eh * 0.5), CGPoint(x: 0.5, y: -eh), CGPoint(x: 6.5, y: -eh * 0.45), CGPoint(x: 9, y: 3)])
            outer.closeSubpath()
            e.fill(outer, with: shade(CGPoint(x: -8, y: -eh), CGPoint(x: 8, y: 2), light, coat, dark))
            var inner = Path.smooth([CGPoint(x: -4.8, y: 1.5), CGPoint(x: -3.2, y: -eh * 0.42), CGPoint(x: 0.4, y: -eh * 0.72), CGPoint(x: 3.8, y: -eh * 0.4), CGPoint(x: 5, y: 1.5)])
            inner.closeSubpath()
            e.fill(inner, with: .color(accent.color()))
            e.fill(Path(ellipseIn: CGRect(x: -3.4, y: -eh * 0.62, width: 3, height: eh * 0.3)), with: .color(Color.white.opacity(0.22)))
        }
        // The head: a wide ellipse lit from its upper left, with cheek fur.
        let head = Path(ellipseIn: CGRect(x: -w, y: -17.5, width: w * 2, height: 35))
        dabs(h, [(-w + 2, 3, 2.6, 9, 3.4), (-w + 3, 8, 2.2, 8, 3), (w - 2, 3, 0.54, 9, 3.4), (w - 3, 8, 0.94, 8, 3)], coat)
        h.fill(head, with: .radialGradient(Gradient(colors: [light.color(), coat.color(), coat.shifted(-6, 3).color()]),
                                           center: CGPoint(x: -7, y: -9), startRadius: 0, endRadius: w * 1.35))
        // The tabby's brow: three strokes pointing down the forehead.
        if plan.marks == .tabby {
            var brow = Path()
            for (x, a, len) in [(0.0, Double.pi / 2, 8.5), (-6.0, 1.9, 7), (6.0, 1.24, 7)] { brow.leaf(x, -17, cos(a), sin(a), len, 1.9, 0.2) }
            h.fill(brow, with: .color(mark.color(0.6)))
        }
        // The muzzle: pale, with the nose and the little mouth.
        h.fill(Path(ellipseIn: CGRect(x: -9.5, y: 1, width: 19, height: 13)), with: .radialGradient(
            Gradient(colors: [belly.mix(RGB(255, 255, 255), 0.3).color(), belly.color()]), center: CGPoint(x: -2, y: 4), startRadius: 0, endRadius: 11))
        var nosePath = Path.smooth([CGPoint(x: -3.2, y: 2.6), CGPoint(x: 0, y: 2.2), CGPoint(x: 3.2, y: 2.6), CGPoint(x: 0, y: 6.2)])
        nosePath.closeSubpath()
        h.fill(nosePath, with: .color(nose.color()))
        h.fill(Path(ellipseIn: CGRect(x: -1.6, y: 2.7, width: 1.8, height: 1)), with: .color(Color.white.opacity(0.5)))
        var mouth = Path()
        mouth.move(to: CGPoint(x: 0, y: 6.2)); mouth.addLine(to: CGPoint(x: 0, y: 8.2))
        mouth.move(to: CGPoint(x: -4.2, y: 9.2)); mouth.addQuadCurve(to: CGPoint(x: 0, y: 8.2), control: CGPoint(x: -2.2, y: 10.8))
        mouth.addQuadCurve(to: CGPoint(x: 4.2, y: 9.2), control: CGPoint(x: 2.2, y: 10.8))
        h.stroke(mouth, with: .color(dark.shifted(-14).color(0.7)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
        // Blush, whiskers, eyes.
        let blush = Ink.lerp(0.2, 0.95, Ink.smooth((frame.mood - 0.3) / 0.7))
        for s in [-1.0, 1] { h.circle(s * 14.5, 6.5, 3.3, .color(tone(0xFF8FA3).color(blush))) }
        if plan.whiskers {
            var whiskers = Path()
            let sway = frame.reduceMotion ? 0 : sin(time * 2.3) * 0.6
            for s in [-1.0, 1] {
                for (i, dy) in [-2.4, 0.4, 3.2].enumerated() {
                    whiskers.move(to: CGPoint(x: s * 11.5, y: 7 + Double(i) * 1.2))
                    whiskers.addQuadCurve(to: CGPoint(x: s * 29, y: 6 + dy * 2 + sway), control: CGPoint(x: s * 20, y: 5 + dy + Double(i) * 0.4))
                }
            }
            h.stroke(whiskers, with: .color(Color.white.opacity(0.78)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        }
        for s in [-1.0, 1] { eye(h, at: CGPoint(x: s * 9.5, y: -2.4)) }
    }

    /// An eye, ink with a highlight: bigger and sparkling when bright, a
    /// closed line when it sleeps, blinking now and then, fluttering open
    /// when it wakes.
    private func eye(_ c: GraphicsContext, at p: CGPoint) {
        let ink = Color(hex: "2A1D0E")
        if motion.eyesClosed, waking == nil {
            var lid = Path()
            lid.move(to: CGPoint(x: p.x - 3.6, y: p.y + 0.4))
            lid.addQuadCurve(to: CGPoint(x: p.x + 3.6, y: p.y + 0.4), control: CGPoint(x: p.x, y: p.y + 4.2))
            c.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            return
        }
        var e = c
        e.translateBy(x: p.x, y: p.y)
        e.scaleBy(x: 1, y: motion.blink())
        let bright = frame.mood > 0.82
        e.ellipse(0, 0, bright ? 3.9 : 3.4, bright ? 5 : 4.5, .color(ink))
        e.circle(bright ? 1.3 : 1, bright ? -2 : -1.8, bright ? 1.6 : 1.3, .color(.white))
        if bright { e.circle(-1.3, 1.8, 0.8, .color(.white)) }
    }
}

// MARK: - The perched bird

extension CritterPainter {
    fileprivate func perched(_ c: GraphicsContext) {
        var b = c
        b.translateBy(x: 0, y: 3 * slump)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1, y: 1 - 0.06 * slump)
        b.translateBy(x: -60, y: -108)

        let coat = tone(plan.coat), light = tone(plan.light), dark = tone(plan.shade), belly = tone(plan.belly), mark = tone(plan.mark)
        let accent = tone(plan.accent)
        let bw = plan.bodyWidth

        // Feet: three round toes each.
        for s in [-1.0, 1] {
            for dx in [-3.6, 0, 3.6] { b.ellipse(60 + s * 10 + dx, 108, 2.6, 2, .color(accent.color())) }
            b.fill(Path(roundedRect: CGRect(x: 60 + s * 10 - 1.6, y: 101, width: 3.2, height: 7), cornerRadius: 1.6), with: .color(accent.shifted(-8).color()))
        }
        // The body: an egg, lit from the upper left, and the pale breast with its rows of chevrons.
        let body = Path(ellipseIn: CGRect(x: 60 - 28 * bw, y: 50, width: 56 * bw, height: 60))
        b.fill(body, with: shade(CGPoint(x: 38, y: 54), CGPoint(x: 84, y: 108), light, coat, dark))
        lit(b, body, light.mix(RGB(255, 255, 255), 0.2), centre: CGPoint(x: 48, y: 66), radius: 24, alpha: 0.6)
        let breast = Path(ellipseIn: CGRect(x: 60 - 17.5, y: 66, width: 35, height: 43))
        b.fill(breast, with: .radialGradient(Gradient(colors: [belly.mix(RGB(255, 255, 255), 0.3).color(), belly.color(), belly.shifted(-10, 3).color()]),
                                             center: CGPoint(x: 55, y: 78), startRadius: 0, endRadius: 28))
        var chevrons = Path()
        for (row, y) in [74.0, 82, 90, 98].enumerated() {
            for x in stride(from: row.isMultiple(of: 2) ? -9.0 : -4.5, through: 9, by: 9) {
                chevrons.move(to: CGPoint(x: 60 + x - 3.4, y: y - 2.4))
                chevrons.addQuadCurve(to: CGPoint(x: 60 + x, y: y + 1.6), control: CGPoint(x: 60 + x - 2.4, y: y + 1.2))
                chevrons.addQuadCurve(to: CGPoint(x: 60 + x + 3.4, y: y - 2.4), control: CGPoint(x: 60 + x + 2.4, y: y + 1.2))
            }
        }
        b.stroke(chevrons, with: .color(mark.color(0.55)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))

        // The wings, folded at its sides: they lift when it is bright, hang when it is tired, and open a little on a hop.
        let flap = hop.flatMap { $0 < 0.66 ? abs(sin($0 / 0.22 * .pi)) * 0.55 : nil } ?? 0
        for s in [-1.0, 1] {
            var w = b
            w.translateBy(x: 60 + s * 23, y: 64)
            w.rotate(by: .radians(s * (0.1 * slump - 0.1 * Ink.smooth((frame.mood - 0.82) / 0.18) - flap)))
            var wing = Path()
            wing.leaf(0, 0, s * 0.16, 0.99, 42, 12.5, 0.35)
            w.fill(wing, with: shade(CGPoint(x: -10, y: 0), CGPoint(x: 12, y: 40), coat, dark, dark.shifted(-6)))
            var feathers = Path()
            for (i, y) in [16.0, 26, 35].enumerated() {
                feathers.move(to: CGPoint(x: s * (2 + Double(i)) - 5, y: y))
                feathers.addQuadCurve(to: CGPoint(x: s * (2 + Double(i)) + 5, y: y + 1), control: CGPoint(x: s * (2 + Double(i)), y: y + 4))
            }
            w.stroke(feathers, with: .color(light.color(0.5)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            w.fill(Path(ellipseIn: CGRect(x: -4, y: 2, width: 5, height: 14)), with: .color(light.color(0.3)))
        }

        var h = b
        h.translateBy(x: 60, y: 70)
        h.rotate(by: .radians(slump * 0.12))
        h.translateBy(x: -60, y: -70)
        perchedHead(h, babyness: babyness)
        PetMotion(frame: frame, stage: stage, hop: hop, wiggle: wiggle, waking: waking).nightcap(b)
    }

    /// The owl's head: tufts, a wide head, two pale discs with big eyes
    /// and the beak between them.
    private func perchedHead(_ c: GraphicsContext, babyness: Double, drop: Double = 0) {
        var h = c
        // A hatchling's head sits low, in the shell.
        h.translateBy(x: 0, y: drop)
        let coat = tone(plan.coat), light = tone(plan.light), dark = tone(plan.shade), belly = tone(plan.belly), mark = tone(plan.mark)
        let accent = tone(plan.accent)
        let w = 27 * plan.headWidth * (1 + babyness * 0.12)
        let perk = Ink.smooth((frame.mood - 0.7) / 0.28)
        // Ear tufts: two feathers standing out from the top of the head.
        for s in [-1.0, 1] {
            var tuft = Path()
            let a = -Double.pi / 2 + s * (0.6 + 0.4 * slump - 0.1 * perk)
            tuft.leaf(60 + s * 17, 35, cos(a), sin(a), 15 * plan.earHeight, 5.4, 0.2)
            h.fill(tuft, with: shade(CGPoint(x: 60 + s * 17 - 6, y: 20), CGPoint(x: 60 + s * 17 + 6, y: 36), light, coat, dark))
            var line = Path()
            line.move(to: CGPoint(x: 60 + s * 17, y: 34))
            line.addLine(to: CGPoint(x: 60 + s * 17 + cos(a) * 10, y: 35 + sin(a) * 10))
            h.stroke(line, with: .color(mark.color(0.6)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        let head = Path(ellipseIn: CGRect(x: 60 - w, y: 28, width: w * 2, height: 44))
        h.fill(head, with: .radialGradient(Gradient(colors: [light.color(), coat.color(), dark.color()]),
                                           center: CGPoint(x: 50, y: 38), startRadius: 0, endRadius: w * 1.3))
        // The facial discs: pale, ringed.
        for s in [-1.0, 1] {
            let centre = CGPoint(x: 60 + s * 11.5, y: 51)
            let disc = Path(ellipseIn: CGRect(x: centre.x - 13.5, y: centre.y - 14, width: 27, height: 28))
            h.fill(disc, with: .radialGradient(Gradient(colors: [belly.mix(RGB(255, 255, 255), 0.35).color(), belly.color(), belly.shifted(-12, 4).color()]),
                                               center: CGPoint(x: centre.x - 3, y: centre.y - 4), startRadius: 0, endRadius: 16))
            h.stroke(disc, with: .color(mark.color(0.4)), lineWidth: 1.2)
            // The brow: a dark feather over each eye.
            var brow = Path()
            let ba = s > 0 ? -0.5 : -Double.pi + 0.5
            brow.leaf(60 + s * 3, 40, cos(ba), sin(ba), 18, 3.2, 0.2)
            h.fill(brow, with: .color(dark.color(0.7)))
            owlEye(h, at: centre, bright: frame.mood > 0.82)
        }
        // The beak: small, hooked, between the eyes.
        var beak = Path.smooth([CGPoint(x: 56.6, y: 53.5), CGPoint(x: 60, y: 52.6), CGPoint(x: 63.4, y: 53.5), CGPoint(x: 60, y: 62)])
        beak.closeSubpath()
        h.fill(beak, with: shade(CGPoint(x: 57, y: 53), CGPoint(x: 62, y: 62), accent.mix(RGB(255, 255, 255), 0.3), accent, accent.shifted(-14, 4)))
        h.fill(Path(ellipseIn: CGRect(x: 58, y: 54, width: 1.8, height: 3)), with: .color(Color.white.opacity(0.45)))
        let blush = Ink.lerp(0.18, 0.8, Ink.smooth((frame.mood - 0.3) / 0.7))
        for s in [-1.0, 1] { h.circle(60 + s * 22, 61, 3, .color(tone(0xFF8FA3).color(blush))) }
    }

    /// A big round eye: a gold ring, a dark pupil that opens wide when it is
    /// bright, a highlight, and a lid that comes down as the house goes quiet.
    private func owlEye(_ c: GraphicsContext, at p: CGPoint, bright: Bool) {
        let ink = Color(hex: "2A1D0E")
        if motion.eyesClosed, waking == nil {
            var lid = Path()
            lid.move(to: CGPoint(x: p.x - 6, y: p.y))
            lid.addQuadCurve(to: CGPoint(x: p.x + 6, y: p.y), control: CGPoint(x: p.x, y: p.y + 5.4))
            c.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            return
        }
        var e = c
        e.translateBy(x: p.x, y: p.y)
        e.scaleBy(x: 1, y: motion.blink())
        let gold = tone(0xFFC53D, dim: 0.35)
        e.circle(0, 0, 7.4, .color(gold.shifted(-10).color()))
        e.circle(0, 0, 6.4, .radialGradient(Gradient(colors: [gold.mix(RGB(255, 255, 255), 0.25).color(), gold.color()]),
                                            center: CGPoint(x: -1.5, y: -2), startRadius: 0, endRadius: 7))
        e.circle(0, 0, bright ? 4.6 : 3.9, .color(ink))
        e.circle(2, -2.2, bright ? 1.9 : 1.5, .color(.white))
        if bright { e.circle(-1.8, 1.8, 0.9, .color(.white)) }
        // Tiredness: a lid of the face's colour over the top of the eye.
        let lid = Ink.smooth((0.62 - frame.mood) / 0.3) * 0.5
        if lid > 0.02 {
            e.clip(to: Path(ellipseIn: CGRect(x: -7.4, y: -7.4, width: 14.8, height: 14.8)))
            e.fill(Path(CGRect(x: -8, y: -8, width: 16, height: 16 * lid * 1.2)), with: .color(tone(plan.belly).shifted(-4).color()))
        }
    }
}
