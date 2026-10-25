import SwiftUI

/// The duckling's old, flat painter, kept so `-ducklingLegacy 1` (Debug) can
/// draw it beside the new one (`CritterPainter+Duck`, body plan `waddler`),
/// which is what the app draws. It was drawn from five parts — body, head, wing, eye, beak — the way
/// a pet is built without an animation tool: the parts are drawn once and
/// code moves them. It shares the plant's seven-stage growth and its moods:
/// a bright duck bounces with sparkly eyes, a sleepy one fades and droops,
/// and a dozing one wears a nightcap until somebody wakes it.
///
/// Coordinates are the prototype's 120-unit box (Docs/Companion/prototype/
/// duck.js), with the duck's shadow at (60, 108).
struct PetPainter {
    let frame: SceneFrame
    /// 0–6: egg, wobbly egg, hatchling, baby, little one, young, grown.
    let stage: Int
    /// Seconds since the last hop, wiggle or wake-up began; `nil` if none.
    let hop: Double?
    let wiggle: Double?
    /// Seconds into waking up, for the stretch and the shake.
    let waking: Double?

    private static let scales = PetMotion.scales

    private var time: Double { frame.reduceMotion ? 0 : frame.time }
    /// 0 when fast asleep, 1 when fully awake and bright.
    private var awake: Double { Ink.smooth((frame.mood - 0.15) / 0.5) }
    private var pm: PetMotion { PetMotion(frame: frame, stage: stage, hop: hop, wiggle: wiggle, waking: waking) }
    /// Shut only when properly asleep: a thirsty duck is awake and wanting.
    private var eyesClosed: Bool { pm.sleep > 0.5 }

    /// Draws the duck standing on the floor at `x`, `size` points tall.
    func draw(_ context: GraphicsContext, x: Double, floor: Double, size: Double) {
        PetTiming.measure("duckling") { paint(context, x: x, floor: floor, size: size) }
    }

    private func paint(_ context: GraphicsContext, x: Double, floor: Double, size: Double) {
        var c = context
        let k = size / 120
        c.translateBy(x: x - 60 * k, y: floor - 108 * k)
        c.scaleBy(x: k, y: k)
        shadow(c)
        // A thirsty duck has a little empty bowl beside it, the same one the
        // other pets have (drawn by `CritterPainter`, which owns it).
        if stage >= 3, pm.weights.thirst > 0.02, let plan = CritterPlan.of(.kitten) {
            var ground = c
            let scale = Self.scales[stage]
            ground.translateBy(x: 60, y: 108)
            ground.scaleBy(x: scale, y: scale)
            ground.translateBy(x: -60, y: -108)
            CritterPainter(plan: plan, frame: frame, stage: stage, hop: nil, wiggle: nil, waking: nil).bowl(ground)
        }
        var body = c
        // Everything moves about the feet.
        body.translateBy(x: 60, y: 108)
        let (dx, dy, sx, sy, turn) = motion()
        body.translateBy(x: dx, y: dy)
        body.rotate(by: .radians(turn))
        body.scaleBy(x: sx, y: sy)
        body.translateBy(x: -60, y: -108)
        if stage < 2 { egg(body); return }
        let scale = Self.scales[stage]
        body.translateBy(x: 60, y: 108)
        body.scaleBy(x: scale, y: scale)
        body.translateBy(x: -60, y: -108)
        if stage == 2 { hatchling(body); return }
        duck(body)
    }

    // MARK: Motion

    /// Offsets, scale and turn for this instant, from `PetMotion`.
    private func motion() -> (Double, Double, Double, Double, Double) {
        let m = PetMotion(frame: frame, stage: stage, hop: hop, wiggle: wiggle, waking: waking).offsets()
        return (m.dx, m.dy, m.sx, m.sy, m.turn)
    }

    // MARK: Parts

    /// The body's yellow fades towards straw as the house goes quiet.
    private var body: Color { Ink.hsl(46, Ink.lerp(55, 100, awake), Ink.lerp(72, 64, awake)) }
    private var wing: Color { Ink.hsl(44, Ink.lerp(50, 90, awake), Ink.lerp(63, 56, awake)) }
    private static let beak = Color(hex: "FF9F43")
    private static let ink = Color(hex: "2A1D0E")
    private static let blush = Color(hex: "FF8FA3")
    private static let shell = Color(hex: "FFF3DC")
    private static let crack = Color(hex: "D9C39A")

    private func shadow(_ c: GraphicsContext) {
        let scale = stage < 2 ? 1 : Self.scales[stage]
        c.ellipse(60, 108, stage < 2 ? 22 : 32 * scale, stage < 2 ? 5 : 5 * scale + 1, .color(SceneInk.shadow))
    }

    private func egg(_ c: GraphicsContext) {
        c.ellipse(60, 72, 24, 32, .color(Self.shell.opacity(Ink.lerp(0.85, 1, awake))))
        c.ellipse(51, 60, 6, 10, .color(Color.white.opacity(0.7)))
        if stage == 1 {
            var crack = Path()
            crack.move(to: CGPoint(x: 44, y: 66))
            for point in [(50.0, 71.0), (55, 65), (61, 71), (67, 66)] { crack.addLine(to: CGPoint(x: point.0, y: point.1)) }
            c.stroke(crack, with: .color(Self.crack), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }

    private func hatchling(_ c: GraphicsContext) {
        var head = c
        head.translateBy(x: 14, y: 34)
        self.head(head)
        var shell = Path()
        shell.move(to: CGPoint(x: 30, y: 84))
        for point in [(37.0, 75.0), (44, 83), (52, 73), (60, 83), (68, 74), (75, 82), (83, 73), (90, 84), (90, 96)] {
            shell.addLine(to: CGPoint(x: point.0, y: point.1))
        }
        shell.addQuadCurve(to: CGPoint(x: 30, y: 96), control: CGPoint(x: 60, y: 126))
        shell.closeSubpath()
        c.fill(shell, with: .color(Self.shell))
    }

    private func duck(_ c: GraphicsContext) {
        var b = c
        let slump = 1 - awake
        // A sleepy duck sits lower and rounder.
        b.translateBy(x: 0, y: 4 * slump)
        b.translateBy(x: 60, y: 108)
        b.scaleBy(x: 1, y: 1 - 0.06 * slump)
        b.translateBy(x: -60, y: -108)
        b.ellipse(50, 105, 7, 3, .color(Self.beak))
        b.ellipse(72, 105, 7, 3, .color(Self.beak))
        b.ellipse(62, 80, 30, 24, .color(body))
        var tail = Path()
        tail.move(to: CGPoint(x: 89, y: 74))
        tail.addQuadCurve(to: CGPoint(x: 98, y: 78), control: CGPoint(x: 97, y: 72))
        tail.addQuadCurve(to: CGPoint(x: 89, y: 80), control: CGPoint(x: 93, y: 79))
        tail.closeSubpath()
        b.fill(tail, with: .color(wing))
        // The wing droops when sleepy, lifts when bright, and flaps on a hop.
        var w = b
        w.translateBy(x: 66, y: 78)
        var tilt = Ink.lerp(0.24, 0, awake) - max(0, frame.mood - 0.82) * 0.9
        if let hop, hop < 0.66 { tilt -= abs(sin(hop / 0.22 * .pi)) * 0.49 }
        w.rotate(by: .radians(tilt))
        w.translateBy(x: -66, y: -78)
        w.ellipse(70, 81, 14, 9, .color(wing))
        head(b)
        if stage == 6 {
            var scarf = Path()
            scarf.move(to: CGPoint(x: 33, y: 62))
            scarf.addQuadCurve(to: CGPoint(x: 59, y: 62), control: CGPoint(x: 46, y: 70))
            b.stroke(scarf, with: .color(Color.white.opacity(0.85)), lineWidth: 3)
        }
    }

    private func head(_ c: GraphicsContext) {
        var h = c
        // A sleepy head nods forward.
        h.translateBy(x: 46, y: 68)
        h.rotate(by: .radians(pm.by(0.21, -0.2, 0.06, 0)))
        h.translateBy(x: -46, y: -68)
        h.circle(46, 50, 19, .color(body))
        var tuft = Path()
        tuft.move(to: CGPoint(x: 45, y: 32))
        tuft.addQuadCurve(to: CGPoint(x: 55, y: 28), control: CGPoint(x: 48, y: 23))
        tuft.addQuadCurve(to: CGPoint(x: 48, y: 34), control: CGPoint(x: 49, y: 28))
        tuft.closeSubpath()
        h.fill(tuft, with: .color(wing))
        var beak = Path()
        beak.move(to: CGPoint(x: 29, y: 53))
        beak.addQuadCurve(to: CGPoint(x: 29, y: 61), control: CGPoint(x: 18, y: 56))
        beak.addQuadCurve(to: CGPoint(x: 38, y: 56), control: CGPoint(x: 37, y: 62))
        beak.closeSubpath()
        h.fill(beak, with: .color(Self.beak))
        // Wanting something: the beak a little open.
        let thirst = pm.weights.thirst
        if thirst > 0.05 {
            h.fill(Path(ellipseIn: CGRect(x: 23, y: 56.2, width: 9, height: 1.6)), with: .color(Self.ink.opacity(0.75 * thirst)))
        }
        eye(h)
        h.circle(51, 57, 3.4, .color(Self.blush.opacity(Ink.lerp(0.2, 0.95, Ink.smooth((frame.mood - 0.3) / 0.7)))))
        nightcap(h)
    }

    private func eye(_ c: GraphicsContext) {
        let blinkCycle = (time / 4.2).truncatingRemainder(dividingBy: 1)
        var blink = blinkCycle > 0.93 && blinkCycle < 0.99 ? 0.1 : 1.0
        // Waking: the eyes flutter open twice.
        if let waking, waking < 0.45 { blink = abs(cos(waking / 0.45 * .pi * 2)) * 0.9 + 0.1 }
        if eyesClosed, waking == nil {
            var lid = Path()
            lid.move(to: CGPoint(x: 38.5, y: 47))
            lid.addQuadCurve(to: CGPoint(x: 45.5, y: 47), control: CGPoint(x: 42, y: 50.5))
            c.stroke(lid, with: .color(Self.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            return
        }
        var e = c
        e.translateBy(x: 42, y: 47)
        e.scaleBy(x: 1, y: blink)
        e.translateBy(x: -42, y: -47)
        let bright = frame.mood > 0.82
        // Wanting something it looks at it: a ring of white round the eye, the
        // dark of it shifted toward the bowl, down and to the left.
        let thirst = pm.weights.thirst
        if thirst > 0.05 {
            e.ellipse(42, 47, 4.9, 5.4, .color(Color.white.opacity(0.95 * thirst)))
        }
        let gx = -1.5 * thirst, gy = 1.6 * thirst
        e.ellipse(42 + gx, 47 + gy, bright ? 3.8 : 3.2, bright ? 4.8 : 4.2, .color(Self.ink))
        e.circle((bright ? 43.3 : 43) + gx * 0.5, (bright ? 45.2 : 45.5) + gy * 0.5, bright ? 1.6 : 1.2, .color(.white))
        if bright { e.circle(40.6, 49, 0.8, .color(.white)) }
    }

    /// Worn while dozing; it flies off as the duck wakes.
    private func nightcap(_ c: GraphicsContext) {
        PetMotion(frame: frame, stage: stage, hop: hop, wiggle: wiggle, waking: waking).nightcap(c)
    }
}
