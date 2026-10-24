import SwiftUI

/// Decorations drawn in the art pass: the party hat a birthday brings, and the
/// bird feeder.
extension ScenePainter {
    /// A cone of coloured paper with a pompom, its foot on `top`, tipped a
    /// little. Lit from the upper left like everything else.
    func partyHat(_ context: GraphicsContext, at top: CGPoint) {
        var c = context
        c.translateBy(x: top.x, y: top.y + 3)
        c.rotate(by: .radians(-0.12 + (frame.reduceMotion ? 0 : sin(time * 1.6) * 0.03)))
        let night = 1 - day
        func dim(_ hex: UInt32) -> Color { Ink.color(hex).opacity(1) }
        var cone = Path()
        cone.move(to: CGPoint(x: -11, y: 0))
        cone.addQuadCurve(to: CGPoint(x: 1, y: -30), control: CGPoint(x: -6, y: -16))
        cone.addQuadCurve(to: CGPoint(x: 11, y: 0), control: CGPoint(x: 8, y: -15))
        cone.addQuadCurve(to: CGPoint(x: -11, y: 0), control: CGPoint(x: 0, y: 4))
        c.fill(cone, with: .linearGradient(
            Gradient(colors: [Ink.color(0xFF9CC8), Ink.color(0xF25C9B), Ink.color(0xC93A7C)]),
            startPoint: CGPoint(x: -11, y: -20), endPoint: CGPoint(x: 11, y: 0)))
        // Stripes and dots, clipped to the cone.
        var inside = c
        inside.clip(to: cone)
        var stripes = Path()
        for (x0, y0) in [(-12.0, -6.0), (-10, -14), (-6, -22)] {
            stripes.move(to: CGPoint(x: x0, y: y0 + 3)); stripes.addLine(to: CGPoint(x: x0 + 26, y: y0 - 4))
        }
        inside.stroke(stripes, with: .color(Ink.color(0xFFE08A)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        inside.fill(Path(ellipseIn: CGRect(x: -9, y: -3, width: 18, height: 6)), with: .color(Ink.color(0xFFE08A, 0.9)))
        inside.fill(Path(CGRect(x: -14, y: -34, width: 8, height: 40)), with: .color(Color.white.opacity(0.16)))
        for (x, y) in [(-1.0, -9.0), (3, -16), (-3, -19)] { inside.circle(x, y, 1.3, .color(Color.white.opacity(0.8))) }
        if night > 0.4 { c.fill(cone, with: .color(Ink.color(0x1B1240, 0.25 * night))) }
        // The pompom, on a tuft of ribbon.
        var tuft = Path()
        for a in stride(from: -2.6, through: -0.5, by: 0.35) {
            tuft.move(to: CGPoint(x: 1, y: -30)); tuft.addLine(to: CGPoint(x: 1 + cos(a) * 5.5, y: -30 + sin(a) * 5.5))
        }
        c.stroke(tuft, with: .color(Ink.color(0xFFE08A)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        c.circle(1, -31, 3.4, .color(Ink.color(0xFFE08A)))
        c.circle(0, -32, 1.3, .color(Color.white.opacity(0.7)))
    }

    /// A feeder on a post: a little wooden house with a seed tray, and a
    /// sparrow that pecks now and then and hops off for a bit.
    func birdFeeder(_ context: GraphicsContext, x: Double, y: Double) {
        let night = 1 - day
        func wood(_ l: Double) -> Color { tint(28, 46, l) }
        context.ellipse(x, y + 1, 11, 3.4, .color(SceneInk.shadow))
        // Post.
        context.fill(Path(roundedRect: CGRect(x: x - 2.2, y: y - 50, width: 4.4, height: 50), cornerRadius: 1.6), with: .linearGradient(
            Gradient(colors: [wood(48), wood(30)]), startPoint: CGPoint(x: x - 2.2, y: y), endPoint: CGPoint(x: x + 2.2, y: y)))
        // The house: back wall, tray, roof.
        let top = y - 50
        context.fill(Path(roundedRect: CGRect(x: x - 15, y: top - 22, width: 30, height: 22), cornerRadius: 3), with: .linearGradient(
            Gradient(colors: [wood(58), wood(40)]), startPoint: CGPoint(x: x - 15, y: top - 22), endPoint: CGPoint(x: x + 15, y: top)))
        // The opening, dark, with seed in the tray.
        context.fill(Path(roundedRect: CGRect(x: x - 9, y: top - 17, width: 18, height: 13), cornerRadius: 6), with: .color(tint(24, 40, 18)))
        context.fill(Path(roundedRect: CGRect(x: x - 19, y: top - 2, width: 38, height: 4.4), cornerRadius: 2), with: .color(wood(34)))
        var seeds = Path()
        for i in 0..<9 { seeds.addEllipse(in: CGRect(x: x - 16 + Double(i) * 4, y: top - 3.2 - Double(i % 2) * 0.8, width: 2.6, height: 1.8)) }
        context.fill(seeds, with: .color(tint(42, 70, 70)))
        var roof = Path()
        roof.move(to: CGPoint(x: x - 21, y: top - 20))
        roof.addLine(to: CGPoint(x: x, y: top - 36))
        roof.addLine(to: CGPoint(x: x + 21, y: top - 20))
        roof.addQuadCurve(to: CGPoint(x: x - 21, y: top - 20), control: CGPoint(x: x, y: top - 17))
        context.fill(roof, with: .linearGradient(
            Gradient(colors: [tint(8, 50, 54), tint(8, 52, 34)]), startPoint: CGPoint(x: x - 21, y: top - 36), endPoint: CGPoint(x: x + 21, y: top - 18)))
        context.stroke(Path { $0.move(to: CGPoint(x: x - 20, y: top - 21)); $0.addLine(to: CGPoint(x: x, y: top - 35)) },
                       with: .color(Color.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        // The sparrow on the tray: pecks, then is gone for a while.
        let cycle = frame.reduceMotion ? 1 : (time / 9).truncatingRemainder(dividingBy: 1)
        guard cycle < 0.7 else { return }
        let peck = frame.reduceMotion ? 0 : max(0, sin(time * 9)) * (cycle.truncatingRemainder(dividingBy: 0.2) < 0.1 ? 1 : 0)
        var b = context
        b.translateBy(x: x + 9, y: top - 3)
        let brown = tint(28, 50, 40), pale = tint(40, 30, 78)
        b.ellipse(0, -4, 6.4, 4.6, .color(brown))
        b.ellipse(-0.5, -2.6, 4, 2.6, .color(pale))
        b.fill(Path { $0.move(to: CGPoint(x: 5, y: -5)); $0.addLine(to: CGPoint(x: 10, y: -3)); $0.addLine(to: CGPoint(x: 5, y: -2)) }, with: .color(brown))
        var head = b
        head.translateBy(x: -5, y: -8)
        head.rotate(by: .radians(peck * 0.7))
        head.circle(0, 0, 3.4, .color(tint(30, 46, 50)))
        head.fill(Path { $0.move(to: CGPoint(x: -3, y: -0.5)); $0.addLine(to: CGPoint(x: -6.4, y: 0.6)); $0.addLine(to: CGPoint(x: -3, y: 1.8)) }, with: .color(Ink.color(0xE9A23B)))
        head.circle(-1, -0.6, 0.8, .color(Color(hex: "2A1D0E")))
        b.fill(Path { $0.move(to: CGPoint(x: -2, y: -5)); $0.addQuadCurve(to: CGPoint(x: 3, y: -1), control: CGPoint(x: 4, y: -7)) }, with: .color(tint(26, 50, 30, 0.9)))
        _ = night
    }
}
