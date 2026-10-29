#if DEBUG
import SwiftUI

/// Set by an art sheet cell while it draws, so the tree under it is drawn with
/// its skeleton and with a mark on anything that is not held by wood.
enum TreeDebug {
    nonisolated(unsafe) static var wood = false
    /// The pixel audit is drawing: leave out what is meant to be in the air.
    nonisolated(unsafe) static var pixel = false
}

/// Whether a tree's foliage is on its wood at a growth and mood: every clump,
/// blossom, bud and fruit's spur is within a few points of a limb or a twig, or
/// inside leaves that are themselves on one. It is the check behind
/// `-artSheet attach-scan` and the overlay of the growth sheets
/// (`-artSheet <tree>-growth-wood`).
enum TreeAudit {
    /// How far from wood, in the scene's points, a thing may stand and still be
    /// held by it: a twig's end and a flower's width.
    static let tolerance = 3.5

    struct Subject {
        var core: TreeCore
        var leafK: Double
        var hung: (inout TreeCore.Sprigs) -> Void
    }

    /// The painter's own view of a tree at this growth, mood and light.
    static func subject(_ canopy: Canopy, growth: Double, mood: Double, day: Double = 1, light: Double = 0) -> Subject? {
        func of(_ art: some TreeArt) -> Subject { Subject(core: art.core, leafK: art.leafK, hung: { art.hung(&$0) }) }
        switch canopy.species {
        case .lemon: return of(LemonPainter(canopy: canopy, growth: growth, mood: mood, day: day, light: light))
        case .olive: return of(OlivePainter(canopy: canopy, growth: growth, mood: mood, day: day, light: light))
        case .magnolia: return of(MagnoliaPainter(canopy: canopy, growth: growth, mood: mood, day: day, light: light))
        case .cherry: return of(CherryPainter(canopy: canopy, growth: growth, mood: mood, day: day, light: light))
        case .azalea: return of(AzaleaPainter(canopy: canopy, growth: growth, mood: mood, day: day, light: light))
        case .pomegranate:
            let M = Canopy.Mood(mood)
            let tones = Canopy.Tones(canopy.kind, M, day: day, growth: growth)
            let core = TreeCore(canopy, growth: growth, mood: mood, day: day, light: light, tones: tones, M: M, fresh: 0xBE5A38)
            return Subject(core: core, leafK: 1, hung: { core.noteCrop(&$0) })
        default: return nil
        }
    }

    struct Finding {
        var kind: String
        var at: CGPoint
        var gap: Double
    }

    /// The wood of the pose as short segments: each limb's curve in a dozen steps.
    static func wood(_ pose: Canopy.Pose) -> [(CGPoint, CGPoint)] {
        var out: [(CGPoint, CGPoint)] = []
        for case let q? in pose.limbs {
            var last = TreeWood.along(q, 0)
            for step in 1...12 {
                let next = TreeWood.along(q, Double(step) / 12)
                out.append((last, next))
                last = next
            }
        }
        return out
    }

    static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y, len2 = dx * dx + dy * dy
        let t = len2 < 1e-9 ? 0 : max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        let x = a.x + dx * t - p.x, y = a.y + dy * t - p.y
        return (x * x + y * y).squareRoot()
    }

    /// What is not held, at this growth and mood, and how many things were
    /// looked at.
    static func check(_ subject: Subject) -> (checked: Int, findings: [Finding], sprigs: TreeCore.Sprigs) {
        let core = subject.core
        var sprigs = TreeCore.Sprigs()
        sprigs.audit = true
        subject.hung(&sprigs)
        var segments = wood(core.pose)
        segments.append(contentsOf: sprigs.segments)
        func nearest(_ p: CGPoint) -> Double { segments.reduce(Double.infinity) { min($0, distance(p, $1.0, $1.1)) } }

        // Leaf masses: a thing inside the leaves of any clump is held by them, as
        // they are by the wood (checked below).
        var masses: [(CGPoint, Double)] = []
        for i in core.pose.clumps.indices {
            guard let q = core.pose.clumps[i] else { continue }
            let c = core.settle(q, leaf: subject.leafK)
            masses.append((CGPoint(x: c.x, y: c.y), 0.85 * c.R * subject.leafK))
        }
        var findings: [Finding] = []
        var checked = sprigs.flowers
        for item in sprigs.items {
            checked += 1
            let inLeaves = masses.contains { m in
                let dx = item.at.x - m.0.x, dy = item.at.y - m.0.y
                return (dx * dx + dy * dy).squareRoot() <= item.cover * m.1
            }
            if inLeaves { continue }
            let gap = nearest(item.at)
            if gap > tolerance { findings.append(Finding(kind: item.kind, at: item.at, gap: gap)) }
        }
        // Each clump's leaves: the wood has to reach into them, or they have to be
        // part of the mass of a clump on the same limb that it does (the darker
        // clump behind another).
        var centres: [Int: (CGPoint, Double)] = [:]
        var reached = Set<Int>()
        for i in core.pose.clumps.indices {
            guard let q = core.pose.clumps[i] else { continue }
            let c = core.settle(q, leaf: subject.leafK), rho = 0.85 * c.R * subject.leafK
            centres[i] = (CGPoint(x: c.x, y: c.y), rho)
            checked += 1
            if nearest(CGPoint(x: c.x, y: c.y)) <= max(tolerance, rho) { reached.insert(i) }
        }
        for (i, (at, rho)) in centres where !reached.contains(i) {
            let node = core.canopy.clumps[i].node
            let joined = reached.contains { j in
                guard core.canopy.clumps[j].node == node, let other = centres[j] else { return false }
                let dx = at.x - other.0.x, dy = at.y - other.0.y
                return (dx * dx + dy * dy).squareRoot() <= (rho + other.1)
            }
            if !joined { findings.append(Finding(kind: "clump", at: at, gap: nearest(at) - rho)) }
        }
        return (checked, findings, sprigs)
    }

    // MARK: Overlay

    /// The skeleton, the twigs, the leaf discs, and a dot on each thing held (green)
    /// or a red ring on each that is not. Drawn in the tree's own space.
    static func overlay(_ art: some TreeArt, _ tree: GraphicsContext) {
        overlay(Subject(core: art.core, leafK: art.leafK, hung: { art.hung(&$0) }), tree)
    }

    static func overlay(_ subject: Subject, _ tree: GraphicsContext) {
        let (_, findings, sprigs) = check(subject)
        var skeleton = Path(), twigs = Path(), discs = Path()
        for (a, b) in wood(subject.core.pose) { skeleton.move(to: a); skeleton.addLine(to: b) }
        for (a, b) in sprigs.segments { twigs.move(to: a); twigs.addLine(to: b) }
        for i in subject.core.pose.clumps.indices {
            guard let q = subject.core.pose.clumps[i] else { continue }
            let c = subject.core.settle(q, leaf: subject.leafK), rho = 0.85 * c.R * subject.leafK
            discs.addEllipse(in: CGRect(x: c.x - rho, y: c.y - rho, width: rho * 2, height: rho * 2))
        }
        tree.stroke(discs, with: .color(.green.opacity(0.7)), lineWidth: 0.6)
        tree.stroke(skeleton, with: .color(.cyan), lineWidth: 0.7)
        tree.stroke(twigs, with: .color(.yellow), lineWidth: 0.6)
        var held = Path()
        for item in sprigs.items { held.addEllipse(in: CGRect(x: item.at.x - 1, y: item.at.y - 1, width: 2, height: 2)) }
        tree.fill(held, with: .color(.green))
        var bad = Path()
        for f in findings { bad.addEllipse(in: CGRect(x: f.at.x - 4, y: f.at.y - 4, width: 8, height: 8)) }
        tree.stroke(bad, with: .color(.red), lineWidth: 1.4)
        tree.fill(bad, with: .color(.red.opacity(0.35)))
    }
}
#endif
