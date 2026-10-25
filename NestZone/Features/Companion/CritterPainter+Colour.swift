import SwiftUI

// MARK: - Colourway marks

extension CritterPainter {
    /// A patch's colour lit as a form is: light, middle, shade.
    func patchTones(_ hex: UInt32) -> (RGB, RGB, RGB) {
        let mid = look.tone(hex, dim: 0.5)
        return (look.lifted(mid, 0.22), mid, mid.shifted(-14, 2))
    }

    /// A calico's two patches on one form, shaded along the light like the
    /// form under them, so they sit in the fur and not on it.
    func patches(_ c: GraphicsContext, _ a: Path, _ b: Path, centre: CGPoint, radius: Double, L: CGPoint? = nil) {
        guard plan.patches.count >= 2 else { return }
        for (path, hex) in [(a, plan.patches[0]), (b, plan.patches[1])] where !path.isEmpty {
            let (l, m, d) = patchTones(hex)
            c.fill(path, with: ramp(centre, radius, l, m, d, L: L))
        }
    }

    /// The spots of a spotted coat: the plan's own colour, or the belly's
    /// (a fawn's white spots).
    var spotDark: RGB { plan.spotTone.map { look.tone($0, dim: 0.5) } ?? look.belly.shifted(-5) }
    var spotLight: RGB { plan.spotTone.map { look.lifted(look.tone($0, dim: 0.5), 0.2) } ?? look.lifted(look.belly, 0.3) }
}
