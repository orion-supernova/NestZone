import SwiftUI

/// What keeps a tree's foliage on its wood, at every growth from the seed to
/// the grown crown and not only at the stages. The rules are in
/// `Docs/Companion/art/RULES.md`, section 18.
///
/// A clump is placed at the tip of the limb that carries it, but the things it
/// carries (a blossom, a bud, a fruit's spur) are laid out in the clump's own
/// units at the size of the *grown* crown. While the leaves are still small a
/// magnolia's buds or a cherry's clusters therefore stood a clump's radius off
/// the wood, in the air, with nothing between. So three things hold them on:
///
/// - the clump's centre slides back to the tip as its leaves get smaller
///   (`settle`): a clump with few leaves is a tuft on the tip, not a tuft
///   beside it;
/// - what it carries is gathered towards the tip while the leaves are few
///   (`gather`), and spread to its grown places as they come in, so at the
///   grown size the picture is the one it always was;
/// - what still stands clear of the leaves is held by a twig from the tip
///   (`Sprigs`), one thin fill for the whole crown, drawn with the wood.
extension TreeCore {
    /// Where the clump's leaves are drawn once `k` of them are out (1 is all):
    /// its centre moves from the tip to the grown place as they come in, so a
    /// clump with few leaves is on the wood. All of them leaves the pose as it is.
    func settle(_ q: Canopy.Pose.Spot, leaf k: Double) -> Canopy.Pose.Spot { q.settled(leaf: k) }

    /// How far a clump's blossoms and fruit spread from its tip while `k` of its
    /// leaves are out: from half their grown reach with the first leaves to all
    /// of it between `lo` and `hi`.
    func gather(_ k: Double, from lo: Double = 0.1, to hi: Double = 1) -> Double {
        guard TreeAttach.on else { return 1 }
        return 0.5 + 0.5 * Ink.smooth((k - lo) / max(0.01, hi - lo))
    }

    /// A point carried by a clump, `dx` and `dy` in its own units from its
    /// centre, with the leaves `k` out and the carried things gathered by `g`.
    func site(_ q: Canopy.Pose.Spot, leaf k: Double, gather g: Double, _ dx: Double, _ dy: Double) -> CGPoint {
        let c = settle(q, leaf: k)
        return CGPoint(x: c.x + dx * c.R * g, y: c.y + dy * c.R * g)
    }

    /// Everything that is hung on the crown away from its leaves, as wood: the
    /// twigs from limb tips to what they carry, in one path (one fill), and for
    /// the audit what was hung and the wood that holds it.
    struct Sprigs {
        var path = Path()
        var audit = false
        /// The audit's: every point that must be on wood or in leaves, the leaf
        /// disc that may cover it, and the segments of wood the twigs add.
        var items: [Item] = []
        var segments: [(CGPoint, CGPoint)] = []
        /// How many flowers stand on a stalk of a cluster that is itself held.
        var flowers = 0

        struct Item {
            var kind: String
            var at: CGPoint
            var centre: CGPoint
            var radius: Double
            /// How much of the leaf disc counts as covering it.
            var cover = 0.62
        }

        /// A tapered, slightly bowed twig, as two thin quads.
        mutating func twig(_ a: CGPoint, _ b: CGPoint, _ w0: Double, _ w1: Double) {
            let dx = b.x - a.x, dy = b.y - a.y, d = max(1e-6, (dx * dx + dy * dy).squareRoot())
            // The bow is a share of the length, to the side the twig leans.
            let bow = min(2.2, d * 0.07) * (dx >= 0 ? 1.0 : -1)
            let m = CGPoint(x: (a.x + b.x) / 2 - dy / d * bow, y: (a.y + b.y) / 2 + dx / d * bow)
            path.twig(a, m, w0, (w0 + w1) / 2)
            path.twig(m, b, (w0 + w1) / 2, w1)
            if audit {
                segments.append((a, m))
                segments.append((m, b))
            }
        }
    }

    /// Holds one carried point `at` of clump `i` on the wood: nothing when the
    /// clump's leaves cover it, otherwise a twig from the limb's tip. `k` is how
    /// much of the clump's leaves are out.
    func hang(_ s: inout Sprigs, _ kind: String, clump i: Int, at: CGPoint, leaf k: Double) {
        guard let q = pose.clumps[i] else { return }
        let c = settle(q, leaf: k), rho = 0.85 * c.R * k
        let centre = CGPoint(x: c.x, y: c.y)
        if s.audit { s.items.append(Sprigs.Item(kind: kind, at: at, centre: centre, radius: rho)) }
        guard TreeAttach.on else { return }
        let dx = at.x - c.x, dy = at.y - c.y
        guard (dx * dx + dy * dy).squareRoot() > 0.62 * rho else { return }
        let tip = CGPoint(x: q.ax, y: q.ay)
        let reach = ((at.x - tip.x) * (at.x - tip.x) + (at.y - tip.y) * (at.y - tip.y)).squareRoot()
        guard reach > 1.2 else { return }
        // A twig thickens a little with the clump's size.
        let w = 0.55 + 0.35 * min(1, q.R / 30)
        s.twig(tip, at, w, w * 0.5)
    }

    /// Notes a carried point for the audit only: it is held by something else
    /// (a cluster's own stalk), not by a twig of its own.
    func note(_ s: inout Sprigs, _ kind: String, clump i: Int, at: CGPoint, leaf k: Double, cover: Double = 0.62) {
        guard s.audit, let q = pose.clumps[i] else { return }
        let c = settle(q, leaf: k)
        s.items.append(Sprigs.Item(kind: kind, at: at, centre: CGPoint(x: c.x, y: c.y), radius: 0.85 * c.R * k, cover: cover))
    }

    /// The blossoms and fruit of a tree that has all its leaves, for the audit,
    /// as the painters of the lemon, the olive and the pomegranate show them.
    func noteCrop(_ s: inout Sprigs) {
        guard s.audit else { return }
        let stays: Double = canopy.species == .olive ? 0.4 : canopy.species == .pomegranate ? 0.32 : 0.5
        for b in canopy.blossoms where p > 0.55 {
            guard let q = pose.clumps[b.clump] else { continue }
            let first = 0.56 + b.born * 0.12
            guard Ink.back((p - first) / 0.04) > 0 else { continue }
            let gone = b.born < stays ? 1 : 1 - Ink.smooth((p - (0.86 + b.born * 0.06)) / 0.03)
            guard gone > 0.03 else { continue }
            note(&s, "blossom", clump: b.clump, at: site(q, leaf: 1, gather: 1, b.dx, b.dy), leaf: 1, cover: 1.1)
        }
        for f in canopy.fruits where p > 0.8 {
            guard let q = pose.clumps[f.clump] else { continue }
            guard Ink.back((p - (0.84 + f.born * 0.07)) / 0.1) > 0.02 else { continue }
            // A fruit hangs in the clump's leaves, low in them.
            note(&s, "fruit", clump: f.clump, at: site(q, leaf: 1, gather: 1, f.dx * 0.66, 0.14 + 0.95 * f.hang), leaf: 1, cover: 1)
        }
    }

    /// The twigs of a crown, filled once in the bark's colour.
    func twigs(_ tree: GraphicsContext, _ s: Sprigs) {
        guard !s.path.isEmpty else { return }
        tree.fill(s.path, with: .color(tones.bark.mix(tones.barkHi, 0.18).color()))
    }
}

extension Canopy.Pose.Spot {
    /// The clump with its centre held to its limb's tip: while few leaves are out
    /// it slides back to the tip, and however many are out the tip stays inside
    /// the leaf mass, which a drooping crown (`TreeCore.calmed`) had let slip.
    func settled(leaf k: Double) -> Self {
        guard TreeAttach.on else { return self }
        let s = min(1, 1.25 * k)
        var r = self
        r.x = ax + (x - ax) * s
        r.y = ay + (y - ay) * s
        let dx = r.x - ax, dy = r.y - ay, d = (dx * dx + dy * dy).squareRoot(), reach = max(0.64 * R * k, hold + 0.3 * R * k)
        if d > reach && d > 0 {
            r.x = ax + dx * reach / d
            r.y = ay + dy * reach / d
        }
        return r
    }
}

/// The switch for the fix, and for the audit that proves it.
enum TreeAttach {
    #if DEBUG
    /// `-attachFix 0` draws the crown the way it was before foliage was held to
    /// its wood, to see the difference on the same build.
    static let on = UserDefaults.standard.object(forKey: "attachFix") == nil || UserDefaults.standard.bool(forKey: "attachFix")
    #else
    static let on = true
    #endif
}
