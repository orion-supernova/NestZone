import SwiftUI

/// How a pet moves, whatever it is: the idle bob, the hop when a chore lands
/// or a stage is reached, the wiggle after a pat, the stretch and the shake
/// of waking up, and the blink. The duckling's painter and every body plan
/// (`CritterPainter`) draw their own parts and let this move them, so a pet
/// feels the same however it is built.
struct PetMotion {
    let frame: SceneFrame
    /// 0–6: egg, wobbly egg, hatchling, baby, little one, young, grown.
    let stage: Int
    /// Seconds since the last hop, wiggle or wake-up began; `nil` if none.
    let hop: Double?
    let wiggle: Double?
    /// Seconds into waking up, for the stretch and the shake.
    let waking: Double?

    /// How big each stage stands against the grown pet.
    static let scales = [1.0, 1, 0.82, 0.62, 0.74, 0.86, 1]

    var time: Double { frame.reduceMotion ? 0 : frame.time }
    /// 0 when fast asleep, 1 when fully awake and bright.
    var awake: Double { Ink.smooth((frame.mood - 0.15) / 0.5) }
    var eyesClosed: Bool { frame.mood < 0.42 }

    /// Offsets, scale and turn for this instant: the idle bob, and any hop,
    /// wiggle or stretch under way. About the feet.
    func offsets() -> (dx: Double, dy: Double, sx: Double, sy: Double, turn: Double) {
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

    /// How open the eyes are, 0.1 shut to 1 open: the blink every four
    /// seconds, and the flutter of waking.
    func blink() -> Double {
        let cycle = (time / 4.2).truncatingRemainder(dividingBy: 1)
        var blink = cycle > 0.93 && cycle < 0.99 ? 0.1 : 1.0
        if let waking, waking < 0.45 { blink = abs(cos(waking / 0.45 * .pi * 2)) * 0.9 + 0.1 }
        return blink
    }

    private static let capColour = Color(hex: "7C8BE8")

    /// Worn while dozing; it flies off as the duck wakes.
    func nightcap(_ c: GraphicsContext) {
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
        cap.fill(shape, with: .color(Self.capColour))
        var band = Path()
        band.move(to: CGPoint(x: 29, y: 41))
        band.addQuadCurve(to: CGPoint(x: 62, y: 38), control: CGPoint(x: 45, y: 33))
        cap.stroke(band, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        cap.circle(72, 18, 4, .color(.white))
    }
}
