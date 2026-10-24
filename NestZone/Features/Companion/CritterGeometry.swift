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
    /// Where the form's centre is, for the gradients.
    let bodyCentre = CGPoint(x: 68, y: 84)

    init(_ plan: CritterPlan) {
        let bw = plan.bodyWidth, fur = plan.fur
        func wide(_ x: Double) -> Double { 66 + (x - 66) * bw }
        let bodyPath = Path.loop([(40, 66), (58, 57), (82, 62), (96, 84), (93, 103), (68, 109), (44, 109), (34, 90)].map { CGPoint(x: wide($0.0), y: $0.1) })
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
        chest = .loop([CGPoint(x: 45, y: 71), CGPoint(x: 57, y: 77), CGPoint(x: 58.5, y: 95), CGPoint(x: 53, y: 107), CGPoint(x: 45, y: 107),
                       CGPoint(x: 43, y: 94), CGPoint(x: 42, y: 79)])

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

        nearLeg = .loop([CGPoint(x: 37, y: 79), CGPoint(x: 49.5, y: 79), CGPoint(x: 48, y: 94), CGPoint(x: 50.2, y: 104), CGPoint(x: 36.5, y: 104), CGPoint(x: 39.5, y: 93)])
        nearPaw = Path(ellipseIn: CGRect(x: 35.2, y: 101.6, width: 17, height: 8.6))
        var nt = Path()
        for x in [39.4, 43.6, 47.8] { nt.move(to: CGPoint(x: x, y: 106.2)); nt.addLine(to: CGPoint(x: x, y: 109)) }
        nearToes = nt
        var nb = Path()
        nb.fur(38.5, 86, 0.2, 9, 1.4, bend: 1)
        nb.fur(39.5, 92, 0.15, 8, 1.3, bend: 1)
        nearBars = nb

        farLeg = .loop([CGPoint(x: 51, y: 82), CGPoint(x: 62, y: 82), CGPoint(x: 61, y: 95), CGPoint(x: 63, y: 105), CGPoint(x: 50, y: 105), CGPoint(x: 52, y: 94)])
        farPaw = Path(ellipseIn: CGRect(x: 50, y: 102.4, width: 14, height: 7.4))

    }
}

/// The curled-up pose, in the same box: a round of fur lying on the floor.
struct CurlGeometry {
    let body, stripes, hairs, haunch, haunchBars: Path
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
    let earHeight: Double
    let w: Double

    init(_ plan: CritterPlan) {
        let w = 21 * plan.headWidth
        self.w = w
        let fur = plan.fur
        var h = Path()
        h.move(to: CGPoint(x: 0, y: -17.5))
        h.addCurve(to: CGPoint(x: w, y: 0), control1: CGPoint(x: w * 0.62, y: -17.5), control2: CGPoint(x: w, y: -9.5))
        h.addCurve(to: CGPoint(x: w * 0.42, y: 16), control1: CGPoint(x: w * 1.02, y: 8), control2: CGPoint(x: w * 0.84, y: 14.5))
        h.addCurve(to: CGPoint(x: 0, y: 17.8), control1: CGPoint(x: w * 0.3, y: 17.2), control2: CGPoint(x: w * 0.12, y: 17.8))
        h.addCurve(to: CGPoint(x: -w * 0.42, y: 16), control1: CGPoint(x: -w * 0.12, y: 17.8), control2: CGPoint(x: -w * 0.3, y: 17.2))
        h.addCurve(to: CGPoint(x: -w, y: 0), control1: CGPoint(x: -w * 0.84, y: 14.5), control2: CGPoint(x: -w * 1.02, y: 8))
        h.addCurve(to: CGPoint(x: 0, y: -17.5), control1: CGPoint(x: -w, y: -9.5), control2: CGPoint(x: -w * 0.62, y: -17.5))
        h.closeSubpath()
        head = h
        let headOutline = h

        // Fur on the cheeks only (and a little under the chin line), from inside the head.
        headFur = FurEdge.furry(headOutline, seed: "head-\(plan.key)", gap: 4...7, height: (1.6 * fur)...(3.2 * fur), width: 3.4) { p in
            let side = abs(p.x) / w
            return (side > 0.62 && p.y > -4 && p.y < 15) ? 1 : 0
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
        var m = Path(ellipseIn: CGRect(x: -6.4, y: 2.2, width: 12.8, height: 10.5 * mz))
        m.addEllipse(in: CGRect(x: -10.6, y: 4.6, width: 11.2, height: 8.6 * mz))
        m.addEllipse(in: CGRect(x: -0.6, y: 4.6, width: 11.2, height: 8.6 * mz))
        m.addEllipse(in: CGRect(x: -3.1, y: 11 + 5 * (mz - 1), width: 6.2, height: 4.2))
        muzzle = m
        var dots = Path()
        for s in [-1.0, 1] {
            for (x, y) in [(5.2, 7.6), (7.8, 8.6), (5.0, 10.2), (7.6, 11.0)] {
                dots.addEllipse(in: CGRect(x: s * x - 0.45, y: y - 0.45, width: 0.9, height: 0.9))
            }
        }
        whiskerDots = dots
        let nd = 3.0 * (mz - 1)
        nose = .loop([CGPoint(x: -3.6, y: 2.3 + nd), CGPoint(x: 0, y: 1.7 + nd), CGPoint(x: 3.6, y: 2.3 + nd), CGPoint(x: 0, y: 6.5 + nd)])
        var ml = Path()
        ml.move(to: CGPoint(x: 0, y: 5.8)); ml.addLine(to: CGPoint(x: 0, y: 8))
        mouthLine = ml

        let eh = 24 * plan.earHeight
        earHeight = eh
        switch plan.ears {
        case .round:
            ear = .loop([CGPoint(x: -9.4, y: 3), CGPoint(x: -10, y: -eh * 0.4), CGPoint(x: -6, y: -eh * 0.95), CGPoint(x: 0, y: -eh * 1.12),
                         CGPoint(x: 6, y: -eh * 0.95), CGPoint(x: 10, y: -eh * 0.4), CGPoint(x: 9.4, y: 3)])
            earInner = .loop([CGPoint(x: -5.4, y: 1.5), CGPoint(x: -6, y: -eh * 0.4), CGPoint(x: -3, y: -eh * 0.72), CGPoint(x: 0, y: -eh * 0.8),
                              CGPoint(x: 3, y: -eh * 0.72), CGPoint(x: 6, y: -eh * 0.4), CGPoint(x: 5.4, y: 1.5)])
        case .long:
            ear = .loop([CGPoint(x: -6.4, y: 3), CGPoint(x: -5.6, y: -eh * 0.5), CGPoint(x: 0.4, y: -eh * 1.04), CGPoint(x: 5.6, y: -eh * 0.5), CGPoint(x: 6.6, y: 3)])
            earInner = .loop([CGPoint(x: -3.2, y: 1.5), CGPoint(x: -2.8, y: -eh * 0.46), CGPoint(x: 0.3, y: -eh * 0.84), CGPoint(x: 3, y: -eh * 0.46), CGPoint(x: 3.4, y: 1.5)])
        case .drop:
            // Hangs from the crown: the same origin, the ear falling outward and down.
            ear = .loop([CGPoint(x: -5, y: -2), CGPoint(x: 5, y: -3), CGPoint(x: 13, y: 6), CGPoint(x: 13, y: 17), CGPoint(x: 6, y: 21), CGPoint(x: -1, y: 11)])
            earInner = Path()
        default:
            ear = .loop([CGPoint(x: -8.8, y: 3), CGPoint(x: -6.2, y: -eh * 0.5), CGPoint(x: 0.5, y: -eh), CGPoint(x: 6.8, y: -eh * 0.45), CGPoint(x: 9.2, y: 3)])
            earInner = .loop([CGPoint(x: -5, y: 1.5), CGPoint(x: -3.3, y: -eh * 0.42), CGPoint(x: 0.4, y: -eh * 0.74), CGPoint(x: 4, y: -eh * 0.4), CGPoint(x: 5.2, y: 1.5)])
        }
        var eHairs = Path()
        for (x, a, len) in [(-2.4, -1.75, 9.0), (0.2, -1.6, 11.0), (2.6, -1.42, 8.5)] {
            eHairs.fur(x, 1, a, len * plan.earHeight * (plan.ears == .round ? 0.6 : 1), 0.8)
        }
        earHairs = eHairs
    }
}

/// What has been built from a plan, kept: the drawing asks for the same
/// shapes thirty times a second and they do not change.
enum CritterGeometry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var sits: [String: SitGeometry] = [:]
    nonisolated(unsafe) private static var curls: [String: CurlGeometry] = [:]
    nonisolated(unsafe) private static var heads: [String: HeadGeometry] = [:]

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
