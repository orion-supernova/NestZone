import SwiftUI
import Synchronization

/// What a worn or hung thing is lit and coloured by: the sky's one light and
/// the hour, as `CritterLook` has them for a pet, so a hat on a kitten, a bow
/// on a pot and a chime in the window are lit from the side the sun (or the
/// moon) stands on. Worked out once per draw, never in a loop.
struct WearLook {
    typealias RGB = Canopy.RGB

    /// Towards the light, y up negative; never straight overhead.
    let L: CGPoint
    let day: Double
    /// 0 awake to 1 asleep: a quiet pet is paler, and so is what it wears.
    let slump: Double
    let dusk: Double
    let moon: Double
    /// The thin edge of light on the side that faces it: warm white at noon,
    /// amber when the sun is low, cool blue-white by the moon.
    let rim: RGB
    let rimAlpha: Double
    /// What shadow is tinted with: a cool violet, deeper at night.
    let cool: RGB
    let coolAlpha: Double

    init(L: CGPoint, day: Double, slump: Double = 0) {
        self.L = L
        self.day = day
        self.slump = slump
        dusk = 4 * day * (1 - day)
        moon = Ink.smooth((0.3 - day) / 0.3)
        rim = RGB(0xFFF3C4).mix(RGB(0xFF9A5C), Ink.clamp(dusk * 1.4)).mix(RGB(0xC4D2FF), moon)
        rimAlpha = (0.26 + 0.34 * Ink.clamp(dusk * 1.3) + 0.3 * moon) * (1 - 0.5 * slump)
        cool = RGB(0x6E5AA8).mix(RGB(0x2C2A78), moon)
        coolAlpha = 0.2 + 0.14 * moon
    }

    private init(_ other: WearLook, L: CGPoint) {
        (self.L, day, slump, dusk, moon) = (L, other.day, other.slump, other.dusk, other.moon)
        (rim, rimAlpha, cool, coolAlpha) = (other.rim, other.rimAlpha, other.cool, other.coolAlpha)
    }

    /// The same colours lit from another direction: the mirror image of a
    /// bow's far loop is lit from the other side.
    func lit(from L: CGPoint) -> WearLook { WearLook(self, L: L) }

    /// The sky's light across the scene for a sun or moon on `side` (-1 the
    /// far left, 1 the far right): the same vector `CritterLook` makes.
    static func light(side: Double, day: Double) -> CGPoint {
        let sx = abs(side) < 0.25 ? (side > 0 ? 0.25 : -0.25) : side
        let sy = -(0.45 + 0.4 * day)
        let len = (sx * sx * 0.81 + sy * sy).squareRoot()
        return CGPoint(x: sx * 0.9 / len, y: sy / len)
    }

    /// One colour as this hour leaves it, paler and greyer if the pet is quiet.
    func tone(_ hex: UInt32, dim: Double = 0.55) -> RGB { CritterLook.tone(hex, dim: dim, day: day, slump: slump) }

    func lifted(_ c: RGB, _ amount: Double = 0.3) -> RGB { c.mix(RGB(255, 255, 255), amount) }
}

/// The things a companion wears, drawn once for every body that wears them:
/// a pet's head or throat, a plant's crown or pot. Each is drawn about its own
/// origin (a hat stands on it, up is negative; a bow or scarf is tied at the
/// throat with its tails hanging down) and the caller moves, tilts and scales
/// the context, so the same drawing sits on a kitten's head, which nods, and
/// on a tree's crown, which sways.
///
/// Shapes are built once. A form is a gradient along the light with a rim of
/// the light on its lit edge and a cool shadow on the other (`form`); what
/// shares a colour is one path and one fill.
enum WearArt {
    typealias RGB = Canopy.RGB

    // MARK: Shading

    static func glow(_ c: GraphicsContext, _ path: Path, _ colour: RGB, centre: CGPoint, radius: Double, alpha: Double) {
        c.fill(path, with: .radialGradient(Gradient(colors: [colour.color(alpha), colour.color(0)]), center: centre, startRadius: 0, endRadius: radius))
    }

    /// A round form lit from the sky: rim, ramp along the light, cool core, highlight.
    static func form(_ c: GraphicsContext, _ path: Path, centre: CGPoint, radius r: Double, _ look: WearLook,
                     _ light: RGB, _ mid: RGB, _ dark: RGB, highlight: Double = 0.45, core: Double = 0.8, rim: Bool = true) {
        let L = look.L
        if rim, look.rimAlpha > 0.03 {
            var lit = c
            lit.translateBy(x: L.x * 0.8, y: L.y * 0.8)
            lit.fill(path, with: .color(look.rim.color(look.rimAlpha)))
        }
        c.fill(path, with: .linearGradient(
            Gradient(stops: [.init(color: light.color(), location: 0), .init(color: mid.color(), location: 0.5), .init(color: dark.color(), location: 1)]),
            startPoint: CGPoint(x: centre.x + L.x * r, y: centre.y + L.y * r), endPoint: CGPoint(x: centre.x - L.x * r, y: centre.y - L.y * r)))
        if core > 0 {
            glow(c, path, look.cool, centre: CGPoint(x: centre.x - L.x * r * 0.7, y: centre.y - L.y * r * 0.7), radius: r * 1.1, alpha: look.coolAlpha * core)
        }
        if highlight > 0 {
            glow(c, path, look.lifted(light, 0.35), centre: CGPoint(x: centre.x + L.x * r * 0.42, y: centre.y + L.y * r * 0.42), radius: r * 0.8, alpha: highlight)
        }
    }

    /// Light on one side and shade on the other, laid over flat colours that
    /// are already in the context's clip: how a striped thing gets its form.
    static func lit(_ c: GraphicsContext, _ rect: CGRect, _ look: WearLook, strength: Double = 1) {
        let L = look.L
        let mid = CGPoint(x: rect.midX, y: rect.midY), r = max(rect.width, rect.height) * 0.5
        c.fill(Path(rect), with: .linearGradient(
            Gradient(stops: [.init(color: Color.white.opacity(0.22 * strength), location: 0), .init(color: .clear, location: 0.45),
                             .init(color: look.cool.color(0.34 * strength), location: 1)]),
            startPoint: CGPoint(x: mid.x + L.x * r, y: mid.y + L.y * r), endPoint: CGPoint(x: mid.x - L.x * r, y: mid.y - L.y * r)))
    }

    /// The same light and shade laid over `path` itself, where `lit` is laid
    /// over a rectangle inside a clip. A clip is an offscreen pass in a
    /// `Canvas`, and a worn thing on a pet is drawn every frame, so the things
    /// that were clipped are cut to their shape once (`Path.intersection`) and
    /// filled plain.
    static func shade(_ c: GraphicsContext, _ path: Path, _ look: WearLook, strength: Double = 1) {
        let rect = path.boundingRect, L = look.L
        let mid = CGPoint(x: rect.midX, y: rect.midY), r = max(rect.width, rect.height) * 0.5
        c.fill(path, with: .linearGradient(
            Gradient(stops: [.init(color: Color.white.opacity(0.22 * strength), location: 0), .init(color: .clear, location: 0.45),
                             .init(color: look.cool.color(0.34 * strength), location: 1)]),
            startPoint: CGPoint(x: mid.x + L.x * r, y: mid.y + L.y * r), endPoint: CGPoint(x: mid.x - L.x * r, y: mid.y - L.y * r)))
    }

    // MARK: The party hat

    private static let cone: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -11, y: 0))
        p.addQuadCurve(to: CGPoint(x: 1, y: -30), control: CGPoint(x: -6, y: -16))
        p.addQuadCurve(to: CGPoint(x: 11, y: 0), control: CGPoint(x: 8, y: -15))
        p.addQuadCurve(to: CGPoint(x: -11, y: 0), control: CGPoint(x: 0, y: 4))
        return p
    }()

    private static let hatStripes: Path = {
        var p = Path()
        for (x0, y0) in [(-12.0, -6.0), (-10, -14), (-6, -22)] {
            p.move(to: CGPoint(x: x0, y: y0 + 3)); p.addLine(to: CGPoint(x: x0 + 26, y: y0 - 4))
        }
        return p
    }()

    private static let hatDots: Path = {
        var p = Path()
        for (x, y) in [(-1.0, -9.0), (3, -16), (-3, -19), (5, -7), (-6, -12)] { p.addEllipse(in: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)) }
        return p
    }()

    private static let hatTuft: Path = {
        var p = Path()
        for a in stride(from: -2.6, through: -0.5, by: 0.35) {
            p.move(to: CGPoint(x: 1, y: -30)); p.addLine(to: CGPoint(x: 1 + cos(a) * 5.5, y: -30 + sin(a) * 5.5))
        }
        return p
    }()

    /// The stripes, the band and the dots, already cut to the cone.
    private static let hatInside: (stripes: Path, band: Path, dots: Path) = (
        hatStripes.strokedPath(StrokeStyle(lineWidth: 2.2, lineCap: .round)).intersection(cone),
        Path(ellipseIn: CGRect(x: -10, y: -3.4, width: 20, height: 7)).intersection(cone),
        hatDots.intersection(cone))

    /// A cone of coloured paper with a pompom, its foot on the origin: pink
    /// with gold stripes and dots and a thin elastic down each cheek. `strap`
    /// is for a head; a plant has no chin.
    static func partyHat(_ c: GraphicsContext, _ look: WearLook, strap: Bool = false) {
        let pale = look.tone(0xFF9CC8), pink = look.tone(0xF25C9B), deep = look.tone(0xC93A7C), gold = look.tone(0xFFE08A)
        if strap {
            var elastic = Path()
            for s in [-1.0, 1] {
                elastic.move(to: CGPoint(x: s * 10, y: 0.5))
                elastic.addQuadCurve(to: CGPoint(x: s * 14.5, y: 15), control: CGPoint(x: s * 13.5, y: 6))
            }
            c.stroke(elastic, with: .color(gold.color(0.7)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        }
        // Where it sits: a soft shade on the fur under the brim.
        c.fill(Path(ellipseIn: CGRect(x: -12, y: -2, width: 24, height: 8)), with: .color(Color.black.opacity(0.15)))
        form(c, cone, centre: CGPoint(x: 0, y: -14), radius: 17, look, pale, pink, deep, highlight: 0.35, core: 0.7)
        c.fill(hatInside.stripes, with: .color(gold.color()))
        c.fill(hatInside.band, with: .color(gold.color(0.92)))
        c.fill(hatInside.dots, with: .color(Color.white.opacity(0.78)))
        shade(c, cone, look, strength: 0.8)
        // The pompom on its tuft of ribbon.
        c.stroke(hatTuft, with: .color(gold.color()), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        form(c, Path(ellipseIn: CGRect(x: -2.4, y: -34.4, width: 6.8, height: 6.8)), centre: CGPoint(x: 1, y: -31), radius: 3.4, look, look.lifted(gold, 0.5), gold, gold.shifted(-14), highlight: 0.5, core: 0.5)
    }

    // MARK: The tiny crown

    private static let crownTips: [CGPoint] = [CGPoint(x: -12.5, y: -14), CGPoint(x: -6.2, y: -17.5), CGPoint(x: 0, y: -21.5),
                                              CGPoint(x: 6.2, y: -17.5), CGPoint(x: 12.5, y: -14)]

    /// Five points joined by scooped valleys, over a band that curves round the head.
    private static let crownBody: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -11.5, y: 0))
        p.addLine(to: crownTips[0])
        for i in 0..<4 {
            let a = crownTips[i], b = crownTips[i + 1]
            p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: -2.2))
        }
        p.addLine(to: CGPoint(x: 11.5, y: 0))
        p.addQuadCurve(to: CGPoint(x: -11.5, y: 0), control: CGPoint(x: 0, y: 3.6))
        return p
    }()

    private static let crownBand: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -12, y: -5.4))
        p.addQuadCurve(to: CGPoint(x: 12, y: -5.4), control: CGPoint(x: 0, y: -2.4))
        p.addLine(to: CGPoint(x: 11.5, y: 0))
        p.addQuadCurve(to: CGPoint(x: -11.5, y: 0), control: CGPoint(x: 0, y: 3.6))
        p.closeSubpath()
        return p
    }()

    private static let crownVelvet = Path(ellipseIn: CGRect(x: -10.6, y: -16.5, width: 21.2, height: 15))

    /// A gold crown, its foot on the origin: a velvet cap showing between the
    /// points, pearls on the tips, a ruby and two sapphires in the band, and a
    /// glint that comes and goes (`glint` 0 to 1).
    static func crown(_ c: GraphicsContext, _ look: WearLook, glint: Double = 0.6) {
        let gold = look.tone(0xF2C14E, dim: 0.75), pale = look.tone(0xFFE9A0, dim: 0.75), deep = look.tone(0xA8741A, dim: 0.75)
        let velvet = look.tone(0xB02A48, dim: 0.7)
        c.fill(Path(ellipseIn: CGRect(x: -12.5, y: -2, width: 25, height: 8)), with: .color(Color.black.opacity(0.16)))
        c.fill(crownVelvet, with: .linearGradient(Gradient(colors: [velvet.shifted(8).color(), velvet.shifted(-14, 4).color()]),
                                                  startPoint: CGPoint(x: 0, y: -16), endPoint: CGPoint(x: 0, y: -2)))
        form(c, crownBody, centre: CGPoint(x: 0, y: -9), radius: 14, look, pale, gold, deep, highlight: 0.5, core: 0.7)
        // The band is a shade darker, with a bright line on its upper edge.
        c.fill(crownBand, with: .linearGradient(Gradient(colors: [gold.shifted(-6).color(), deep.color()]), startPoint: CGPoint(x: 0, y: -5), endPoint: CGPoint(x: 0, y: 3)))
        var edge = Path()
        edge.move(to: CGPoint(x: -12, y: -5.4))
        edge.addQuadCurve(to: CGPoint(x: 12, y: -5.4), control: CGPoint(x: 0, y: -2.4))
        c.stroke(edge, with: .color(look.lifted(pale, 0.4).color(0.85)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        // Jewels in gold settings.
        let ruby = look.tone(0xD9304F, dim: 0.8), sapphire = look.tone(0x3F73DB, dim: 0.8)
        for (x, y, r, stone) in [(-6.6, -1.4, 2.0, sapphire), (0.0, -1.0, 2.6, ruby), (6.6, -1.4, 2.0, sapphire)] {
            c.circle(x, y, r + 0.9, .color(deep.shifted(6).color()))
            c.circle(x, y, r, .color(stone.color()))
            c.circle(x - r * 0.3, y - r * 0.35, r * 0.4, .color(Color.white.opacity(0.75)))
        }
        // Pearls on the points.
        var pearls = Path()
        for tip in crownTips { pearls.addEllipse(in: CGRect(x: tip.x - 1.9, y: tip.y - 3.4, width: 3.8, height: 3.8)) }
        c.fill(pearls, with: .color(look.tone(0xFFF4E2, dim: 0.5).color()))
        var shine = Path()
        for tip in crownTips { shine.addEllipse(in: CGRect(x: tip.x - 1.1, y: tip.y - 2.8, width: 1.3, height: 1.1)) }
        c.fill(shine, with: .color(Color.white.opacity(0.9)))
        if glint > 0.02 { c.glint(crownTips[2].x + 2.6, crownTips[2].y - 4, 1.1 * glint, Color.white.opacity(0.95 * glint)) }
    }

    // MARK: The bow

    private static let bowLoop: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -1, y: 0))
        p.addCurve(to: CGPoint(x: -15.5, y: -2), control1: CGPoint(x: -4, y: -9.5), control2: CGPoint(x: -15, y: -10.5))
        p.addCurve(to: CGPoint(x: -1, y: 1), control1: CGPoint(x: -16.5, y: 6.5), control2: CGPoint(x: -6, y: 9.5))
        p.closeSubpath()
        return p
    }()

    private static let bowFold: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -2.2, y: 0))
        p.addCurve(to: CGPoint(x: -12, y: -1.6), control1: CGPoint(x: -5, y: -5), control2: CGPoint(x: -11, y: -6))
        p.addCurve(to: CGPoint(x: -2.2, y: 0.8), control1: CGPoint(x: -12.4, y: 3), control2: CGPoint(x: -7, y: 5))
        p.closeSubpath()
        return p
    }()

    private static let bowSheen: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -4, y: -4.6))
        p.addQuadCurve(to: CGPoint(x: -13.4, y: -4.2), control: CGPoint(x: -9.5, y: -9))
        p.addQuadCurve(to: CGPoint(x: -4.4, y: -2.6), control: CGPoint(x: -9.5, y: -6.2))
        p.closeSubpath()
        return p
    }()

    /// A swallowtail hanging from the knot, for the left; the right is its mirror.
    private static let bowTail: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -1, y: 1.5))
        p.addLine(to: CGPoint(x: -4.8, y: 2.4))
        p.addQuadCurve(to: CGPoint(x: -11.2, y: 16.5), control: CGPoint(x: -8.4, y: 8))
        p.addLine(to: CGPoint(x: -8.2, y: 13.4))
        p.addLine(to: CGPoint(x: -6, y: 16.2))
        p.addQuadCurve(to: CGPoint(x: -1.4, y: 5), control: CGPoint(x: -3.2, y: 10))
        p.closeSubpath()
        return p
    }()

    /// A satin ribbon bow in berry pink on a collar that goes round the throat,
    /// `span` either side of the origin; the bow's knot sits on the origin and
    /// is `size` times the usual 31 across.
    static func bow(_ c: GraphicsContext, _ look: WearLook, span: Double, size: Double = 1) {
        let pale = look.tone(0xFF9FB8, dim: 0.65), mid = look.tone(0xE94E75, dim: 0.65), deep = look.tone(0xA6224C, dim: 0.65)
        // The collar: a band curving round the neck, tucked behind the head at both ends.
        var collar = Path()
        collar.move(to: CGPoint(x: -span, y: -3.4))
        collar.addQuadCurve(to: CGPoint(x: span, y: -3.4), control: CGPoint(x: 0, y: 3.4))
        collar.addLine(to: CGPoint(x: span - 0.3, y: 0.2))
        collar.addQuadCurve(to: CGPoint(x: -span + 0.3, y: 0.2), control: CGPoint(x: 0, y: 7))
        collar.closeSubpath()
        c.fill(collar.offsetBy(dx: 0, dy: 1.6), with: .color(Color.black.opacity(0.14)))
        form(c, collar, centre: CGPoint(x: 0, y: 1), radius: span, look, pale, mid, deep, highlight: 0.3, core: 0.7)
        var b = c
        b.scaleBy(x: size, y: size)
        let L = look.L
        for side in [-1.0, 1] {
            var s = b
            s.scaleBy(x: side, y: 1)
            // The tail first, then the loop over it.
            var tail = s
            tail.rotate(by: .radians(side * -0.07))
            if side > 0 { tail.scaleBy(x: 1, y: 0.86) }
            let eL = CGPoint(x: L.x * side, y: L.y)
            let sub = look.lit(from: eL)
            form(tail, bowTail, centre: CGPoint(x: -6, y: 9), radius: 11, sub, deep.mix(pale, 0.35), deep.mix(mid, 0.5), deep.shifted(-6), highlight: 0.2, core: 0.5)
            form(s, bowLoop, centre: CGPoint(x: -8, y: 0), radius: 11, sub, pale, mid, deep, highlight: 0.4, core: 0.6)
            s.fill(bowFold, with: .color(deep.color(0.55)))
            s.fill(bowSheen, with: .color(Color.white.opacity(0.42)))
        }
        form(b, Path(ellipseIn: CGRect(x: -3.6, y: -3.8, width: 7.2, height: 7.8)), centre: CGPoint(x: 0, y: 0), radius: 4.4, look, pale, mid, deep, highlight: 0.55, core: 0.5)
        var crease = Path()
        crease.move(to: CGPoint(x: -1.6, y: -2.6)); crease.addQuadCurve(to: CGPoint(x: -1.4, y: 2.8), control: CGPoint(x: -2.4, y: 0))
        b.stroke(crease, with: .color(deep.color(0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
    }

    // MARK: The scarf

    /// A scarf's shapes for one span and size, cut to their outlines once.
    private struct ScarfParts {
        var band, tail, fold: Path
        var bandStripes, bandRibs, tailStripes, tailKnit, fringe, lip, foldStripe: Path
    }

    private static let scarves = Mutex<[Int: ScarfParts]>([:])

    private static func scarfParts(span: Double, size: Double) -> ScarfParts {
        let key = Int((span * 10).rounded()) * 1000 + Int((size * 100).rounded())
        return scarves.withLock { cache in
            if let found = cache[key] { return found }
            let made = makeScarf(span: span, size: size)
            cache[key] = made
            return made
        }
    }

    private static func makeScarf(span: Double, size: Double) -> ScarfParts {
        var band = Path()
        band.move(to: CGPoint(x: -span, y: -6))
        band.addQuadCurve(to: CGPoint(x: span, y: -6), control: CGPoint(x: 0, y: 2.6 * size))
        band.addQuadCurve(to: CGPoint(x: -span, y: -6), control: CGPoint(x: 0, y: 12.6 * size))
        band.closeSubpath()
        let knotX = span * 0.34, length = 25 * size, wide = 4.8 * size
        var tail = Path()
        tail.move(to: CGPoint(x: knotX - wide, y: 2))
        tail.addLine(to: CGPoint(x: knotX + wide, y: 2.6))
        tail.addQuadCurve(to: CGPoint(x: knotX + wide - 0.6, y: length), control: CGPoint(x: knotX + wide + 1.2, y: length * 0.5))
        tail.addLine(to: CGPoint(x: knotX - wide + 0.4, y: length - 0.4))
        tail.addQuadCurve(to: CGPoint(x: knotX - wide, y: 2), control: CGPoint(x: knotX - wide - 1, y: length * 0.5))
        tail.closeSubpath()
        var fringe = Path()
        for i in 0..<6 {
            let x = knotX - wide + 0.8 + Double(i) * (wide * 2 - 1.6) / 5
            fringe.move(to: CGPoint(x: x, y: length - 0.6)); fringe.addLine(to: CGPoint(x: x + (i.isMultiple(of: 2) ? -0.5 : 0.5), y: length + 4.4 * size))
        }
        var tailStripes = Path(), tailKnit = Path()
        var y = 5.0 * size
        while y < length {
            tailStripes.addRect(CGRect(x: knotX - wide - 2, y: y, width: wide * 2 + 4, height: 2.5 * size))
            y += 5.6 * size
        }
        y = 3.2
        while y < length - 1 {
            for k in -1...1 {
                let x = knotX + Double(k) * wide * 0.62
                tailKnit.move(to: CGPoint(x: x - 1.1, y: y)); tailKnit.addLine(to: CGPoint(x: x, y: y + 1.5)); tailKnit.addLine(to: CGPoint(x: x + 1.1, y: y))
            }
            y += 3.2
        }
        var stripes = Path(), ribs = Path()
        var x = -span + 1.5
        while x < span {
            stripes.addRect(CGRect(x: x, y: -10, width: 2.6, height: 28 * size))
            x += 5.6
        }
        x = -span
        while x < span {
            ribs.move(to: CGPoint(x: x, y: -8)); ribs.addLine(to: CGPoint(x: x + 0.6, y: 14 * size))
            x += 2.3
        }
        var lip = Path()
        lip.move(to: CGPoint(x: -span + 1, y: -4.6))
        lip.addQuadCurve(to: CGPoint(x: span - 1, y: -4.6), control: CGPoint(x: 0, y: 2.8 * size))
        let fold = Path(roundedRect: CGRect(x: knotX - wide - 1.6, y: 0.4, width: wide * 2 + 3.2, height: 6.4 * size), cornerRadius: 3 * size)
        let foldStripe = Path(CGRect(x: knotX - wide - 2, y: 2.4 * size, width: wide * 2 + 4, height: 1.6 * size)).intersection(fold)
        return ScarfParts(
            band: band, tail: tail, fold: fold,
            bandStripes: stripes.intersection(band),
            bandRibs: ribs.strokedPath(StrokeStyle(lineWidth: 0.5)).intersection(band),
            tailStripes: tailStripes.intersection(tail),
            tailKnit: tailKnit.strokedPath(StrokeStyle(lineWidth: 0.55, lineCap: .round, lineJoin: .round)).intersection(tail),
            fringe: fringe.strokedPath(StrokeStyle(lineWidth: 1.15, lineCap: .round)),
            lip: lip.strokedPath(StrokeStyle(lineWidth: 0.7, lineCap: .round)), foldStripe: foldStripe)
    }

    /// A knitted scarf round the throat, `span` either side of the origin:
    /// cranberry with cream stripes, one end hanging down the chest with a
    /// fringe. `size` scales the band's depth and the hanging end.
    static func scarf(_ c: GraphicsContext, _ look: WearLook, span: Double, size: Double = 1) {
        let wool = look.tone(0xC93A4E, dim: 0.65), cream = look.tone(0xF6E8C8, dim: 0.55), deepWool = wool.shifted(-12, 3)
        let parts = scarfParts(span: span, size: size)
        // The shade of the band and of the hanging end on the chest under them.
        c.fill(parts.band.offsetBy(dx: 0, dy: 2.2), with: .color(Color.black.opacity(0.14)))
        c.fill(parts.tail.offsetBy(dx: 1.4, dy: 1.6), with: .color(Color.black.opacity(0.14)))
        // The hanging end: wool, cream stripes, the knit's small vees, a fringe.
        c.fill(parts.fringe, with: .color(wool.color()))
        c.fill(parts.tail, with: .color(wool.color()))
        c.fill(parts.tailStripes, with: .color(cream.color()))
        c.fill(parts.tailKnit, with: .color(deepWool.color(0.5)))
        shade(c, parts.tail, look)
        // The band: stripes round it, ribbed, lit like a roll of wool.
        c.fill(parts.band, with: .color(wool.color()))
        c.fill(parts.bandStripes, with: .color(cream.color()))
        c.fill(parts.bandRibs, with: .color(deepWool.color(0.28)))
        shade(c, parts.band, look)
        // Its lower edge catches a little light, and the knot's fold lies over the end.
        c.fill(parts.lip, with: .color(look.rim.color(look.rimAlpha * 0.7)))
        c.fill(parts.fold, with: .color(wool.color()))
        c.fill(parts.foldStripe, with: .color(cream.color()))
        shade(c, parts.fold, look)
    }
}
