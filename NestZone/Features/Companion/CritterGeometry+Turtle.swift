import SwiftUI

/// The turtle, built once: a dome of a shell with its scutes in three rows
/// (a crest, the side plates, the marginals along the rim), the pale rim
/// under it, a head, four stumps of legs, a tail. The same box as every pet
/// (120 units, feet at (60, 108)), looking left. The neck is the one part
/// that is not built here: it stretches and tucks, so the painter lays it
/// out per frame.
struct TurtleGeometry {
    let dome, skirt: Path
    /// Every scute as one path, its inner outlines (growth rings) as another.
    let plates, rings: Path
    let head: Path
    let chin, spots: Path
    let leg: Path
    let claws: Path
    let tail: Path
    static let shellCentre = CGPoint(x: 73, y: 80)

    init(_ plan: CritterPlan) {
        dome = .loop([CGPoint(x: 38, y: 100), CGPoint(x: 37, y: 88), CGPoint(x: 43, y: 71), CGPoint(x: 57, y: 59), CGPoint(x: 74, y: 54), CGPoint(x: 92, y: 59),
                      CGPoint(x: 104, y: 72), CGPoint(x: 109.5, y: 88), CGPoint(x: 107, y: 99.5), CGPoint(x: 90, y: 102.6), CGPoint(x: 70, y: 103.6), CGPoint(x: 52, y: 102.6)])
        skirt = .loop([CGPoint(x: 40, y: 98), CGPoint(x: 58, y: 101), CGPoint(x: 76, y: 102), CGPoint(x: 94, y: 101), CGPoint(x: 108, y: 97), CGPoint(x: 106, y: 104),
                       CGPoint(x: 88, y: 108), CGPoint(x: 66, y: 109), CGPoint(x: 48, y: 107.4), CGPoint(x: 39, y: 104)])

        // Scutes: hexagons laid in three rows over the dome, each tilted to
        // follow the curve it sits on, a little smaller than the room it has
        // so the dome shows between as the seam.
        var hexes = Path(), inner = Path()
        func hex(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ tilt: Double) {
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
            hexes.addPath(outline(1))
            inner.addPath(outline(0.52))
        }
        // The crest.
        for (x, y, t) in [(54.0, 65.6, -0.5), (67, 61, -0.24), (80, 60, 0.12), (93, 65, 0.5)] { hex(x, y, 6.6, 5.3, t) }
        // The sides.
        for (x, y, t) in [(46.0, 79.0, -0.9), (59, 73, -0.5), (73, 70, 0), (87, 72, 0.5), (99, 79.5, 0.9)] { hex(x, y, 6.8, 6.2, t) }
        // The marginals along the rim.
        for (x, y, t) in [(42.6, 92.0, -1.2), (53, 87.6, -0.8), (65, 84.4, -0.3), (78, 83.6, 0.1), (91, 85.6, 0.55), (101, 90.5, 1.0), (106.2, 96.4, 1.3)] { hex(x, y, 5.6, 5.0, t) }
        plates = hexes
        rings = inner

        head = .loop([CGPoint(x: -15.4, y: 2.6), CGPoint(x: -11.6, y: -6), CGPoint(x: -2.4, y: -11), CGPoint(x: 8, y: -9.4), CGPoint(x: 13.4, y: -2),
                      CGPoint(x: 12.4, y: 6.4), CGPoint(x: 4.4, y: 10.6), CGPoint(x: -7, y: 9.4)])
        chin = Path(ellipseIn: CGRect(x: -13, y: 3.4, width: 17, height: 8))
        var sp = Path()
        for (x, y, r) in [(4.0, -8.0, 1.5), (9.0, -3.6, 1.3), (-0.4, -9.4, 1.2), (10.4, 2.4, 1.1)] { sp.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 1.8)) }
        spots = sp

        // A leg from its top (origin) down 14 units, blunt, with a flat foot.
        leg = .loop([CGPoint(x: -6.2, y: 0), CGPoint(x: 6.2, y: 0), CGPoint(x: 7.2, y: 8), CGPoint(x: 8.4, y: 13), CGPoint(x: 6, y: 14.6), CGPoint(x: -7.4, y: 14.6), CGPoint(x: -8, y: 12.6), CGPoint(x: -7, y: 8)])
        var cl = Path()
        for x in [-5.4, -1.2, 3.0] { cl.addEllipse(in: CGRect(x: x - 1.4, y: 12.2, width: 2.8, height: 2.4)) }
        claws = cl
        tail = .loop([CGPoint(x: 105, y: 92), CGPoint(x: 112, y: 97), CGPoint(x: 118, y: 103), CGPoint(x: 108, y: 102.4), CGPoint(x: 103, y: 99)])
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var turtles: [String: TurtleGeometry] = [:]
    private static let turtleLock = NSLock()

    static func turtle(_ plan: CritterPlan) -> TurtleGeometry {
        turtleLock.lock(); defer { turtleLock.unlock() }
        if let kept = turtles[plan.key] { return kept }
        let made = TurtleGeometry(plan)
        turtles[plan.key] = made
        return made
    }
}
