import SwiftUI

/// The balcony: a view over hills, rooftops and a park, behind a wrought-iron
/// railing, with a flower box on the rail and tiles under the companion's feet.
extension ScenePainter {
    func balcony(_ context: GraphicsContext) {
        let W = width, c = center, L = lamp.L
        let night = 1 - day
        var r = seed
        let railTop = 232.0, railFoot = 322.0

        // Far hills, hazy: two long swells in the colour of distance.
        let haze = hue(0xB3C3DE, warm: 0.3), far = hue(0xC6D2E8, warm: 0.3)
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: 330))
        for x in stride(from: 0.0, through: W, by: 8) { hills.addLine(to: CGPoint(x: x, y: 248 - sin(x * 0.011 + 1) * 11 - sin(x * 0.027 + 2) * 5)) }
        hills.addLine(to: CGPoint(x: W, y: 330)); hills.closeSubpath()
        context.fill(hills, with: vertical(far, haze, in: CGRect(x: 0, y: 230, width: W, height: 100)))
        var ridge = Path()
        ridge.move(to: CGPoint(x: 0, y: 330))
        for x in stride(from: 0.0, through: W, by: 8) { ridge.addLine(to: CGPoint(x: x, y: 262 - sin(x * 0.017 + 4) * 9 - sin(x * 0.041) * 4)) }
        ridge.addLine(to: CGPoint(x: W, y: 330)); ridge.closeSubpath()
        context.fill(ridge, with: vertical(hue(0x9FB3A3, warm: 0.3), hue(0x8DA597, warm: 0.3), in: CGRect(x: 0, y: 250, width: W, height: 80)))

        // The street's rooftops on the left, a park on the right.
        let parkFrom = W * 0.6
        var x = -10.0
        var wallsA = Path(), wallsB = Path(), roofs = Path(), darkWindows = Path(), litWindows = Path()
        while x < parkFrom {
            let w = r.between(22, 44), h = r.between(28, 62), top = 300 - h
            let rect = CGRect(x: x, y: top, width: w, height: h + 24)
            if r.next() < 0.5 { wallsA.addRect(rect) } else { wallsB.addRect(rect) }
            // A pitched roof on some, a flat one with a tank or a chimney on others.
            if r.next() < 0.55 {
                roofs.move(to: CGPoint(x: x - 2, y: top)); roofs.addLine(to: CGPoint(x: x + w / 2, y: top - w * 0.3)); roofs.addLine(to: CGPoint(x: x + w + 2, y: top)); roofs.closeSubpath()
            } else if r.next() < 0.5 {
                roofs.addRect(CGRect(x: x + w * 0.62, y: top - 9, width: 5, height: 9))
            }
            var wy = top + 5
            while wy < 292 {
                var wx = x + 4
                while wx < x + w - 5 {
                    let rect = CGRect(x: wx, y: wy, width: 4, height: 5.4)
                    if r.next() < 0.3 { litWindows.addRect(rect) } else { darkWindows.addRect(rect) }
                    wx += 8
                }
                wy += 11
            }
            x += w + r.between(0, 3)
        }
        context.fill(wallsA, with: .color(hue(0xA0AECB, warm: 0.3).color()))
        context.fill(wallsB, with: .color(hue(0x93A2C2, warm: 0.3).color()))
        context.fill(roofs, with: .color(hue(0x8A7F9A, warm: 0.3).color()))
        context.fill(darkWindows, with: .color(hue(0x6F7FA8).color(0.45)))
        context.fill(litWindows, with: .color(Ink.color(0xFFD98A, 0.3 + 0.7 * night)))
        // The park: round crowns in three greens, trunks between them.
        var crownsA = Path(), crownsB = Path(), crownsC = Path(), trunks = Path()
        var tx = parkFrom - 6
        while tx < W + 20 {
            let rad = r.between(15, 24), ty = 276 - r.between(0, 14)
            trunks.addRect(CGRect(x: tx - 1.6, y: ty, width: 3.2, height: 40))
            crownsA.addEllipse(in: CGRect(x: tx - rad, y: ty - rad, width: rad * 2, height: rad * 1.7))
            crownsB.addEllipse(in: CGRect(x: tx - rad * 0.7 + L.x * 3, y: ty - rad * 0.95, width: rad * 1.3, height: rad))
            crownsC.addEllipse(in: CGRect(x: tx - rad * 0.3 + L.x * 6, y: ty - rad * 0.9, width: rad * 0.6, height: rad * 0.5))
            tx += r.between(26, 38)
        }
        context.fill(trunks, with: .color(hue(0x5C4636).color()))
        context.fill(crownsA, with: .color(hue(0x4F8A5E, warm: 0.3).color()))
        context.fill(crownsB, with: .color(hue(0x6BA877, warm: 0.3).color()))
        context.fill(crownsC, with: .color(hue(0x93CC8C, warm: 0.3).color(0.8)))
        // Street level, in shadow, under the lot.
        context.fill(Path(CGRect(x: 0, y: 296, width: W, height: 30)), with: vertical(hue(0x6F7FA5).shifted(-4), hue(0x4F5C80), in: CGRect(x: 0, y: 296, width: W, height: 30)))

        // The floor: terracotta tiles in perspective, lighter at the rail than at the viewer.
        let floorTop = railFoot, tile = hue(0xD79B72), tileDark = hue(0xBC7A55)
        let floorRect = CGRect(x: 0, y: floorTop, width: W, height: 360 - floorTop)
        context.fill(Path(floorRect), with: vertical(tile, tileDark, in: floorRect))
        let rowsY: [Double] = [floorTop, floorTop + 9, floorTop + 20, 360]
        func tileX(_ i: Int, _ y: Double) -> Double { c + Double(i) * 54 * (1 + 0.42 * (y - floorTop) / (360 - floorTop)) }
        var paler = Path(), deeper = Path(), joints = Path()
        for j in 0..<3 {
            for i in -8..<8 {
                let quad = Path { p in
                    p.move(to: CGPoint(x: tileX(i, rowsY[j]), y: rowsY[j])); p.addLine(to: CGPoint(x: tileX(i + 1, rowsY[j]), y: rowsY[j]))
                    p.addLine(to: CGPoint(x: tileX(i + 1, rowsY[j + 1]), y: rowsY[j + 1])); p.addLine(to: CGPoint(x: tileX(i, rowsY[j + 1]), y: rowsY[j + 1])); p.closeSubpath()
                }
                let roll = r.next()
                if roll < 0.25 { paler.addPath(quad) } else if roll < 0.5 { deeper.addPath(quad) }
            }
            joints.move(to: CGPoint(x: 0, y: rowsY[j])); joints.addLine(to: CGPoint(x: W, y: rowsY[j]))
        }
        for i in -8...8 { joints.move(to: CGPoint(x: tileX(i, floorTop), y: floorTop)); joints.addLine(to: CGPoint(x: tileX(i, 360), y: 360)) }
        context.fill(paler, with: .color(Color.white.opacity(0.1)))
        context.fill(deeper, with: .color(Color.black.opacity(0.07)))
        context.stroke(joints, with: .color(hue(0x8E5436).color(0.45)), lineWidth: 0.9)
        // The railing's shadow on the tiles, thrown away from the light.
        var thrown = Path()
        let drift = -L.x * 16
        for bx in stride(from: 12.0, through: W - 12, by: 17) {
            thrown.move(to: CGPoint(x: bx - 1.3, y: floorTop)); thrown.addLine(to: CGPoint(x: bx + 1.3, y: floorTop))
            thrown.addLine(to: CGPoint(x: bx + 1.3 + drift, y: floorTop + 17)); thrown.addLine(to: CGPoint(x: bx - 1.3 + drift, y: floorTop + 17)); thrown.closeSubpath()
        }
        context.fill(thrown, with: .color(Color.black.opacity(0.11)))
        context.fill(Path(CGRect(x: 0, y: floorTop, width: W, height: 5)), with: .linearGradient(
            Gradient(colors: [Color.black.opacity(0.22), .clear]), startPoint: CGPoint(x: 0, y: floorTop), endPoint: CGPoint(x: 0, y: floorTop + 5)))

        // The railing: iron, with a ring in every bay, posts with ball caps.
        let iron = hue(0x3F4A5A, warm: 0.15), ironLit = hue(0x6A7A92, warm: 0.15)
        var bars = Path(), litBars = Path(), rings = Path()
        for bx in stride(from: 12.0, through: W - 12, by: 17) {
            bars.addRect(CGRect(x: bx - 1.3, y: railTop + 6, width: 2.6, height: railFoot - railTop - 8))
            litBars.addRect(CGRect(x: bx + (L.x > 0 ? 0.3 : -1.3), y: railTop + 6, width: 1, height: railFoot - railTop - 8))
            rings.addEllipse(in: CGRect(x: bx + 1.3, y: 268, width: 14.4, height: 14.4))
        }
        context.fill(bars, with: .color(iron.color(0.94)))
        context.stroke(rings, with: .color(iron.color(0.85)), lineWidth: 1.5)
        context.fill(litBars, with: .color(ironLit.color(0.65)))
        for (y, h) in [(railTop, 8.0), (railFoot - 8, 6.0)] {
            let rail = Path(roundedRect: CGRect(x: 0, y: y, width: W, height: h), cornerRadius: 3)
            context.fill(rail.offsetBy(dx: 0, dy: 2), with: .color(Color.black.opacity(0.14)))
            context.fill(rail, with: vertical(ironLit.shifted(4), iron, in: CGRect(x: 0, y: y, width: W, height: h)))
            context.fill(Path(CGRect(x: 0, y: y + 0.8, width: W, height: 1)), with: .color(lamp.rim.color(lamp.rimAlpha * 0.9 + 0.1)))
        }
        for px in [8.0, W - 8] {
            context.fill(Path(roundedRect: CGRect(x: px - 5, y: railTop - 6, width: 10, height: railFoot - railTop + 8), cornerRadius: 2), with: .linearGradient(
                Gradient(colors: [ironLit.color(), iron.color(), iron.shifted(-8).color()]),
                startPoint: CGPoint(x: px + L.x * 5, y: 0), endPoint: CGPoint(x: px - L.x * 5, y: 0)))
            WearArt.form(context, Path(ellipseIn: CGRect(x: px - 6.5, y: railTop - 17, width: 13, height: 13)), centre: CGPoint(x: px, y: railTop - 10.5), radius: 6.5, lamp, ironLit.mix(RGB(255, 255, 255), 0.2), ironLit, iron, highlight: 0.6, core: 0.5)
        }

        flowerBox(context, x: W - 110, rail: railTop)
        _ = night
    }

    /// A box of geraniums on the rail: slatted wood, a mound of leaves, clusters
    /// of red and pink flowers, and strands of ivy hanging over the front.
    private func flowerBox(_ context: GraphicsContext, x: Double, rail: Double) {
        var r = Ink.Random("box-" + String(Int(x)))
        let L = lamp.L
        let wood = hue(0x9A6A44), woodDark = hue(0x6F4A2E)
        let box = CGRect(x: x, y: rail - 22, width: 72, height: 22)
        context.fill(Path(roundedRect: box.offsetBy(dx: 1.5, dy: 2.5), cornerRadius: 2), with: .color(Color.black.opacity(0.16)))
        // The mound first, so the box's lip overlaps its foot.
        var leavesA = Path(), leavesB = Path(), leavesC = Path()
        for _ in 0..<26 {
            let lx = x + r.between(4, 68), ly = box.minY - r.between(-2, 22) * (1 - abs(lx - (x + 36)) / 46)
            let rad = r.between(4.5, 8)
            let blob = CGRect(x: lx - rad, y: ly - rad * 0.8, width: rad * 2, height: rad * 1.6)
            switch Int(r.next() * 3) { case 0: leavesA.addEllipse(in: blob); case 1: leavesB.addEllipse(in: blob.offsetBy(dx: L.x * 1.2, dy: -1)); default: leavesC.addEllipse(in: blob.insetBy(dx: 1.5, dy: 1.2).offsetBy(dx: L.x * 2.2, dy: -2)) }
        }
        context.fill(leavesA, with: .color(hue(0x2F6B3A).color()))
        context.fill(leavesB, with: .color(hue(0x3F8F4B).color()))
        context.fill(leavesC, with: .color(hue(0x6BBF6A).color(0.9)))
        var red = Path(), pink = Path(), deep = Path(), eyes = Path()
        for k in 0..<9 {
            let fx = x + 8 + Double(k) * 7.2 + r.between(-2, 2), fy = box.minY - 6 - r.between(0, 14) * (1 - abs(fx - (x + 36)) / 44)
            for p in 0..<6 {
                let a = Double(p) / 6 * .pi * 2 + Double(k)
                let petal = CGRect(x: fx + cos(a) * 2.7 - 1.7, y: fy + sin(a) * 2.5 - 1.7, width: 3.4, height: 3.4)
                if k % 3 == 0 { pink.addEllipse(in: petal) } else { red.addEllipse(in: petal) }
            }
            deep.addEllipse(in: CGRect(x: fx - 2, y: fy - 2, width: 4, height: 4))
            eyes.addEllipse(in: CGRect(x: fx - 0.9, y: fy - 0.9, width: 1.8, height: 1.8))
        }
        context.fill(red, with: .color(hue(0xE5483D).color()))
        context.fill(pink, with: .color(hue(0xF27BA4).color()))
        context.fill(deep, with: .color(hue(0xB82E2E).color(0.55)))
        context.fill(eyes, with: .color(hue(0xFFD86B).color()))
        // The box: two slats, the lit top edge, the shade under the lip.
        context.fill(Path(roundedRect: box, cornerRadius: 2), with: .linearGradient(
            Gradient(colors: [hue(0xB07C52).color(), wood.color(), woodDark.color()]), startPoint: CGPoint(x: 0, y: box.minY), endPoint: CGPoint(x: 0, y: box.maxY)))
        context.fill(Path(CGRect(x: box.minX, y: box.minY + 10.4, width: box.width, height: 1.4)), with: .color(woodDark.color(0.55)))
        context.fill(Path(CGRect(x: box.minX, y: box.minY, width: box.width, height: 3)), with: .color(Color.black.opacity(0.18)))
        context.fill(Path(CGRect(x: box.minX + 1, y: box.minY + 3, width: box.width - 2, height: 1)), with: .color(lamp.rim.color(lamp.rimAlpha * 0.9 + 0.1)))
        var screws = Path()
        for sx in [box.minX + 5, box.maxX - 5] { for sy in [box.minY + 6.5, box.minY + 16.5] { screws.addEllipse(in: CGRect(x: sx - 1, y: sy - 1, width: 2, height: 2)) } }
        context.fill(screws, with: .color(hue(0xC9A24A).color(0.9)))
        // Ivy over the front.
        var strands = Path(), ivy = Path()
        for sx in [x + 10, x + 31, x + 55] {
            let len = r.between(14, 26)
            strands.move(to: CGPoint(x: sx, y: box.minY + 4))
            strands.addQuadCurve(to: CGPoint(x: sx + L.x * -2, y: box.minY + 4 + len), control: CGPoint(x: sx + 3, y: box.minY + 4 + len * 0.5))
            for t in stride(from: 0.2, through: 1.0, by: 0.2) { ivy.addEllipse(in: CGRect(x: sx - 1.6 + sin(t * 9) * 2, y: box.minY + 4 + len * t - 1.6, width: 3.6, height: 3)) }
        }
        context.stroke(strands, with: .color(hue(0x2F6B3A).color()), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        context.fill(ivy, with: .color(hue(0x4E9B58).color()))
    }
}
