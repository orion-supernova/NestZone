import SwiftUI

/// A drawn plant in layered gouache, the way `CanopyPainter` draws a tree:
/// every leaf is a shade shape, a lit copy of it up and left, a rib; the plant
/// is built back to front in three depth tiers, cool and dark behind, warm and
/// light in front, with one light from the upper left on every part.
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

    let M: Canopy.Mood
    let night: Double
    /// The plan's five greens as this mood and light leave them.
    let ramp: [RGB]
    let tiers: [Tier]
    /// The shadow a leaf casts on what is behind it, in the plant's own
    /// deepest green.
    let cast: Color

    var p: Double { growth }

    /// One depth tier's paint, as a tree's clumps have: the shade runs light to
    /// dark along the light, the lit copy is radial from its upper left.
    struct Tier {
        let shade, lit: Gradient
        let vein: Color
    }

    init(plan: PlantPlan, seed: String, growth: Double, mood: Double, day: Double) {
        self.plan = plan
        self.seed = PlantSeed(seed)
        self.growth = growth
        self.mood = mood
        self.day = day
        let M = Canopy.Mood(mood)
        let night = 1 - day
        self.M = M
        self.night = night
        var ramp = (0..<5).map { Canopy.leafTone(RGB(plan.ramp[$0]), $0, M, day: day) }
        // Moonlight on the lit rim.
        ramp[4] = ramp[4].mix(RGB(0xCDD6FF), 0.3 * night)
        self.ramp = ramp
        tiers = (0..<3).map { k in
            let base = ramp[k], lit = ramp[k + 1], sun = ramp[k + 2]
            let sh0 = base.shifted(4, -4), sh1 = base.shifted(-4, 6)
            let li0 = lit.mix(sun, (0.34 + 0.18 * M.glow) * (1 - 0.45 * night) * (1 - 0.35 * M.doze))
            let li2 = lit.shifted(-4, 5)
            return Tier(
                shade: Gradient(colors: [sh0.color(), sh1.color()]),
                lit: Gradient(stops: [.init(color: li0.color(), location: 0), .init(color: lit.color(), location: 0.55),
                                      .init(color: li2.color(), location: 1)]),
                vein: lit.mix(base, 0.38).color(0.85)
            )
        }
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
    var wilt: Double { M.wilt }

    /// The light, as a unit step towards it.
    var toLight: CGPoint { CGPoint(x: Canopy.light.x, y: Canopy.light.y) }
}

// MARK: - The seed

extension PlantPainter {
    /// Before it sprouts: a little mound of loose earth and the seed on it,
    /// with a crack in the mound as the sprout comes. Put down unscaled on the
    /// soil, as the trees' seeds are.
    func seedAndSoil(_ c: GraphicsContext) {
        let k = 1 - Ink.smooth((p - 0.1) / 0.06)
        guard k > 0.01 else { return }
        var c = c
        c.opacity = k
        let earth = RGB.night(28, 34, 24, day: day, dim: 0.9), loose = RGB.night(30, 34, 36, day: day, dim: 0.9)
        c.ellipse(0, 0.5, 14, 4.4, .color(earth.color()))
        c.ellipse(-1.2, -0.6, 11, 3.4, .color(loose.color()))
        let pale = RGB.night(38, 52, 68, day: day, dim: 0.8), seedShade = RGB.night(30, 40, 42, day: day, dim: 0.8)
        let wobble = Ink.smooth((p - 0.04) / 0.05)
        var kernel = c
        kernel.translateBy(x: 1, y: -2.4 - 1.6 * wobble)
        kernel.rotate(by: .radians(-0.3 + 0.5 * wobble))
        kernel.ellipse(0, 0, 4.6, 3, .color(seedShade.color()))
        kernel.ellipse(-0.5, -0.5, 3.8, 2.3, .color(pale.color()))
        kernel.ellipse(-1.2, -1.1, 1.5, 0.8, .color(Color.white.opacity(0.55)))
    }
}

// MARK: - Shapes

extension PlantPainter {
    /// A leaf from its base at `at`, pointing along `angle` (0 is right, up is
    /// -π/2), `length` long and `halfWidth` out either side at its widest,
    /// which is `widest` of the way along; `bend` turns the tip clockwise (down,
    /// for a leaf pointing right) by that many radians over its length. The
    /// outline and the midrib both.
    static func blade(at: CGPoint, angle: Double, length: Double, halfWidth: Double, widest: Double = 0.4,
                      bend: Double = 0, fullness: Double = 0.8) -> (outline: Path, rib: Path, tip: CGPoint) {
        let n = 10
        let a = log(0.5) / log(max(0.1, min(0.9, widest)))
        var mid = [at]
        var heading: [Double] = [angle]
        for i in 0..<n {
            let phi = angle + bend * (Double(i) + 0.5) / Double(n)
            let last = mid[i]
            mid.append(CGPoint(x: last.x + cos(phi) * length / Double(n), y: last.y + sin(phi) * length / Double(n)))
            heading.append(angle + bend * Double(i + 1) / Double(n))
        }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...n {
            let t = Double(i) / Double(n)
            let w = halfWidth * pow(max(0, sin(.pi * pow(t, a))), fullness)
            let nx = -sin(heading[i]), ny = cos(heading[i])
            left.append(CGPoint(x: mid[i].x + nx * w, y: mid[i].y + ny * w))
            right.append(CGPoint(x: mid[i].x - nx * w, y: mid[i].y - ny * w))
        }
        var outline = Path.smooth(left + right.reversed())
        outline.closeSubpath()
        var rib = Path()
        rib.move(to: mid[0])
        for point in mid.dropFirst().dropLast(2) { rib.addLine(to: point) }
        return (outline, rib, mid[n])
    }

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
    /// A leaf in its depth tier: a shadow on what is behind it, its shade
    /// shape, the lit copy up and left of it, and its rib.
    func paint(_ c: GraphicsContext, leaf: (outline: Path, rib: Path, tip: CGPoint), tier: Int, shadow: Bool = true,
               litScale: Double = 0.7) {
        let box = leaf.outline.boundingRect
        let r = max(box.width, box.height) / 2
        let centre = CGPoint(x: box.midX, y: box.midY)
        if shadow && tier > 0 {
            c.fill(leaf.outline.offsetBy(dx: 1.4, dy: 2), with: .color(cast))
        }
        let paint = tiers[tier]
        c.fill(leaf.outline, with: .linearGradient(
            paint.shade,
            startPoint: CGPoint(x: centre.x + toLight.x * r, y: centre.y + toLight.y * r),
            endPoint: CGPoint(x: centre.x - toLight.x * r * 0.8, y: centre.y - toLight.y * r * 0.8)))
        let lit = leaf.outline.applying(
            CGAffineTransform(translationX: centre.x + toLight.x * r * 0.14, y: centre.y + toLight.y * r * 0.14)
                .scaledBy(x: litScale, y: litScale).translatedBy(x: -centre.x, y: -centre.y))
        c.fill(lit, with: .radialGradient(paint.lit, center: CGPoint(x: centre.x + toLight.x * r * 0.35, y: centre.y + toLight.y * r * 0.35),
                                          startRadius: 0, endRadius: r * 0.95))
        if tier > 0 { c.stroke(leaf.rib, with: .color(paint.vein), style: StrokeStyle(lineWidth: 0.9, lineCap: .round)) }
    }

    /// A stem: its shade, the lit edge, and the soft shadow of what is above.
    func paint(_ c: GraphicsContext, stem outline: Path, along points: [CGPoint], width: Double, tier: Int = 1) {
        let box = outline.boundingRect
        c.fill(outline, with: .linearGradient(
            Gradient(colors: [ramp[tier + 1].color(), ramp[tier].shifted(-3).color()]),
            startPoint: CGPoint(x: box.minX, y: box.midY), endPoint: CGPoint(x: box.maxX, y: box.midY)))
        guard points.count > 2 else { return }
        var edge = Path()
        let shift = width * 0.2
        for (i, point) in points.enumerated() {
            let q = CGPoint(x: point.x - shift, y: point.y)
            i == 0 ? edge.move(to: q) : edge.addLine(to: q)
        }
        c.stroke(edge, with: .color(ramp[tier + 2].color(0.7)), style: StrokeStyle(lineWidth: max(0.8, width * 0.22), lineCap: .round, lineJoin: .round))
    }

    /// Bloom colours: they open, glow and drain with the mood as a tree's do.
    func bloom(_ hex: UInt32, dim: Double = 0.5) -> RGB {
        let open = (0.5 + 0.5 * M.open) * (1 + 0.12 * M.glow) * (1 - 0.4 * M.doze)
        let (h, s, l) = RGB(hex).hsl
        return RGB.night(h, s * open, l, day: day, dim: dim)
    }
}

// MARK: - Leaves

extension PlantPainter {
    /// A leaf on a short petiole from `base`, pointing out to one `side` and
    /// `lift` radians above level. It hangs and curls as the house goes quiet.
    /// Returns where its tip is, for whatever hangs from the plant.
    @discardableResult
    func place(_ c: GraphicsContext?, _ m: inout Marks, at base: CGPoint, side s: Double, lift: Double, length: Double,
               tier: Int, petiole: Double = 5, curl: Double = 0.25, slim: Double = 1, hang: Double = 1.4,
               young: Double = 0, hangs: Bool = true) -> CGPoint {
        let angle = (s > 0 ? -lift : -.pi + lift) + s * wilt * hang
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let start = CGPoint(x: base.x + direction.x * petiole, y: base.y + direction.y * petiole)
        let leaf = Self.blade(at: start, angle: angle, length: length, halfWidth: length * plan.leafWidth * slim,
                              widest: plan.widest, bend: s * (curl + 0.8 * wilt))
        if let c {
            if petiole > 0.5 { c.fill(Self.ribbon([base, start], 2.2, 1.8), with: .color(ramp[1].color())) }
            paint(c, leaf: leaf, tier: tier)
            // A young leaf is lighter, and a glossy one has its shine along the rib.
            if young > 0 { c.fill(leaf.outline, with: .color(ramp[4].color(0.34 * young))) }
        }
        m.note(leaf.tip, hang: hangs)
        return leaf.tip
    }
}
