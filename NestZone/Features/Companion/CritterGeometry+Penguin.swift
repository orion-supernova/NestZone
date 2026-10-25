import SwiftUI

/// The penguin, built once: an upright egg of a body with a white front, a
/// round head with a white face and a gold patch at the neck, a pointed bill
/// in two halves, a flipper, a stub of a tail, webbed feet. The duckling's
/// box (120 units, feet at (60, 108)), looking left, and the same head
/// position (46, 47) so a hat, the hatchling and the face crop all agree.
struct PenguinGeometry {
    /// The body and the head with their edges furred from inside, shadow on the left [0] or the right [1].
    let body, headFur: [Path]
    let belly, bellyFur: Path
    let flipper, flipperEdge: Path
    let tail: Path
    let upperBill, lowerBill: Path
    let feet: [Path]
    let toes: Path
    static let bodyCentre = CGPoint(x: 60, y: 80)
    static let headCentre = CGPoint(x: 46, y: 47)

    init(_ plan: CritterPlan) {
        let fur = plan.fur
        let bodyPath = Path.loop([CGPoint(x: 34, y: 96), CGPoint(x: 31.5, y: 76), CGPoint(x: 40, y: 56), CGPoint(x: 58, y: 47), CGPoint(x: 77, y: 56),
                                  CGPoint(x: 87, y: 78), CGPoint(x: 84, y: 100), CGPoint(x: 68, y: 110.4), CGPoint(x: 48, y: 110.4)])
        func furred(_ path: Path, _ tag: String, _ shadowRight: Double, gap: ClosedRange<Double>, height: ClosedRange<Double>) -> Path {
            FurEdge.furry(path, seed: "peng-\(tag)-\(shadowRight)", gap: gap, height: height, width: 3.2) { p in
                0.25 + 0.75 * Ink.smooth(((p.x - 60) * shadowRight) / 26)
            }
        }
        body = [furred(bodyPath, "body", -1, gap: 7...12, height: (0.8 * fur)...(1.8 * fur)), furred(bodyPath, "body", 1, gap: 7...12, height: (0.8 * fur)...(1.8 * fur))]
        let bellyPath = Path.loop([CGPoint(x: 37.5, y: 96), CGPoint(x: 38, y: 76), CGPoint(x: 44.5, y: 60), CGPoint(x: 56, y: 53), CGPoint(x: 65, y: 63),
                                   CGPoint(x: 65, y: 84), CGPoint(x: 66.5, y: 102), CGPoint(x: 56, y: 109.6), CGPoint(x: 45, y: 107)])
        belly = bellyPath
        bellyFur = FurEdge.furry(bellyPath, seed: "peng-belly", gap: 6...10, height: (0.6 * fur)...(1.3 * fur), width: 3)

        let head = Path(ellipseIn: CGRect(x: 28, y: 29, width: 36, height: 36))
        headFur = [furred(head, "head", -1, gap: 5...9, height: (0.7 * fur)...(1.5 * fur)), furred(head, "head", 1, gap: 5...9, height: (0.7 * fur)...(1.5 * fur))]

        // The flipper hangs from the shoulder (its origin), a blunt leaf.
        var fl = Path()
        fl.leaf(0, 0, 0.3, 0.95, 38, 8.4, 0.45)
        flipper = fl
        // The pale edge along its leading side, a thin crescent.
        var fe = Path()
        fe.move(to: CGPoint(x: -5.4, y: 6)); fe.addQuadCurve(to: CGPoint(x: 6.4, y: 35), control: CGPoint(x: -4.4, y: 23))
        flipperEdge = fe

        tail = .loop([CGPoint(x: 80, y: 99), CGPoint(x: 91, y: 103.5), CGPoint(x: 98, y: 108.6), CGPoint(x: 86, y: 109.2), CGPoint(x: 77, y: 108)])

        var up = Path()
        up.move(to: CGPoint(x: 34.5, y: 49.4))
        up.addCurve(to: CGPoint(x: 12.4, y: 55.6), control1: CGPoint(x: 27, y: 48.6), control2: CGPoint(x: 17.5, y: 51.6))
        up.addCurve(to: CGPoint(x: 34.5, y: 55.4), control1: CGPoint(x: 17.5, y: 57.2), control2: CGPoint(x: 27, y: 56.4))
        up.closeSubpath()
        upperBill = up
        var lo = Path()
        lo.move(to: CGPoint(x: 34, y: 55.2))
        lo.addCurve(to: CGPoint(x: 17.4, y: 57), control1: CGPoint(x: 27, y: 55.4), control2: CGPoint(x: 20.4, y: 56))
        lo.addCurve(to: CGPoint(x: 33.4, y: 59.8), control1: CGPoint(x: 20, y: 59.4), control2: CGPoint(x: 27, y: 60.4))
        lo.closeSubpath()
        lowerBill = lo

        // Webbed feet, toes forward (to the left), under the body.
        func foot(_ x: Double) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: x + 5.5, y: 104.6))
            p.addLine(to: CGPoint(x: x - 9, y: 106.4))
            p.addQuadCurve(to: CGPoint(x: x - 8.4, y: 109), control: CGPoint(x: x - 6.6, y: 107))
            p.addQuadCurve(to: CGPoint(x: x - 5.2, y: 110.4), control: CGPoint(x: x - 4.8, y: 109))
            p.addQuadCurve(to: CGPoint(x: x + 5.5, y: 109), control: CGPoint(x: x - 1, y: 109.6))
            p.closeSubpath()
            return p
        }
        feet = [foot(49), foot(69)]
        var tp = Path()
        for x in [49.0, 69] {
            for (tx, ty) in [(-8.8, 106.8), (-7.8, 109), (-5.0, 110)] {
                tp.move(to: CGPoint(x: x + 3, y: 106.6)); tp.addLine(to: CGPoint(x: x + tx, y: ty))
            }
        }
        toes = tp
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var penguins: [String: PenguinGeometry] = [:]
    private static let penguinLock = NSLock()

    static func penguin(_ plan: CritterPlan) -> PenguinGeometry {
        penguinLock.lock(); defer { penguinLock.unlock() }
        if let kept = penguins[plan.key] { return kept }
        let made = PenguinGeometry(plan)
        penguins[plan.key] = made
        return made
    }
}
