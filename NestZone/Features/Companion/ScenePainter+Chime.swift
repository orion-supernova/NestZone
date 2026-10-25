import SwiftUI

/// The wind chime, hung overhead. It is the one thing in the sky's reach that
/// moves all the time, so it is drawn every frame: a swing of the whole
/// chime, each tube a little behind it, the wind catcher turning on its
/// string, and now and then a glint running down a tube.
extension ScenePainter {
    private static let chimeCentres: [Double] = [-13.2, -6.6, 0, 6.6, 13.2]
    private static let chimeLengths: [Double] = [62, 74, 54, 68, 46]
    private static let chimeBrass: [UInt32] = [0xE2B85A, 0xCF9A45, 0xEBC66F, 0xC98A42, 0xD9AB52]

    /// The wind catcher: a leaf on a string, widest at its belly.
    private static let chimeSail: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addCurve(to: CGPoint(x: 0, y: 31), control1: CGPoint(x: 9, y: 7), control2: CGPoint(x: 9, y: 22))
        p.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: -9, y: 22), control2: CGPoint(x: -9, y: 7))
        p.closeSubpath()
        return p
    }()

    private static let chimeVein: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 2)); p.addLine(to: CGPoint(x: 0, y: 28))
        for k in 1...4 {
            let y = Double(k) * 5.2
            p.move(to: CGPoint(x: 0, y: y + 2)); p.addQuadCurve(to: CGPoint(x: -5.2, y: y - 1.5), control: CGPoint(x: -2.5, y: y + 1))
            p.move(to: CGPoint(x: 0, y: y + 2)); p.addQuadCurve(to: CGPoint(x: 5.2, y: y - 1.5), control: CGPoint(x: 2.5, y: y + 1))
        }
        return p
    }()

    func windChime(_ context: GraphicsContext) {
        let L = lamp.L
        let hangX = min(width - 50, center + 118)
        let wind = frame.reduceMotion ? 0 : frame.wind
        // A slow swing with gusts that only push one way, as the trees have it.
        let gust = max(0, sin(time * 0.7) + 0.5 * sin(time * 1.9 + 1))
        let swing = frame.reduceMotion ? 0 : (sin(time * 1.15) * 0.03 + gust * 0.03) * (0.5 + wind)
        var c = context
        c.translateBy(x: hangX, y: 0)
        c.rotate(by: .radians(swing * 0.6))

        let wood = lamp.tone(0x7A5233, dim: 0.8), brassDark = lamp.tone(0x8A6420, dim: 0.8)
        let thread = Color.white.opacity(0.55 + 0.2 * day)
        // The cord up out of the frame, and a brass ring where it meets the plate.
        var cord = Path()
        cord.move(to: CGPoint(x: 0, y: -4)); cord.addLine(to: CGPoint(x: 0, y: 11))
        c.stroke(cord, with: .color(thread), lineWidth: 1.1)
        c.stroke(Path(ellipseIn: CGRect(x: -3, y: 8, width: 6, height: 5.4)), with: .color(lamp.tone(0xD9AB52, dim: 0.8).color()), lineWidth: 1.3)

        // The plate: a wooden disc, its edge and its top face.
        c.fill(Path(ellipseIn: CGRect(x: -17, y: 17, width: 34, height: 9.4)), with: .color(wood.shifted(-14).color()))
        let top = Path(ellipseIn: CGRect(x: -17, y: 14, width: 34, height: 9.4))
        WearArt.form(c, top, centre: CGPoint(x: 0, y: 18.7), radius: 17, lamp, lamp.lifted(wood, 0.3), wood, wood.shifted(-12), highlight: 0.35, core: 0.5)
        var holes = Path()
        for x in Self.chimeCentres { holes.addEllipse(in: CGRect(x: x * 1.1 - 1, y: 20.4 + (1 - abs(x) / 14) * 0.6, width: 2, height: 1.1)) }
        c.fill(holes, with: .color(Color.black.opacity(0.45)))

        // The sail and the clapper hang on the middle string and swing further than the tubes do.
        let long = swing * 1.5 + (frame.reduceMotion ? 0 : sin(time * 2.1) * 0.05 * wind)
        let tubeTop = 31.0
        var sail = c
        sail.translateBy(x: 0, y: 22)
        sail.rotate(by: .radians(long))
        var string = Path()
        string.move(to: .zero); string.addLine(to: CGPoint(x: 0, y: 66))
        sail.stroke(string, with: .color(thread), lineWidth: 0.8)
        // The clapper: a wooden disc.
        sail.fill(Path(ellipseIn: CGRect(x: -6, y: 42, width: 12, height: 5)), with: .color(wood.shifted(-14).color()))
        WearArt.form(sail, Path(ellipseIn: CGRect(x: -6, y: 40.4, width: 12, height: 5)), centre: CGPoint(x: 0, y: 43), radius: 6, lamp, lamp.lifted(wood, 0.3), wood, wood.shifted(-12), highlight: 0.3, core: 0.4)
        // The sail turns on its string: wide, then edge-on, then wide.
        let turn = frame.reduceMotion ? 1 : 0.62 + 0.38 * cos(time * 0.9 + 0.5)
        var leaf = sail
        leaf.translateBy(x: 0, y: 64)
        leaf.scaleBy(x: turn, y: 1)
        let sage = lamp.tone(0x7FB08C, dim: 0.8)
        WearArt.form(leaf, Self.chimeSail, centre: CGPoint(x: 0, y: 15), radius: 11, lamp, lamp.lifted(sage, 0.3), sage, sage.shifted(-14, 4), highlight: 0.4, core: 0.6)
        leaf.stroke(Self.chimeVein, with: .color(sage.shifted(-20).color(0.5)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))

        // The tubes: brass cylinders lit across their width, each on its own thread.
        let glintTube = frame.reduceMotion ? 1 : Int(time / 4.7) % 5
        let glintPhase = frame.reduceMotion ? 0.5 : (time / 4.7).truncatingRemainder(dividingBy: 1) / 0.12
        var threads = Path()
        for x in Self.chimeCentres { threads.move(to: CGPoint(x: x * 1.1, y: 22)); threads.addLine(to: CGPoint(x: x * 1.1, y: tubeTop)) }
        c.stroke(threads, with: .color(thread), lineWidth: 0.7)
        for (i, x) in Self.chimeCentres.enumerated() {
            let length = Self.chimeLengths[i]
            let lag = frame.reduceMotion ? 0 : sin(time * 2.3 + Double(i) * 1.7) * 0.022 * wind + swing * 0.4 * (i.isMultiple(of: 2) ? 1 : -0.3)
            var t = c
            t.translateBy(x: x * 1.1, y: 22)
            t.rotate(by: .radians(lag))
            let brass = lamp.tone(Self.chimeBrass[i], dim: 0.8)
            let body = Path(roundedRect: CGRect(x: -2.6, y: tubeTop - 22, width: 5.2, height: length), cornerRadius: 1.2)
            t.fill(body, with: .linearGradient(
                Gradient(stops: [.init(color: lamp.lifted(brass, 0.45).color(), location: 0), .init(color: brass.color(), location: 0.4),
                                 .init(color: brass.shifted(-16, 2).color(), location: 0.8), .init(color: brassDark.color(), location: 1)]),
                startPoint: CGPoint(x: L.x * 2.6, y: 0), endPoint: CGPoint(x: -L.x * 2.6, y: 0)))
            if lamp.rimAlpha > 0.03 {
                t.fill(Path(CGRect(x: L.x > 0 ? 1.7 : -2.6, y: tubeTop - 21, width: 0.9, height: length - 2)), with: .color(lamp.rim.color(lamp.rimAlpha * 0.9)))
            }
            t.fill(Path(CGRect(x: L.x - 0.45, y: tubeTop - 20, width: 0.9, height: length * 0.7)), with: .color(Color.white.opacity(0.4 + 0.2 * day)))
            t.fill(Path(ellipseIn: CGRect(x: -2.3, y: tubeTop - 22 + length - 1.1, width: 4.6, height: 2.2)), with: .color(brassDark.shifted(-20).color(0.9)))
            if i == glintTube, glintPhase < 1 {
                let k = sin(glintPhase * .pi)
                t.glint(L.x, tubeTop - 20 + length * 0.7 * glintPhase, 1.5 * k, Color.white.opacity(0.95 * k))
            }
        }
    }
}
