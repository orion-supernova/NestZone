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

    /// A cross fox's dark, as this mood and light leave it.
    var crossTone: RGB? { plan.cross.map { look.tone($0, dim: 0.45) } }

    /// A leg that goes dark from `from` down to `to`.
    func legFade(_ tone: RGB, from: Double, to: Double) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: [.init(color: tone.color(0), location: 0), .init(color: tone.color(0.82), location: 0.3), .init(color: tone.color(0.96), location: 0.6)]),
                        startPoint: CGPoint(x: 43, y: from), endPoint: CGPoint(x: 43, y: to))
    }

    /// The stripe down the spine, the bar over the shoulders and the dark underside.
    func crossMarks(_ b: GraphicsContext, _ g: SitGeometry, _ tone: RGB) {
        b.fill(g.underside, with: .linearGradient(Gradient(stops: [.init(color: tone.color(0), location: 0), .init(color: tone.color(0.85), location: 1)]),
                                                  startPoint: CGPoint(x: 66, y: 93), endPoint: CGPoint(x: 66, y: 109)))
        b.fill(g.crossMark, with: .color(tone.color(0.92)))
        // The light on the sunny edge of the stripe, as the fur's lit copy.
        var lit = b
        lit.translateBy(x: look.L.x * 0.6, y: look.L.y * 0.6)
        lit.fill(g.crossMark, with: .color(look.lifted(tone, 0.25).color(0.25)))
    }

    /// The spots of a spotted coat: the plan's own colour, or the belly's
    /// (a fawn's white spots).
    var spotDark: RGB { plan.spotTone.map { look.tone($0, dim: 0.5) } ?? look.belly.shifted(-5) }
    var spotLight: RGB { plan.spotTone.map { look.lifted(look.tone($0, dim: 0.5), 0.2) } ?? look.lifted(look.belly, 0.3) }
}
