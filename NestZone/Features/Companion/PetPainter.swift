import SwiftUI

/// The duckling, drawn from five parts — body, head, wing, eye, beak — the way
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

    private static let scales = [1.0, 1, 0.82, 0.62, 0.74, 0.86, 1]

    private var time: Double { frame.reduceMotion ? 0 : frame.time }
    /// 0 when fast asleep, 1 when fully awake and bright.
    private var awake: Double { Ink.smooth((frame.mood - 0.15) / 0.5) }
    private var eyesClosed: Bool { frame.mood < 0.42 }

    /// Draws the duck standing on the floor at `x`, `size` points tall.
    func draw(_ context: GraphicsContext, x: Double, floor: Double, size: Double) {
        var c = context
        let k = size / 120
        c.translateBy(x: x - 60 * k, y: floor - 108 * k)
        c.scaleBy(x: k, y: k)
        shadow(c)
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

    /// Offsets, scale and turn for this instant: the idle bob, and any hop,
    /// wiggle or stretch under way.
    private func motion() -> (Double, Double, Double, Double, Double) {
        var dy = 0.0, dx = 0.0, sx = 1.0, sy = 1.0, turn = 0.0
        if !frame.reduceMotion {
            if frame.mood > 0.82 {
                // Bright: a bouncy little idle.
                let t = (time / 1.1).truncatingRemainder(dividingBy: 1)
                dy = -7 * max(0, sin(t * .pi))
                sx = 1 + 0.02 * sin(t * .pi * 2)
                sy = 1 - 0.02 * sin(t * .pi * 2)
            } else if frame.mood < 0.15 {
                // Dozing: slow breathing.
                let b = sin(time / 5 * .pi * 2)
                sx = 1 + 0.02 * b; sy = 1 - 0.02 * b
            } else {
                let period = frame.mood < 0.42 ? 4.0 : 2.2
                dy = -2.5 * (0.5 - 0.5 * cos(time / period * .pi * 2))
            }
            if stage == 1 { turn = sin(time / 1.3 * .pi * 2) * 0.16 }
        }
        if let hop, hop < 0.65 {
            let t = hop / 0.65
            if t < 0.2 { dy += 2 * t / 0.2; sx *= 1 + 0.08 * t / 0.2; sy *= 1 - 0.1 * t / 0.2 }
            else if t < 0.5 { let u = (t - 0.2) / 0.3; dy += Ink.lerp(2, -18, Ink.ease(u)); sx *= Ink.lerp(1.08, 0.95, u); sy *= Ink.lerp(0.9, 1.06, u) }
            else if t < 0.8 { let u = (t - 0.5) / 0.3; dy += Ink.lerp(-18, 0, u * u); sx *= Ink.lerp(0.95, 1.05, u); sy *= Ink.lerp(1.06, 0.95, u) }
            else { let u = (t - 0.8) / 0.2; sx *= Ink.lerp(1.05, 1, u); sy *= Ink.lerp(0.95, 1, u) }
        }
        if let wiggle, wiggle < 0.6 { turn += sin(wiggle / 0.6 * .pi * 2) * 0.1 }
        if let waking {
            // Waking up: a long stretch, then a shake.
            if waking > 0.4, waking < 0.9 {
                let u = sin((waking - 0.4) / 0.5 * .pi)
                sy *= 1 + 0.14 * u; sx *= 1 - 0.08 * u
            }
            if waking > 0.9, waking < 1.4 { turn += sin((waking - 0.9) / 0.5 * .pi * 4) * 0.12 }
        }
        return (dx, dy, sx, sy, turn)
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
    private static let cap = Color(hex: "7C8BE8")

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
        h.rotate(by: .radians((1 - awake) * 0.21))
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
        e.ellipse(42, 47, bright ? 3.8 : 3.2, bright ? 4.8 : 4.2, .color(Self.ink))
        e.circle(bright ? 43.3 : 43, bright ? 45.2 : 45.5, bright ? 1.6 : 1.2, .color(.white))
        if bright { e.circle(40.6, 49, 0.8, .color(.white)) }
    }

    /// Worn while dozing; it flies off as the duck wakes.
    private func nightcap(_ c: GraphicsContext) {
        let shown = frame.mood < 0.15 || frame.domeLift > 0
        guard shown, stage >= 2 else { return }
        var cap = c
        let off = frame.domeLift
        cap.opacity = 1 - off
        cap.translateBy(x: 30 * off, y: -60 * off)
        cap.translateBy(x: 50, y: 30)
        cap.rotate(by: .radians(off * 1.1))
        cap.translateBy(x: -50, y: -30)
        var shape = Path()
        shape.move(to: CGPoint(x: 29, y: 41))
        shape.addQuadCurve(to: CGPoint(x: 62, y: 38), control: CGPoint(x: 43, y: 27))
        shape.addQuadCurve(to: CGPoint(x: 72, y: 18), control: CGPoint(x: 61, y: 24))
        shape.addQuadCurve(to: CGPoint(x: 47, y: 25), control: CGPoint(x: 55, y: 16))
        shape.addQuadCurve(to: CGPoint(x: 29, y: 41), control: CGPoint(x: 37, y: 29))
        shape.closeSubpath()
        cap.fill(shape, with: .color(Self.cap))
        var band = Path()
        band.move(to: CGPoint(x: 29, y: 41))
        band.addQuadCurve(to: CGPoint(x: 62, y: 38), control: CGPoint(x: 45, y: 33))
        cap.stroke(band, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        cap.circle(72, 18, 4, .color(.white))
    }
}
