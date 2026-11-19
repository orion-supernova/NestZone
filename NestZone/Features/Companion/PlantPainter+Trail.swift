import SwiftUI

// The trail: a vine that climbs a little and then creeps, over the pot's rim
// and down its side, with big lobed leaves on long stalks, tendrils that curl
// round nothing, a yellow trumpet flower and, at the foot, the fruit. A pumpkin
// is this rule; a squash or a melon would be the same vine with another fruit.
//
// The fruit is a ribbed globe built the way the cactus's body is: bands between
// meridians, each toned by the angle it faces the sun, with a dark valley
// between, so the light runs across the ribs. It starts green and small under
// the flower and ripens to orange as it grows.
//
// Growth: the seed (flat, pale), two seed leaves (.1), the vine (.12 to .7),
// leaves as it reaches them, tendrils, the flower (.62 bud, .74 open), the
// fruit swelling (.78 to .97, green to orange). A thirsty one is the thing
// everyone knows: the big leaves hang limp from their stalks and the vine
// sags; a dozing one is the same at 55%, with the flower shut.
extension PlantPainter {
    private struct Run {
        var points: [CGPoint]
        var born, span, width: Double
    }

    private struct Foliage {
        var run: Int
        var t, born, length, lift: Double
        var side: Double
        var tier: Int
        var stalk: Double
    }

    func trail(_ c: GraphicsContext?, _ m: inout Marks) {
        guard let flower = plan.flower else { return }
        let sx = seed.side, wilt = self.wilt
        func v(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y) }
        let sag = 1 + 0.25 * wilt
        // Two runs: the main vine up, over and down the right; a second out to
        // the left. Each is one sampled curve, grown by trimming.
        let mainWhole = Self.cubic(v(0, 1), v(-4, -34), v(22, -70), v(54, -62 * sag), n: 12)
            + Self.cubic(v(54, -62 * sag), v(84, -54 * sag), v(100, -6 * sag), v(90, 36), n: 12).dropFirst()
        let leftWhole = Self.cubic(v(-3, 1), v(-26, -24), v(-62, -36 * sag), v(-88, -8), n: 10)
            + Self.cubic(v(-88, -8), v(-100, 6), v(-98, 22), v(-92, 38), n: 8).dropFirst()
        let runs = [Run(points: Array(mainWhole), born: 0.12, span: 0.58, width: 4.6), Run(points: Array(leftWhole), born: 0.3, span: 0.46, width: 3.6)]
        func reach(_ i: Int) -> Double {
            i == 0 ? grown([(0.09, 0), (0.12, 0.08), (0.3, 0.3), (0.5, 0.62), (0.7, 1)]) : Ink.smooth((p - runs[i].born) / runs[i].span)
        }
        func trimmed(_ i: Int) -> [CGPoint] {
            let all = runs[i].points, r = max(0.02, reach(i))
            let n = max(2, Int(Double(all.count - 1) * r))
            return Array(all.prefix(n + 1))
        }
        let paths = runs.indices.map { trimmed($0) }

        let foliage = [
            Foliage(run: 1, t: 0.3, born: 0.4, length: 1.0, lift: 1.0, side: -1, tier: 0, stalk: 22),
            Foliage(run: 0, t: 0.2, born: 0.2, length: 0.9, lift: 1.1, side: -1, tier: 1, stalk: 22),
            Foliage(run: 0, t: 0.38, born: 0.3, length: 1.08, lift: 0.9, side: 1, tier: 1, stalk: 28),
            Foliage(run: 1, t: 0.62, born: 0.5, length: 0.95, lift: 0.7, side: -1, tier: 0, stalk: 24),
            Foliage(run: 0, t: 0.56, born: 0.42, length: 1.0, lift: 0.8, side: 1, tier: 2, stalk: 24),
            Foliage(run: 0, t: 0.74, born: 0.54, length: 0.84, lift: 0.4, side: 1, tier: 2, stalk: 16),
            Foliage(run: 0, t: 0.9, born: 0.62, length: 0.7, lift: 0.1, side: -1, tier: 2, stalk: 14),
        ]
        var batches = [LeafBatch(), LeafBatch(), LeafBatch()]
        var stalks = Path()

        // The seed leaves: a pair of plain ovals that the true leaves outgrow.
        let seedLeaf = pop(0.1, over: 0.06) * (1 - Ink.smooth((p - 0.34) / 0.12))
        if seedLeaf > 0.02 {
            for s in [-1.0, 1.0] {
                let angle = (s > 0 ? -0.3 : -.pi + 0.3) + s * wilt * 0.9
                if c != nil { batches[2].add(.of(.ovate, bend: s * 0.3), base: CGPoint(x: 0, y: -3), angle: angle, length: 22 * seedLeaf, light: L, bright: 0.6, glossy: true) }
                m.note(CGPoint(x: cos(angle) * 20 * seedLeaf, y: -3 + sin(angle) * 20 * seedLeaf))
            }
        }

        for (n, f) in foliage.enumerated() {
            let k = pop(f.born, over: 0.12)
            let r = reach(f.run)
            guard k > 0.02, r >= f.t - 0.001 else { continue }
            let path = paths[f.run]
            let at = Self.along(path, f.t / max(0.001, r))
            let s = f.side * sx
            // On a long stalk, up and out; and when tired it hangs from the stalk.
            let stalkAngle = (s > 0 ? -f.lift : -.pi + f.lift) + s * wilt * 1.5
            let stalkLen = f.stalk * k
            let end = CGPoint(x: at.x + cos(stalkAngle) * stalkLen, y: at.y + sin(stalkAngle) * stalkLen)
            let leafAngle = (s > 0 ? -0.55 : -.pi + 0.55) + s * wilt * 1.5
            let length = plan.leafLength * f.length * k * (1 - 0.1 * wilt) * seed.between(n, 0.94, 1.06)
            if c != nil {
                stalks.addPath(Self.ribbon([at, CGPoint(x: (at.x + end.x) / 2 + s * 1.5, y: (at.y + end.y) / 2 - 2), end], 2.8, 2.0))
                batches[f.tier].add(.of(.palmate, bend: s * (0.35 + 0.5 * wilt)), base: end, angle: leafAngle, length: length, light: L,
                                    bright: bright(leafAngle, luck: luck(n + 14), tier: f.tier), glossy: true)
            }
            m.note(CGPoint(x: end.x + cos(leafAngle) * length * 0.7, y: end.y + sin(leafAngle) * length * 0.7))
        }

        // Tendrils: a thin cord off a node that ends in a curl.
        var tendrils = Path()
        for (n, (run, t, born, turn)) in [(0, 0.3, 0.34, 1.0), (1, 0.45, 0.5, -1.0), (0, 0.66, 0.5, -1.0)].enumerated() {
            let r = reach(run)
            let grow = Ink.smooth((p - born) / 0.16)
            guard grow > 0.05, r >= t else { continue }
            let at = Self.along(paths[run], t / max(0.001, r))
            let s = turn * sx
            var cord: [CGPoint] = []
            for k in 0...16 {
                let u = Double(k) / 16 * grow
                let ang = (s > 0 ? -0.9 : -.pi + 0.9) + s * (u * u * 11)
                let rad = 11 * (1 - 0.8 * u) * (0.6 + 0.4 * u) + 2
                cord.append(CGPoint(x: at.x + cos(ang) * rad * u * 2.2 + s * u * 3, y: at.y + sin(ang) * rad * u * 2.2 - u * 6 * (1 + 0.2 * Double(n))))
            }
            tendrils.addPath(Self.ribbon(cord, 1.5, 0.6))
        }

        if let c {
            batches[0].flush(c, inks[0], casting: false)
            // The vines, the second behind the first, and the main one's leaves in front.
            for i in [1, 0] where reach(i) > 0.02 {
                let w = runs[i].width * (1 - 0.2 * wilt)
                paint(c, stem: Self.ribbon(paths[i], w, w * 0.55), along: paths[i], width: w, tier: i == 0 ? 1 : 0)
            }
            c.fill(stalks, with: .color(ramp[2].color()))
            c.fill(tendrils, with: .color(ramp[3].color(0.9)))
            batches[1].flush(c, inks[1])
            batches[2].flush(c, inks[2])
        }

        // The flower, on the vine at the node by the fruit.
        let budK = since(0.58, over: 0.1)
        let openK = Ink.smooth((p - 0.72) / 0.08)
        if budK > 0.03, reach(0) > 0.55 {
            let at = Self.along(paths[0], 0.47 / max(0.001, reach(0)))
            let stem = CGPoint(x: at.x - 4 * sx, y: at.y - 22 - 6 * wilt)
            let tip = CGPoint(x: stem.x - 6 * sx, y: stem.y - 14 + 14 * wilt)
            if let c {
                c.fill(Self.ribbon([at, CGPoint(x: (at.x + stem.x) / 2, y: at.y - 8), tip], 2.4, 1.8), with: .color(ramp[2].color()))
                pumpkinFlower(c, at: tip, radius: 25 * (0.5 + 0.5 * budK), open: openK * (0.3 + 0.7 * M.open) * (1 - 0.35 * M.doze), bud: budK, droop: wilt * sx)
            }
            m.note(CGPoint(x: tip.x, y: tip.y - 8), reach: 10, hang: false)
        }

        // The fruit, at the foot, in front of the soil.
        let fruitK = Ink.smooth((p - 0.46) / 0.5)
        if fruitK > 0.03 {
            let r = Ink.lerp(3, 31, fruitK * fruitK * 0.4 + fruitK * 0.6)
            let ripe = Ink.smooth((p - 0.8) / 0.17)
            let at = CGPoint(x: -26 * sx, y: 6)
            if let c { fruit(c, at: at, radius: r, ripe: ripe) }
            m.note(CGPoint(x: at.x, y: at.y - r * 1.8), reach: r, hang: false)
        }
        m.note(paths[0][paths[0].count - 1], reach: 3, hang: false)
    }

    /// A trumpet flower: a green calyx, a flared yellow tube seen from the
    /// front with five pointed lobes, ribbed and deeper in the throat; or a
    /// twisted bud with a yellow tip.
    private func pumpkinFlower(_ c: GraphicsContext, at: CGPoint, radius R: Double, open: Double, bud: Double, droop: Double) {
        guard let flower = plan.flower else { return }
        var h = c
        h.translateBy(x: at.x, y: at.y)
        h.rotate(by: .radians(droop * 0.6))
        let mid = bloom(flower.mid), deep = bloom(flower.deep), pale = bloom(flower.pale), throat = bloom(flower.heart, dim: 0.5)
        if open < 0.2 {
            let k = R * (0.7 + 0.5 * open / 0.2)
            var body = Path(), twist = Path(), calyx = Path()
            body.leaf(0, 2, 0, -1, k * 1.5, k * 0.42, 0.3)
            twist.lens(from: CGPoint(x: -k * 0.3, y: -k * 0.2), to: CGPoint(x: k * 0.3, y: -k * 1.2), width: k * 0.16)
            for s in [-1.0, 1.0] { calyx.leaf(0, 3, s * 0.5, -1, k * 0.9, k * 0.14, 0.1) }
            h.fill(body, with: .linearGradient(Gradient(colors: [ramp[3].color(), mid.mix(ramp[3], 0.3).color(), mid.color()]),
                                               startPoint: CGPoint(x: 0, y: 2), endPoint: CGPoint(x: 0, y: -k * 1.5)))
            h.fill(twist, with: .color(deep.color(0.4)))
            h.fill(calyx, with: .color(ramp[3].color()))
            return
        }
        let shape = LeafShape.of(.tepal)
        var sepals = Path()
        for i in 0..<5 { let a = Double(i) / 5 * .pi * 2 + 0.3; sepals.leaf(0, 0, cos(a), sin(a), R * 0.9, R * 0.1, 0) }
        h.fill(sepals, with: .color(ramp[2].color()))
        let rings = [Ring(kind: .tepal, count: 5, base: 0.1, reach: 1.05, wide: 0.78, appears: 0.2, bend: 0.2, jitter: 0.06,
                          tones: [throat, deep.mix(mid, 0.4), mid.mix(pale, 0.2)], detail: 2)]
        rosette(h, rings: rings, radius: R, open: open, light: L)
        _ = shape
        h.fill(Path(ellipseIn: CGRect(x: -R * 0.2, y: -R * 0.2, width: R * 0.4, height: R * 0.4)), with: .color(throat.shifted(-8).color(0.9)))
    }

    /// The fruit: an oblate globe cut into lobes. Each lobe is a band between
    /// two meridians; its tone is how it faces the sun, and a thin dark valley
    /// runs between. A green ridged stem on top and the withered flower's scar.
    private func fruit(_ c: GraphicsContext, at: CGPoint, radius r: Double, ripe: Double) {
        var c = c
        c.translateBy(x: at.x, y: at.y - r * 0.82)
        let rx = r * 1.12, ry = r * 0.92
        let green: [RGB] = [ramp[0], ramp[1], ramp[2], ramp[3]]
        let skin = plan.fruitTones ?? [0xA83F0C, 0xE06A18, 0xFF9A3A, 0xFFC47E]
        let orange: [RGB] = [RGB.tone(skin[0], day: day, dim: 0.9), RGB.tone(skin[1], day: day, dim: 0.9), RGB.tone(skin[2], day: day, dim: 0.9), RGB.tone(skin[3], day: day, dim: 0.85)]
        let t = (0..<4).map { green[$0].mix(orange[$0], ripe) }
        let side = L.x >= 0 ? 1.0 : -1.0
        // The shadow on the soil, then the whole globe in its darkest tone.
        c.fill(Path(ellipseIn: CGRect(x: -rx * 0.95 + 2, y: ry * 0.62, width: rx * 2 * 0.95, height: ry * 0.5)), with: .color(cast))
        var globe = Path()
        globe.oval(0, 0, rx, ry)
        c.fill(globe, with: .color(t[0].color()))
        let lobes = 9
        var classes = [Path(), Path(), Path()], valleys = Path()
        func meridian(_ phi: Double, steps: Int = 8) -> [CGPoint] {
            (0...steps).map { i in
                let u = -Double.pi / 2 + Double(i) / Double(steps) * .pi
                return CGPoint(x: rx * sin(phi) * cos(u), y: -ry * sin(u))
            }
        }
        for i in 0..<lobes {
            let a = -Double.pi / 2 + Double(i) * .pi / Double(lobes), b = a + .pi / Double(lobes), mid = (a + b) / 2
            let bri = 0.5 + 0.55 * (sin(mid) * L.x * 0.8 + cos(mid) * 0.42) - 0.06 * M.doze
            let k = bri < 0.3 ? -1 : bri < 0.52 ? 0 : bri < 0.76 ? 1 : 2
            if k >= 0 {
                var band = Path()
                band.addLines(meridian(a) + meridian(b).reversed())
                band.closeSubpath()
                classes[min(2, k)].addPath(band)
            }
            if i > 0 {
                var line = Path()
                line.addLines(meridian(a - 0.045) + meridian(a + 0.045).reversed())
                line.closeSubpath()
                valleys.addPath(line)
            }
        }
        c.fill(classes[0], with: .color(t[1].color()))
        c.fill(classes[1], with: .color(t[2].color()))
        c.fill(classes[2], with: .color(t[3].mix(glow, 0.12 * (1 - night)).color()))
        c.fill(valleys, with: .color(t[0].shifted(-5).color(0.55)))
        // A waxy sheen, a bounce of the soil underneath, the sun's rim.
        var sheen = Path()
        sheen.oval(side * rx * 0.42, -ry * 0.34, rx * 0.2, ry * 0.12, -0.5 * side)
        c.fill(sheen, with: .color(Color.white.opacity(0.22 * (1 - 0.5 * night))))
        // The stem: green, ridged, curved, with the scar of the flower under it.
        let stem = [CGPoint(x: -1, y: -ry * 0.82), CGPoint(x: 0, y: -ry - r * 0.32), CGPoint(x: 3 * side, y: -ry - r * 0.62)]
        c.fill(Self.ribbon(stem, max(3, r * 0.34), max(2, r * 0.22), flat: true), with: .color(ramp[2].mix(RGB(0x8A7A40), 0.2 + 0.4 * ripe).color()))
        var ridges = Path()
        for k in 0..<3 { let o = Double(k - 1) * r * 0.08; ridges.lens(from: CGPoint(x: stem[0].x + o, y: stem[0].y), to: CGPoint(x: stem[2].x + o, y: stem[2].y), width: 0.6) }
        c.fill(ridges, with: .color(ramp[0].color(0.5)))
        c.fill(Path(ellipseIn: CGRect(x: -r * 0.12, y: ry * 0.86, width: r * 0.24, height: r * 0.1)), with: .color(t[0].shifted(-8).color(0.8)))
    }
}
