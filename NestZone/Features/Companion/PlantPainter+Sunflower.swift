import SwiftUI

/// What a sunflower's disc is made of, in the disc's own units (its radius one):
/// a Fibonacci spiral of seeds, a ring of tiny florets round the edge. It
/// depends on nothing but the golden angle, so it is built once and a head at
/// any size is a scale and a fill.
enum DiscArt {
    static let seeds = 150
    /// Seed bodies, a lighter heart of young seeds, and a glint on each body
    /// (to be shifted a hair towards the light).
    static let (bodies, heart, glints, florets): (Path, Path, Path, Path) = {
        var bodies = Path(), heart = Path(), glints = Path(), florets = Path()
        let golden = 2.399963
        for i in 0..<seeds {
            let t = (Double(i) + 0.5) / Double(seeds)
            let r = 0.74 * t.squareRoot(), a = Double(i) * golden
            let (x, y) = (cos(a) * r, sin(a) * r)
            // Seeds are longer across the spiral than along it, and grow outwards.
            let s = 0.05 + 0.038 * t
            var seed = Path()
            seed.oval(0, 0, s * 1.25, s * 0.85, a + .pi / 2)
            let move = CGAffineTransform(translationX: x, y: y)
            if i < 26 { heart.addPath(seed, transform: move) } else { bodies.addPath(seed, transform: move) }
            glints.addEllipse(in: CGRect(x: x - s * 0.38, y: y - s * 0.3, width: s * 0.76, height: s * 0.5))
        }
        // Two staggered rings of tiny florets at the rim.
        for i in 0..<52 {
            let ring = i % 2, a = Double(i) / 52 * .pi * 2 + Double(ring) * 0.06
            let r = ring == 0 ? 0.9 : 0.82, s = ring == 0 ? 0.042 : 0.036
            florets.addEllipse(in: CGRect(x: cos(a) * r - s, y: sin(a) * r - s, width: s * 2, height: s * 2))
        }
        return (bodies, heart, glints, florets)
    }()
}

extension PlantPainter {
    /// The head, seen from the front and turned a little: green bracts, two rings
    /// of ray petals (each a little different: length, width, a curl), the disc
    /// and its spiral of seeds. It turns away and its petals shorten and curl as
    /// the house goes quiet. The whole head is about a dozen fills.
    func head(_ c: GraphicsContext, at centre: CGPoint, radius R: Double, petal: Double, bud: Double) {
        guard let flower = plan.flower else { return }
        var h = c
        let turn = seed.side * (0.22 + wilt * 1.2 + M.doze * 0.3)
        h.translateBy(x: centre.x, y: centre.y)
        h.rotate(by: .radians(turn))
        h.scaleBy(x: 1, y: 0.94)
        // The light in the head's own frame.
        let lx = L.x * cos(turn) + L.y * sin(turn), ly = -L.x * sin(turn) + L.y * cos(turn)

        // Bracts, behind everything: green, pointed, drawing in as the head opens.
        let sepalLen = Ink.lerp(R * 1.7, R + 8, Ink.smooth(petal * 2))
        var bracts = Path(), litBracts = Path()
        for ring in 0..<2 {
            let n = ring == 0 ? 15 : 13
            for i in 0..<n {
                let a = (Double(i) + 0.5 * Double(ring)) / Double(n) * .pi * 2 + 0.12
                let len = sepalLen * (ring == 0 ? 1 : 0.84) * seed.between(i + 4 * ring, 0.9, 1.08)
                if ring == 0 { bracts.leaf(0, 0, cos(a), sin(a), len, R * 0.34, 0) } else { litBracts.leaf(0, 0, cos(a), sin(a), len, R * 0.24, 0) }
            }
        }
        h.fill(bracts, with: .color(ramp[1].color()))
        h.fill(litBracts, with: .color(ramp[3].mix(glow, 0.12 * (1 - night)).color(0.92)))

        // Ray petals: an outer ring and a shorter, brighter one in front.
        if petal > 0.03 {
            let deep = bloom(flower.deep), mid = bloom(flower.mid), pale = bloom(flower.pale)
            let length = (36 * petal) * (1 - 0.2 * M.thirst) + 2
            let curl = 0.18 + 0.6 * wilt + 0.4 * M.thirst
            let outer = Gradient(colors: [deep.color(), mid.color(), mid.mix(pale, 0.45).color()])
            let inner = Gradient(colors: [deep.mix(mid, 0.4).color(), mid.mix(pale, 0.3).color(), pale.color()])
            var litHalf = Path(), shadeHalf = Path(), creases = Path()
            for ring in 0..<2 {
                var petals = Path()
                let n = ring == 0 ? flower.petals : flower.petals - 2
                let reach = ring == 0 ? length : length * 0.78
                for i in 0..<n {
                    // A thirsty head has lost a petal here and there.
                    if M.thirst > 0.4, (i + ring) % 5 == 3 { continue }
                    let a = (Double(i) + (ring == 0 ? 0 : 0.5)) / Double(n) * .pi * 2 + seed.side * 0.06 + seed.between(i * 2 + ring, -0.05, 0.05)
                    let len = reach * seed.between(i * 3 + ring + 1, 0.84, 1.14)
                    let wide = seed.between(i * 5 + ring + 2, 0.85, 1.12) * (0.72 + 0.28 * petal)
                    let bendNow = (seed.between(i * 7 + ring + 3, -1, 1)) * curl
                    let shape = LeafShape.of(.ray, bend: bendNow)
                    let at = CGPoint(x: cos(a) * R * 0.78, y: sin(a) * R * 0.78)
                    // The ray is narrower than it is long; `wide` fattens it across.
                    let t = CGAffineTransform(translationX: at.x, y: at.y).rotated(by: a).scaledBy(x: len, y: len * wide)
                    petals.addPath(shape.outline, transform: t)
                    let toward = -sin(a) * lx + cos(a) * ly
                    litHalf.addPath(toward >= 0 ? shape.sideA : shape.sideB, transform: t)
                    shadeHalf.addPath(toward >= 0 ? shape.sideB : shape.sideA, transform: t)
                    creases.addPath(shape.veins, transform: t)
                }
                h.fill(petals, with: .radialGradient(ring == 0 ? outer : inner, center: .zero, startRadius: R * 0.5, endRadius: R + reach))
            }
            h.fill(shadeHalf, with: .color(deep.shifted(-10).color(0.3)))
            h.fill(litHalf, with: .color(pale.mix(glow, 0.3 * (1 - night)).color(0.34)))
            h.fill(creases, with: .color(deep.shifted(-8).color(0.5)))
        }

        // The disc: green while it is a bud, brown once it opens.
        let ripe = Ink.smooth((p - 0.82) / 0.14)
        let rim = bloom(0x7A5230, dim: 0.5).mix(ramp[2], 1 - ripe), core = bloom(flower.heart, dim: 0.5).mix(ramp[1], 1 - ripe)
        h.fill(Path(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2)), with: .radialGradient(
            Gradient(colors: [rim.shifted(8).color(), rim.color(), core.color()]),
            center: CGPoint(x: lx * -R * 0.3, y: ly * -R * 0.3), startRadius: 0, endRadius: R * 1.25))
        if ripe > 0.2 {
            var d = h
            d.scaleBy(x: R, y: R)
            d.fill(DiscArt.florets, with: .color(bloom(flower.anther, dim: 0.5).color(0.95 * ripe)))
            d.fill(DiscArt.bodies, with: .color(bloom(0x4A2A14, dim: 0.5).mix(rim, 0.25).color(0.92 * ripe)))
            d.fill(DiscArt.heart, with: .color(bloom(0xA88A32, dim: 0.5).color(0.9 * ripe)))
            d.translateBy(x: lx * 0.03, y: ly * 0.03)
            d.fill(DiscArt.glints, with: .color(bloom(0xC79A5C, dim: 0.5).color(0.7 * ripe)))
            // The sheen: a short lens on the lit side of the disc.
            var shine = Path()
            let px = -ly, py = lx
            shine.lens(from: CGPoint(x: lx * 0.62 + px * 0.42, y: ly * 0.62 + py * 0.42), to: CGPoint(x: lx * 0.62 - px * 0.42, y: ly * 0.62 - py * 0.42),
                       width: 0.1, lean: 0.06)
            d.fill(shine, with: .color(Color.white.opacity(0.22 * ripe)))
        }
        // A bee visits a bright head by day.
        if M.glow > 0.5, day > 0.5, petal > 0.9 { bee(c, near: centre, reach: R + 36 * petal) }
    }

    /// A bee on the lower side of the head: wings, a striped body, a dark head
    /// and a glint, in four fills. Only when the house is thriving, by day.
    private func bee(_ c: GraphicsContext, near centre: CGPoint, reach: Double) {
        var b = c
        let at = CGPoint(x: centre.x + seed.side * reach * 0.72, y: centre.y + reach * 0.62)
        b.translateBy(x: at.x, y: at.y)
        b.rotate(by: .radians(-0.45 * seed.side))
        let alpha = Ink.clamp((day - 0.5) / 0.2)
        var wings = Path(), body = Path(), dark = Path()
        wings.oval(-1.5, -4.2, 2.2, 3.4, -0.5)
        wings.oval(1.2, -4.4, 2.0, 3.2, 0.5)
        body.oval(0, 0, 4.6, 3.1)
        for x in [-1.3, 1.1] { dark.lens(from: CGPoint(x: x, y: -2.8), to: CGPoint(x: x, y: 2.8), width: 0.5) }
        dark.oval(4.4, 0, 1.9, 1.7)
        b.fill(wings, with: .color(Color.white.opacity(0.55 * alpha)))
        b.fill(body, with: .color(bloom(0xF2B81E, dim: 0.6).color(alpha)))
        b.fill(dark, with: .color(RGB(0x2A1B10).color(alpha)))
        var glint = Path()
        glint.oval(-0.4, -1.4, 1.8, 0.7)
        b.fill(glint, with: .color(Color.white.opacity(0.55 * alpha)))
    }

    /// What the head has let fall on the soil: a petal, and when it is thirsty
    /// two more.
    func fallen(_ c: GraphicsContext) {
        guard let flower = plan.flower else { return }
        let tone = bloom(flower.mid, dim: 0.6)
        let fall = Ink.smooth((p - 0.86) / 0.08)
        guard fall > 0.3 else { return }
        onSoil(c, x: -seed.side * 17, length: 9.5, width: 3.4, turn: 0.38 * seed.side, tone: tone)
        if M.thirst > 0.3 {
            onSoil(c, x: seed.side * 12, length: 8, width: 3, turn: -0.5 * seed.side, tone: tone.mix(RGB(0x9A7A2A), 0.3))
            onSoil(c, x: -seed.side * 6, length: 7, width: 2.6, turn: 0.9, tone: tone.mix(RGB(0x9A7A2A), 0.4))
        }
    }
}
