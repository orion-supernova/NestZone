import SwiftUI

/// What a pet is lit with and coloured by at this instant: the plan's coat as
/// this mood and hour leave it, and the one light of the scene as the trees
/// have it (`SceneFrame.skySide`, the same number that places the sun or the
/// moon), so a kitten, an owl and the pomegranate beside them are lit from
/// the same side. Worked out once per draw, never in a loop.
struct CritterLook {
    typealias RGB = Canopy.RGB

    /// The coat, dark to light, then what is marked on it.
    let coat, light, dark, belly, mark, accent, nose, iris: RGB
    /// Towards the light, y up negative. Never straight overhead (at least a
    /// quarter of the way to a side), and higher by day than at dusk.
    let L: CGPoint
    /// The thin edge of light on the side that faces it: warm white at noon,
    /// amber when the sun is low, cool blue-white by the moon. Stronger at
    /// dusk and at night, weaker asleep.
    let rim: RGB
    let rimAlpha: Double
    /// What shadow is tinted with: a cool violet, deeper at night. Shadow is
    /// never black and never grey.
    let cool: RGB
    let coolAlpha: Double
    let day: Double
    let dusk: Double
    let moon: Double
    /// 0 awake to 1 asleep: a quiet pet is paler, greyer and sits lower.
    let slump: Double
    let ink = Color(hex: "2A1D0E")

    init(plan: CritterPlan, frame: SceneFrame, slump: Double) {
        self.slump = slump
        day = frame.day
        dusk = 4 * frame.day * (1 - frame.day)
        moon = Ink.smooth((0.3 - frame.day) / 0.3)
        func tone(_ hex: UInt32, dim: Double = 0.55) -> RGB { Self.tone(hex, dim: dim, day: frame.day, slump: slump) }
        coat = tone(plan.coat); light = tone(plan.light); dark = tone(plan.shade); belly = tone(plan.belly)
        mark = tone(plan.mark); accent = tone(plan.accent); nose = tone(plan.nose)
        iris = tone(plan.iris, dim: 0.3)
        let side = SceneFrame.skySide(frame.hour)
        let sx = abs(side) < 0.25 ? (side > 0 ? 0.25 : -0.25) : side
        let sy = -(0.45 + 0.4 * frame.day)
        let len = (sx * sx * 0.81 + sy * sy).squareRoot()
        L = CGPoint(x: sx * 0.9 / len, y: sy / len)
        rim = RGB(0xFFF3C4).mix(RGB(0xFF9A5C), Ink.clamp(dusk * 1.4)).mix(RGB(0xC4D2FF), moon)
        rimAlpha = (0.26 + 0.34 * Ink.clamp(dusk * 1.3) + 0.3 * moon) * (1 - 0.5 * slump)
        cool = RGB(0x6E5AA8).mix(RGB(0x2C2A78), moon)
        coolAlpha = 0.2 + 0.14 * moon
    }

    /// One colour as this mood and light leave it: a quiet pet goes paler and
    /// greyer, and the evening cools it a little.
    static func tone(_ hex: UInt32, dim: Double, day: Double, slump: Double) -> RGB {
        let (h, s, l) = RGB(hex).hsl
        return RGB.night(h, s * Ink.lerp(1, 0.55, slump), l + 7 * slump * (1 - l / 100), day: day, dim: dim)
    }

    func tone(_ hex: UInt32, dim: Double = 0.55) -> RGB { Self.tone(hex, dim: dim, day: day, slump: slump) }

    /// A tone a step lighter or darker, for a shade you do not want to keep
    /// in the plan.
    func lifted(_ c: RGB, _ amount: Double = 0.3) -> RGB { c.mix(RGB(255, 255, 255), amount) }
}
