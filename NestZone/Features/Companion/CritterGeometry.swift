import SwiftUI

extension Path {
    /// A tapered, slightly bowed stroke: a hair clump, a tabby stripe. It
    /// starts at (x, y), heads `a` radians for `len`, is `w` wide at its
    /// widest (half-width) and bows `bend` to one side.
    mutating func fur(_ x: Double, _ y: Double, _ a: Double, _ len: Double, _ w: Double, bend: Double = 0) {
        let ca = cos(a), sa = sin(a)
        let end = CGPoint(x: x + ca * len, y: y + sa * len)
        let mx = x + ca * len * 0.5 - sa * bend, my = y + sa * len * 0.5 + ca * bend
        move(to: CGPoint(x: x, y: y))
        addQuadCurve(to: end, control: CGPoint(x: mx - sa * w * 2, y: my + ca * w * 2))
        addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: mx + sa * w * 2, y: my - ca * w * 2))
        closeSubpath()
    }

    /// A smooth curve through points, closed, built the way a ribbon is.
    static func loop(_ points: [CGPoint]) -> Path {
        var p = Path.smooth(points)
        p.closeSubpath()
        return p
    }
}

/// Everything a pet is built from that does not change while it lives: the
/// shapes of its body and head, built once per plan and kept. Per frame a
/// painter only fills them, and moves the few parts that act (the tail, the
/// ears, the eyes, the whiskers). Coordinates are the 120-unit box of
/// `CritterPainter`, feet at (60, 108).
struct SitGeometry {
    let body, stripes, hairs: Path
    /// The body with fur breaking its edge, on the shadow side more than the lit
    /// one: [0] for a light from the right (shadow to the left), [1] for the left.
    let bodyFur: [Path]
    let chest: Path
    let haunch, haunchBars, haunchHairs: Path
    let hindPaw, hindToes: Path
    let nearLeg, nearPaw, nearToes, nearBars: Path
    let farLeg, farPaw: Path
    /// The legs from the ankle down, for a plan with socks.
    let nearSock, farSock: Path
    /// A hamster's forearms and paws, held up at the chest, and the sunflower
    /// seed they hold when it is bright.
    let arms, handPaws, handToes, seed, seedStripes: Path
    /// A rabbit's tail: a ball of white fur about its own origin, edged with
    /// fur.
    let cotton: Path
    /// A fawn's white spots on the back and the haunch.
    let spots, haunchSpots: Path
    /// Where the form's centre is, for the gradients.
    let bodyCentre = CGPoint(x: 68, y: 84)

    init(_ plan: CritterPlan) {
        let bw = plan.bodyWidth, fur = plan.fur
        func wide(_ x: Double) -> Double { 66 + (x - 66) * bw }
        let outline: [(Double, Double)]
        switch plan.species {
        case .hamster: outline = [(39, 66), (58, 57), (84, 60), (99, 80), (98, 101), (72, 111), (46, 111), (32, 92)]
        case .bunny: outline = [(42, 66), (58, 58), (82, 60), (98, 80), (98, 100), (70, 110), (46, 110), (35, 90)]
        default: outline = [(40, 66), (58, 57), (82, 62), (96, 84), (93, 103), (68, 109), (44, 109), (34, 90)]
        }
        let bodyPath = Path.loop(outline.map { CGPoint(x: wide($0.0), y: $0.1) })
        body = bodyPath

        var s = Path()
        let ribs: [(Double, Double, Double, Double, Double, Double)] = [
            (58.5, 60.5, 1.95, 17, 1.6, -3.5), (66, 60, 1.85, 20, 1.7, -3.5), (74, 62, 1.72, 20, 1.7, -3),
            (82, 66, 1.58, 18, 1.7, -2.5), (89.5, 73, 1.42, 14, 1.6, -2), (62, 69, 1.9, 10, 1.1, -2), (72, 70, 1.8, 10, 1.1, -2)]
        for (x, y, a, len, w, bend) in ribs { s.fur(wide(x), y, a, len, w * 0.6, bend: bend) }
        stripes = s

        // Painted fur: short hair strokes that go round the form, lit on one
        // edge by a shifted copy of the same path.
        var r = Ink.Random("hair-\(plan.key)")
        var h = Path()
        for gy in stride(from: 61.0, through: 106, by: 5.2) {
            for gx in stride(from: 47.0, through: 96, by: 5.2) {
                let x = wide(gx) + r.between(-2, 2), y = gy + r.between(-2, 2)
                let dx = (x - 68) / 29, dy = (y - 84) / 26
                guard dx * dx + dy * dy < 0.92, !(x < 58 && y > 72) else { continue }
                let a = atan2(y - 84, x - 68) + .pi / 2 + r.between(-0.25, 0.25)
                h.fur(x, y, a, r.between(4.2, 6.2), 0.7)
            }
        }
        hairs = h

        // Fur breaks the body's edge from inside it, more on the shadow side.
        func furred(_ shadowRight: Double) -> Path {
            FurEdge.furry(bodyPath, seed: "body-\(plan.key)-\(shadowRight)", gap: 6...12, height: (1.4 * fur)...(3.0 * fur), width: 3.8) { p in
                0.3 + 0.7 * Ink.smooth(((p.x - 66) * shadowRight) / 26)
            }
        }
        bodyFur = [furred(-1), furred(1)]
        // The chest is narrower than it was: the near leg covers its left edge,
        // so no pale rim shows around the leg.
        let bib = plan.bib
        let chestPath = Path.loop([CGPoint(x: 45, y: 71), CGPoint(x: 57, y: 77), CGPoint(x: 58.5, y: 95), CGPoint(x: 53, y: 107), CGPoint(x: 45, y: 107),
                                   CGPoint(x: 43, y: 94), CGPoint(x: 42, y: 79)])
        // A bib reaches up to the throat and wider across, about the chest's middle.
        chest = bib == 1 ? chestPath : chestPath.applying(CGAffineTransform(translationX: 57, y: 92).scaledBy(x: 1 + 0.08 * (bib - 1), y: bib).translatedBy(x: -57, y: -92))

        haunch = Path(ellipseIn: CGRect(x: 58, y: 74, width: 38, height: 34))
        var hb = Path()
        for (x, y, a, len, bend) in [(92.0, 80.0, 2.55, 11.0, 2.0), (95, 89, 2.85, 11.5, 1.2), (91, 98, 3.15, 10.0, 0.0)] {
            hb.fur(wide(x), y, a, len, 1.3, bend: bend)
        }
        haunchBars = hb
        var hh = Path()
        for (x, y) in [(66.0, 84.0), (72, 80), (79, 78), (86, 82), (70, 92), (77, 90), (84, 92), (73, 99), (81, 100), (66, 97)] {
            let a = atan2(y - 91, x - 77) + .pi / 2 + r.between(-0.2, 0.2)
            hh.fur(x + r.between(-1, 1), y + r.between(-1, 1), a, r.between(4, 5.6), 0.65)
        }
        haunchHairs = hh

        hindPaw = Path(ellipseIn: CGRect(x: 55, y: 102.4, width: 30, height: 9.2))
        var ht = Path()
        for x in [58.6, 61.6, 64.6] { ht.move(to: CGPoint(x: x, y: 105.2)); ht.addLine(to: CGPoint(x: x - 0.8, y: 108.4)) }
        hindToes = ht

        // A fawn's legs are thin and a cub's stout: the same legs, narrowed or
        // widened about their own middle.
        let lw = plan.legWidth
        func stout(_ p: Path, _ cx: Double) -> Path {
            lw == 1 ? p : p.applying(CGAffineTransform(translationX: cx, y: 0).scaledBy(x: lw, y: 1).translatedBy(x: -cx, y: 0))
        }
        let nearLegPath = stout(.loop([CGPoint(x: 37, y: 79), CGPoint(x: 49.5, y: 79), CGPoint(x: 48, y: 94), CGPoint(x: 50.2, y: 104), CGPoint(x: 36.5, y: 104), CGPoint(x: 39.5, y: 93)]), 43)
        nearLeg = nearLegPath
        nearPaw = stout(Path(ellipseIn: CGRect(x: 35.2, y: 101.6, width: 17, height: 8.6)), 43.7)
        var nt = Path()
        for x in [39.4, 43.6, 47.8] { nt.move(to: CGPoint(x: 43.7 + (x - 43.6) * lw, y: 106.2)); nt.addLine(to: CGPoint(x: 43.7 + (x - 43.6) * lw, y: 109)) }
        nearToes = nt
        var nb = Path()
        nb.fur(38.5, 86, 0.2, 9, 1.4, bend: 1)
        nb.fur(39.5, 92, 0.15, 8, 1.3, bend: 1)
        nearBars = nb

        let farLegPath = stout(.loop([CGPoint(x: 51, y: 82), CGPoint(x: 62, y: 82), CGPoint(x: 61, y: 95), CGPoint(x: 63, y: 105), CGPoint(x: 50, y: 105), CGPoint(x: 52, y: 94)]), 56.5)
        farLeg = farLegPath
        farPaw = stout(Path(ellipseIn: CGRect(x: 50, y: 102.4, width: 14, height: 7.4)), 57)

        let lower = Path(CGRect(x: 0, y: 91, width: 120, height: 30))
        nearSock = plan.socks == nil ? Path() : nearLegPath.intersection(lower)
        farSock = plan.socks == nil ? Path() : farLegPath.intersection(lower)

        var a = Path(), hp = Path(), ht2 = Path(), sd = Path(), ss = Path()
        if plan.species == .hamster {
            // Two short arms from the body, two small paws up under the chin.
            a.addPath(Path.loop([CGPoint(x: 33, y: 98), CGPoint(x: 35, y: 89), CGPoint(x: 39, y: 82), CGPoint(x: 44.5, y: 84), CGPoint(x: 42, y: 93), CGPoint(x: 41.5, y: 100)]))
            a.addPath(Path.loop([CGPoint(x: 62, y: 100), CGPoint(x: 60, y: 90), CGPoint(x: 55, y: 82), CGPoint(x: 50, y: 85), CGPoint(x: 52.5, y: 93), CGPoint(x: 54, y: 101)]))
            for x in [40.5, 53.5] { hp.addEllipse(in: CGRect(x: x - 5.8, y: 73, width: 11.6, height: 9)) }
            for x in [38.6, 40.6, 42.6, 51.6, 53.6, 55.6] { ht2.move(to: CGPoint(x: x, y: 74.6)); ht2.addLine(to: CGPoint(x: x, y: 77.8)) }
            // A sunflower seed: a pointed teardrop, striped, held across the paws.
            sd = .loop([CGPoint(x: -6.4, y: 0.2), CGPoint(x: -2.4, y: -3.2), CGPoint(x: 3.6, y: -3), CGPoint(x: 7.4, y: 0.2), CGPoint(x: 3.6, y: 3), CGPoint(x: -2.4, y: 3.2)])
            for dy in [-1.8, 0.0, 1.8] { ss.move(to: CGPoint(x: -4.4, y: dy * 0.9)); ss.addQuadCurve(to: CGPoint(x: 5.4, y: dy * 0.5), control: CGPoint(x: 0.4, y: dy * 1.1 - 0.4)) }
        }
        // A fawn's spots: soft ovals laid along the form, back and haunch.
        var sp = Path(), hs = Path()
        if plan.marks == .spots {
            func dot(_ path: inout Path, _ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ a: Double) {
                path.addPath(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)).applying(CGAffineTransform(translationX: x, y: y).rotated(by: a)))
            }
            for (x, y, rx, ry, a) in [(50.0, 66.0, 2.3, 1.6, -0.5), (58, 61.5, 2.6, 1.7, -0.25), (67, 60.6, 2.8, 1.8, -0.05), (76, 62.2, 2.6, 1.7, 0.25),
                                      (84, 67, 2.4, 1.6, 0.6), (89, 75, 2.2, 1.5, 1.0), (55, 70, 2.0, 1.4, -0.3), (63.5, 67, 2.3, 1.5, -0.1),
                                      (72, 67.5, 2.3, 1.5, 0.1), (80, 72, 2.2, 1.5, 0.5), (60, 77, 1.8, 1.3, 0), (68.5, 74.5, 2.0, 1.4, 0.1)] {
                dot(&sp, wide(x), y, rx, ry, a)
            }
            for (x, y, rx, ry, a) in [(73.0, 82.0, 2.4, 1.6, -0.5), (83, 80, 2.4, 1.6, 0.3), (89, 89, 2.2, 1.5, 1.1), (78, 90, 2.3, 1.5, 0),
                                      (70, 95, 2.0, 1.4, -0.2), (84, 98, 2.0, 1.4, 0.9), (76, 101, 1.8, 1.2, 0)] {
                dot(&hs, wide(x), y, rx, ry, a)
            }
        }
        spots = sp; haunchSpots = hs
        arms = a; handPaws = hp; handToes = ht2; seed = sd; seedStripes = ss
        cotton = plan.tail == .cotton
            ? FurEdge.furry(Path(ellipseIn: CGRect(x: -7.2, y: -7.2, width: 14.4, height: 14.4)), seed: "cotton-\(plan.key)", gap: 1.8...3.2, height: 0.9...2.1, width: 2.4)
            : Path()
    }
}

/// The curled-up pose, in the same box: a round of fur lying on the floor.
struct CurlGeometry {
    let body, stripes, hairs, haunch, haunchBars: Path
    let spots: Path
    let bodyFur: [Path]

    init(_ plan: CritterPlan) {
        let fur = plan.fur
        let bodyPath = Path.loop([CGPoint(x: 22, y: 102), CGPoint(x: 30, y: 83), CGPoint(x: 54, y: 74), CGPoint(x: 82, y: 75), CGPoint(x: 102, y: 84),
                                  CGPoint(x: 106, y: 101), CGPoint(x: 92, y: 112), CGPoint(x: 54, y: 113), CGPoint(x: 28, y: 110)])
        body = bodyPath
        var s = Path()
        for (x, y, a, len, bend) in [(46.0, 76.5, 1.7, 14.0, -2.0), (55, 75.2, 1.62, 16, -2), (65, 74.8, 1.57, 17, -1.5), (75, 75.2, 1.5, 17, -1),
                                      (85, 78, 1.4, 16, -1), (94, 83, 1.25, 14, -1), (101, 91, 1.1, 11, -1)] {
            s.fur(x, y, a, len, 1.4, bend: bend)
        }
        stripes = s
        var r = Ink.Random("curl-\(plan.key)")
        var h = Path()
        for gy in stride(from: 77.0, through: 111, by: 5.0) {
            for gx in stride(from: 32.0, through: 103, by: 5.2) {
                let x = gx + r.between(-2, 2), y = gy + r.between(-2, 2)
                let dx = (x - 66) / 38, dy = (y - 94) / 19
                guard dx * dx + dy * dy < 0.9 else { continue }
                let a = atan2(y - 94, x - 66) + .pi / 2 + r.between(-0.25, 0.25)
                h.fur(x, y, a, r.between(4.2, 6.2), 0.7)
            }
        }
        hairs = h
        haunch = Path(ellipseIn: CGRect(x: 64, y: 80, width: 36, height: 31))
        var hb = Path()
        for (x, y, a, len, bend) in [(98.0, 88.0, 2.5, 11.0, 2.0), (99, 97, 2.85, 11, 1), (95, 105, 3.1, 10, 0)] { hb.fur(x, y, a, len, 1.3, bend: bend) }
        haunchBars = hb
        func furred(_ shadowRight: Double) -> Path {
            FurEdge.furry(bodyPath, seed: "curl-\(plan.key)-\(shadowRight)", gap: 6...12, height: (1.4 * fur)...(3.0 * fur), width: 3.8) { p in
                0.3 + 0.7 * Ink.smooth(((p.x - 64) * shadowRight) / 30)
            }
        }
        bodyFur = [furred(-1), furred(1)]
        var sp = Path()
        if plan.marks == .spots {
            for (x, y, rx, ry, a) in [(40.0, 82.0, 2.4, 1.6, -0.6), (50, 78.5, 2.7, 1.7, -0.3), (60, 76.8, 2.8, 1.8, -0.1), (70, 76.5, 2.8, 1.8, 0.05),
                                      (80, 78, 2.7, 1.7, 0.25), (90, 82, 2.5, 1.6, 0.55), (97, 89, 2.2, 1.5, 1.0), (45, 88, 2.0, 1.4, -0.4), (56, 84, 2.4, 1.5, -0.2),
                                      (66, 83, 2.4, 1.5, 0), (76, 85, 2.4, 1.5, 0.2), (85, 90, 2.3, 1.5, 0.6), (70, 92, 2.0, 1.4, 0.1), (91, 98, 2.0, 1.4, 0.9)] {
                sp.addPath(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)).applying(CGAffineTransform(translationX: x, y: y).rotated(by: a)))
            }
        }
        spots = sp
    }
}

/// The head, in its own space: origin at its centre, the face looking at us.
struct HeadGeometry {
    let head: Path
    let headFur: Path
    let brow, liner, cheekStripes: Path
    let muzzle, whiskerDots: Path
    let nose: Path
    let mouthLine: Path
    /// One ear, for the side +1, standing up from its own origin; the other is
    /// the same mirrored. The inner ear, and the cream hairs in it.
    let ear, earInner, earHairs: Path
    /// A bunny's ear at five steps of flop, from standing (0) to laid back (1):
    /// a bent ear cannot be a transform, so the bends are built once and the
    /// painter picks (or fades between) two of them.
    let earBends: [Path], earInnerBends: [Path]
    /// What the ear's colour (`CritterPlan.earColour`) covers: the top of a
    /// fox's ear, from the back.
    let earTip: Path
    /// A puppy's ear with its fur edge.
    let earFur: Path
    /// A hamster's pouches, the fox's white cheeks, the fox's dark tear lines.
    let pouches, cheekWhite, tears: Path
    /// A pup's pale blaze, from the crown to the muzzle.
    let blaze: Path
    /// How far the nose and the mouth sit below the kitten's: a long muzzle
    /// carries them to its end.
    let drop: Double
    let earHeight: Double
    let w: Double

    init(_ plan: CritterPlan) {
        let w = 21 * plan.headWidth
        self.w = w
        let fur = plan.fur
        let c = plan.chin, k = plan.cheek
        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
        // The lower face, right side: out to the cheek, round to the chin.
        let toX = w * lerp(0.42, 0.15, c), toY = lerp(16, 19.6, c)
        let c1 = CGPoint(x: w * (1.02 + 0.1 * k), y: 8 + 2 * k)
        let c2 = CGPoint(x: w * lerp(0.84, 0.6, c) * (1 + 0.1 * k), y: lerp(14.5, 17.4, c) + 1.5 * k)
        let chinY = lerp(17.8, 22.5, c)
        let d1 = CGPoint(x: w * lerp(0.3, 0.08, c), y: lerp(17.2, 21.6, c)), d2 = CGPoint(x: w * lerp(0.12, 0.03, c), y: chinY)
        var h = Path()
        h.move(to: CGPoint(x: 0, y: -17.5))
        h.addCurve(to: CGPoint(x: w, y: 0), control1: CGPoint(x: w * 0.62, y: -17.5), control2: CGPoint(x: w, y: -9.5))
        h.addCurve(to: CGPoint(x: toX, y: toY), control1: c1, control2: c2)
        h.addCurve(to: CGPoint(x: 0, y: chinY), control1: d1, control2: d2)
        h.addCurve(to: CGPoint(x: -toX, y: toY), control1: CGPoint(x: -d2.x, y: d2.y), control2: CGPoint(x: -d1.x, y: d1.y))
        h.addCurve(to: CGPoint(x: -w, y: 0), control1: CGPoint(x: -c2.x, y: c2.y), control2: CGPoint(x: -c1.x, y: c1.y))
        h.addCurve(to: CGPoint(x: 0, y: -17.5), control1: CGPoint(x: -w, y: -9.5), control2: CGPoint(x: -w * 0.62, y: -17.5))
        h.closeSubpath()
        head = h
        let headOutline = h

        // Fur on the cheeks only (and a little under the chin line), from inside the head.
        headFur = FurEdge.furry(headOutline, seed: "head-\(plan.key)", gap: 4...7, height: (1.6 * fur)...(3.2 * fur), width: 3.4) { p in
            let side = abs(p.x) / w
            return (side > 0.62 && p.y > -4 && p.y < 15 + 4 * c) ? 1 : 0
        }

        var b = Path()
        for (x, a, len) in [(0.0, Double.pi / 2, 9.0), (-5.6, 1.95, 7.5), (5.6, 1.19, 7.5), (-10.5, 2.2, 5.5), (10.5, 0.94, 5.5)] {
            b.fur(x, -17.4, a, len * 0.9, 0.95, bend: 0.4)
        }
        brow = b
        var l = Path()
        for s in [-1.0, 1] {
            l.fur(s * 15.6, -1.4, s > 0 ? 0.1 : Double.pi - 0.1, 6.5, 0.6, bend: -0.5)
            l.fur(s * 15.0, 1.6, s > 0 ? 0.35 : Double.pi - 0.35, 5, 0.55, bend: -0.4)
        }
        liner = l
        var cs = Path()
        for s in [-1.0, 1] {
            cs.fur(s * (w - 0.6), 5.4, s > 0 ? Double.pi - 0.15 : 0.15, 5.0, 0.7)
            cs.fur(s * (w - 1.8), 9.6, s > 0 ? Double.pi - 0.45 : 0.45, 4.2, 0.65)
        }
        cheekStripes = cs

        let mz = plan.muzzle
        let drop = 3 * (mz - 1) + 6 * c
        self.drop = drop
        let pad = 1 - 0.3 * c
        var m = Path(ellipseIn: CGRect(x: -6.4 * pad, y: 2.2, width: 12.8 * pad, height: 10.5 * mz + drop))
        m.addEllipse(in: CGRect(x: -10.6 * pad, y: 4.6 + drop * 0.5, width: 11.2 * pad, height: 8.6 * mz))
        m.addEllipse(in: CGRect(x: -0.6 * pad, y: 4.6 + drop * 0.5, width: 11.2 * pad, height: 8.6 * mz))
        m.addEllipse(in: CGRect(x: -3.1, y: 11 + 5 * (mz - 1) + drop * 0.8, width: 6.2, height: 4.2))
        muzzle = m
        var dots = Path()
        for s in [-1.0, 1] {
            for (x, y) in [(5.2, 7.6), (7.8, 8.6), (5.0, 10.2), (7.6, 11.0)] {
                dots.addEllipse(in: CGRect(x: s * x * pad - 0.45, y: y + drop * 0.5 - 0.45, width: 0.9, height: 0.9))
            }
        }
        whiskerDots = dots
        let ns = plan.noseSize
        let nd = drop
        // Leather: a triangle with a soft top; bigger for a puppy's.
        nose = .loop([CGPoint(x: -3.6 * ns, y: 2.3 + nd), CGPoint(x: 0, y: 1.7 + nd), CGPoint(x: 3.6 * ns, y: 2.3 + nd),
                      CGPoint(x: 0, y: 2.3 + nd + 4.2 * (0.6 + 0.4 * ns))])
        var ml = Path()
        ml.move(to: CGPoint(x: 0, y: 5.8 + nd + 1.2 * (ns - 1))); ml.addLine(to: CGPoint(x: 0, y: 8 + nd + 1.2 * (ns - 1)))
        mouthLine = ml

        let eh = 24 * plan.earHeight
        earHeight = eh
        var bends: [Path] = [], innerBends: [Path] = []
        if plan.ears == .long {
            for i in 0..<5 {
                let (outer, inner) = Self.bunnyEar(eh, bend: Double(i) / 4)
                bends.append(outer); innerBends.append(inner)
            }
        }
        earBends = bends; earInnerBends = innerBends
        var tipPath = Path()
        var earFurPath = Path()
        switch plan.ears {
        case .round:
            ear = .loop([CGPoint(x: -9.4, y: 3), CGPoint(x: -10, y: -eh * 0.4), CGPoint(x: -6, y: -eh * 0.95), CGPoint(x: 0, y: -eh * 1.12),
                         CGPoint(x: 6, y: -eh * 0.95), CGPoint(x: 10, y: -eh * 0.4), CGPoint(x: 9.4, y: 3)])
            earInner = .loop([CGPoint(x: -5.4, y: 1.5), CGPoint(x: -6, y: -eh * 0.4), CGPoint(x: -3, y: -eh * 0.72), CGPoint(x: 0, y: -eh * 0.8),
                              CGPoint(x: 3, y: -eh * 0.72), CGPoint(x: 6, y: -eh * 0.4), CGPoint(x: 5.4, y: 1.5)])
        case .long:
            ear = bends[0]; earInner = innerBends[0]
        case .drop:
            // Hangs from the crown: the same origin, the ear falling outward
            // and down, broad at the tip like a pup's, with a fur edge.
            let outline = Path.loop([CGPoint(x: -5, y: -3), CGPoint(x: 4, y: -5), CGPoint(x: 11.5, y: -1), CGPoint(x: 15.5, y: 8), CGPoint(x: 15, y: 18),
                                     CGPoint(x: 10, y: 25), CGPoint(x: 4.5, y: 24), CGPoint(x: 0.5, y: 14), CGPoint(x: -3, y: 4)])
            ear = outline
            earInner = Path()
            earFurPath = FurEdge.furry(outline, seed: "ear-\(plan.key)", gap: 5...8, height: (0.9 * fur)...(1.8 * fur), width: 3.2) { p in p.y > 6 ? 1 : 0.3 }
        case .leaf:
            // A fawn's: broad, pointed, held out to the side, pale hairs inside.
            ear = .loop([CGPoint(x: -8.5, y: 3), CGPoint(x: -11.6, y: -eh * 0.36), CGPoint(x: -8, y: -eh * 0.8), CGPoint(x: 0.6, y: -eh * 1.06),
                         CGPoint(x: 8.6, y: -eh * 0.68), CGPoint(x: 11, y: -eh * 0.3), CGPoint(x: 8.6, y: 3)])
            earInner = .loop([CGPoint(x: -5, y: 1.5), CGPoint(x: -7.4, y: -eh * 0.34), CGPoint(x: -4.2, y: -eh * 0.68), CGPoint(x: 0.5, y: -eh * 0.86),
                              CGPoint(x: 5, y: -eh * 0.62), CGPoint(x: 7, y: -eh * 0.28), CGPoint(x: 5, y: 1.5)])
        default:
            ear = .loop([CGPoint(x: -8.8, y: 3), CGPoint(x: -6.2, y: -eh * 0.5), CGPoint(x: 0.5, y: -eh), CGPoint(x: 6.8, y: -eh * 0.45), CGPoint(x: 9.2, y: 3)])
            earInner = .loop([CGPoint(x: -5, y: 1.5), CGPoint(x: -3.3, y: -eh * 0.42), CGPoint(x: 0.4, y: -eh * 0.74), CGPoint(x: 4, y: -eh * 0.4), CGPoint(x: 5.2, y: 1.5)])
            if plan.earColour != nil {
                tipPath = ear.intersection(Path(CGRect(x: -20, y: -eh * 1.2, width: 40, height: eh * 0.7)))
            }
        }
        earTip = tipPath
        earFur = earFurPath
        var eHairs = Path()
        for (x, a, len) in [(-2.4, -1.75, 9.0), (0.2, -1.6, 11.0), (2.6, -1.42, 8.5)] {
            eHairs.fur(x, 1, a, len * plan.earHeight * (plan.ears == .round ? 0.6 : 1), 0.8)
        }
        earHairs = eHairs

        // A hamster's cheeks: two round pouches of cream, soft at the edge.
        var pp = Path()
        if k > 0 {
            for s in [-1.0, 1] { pp.addEllipse(in: CGRect(x: s * w * 0.56 - 9.5, y: 7.5 - 8, width: 19, height: 16)) }
        }
        pouches = pp
        // A fox's cheeks and chin are white: the lower face, cut from the
        // furred outline so the ruff is white too, from the eyes' level down.
        var white = Path(), tear = Path()
        if plan.marks == .mask {
            var region = Path()
            for s in [-1.0, 1] {
                region.addEllipse(in: CGRect(x: s * w * 0.62 - w * 0.64, y: 1.5, width: w * 1.28, height: 24))
            }
            region.addEllipse(in: CGRect(x: -w * 0.32, y: -2, width: w * 0.64, height: 28))
            white = headFur.intersection(region)
            for s in [-1.0, 1] { tear.fur(s * 5.2, 0.6, s > 0 ? 1.2 : Double.pi - 1.2, 10.5 + drop * 0.4, 0.9, bend: s * -0.6) }
        }
        cheekWhite = white
        tears = tear
        var bl = Path()
        if plan.species == .puppy { bl.fur(0, -17.2, .pi / 2, 21 + drop * 0.4, 2.4) }
        blaze = bl
    }

    /// A bunny's ear: a leaf that stands up, bent more and more along its
    /// length as `bend` goes from 0 (straight) to 1 (laid back, tip
    /// outwards), with the inner ear along the same line.
    static func bunnyEar(_ eh: Double, bend: Double) -> (Path, Path) {
        let n = 10
        func side(_ half: (Double) -> Double, _ from: Double, _ to: Double) -> ([CGPoint], [CGPoint]) {
            var left: [CGPoint] = [], right: [CGPoint] = []
            var x = 0.0, y = 3.0, angle = 0.0
            let step = eh * 1.04 / Double(n)
            for i in 0...n {
                let t = Double(i) / Double(n)
                if i > 0 {
                    angle = bend * 2.1 * pow(t, 1.25)
                    x += sin(angle) * step; y -= cos(angle) * step
                }
                guard t >= from, t <= to else { continue }
                let hw = half(t)
                left.append(CGPoint(x: x - cos(angle) * hw, y: y - sin(angle) * hw))
                right.append(CGPoint(x: x + cos(angle) * hw, y: y + sin(angle) * hw))
            }
            return (left, right)
        }
        func outerHalf(_ t: Double) -> Double { 6.2 * (0.7 + 0.3 * sin(min(1, t * 1.05) * .pi * 0.95)) * pow(max(0, 1 - pow(t, 5)), 0.5) + 0.2 }
        func innerHalf(_ t: Double) -> Double { 3.1 * (0.7 + 0.3 * sin(min(1, t * 1.05) * .pi * 0.95)) * pow(max(0, 1 - pow(t / 0.86, 5)), 0.5) + 0.1 }
        let (ol, or) = side(outerHalf, 0, 1)
        let (il, ir) = side(innerHalf, 0.04, 0.86)
        return (Path.loop(ol + or.reversed()), Path.loop(il + ir.reversed()))
    }
}

/// What has been built from a plan, kept: the drawing asks for the same
/// shapes thirty times a second and they do not change.
enum CritterGeometry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var sits: [String: SitGeometry] = [:]
    nonisolated(unsafe) private static var curls: [String: CurlGeometry] = [:]
    nonisolated(unsafe) private static var heads: [String: HeadGeometry] = [:]

    /// Builds what a pet will be drawn from, off the main thread, so the
    /// first frame fills paths and builds none (the goldfish's bowl and the
    /// fox's furred outlines were 13-45 ms on the first frame).
    static func prepare(_ plan: CritterPlan) {
        switch plan.body {
        case .sitter:
            _ = sit(plan); _ = curl(plan); _ = head(plan)
            if plan.species == .hedgehog { _ = hedgehog(plan) }
        case .perched: _ = bird(plan)
        case .waddler:
            if plan.species == .penguin { _ = penguin(plan) } else { _ = duck(plan) }
        case .shelled: _ = turtle(plan)
        case .swimmer: _ = bowlArt.water(0); _ = fishArt
        }
    }

    static func sit(_ plan: CritterPlan) -> SitGeometry {
        lock.lock(); defer { lock.unlock() }
        if let kept = sits[plan.key] { return kept }
        let made = SitGeometry(plan)
        sits[plan.key] = made
        return made
    }

    static func curl(_ plan: CritterPlan) -> CurlGeometry {
        lock.lock(); defer { lock.unlock() }
        if let kept = curls[plan.key] { return kept }
        let made = CurlGeometry(plan)
        curls[plan.key] = made
        return made
    }

    static func head(_ plan: CritterPlan) -> HeadGeometry {
        lock.lock(); defer { lock.unlock() }
        if let kept = heads[plan.key] { return kept }
        let made = HeadGeometry(plan)
        heads[plan.key] = made
        return made
    }
}
