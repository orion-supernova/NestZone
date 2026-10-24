import SwiftUI

// The column: a ribbed body that swells and rises from a seed, puts out arms
// (the first at .5, the second at .72) and pups at its foot, and flowers from
// the top once it is grown. A cactus is this rule; a snake plant is the same
// body without the ribs and with blades for arms.
//
// It does not droop the way a leafy plant does. A thirsty one shrinks in on
// itself (the ribs deepen, the girth falls), leans, and keeps its flower shut;
// a dozing one is pale and shut.
extension PlantPainter {
    func column(_ c: GraphicsContext?, _ m: inout Marks) {
        let thirst = M.thirst, doze = M.doze, side = seed.side
        let pinch = 1 - 0.16 * thirst - 0.06 * doze
        let height = grown([(0.09, 0), (0.1, 9), (0.12, 15), (0.3, 44), (0.52, 74), (0.76, 98), (0.96, 112)]) * (1 - 0.05 * thirst)
        let r = grown([(0.09, 0), (0.1, 7), (0.12, 9.5), (0.3, 15.5), (0.52, 18.5), (0.76, 20.5), (0.96, 21)]) * (plan.girth / 21) * pinch
        guard height > 4, r > 2 else { return }
        let lean = seed.lean * 0.02 + side * (0.045 * M.wilt)

        // A tired column leans: the whole body is sheared about its foot.
        let shear = CGAffineTransform(a: 1, b: 0, c: -lean, d: 1, tx: 0, ty: 0)
        var plant = c
        plant?.concatenate(shear)
        func sheared(_ point: CGPoint) -> CGPoint { point.applying(shear) }

        let armA = Ink.smooth((p - 0.5) / 0.26), armB = Ink.smooth((p - 0.72) / 0.2)
        let pupA = pop(0.7, over: 0.08), pupB = pop(0.8, over: 0.08)

        // Pups at the foot, behind everything.
        if let plant {
            for (k, pup) in [pupA, pupB].enumerated() where pup > 0.02 {
                let s = k == 0 ? -side : side
                body(plant, x: s * (r + 8 + Double(k) * 2), radius: 5.2 * pup * pinch, height: (12 - Double(k) * 2.5) * pup, ribs: 3, spines: false)
            }
        }
        if pupA > 0.02 { m.note(sheared(CGPoint(x: -side * (r + 8), y: -12)), reach: 5) }
        if pupB > 0.02 { m.note(sheared(CGPoint(x: side * (r + 10), y: -9)), reach: 5) }

        // Arms: an elbow out of the body and then up, grown by trimming its path.
        for (k, arm) in [(armA, (height: 0.5, reach: 17.0, length: 30.0)), (armB, (height: 0.64, reach: 13.0, length: 21.0))].enumerated() {
            guard arm.0 > 0.02, height * arm.1.height > 18 else { continue }
            let s = k == 0 ? side : -side
            let y = -height * arm.1.height
            let outX = s * (r + arm.1.reach), thick = r * (k == 0 ? 0.92 : 0.76)
            let top = y - arm.1.length * arm.0
            var path = Path()
            path.move(to: CGPoint(x: s * r * 0.3, y: y))
            path.addLine(to: CGPoint(x: outX - s * 9, y: y))
            path.addQuadCurve(to: CGPoint(x: outX, y: y - 9), control: CGPoint(x: outX, y: y))
            path.addLine(to: CGPoint(x: outX, y: y - 9 - arm.1.length))
            let whole = 1.0
            let shown = path.trimmedPath(from: 0, to: min(whole, 0.38 + 0.62 * arm.0))
            if let plant {
                plant.stroke(shown, with: .color(ramp[1].shifted(-2).color()), style: StrokeStyle(lineWidth: thick, lineCap: .round, lineJoin: .round))
                plant.stroke(shown, with: .linearGradient(
                    Gradient(colors: [ramp[3].color(), ramp[2].color()]),
                    startPoint: CGPoint(x: outX - thick / 2, y: y), endPoint: CGPoint(x: outX + thick / 2, y: y)),
                             style: StrokeStyle(lineWidth: thick * 0.8, lineCap: .round, lineJoin: .round))
                // A lit stripe up the near side, and the rib on the far side.
                var up = Path()
                up.move(to: CGPoint(x: outX - thick * 0.22, y: y - 8))
                up.addLine(to: CGPoint(x: outX - thick * 0.22, y: top - 6 + 12 * (1 - arm.0)))
                plant.stroke(up.trimmedPath(from: 0, to: arm.0), with: .color(ramp[4].color(0.4)), style: StrokeStyle(lineWidth: thick * 0.16, lineCap: .round))
                var rib = Path()
                rib.move(to: CGPoint(x: outX + thick * 0.2, y: y - 8))
                rib.addLine(to: CGPoint(x: outX + thick * 0.2, y: top - 6 + 12 * (1 - arm.0)))
                plant.stroke(rib.trimmedPath(from: 0, to: arm.0), with: .color(ramp[0].color(0.55)), style: StrokeStyle(lineWidth: 1.1 + thirst, lineCap: .round))
                var spines = Path()
                var yy = y - 8.0
                while yy > top - 2 {
                    Self.areole(&spines, at: CGPoint(x: outX - thick * 0.05, y: yy), scale: 0.85, wide: 1)
                    yy -= 9
                }
                plant.stroke(spines, with: .color(RGB.night(44, 40, 85, day: day, dim: 0.8).color()), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
            }
            m.note(sheared(CGPoint(x: outX, y: top - 4)), reach: thick / 2)
            m.note(sheared(CGPoint(x: outX, y: y - 6)), reach: thick / 2)
        }

        // The body.
        if let plant { body(plant, x: 0, radius: r, height: height, ribs: plan.ribs, spines: true) }
        m.note(sheared(CGPoint(x: -r * 0.9, y: -height * 0.4)), reach: 3)
        m.note(sheared(CGPoint(x: r * 0.9, y: -height * 0.62)), reach: 3)
        m.note(sheared(CGPoint(x: 0, y: -height)), reach: r * 0.5)
        m.left = min(m.left, -r - 4); m.right = max(m.right, r + 4)

        // The flower on top, or its bud.
        let budK = pop(0.7, over: 0.14)
        let openK = Ink.smooth((p - 0.86) / 0.1) * Ink.smooth((M.open - 0.25) / 0.4)
        if budK > 0.02, let flower = plan.flower {
            if let plant { bloomOn(plant, at: CGPoint(x: 0, y: -height + r * 0.15), flower: flower, bud: min(budK, 1), open: openK, radius: r) }
            m.note(sheared(CGPoint(x: 0, y: -height - 16 * max(openK, 0.4))), reach: 8, hang: false)
        }
    }

    /// One ribbed body, from the soil: its shade across, the lit patch, the ribs
    /// as seen round a cylinder (they bunch at the edges), and a tuft of
    /// spines at every rib.
    private func body(_ c: GraphicsContext, x: Double, radius r: Double, height h: Double, ribs: Int, spines: Bool) {
        var c = c
        c.translateBy(x: x, y: 0)
        guard h > r else {
            c.fill(Path(ellipseIn: CGRect(x: -r, y: -h * 0.9, width: r * 2, height: h)), with: .color(ramp[2].color()))
            return
        }
        let stem = h - r
        var body = Path()
        body.move(to: CGPoint(x: -r, y: 3))
        body.addLine(to: CGPoint(x: -r, y: -stem))
        body.addArc(center: CGPoint(x: 0, y: -stem), radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        body.addLine(to: CGPoint(x: r, y: 3))
        body.closeSubpath()
        // A cast shadow on the soil.
        c.fill(body, with: .linearGradient(
            Gradient(stops: [
                .init(color: ramp[3].shifted(2).color(), location: 0), .init(color: ramp[2].color(), location: 0.3),
                .init(color: ramp[1].color(), location: 0.72), .init(color: ramp[0].shifted(3).color(), location: 1),
            ]), startPoint: CGPoint(x: -r, y: 0), endPoint: CGPoint(x: r, y: 0)))
        // The lit patch: a soft column of light up the near side.
        var lit = Path()
        lit.addRoundedRect(in: CGRect(x: -r * 0.78, y: -stem - r * 0.7, width: r * 0.5, height: stem + r * 0.3), cornerSize: CGSize(width: r * 0.25, height: r * 0.25))
        c.fill(lit, with: .linearGradient(Gradient(colors: [ramp[4].color(0.32), ramp[4].color(0)]),
                                           startPoint: CGPoint(x: 0, y: -stem - r * 0.7), endPoint: CGPoint(x: 0, y: -4)))
        // Ribs, round a cylinder.
        var dark = Path(), light = Path()
        let step = Double.pi * 0.74 / Double(max(1, ribs - 1))
        let xs = (0..<ribs).map { r * sin((Double($0) - Double(ribs - 1) / 2) * step * 0.98) }
        for x in xs {
            let top = CGPoint(x: x * 0.12, y: -h + r * 0.12)
            for path in [0, 1] {
                let dx = path == 0 ? 0.0 : -1.3
                var line = Path()
                line.move(to: CGPoint(x: x + dx, y: 2))
                line.addLine(to: CGPoint(x: x + dx, y: -stem))
                line.addQuadCurve(to: CGPoint(x: top.x + dx * 0.2, y: top.y), control: CGPoint(x: x * 0.8 + dx, y: -h + r * 0.08))
                if path == 0 { dark.addPath(line) } else { light.addPath(line) }
            }
        }
        c.stroke(dark, with: .color(ramp[0].shifted(-2).color(0.55 + 0.35 * M.thirst)), style: StrokeStyle(lineWidth: 1.2 + 1.5 * M.thirst, lineCap: .round))
        c.stroke(light, with: .color(ramp[4].color(0.36)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        // Spines: a tuft at every rib's every hand's width, face on in the middle and leaning out at the edges.
        guard spines else { return }
        var tufts = Path(), dots = Path()
        for (i, x) in xs.enumerated() where i > 0 && i < ribs - 1 {
            let face = cos(asin(max(-1, min(1, x / r))))
            var y = 9.0 + (i.isMultiple(of: 2) ? 0 : 6)
            while y < h - r * 0.55 {
                Self.areole(&tufts, at: CGPoint(x: x, y: -y), scale: 1, wide: face)
                dots.addEllipse(in: CGRect(x: x - 1.1, y: -y - 0.8, width: 2.2, height: 1.6))
                y += 12
            }
        }
        // And at the very top, a crown of them.
        let tone = RGB.night(44, 40, 86, day: day, dim: 0.85)
        c.fill(dots, with: .color(RGB.night(36, 50, 52, day: day, dim: 0.8).color(0.9)))
        c.stroke(tufts, with: .color(tone.color(0.95)), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))
    }

    /// One areole's spines, radiating, `wide` narrowing them as the rib turns
    /// from us.
    static func areole(_ path: inout Path, at p: CGPoint, scale s: Double, wide: Double) {
        for a in stride(from: -2.6, through: 0.1, by: 0.55) {
            let len = (4.4 + 1.6 * sin(a * 7)) * s
            path.move(to: p)
            path.addLine(to: CGPoint(x: p.x + cos(a) * len * (0.4 + 0.6 * wide), y: p.y + sin(a) * len * 0.9))
        }
        path.move(to: p)
        path.addLine(to: CGPoint(x: p.x + 0.6 * s, y: p.y + 3.4 * s))
    }

    /// The flower: petals fanning from the top of the body, a back ring and a
    /// front one, stamens between; or a closed bud while it isn't open.
    private func bloomOn(_ c: GraphicsContext, at base: CGPoint, flower: PlantPlan.Flower, bud: Double, open: Double, radius r: Double) {
        var c = c
        c.translateBy(x: base.x, y: base.y)
        let deep = bloom(flower.deep), mid = bloom(flower.mid), pale = bloom(flower.pale), centre = bloom(flower.heart, dim: 0.4)
        let k = Ink.lerp(0.5, 1, open) * bud * 1.3
        // The green the bud is wrapped in.
        var wrap = Path()
        for s in [-1.0, 0, 1] { wrap.leaf(s * 2.4, 2, sin(s * 0.5), -cos(s * 0.5), 7 * k, 2.6 * k, 0.2) }
        if open < 0.35 {
            var shut = Path()
            shut.leaf(0, 3, 0, -1, 15 * k, 4.6 * k, 0.3)
            c.fill(wrap, with: .color(ramp[2].color()))
            c.fill(shut, with: .linearGradient(Gradient(colors: [deep.color(), mid.color(), pale.color()]),
                                               startPoint: CGPoint(x: 0, y: 3), endPoint: CGPoint(x: 0, y: -14 * k)))
            return
        }
        let spread = 0.5 + 0.7 * open
        for ring in [0, 1] {
            var petals = Path()
            let n = ring == 0 ? 7 : 6
            for i in 0..<n {
                let f = n == 1 ? 0 : (Double(i) / Double(n - 1) - 0.5) * 2 * spread * (ring == 0 ? 1.12 : 0.9)
                let a = -Double.pi / 2 + f
                petals.leaf(0, 3, cos(a), sin(a), (ring == 0 ? 17 : 14) * k, 4.8 * k, 0.1)
            }
            let gradient = ring == 0
                ? Gradient(colors: [deep.color(), mid.color(), mid.color()])
                : Gradient(colors: [mid.color(), pale.color(), pale.mix(mid, 0.3).color()])
            c.fill(petals, with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 3), endPoint: CGPoint(x: 0, y: -18 * k)))
        }
        var stamens = Path(), anthers = Path()
        for i in 0..<7 {
            let a = -Double.pi / 2 + (Double(i) / 6 - 0.5) * 1.3
            let len = (7 + 2.5 * sin(Double(i) * 2.1)) * k
            stamens.move(to: CGPoint(x: 0, y: 2))
            stamens.addLine(to: CGPoint(x: cos(a) * len, y: 2 + sin(a) * len))
            anthers.addEllipse(in: CGRect(x: cos(a) * len - 1.1, y: 2 + sin(a) * len - 1.1, width: 2.2, height: 2.2))
        }
        c.stroke(stamens, with: .color(centre.shifted(-6).color(0.8)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        c.fill(anthers, with: .color(centre.color()))
        c.fill(wrap, with: .color(ramp[2].color()))
    }
}
