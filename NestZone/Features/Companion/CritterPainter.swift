import SwiftUI

/// A pet on one of two body plans (`CritterPlan`), in the duckling's 120-unit
/// box with its feet at (60, 108): the same stages, the same motion
/// (`PetMotion`), the same moods, and the gouache of the plants. Every part is
/// a form with one light (`CritterLook`, the sky's sun or moon, as the trees
/// have it), a thin rim of that light on its lit edge, a cool shadow on the
/// other, and fur that breaks the outline in small leaf-shaped dabs. No
/// outlines. `Docs/Companion/art/RULES-pets.md` is the rulebook.
///
/// Like the duckling it is drawn whole every frame, so what it spends is
/// kept down: the shapes are built once per plan (`CritterGeometry`) and only
/// filled here, and only the parts that act (tail, ears, eyes, whiskers)
/// are worked out per frame. The plan decides which body is built (`sitter`,
/// `perched`) and with what; nothing here is a species.
struct CritterPainter {
    typealias RGB = Canopy.RGB

    let plan: CritterPlan
    let frame: SceneFrame
    /// 0–6: egg or bundle, wobbling, hatchling, baby, little one, young, grown.
    let stage: Int
    let hop: Double?
    let wiggle: Double?
    let waking: Double?

    let motion: PetMotion
    let look: CritterLook

    init(plan: CritterPlan, frame: SceneFrame, stage: Int, hop: Double?, wiggle: Double?, waking: Double?) {
        self.plan = plan; self.frame = frame; self.stage = stage
        self.hop = hop; self.wiggle = wiggle; self.waking = waking
        motion = PetMotion(frame: frame, stage: stage, hop: hop, wiggle: wiggle, waking: waking)
        look = CritterLook(plan: plan, frame: frame, slump: 1 - motion.awake)
    }

    var time: Double { motion.time }
    var slump: Double { look.slump }
    /// How much the bowl is out, 0 to 1: only while it is thirsty.
    var thirst: Double { motion.weights.thirst }

    /// Draws the pet standing on the floor at `x`, `size` points tall.
    func draw(_ context: GraphicsContext, x: Double, floor: Double, size: Double) {
        PetTiming.measure(plan.body == .sitter ? "critter" : plan.body == .waddler ? "duckling" : "bird") { paint(context, x: x, floor: floor, size: size) }
    }

    private func paint(_ context: GraphicsContext, x: Double, floor: Double, size: Double) {
        var c = context
        let k = size / 120
        c.translateBy(x: x - 60 * k, y: floor - 108 * k)
        c.scaleBy(x: k, y: k)
        let scale = stage < 2 ? 1 : PetMotion.scales[stage]
        var ground = c
        ground.translateBy(x: 60, y: 108)
        ground.scaleBy(x: scale, y: scale)
        ground.translateBy(x: -60, y: -108)
        shadow(ground)
        if stage >= 3, thirst > 0.02 { bowl(ground) }
        var body = c
        // Everything moves about the feet.
        body.translateBy(x: 60, y: 108)
        let (dx, dy, sx, sy, turn) = motion.offsets(calm: plan.body != .waddler)
        body.translateBy(x: dx, y: dy)
        body.rotate(by: .radians(turn))
        body.scaleBy(x: sx, y: sy)
        body.translateBy(x: -60, y: -108)
        if stage < 2 { wrapped(body); return }
        body.translateBy(x: 60, y: 108)
        body.scaleBy(x: scale, y: scale)
        body.translateBy(x: -60, y: -108)
        if stage == 2 { hatchling(body); return }
        switch plan.body {
        case .sitter: sitter(body)
        case .perched: perched(body)
        case .waddler: waddler(body)
        }
    }

    /// Where a hat sits and where a bow or scarf is tied, in the box, for
    /// this stage: the head's top between the ears, and under the chin.
    static func wearing(_ plan: CritterPlan, stage: Int) -> (top: CGPoint, neck: CGPoint) {
        var top = plan.body == .sitter ? CGPoint(x: 47, y: 31) : plan.body == .waddler ? CGPoint(x: 46, y: 33) : CGPoint(x: 60, y: 33)
        var neck = plan.body == .sitter ? CGPoint(x: 47, y: 67) : plan.body == .waddler ? CGPoint(x: 47, y: 70) : CGPoint(x: 60, y: 72)
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

    // MARK: Brushes

    /// A shade across a part, light to dark along the light.
    func ramp(_ centre: CGPoint, _ r: Double, _ light: RGB, _ mid: RGB, _ dark: RGB, L override: CGPoint? = nil) -> GraphicsContext.Shading {
        let L = override ?? look.L
        return .linearGradient(Gradient(stops: [.init(color: light.color(), location: 0), .init(color: mid.color(), location: 0.5),
                                                .init(color: dark.color(), location: 1)]),
                               startPoint: CGPoint(x: centre.x + L.x * r, y: centre.y + L.y * r),
                               endPoint: CGPoint(x: centre.x - L.x * r, y: centre.y - L.y * r))
    }

    func glow(_ c: GraphicsContext, _ path: Path, _ colour: RGB, centre: CGPoint, radius: Double, alpha: Double) {
        c.fill(path, with: .radialGradient(Gradient(colors: [colour.color(alpha), colour.color(0)]), center: centre, startRadius: 0, endRadius: radius))
    }

    /// A round form: a rim of the light on its lit edge, a ramp along the
    /// light, a cool shadow on the far side, and a soft highlight towards
    /// the light.
    func form(_ c: GraphicsContext, _ path: Path, centre: CGPoint, radius r: Double, _ light: RGB, _ mid: RGB, _ dark: RGB,
              highlight: Double = 0.55, core: Double = 1, rim: Bool = true, L override: CGPoint? = nil) {
        let L = override ?? look.L
        if rim, look.rimAlpha > 0.03 {
            // The shifted copy is the context moved, not the path copied.
            var r = c
            r.translateBy(x: L.x * 0.9, y: L.y * 0.9)
            r.fill(path, with: .color(look.rim.color(look.rimAlpha)))
        }
        c.fill(path, with: ramp(centre, r, light, mid, dark, L: L))
        if core > 0 {
            glow(c, path, look.cool, centre: CGPoint(x: centre.x - L.x * r * 0.7, y: centre.y - L.y * r * 0.7), radius: r * 1.1, alpha: look.coolAlpha * core)
        }
        if highlight > 0 {
            glow(c, path, look.lifted(light, 0.35), centre: CGPoint(x: centre.x + L.x * r * 0.42, y: centre.y + L.y * r * 0.42), radius: r * 0.8, alpha: highlight)
        }
    }

    /// A path drawn twice, the second a hair towards the light: fur that has
    /// a lit edge, in two fills instead of one per hair.
    func hairs(_ c: GraphicsContext, _ path: Path, dark: RGB, light: RGB, alpha: Double = 0.35) {
        let L = look.L
        var lit = c
        lit.translateBy(x: L.x * 0.7, y: L.y * 0.7)
        lit.fill(path, with: .color(light.color(alpha * 1.2)))
        c.fill(path, with: .color(dark.color(alpha)))
    }

    private func shadow(_ c: GraphicsContext) {
        let wide = plan.body == .sitter ? 38.0 : plan.body == .waddler ? 35 : 30
        let L = look.L
        let lean = -L.x * 5
        let w = stage < 2 ? 24.0 : wide
        let h = 5.0
        // A wide soft pool away from the light, and a tight dark one right
        // under the weight.
        c.ellipse(60 + lean, 108.4, w * 1.08, h + 1.2, .color(SceneInk.shadow.opacity(0.55)))
        c.ellipse(60 + lean * 0.4, 108.2, w * 0.82, h * 0.7, .color(SceneInk.shadow))
    }

    // MARK: The bowl

    /// A little empty bowl beside it, which is there only while it is
    /// thirsty: ceramic, a painted band, nothing in it but the last drop.
    func bowl(_ c: GraphicsContext) {
        var b = c
        let a = Ink.smooth(thirst / 0.6)
        b.opacity = a
        // It slides in as the mood arrives, never pops.
        b.translateBy(x: (1 - a) * -6, y: 0)
        let L = look.L
        let cx = 14.0, top = 99.6, bottom = 109.0
        let ceramic = look.tone(0xA9D5D2, dim: 0.5), band = look.tone(0x5FA8A6, dim: 0.5), inner = look.tone(0x7F9FA6, dim: 0.5)
        b.ellipse(cx - L.x * 3, bottom - 0.4, 17, 3.2, .color(SceneInk.shadow))
        var shape = Path()
        shape.move(to: CGPoint(x: cx - 14, y: top))
        shape.addQuadCurve(to: CGPoint(x: cx - 8, y: bottom), control: CGPoint(x: cx - 13.5, y: bottom - 1.5))
        shape.addLine(to: CGPoint(x: cx + 8, y: bottom))
        shape.addQuadCurve(to: CGPoint(x: cx + 14, y: top), control: CGPoint(x: cx + 13.5, y: bottom - 1.5))
        shape.closeSubpath()
        form(b, shape, centre: CGPoint(x: cx, y: 104.5), radius: 14, look.lifted(ceramic, 0.3), ceramic, ceramic.shifted(-14, -6), highlight: 0.35)
        var stripe = Path()
        stripe.move(to: CGPoint(x: cx - 12, y: 103.2))
        stripe.addQuadCurve(to: CGPoint(x: cx + 12, y: 103.2), control: CGPoint(x: cx, y: 106.4))
        b.stroke(stripe, with: .color(band.color(0.9)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        // The mouth of the bowl: a rim, and the dry inside.
        let mouth = Path(ellipseIn: CGRect(x: cx - 14.4, y: top - 2.7, width: 28.8, height: 5.8))
        b.fill(mouth, with: .color(look.lifted(ceramic, 0.45).color()))
        b.fill(Path(ellipseIn: CGRect(x: cx - 12.4, y: top - 1.8, width: 24.8, height: 4.2)), with: .linearGradient(
            Gradient(colors: [inner.shifted(-12).color(), inner.color()]), startPoint: CGPoint(x: cx, y: top - 1.7), endPoint: CGPoint(x: cx, y: top + 2)))
        // The last drop, and where the water was.
        b.ellipse(cx + 2.4, top + 0.6, 1.5, 0.7, .color(Color(hex: "BFE6FF").opacity(0.95)))
        b.ellipse(cx + 2.9, top + 0.3, 0.45, 0.25, .color(.white))
        b.stroke(Path(ellipseIn: CGRect(x: cx - 6, y: top - 0.8, width: 12, height: 2.2)), with: .color(inner.shifted(-20).color(0.35)), lineWidth: 0.5)
        // The lit rim, on the side of the sun.
        let side = L.x > 0 ? 1.0 : -1.0
        var rimLight = Path()
        rimLight.move(to: CGPoint(x: cx + 12 * side, y: top - 0.2))
        rimLight.addQuadCurve(to: CGPoint(x: cx + 3 * side, y: top - 2.5), control: CGPoint(x: cx + 9 * side, y: top - 2.8))
        b.stroke(rimLight, with: .color(Color.white.opacity(0.7)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    // MARK: Before it is a pet

    /// The bundle or the egg it starts as: a knitted blanket tied at the top
    /// for a mammal, a speckled egg for a bird. The wobbly one has ears and a
    /// face looking out, or a crack.
    private func wrapped(_ c: GraphicsContext) {
        let wrap = look.tone(plan.wrap, dim: 0.7)
        let L = look.L
        if plan.origin == .egg {
            let egg = Path(ellipseIn: CGRect(x: 36, y: 40, width: 48, height: 64))
            form(c, egg, centre: CGPoint(x: 60, y: 72), radius: 32, wrap.mix(RGB(255, 255, 255), 0.35), wrap, wrap.shifted(-13, 6), highlight: 0.4)
            var speckles = Path()
            for (x, y, r) in [(50.0, 60.0, 1.8), (66, 52, 1.4), (70, 70, 2.0), (54, 82, 1.6), (62, 94, 1.5), (46, 72, 1.2), (74, 86, 1.3), (60, 66, 1.1)] {
                speckles.addEllipse(in: CGRect(x: x - r, y: y - r * 0.8, width: r * 2, height: r * 1.6))
            }
            c.fill(speckles, with: .color(look.tone(plan.mark, dim: 0.7).color(0.55)))
            c.ellipse(60 + L.x * 9, 60 + L.y * 8, 5, 9, .color(Color.white.opacity(0.55)))
            if stage == 1 {
                var crack = Path()
                crack.move(to: CGPoint(x: 44, y: 66))
                for point in [(50.0, 71.0), (55, 65), (61, 71), (67, 66)] { crack.addLine(to: CGPoint(x: point.0, y: point.1)) }
                c.stroke(crack, with: .color(look.tone(0xD9C39A, dim: 0.7).color()), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            return
        }
        // A bundle: a soft dome, the knit in rows of stitches, a knot at the top.
        let dome = CritterGeometry.bundle.dome
        let peek = stage >= 1
        if peek { peeking(c, behind: true) }
        form(c, dome, centre: CGPoint(x: 60, y: 82), radius: 34, wrap.mix(RGB(255, 255, 255), 0.4), wrap, wrap.shifted(-15, 8), highlight: 0.4)
        let knit = CritterGeometry.bundle.knit
        var knitLit = c
        knitLit.translateBy(x: L.x * 0.6, y: L.y * 0.6)
        knitLit.stroke(knit, with: .color(wrap.mix(RGB(255, 255, 255), 0.55).color(0.5)), style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
        c.stroke(knit, with: .color(wrap.shifted(-18, 8).color(0.55)), style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
        // The cuff, where the blanket was turned over.
        c.stroke(CritterGeometry.bundle.cuff, with: .color(wrap.shifted(-14, 6).color(0.5)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        if peek { peeking(c, behind: false) }
        // The knot, like two bunny ears of cloth, and a little tassel.
        let knotShade = wrap.shifted(-8, 4)
        var knot = Path()
        knot.move(to: CGPoint(x: 60, y: 54))
        knot.addQuadCurve(to: CGPoint(x: 47, y: 41), control: CGPoint(x: 48, y: 54))
        knot.addQuadCurve(to: CGPoint(x: 58, y: 50), control: CGPoint(x: 55, y: 39))
        knot.move(to: CGPoint(x: 60, y: 54))
        knot.addQuadCurve(to: CGPoint(x: 73, y: 42), control: CGPoint(x: 72, y: 55))
        knot.addQuadCurve(to: CGPoint(x: 62, y: 50), control: CGPoint(x: 65, y: 40))
        c.fill(knot.offsetBy(dx: L.x * 0.8, dy: L.y * 0.8), with: .color(look.rim.color(look.rimAlpha * 0.8)))
        c.fill(knot, with: .linearGradient(Gradient(colors: [wrap.mix(RGB(255, 255, 255), 0.25).color(), knotShade.color()]),
                                            startPoint: CGPoint(x: 52, y: 40), endPoint: CGPoint(x: 68, y: 54)))
        c.circle(60, 53.4, 3.5, .radialGradient(Gradient(colors: [wrap.shifted(-4, 4).color(), wrap.shifted(-16, 6).color()]),
                                                  center: CGPoint(x: 59, y: 52), startRadius: 0, endRadius: 4))
        c.stroke(CritterGeometry.bundle.tassel, with: .color(wrap.shifted(-12, 6).color(0.8)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
    }

    /// What looks out of the bundle once it wobbles: a dark gap at the top
    /// of the dome with two eyes and a pink nose in it, and the ears over the
    /// edge. Drawn in two parts, the ears behind the dome and the face in
    /// front of it.
    private func peeking(_ c: GraphicsContext, behind: Bool) {
        let coat = look.coat, light = look.light
        if behind {
            for s in [-1.0, 1] {
                var e = c
                e.translateBy(x: 60 + s * 15, y: 53)
                e.rotate(by: .radians(s * (0.28 + 0.2 * slump)))
                e.scaleBy(x: s, y: 1)
                let g = CritterGeometry.head(plan)
                form(e, g.ear.applying(.init(scaleX: 0.9, y: 0.9)), centre: CGPoint(x: 0, y: -8), radius: 12, light, coat, look.dark, highlight: 0.3, core: 0.6)
                e.fill(g.earInner.applying(.init(scaleX: 0.9, y: 0.9)), with: .color(look.accent.color()))
            }
            return
        }
        // The gap, deep in shadow.
        let wrap = look.tone(plan.wrap, dim: 0.7)
        let gap = Path(ellipseIn: CGRect(x: 44, y: 55, width: 32, height: 17))
        c.fill(gap, with: .radialGradient(Gradient(colors: [wrap.shifted(-34, 8).color(), wrap.shifted(-26, 8).color()]),
                                           center: CGPoint(x: 60, y: 64), startRadius: 0, endRadius: 18))
        var f = c
        f.translateBy(x: 60, y: 64.5)
        f.scaleBy(x: 0.62, y: 0.62)
        for s in [-1.0, 1] { eye(f, at: CGPoint(x: s * 9.6, y: -1.5), side: s, rx: 4.35, ry: 5.0, gaze: CGPoint(x: 0, y: 0.1), droop: 0) }
        let g = CritterGeometry.head(plan)
        f.fill(g.nose.offsetBy(dx: 0, dy: 4), with: .color(look.nose.color()))
        // The lip of the gap, a roll of knit over the eyes.
        var lip = Path()
        lip.move(to: CGPoint(x: 43.5, y: 63))
        lip.addQuadCurve(to: CGPoint(x: 76.5, y: 63), control: CGPoint(x: 60, y: 51))
        c.stroke(lip, with: .color(wrap.shifted(6, 3).color()), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
        c.stroke(lip, with: .color(wrap.mix(RGB(255, 255, 255), 0.4).color(0.6)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    }

    /// The head out of its wrapping: the egg's cracked shell, or the blanket
    /// folded back round it, with two little paws over the edge.
    private func hatchling(_ c: GraphicsContext) {
        var h = c
        h.translateBy(x: plan.body == .perched ? 0 : 14, y: plan.body == .perched ? 0 : 34)
        switch plan.body {
        case .sitter: sitterHead(h, babyness: 1, local: false)
        case .perched: perchedHead(h, babyness: 1, drop: 18)
        case .waddler: duckHead(h, babyness: 1)
        }
        let wrap = look.tone(plan.wrap, dim: 0.7)
        let L = look.L
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
        form(c, edge, centre: CGPoint(x: 60, y: 94), radius: 34, wrap.mix(RGB(255, 255, 255), 0.38), wrap, wrap.shifted(-15, 6), highlight: 0.3)
        c.fill(Path(ellipseIn: CGRect(x: 36 + L.x * 3, y: 80, width: 14, height: 5)), with: .color(Color.white.opacity(0.22)))
        if plan.origin == .blanket {
            c.stroke(CritterGeometry.bundle.hatchlingKnit, with: .color(wrap.shifted(-18, 8).color(0.5)), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            // Two paws over the fold.
            for s in [-1.0, 1] {
                let paw = Path(ellipseIn: CGRect(x: 60 + s * 17 - 5.5, y: 80.5, width: 11, height: 7.4))
                form(c, paw, centre: CGPoint(x: 60 + s * 17, y: 84), radius: 6, look.lifted(look.belly, 0.2), look.belly, look.belly.shifted(-10, 3), highlight: 0.4, core: 0.5)
                var toes = Path()
                for dx in [-1.8, 1.8] { toes.move(to: CGPoint(x: 60 + s * 17 + dx, y: 84.6)); toes.addLine(to: CGPoint(x: 60 + s * 17 + dx, y: 87.4)) }
                c.stroke(toes, with: .color(look.dark.color(0.4)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
            }
        }
    }
}

/// The bundle's knit and fold, built once: it is the same for every mammal.
struct BundleGeometry {
    let dome, knit, cuff, tassel, hatchlingKnit: Path

    init() {
        dome = .loop([CGPoint(x: 34, y: 106), CGPoint(x: 30, y: 82), CGPoint(x: 42, y: 56), CGPoint(x: 60, y: 50), CGPoint(x: 78, y: 56),
                      CGPoint(x: 90, y: 82), CGPoint(x: 86, y: 106), CGPoint(x: 60, y: 111)])
        // Rows of small stitches, each a "V", the rows sagging at the sides
        // the way a knit over a round thing does.
        var k = Path()
        var row = 0
        for y in stride(from: 70.0, through: 106, by: 5.6) {
            let half = (y <= 82 ? 14 + (y - 56) * 0.6 : 30 - (y - 82) * 0.2) - 3
            var x = 60 - half + (row.isMultiple(of: 2) ? 0 : 2.6)
            while x < 60 + half - 2 {
                let dy = pow((x - 60) / half, 2) * 2.4
                k.move(to: CGPoint(x: x, y: y + dy - 1.8))
                k.addLine(to: CGPoint(x: x + 1.5, y: y + dy + 0.2))
                k.addLine(to: CGPoint(x: x + 3.0, y: y + dy - 1.8))
                x += 5.2
            }
            row += 1
        }
        knit = k
        var cf = Path()
        cf.move(to: CGPoint(x: 38.5, y: 67))
        cf.addQuadCurve(to: CGPoint(x: 81.5, y: 67), control: CGPoint(x: 60, y: 75))
        cuff = cf
        var t = Path()
        t.move(to: CGPoint(x: 60, y: 56))
        t.addQuadCurve(to: CGPoint(x: 64, y: 70), control: CGPoint(x: 66, y: 62))
        tassel = t
        var hk = Path()
        var r = 0
        for y in stride(from: 90.0, through: 106, by: 5.6) {
            var x = 34 + (r.isMultiple(of: 2) ? 0 : 2.6)
            while x < 86 {
                hk.move(to: CGPoint(x: x, y: y - 1.6))
                hk.addLine(to: CGPoint(x: x + 1.4, y: y + 0.1))
                hk.addLine(to: CGPoint(x: x + 2.8, y: y - 1.6))
                x += 5.2
            }
            r += 1
        }
        hatchlingKnit = hk
    }
}

extension CritterGeometry {
    static let bundle = BundleGeometry()
}
