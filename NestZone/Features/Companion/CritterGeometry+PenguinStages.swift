import SwiftUI

/// What a penguin's growing up adds to `PenguinGeometry`: the hatchling's
/// bare, wet blob, the chick's round ball of down, the juvenile's tufts of
/// down still stuck on its new tuxedo, the grown bird's sleek edge and the
/// rockhopper's crest. Built once per plan, only filled.
struct PenguinStages {
    /// Hatchling: a wet, nearly bare blob with a few thin strands, its head
    /// and wisps (shadow left [0] or right [1]).
    let hatchBody: [Path]
    let hatchHairs, hatchWisps, hatchHead: Path
    /// Chick and little one: bodies and heads with a deep fringe of down.
    let chickBody, chickHead: [Path]
    /// Soft strokes of down laid round the chick's body.
    let downHairs: Path
    /// The grown bird: a smooth edge on the body and the head.
    let sleekBody, sleekHead: [Path]
    /// Tufts of down on a moulting juvenile: on the body, and on the head
    /// (the crown's, and the cheek's), each a furred blob with strands.
    let bodyTufts, bodyTuftCores, headTufts, headTuftCores, tuftHairs: Path
    /// The rockhopper's plumes, sweeping back from over the eye.
    let crest, crestLines: Path

    static let hatchCentre = CGPoint(x: 60, y: 92)

    init(_ plan: CritterPlan) {
        var r = Ink.Random("penguin-stages-\(plan.key)")
        let fur = max(0.7, plan.fur)

        let blob = Path.loop([CGPoint(x: 33, y: 101), CGPoint(x: 35, y: 90), CGPoint(x: 46, y: 80.5), CGPoint(x: 60, y: 77.5), CGPoint(x: 74, y: 81),
                              CGPoint(x: 85, y: 90), CGPoint(x: 87, y: 101), CGPoint(x: 72, y: 107.6), CGPoint(x: 47, y: 107.6)])
        func wet(_ right: Double) -> Path {
            FurEdge.furry(blob, seed: "peng-wet-\(right)", gap: 5...9, height: 0.7...1.5, width: 2.2) { p in
                0.4 + 0.6 * Ink.smooth(((p.x - 60) * right) / 26)
            }
        }
        hatchBody = [wet(-1), wet(1)]
        var strands = Path()
        for _ in 0..<26 {
            let x = r.between(38, 83), y = r.between(82, 104)
            let dx = (x - 60) / 26, dy = (y - 93) / 15
            guard dx * dx + dy * dy < 0.9 else { continue }
            strands.fur(x, y, r.between(-0.5, 0.7), r.between(4.2, 6.6), 0.55, bend: 0.8)
        }
        hatchHairs = strands
        var wisps = Path()
        for (x, y, a, len) in [(42.0, 34.0, -1.9, 5.0), (47.0, 32.0, -1.55, 6.0), (52.0, 33.0, -1.25, 5.0), (58.0, 38.0, -0.9, 4.0)] {
            wisps.fur(x, y, a, len, 0.5, bend: 1.2)
        }
        hatchWisps = wisps
        let head = Path(ellipseIn: CGRect(x: 28, y: 29, width: 36, height: 36))
        hatchHead = FurEdge.furry(head, seed: "peng-wet-head", gap: 5...8, height: 0.6...1.3, width: 2.4)

        // The chick: a ball with a deep fringe of down, soft on the underside.
        let chick = Path.loop([CGPoint(x: 31, y: 96), CGPoint(x: 29, y: 76), CGPoint(x: 38, y: 58), CGPoint(x: 58, y: 50), CGPoint(x: 79, y: 58),
                               CGPoint(x: 90, y: 78), CGPoint(x: 88, y: 99), CGPoint(x: 68, y: 110.4), CGPoint(x: 46, y: 110.4)])
        func fluffy(_ path: Path, _ tag: String, _ right: Double, height: ClosedRange<Double>, centre: Double) -> Path {
            FurEdge.furry(path, seed: "peng-chick-\(tag)-\(right)", gap: 4...7.5, height: height, width: 3.4) { p in
                0.4 + 0.6 * Ink.smooth(((p.x - centre) * right) / 26)
            }
        }
        chickBody = [fluffy(chick, "body", -1, height: (1.7 * fur)...(3.6 * fur), centre: 60), fluffy(chick, "body", 1, height: (1.7 * fur)...(3.6 * fur), centre: 60)]
        chickHead = [fluffy(head, "head", -1, height: (1.3 * fur)...(2.9 * fur), centre: 46), fluffy(head, "head", 1, height: (1.3 * fur)...(2.9 * fur), centre: 46)]
        var d = Path()
        for gy in stride(from: 54.0, through: 108, by: 4.8) {
            for gx in stride(from: 33.0, through: 88, by: 5.0) {
                let x = gx + r.between(-1.8, 1.8), y = gy + r.between(-1.8, 1.8)
                let dx = (x - 60) / 28, dy = (y - 82) / 28
                guard dx * dx + dy * dy < 0.88 else { continue }
                d.fur(x, y, atan2(y - 82, x - 60) + .pi / 2 + r.between(-0.3, 0.3), r.between(3.6, 5.6), 0.7)
            }
        }
        downHairs = d

        // The grown bird's edge.
        let body = Path.loop([CGPoint(x: 34, y: 96), CGPoint(x: 31.5, y: 76), CGPoint(x: 40, y: 56), CGPoint(x: 58, y: 47), CGPoint(x: 77, y: 56),
                              CGPoint(x: 87, y: 78), CGPoint(x: 84, y: 100), CGPoint(x: 68, y: 110.4), CGPoint(x: 48, y: 110.4)])
        func sleek(_ path: Path, _ tag: String, _ right: Double) -> Path {
            FurEdge.furry(path, seed: "peng-sleek-\(tag)-\(right)", gap: 8...13, height: (0.1 * fur)...(0.45 * fur), width: 3) { p in
                0.3 + 0.7 * Ink.smooth(((p.x - 60) * right) / 26)
            }
        }
        sleekBody = [sleek(body, "body", -1), sleek(body, "body", 1)]
        sleekHead = [sleek(head, "head", -1), sleek(head, "head", 1)]

        // Tufts of down on a moulting bird, where the old coat is last to go
        // (the crown, the nape, the shoulder, the flank, the thigh, the
        // tail): each a fan of soft strokes standing out from a small core,
        // never a flat patch.
        func fan(_ path: inout Path, _ cores: inout Path, x: Double, y: Double, dir: Double, count: Int, length: ClosedRange<Double>, spread: Double = 1.0) {
            cores.addEllipse(in: CGRect(x: x - 3.2, y: y - 2.6, width: 6.4, height: 5.2))
            for i in 0..<count {
                let a = dir + (Double(i) / Double(max(1, count - 1)) - 0.5) * 2 * spread + r.between(-0.12, 0.12)
                path.fur(x + cos(a) * 1.5, y + sin(a) * 1.5, a, r.between(length.lowerBound, length.upperBound), r.between(0.7, 1.05), bend: r.between(-1.0, 1.0))
            }
        }
        var bt = Path(), btc = Path()
        for (x, y, dir, n) in [(72.0, 58.0, -1.05, 13), (85.0, 76.0, -0.15, 12), (86.0, 93.0, 0.2, 12), (78.0, 104.0, 0.75, 10), (37.0, 100.0, 2.7, 10), (66.0, 52.0, -1.45, 9),
                               (52.0, 105.0, 1.9, 8)] {
            fan(&bt, &btc, x: x, y: y, dir: dir, count: n, length: 4.5...8.0, spread: 1.25)
        }
        bodyTufts = bt; bodyTuftCores = btc
        var ht = Path(), htc = Path()
        fan(&ht, &htc, x: 47, y: 31, dir: -1.55, count: 15, length: 6.0...10, spread: 1.25)
        fan(&ht, &htc, x: 57, y: 38, dir: -0.55, count: 9, length: 4.5...8, spread: 1.1)
        headTufts = ht; headTuftCores = htc
        var th = Path()
        for _ in 0..<14 {
            let x = r.between(70, 90), y = r.between(62, 104)
            th.fur(x, y, r.between(-1.5, -0.2), r.between(3.0, 4.6), 0.5, bend: 1.0)
        }
        tuftHairs = th

        // The rockhopper's crest: three plumes that start over the eye and
        // sweep back, drooping at the ends.
        var cr = Path(), crl = Path()
        for (x, y, a, len, w) in [(37.0, 39.0, -0.55, 17.0, 1.5), (35.5, 41.5, -0.25, 17.0, 1.7), (39.0, 36.5, -0.9, 13.0, 1.3), (36.0, 44.0, 0.05, 12.0, 1.3)] {
            cr.fur(x, y, a, len, w, bend: 2.2)
            crl.move(to: CGPoint(x: x + 1, y: y)); crl.addLine(to: CGPoint(x: x + cos(a) * len * 0.85, y: y + sin(a) * len * 0.85 + 1.2))
        }
        crest = cr; crestLines = crl
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var penguinGrowth: [String: PenguinStages] = [:]
    private static let penguinGrowthLock = NSLock()

    static func penguinStages(_ plan: CritterPlan) -> PenguinStages {
        penguinGrowthLock.lock(); defer { penguinGrowthLock.unlock() }
        if let kept = penguinGrowth[plan.key] { return kept }
        let made = PenguinStages(plan)
        penguinGrowth[plan.key] = made
        return made
    }
}
