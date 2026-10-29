import SwiftUI

/// What an owl's growing up adds to `BirdGeometry`: the hatchling's bare,
/// wet body, the owlet's ball of down (body and head fringed with it), the
/// feather tips that come in over the down on the back and the wings, the
/// quills of the wings, the wisps of down that cling to a half-feathered
/// brancher. Built once per plan; the painter only fills them.
struct OwlStages {
    /// Hatchling: a pinkish blob with a few strands, and a head with a short
    /// fringe (shadow left [0] or right [1]).
    let hatchBody, hatchHead: [Path]
    let hatchHairs: Path
    /// Owlet: body and head with a deep fringe of down, and soft strokes of
    /// down round the body.
    let downBody, downHead: [Path]
    let downHairs: Path
    /// Feather tips over the body, four cumulative levels: shoulders and
    /// flanks first, the breast last.
    let scallops: [Path]
    /// Quills in the wing, in its own space, for the right wing [1] and the
    /// left [0]: three cumulative levels.
    let wingQuills: [[(shafts: Path, sheaths: Path)]]
    /// Wisps of down that cling over the feathers of a brancher: on the
    /// shoulders and the crown.
    let fuzz, headFuzz: Path

    static let hatchCentre = CGPoint(x: 60, y: 93)

    init(_ plan: CritterPlan) {
        var r = Ink.Random("owl-stages-\(plan.key)")
        let bw = plan.bodyWidth, fur = max(0.8, plan.fur)
        let hw = 27 * plan.headWidth

        let blob = Path.loop([CGPoint(x: 33, y: 102), CGPoint(x: 34, y: 91), CGPoint(x: 45, y: 82), CGPoint(x: 60, y: 79), CGPoint(x: 75, y: 82),
                              CGPoint(x: 86, y: 91), CGPoint(x: 87, y: 102), CGPoint(x: 72, y: 108), CGPoint(x: 48, y: 108)])
        func wet(_ right: Double) -> Path {
            FurEdge.furry(blob, seed: "owl-wet-\(right)", gap: 5...9, height: 0.6...1.4, width: 2.2) { p in
                0.4 + 0.6 * Ink.smooth(((p.x - 60) * right) / 26)
            }
        }
        hatchBody = [wet(-1), wet(1)]
        var strands = Path()
        for _ in 0..<28 {
            let x = r.between(38, 83), y = r.between(83, 105)
            let dx = (x - 60) / 26, dy = (y - 94) / 14
            guard dx * dx + dy * dy < 0.9 else { continue }
            strands.fur(x, y, r.between(-0.5, 0.7), r.between(4.2, 7.0), 0.55, bend: 0.8)
        }
        hatchHairs = strands

        let body = Path(ellipseIn: CGRect(x: 60 - 28 * bw, y: 50, width: 56 * bw, height: 60))
        let head = Path(ellipseIn: CGRect(x: 60 - hw, y: 28, width: hw * 2, height: 44))
        func fringe(_ path: Path, _ tag: String, _ right: Double, height: ClosedRange<Double>, gap: ClosedRange<Double>) -> Path {
            FurEdge.furry(path, seed: "owl-down-\(tag)-\(plan.key)-\(right)", gap: gap, height: height, width: 3.6) { p in
                0.45 + 0.55 * Ink.smooth(((p.x - 60) * right) / 24)
            }
        }
        downBody = [fringe(body, "body", -1, height: (2.2 * fur)...(4.2 * fur), gap: 4...7.5), fringe(body, "body", 1, height: (2.2 * fur)...(4.2 * fur), gap: 4...7.5)]
        downHead = [fringe(head, "head", -1, height: (1.8 * fur)...(3.4 * fur), gap: 3.5...6.5), fringe(head, "head", 1, height: (1.8 * fur)...(3.4 * fur), gap: 3.5...6.5)]
        hatchHead = [fringe(head, "hatch", -1, height: (0.6 * fur)...(1.4 * fur), gap: 5...8), fringe(head, "hatch", 1, height: (0.6 * fur)...(1.4 * fur), gap: 5...8)]
        var dh = Path()
        for gy in stride(from: 54.0, through: 108, by: 4.8) {
            for gx in stride(from: 33.0, through: 87, by: 5.0) {
                let x = gx + r.between(-1.8, 1.8), y = gy + r.between(-1.8, 1.8)
                let dx = (x - 60) / (27 * bw), dy = (y - 80) / 29
                guard dx * dx + dy * dy < 0.9 else { continue }
                dh.fur(x, y, atan2(y - 80, x - 60) + .pi / 2 + r.between(-0.3, 0.3), r.between(3.8, 6.0), 0.7)
            }
        }
        downHairs = dh

        // Feather tips: the shoulders and flanks come in first, the breast
        // (which keeps its down longest) last, and a slow wave in the weight
        // keeps half-feathered from being a line.
        scallops = Plumage.scallops(seed: "owl-scallops-\(plan.key)", bounds: CGRect(x: 60 - 28 * bw, y: 52, width: 56 * bw, height: 58), pitch: CGSize(width: 5.4, height: 4.8),
                                    size: CGSize(width: 6.8, height: 6.0), tilt: 0) { p in
            let dx = (p.x - 60) / (27 * bw), dy = (p.y - 80) / 29
            guard dx * dx + dy * dy < 0.92 else { return nil }
            let outer = Ink.smooth(abs(dx) * 1.25)
            let shoulder = Ink.clamp(0.5 - dy * 0.5)
            let wave = 0.2 * sin(p.x * 0.45 + 0.7) * cos(p.y * 0.4)
            return Ink.clamp(0.2 + 0.55 * outer + 0.25 * shoulder + wave)
        }

        func quills(_ s: Double) -> [(shafts: Path, sheaths: Path)] {
            let sets: [[(CGPoint, Double, Double)]] = [
                [(CGPoint(x: s * 3, y: 38), .pi / 2 + s * 0.1, 5.5), (CGPoint(x: s * 8, y: 36), .pi / 2 + s * 0.2, 5)],
                [(CGPoint(x: s * 5, y: 40), .pi / 2 + s * 0.05, 6), (CGPoint(x: s * 10, y: 33), .pi / 2 + s * 0.3, 5), (CGPoint(x: s * 1, y: 34), .pi / 2, 5)],
                [(CGPoint(x: s * 7, y: 40), .pi / 2 + s * 0.15, 5.5), (CGPoint(x: s * 11, y: 26), .pi / 2 + s * 0.35, 4.5)]]
            var running: [(CGPoint, Double, Double)] = []
            return sets.map { running += $0; return Plumage.quills(running) }
        }
        wingQuills = [quills(-1), quills(1)]

        var f = Path()
        for _ in 0..<26 {
            let a = r.between(0, .pi * 2)
            let x = 60 + cos(a) * r.between(16, 27) * bw, y = 76 + sin(a) * r.between(8, 24)
            f.fur(x, y, a - .pi / 2 + r.between(-0.6, 0.6) * 0 + (a > 0 && a < .pi ? 0 : -0.4), r.between(3.2, 5.4), 0.6, bend: 1.0)
        }
        fuzz = f
        var hf = Path()
        for _ in 0..<18 {
            let x = 60 + r.between(-hw * 0.85, hw * 0.85), y = r.between(30, 42)
            hf.fur(x, y, -.pi / 2 + (x - 60) / hw * 0.7 + r.between(-0.25, 0.25), r.between(3.5, 6.5), 0.6, bend: 1.2)
        }
        headFuzz = hf
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var owlGrowth: [String: OwlStages] = [:]
    private static let owlGrowthLock = NSLock()

    static func owlStages(_ plan: CritterPlan) -> OwlStages {
        owlGrowthLock.lock(); defer { owlGrowthLock.unlock() }
        if let kept = owlGrowth[plan.key] { return kept }
        let made = OwlStages(plan)
        owlGrowth[plan.key] = made
        return made
    }
}
