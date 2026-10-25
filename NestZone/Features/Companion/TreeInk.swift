import SwiftUI

/// The colours a tree's leaves are painted with in one light, shared by every
/// tree that is drawn the pomegranate's way: four classes of green per tier
/// (the shade, the middle, the lit and the sunstruck), the light on a leaf's
/// edge, the dark body behind a clump and the shadow it casts.
enum TreeInk {
    typealias RGB = Canopy.RGB

    /// What the sky's light does to a leaf at this hour: the warm white of
    /// noon, amber when the sun is low, and by the moon a cool, dim blue.
    struct Light {
        let dusk, moon: Double
        let rim, glow: RGB
        /// Towards the light, a unit vector, y up negative.
        let L: (x: Double, y: Double)

        init(light: Double, day: Double) {
            L = LeafArt.sun(light: light, day: day)
            dusk = 4 * day * (1 - day)
            moon = Ink.smooth((0.3 - day) / 0.3)
            rim = RGB(0xFFF3C4).mix(RGB(0xFF9A5C), Ink.clamp(dusk * 1.4)).mix(RGB(0xC4D2FF), moon)
            glow = RGB(0xFFE9A8).mix(RGB(0xFFB070), Ink.clamp(dusk * 1.4)).mix(RGB(0xB8C8FF), moon)
        }
    }

    /// Tier 0, 1, 2, each plain then fresh (new growth). `fresh` is the colour
    /// new growth leans towards: a pomegranate's is copper, a lemon's a pale
    /// yellow-green.
    static func leafInks(_ tones: Canopy.Tones, _ M: Canopy.Mood, day: Double, light lt: Light, fresh freshHex: UInt32 = 0xBE5A38,
                         rimBase: RGB? = nil, rimK: Double = 0.65) -> [PomegranatePainter.LeafInk] {
        let moon = lt.moon, dusk = lt.dusk, glow = lt.glow, doze = M.doze, thirst = M.thirst
        let ramp = tones.ramp
        let bronze = RGB.tone(freshHex, day: day, dim: 0.9)
        // By moonlight a leaf is not a paler green, it is a dim blue one: the
        // classes are drawn towards one deep blue and pulled close together,
        // so a night crown is a low-contrast mass with a faint cool rim.
        let blue = RGB(0x24476F), deepBlue = RGB(0x13283E), rimNight = RGB(0x86A4D6)
        var inks: [PomegranatePainter.LeafInk] = []
        for tier in 0..<3 {
            for fresh in [false, true] {
                // Where the four classes sit on the ramp, tier by tier: the
                // back is a step down the ramp from the front.
                var d, m, l, s: RGB
                switch tier {
                case 0:
                    d = ramp[0].mix(ramp[1], 0.6)
                    m = ramp[1].mix(ramp[2], 0.3)
                    l = ramp[1].mix(ramp[2], 0.7)
                    s = ramp[2].mix(ramp[3], 0.1)
                case 1:
                    d = ramp[1].mix(ramp[2], 0.1)
                    m = ramp[1].mix(ramp[2], 0.7)
                    l = ramp[2].mix(ramp[3], 0.45)
                    s = ramp[2].mix(ramp[3], 0.95)
                default:
                    d = ramp[1].mix(ramp[2], 0.55)
                    m = ramp[2].mix(ramp[3], 0.55)
                    l = ramp[3].mix(ramp[4], 0.15)
                    s = ramp[3].mix(ramp[4], 0.4)
                }
                // The shade leans cool and the light warm, as it does in paint.
                d = d.mix(RGB(0x143A44), 0.22)
                if fresh {
                    let k = 0.3 * (1 - 0.5 * thirst)
                    d = d.mix(bronze, k * 0.6)
                    m = m.mix(bronze, k)
                    l = l.mix(bronze, k)
                    s = s.mix(bronze, k)
                }
                if moon > 0 {
                    let mB = m.mix(blue, 0.34)
                    d = d.mix(d.mix(deepBlue, 0.5), moon)
                    l = l.mix(mB.mix(l.mix(blue, 0.5), 0.3), moon)
                    s = s.mix(mB.mix(s.mix(blue, 0.5), 0.45), moon)
                    m = m.mix(mB, moon)
                }
                s = s.mix(glow, 0.16 * (1 - moon) * (0.6 + 0.4 * day))
                if fresh {
                    // New leaves are a fresh yellow-green with bronze at the tip.
                    m = m.mix(ramp[3], 0.25)
                    l = l.mix(ramp[4], 0.2)
                }
                let deep = ramp[0].mix(RGB(0x0B1A1C), 0.4)
                let edgeA = (0.34 + 0.06 * dusk - 0.16 * moon) * (1 - 0.35 * doze)
                let edge = (rimBase ?? ramp[4]).mix(lt.rim, rimK).mix(rimNight, moon)
                inks.append(PomegranatePainter.LeafInk(
                    d: d.color(), m: m.color(), l: l.color(), s: s.color(),
                    mLit: m.shifted(2 - 5 * moon, -3).color(), mShade: m.shifted(-5, 6).color(),
                    rim: edge.color(min(1, edgeA * (1 - 0.15 * moon))),
                    body: ramp[tier].mix(deep, 0.35).color(),
                    shadow: Gradient(colors: [deep.color(0.4 * (1 - 0.3 * doze)), deep.color(0.16), deep.color(0)])
                ))
            }
        }
        return inks
    }
}
