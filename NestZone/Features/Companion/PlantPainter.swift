import SwiftUI

/// A drawn plant in layered gouache, the way `PomegranatePainter` draws a tree:
/// leaves are sorted by the light into classes and merged into a few fills per
/// depth tier (`LeafBatch`), their shapes are worked out once and kept
/// (`LeafShape`), and every bit of light, the lit half of a leaf, the rim, a
/// highlight on a bloom, comes from one vector towards the sun (or at night the
/// moon). See `Docs/Companion/art/RULES.md`.
///
/// It is one still picture, drawn only when what it shows changes (the mood or
/// the growth easing in, the light moving), on a layer of its own (`PlantLayer`);
/// the wind is a shear of that picture, as for the trees. A plant is a `Rule`
/// (`PlantPlan`) read at one growth, mood and light: the rules are in the
/// `PlantPainter+…` files, and this one is what they share.
///
/// The caller's context sits at the base of the plant on the soil line, up
/// negative, the way a tree's does. Growth is the companion's share of the way
/// to graduation (the stages are at 0, .1, .28, .5, .72 and .88).
struct PlantPainter {
    typealias RGB = Canopy.RGB

    let plan: PlantPlan
    let seed: PlantSeed
    var growth: Double
    var mood: Double
    var day: Double
    /// Where the sun (or at night the moon) stands across the scene, -1 to 1.
    var light = -0.5

    let M: Canopy.Mood
    let night: Double
    /// Towards the light, a unit vector, y up negative.
    let L: (x: Double, y: Double)
    /// How low the sun is (it peaks at dusk) and how far into moonlight we are.
    let dusk: Double
    let moon: Double
    /// The warm white of a rim by day, amber at dusk, cool by the moon; and the
    /// glow of a patch of light.
    let rimTone: RGB
    let glow: RGB
    /// The plan's five greens as this mood and light leave them.
    let ramp: [RGB]
    /// What a leaf is painted with, back tier to front, and the front tier's
    /// new growth.
    let inks: [LeafInk]
    let fresh: LeafInk
    /// The shadow a leaf casts on what is behind it, in the plant's own
    /// deepest green.
    let cast: Color

    var p: Double { growth }

    /// A tier's paint: three classes of green, the half of a leaf that faces
    /// the light, its veins, the light on its edge and a glint, and the stalks.
    struct LeafInk {
        var d, m, l, half, vein, rim, gloss, shadow, stalk: Color
        /// The pale of a variegated leaf; unused (clear) when the plant has none.
        var pale = Color.clear
    }

    init(plan: PlantPlan, seed: String, growth: Double, mood: Double, day: Double, light: Double = -0.5) {
        self.plan = plan
        self.light = light
        self.seed = PlantSeed(seed)
        self.growth = growth
        self.mood = mood
        self.day = day
        let M = Canopy.Mood(mood)
        let night = 1 - day
        self.M = M
        self.night = night
        L = LeafArt.sun(light: light, day: day)
        let dusk = 4 * day * (1 - day)
        self.dusk = dusk
        let moon = Ink.smooth((0.3 - day) / 0.3)
        self.moon = moon
        let rimTone = RGB(0xFFF3C4).mix(RGB(0xFF9A5C), Ink.clamp(dusk * 1.4)).mix(RGB(0xC4D2FF), moon)
        let glow = RGB(0xFFE9A8).mix(RGB(0xFFB070), Ink.clamp(dusk * 1.4)).mix(RGB(0xB8C8FF), moon)
        self.rimTone = rimTone
        self.glow = glow
        var ramp = (0..<5).map { Canopy.leafTone(RGB(plan.ramp[$0]), $0, M, day: day) }
        // Moonlight on the lit rim.
        ramp[4] = ramp[4].mix(RGB(0xCDD6FF), 0.3 * night)
        self.ramp = ramp
        let rimAlpha = (0.26 + 0.3 * Ink.clamp(dusk * 1.6) + 0.22 * moon) * (1 - 0.45 * M.doze) * (1 - 0.3 * M.thirst)
        let deepTeal = RGB(0x143A44)
        func ink(_ tier: Int, bronze: Double = 0) -> LeafInk {
            var d, m, l: RGB
            switch tier {
            case 0:
                d = ramp[0].mix(ramp[1], 0.6)
                m = ramp[1].mix(ramp[2], 0.3)
                l = ramp[1].mix(ramp[2], 0.7)
            case 1:
                d = ramp[1].mix(ramp[2], 0.1)
                m = ramp[1].mix(ramp[2], 0.7)
                l = ramp[2].mix(ramp[3], 0.45)
            default:
                d = ramp[1].mix(ramp[2], 0.55)
                m = ramp[2].mix(ramp[3], 0.55)
                l = ramp[3].mix(ramp[4], 0.15)
            }
            // The shade leans cool and the light warm, as it does in paint.
            d = d.mix(deepTeal, 0.2)
            l = l.mix(glow, 0.1 * (1 - night))
            if bronze > 0 {
                let b = RGB.night(12, 52, 44, day: day, dim: 0.9)
                d = d.mix(b, bronze * 0.5)
                m = m.mix(b, bronze)
                l = l.mix(b.mix(RGB(0xE9A265), 0.4), bronze)
            }
            let half = l.mix(ramp[4], 0.5).mix(glow, 0.2 * (1 - night))
            return LeafInk(d: d.color(), m: m.color(), l: l.color(),
                           half: half.color(0.5 * (1 - 0.4 * M.doze)),
                           vein: l.mix(ramp[4], 0.6).color(0.42),
                           rim: rimTone.color(rimAlpha),
                           gloss: RGB(0xFFFFFF).mix(glow, 0.3).color(0.5 * (1 - 0.5 * night) * (1 - 0.5 * M.thirst)),
                           shadow: ramp[0].mix(RGB(0x061A10), 0.6).shifted(-8).color((0.17 + 0.04 * M.glow) * (1 - 0.35 * M.thirst - 0.3 * M.doze) * (1 - 0.25 * night)),
                           stalk: ramp[1].mix(ramp[2], 0.4).color(),
                           pale: plan.variegation.map { v in
                               // The pale is a leaf tone like the greens: it goes olive when thirsty and dim at night.
                               Canopy.leafTone(RGB(v.tone), 3, M, day: day).mix(ramp[1], tier == 0 ? 0.3 : tier == 1 ? 0.12 : 0).color()
                           } ?? .clear)
        }
        inks = (0..<3).map { ink($0) }
        fresh = ink(2, bronze: 0.42)
        cast = ramp[0].mix(RGB(0x122027), 0.35).shifted(-10)
            .color((0.3 + 0.05 * M.glow) * (1 - 0.35 * M.thirst - 0.3 * M.doze) * (1 - 0.25 * night))
    }

    /// Where a plant puts what it grows, for whatever hangs on it and plays
    /// round it.
    struct Marks {
        var left = 0.0, right = 0.0, top = 0.0, bottom = 0.0
        var crownTop = CGPoint.zero
        /// The foliage, as points to hang things from.
        var points: [CGPoint] = []

        mutating func note(_ point: CGPoint, reach: Double = 0, hang: Bool = true) {
            left = min(left, point.x - reach)
            right = max(right, point.x + reach)
            if point.y - reach < top {
                top = point.y - reach
                crownTop = CGPoint(x: point.x, y: top)
            }
            bottom = max(bottom, point.y + reach * 0.5)
            if hang { points.append(point) }
        }
    }

    /// Draws the plant, or with no context only works out where it is.
    func render(_ context: GraphicsContext?) -> Marks {
        var marks = Marks()
        marks.top = 0
        if let context { seedAndSoil(context) }
        guard p > 0.07 else { return marks }
        switch plan.rule {
        case .stalk: stalk(context, &marks)
        case .bush: bush(context, &marks)
        case .column: column(context, &marks)
        case .vine: vine(context, &marks)
        case .tuft: tuft(context, &marks)
        case .cane: cane(context, &marks)
        case .sprig: sprig(context, &marks)
        case .blades: blades(context, &marks)
        case .frond: frond(context, &marks)
        case .spray: spray(context, &marks)
        case .sculpt: sculpt(context, &marks)
        case .trail: trail(context, &marks)
        }
        return marks
    }

    func draw(_ context: GraphicsContext) { _ = render(context) }

    /// Where decorations hang on the plant as it stands, in the painter's
    /// space (the plant's base at the origin, up negative).
    func anchors() -> CanopyAnchors {
        let marks = render(nil)
        guard marks.top < -1 else {
            return CanopyAnchors(left: -20, right: 20, top: -14, bottom: 0, crownTop: CGPoint(x: 0, y: -14), hangs: [], notes: [])
        }
        let sorted = marks.points.sorted { $0.x < $1.x }
        var hangs: [CGPoint] = []
        let count = min(7, sorted.count)
        for i in 0..<count {
            hangs.append(sorted[count == 1 ? 0 : i * (sorted.count - 1) / (count - 1)])
        }
        let low = marks.points.sorted { $0.y > $1.y }.prefix(2)
        let notes = low.map { CGPoint(x: $0.x, y: $0.y + 4) }
        return CanopyAnchors(left: marks.left, right: marks.right, top: marks.top, bottom: marks.bottom,
                             crownTop: marks.crownTop, hangs: hangs, notes: notes)
    }
}

// MARK: - Growth

extension PlantPainter {
    /// A value that follows the growth through keyframes, linearly: `keys`
    /// are (growth, value) pairs in order.
    func grown(_ keys: [(Double, Double)]) -> Double {
        guard let first = keys.first, let last = keys.last else { return 0 }
        if p <= first.0 { return first.1 }
        if p >= last.0 { return last.1 }
        for i in 1..<keys.count where p <= keys[i].0 {
            let (a, b) = (keys[i - 1], keys[i])
            return Ink.lerp(a.1, b.1, (p - a.0) / (b.0 - a.0))
        }
        return last.1
    }

    /// 0…1 over `span` of growth from `at`.
    func since(_ at: Double, over span: Double) -> Double { Ink.clamp((p - at) / span) }

    /// What a leaf or bloom does as it is born: it overshoots a little and
    /// settles.
    func pop(_ at: Double, over span: Double = 0.07) -> Double { Ink.back((p - at) / span) }

    /// Which way things hang as the house goes quiet: 0 upright, 1 limp.
    var wilt: Double { M.wilt * (1 - 0.45 * M.doze) }

    /// The light, as a unit step towards it.
    var toLight: CGPoint { CGPoint(x: L.x, y: L.y) }

    /// A draw in 0…1 for whatever wants a little difference.
    func luck(_ n: Int) -> Double { seed.between(n, 0, 1) }

    /// Which class of green a leaf pointing along `angle` falls in, 0…1: leaves
    /// that point at the light are brighter, and every leaf has luck of its own.
    func bright(_ angle: Double, luck: Double, tier: Int) -> Double {
        let toward = cos(angle) * L.x + sin(angle) * L.y
        return 0.5 + 0.22 * toward + 0.4 * (luck - 0.5) + (tier == 2 ? 0.1 : tier == 0 ? -0.14 : 0) - 0.1 * M.doze
    }
}

// MARK: - The seed

extension PlantPainter {
    /// Before it sprouts: a little mound of loose earth and the species' own
    /// seed on it, with a crack in the mound as the sprout comes. Put down
    /// unscaled on the soil, as the trees' seeds are.
    func seedAndSoil(_ c: GraphicsContext) {
        let k = 1 - Ink.smooth((p - 0.1) / 0.06)
        guard k > 0.01 else { return }
        var c = c
        c.opacity = k
        let earth = RGB.night(28, 34, 24, day: day, dim: 0.9), loose = RGB.night(30, 34, 36, day: day, dim: 0.9)
        c.ellipse(0, 0.5, 14, 4.4, .color(earth.color()))
        c.ellipse(-1.2, -0.6, 11, 3.4, .color(loose.color()))
        let wobble = Ink.smooth((p - 0.04) / 0.05)
        var kernel = c
        kernel.translateBy(x: 1, y: -2.4 - 1.6 * wobble)
        kernel.rotate(by: .radians(-0.3 + 0.5 * wobble))
        let pale = RGB.night(38, 52, 68, day: day, dim: 0.8), shade = RGB.night(30, 40, 42, day: day, dim: 0.8)
        switch plan.seedLook {
        case .husk:
            // A sunflower's: a pointed teardrop, charcoal with pale stripes.
            var body = Path(), stripes = Path()
            body.leaf(-4.6, 0, 1, 0, 9.4, 3.1, 0)
            for off in [-1.1, 1.1] { stripes.lens(from: CGPoint(x: -3, y: off), to: CGPoint(x: 3.4, y: off * 0.5), width: 0.5) }
            kernel.fill(body, with: .color(RGB.night(220, 18, 22, day: day, dim: 0.8).color()))
            kernel.fill(stripes, with: .color(RGB.night(40, 24, 78, day: day, dim: 0.8).color(0.85)))
            kernel.ellipse(-1.2, -1.2, 1.6, 0.7, .color(Color.white.opacity(0.4)))
        case .dot:
            // A few small dark seeds.
            var seeds = Path()
            for (x, y, r) in [(-2.4, 0.2, 1.5), (0.4, -0.5, 1.7), (2.8, 0.3, 1.4)] { seeds.addEllipse(in: CGRect(x: x - r, y: y - r * 0.7, width: r * 2, height: r * 1.4)) }
            kernel.fill(seeds, with: .color(RGB.night(24, 30, 18, day: day, dim: 0.8).color()))
            kernel.ellipse(0, -1, 0.7, 0.4, .color(Color.white.opacity(0.4)))
        case .bulb:
            // A tulip bulb: brown onion with a papery tip and a pink nub of shoot.
            var body = Path(), tip = Path()
            body.oval(0, 0.6, 5.2, 4.2)
            tip.addLines([CGPoint(x: -1.8, y: -2.6), CGPoint(x: 0.3, y: -7.4), CGPoint(x: 1.8, y: -2.6)])
            kernel.fill(tip, with: .color(RGB.night(34, 40, 52, day: day, dim: 0.8).color()))
            kernel.fill(body, with: .color(RGB.night(30, 46, 38, day: day, dim: 0.8).color()))
            kernel.ellipse(-1.4, -0.6, 2.2, 1.6, .color(RGB.night(34, 40, 56, day: day, dim: 0.8).color(0.8)))
            kernel.ellipse(0.2, -7, 0.9, 1.3, .color(RGB.night(346, 70, 60, day: day, dim: 0.8).color()))
        case .tuber:
            // A peony's: two knobs with pink eyes.
            for (x, r) in [(-2.8, 3.0), (2.8, 2.6)] {
                kernel.ellipse(x, 0.2, r, r * 0.75, .color(RGB.night(24, 36, 40, day: day, dim: 0.8).color()))
                kernel.ellipse(x - 0.5, -0.6, r * 0.5, r * 0.28, .color(RGB.night(30, 40, 62, day: day, dim: 0.8).color(0.8)))
                kernel.ellipse(x + 0.5, -2.2, 0.8, 1.0, .color(RGB.night(340, 66, 62, day: day, dim: 0.8).color()))
            }
        case .hip:
            // A rosehip: a small red berry with a dark crown.
            kernel.ellipse(0, 0, 3.6, 3.2, .color(RGB.night(354, 70, 34, day: day, dim: 0.9).color()))
            kernel.ellipse(-0.6, -0.8, 2.4, 1.8, .color(RGB.night(358, 72, 48, day: day, dim: 0.9).color()))
            kernel.ellipse(-1.1, -1.3, 1.0, 0.6, .color(Color.white.opacity(0.55)))
            kernel.ellipse(0, -3, 0.9, 0.6, .color(RGB.night(24, 30, 16, day: day, dim: 0.8).color()))
        case .cutting:
            // A monstera starts as a cutting: a node with a stub of aerial root.
            kernel.ellipse(0, 0, 4.4, 2.6, .color(RGB.night(28, 38, 36, day: day, dim: 0.8).color()))
            kernel.ellipse(-0.6, -0.5, 3, 1.5, .color(RGB.night(100, 34, 54, day: day, dim: 0.8).color()))
            kernel.ellipse(-3.8, 1.2, 1.2, 0.8, .color(RGB.night(24, 40, 50, day: day, dim: 0.8).color()))
            kernel.ellipse(-1.2, -1.1, 1.3, 0.6, .color(Color.white.opacity(0.4)))
        case .sprig:
            // A cutting: a bare stub of stem with two small leaves.
            var stub = Path(), leaves = Path()
            stub.addPath(Self.ribbon([CGPoint(x: -2.5, y: 1.5), CGPoint(x: 0, y: -2), CGPoint(x: 2, y: -6)], 2.2, 1.4))
            leaves.leaf(1.6, -5, 0.8, -0.6, 4.6, 1.5, 0.3)
            leaves.leaf(0.8, -3.6, -0.8, -0.6, 4.2, 1.4, 0.3)
            kernel.fill(stub, with: .color(RGB.night(24, 30, 34, day: day, dim: 0.8).color()))
            kernel.fill(leaves, with: .color(RGB.night(120, 44, 40, day: day, dim: 0.8).color()))
        case .rhizome:
            // A snake plant's: pale, fat knuckles of rhizome with a pink eye.
            for (x, y, r) in [(-3.6, 0.4, 3.2), (0.6, -0.4, 3.6), (4.6, 0.6, 2.6)] {
                kernel.ellipse(x, y, r, r * 0.62, .color(RGB.night(64, 30, 62, day: day, dim: 0.8).color()))
                kernel.ellipse(x - 0.5, y - 0.8, r * 0.55, r * 0.22, .color(RGB.night(70, 30, 78, day: day, dim: 0.8).color(0.8)))
            }
            kernel.ellipse(1.6, -2, 0.9, 0.6, .color(RGB.night(340, 50, 66, day: day, dim: 0.8).color()))
        case .spore:
            // Dust of spores, and one tiny coil.
            var dust = Path()
            for (x, y, r) in [(-4.2, 0.4, 0.8), (-2.4, -0.6, 0.7), (-0.4, 0.5, 0.9), (1.6, -0.5, 0.7), (3.4, 0.3, 0.8), (-1.2, -1.6, 0.6), (2.4, -1.4, 0.6)] {
                dust.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            kernel.fill(dust, with: .color(RGB.night(28, 44, 28, day: day, dim: 0.8).color()))
            kernel.stroke(Path { $0.addArc(center: CGPoint(x: 0, y: -4), radius: 1.6, startAngle: .degrees(60), endAngle: .degrees(330), clockwise: false) },
                          with: .color(RGB.night(92, 40, 52, day: day, dim: 0.8).color()), lineWidth: 1)
        case .bark:
            // An orchid starts on bark: a chip with a silver root and a green tip.
            var chip = Path()
            chip.addRoundedRect(in: CGRect(x: -5.4, y: -2.2, width: 10.8, height: 4.2), cornerSize: CGSize(width: 1.8, height: 1.8))
            kernel.fill(chip, with: .color(RGB.night(24, 32, 30, day: day, dim: 0.8).color()))
            kernel.ellipse(-1, -1.6, 3.6, 0.9, .color(RGB.night(26, 34, 44, day: day, dim: 0.8).color(0.8)))
            kernel.ellipse(5.6, 1.4, 2.6, 0.9, .color(RGB.night(110, 12, 66, day: day, dim: 0.8).color()))
            kernel.ellipse(7.6, 1.4, 0.8, 0.8, .color(RGB.night(88, 56, 62, day: day, dim: 0.8).color()))
        case .acorn:
            // A bonsai's: an acorn with a cap.
            kernel.ellipse(0, 0.4, 3.2, 4.2, .color(RGB.night(30, 52, 40, day: day, dim: 0.8).color()))
            kernel.ellipse(-0.8, -0.4, 1.2, 2.4, .color(RGB.night(34, 50, 56, day: day, dim: 0.8).color(0.8)))
            kernel.ellipse(0, -3, 3.8, 2, .color(RGB.night(26, 34, 26, day: day, dim: 0.8).color()))
            kernel.ellipse(0, -5, 0.7, 0.9, .color(RGB.night(26, 34, 22, day: day, dim: 0.8).color()))
        case .winged:
            // A maple key: a seed and a wing.
            var wing = Path()
            wing.leaf(0, -1, 0.6, -0.8, 9, 2.6, 0.2)
            kernel.fill(wing, with: .color(RGB.night(40, 44, 70, day: day, dim: 0.8).color(0.9)))
            kernel.ellipse(-0.4, 0.4, 2.2, 2.6, .color(RGB.night(30, 50, 40, day: day, dim: 0.8).color()))
            kernel.ellipse(-1.2, -0.4, 0.8, 1.2, .color(Color.white.opacity(0.4)))
        case .cone:
            // A pine cone: brown scales in rows.
            kernel.ellipse(0, -1, 3.4, 4.6, .color(RGB.night(26, 46, 30, day: day, dim: 0.8).color()))
            var scales = Path()
            for r in 0..<4 { scales.addEllipse(in: CGRect(x: -3 + 0.4 * Double(r % 2), y: -4.6 + 2.2 * Double(r), width: 5.6, height: 1.2)) }
            kernel.fill(scales, with: .color(RGB.night(24, 36, 52, day: day, dim: 0.8).color(0.8)))
        case .flat:
            // A pumpkin seed: a flat, pale teardrop with a rim.
            var body = Path()
            body.leaf(-4, 0, 1, 0, 8.4, 2.9, 0.1)
            kernel.fill(body, with: .color(RGB.night(46, 40, 78, day: day, dim: 0.8).color()))
            kernel.fill(body.offsetBy(dx: 0.3, dy: 0.2), with: .color(RGB.night(46, 34, 90, day: day, dim: 0.8).color(0.5)))
            kernel.ellipse(-1.4, -0.4, 2.4, 0.6, .color(Color.white.opacity(0.4)))
        }
        _ = (pale, shade)
    }

    /// Something small lying on the soil: a fallen petal, a leaf. Drawn flat on
    /// the ground, `x` along it, turned `turn`.
    func onSoil(_ c: GraphicsContext, x: Double, length: Double, width: Double, turn: Double, tone: RGB, tip: RGB? = nil) {
        var a = Path(), b = Path()
        let ca = cos(turn), sa = sin(turn) * 0.34
        a.leaf(x, 1.8, ca, sa, length, width, 0.5)
        c.fill(a.offsetBy(dx: 0.6, dy: 0.9), with: .color(cast))
        c.fill(a, with: .color(tone.color()))
        b.leaf(x + ca * length * 0.1, 1.5, ca, sa, length * 0.7, width * 0.45, 0.4)
        c.fill(b, with: .color((tip ?? tone.mix(RGB(0xFFFFFF), 0.3)).color(0.6)))
    }
}

// MARK: - Shapes

extension PlantPainter {
    /// A stem that tapers from `w0` to `w1` along `points`, round at the tip
    /// and, unless `flat`, at the base.
    static func ribbon(_ points: [CGPoint], _ w0: Double, _ w1: Double, flat: Bool = true) -> Path {
        guard points.count > 1 else { return Path() }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for (i, point) in points.enumerated() {
            let before = points[max(0, i - 1)], after = points[min(points.count - 1, i + 1)]
            let angle = atan2(after.y - before.y, after.x - before.x)
            let w = Ink.lerp(w0, w1, Double(i) / Double(points.count - 1)) / 2
            left.append(CGPoint(x: point.x - sin(angle) * w, y: point.y + cos(angle) * w))
            right.append(CGPoint(x: point.x + sin(angle) * w, y: point.y - cos(angle) * w))
        }
        let tip = points[points.count - 1], prev = points[points.count - 2]
        let a = atan2(tip.y - prev.y, tip.x - prev.x)
        let cap = CGPoint(x: tip.x + cos(a) * w1 * 0.5, y: tip.y + sin(a) * w1 * 0.5)
        var outline = left + [cap] + right.reversed()
        if !flat {
            let first = points[0], next = points[1]
            let b = atan2(first.y - next.y, first.x - next.x)
            outline.append(CGPoint(x: first.x + cos(b) * w0 * 0.5, y: first.y + sin(b) * w0 * 0.5))
        }
        var path = Path.smooth(outline)
        path.closeSubpath()
        return path
    }

    /// A quadratic Bézier sampled into `n` points.
    static func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, upTo t1: Double = 1, n: Int = 10) -> [CGPoint] {
        (0...n).map { i in
            let t = t1 * Double(i) / Double(n), u = 1 - t
            return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
        }
    }

    /// A cubic Bézier sampled into `n` points.
    static func cubic(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, upTo t1: Double = 1, n: Int = 14) -> [CGPoint] {
        (0...n).map { i in
            let t = t1 * Double(i) / Double(n), u = 1 - t
            let k0 = u * u * u, k1 = 3 * u * u * t, k2 = 3 * u * t * t, k3 = t * t * t
            return CGPoint(x: k0 * a.x + k1 * c1.x + k2 * c2.x + k3 * b.x, y: k0 * a.y + k1 * c1.y + k2 * c2.y + k3 * b.y)
        }
    }

    /// The point on a sampled stem at a share of its way along.
    static func along(_ points: [CGPoint], _ t: Double) -> CGPoint {
        let f = Ink.clamp(t) * Double(points.count - 1)
        let i = min(Int(f), points.count - 2), u = f - Double(i)
        return CGPoint(x: Ink.lerp(points[i].x, points[i + 1].x, u), y: Ink.lerp(points[i].y, points[i + 1].y, u))
    }

    /// The heading of a sampled stem a share of the way along it.
    static func heading(_ points: [CGPoint], _ t: Double) -> Double {
        let a = along(points, max(0, t - 0.04)), b = along(points, min(1, t + 0.04))
        return atan2(b.y - a.y, b.x - a.x)
    }

    /// The point on a sampled stem at a height above its first point.
    static func height(_ points: [CGPoint], _ height: Double) -> CGPoint {
        for i in 1..<points.count where points[0].y - points[i].y >= height {
            let a = points[i - 1], b = points[i]
            let t = (height - (points[0].y - a.y)) / max(0.001, a.y - b.y)
            return CGPoint(x: Ink.lerp(a.x, b.x, t), y: Ink.lerp(a.y, b.y, t))
        }
        return points[points.count - 1]
    }
}

extension Path {
    /// A smooth closed curve through the middles of the sides of `points`,
    /// which pull it without being on it.
    static func smooth(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 2 else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(points[points.count - 1], points[0]))
        for i in 0..<points.count {
            path.addQuadCurve(to: mid(points[i], points[(i + 1) % points.count]), control: points[i])
        }
        return path
    }
}

// MARK: - Painting

extension PlantPainter {
    /// A stem: its shade, the lit edge towards the light, and a thin bright
    /// streak of the sun's colour on it.
    func paint(_ c: GraphicsContext, stem outline: Path, along points: [CGPoint], width: Double, tier: Int = 1, tint: UInt32 = 0) {
        let box = outline.boundingRect
        let side = L.x >= 0 ? 1.0 : -1.0
        // A stem with a colour of its own (mint's is plum) takes it through the
        // shade and the middle and keeps a green light on its edge.
        let wood = tint == 0 ? nil : RGB.tone(tint, day: day, dim: 0.85)
        func toned(_ i: Int, _ amount: Double) -> RGB { wood.map { ramp[i].mix($0, amount) } ?? ramp[i] }
        c.fill(outline, with: .linearGradient(
            Gradient(colors: [toned(tier + 2, 0.35).mix(glow, 0.08 * (1 - night)).color(), toned(tier + 1, 0.6).color(), toned(tier, 0.7).shifted(-3).color()]),
            startPoint: CGPoint(x: box.midX + side * box.width * 0.5, y: box.midY), endPoint: CGPoint(x: box.midX - side * box.width * 0.5, y: box.midY)))
        guard points.count > 2 else { return }
        let shift = side * width * 0.2
        let edge = points.map { CGPoint(x: $0.x + shift, y: $0.y) }
        c.fill(Self.ribbon(edge, max(0.8, width * 0.2), max(0.5, width * 0.12)), with: .color(rimTone.mix(ramp[4], 0.4).color(0.5 + 0.2 * dusk)))
    }

    /// Bloom colours: they open, glow and drain with the mood as a tree's do.
    func bloom(_ hex: UInt32, dim: Double = 0.5) -> RGB {
        let open = (0.5 + 0.5 * M.open) * (1 + 0.12 * M.glow) * (1 - 0.4 * M.doze)
        let (h, s, l) = RGB(hex).hsl
        return RGB.night(h, s * open, l, day: day, dim: dim)
    }
}
