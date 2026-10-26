import SwiftUI

/// What a goldfish's growing up adds to `FishGeometry`: the fry (a slim,
/// glassy tadpole with its yolk sac and its spine showing), the gold that
/// breaks through a bronze juvenile (blotches in four cumulative levels,
/// cut to the body, and a few flecks that come first), and the jelly beads
/// of the egg. In the fish's own space (origin at the middle of the body,
/// looking left), built once for every fish; the colour is the plan's.
struct FishStages {
    /// The fry's body, its tail fold, its yolk sac, the beat of its spine
    /// and the fold along its back, in the fry's own space (the head at the
    /// left, 26 units long).
    let fryBody, fryTail, fryFold, frySac, frySpine: Path
    /// The gold coming through: blotches (four cumulative levels) and the
    /// first flecks, at the gill and along the belly.
    let turn: [Path]
    let flecks: Path

    init() {
        var r = Ink.Random("fish-stages")
        fryBody = Path.loop([CGPoint(x: -11.8, y: 0.8), CGPoint(x: -10.8, y: -4.6), CGPoint(x: -5, y: -6.4), CGPoint(x: 2, y: -4.4), CGPoint(x: 8.5, y: -1.4),
                             CGPoint(x: 8.6, y: 1.2), CGPoint(x: 2, y: 3.4), CGPoint(x: -5, y: 4.6), CGPoint(x: -10.2, y: 3.8)])
        fryTail = Path.leaf(from: CGPoint(x: 7, y: 0), to: CGPoint(x: 19, y: 0.4), width: 3.6)
        var fold = Path()
        fold.move(to: CGPoint(x: -4, y: -5.8))
        fold.addQuadCurve(to: CGPoint(x: 10, y: -2.6), control: CGPoint(x: 3, y: -9.4))
        fold.addLine(to: CGPoint(x: 8, y: -1))
        fold.closeSubpath()
        fryFold = fold
        frySac = Path(ellipseIn: CGRect(x: -8.4, y: 1.4, width: 12.5, height: 9))
        var sp = Path()
        sp.move(to: CGPoint(x: -5.6, y: -0.8)); sp.addQuadCurve(to: CGPoint(x: 8, y: 0.2), control: CGPoint(x: 1, y: -2.4))
        frySpine = sp

        // The turning: blotches over the back and the flank first, the head
        // and the belly last, each cut to the body so it ends at its edge.
        let bodyPath = Path.loop([CGPoint(x: -15.4, y: 0.6), CGPoint(x: -12.6, y: -8.2), CGPoint(x: -3.6, y: -12.6), CGPoint(x: 7.6, y: -9.6), CGPoint(x: 14.4, y: -3.2),
                                  CGPoint(x: 14.4, y: 3.4), CGPoint(x: 8, y: 9.4), CGPoint(x: -3.4, y: 12.8), CGPoint(x: -12.6, y: 8.4)])
        func blotch(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ tilt: Double) -> Path {
            var pts: [CGPoint] = []
            for i in 0..<9 {
                let a = Double(i) / 9 * .pi * 2
                let k = 1 + 0.28 * sin(a * 3 + x) + 0.12 * cos(a * 2 + y)
                pts.append(CGPoint(x: x + (cos(a) * rx * k) * cos(tilt) - (sin(a) * ry * k) * sin(tilt), y: y + (cos(a) * rx * k) * sin(tilt) + (sin(a) * ry * k) * cos(tilt)))
            }
            return bodyPath.intersection(Path.loop(pts))
        }
        let blots: [[Path]] = [
            [blotch(3, -7.4, 7.4, 4.2, 0.1), blotch(9.6, 1.2, 4.8, 3.6, 0.4)],
            [blotch(-4.6, 4.8, 5.6, 3.6, -0.2), blotch(-8.6, -5.6, 4.6, 3.2, -0.5)],
            [blotch(2.4, 1.6, 4.4, 3, 0), blotch(-10.6, 1.6, 3.4, 3.4, 0)],
            [blotch(8.2, 7.2, 4.6, 2.8, 0.5), blotch(-2.4, -1.4, 3.4, 2.4, 0.3), blotch(-12.4, -1.4, 2.6, 3, 0)]]
        var running = Path()
        var levels: [Path] = []
        for set in blots {
            for p in set { running.addPath(p) }
            levels.append(running)
        }
        turn = levels
        var fl = Path()
        for (x, y) in [(-9.0, 4.0), (-7.0, 7.6), (-3.0, 9.4), (2.0, 8.4), (-11.6, 0.6)] {
            fl.addEllipse(in: CGRect(x: x - 1.2, y: y - 0.9, width: r.between(1.8, 2.8), height: r.between(1.4, 2.0)))
        }
        flecks = fl
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var fishGrowth: FishStages?

    static var fishStages: FishStages {
        bowlLockForStages.lock(); defer { bowlLockForStages.unlock() }
        if let kept = fishGrowth { return kept }
        let made = FishStages()
        fishGrowth = made
        return made
    }

    private static let bowlLockForStages = NSLock()
}
