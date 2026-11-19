import SwiftUI

/// What a turtle's growing up adds to `TurtleGeometry`: the hatchling's and
/// the baby's big, bumpy scutes (fewer, larger, each a boss), the growth
/// rings a second ring of which a grown shell adds, the scratches and the
/// bloom of algae a weathered shell has, the scales on a leg, and the torn
/// leathery egg a hatchling is still in. Built once per plan.
struct TurtleStages {
    /// The big scutes of a baby's soft, flat shell, their one ring and a
    /// small boss at the middle of each.
    let bigPlates, bigRings, bigBumps: Path
    /// The grown shell's second ring, outside the first.
    let rings2: Path
    /// What a weathered shell has: scratches across the scutes, algae at the rim.
    let scratches, algae: Path
    /// Scales on a leg (in its own space) and the wrinkles of an old head.
    let legScales, headWrinkles: Path
    /// The egg a hatchling is in: the inside of its back half, the front
    /// lip with its torn edge, and that edge as a line.
    let cupBack, cupFront, cupRim: Path

    init(_ plan: CritterPlan) {
        var r = Ink.Random("turtle-stages-\(plan.key)")
        func hexes(_ layout: [(Double, Double, Double, Double, Double)], _ inner: Double) -> (Path, Path) {
            var all = Path(), ring = Path()
            for (cx, cy, rx, ry, tilt) in layout {
                func outline(_ k: Double) -> Path {
                    var p = Path()
                    for i in 0..<6 {
                        let a = Double(i) * .pi / 3 + .pi / 6
                        let x = cos(a) * rx * k, y = sin(a) * ry * k
                        let pt = CGPoint(x: cx + x * cos(tilt) - y * sin(tilt), y: cy + x * sin(tilt) + y * cos(tilt))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                    p.closeSubpath()
                    return p
                }
                all.addPath(outline(1))
                ring.addPath(outline(inner))
            }
            return (all, ring)
        }
        // A baby's scutes: three on the crest, four down the sides, five at the rim, each large.
        let big: [(Double, Double, Double, Double, Double)] = [
            (58, 67, 9.4, 7.4, -0.4), (74, 62, 9.2, 7.2, 0), (90, 67, 9.4, 7.4, 0.4),
            (47, 82, 9.6, 8.8, -0.85), (63, 78, 9.4, 8.8, -0.3), (82, 78, 9.4, 8.8, 0.3), (98, 82, 9.6, 8.8, 0.85),
            (43.5, 94, 7.4, 6.4, -1.2), (57, 91, 7.6, 6.6, -0.6), (73, 89.5, 7.8, 6.6, 0), (89, 91, 7.6, 6.6, 0.6), (102.5, 95, 7.2, 6.2, 1.15)]
        (bigPlates, bigRings) = hexes(big, 0.52)
        var bumps = Path()
        for (cx, cy, rx, ry, _) in big { bumps.addEllipse(in: CGRect(x: cx - rx * 0.36, y: cy - ry * 0.4, width: rx * 0.72, height: ry * 0.8)) }
        bigBumps = bumps
        let regular: [(Double, Double, Double, Double, Double)] =
            [(54, 65.6, 6.6, 5.3, -0.5), (67, 61, 6.6, 5.3, -0.24), (80, 60, 6.6, 5.3, 0.12), (93, 65, 6.6, 5.3, 0.5),
             (46, 79, 6.8, 6.2, -0.9), (59, 73, 6.8, 6.2, -0.5), (73, 70, 6.8, 6.2, 0), (87, 72, 6.8, 6.2, 0.5), (99, 79.5, 6.8, 6.2, 0.9),
             (42.6, 92, 5.6, 5.0, -1.2), (53, 87.6, 5.6, 5.0, -0.8), (65, 84.4, 5.6, 5.0, -0.3), (78, 83.6, 5.6, 5.0, 0.1), (91, 85.6, 5.6, 5.0, 0.55),
             (101, 90.5, 5.6, 5.0, 1.0), (106.2, 96.4, 5.6, 5.0, 1.3)]
        rings2 = hexes(regular, 0.76).1

        var sc = Path()
        for _ in 0..<34 {
            let x = r.between(46, 100), y = r.between(62, 96)
            let dx = (x - 73) / 34, dy = (y - 80) / 24
            guard dx * dx + dy * dy < 0.9 else { continue }
            let a = r.between(-0.9, 0.5)
            sc.move(to: CGPoint(x: x, y: y)); sc.addLine(to: CGPoint(x: x + cos(a) * r.between(3, 7), y: y + sin(a) * r.between(3, 7)))
        }
        scratches = sc
        var al = Path()
        for _ in 0..<22 {
            let t = r.between(0.1, 0.95)
            let x = 40 + t * 66, y = 96 + sin(t * .pi) * -8 + r.between(-2, 4) + (t > 0.9 ? -4 : 0)
            al.addEllipse(in: CGRect(x: x - 1, y: y - 0.8, width: r.between(1.4, 3), height: r.between(1, 1.8)))
        }
        algae = al

        var ls = Path()
        for (x, y) in [(-3.8, 3.5), (1.2, 3.5), (-2.4, 7.6), (2.6, 7.6), (-4.6, 10.6), (0.2, 10.6), (4.8, 10.6)] {
            ls.move(to: CGPoint(x: x - 1.8, y: y - 1)); ls.addQuadCurve(to: CGPoint(x: x + 1.8, y: y - 1), control: CGPoint(x: x, y: y + 1.6))
        }
        legScales = ls
        var hw = Path()
        for (x, y) in [(2.0, -6.6), (5.4, -4.4), (7.6, -1.0), (4.4, 6.4)] {
            hw.move(to: CGPoint(x: x - 2, y: y)); hw.addQuadCurve(to: CGPoint(x: x + 2, y: y + 0.4), control: CGPoint(x: x, y: y + 1.6))
        }
        headWrinkles = hw

        cupBack = Path.loop([CGPoint(x: 54, y: 90), CGPoint(x: 55, y: 78), CGPoint(x: 66, y: 69), CGPoint(x: 80, y: 67), CGPoint(x: 93, y: 71),
                             CGPoint(x: 101, y: 82), CGPoint(x: 101, y: 98), CGPoint(x: 86, y: 106), CGPoint(x: 66, y: 106), CGPoint(x: 55, y: 100)])
        var cf = Path()
        cf.move(to: CGPoint(x: 53, y: 92))
        for (x, y) in [(58.0, 87.0), (63, 92.5), (69, 85), (75, 91), (82, 84.5), (88, 91), (94, 86), (99, 92), (102, 90)] { cf.addLine(to: CGPoint(x: x, y: y)) }
        cf.addLine(to: CGPoint(x: 101, y: 100))
        cf.addQuadCurve(to: CGPoint(x: 55, y: 101), control: CGPoint(x: 78, y: 114))
        cf.closeSubpath()
        cupFront = cf
        var rim = Path()
        rim.move(to: CGPoint(x: 53, y: 93))
        for (x, y) in [(58.0, 88.0), (63, 93.5), (69, 86), (75, 92), (82, 85.5), (88, 92), (94, 87), (99, 93), (102, 91)] { rim.addLine(to: CGPoint(x: x, y: y)) }
        cupRim = rim
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var turtleGrowth: [String: TurtleStages] = [:]
    private static let turtleGrowthLock = NSLock()

    static func turtleStages(_ plan: CritterPlan) -> TurtleStages {
        turtleGrowthLock.lock(); defer { turtleGrowthLock.unlock() }
        if let kept = turtleGrowth[plan.key] { return kept }
        let made = TurtleStages(plan)
        turtleGrowth[plan.key] = made
        return made
    }
}
