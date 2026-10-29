import SwiftUI

/// What a dozing plant or tree wears: a small knitted cozy round its pot, the
/// plants' own nightcap. It is drawn from the pot, not from the plant, so it
/// fits a seedling and a tall tree alike; the plant itself goes to sleep the
/// way real plants do (`Canopy.Mood.doze`: leaves fold and droop, blossoms close,
/// colours dim, a sunflower's head bows).
///
/// It is one still picture on a layer of its own (`CozyLayer`), drawn again only
/// when the mood, the hour or the house's pot changes, and kept out of the
/// plant's layer on purpose: that layer is sheared by the wind and stretched by
/// a bounce about the soil line, and a cozy below the soil line would slide
/// against the pot it is wrapped round.
enum SleepCozy {
    typealias RGB = Canopy.RGB

    /// The house's wool, from its seed: coral, mustard or rose.
    private static let wools: [UInt32] = [0xE8734A, 0xE5B04A, 0xD9607A]
    private static let cream: UInt32 = 0xFFF1D6

    /// How much of the cozy is on: it comes on as the plant dozes off and comes
    /// off as it wakes, so it is never on a plant that is merely thirsty.
    static func amount(mood: Double) -> Double { Ink.smooth(Canopy.Mood(mood).doze * 1.6) }

    /// The cozy on the scene's pot, unscaled, about the trunk's base on the soil
    /// (up is negative), `k` of the way on.
    static func paint(_ context: GraphicsContext, seed: String, day: Double, k: Double) {
        guard k > 0.01 else { return }
        var c = context
        c.opacity = k
        // It is pulled on from above: it settles the last few points down.
        c.translateBy(x: 0, y: (1 - k) * -6)
        let hex = wools[Int(Ink.hash(seed) % UInt32(wools.count))]
        let wool = RGB.tone(hex, day: day, dim: 0.85)
        let rib = wool.mix(RGB(0x4A1F14), 0.28)
        let cuff = wool.mix(RGB(0xFFFFFF), 0.16)
        let pale = RGB.tone(cream, day: day, dim: 0.9)

        // The sleeve is a little wider than the pot: knitting has body.
        let top = 11.0, bottom = 46.0, wTop = 51.5, wBottom = 46.5
        func topY(_ x: Double) -> Double { top + 3 * (1 - (x / wTop) * (x / wTop)) }
        func bottomY(_ x: Double) -> Double { bottom + 5 * (1 - (x / wBottom) * (x / wBottom)) }
        var sleeve = Path()
        sleeve.move(to: CGPoint(x: -wTop, y: top))
        sleeve.addQuadCurve(to: CGPoint(x: wTop, y: top), control: CGPoint(x: 0, y: top + 6))
        sleeve.addLine(to: CGPoint(x: wBottom, y: bottom))
        sleeve.addQuadCurve(to: CGPoint(x: -wBottom, y: bottom), control: CGPoint(x: 0, y: bottom + 10))
        sleeve.closeSubpath()
        c.fill(sleeve, with: .linearGradient(Gradient(colors: [wool.mix(RGB(0xFFFFFF), 0.12).color(), wool.color(), wool.mix(RGB(0x3A1810), 0.22).color()]),
                                             startPoint: CGPoint(x: -wTop, y: 0), endPoint: CGPoint(x: wTop, y: 0)))

        // Ribs run down the sleeve, bowed with it.
        var ribs = Path()
        for i in -11...11 {
            let xt = Double(i) * 4.5, xb = xt * wBottom / wTop
            let a = CGPoint(x: xt, y: topY(xt) + 7), b = CGPoint(x: xb, y: bottomY(xb) - 0.5)
            let mid = CGPoint(x: (a.x + b.x) / 2 * 1.015, y: (a.y + b.y) / 2)
            ribs.move(to: CGPoint(x: a.x - 0.5, y: a.y))
            ribs.addQuadCurve(to: CGPoint(x: b.x - 0.4, y: b.y), control: CGPoint(x: mid.x - 0.5, y: mid.y))
            ribs.addLine(to: CGPoint(x: b.x + 0.4, y: b.y))
            ribs.addQuadCurve(to: CGPoint(x: a.x + 0.5, y: a.y), control: CGPoint(x: mid.x + 0.5, y: mid.y))
            ribs.closeSubpath()
        }
        var clip = c
        clip.clip(to: sleeve)
        clip.fill(ribs, with: .color(rib.color(0.55)))

        // A band of cream diamonds across the middle.
        var diamonds = Path()
        let rowY = 29.0
        for i in -4...4 {
            let x = Double(i) * 10, squeeze = (1 - (x / wTop) * (x / wTop)).squareRoot()
            let cx = x * 0.96, cy = rowY + 3.2 * (1 - (x / wTop) * (x / wTop))
            diamonds.move(to: CGPoint(x: cx, y: cy - 3.4))
            diamonds.addLine(to: CGPoint(x: cx + 3.4 * squeeze, y: cy))
            diamonds.addLine(to: CGPoint(x: cx, y: cy + 3.4))
            diamonds.addLine(to: CGPoint(x: cx - 3.4 * squeeze, y: cy))
            diamonds.closeSubpath()
        }
        clip.fill(diamonds, with: .color(pale.color(0.95)))

        // The cuff, folded over at the top, and its stitches.
        var band = Path()
        band.move(to: CGPoint(x: -wTop, y: top))
        band.addQuadCurve(to: CGPoint(x: wTop, y: top), control: CGPoint(x: 0, y: top + 6))
        band.addLine(to: CGPoint(x: wTop - 0.6, y: top + 7))
        band.addQuadCurve(to: CGPoint(x: -wTop + 0.6, y: top + 7), control: CGPoint(x: 0, y: top + 13))
        band.closeSubpath()
        c.fill(band, with: .color(cuff.color()))
        var stitches = Path()
        for i in -12...12 {
            let x = Double(i) * 4.2
            stitches.move(to: CGPoint(x: x, y: topY(x) + 1.6))
            stitches.addLine(to: CGPoint(x: x + 0.5, y: topY(x) + 5.2))
            stitches.addLine(to: CGPoint(x: x + 1.2, y: topY(x) + 5))
            stitches.addLine(to: CGPoint(x: x + 0.7, y: topY(x) + 1.5))
            stitches.closeSubpath()
        }
        c.fill(stitches, with: .color(rib.color(0.4)))
        // The edge of the cuff, a touch of shade under it, and the lower hem.
        var under = Path()
        under.move(to: CGPoint(x: -wTop + 0.6, y: top + 7))
        under.addQuadCurve(to: CGPoint(x: wTop - 0.6, y: top + 7), control: CGPoint(x: 0, y: top + 13))
        c.stroke(under, with: .color(rib.color(0.7)), lineWidth: 1)
        var hem = Path()
        hem.move(to: CGPoint(x: -wBottom, y: bottom))
        hem.addQuadCurve(to: CGPoint(x: wBottom, y: bottom), control: CGPoint(x: 0, y: bottom + 10))
        c.stroke(hem, with: .color(rib.color(0.8)), lineWidth: 1.4)

        // A pompom on the cuff, off to the lit side.
        let pom = CGPoint(x: -33, y: top + 9)
        c.fill(Path(ellipseIn: CGRect(x: pom.x - 4.6, y: pom.y - 4.4, width: 9.2, height: 8.8)), with: .color(pale.color()))
        c.fill(Path(ellipseIn: CGRect(x: pom.x - 3.4, y: pom.y - 3.2, width: 4.4, height: 3)), with: .color(RGB(0xFFFFFF).color(0.7)))
        c.fill(Path(ellipseIn: CGRect(x: pom.x - 1, y: pom.y + 0.6, width: 5, height: 3.6)), with: .color(rib.color(0.16)))
    }
}

/// The cozy on a layer of its own, between the pot and the plant.
struct CozyLayer: View, Equatable {
    let seed: String
    let mood: Double
    let day: Double

    var body: some View {
        Canvas { context, size in Self.paint(context, size: size, seed: seed, mood: mood, day: day) }
            .drawingGroup()
            .allowsHitTesting(false)
    }

    /// On the scene's soil, the way the tree is.
    static func paint(_ context: GraphicsContext, size: CGSize, seed: String, mood: Double, day: Double) {
        let k = SleepCozy.amount(mood: mood)
        guard k > 0.01 else { return }
        let scale = size.height / SceneSpace.height
        var c = context
        c.scaleBy(x: scale, y: scale)
        c.translateBy(x: size.width / scale / 2, y: SceneSpace.soil)
        SleepCozy.paint(c, seed: seed, day: day, k: k)
    }
}
