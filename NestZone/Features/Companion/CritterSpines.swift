import SwiftUI

extension Path {
    /// One spine, a dab of the hedgehog's coat: a narrow pointed blade from
    /// (x, y) heading `a` radians for `len`, `hw` wide at the base, bowed a
    /// little (`bend`) so a row of them is combed rather than printed. Its
    /// light tip, the last 42% of it, goes into `tip`.
    mutating func spine(_ x: Double, _ y: Double, _ a: Double, _ len: Double, _ hw: Double, bend: Double = 0.8, tip: inout Path) {
        let ca = cos(a), sa = sin(a)
        let nx = -sa, ny = ca
        let end = CGPoint(x: x + ca * len + nx * bend, y: y + sa * len + ny * bend)
        let mid = CGPoint(x: x + ca * len * 0.5 + nx * bend * 0.3, y: y + sa * len * 0.5 + ny * bend * 0.3)
        move(to: CGPoint(x: x + nx * hw, y: y + ny * hw))
        addQuadCurve(to: end, control: CGPoint(x: mid.x + nx * hw * 0.8, y: mid.y + ny * hw * 0.8))
        addQuadCurve(to: CGPoint(x: x - nx * hw, y: y - ny * hw), control: CGPoint(x: mid.x - nx * hw * 0.8, y: mid.y - ny * hw * 0.8))
        closeSubpath()
        // The tip: the same blade from 58% of the way out, narrower.
        let t = 0.58
        let bx = x + ca * len * t + nx * bend * t * t, by = y + sa * len * t + ny * bend * t * t
        let w = hw * 0.5
        tip.move(to: CGPoint(x: bx + nx * w, y: by + ny * w))
        tip.addLine(to: end)
        tip.addLine(to: CGPoint(x: bx - nx * w, y: by - ny * w))
        tip.closeSubpath()
    }
}

/// The hedgehog's coat, the one fur kind that is not hair: spines laid as
/// dabs in rows, the outermost row first so each row after it overlaps the
/// roots of the one before, every spine with a pale tip. Built once per plan
/// and drawn as two fills a row (the blades, then their tips), the same
/// economy as the cat's hairs. The outline of the animal is the spines' own
/// points, so it needs no separate fuzz.
struct SpineField {
    struct Row {
        let blades, tips: Path
    }
    /// From the outermost row to the innermost.
    let rows: [Row]

    /// A dome's worth of spines: rows at `radii` (fractions of the dome),
    /// round `centre` over the arc `from`...`to` (radians, y down: the top is
    /// 1.5 pi), swept back toward +x by `sweep` (0 radial, 1 combed back).
    init(seed: String, centre: CGPoint, rx: Double, ry: Double, arc: ClosedRange<Double>, radii: [Double], counts: [Int], lengths: [Double],
         sweep: Double, width: Double = 1.7, skip: (CGPoint, Double) -> Bool = { _, _ in false }) {
        var r = Ink.Random(seed)
        var made: [Row] = []
        for (i, rad) in radii.enumerated() {
            var blades = Path(), tips = Path()
            let n = counts[i]
            for j in 0..<n {
                let t = (Double(j) + 0.5 + r.between(-0.3, 0.3)) / Double(n)
                let th = arc.lowerBound + (arc.upperBound - arc.lowerBound) * t
                let x = centre.x + cos(th) * rx * rad, y = centre.y + sin(th) * ry * rad
                guard !skip(CGPoint(x: x, y: y), rad) else { continue }
                // Outward, combed toward the rump.
                let ox = cos(th), oy = sin(th)
                let bx = ox * (1 - sweep) + sweep * 0.9, by = oy * (1 - sweep) - sweep * 0.3
                let a = atan2(by, bx) + r.between(-0.14, 0.14)
                blades.spine(x, y, a, lengths[i] * r.between(0.88, 1.12), width * r.between(0.9, 1.15), tip: &tips)
            }
            made.append(Row(blades: blades, tips: tips))
        }
        rows = made
    }
}

/// What the hedgehog is built from, kept per plan: the sitting coat, the hood
/// of spines over the head, and the ball it rolls into.
struct HedgehogGeometry {
    let coat: SpineField
    let hood: SpineField
    let ball: SpineField
    let dome: Path
    let belly: Path
    /// The dark under the hood, in head space.
    let hoodBase: Path

    init(_ plan: CritterPlan) {
        let bw = plan.bodyWidth
        let c = CGPoint(x: 68, y: 80)
        dome = Path(ellipseIn: CGRect(x: c.x - 31 * bw, y: c.y - 27, width: 62 * bw, height: 54))
        belly = Path(ellipseIn: CGRect(x: 40, y: 96, width: 24, height: 13))
        let hw = 21 * plan.headWidth * 0.92
        var base = Path()
        base.move(to: CGPoint(x: -hw, y: -3))
        base.addQuadCurve(to: CGPoint(x: hw, y: -3), control: CGPoint(x: 0, y: -31))
        base.addQuadCurve(to: CGPoint(x: -hw, y: -3), control: CGPoint(x: 0, y: -8))
        hoodBase = base
        coat = SpineField(seed: "coat-\(plan.key)", centre: c, rx: 31 * bw, ry: 27, arc: (1.0 * .pi)...(2.16 * .pi),
                          radii: [0.92, 0.78, 0.64, 0.5, 0.36, 0.22], counts: [36, 31, 25, 19, 13, 8], lengths: [9.5, 9.2, 8.8, 8.4, 8, 7.6], sweep: 0.55, width: 1.05)
        // Over the head, on the crown only: two rows from ear to ear. The
        // origin is the head's centre.
        hood = SpineField(seed: "hood-\(plan.key)", centre: CGPoint(x: 0, y: -3), rx: 21 * plan.headWidth, ry: 17, arc: (1.08 * .pi)...(1.92 * .pi),
                          radii: [0.92, 0.72], counts: [19, 15], lengths: [7.8, 7], sweep: 0.2, width: 1.05)
        // The ball: rings from the rim in, round the whole circle. A gap is
        // left low on the left for the face.
        ball = SpineField(seed: "ball-\(plan.key)", centre: CGPoint(x: 60, y: 78), rx: 32, ry: 29, arc: 0...(2 * .pi),
                          radii: [0.92, 0.8, 0.68, 0.54, 0.4, 0.24], counts: [40, 33, 25, 17, 10, 4], lengths: [9.5, 9.2, 8.8, 8.4, 8, 7.5], sweep: 0.0, width: 1.1,
                          skip: { p, rad in rad > 0.5 && p.x < 44 && p.y > 82 })
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var hedgehogs: [String: HedgehogGeometry] = [:]
    private static let hedgehogLock = NSLock()

    static func hedgehog(_ plan: CritterPlan) -> HedgehogGeometry {
        hedgehogLock.lock(); defer { hedgehogLock.unlock() }
        if let kept = hedgehogs[plan.key] { return kept }
        let made = HedgehogGeometry(plan)
        hedgehogs[plan.key] = made
        return made
    }
}
