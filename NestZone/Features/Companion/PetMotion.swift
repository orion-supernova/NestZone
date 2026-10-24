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

    // MARK: Mood, as acting

    /// How much each of the four moods is in the pose: they sum to 1 and ease
    /// into one another as the shown mood does (dozing .05, thirsty .3,
    /// content .62, bright 1), so a pose is a blend of the four and never a
    /// switch. Every part of a pet that acts (ears, tail, lids, gaze, posture)
    /// takes its numbers through `by`, which is what keeps "thirsty" from
    /// being a half-asleep content.
    struct Weights {
        var doze = 0.0, thirst = 0.0, content = 0.0, bright = 0.0
    }

    var weights: Weights {
        let m = frame.mood
        var w = Weights()
        if m <= 0.05 { w.doze = 1 }
        else if m < 0.3 { let t = Ink.smooth((m - 0.05) / 0.25); w.doze = 1 - t; w.thirst = t }
        else if m < 0.62 { let t = Ink.smooth((m - 0.3) / 0.32); w.thirst = 1 - t; w.content = t }
        else if m < 1 { let t = Ink.smooth((m - 0.62) / 0.38); w.content = 1 - t; w.bright = t }
        else { w.bright = 1 }
        return w
    }

    /// A number that is `d` when dozing, `t` when thirsty, `c` when content
    /// and `b` when bright, and between them in between.
    func by(_ d: Double, _ t: Double, _ c: Double, _ b: Double) -> Double {
        let w = weights
        return d * w.doze + t * w.thirst + c * w.content + b * w.bright
    }

    /// 1 once the pet is properly asleep, 0 from thirsty up.
    var sleep: Double { Ink.smooth((0.22 - frame.mood) / 0.14) }

    /// A one-off beat that comes round every `period` seconds, lasting
    /// `length`, as 0 to 1 and back (a sine arch). `offset` keeps two beats
    /// from landing together. Frozen under Reduce Motion.
    func beat(every period: Double, lasting length: Double, offset: Double = 0) -> Double {
        guard !frame.reduceMotion else { return 0 }
        let t = (time + offset).truncatingRemainder(dividingBy: period)
        return t < length ? sin(t / length * .pi) : 0
    }

    /// Offsets, scale and turn for this instant: the idle bob, and any hop,
    /// wiggle or stretch under way. About the feet.
    func offsets(calm: Bool = false) -> (dx: Double, dy: Double, sx: Double, sy: Double, turn: Double) {
        var dy = 0.0, dx = 0.0, sx = 1.0, sy = 1.0, turn = 0.0
        if !frame.reduceMotion, calm {
            // A mammal sitting: it does not bob, it breathes (the chest a
            // little wider and taller on the in-breath), and a bright one
            // rocks up on its paws now and then.
            let breath = sin(time / 3.6 * .pi * 2)
            let depth = by(0.03, 0.016, 0.014, 0.018)
            sx = 1 + depth * 0.5 * breath
            sy = 1 + depth * breath
            if frame.mood > 0.82 {
                let t = (time / 1.5).truncatingRemainder(dividingBy: 1)
                dy = -3 * max(0, sin(t * .pi)) * Ink.smooth((frame.mood - 0.82) / 0.18)
            }
            if stage == 1 { turn = sin(time / 1.3 * .pi * 2) * 0.16 }
        } else if !frame.reduceMotion {
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

    /// How far the lids are down, 0 open to 1 shut, from sleep, the quick
    /// blink every four seconds (and two together now and then), the slow,
    /// trusting one of a content pet, and the flutter of waking. The mood's own
    /// droop (heavy lids when content, wide eyes when thirsty) is the face's.
    func lids() -> Double {
        if let waking, waking < 0.45 { return 1 - (abs(cos(waking / 0.45 * .pi * 2)) * 0.9 + 0.1) }
        let quick = max(beat(every: 4.3, lasting: 0.16), beat(every: 12.9, lasting: 0.16, offset: 12.6))
        let slow = beat(every: 7.5, lasting: 0.8, offset: 2) * weights.content * 0.95
        return max(sleep, quick, slow)
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
