import SwiftUI

/// The watermelon on the floor: a whole striped one with its stem, and a slice
/// leaning against it with the seeds in the flesh. Lit by the sky's one light
/// and dimmed with the hour, like the pet beside it.
extension ScenePainter {
    /// The slice's seeds, each tipped outward from where the flesh begins.
    private static let melonSeeds: Path = {
        var p = Path()
        for (x, y, a) in [(-8.2, 4.4, -0.7), (-4.2, 7.4, -0.3), (0.0, 4.6, 0.0), (4.4, 7.6, 0.3), (8.4, 4.2, 0.7), (-10.6, 8.2, -0.9), (10.8, 8.0, 0.9), (0.2, 9.8, 0.1)] {
            let seed = Path(ellipseIn: CGRect(x: -0.95, y: -1.9, width: 1.9, height: 3.8))
                .applying(CGAffineTransform(rotationAngle: a).concatenating(CGAffineTransform(translationX: x, y: y)))
            p.addPath(seed)
        }
        return p
    }()

    private static let melonSlice: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -17, y: 0))
        p.addLine(to: CGPoint(x: 17, y: 0))
        p.addArc(center: .zero, radius: 17, startAngle: .zero, endAngle: .radians(.pi), clockwise: false)
        p.closeSubpath()
        return p
    }()

    private static let melonPith: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -15.2, y: 0))
        p.addLine(to: CGPoint(x: 15.2, y: 0))
        p.addArc(center: .zero, radius: 15.2, startAngle: .zero, endAngle: .radians(.pi), clockwise: false)
        p.closeSubpath()
        return p
    }()

    private static let melonFlesh: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -13.6, y: 0))
        p.addLine(to: CGPoint(x: 13.6, y: 0))
        p.addArc(center: .zero, radius: 13.6, startAngle: .zero, endAngle: .radians(.pi), clockwise: false)
        p.closeSubpath()
        return p
    }()

    private static let melonBody = Path(ellipseIn: CGRect(x: -30, y: -34, width: 42, height: 34))

    /// The meridian stripes, already cut to the body: no clip at draw time (a
    /// clip is an offscreen pass, and this is drawn every frame).
    private static let melonStripes: (dark: Path, light: Path) = {
        var dark = Path(), light = Path()
        let cx = -9.0, cy = -17.0, ry = 17.0
        for k in -3...3 {
            let ox = Double(k) * 6.6, wob = sin(Double(k) * 2.1) * 1.1
            func ribbon(_ into: inout Path, shift: Double, mid: Double, ends: Double) {
                into.move(to: CGPoint(x: cx + ox * 0.28 + shift - ends / 2, y: cy - ry - 1))
                into.addQuadCurve(to: CGPoint(x: cx + ox * 0.28 + shift - ends / 2, y: cy + ry + 1), control: CGPoint(x: cx + ox * 1.95 + shift - mid / 2 + wob, y: cy))
                into.addLine(to: CGPoint(x: cx + ox * 0.28 + shift + ends / 2, y: cy + ry + 1))
                into.addQuadCurve(to: CGPoint(x: cx + ox * 0.28 + shift + ends / 2, y: cy - ry - 1), control: CGPoint(x: cx + ox * 1.95 + shift + mid / 2 + wob, y: cy))
                into.closeSubpath()
            }
            ribbon(&dark, shift: 0, mid: 3.8, ends: 1.2)
            ribbon(&light, shift: 3.3, mid: 1.0, ends: 0.4)
        }
        return (dark.intersection(melonBody), light.intersection(melonBody))
    }()

    func watermelon(_ context: GraphicsContext, x: Double, y: Double) {
        let L = lamp.L
        let rind = lamp.tone(0x3F8F4B, dim: 0.8), stripe = lamp.tone(0x1E5C34, dim: 0.8), pale = lamp.tone(0x8FD27F, dim: 0.8)
        var context = context
        context.translateBy(x: x, y: y)
        // The shadows: a wide soft one under both, a dark contact under each.
        context.ellipse(4, 1.5, 36, 5, .color(SceneInk.shadow))
        context.ellipse(-9, -0.4, 19, 2.6, .color(Color.black.opacity(0.22)))

        // The whole melon, behind to the left.
        let cx = -9.0, cy = -17.0, ry = 17.0
        let body = Self.melonBody
        context.fill(body, with: .color(rind.color()))
        context.fill(Self.melonStripes.light, with: .color(pale.color(0.55)))
        context.fill(Self.melonStripes.dark, with: .color(stripe.color(0.85)))
        // Light on one side and shade on the other, over the whole body.
        context.fill(body, with: .linearGradient(
            Gradient(stops: [.init(color: Color.white.opacity(0.27), location: 0), .init(color: .clear, location: 0.45), .init(color: lamp.cool.color(0.42), location: 1)]),
            startPoint: CGPoint(x: cx + L.x * 21, y: cy + L.y * 21), endPoint: CGPoint(x: cx - L.x * 21, y: cy - L.y * 21)))
        // Gloss: a long soft highlight on the lit shoulder and a bright speck in it.
        WearArt.glow(context, body, lamp.lifted(pale, 0.7), centre: CGPoint(x: cx + L.x * 9, y: cy + L.y * 8), radius: 11, alpha: 0.5)
        context.fill(Path(ellipseIn: CGRect(x: cx + L.x * 10 - 2.6, y: cy + L.y * 9 - 1.3, width: 5.2, height: 2.6)), with: .color(Color.white.opacity(0.55)))
        // The rim of the light along the lit edge.
        if lamp.rimAlpha > 0.03 {
            var edge = Path()
            edge.addArc(center: CGPoint(x: cx, y: cy), radius: ry - 0.4, startAngle: .radians(L.x > 0 ? -1.2 : Double.pi - 0.4), endAngle: .radians(L.x > 0 ? 0.4 : Double.pi + 1.2), clockwise: false)
            context.stroke(edge, with: .color(lamp.rim.color(lamp.rimAlpha * 0.8)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        // The stem, with a dried curl beside it.
        let stem = lamp.tone(0x6B7A32, dim: 0.8)
        var stalk = Path()
        stalk.move(to: CGPoint(x: cx + 1, y: cy - ry + 1))
        stalk.addQuadCurve(to: CGPoint(x: cx + 4.2, y: cy - ry - 5), control: CGPoint(x: cx + 0.6, y: cy - ry - 4))
        context.stroke(stalk, with: .color(stem.shifted(-10).color()), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.stroke(stalk, with: .color(stem.color()), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        var curl = Path()
        curl.move(to: CGPoint(x: cx + 1.6, y: cy - ry + 0.4))
        curl.addCurve(to: CGPoint(x: cx - 6.4, y: cy - ry - 3.4), control1: CGPoint(x: cx - 1, y: cy - ry - 5), control2: CGPoint(x: cx - 5, y: cy - ry - 7))
        curl.addQuadCurve(to: CGPoint(x: cx - 5, y: cy - ry - 0.6), control: CGPoint(x: cx - 8, y: cy - ry - 1.2))
        context.stroke(curl, with: .color(stem.shifted(2, 4).color(0.9)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))

        // The slice, in front to the right, leaning a little on the melon.
        var slice = context
        slice.translateBy(x: 15, y: -17)
        slice.rotate(by: .radians(-0.17))
        slice.fill(Self.melonSlice.offsetBy(dx: 0.8, dy: 1.4), with: .color(Color.black.opacity(0.18)))
        WearArt.form(slice, Self.melonSlice, centre: CGPoint(x: 0, y: 8), radius: 18, lamp, lamp.lifted(rind, 0.2), rind, stripe, highlight: 0.3, core: 0.6)
        let white = lamp.tone(0xEAF4CC, dim: 0.6)
        slice.fill(Self.melonPith, with: .color(white.color()))
        let coral = lamp.tone(0xFF6B7C, dim: 0.75), red = lamp.tone(0xE5334B, dim: 0.75), deepRed = lamp.tone(0xB8203A, dim: 0.75)
        slice.fill(Self.melonFlesh, with: .radialGradient(
            Gradient(stops: [.init(color: deepRed.color(), location: 0), .init(color: red.color(), location: 0.45), .init(color: coral.color(), location: 1)]),
            center: CGPoint(x: 0, y: 1), startRadius: 0, endRadius: 14.6))
        // Juice: a bright wet line along the cut and the sheen on the flesh.
        var cut = Path()
        cut.move(to: CGPoint(x: -13, y: 0.6)); cut.addLine(to: CGPoint(x: 13, y: 0.6))
        slice.stroke(cut, with: .color(lamp.lifted(coral, 0.55).color(0.8)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        var sheen = Path()
        sheen.addArc(center: .zero, radius: 10.6, startAngle: .radians(0.35), endAngle: .radians(1.15), clockwise: false)
        slice.stroke(sheen, with: .color(Color.white.opacity(0.32)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        slice.fill(Self.melonSeeds, with: .color(lamp.tone(0x2A1B1B, dim: 0.5).color()))
        var glints = Path()
        for (sx, sy) in [(-8.2, 3.7), (0.0, 3.9), (8.4, 3.5), (-4.2, 6.7), (4.4, 6.9)] { glints.addEllipse(in: CGRect(x: sx - 0.8, y: sy - 0.5, width: 0.7, height: 1.1)) }
        slice.fill(glints, with: .color(Color.white.opacity(0.55)))
    }
}
