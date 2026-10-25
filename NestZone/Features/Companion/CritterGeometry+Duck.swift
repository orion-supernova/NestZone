import SwiftUI

/// The duckling, built once: a round downy body, a head with a tuft, a wing,
/// a bill in two halves, webbed feet. The same box as every pet (120 units,
/// feet at (60, 108)), the duckling the households already know: yellow, an
/// orange bill, a pink cheek, looking left.
struct DuckGeometry {
    /// The body with down breaking its edge, shadow on the left [0] or the right [1].
    let body: [Path]
    let down, belly: Path
    let tail, tailLines: Path
    let wing, wingFeathers: Path
    let head: Path
    let headDown: Path
    let headHairs: Path
    let tuft: Path
    let upperBill, lowerBill: Path
    /// The face, where it is another colour than the crown: the cheek and the
    /// eye's surround, cut from the head.
    let face: Path
    let feet: [Path]
    let toes: Path
    static let bodyCentre = CGPoint(x: 62, y: 80)
    static let headCentre = CGPoint(x: 46, y: 50)

    init(_ plan: CritterPlan) {
        let fur = plan.fur
        let bodyPath = Path(ellipseIn: CGRect(x: 32, y: 56, width: 60, height: 48))
        func furred(_ shadowRight: Double) -> Path {
            FurEdge.furry(bodyPath, seed: "duck-body-\(shadowRight)", gap: 6...10, height: (0.9 * fur)...(1.9 * fur), width: 4.2) { p in
                // The belly and the underside are soft; the back, a little less.
                0.35 + 0.65 * Ink.smooth(((p.x - 62) * shadowRight) / 28 + (p.y - 80) / 60)
            }
        }
        body = [furred(-1), furred(1)]

        // Down: short soft strokes round the form, under 0.3 alpha.
        var r = Ink.Random("duck-down-\(plan.key)")
        var d = Path()
        for gy in stride(from: 59.0, through: 102, by: 4.6) {
            for gx in stride(from: 36.0, through: 90, by: 4.8) {
                let x = gx + r.between(-1.8, 1.8), y = gy + r.between(-1.8, 1.8)
                let dx = (x - 62) / 28, dy = (y - 80) / 22
                guard dx * dx + dy * dy < 0.9 else { continue }
                let a = atan2(y - 80, x - 62) + .pi / 2 + r.between(-0.3, 0.3)
                d.fur(x, y, a, r.between(3.4, 5.2), 0.65)
            }
        }
        down = d
        belly = Path(ellipseIn: CGRect(x: 34, y: 72, width: 38, height: 32))

        // A little upturned tail of three soft feathers.
        var t = Path(), tl = Path()
        for (a, len, w) in [(-0.62, 10.0, 2.3), (-0.2, 11.5, 2.5), (0.22, 9.5, 2.2)] {
            t.fur(87.5, 77.5, a, len, w, bend: 1.2)
            tl.move(to: CGPoint(x: 88.5, y: 77.4)); tl.addLine(to: CGPoint(x: 88.5 + cos(a) * len * 0.8, y: 77.4 + sin(a) * len * 0.8))
        }
        tail = t; tailLines = tl

        // The wing: a leaf folded on the flank, root forward, with three
        // rows of small feathers at its edge.
        wing = .loop([CGPoint(x: 57, y: 76), CGPoint(x: 66, y: 71), CGPoint(x: 78, y: 72.5), CGPoint(x: 86, y: 80), CGPoint(x: 83, y: 88),
                      CGPoint(x: 73, y: 90), CGPoint(x: 62, y: 85)])
        var wf = Path()
        for (x, y) in [(70.0, 83.0), (76, 85.5), (81, 83.0)] {
            wf.move(to: CGPoint(x: x - 3.6, y: y - 3)); wf.addQuadCurve(to: CGPoint(x: x + 3.4, y: y - 2.6), control: CGPoint(x: x, y: y + 1.6))
        }
        wingFeathers = wf

        let headCircle = Path(ellipseIn: CGRect(x: 27, y: 31, width: 38, height: 38))
        head = headCircle
        let downPath = FurEdge.furry(headCircle, seed: "duck-head", gap: 4.5...8, height: (1.1 * fur)...(2.3 * fur), width: 3.2) { p in
            // On the cheek and the back of the head, never over the face.
            Ink.smooth(((p.x - 46) / 19) * 0.9 + ((p.y - 50) / 19) * 0.45 + 0.1)
        }
        headDown = downPath
        face = plan.face == nil ? Path() : downPath.intersection(Path(ellipseIn: CGRect(x: 21, y: 40, width: 33, height: 31)))
        var hh = Path()
        for (x, y) in [(53.0, 45.0), (56, 52), (52, 60), (47, 63), (58, 42), (49, 36), (55, 36)] {
            hh.fur(x + r.between(-0.8, 0.8), y, atan2(y - 50, x - 46) + .pi / 2, r.between(3.4, 4.4), 0.6)
        }
        headHairs = hh
        // The crown's tuft: three wisps that lean forward.
        var tf = Path()
        for (x, a, len, w) in [(43.5, -1.95, 9.0, 1.15), (47.5, -1.45, 11.5, 1.3), (51.5, -1.0, 8.5, 1.1)] {
            tf.fur(x, 33, a, len, w, bend: 1.4)
        }
        tuft = tf

        // The bill, a top half and a lower one that drops when it opens.
        var up = Path()
        up.move(to: CGPoint(x: 38, y: 52.4))
        up.addCurve(to: CGPoint(x: 18.8, y: 56.6), control1: CGPoint(x: 31, y: 50.4), control2: CGPoint(x: 22.2, y: 52.2))
        up.addCurve(to: CGPoint(x: 38, y: 57.6), control1: CGPoint(x: 21.6, y: 59), control2: CGPoint(x: 30, y: 58.6))
        up.closeSubpath()
        upperBill = up
        var lo = Path()
        lo.move(to: CGPoint(x: 37.4, y: 57.4))
        lo.addCurve(to: CGPoint(x: 23.2, y: 58.6), control1: CGPoint(x: 31, y: 57), control2: CGPoint(x: 25.6, y: 57.4))
        lo.addCurve(to: CGPoint(x: 36.4, y: 61.6), control1: CGPoint(x: 24.4, y: 61.6), control2: CGPoint(x: 31, y: 62.4))
        lo.closeSubpath()
        lowerBill = lo

        // Webbed feet, toes forward (to the left).
        func foot(_ x: Double) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: x + 5, y: 103.2))
            p.addLine(to: CGPoint(x: x - 9, y: 105.6))
            p.addQuadCurve(to: CGPoint(x: x - 8, y: 108.2), control: CGPoint(x: x - 6.2, y: 106.2))
            p.addQuadCurve(to: CGPoint(x: x - 5.2, y: 109.6), control: CGPoint(x: x - 4.8, y: 108.2))
            p.addQuadCurve(to: CGPoint(x: x + 5, y: 108), control: CGPoint(x: x - 1, y: 108.6))
            p.closeSubpath()
            return p
        }
        feet = [foot(54), foot(76)]
        var tp = Path()
        for x in [54.0, 76] {
            for (tx, ty) in [(-8.6, 105.9), (-7.6, 108.2), (-5.0, 109.2)] {
                tp.move(to: CGPoint(x: x + 3, y: 105.6)); tp.addLine(to: CGPoint(x: x + tx, y: ty))
            }
        }
        toes = tp
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var ducks: [String: DuckGeometry] = [:]
    private static let duckLock = NSLock()

    static func duck(_ plan: CritterPlan) -> DuckGeometry {
        duckLock.lock(); defer { duckLock.unlock() }
        if let kept = ducks[plan.key] { return kept }
        let made = DuckGeometry(plan)
        ducks[plan.key] = made
        return made
    }
}
