import SwiftUI

/// Fans of cactus spines in a unit (about five points), built once: nine fine
/// triangles radiating from an areole, three versions so no two neighbours
/// are the same. A body's spines are these, moved and scaled to each areole.
enum SpineArt {
    static let fans: [Path] = (0..<3).map { v in
        var path = Path()
        var r = Ink.Random(seed: UInt32(31 + v))
        let n = 9
        for k in 0..<n {
            let a = (Double(k) + r.next() * 0.7) / Double(n) * .pi * 2
            // A couple of them are longer, as a cluster's central spines are.
            let len = (k % 4 == 0 ? 1.0 : 0.55) + 0.3 * r.next()
            path.spike(from: .zero, to: CGPoint(x: cos(a) * len, y: sin(a) * len * 0.86), width: 0.13)
        }
        return path
    }
}

// The column: a ribbed body that swells and rises from a seed, puts out arms
// (the first at .5, the second at .72) and pups at its foot, and flowers from
// the top once it is grown. A cactus is this rule; a snake plant is the same
// body without the ribs and with blades for arms.
//
// The body is a cylinder: each rib is a band whose tone comes from where it
// faces (a rib turned to the sun is light, one turned away is deep, so the
// light runs across the ribs), the valleys between them are thin dark lenses,
// and the spines are fine fans on an areole at the crest of every rib. The
// flower is waxy: two rings of pointed petals with a glint on each.
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
                body(plant, x: s * (r + 8 + Double(k) * 2), radius: 5.2 * pup * pinch, height: (12 - Double(k) * 2.5) * pup, ribs: 3, spines: false, detail: false, scale: 0.6)
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
            let rise = arm.1.length * arm.0
            if let plant {
                // The elbow: out of the trunk, a bend, and up.
                var line = (0...3).map { CGPoint(x: Ink.lerp(s * r * 0.3, outX - s * 8, Double($0) / 3), y: y) }
                line += Self.quad(CGPoint(x: outX - s * 8, y: y), CGPoint(x: outX, y: y), CGPoint(x: outX, y: y - 8), n: 5).dropFirst()
                let shown = Array(line.prefix(max(3, Int((0.4 + 0.6 * arm.0) * Double(line.count)))))
                let elbow = Self.ribbon(shown, thick * 0.84, thick * 0.84)
                plant.fill(elbow, with: .linearGradient(Gradient(colors: [ramp[3].color(), ramp[2].color(), ramp[1].color()]),
                                                        startPoint: CGPoint(x: 0, y: y - thick / 2), endPoint: CGPoint(x: 0, y: y + thick / 2)))
                if rise > 5 {
                    body(plant, x: outX, base: y - 6, radius: thick / 2, height: rise + 5, ribs: 3, spines: true, detail: false, scale: 0.8)
                }
            }
            m.note(sheared(CGPoint(x: outX, y: y - 8 - rise)), reach: thick / 2)
            m.note(sheared(CGPoint(x: outX, y: y - 6)), reach: thick / 2)
        }

        // The body.
        if let plant { body(plant, x: 0, radius: r, height: height, ribs: plan.ribs, spines: true, detail: true) }
        m.note(sheared(CGPoint(x: -r * 0.9, y: -height * 0.4)), reach: 3)
        m.note(sheared(CGPoint(x: r * 0.9, y: -height * 0.62)), reach: 3)
        m.note(sheared(CGPoint(x: 0, y: -height)), reach: r * 0.5)
        m.left = min(m.left, -r - 4); m.right = max(m.right, r + 4)

        // The flower on top, or its bud.
        let budK = pop(0.7, over: 0.14)
        let openK = Ink.smooth((p - 0.86) / 0.1) * Ink.smooth((M.open - 0.25) / 0.4)
        if budK > 0.02, let flower = plan.flower {
            if let plant { bloomOn(plant, at: CGPoint(x: 0, y: -height + r * 0.15), flower: flower, bud: min(budK, 1), open: openK) }
            m.note(sheared(CGPoint(x: 0, y: -height - 16 * max(openK, 0.4))), reach: 8, hang: false)
        }
    }

    /// One ribbed body, from the soil. The ribs tile the half of the cylinder we
    /// see, each a vertical band whose tone is its angle to the light; between
    /// them are the valleys, down the crests run the lit edges, and an areole
    /// sits at every crest's every hand's width with its fan of spines.
    private func body(_ c: GraphicsContext, x: Double, base: Double = 0, radius r: Double, height h: Double, ribs: Int, spines: Bool,
                      detail: Bool, scale sc: Double = 1) {
        var c = c
        c.translateBy(x: x, y: base)
        guard h > r else {
            c.fill(Path(ellipseIn: CGRect(x: -r, y: -h * 0.9, width: r * 2, height: h)), with: .color(ramp[2].color()))
            return
        }
        let stem = h - r
        let side = L.x >= 0 ? 1.0 : -1.0
        func top(_ x: Double) -> Double { -stem - max(0, r * r - x * x).squareRoot() }
        var body = Path()
        body.move(to: CGPoint(x: -r, y: 3))
        body.addLine(to: CGPoint(x: -r, y: -stem))
        body.addArc(center: CGPoint(x: 0, y: -stem), radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        body.addLine(to: CGPoint(x: r, y: 3))
        body.closeSubpath()

        // The tones: the shade, the middle, the lit and the sunstruck.
        let d = ramp[0].mix(ramp[1], 0.5).shifted(1), mid = ramp[1].mix(ramp[2], 0.7)
        let lit = ramp[2].mix(ramp[3], 0.6), sun = ramp[3].mix(ramp[4], 0.35).mix(glow, 0.12 * (1 - night))
        c.fill(body, with: .color(d.color()))

        // Ribs: the half of the cylinder in front tiled in bands.
        let n = max(2, ribs)
        var classes = [Path(), Path(), Path()]
        var valleys = Path(), crests = Path()
        var crestBright: [Double] = []
        for i in 0..<n {
            let l = -Double.pi / 2 + Double(i) * .pi / Double(n), rr = l + .pi / Double(n), mid = (l + rr) / 2
            let xl = r * sin(l), xr = r * sin(rr), xc = r * sin(mid)
            let b = 0.5 + 0.55 * (sin(mid) * L.x * 0.8 + cos(mid) * 0.42) - 0.08 * M.doze
            crestBright.append(b)
            let k = b < 0.3 ? -1 : b < 0.52 ? 0 : b < 0.74 ? 1 : 2
            if k >= 0 {
                var band = Path()
                band.move(to: CGPoint(x: xl, y: 3))
                for t in 0...4 {
                    let bx = Ink.lerp(xl, xr, Double(t) / 4)
                    band.addLine(to: CGPoint(x: bx, y: top(bx)))
                }
                band.addLine(to: CGPoint(x: xr, y: 3))
                band.closeSubpath()
                classes[k].addPath(band)
            }
            if i > 0 {
                valleys.lens(from: CGPoint(x: xl, y: 2), to: CGPoint(x: xl, y: top(xl) + 0.5), width: 1.0 + 1.5 * M.thirst)
            }
            if detail, b > 0.5 {
                crests.lens(from: CGPoint(x: xc, y: -1), to: CGPoint(x: xc, y: top(xc) + r * 0.2), width: 0.9)
            }
        }
        c.fill(classes[0], with: .color(mid.color()))
        c.fill(classes[1], with: .color(lit.color()))
        c.fill(classes[2], with: .color(sun.color()))
        c.fill(valleys, with: .color(ramp[0].shifted(-3).color(0.5 + 0.35 * M.thirst)))
        if detail {
            // The ground's shade at the foot, the crests' light, a waxy sheen and the sun's rim.
            c.fill(Path(CGRect(x: -r, y: -stem * 0.3, width: r * 2, height: stem * 0.3 + 3)),
                   with: .linearGradient(Gradient(colors: [ramp[0].color(0), ramp[0].shifted(-4).color(0.5)]),
                                         startPoint: CGPoint(x: 0, y: -stem * 0.3), endPoint: CGPoint(x: 0, y: 3)))
            c.fill(crests, with: .color(ramp[4].mix(glow, 0.2).color(0.3 - 0.12 * M.thirst)))
            var sheen = Path(), rim = Path()
            sheen.lens(from: CGPoint(x: side * r * 0.45, y: -stem * 0.1), to: CGPoint(x: side * r * 0.45, y: -stem * 0.86), width: r * 0.3)
            c.fill(sheen, with: .color(Color.white.opacity(0.13 * (1 - 0.5 * night))))
            rim.lens(from: CGPoint(x: side * r * 0.95, y: -2), to: CGPoint(x: side * r * 0.95, y: -stem - r * 0.3), width: 1.3)
            c.fill(rim, with: .color(rimTone.color(0.3 + 0.3 * dusk + 0.2 * moon)))
        }

        guard spines else { return }
        // Areoles at every crest and a fan of spines on each, face on in the
        // middle of the body and leaning out at its edges.
        var pads = Path(), lit1 = Path(), shade1 = Path()
        for i in 0..<n {
            let mid = -Double.pi / 2 + (Double(i) + 0.5) * .pi / Double(n)
            let xc = r * sin(mid), face = cos(mid)
            var y = 8.0 * sc + (i.isMultiple(of: 2) ? 0 : 6 * sc)
            var row = 0
            while y < h - r * 0.5 {
                let at = CGPoint(x: xc, y: -y)
                pads.addEllipse(in: CGRect(x: at.x - 1.5 * sc * (0.5 + 0.5 * face), y: at.y - 1.1 * sc, width: 3 * sc * (0.5 + 0.5 * face), height: 2.2 * sc))
                let t = CGAffineTransform(translationX: at.x, y: at.y).scaledBy(x: 4.4 * sc * (0.5 + 0.5 * face), y: 4.4 * sc)
                if crestBright[i] > 0.48 { lit1.addPath(SpineArt.fans[(i + row) % 3], transform: t) } else { shade1.addPath(SpineArt.fans[(i + row) % 3], transform: t) }
                y += 12.5 * sc
                row += 1
            }
        }
        // And a crown of them at the very top.
        pads.addEllipse(in: CGRect(x: -2, y: top(0) + 0.5, width: 4, height: 2.6))
        lit1.addPath(SpineArt.fans[1], transform: CGAffineTransform(translationX: 0, y: top(0) + 1.8).scaledBy(x: 6 * sc, y: 6 * sc))
        let tone = RGB.tone(plan.spine, day: day, dim: 0.85)
        c.fill(pads, with: .color(RGB.night(40, 36, 78, day: day, dim: 0.85).mix(ramp[1], 0.12).color(0.95)))
        c.fill(shade1, with: .color(tone.mix(ramp[1], 0.4).color(0.9)))
        c.fill(lit1, with: .color(tone.mix(ramp[2], 0.12).color(0.9)))
    }

    /// The flower: two rings of pointed, waxy petals fanning from the top of the
    /// body, each with a glint on its lit side, a ring of stamens between; or
    /// a closed bud while it isn't open.
    private func bloomOn(_ c: GraphicsContext, at base: CGPoint, flower: PlantPlan.Flower, bud: Double, open: Double) {
        var c = c
        c.translateBy(x: base.x, y: base.y)
        let deep = bloom(flower.deep), mid = bloom(flower.mid), pale = bloom(flower.pale), centre = bloom(flower.heart, dim: 0.4)
        let k = Ink.lerp(0.5, 1, open) * bud * 1.5
        let shape = LeafShape.of(.tepal)
        // The green the bud is wrapped in.
        var wrap = Path()
        for s in [-1.0, 0, 1] { wrap.leaf(s * 2.4, 2, sin(s * 0.5), -cos(s * 0.5), 3.6 * k, 1.5 * k, 0.2) }
        if open < 0.35 {
            var back = Path(), front = Path(), streak = Path()
            for (i, lean) in [-0.34, 0.34, 0.0].enumerated() {
                let t = CGAffineTransform(translationX: lean * 5, y: 3).rotated(by: -.pi / 2 + lean).scaledBy(x: 15 * k, y: 8.4 * k)
                if i < 2 { back.addPath(shape.outline, transform: t) } else { front.addPath(shape.outline, transform: t) }
                if i == 2 { streak.addPath(L.x >= 0 ? shape.glossA : shape.glossB, transform: t) }
            }
            c.fill(wrap, with: .color(ramp[2].color()))
            c.fill(back, with: .color(deep.color()))
            c.fill(front, with: .linearGradient(Gradient(colors: [deep.mix(mid, 0.3).color(), mid.color(), pale.color()]),
                                                startPoint: CGPoint(x: 0, y: 3), endPoint: CGPoint(x: 0, y: -14 * k)))
            c.fill(streak, with: .color(Color.white.opacity(0.4)))
            return
        }
        let spread = 0.34 + 0.5 * open
        var litHalf = Path(), shadeHalf = Path(), glints = Path(), creases = Path()
        for ring in 0..<2 {
            var petals = Path()
            let n = ring == 0 ? 9 : 8
            for i in 0..<n {
                let f = (Double(i) / Double(n - 1) - 0.5) * 2 * spread * (ring == 0 ? 1.15 : 0.9)
                let a = -Double.pi / 2 + f
                let len = (ring == 0 ? 18 : 14.5) * k * seed.between(i + 5 * ring, 0.92, 1.08)
                let t = CGAffineTransform(translationX: 0, y: 3).rotated(by: a).scaledBy(x: len, y: len * 0.42)
                petals.addPath(shape.outline, transform: t)
                let toward = -sin(a) * L.x + cos(a) * L.y
                litHalf.addPath(toward >= 0 ? shape.sideA : shape.sideB, transform: t)
                shadeHalf.addPath(toward >= 0 ? shape.sideB : shape.sideA, transform: t)
                if toward > -0.1 { glints.addPath(toward >= 0 ? shape.glossA : shape.glossB, transform: t) }
                creases.addPath(shape.veins, transform: t)
            }
            let gradient = ring == 0
                ? Gradient(colors: [deep.color(), mid.color(), mid.color()])
                : Gradient(colors: [mid.color(), pale.color(), pale.mix(mid, 0.3).color()])
            c.fill(petals, with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 3), endPoint: CGPoint(x: 0, y: -18 * k)))
        }
        c.fill(shadeHalf, with: .color(deep.shifted(-8).color(0.28)))
        c.fill(litHalf, with: .color(pale.mix(glow, 0.3 * (1 - night)).color(0.3)))
        c.fill(creases, with: .color(deep.color(0.32)))
        // Waxy: a thin bright streak on the lit side of each petal.
        c.fill(glints, with: .color(Color.white.opacity(0.5 * (1 - 0.4 * night))))
        var stamens = Path(), anthers = Path()
        for i in 0..<13 {
            let a = -Double.pi / 2 + (Double(i) / 12 - 0.5) * 1.4
            let len = (7 + 2.6 * sin(Double(i) * 2.1)) * k
            let tip = CGPoint(x: cos(a) * len, y: 2 + sin(a) * len)
            stamens.spike(from: CGPoint(x: 0, y: 2), to: tip, width: 0.7)
            anthers.addEllipse(in: CGRect(x: tip.x - 1.1, y: tip.y - 1.1, width: 2.2, height: 2.2))
        }
        c.fill(stamens, with: .color(centre.shifted(-6).color(0.85)))
        c.fill(anthers, with: .color(centre.color()))
        c.fill(wrap, with: .color(ramp[2].color()))
    }
}
