import SwiftUI

/// What the duckling's growing up adds to `DuckGeometry`, built once per plan
/// and, like it, only filled by the painter: the wet hatchling's slicked down,
/// the pin feathers of the juvenile, the feather tips that come in over the
/// down, the neck that lengthens, the grown bird's sleek edge, its wing with
/// the colourway's mark on it. The stages are in `CritterPainter+DuckStages`.
struct DuckStages {
    /// The hatchling's body, wet: a squat blob with clumped, pointed down at
    /// its edge (shadow left [0] or right [1]), the slicked strokes laid
    /// along it, the long wisps that stand up on a drying head, and the
    /// crown's three first wisps.
    let hatchBody: [Path]
    let hatchHairs, hatchWisps: Path
    let hatchHead: Path
    /// The head and the body with almost no down at the edge, for the bird
    /// whose feathers have come in.
    let headSleek: Path
    let bodySleek: [Path]
    /// Feather tips over the body, in four cumulative levels.
    let scallops: [Path]
    /// A neck for each stage that shows one (5 and 6), with its barbs.
    let necks: [Int: DuckNeck]
    /// Pin feathers: tail, wing and back, in three cumulative levels each.
    let tailQuills, wingQuills, backQuills: [(shafts: Path, sheaths: Path)]
    /// The grown wing, its flight feathers and the colourway's speculum with
    /// its two pale borders, and the grown tail turned up.
    let adultWing, adultFeathers, speculum, speculumBorders: Path
    let adultTail, adultTailLines: Path
    /// The dark stripe through the eye of a duckling.
    let stripe: Path
    /// A bib of a blue Swedish duck, cut to the breast.
    let bib: Path

    static let hatchCentre = CGPoint(x: 60, y: 92)

    init(_ plan: CritterPlan) {
        let fur = plan.fur
        var r = Ink.Random("duck-stages-\(plan.key)")

        // The hatchling.
        let blob = Path.loop([CGPoint(x: 34, y: 101), CGPoint(x: 35, y: 90), CGPoint(x: 45, y: 80.5), CGPoint(x: 60, y: 77.5), CGPoint(x: 75, y: 81),
                              CGPoint(x: 85, y: 90), CGPoint(x: 86.5, y: 101), CGPoint(x: 72, y: 107.4), CGPoint(x: 48, y: 107.4)])
        func clumped(_ right: Double) -> Path {
            FurEdge.furry(blob, seed: "duck-wet-\(right)", gap: 4...7, height: (1.1 * fur)...(2.6 * fur), width: 2.6) { p in
                0.5 + 0.5 * Ink.smooth(((p.x - 60) * right) / 26)
            }
        }
        hatchBody = [clumped(-1), clumped(1)]
        var slick = Path()
        for gy in stride(from: 82.0, through: 104, by: 4.2) {
            for gx in stride(from: 38.0, through: 84, by: 5.4) {
                let x = gx + r.between(-1.6, 1.6), y = gy + r.between(-1.4, 1.4)
                let dx = (x - 60) / 25, dy = (y - 93) / 15
                guard dx * dx + dy * dy < 0.86 else { continue }
                slick.fur(x, y, 0.35 + dx * 0.5 + r.between(-0.25, 0.25), r.between(5.2, 7.6), 0.7, bend: 1.0)
            }
        }
        hatchHairs = slick
        var wisps = Path()
        for (x, y, a, len) in [(45.0, 33.0, -1.75, 7.0), (49.5, 31.5, -1.5, 8.5), (54.0, 33.0, -1.2, 6.5), (41.0, 36.0, -2.1, 5.5),
                               (66.0, 84.0, -0.6, 7.0), (72.0, 87.0, -0.35, 8.0), (60.0, 80.0, -0.9, 6.5)] {
            wisps.fur(x, y, a, len, 0.55, bend: 1.8)
        }
        hatchWisps = wisps
        let headCircle = Path(ellipseIn: CGRect(x: 27, y: 31, width: 38, height: 38))
        hatchHead = FurEdge.furry(headCircle, seed: "duck-wet-head", gap: 3.5...6, height: (0.9 * fur)...(2.2 * fur), width: 2.4) { p in
            Ink.smooth(((p.x - 46) / 19) * 0.8 + ((p.y - 50) / 19) * 0.4 + 0.2)
        }

        // The grown bird's edge.
        let body = Path(ellipseIn: CGRect(x: 32, y: 56, width: 60, height: 48))
        func sleek(_ right: Double) -> Path {
            FurEdge.furry(body, seed: "duck-sleek-\(right)", gap: 8...13, height: (0.15 * fur)...(0.5 * fur), width: 3.4) { p in
                0.4 + 0.6 * Ink.smooth(((p.x - 62) * right) / 28)
            }
        }
        bodySleek = [sleek(-1), sleek(1)]
        headSleek = FurEdge.furry(headCircle, seed: "duck-head-sleek", gap: 7...12, height: (0.15 * fur)...(0.45 * fur), width: 3) { p in
            Ink.smooth(((p.x - 46) / 19) * 0.9 + 0.1)
        }

        // Feather tips: the back and shoulder first, the belly last, patchy
        // between (a slow wave in the weight, so half-feathered is a
        // scattering and not a line).
        scallops = Plumage.scallops(seed: "duck-scallops-\(plan.key)", bounds: CGRect(x: 33, y: 57, width: 58, height: 46), pitch: CGSize(width: 5.0, height: 4.4),
                                    size: CGSize(width: 6.2, height: 5.6), tilt: -0.5) { p in
            let dx = (p.x - 62) / 29, dy = (p.y - 80) / 23
            guard dx * dx + dy * dy < 0.94 else { return nil }
            let back = 0.5 + 0.5 * Ink.clamp((dx * 0.55 - dy * 0.9) * 0.6 + 0.35, -1, 1)
            let patchy = 0.22 * sin(p.x * 0.42 + 1.1) * cos(p.y * 0.5)
            return Ink.clamp(back * 0.85 + patchy)
        }

        // The neck, a loop from the breast to under the head, for the stages
        // that show one. `lift` is how far the head is raised above its
        // place on the body, `thin` how slender.
        func neck(_ lift: Double, thin: Double, _ seed: String) -> DuckNeck {
            func x(_ v: Double) -> Double { 46 + (v - 46) * thin }
            let shape = Path.loop([CGPoint(x: x(38.5), y: 62 - lift), CGPoint(x: x(46), y: 58 - lift), CGPoint(x: x(55.5), y: 61 - lift),
                                   CGPoint(x: x(58.5), y: 72 - lift * 0.4), CGPoint(x: 64, y: 88), CGPoint(x: 46, y: 92),
                                   CGPoint(x: 33, y: 84), CGPoint(x: x(34.5), y: 72 - lift * 0.4)])
            var rr = Ink.Random(seed)
            var barbs = Path()
            for _ in 0..<26 {
                let px = rr.between(x(36), x(57)), py = rr.between(60 - lift, 84)
                barbs.fur(px, py, .pi / 2 + rr.between(-0.3, 0.3), rr.between(3.2, 4.8), 0.6)
            }
            return DuckNeck(shape: shape, barbs: barbs)
        }
        necks = [5: neck(12, thin: 1.0, "duck-neck-5"), 6: neck(11, thin: 0.95, "duck-neck-6")]

        // Pin feathers, three levels (what has come in by stage 4, 5 and the
        // last of them): the tail, the wing's edge and the back.
        func quills(_ sets: [[(CGPoint, Double, Double)]]) -> [(shafts: Path, sheaths: Path)] {
            var running: [(CGPoint, Double, Double)] = []
            return sets.map { running += $0; return Plumage.quills(running) }
        }
        tailQuills = quills([[(CGPoint(x: 87.5, y: 78), -0.45, 6.5)],
                             [(CGPoint(x: 88, y: 77), -0.1, 7.5), (CGPoint(x: 87, y: 79), 0.25, 6)],
                             [(CGPoint(x: 86.5, y: 76), -0.8, 6), (CGPoint(x: 88, y: 80), 0.5, 5)]])
        wingQuills = quills([[(CGPoint(x: 79, y: 80), 0.0, 5.5), (CGPoint(x: 82, y: 84), 0.25, 5.5)],
                             [(CGPoint(x: 76, y: 77.5), -0.25, 6), (CGPoint(x: 83, y: 88), 0.5, 5), (CGPoint(x: 72, y: 76), -0.4, 5)],
                             [(CGPoint(x: 69, y: 74), -0.5, 5), (CGPoint(x: 85, y: 81), 0.05, 5)]])
        backQuills = quills([[(CGPoint(x: 70, y: 60), -1.1, 4), (CGPoint(x: 80, y: 66), -0.8, 4)],
                             [(CGPoint(x: 62, y: 58), -1.3, 4), (CGPoint(x: 86, y: 72), -0.5, 4.2), (CGPoint(x: 75, y: 62), -1.0, 4)],
                             [(CGPoint(x: 54, y: 60), -1.45, 3.4), (CGPoint(x: 88, y: 66), -0.7, 3.6)]])

        // The grown wing: long, folded along the flank with its tip over the
        // tail, a row of flight feathers, the speculum cut to its rear.
        let wing = Path.loop([CGPoint(x: 55, y: 77), CGPoint(x: 66, y: 70), CGPoint(x: 82, y: 72), CGPoint(x: 98, y: 79), CGPoint(x: 108, y: 83.5),
                              CGPoint(x: 96, y: 88), CGPoint(x: 80, y: 91), CGPoint(x: 64, y: 87)])
        adultWing = wing
        var af = Path()
        for (x, y) in [(66.0, 82.0), (74, 84.5), (82, 85.2), (90, 85), (97, 84)] {
            af.move(to: CGPoint(x: x - 4, y: y - 3.4)); af.addQuadCurve(to: CGPoint(x: x + 4.4, y: y - 2.2), control: CGPoint(x: x + 0.5, y: y + 1.8))
        }
        adultFeathers = af
        let band = Path.loop([CGPoint(x: 72, y: 78), CGPoint(x: 90, y: 79), CGPoint(x: 92, y: 85), CGPoint(x: 74, y: 86.5)])
        speculum = wing.intersection(band)
        var sb = Path()
        sb.move(to: CGPoint(x: 71.5, y: 77.6)); sb.addLine(to: CGPoint(x: 73.5, y: 86.8))
        sb.move(to: CGPoint(x: 91, y: 79)); sb.addLine(to: CGPoint(x: 92.4, y: 85.2))
        speculumBorders = sb
        var at = Path(), atl = Path()
        for (a, len, w) in [(-1.0, 13.0, 2.6), (-0.62, 15.0, 2.8), (-0.26, 14.0, 2.6), (0.1, 11.0, 2.3)] {
            at.fur(90, 76.5, a, len, w, bend: 1.8)
            atl.move(to: CGPoint(x: 91, y: 76.6)); atl.addLine(to: CGPoint(x: 91 + cos(a) * len * 0.8, y: 76.6 + sin(a) * len * 0.8))
        }
        adultTail = at; adultTailLines = atl

        var st = Path()
        st.fur(36.5, 47.6, -0.12, 22, 1.45, bend: 1.0)
        stripe = st
        bib = body.intersection(Path(ellipseIn: CGRect(x: 30, y: 70, width: 22, height: 22)))
    }
}

struct DuckNeck {
    let shape, barbs: Path
}

extension CritterGeometry {
    nonisolated(unsafe) private static var duckGrowth: [String: DuckStages] = [:]
    private static let duckGrowthLock = NSLock()

    static func duckStages(_ plan: CritterPlan) -> DuckStages {
        duckGrowthLock.lock(); defer { duckGrowthLock.unlock() }
        if let kept = duckGrowth[plan.key] { return kept }
        let made = DuckStages(plan)
        duckGrowth[plan.key] = made
        return made
    }
}
