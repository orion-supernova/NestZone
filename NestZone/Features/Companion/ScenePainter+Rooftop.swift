import SwiftUI

/// The rooftop: a terrace deck behind a low parapet, three ranks of city beyond
/// it with their windows lit at night, a string of bulbs from pole to pole, and
/// a telescope where the card is wide enough to leave it room. Its stars are
/// the sky's, plus a dusting that does not twinkle (the twinkling ones, and a
/// shooting star now and then, are `sky`'s, per frame).
extension ScenePainter {
    func rooftop(_ context: GraphicsContext) {
        let W = width, c = center, L = lamp.L
        let night = 1 - day
        var r = seed

        // A dusting of fixed stars, and the Milky Way across them.
        if night > 0.2 {
            var dust = Path()
            for _ in 0..<80 {
                let x = r.next() * W, y = 6 + r.next() * 190, size = r.between(0.4, 1.1)
                dust.addEllipse(in: CGRect(x: x, y: y, width: size * 2, height: size * 2))
            }
            context.fill(dust, with: .color(Color.white.opacity(0.55 * night)))
            for (fx, fy, rad) in [(0.2, 150.0, 70.0), (0.38, 112.0, 80), (0.56, 80.0, 90), (0.74, 46.0, 80)] {
                context.glow(W * fx, fy, rad, Ink.color(0xB9A8FF, 0.1 * night))
            }
        }

        // Three ranks of city, far to near. Each is a run of towers with a grid of
        // windows, some lit; a window is a speck by day and a lamp by night.
        let ranks: [(base: Double, tall: ClosedRange<Double>, wide: ClosedRange<Double>, wall: UInt32, lit: Double)] = [
            (304, 70...120, 22...40, 0x9BA3D0, 0.12), (308, 50...96, 26...46, 0x7A82B4, 0.2), (312, 28...64, 30...54, 0x555C92, 0.28),
        ]
        for (index, rank) in ranks.enumerated() {
            var walls = Path(), edges = Path(), dark = Path(), lit = Path(), rooftops = Path()
            var x = -12.0
            while x < W + 12 {
                let w = r.between(rank.wide.lowerBound, rank.wide.upperBound), h = r.between(rank.tall.lowerBound, rank.tall.upperBound)
                let top = rank.base - h
                walls.addRect(CGRect(x: x, y: top, width: w, height: h + 20))
                edges.addRect(CGRect(x: L.x > 0 ? x + w - 1.6 : x, y: top, width: 1.6, height: h + 20))
                if index < 2 {
                    // Windows only on the two ranks that have room for them.
                    var wy = top + 6
                    while wy < rank.base - 6 {
                        var wx = x + 4
                        while wx < x + w - 5 {
                            let cell = CGRect(x: wx, y: wy, width: 3, height: 4)
                            if r.next() < rank.lit { lit.addRect(cell) } else if r.next() < 0.5 { dark.addRect(cell) }
                            wx += 6
                        }
                        wy += 9
                    }
                } else {
                    var wy = top + 7
                    while wy < rank.base - 6 {
                        var wx = x + 5
                        while wx < x + w - 6 {
                            let cell = CGRect(x: wx, y: wy, width: 4, height: 5)
                            if r.next() < rank.lit { lit.addRect(cell) } else { dark.addRect(cell) }
                            wx += 9
                        }
                        wy += 12
                    }
                }
                // The roofline: a water tank on legs, an antenna, or a chimney.
                let roll = r.next()
                if roll < 0.16 {
                    rooftops.addRoundedRect(in: CGRect(x: x + w * 0.2, y: top - 13, width: 11, height: 9), cornerSize: CGSize(width: 2, height: 2))
                    rooftops.addRect(CGRect(x: x + w * 0.2 + 1, y: top - 4, width: 1, height: 4)); rooftops.addRect(CGRect(x: x + w * 0.2 + 9, y: top - 4, width: 1, height: 4))
                    rooftops.move(to: CGPoint(x: x + w * 0.2 - 1, y: top - 13)); rooftops.addLine(to: CGPoint(x: x + w * 0.2 + 5.5, y: top - 17)); rooftops.addLine(to: CGPoint(x: x + w * 0.2 + 12, y: top - 13)); rooftops.closeSubpath()
                } else if roll < 0.32 {
                    rooftops.addRect(CGRect(x: x + w * 0.7, y: top - 8, width: 5, height: 8))
                } else if roll < 0.44 {
                    let ax = x + w * 0.5
                    rooftops.addRect(CGRect(x: ax - 0.5, y: top - 18, width: 1, height: 18))
                    rooftops.addRect(CGRect(x: ax - 4, y: top - 15, width: 8, height: 0.8)); rooftops.addRect(CGRect(x: ax - 3, y: top - 11, width: 6, height: 0.8))
                }
                x += w + r.between(0, 2)
            }
            let wall = hue(rank.wall, dim: 0.95, warm: 0.3)
            context.fill(walls, with: .color(wall.color()))
            context.fill(rooftops, with: .color(wall.shifted(-5).color()))
            context.fill(edges, with: .color(lamp.rim.color(lamp.rimAlpha * 0.5 + 0.05)))
            context.fill(dark, with: .color(wall.shifted(-9).color(0.55)))
            context.fill(lit, with: .color(Ink.color(0xFFD98A, 0.22 + 0.78 * night)))
        }
        // A red light on the tallest tower, as there is on any.
        let beacon = CGPoint(x: W * 0.78, y: 304 - 124)
        context.circle(beacon.x, beacon.y, 1.6, .color(Ink.color(0xFF4A4A, 0.5 + 0.5 * night)))
        if night > 0.3 { context.glow(beacon.x, beacon.y, 12, Ink.color(0xFF4A4A, 0.4 * night)) }

        // The parapet: stucco with a coping stone, its foot in shade.
        let stucco = hue(0x9D93A6, warm: 0.3), coping = hue(0xC4BBCB, warm: 0.3)
        let wall = CGRect(x: 0, y: 302, width: W, height: 22)
        context.fill(Path(wall), with: vertical(stucco.shifted(4), stucco.shifted(-6), in: wall))
        var joints = Path()
        for jx in stride(from: 38.0, through: W, by: 74) { joints.addRect(CGRect(x: jx, y: 304, width: 0.9, height: 18)) }
        context.fill(joints, with: .color(Color.black.opacity(0.1)))
        context.fill(Path(CGRect(x: 0, y: 298, width: W, height: 5)), with: vertical(coping.shifted(8), coping.shifted(-4), in: CGRect(x: 0, y: 298, width: W, height: 5)))
        context.fill(Path(CGRect(x: 0, y: 298, width: W, height: 1.2)), with: .color(lamp.rim.color(lamp.rimAlpha * 0.9 + 0.1)))
        context.fill(Path(CGRect(x: 0, y: 303, width: W, height: 3)), with: .color(Color.black.opacity(0.16)))

        // The deck: boards in perspective, laid across, with staggered joints.
        let board = hue(0x9A7656), boardDark = hue(0x7C5C42)
        let deck = CGRect(x: 0, y: 324, width: W, height: 36)
        context.fill(Path(deck), with: vertical(board, boardDark, in: deck))
        let rows: [Double] = [324, 332, 342, 353, 360]
        var paler = Path(), deeper = Path(), seams = Path(), ticks = Path()
        for j in 0..<4 {
            let rect = CGRect(x: 0, y: rows[j], width: W, height: rows[j + 1] - rows[j])
            if j.isMultiple(of: 2) { paler.addRect(rect) } else { deeper.addRect(rect) }
            seams.move(to: CGPoint(x: 0, y: rows[j])); seams.addLine(to: CGPoint(x: W, y: rows[j]))
            var jx = r.between(0, 70)
            while jx < W {
                ticks.move(to: CGPoint(x: jx, y: rows[j])); ticks.addLine(to: CGPoint(x: jx, y: rows[j + 1]))
                jx += r.between(60, 120)
            }
        }
        context.fill(paler, with: .color(Color.white.opacity(0.06)))
        context.fill(deeper, with: .color(Color.black.opacity(0.06)))
        context.stroke(seams, with: .color(Color.black.opacity(0.28)), lineWidth: 0.9)
        context.stroke(ticks, with: .color(Color.black.opacity(0.2)), lineWidth: 0.7)
        context.fill(Path(CGRect(x: 0, y: 324, width: W, height: 8)), with: .linearGradient(
            Gradient(colors: [Color.black.opacity(0.26), .clear]), startPoint: CGPoint(x: 0, y: 324), endPoint: CGPoint(x: 0, y: 332)))

        // The string of bulbs: two poles on the parapet, a wire that sags between them.
        let pole = hue(0x3A3548), poleLit = hue(0x6C6788)
        for px in [20.0, W - 20] {
            context.fill(Path(roundedRect: CGRect(x: px - 2, y: 142, width: 4, height: 164), cornerRadius: 1.5), with: .linearGradient(
                Gradient(colors: [poleLit.color(), pole.color()]), startPoint: CGPoint(x: px + L.x * 2, y: 0), endPoint: CGPoint(x: px - L.x * 2, y: 0)))
            context.circle(px, 142, 3, .color(pole.shifted(6).color()))
        }
        let a = CGPoint(x: 20, y: 144), b = CGPoint(x: W - 20, y: 144), ctl = CGPoint(x: c, y: 144 + 70)
        var wire = Path()
        wire.move(to: a); wire.addQuadCurve(to: b, control: ctl)
        context.stroke(wire, with: .color(pole.color(0.9)), lineWidth: 0.9)
        let count = max(10, Int(W / 30))
        var bulbs = Path(), shines = Path()
        var glows: [CGPoint] = []
        for i in 1..<count {
            let t = Double(i) / Double(count), u = 1 - t
            let p = CGPoint(x: u * u * a.x + 2 * u * t * ctl.x + t * t * b.x, y: u * u * a.y + 2 * u * t * ctl.y + t * t * b.y + 3)
            bulbs.addEllipse(in: CGRect(x: p.x - 2.4, y: p.y - 3, width: 4.8, height: 6.2))
            shines.addEllipse(in: CGRect(x: p.x - 1.4, y: p.y - 2.2, width: 1.3, height: 2))
            glows.append(p)
        }
        for p in glows { context.glow(p.x, p.y, 16, Ink.color(0xFFC864, 0.1 + 0.42 * night)) }
        context.fill(bulbs, with: .color(Ink.color(0xFFE6A0)))
        context.fill(shines, with: .color(Color.white.opacity(0.9)))

        if W >= 440 { telescope(context, x: c - 178) }
    }

    /// A brass-banded telescope on a tripod, pointed at where the moon rises.
    private func telescope(_ context: GraphicsContext, x: Double) {
        let L = lamp.L
        let navy = hue(0x2F4570, dim: 0.9), navyLit = hue(0x5873A8, dim: 0.9), brass = hue(0xC9A24A, dim: 0.9)
        let foot = 349.0, pivot = CGPoint(x: x, y: 300)
        context.ellipse(x + 2, foot + 0.5, 24, 3.4, .color(SceneInk.shadow))
        var legs = Path()
        for dx in [-17.0, 15, 2] {
            legs.move(to: pivot); legs.addLine(to: CGPoint(x: x + dx, y: foot - (dx == 2 ? -1 : 0)))
        }
        context.stroke(legs, with: .color(navy.shifted(-14).color()), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.stroke(legs, with: .color(navyLit.color(0.55)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        // The mount, and the tube above it, tilted up to the right.
        WearArt.form(context, Path(ellipseIn: CGRect(x: x - 5, y: 295, width: 10, height: 10)), centre: pivot, radius: 5, lamp, navyLit, navy, navy.shifted(-14), highlight: 0.5, core: 0.5)
        var tube = context
        tube.translateBy(x: x, y: 298)
        tube.rotate(by: .radians(-0.95))
        let body = Path(roundedRect: CGRect(x: -22, y: -4.4, width: 52, height: 8.8), cornerRadius: 3)
        tube.fill(body.offsetBy(dx: 0, dy: 2.4), with: .color(Color.black.opacity(0.18)))
        tube.fill(body, with: .linearGradient(
            Gradient(stops: [.init(color: navyLit.color(), location: 0), .init(color: navy.color(), location: 0.5), .init(color: navy.shifted(-14).color(), location: 1)]),
            startPoint: CGPoint(x: 0, y: -4.4), endPoint: CGPoint(x: 0, y: 4.4)))
        var bands = Path()
        for bx in [-16.0, 8, 26] { bands.addRect(CGRect(x: bx, y: -4.8, width: 2.6, height: 9.6)) }
        tube.fill(bands, with: .color(brass.color()))
        tube.fill(Path(roundedRect: CGRect(x: 27, y: -5.6, width: 6, height: 11.2), cornerRadius: 1.5), with: .color(brass.shifted(-8).color()))
        tube.fill(Path(CGRect(x: -22, y: -3.4, width: 52, height: 1.2)), with: .color(Color.white.opacity(0.35)))
        // The eyepiece at the low end, and the finder scope on the back.
        tube.fill(Path(roundedRect: CGRect(x: -29, y: -2.2, width: 8, height: 4.4), cornerRadius: 1.5), with: .color(navy.shifted(-18).color()))
        tube.fill(Path(roundedRect: CGRect(x: -12, y: -9.6, width: 22, height: 3.8), cornerRadius: 1.8), with: .color(navy.color()))
        tube.fill(Path(CGRect(x: -9, y: -6, width: 1.6, height: 2)), with: .color(brass.color()))
        tube.fill(Path(CGRect(x: 5, y: -6, width: 1.6, height: 2)), with: .color(brass.color()))
        // The lens catches the sky.
        tube.fill(Path(ellipseIn: CGRect(x: 31.4, y: -4.4, width: 2.4, height: 8.8)), with: .color(lamp.lifted(RGB(0x9FC8FF), 0.3).color(0.7)))
        _ = L
    }
}
