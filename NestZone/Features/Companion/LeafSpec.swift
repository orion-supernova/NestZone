import SwiftUI

/// What a tree's foliage is made of, so one engine (`LeafArt`) builds the
/// pomegranate's lances, a lemon's glossy ovals, an olive's silver blades and
/// the small leaves of a cherry or an azalea. The defaults are the
/// pomegranate's, and a species changes only what is its own.
struct LeafSpec: Sendable {
    enum Shape: Sendable {
        /// Narrow, pointed at both ends, widest a third of the way out.
        case lance
        /// An oval with a rounded base and a drawn-out tip: a lemon's, a
        /// magnolia's.
        case glossy
        /// Broad and blunt-tipped.
        case round
    }

    var shape = Shape.lance
    /// Half the leaf's width, as a share of its length.
    var hw = 0.17
    /// A leaf's length against its clump's radius, for the first pair.
    var size = 0.72
    /// Sprigs in a young tip's whorl, in a back clump and in a front one.
    var sprigs = (tuft: 2, back: 3, front: 4)
    /// Whether the front tier also has a sprig hanging under it.
    var underSprig = true
    /// Nodes on a sprig that carry leaves, before the one at the tip.
    var pairs = 2
    /// How far a leaf stands out from its twig, in radians.
    var spread = (0.62, 0.95)
    /// A leaf at a time, alternate sides, instead of a pair.
    var alternate = false
    /// How long a sprig reaches, in clump radii.
    var reach = (0.58, 0.86)
    /// The range of leaf lengths about the sprig's, so no two are alike.
    var lens = (0.78, 1.2)
    /// The share of leaves turned over to show their underside.
    var silver = 0.0
    /// The share of sunstruck leaves with a lens of gloss on the midrib.
    var gloss = 0.35
    /// How much of a clump is a dark body behind its leaves: thin leaves need
    /// little, or it shows as a balloon.
    var body = 1.0
    /// Leaves that are mostly hidden behind flowers keep fewer classes: two behind,
    /// three in front, and none of the glints.
    var flat = false
    /// Olive: the back clumps keep fewer tones (two behind, three in the middle), and the
    /// silver undersides are a fill of their own.
    var merge = false
    /// How much of the pomegranate's thirst and doze thinning a species takes: leaves dropped,
    /// leaves curled short, the dark body behind them. The pomegranate takes all of it; the
    /// others stay the same tree, drooping and paling.
    var calm = 1.0

    static func of(_ species: Species) -> LeafSpec {
        var s = LeafSpec()
        if species != .pomegranate { s.calm = 0.45 }
        switch species {
        case .lemon:
            s.shape = .glossy
            s.hw = 0.22
            s.size = 0.7
            s.sprigs = (2, 4, 5)
            s.pairs = 3
            s.alternate = true
            s.spread = (0.5, 0.9)
            s.lens = (0.85, 1.2)
            s.gloss = 0.55
        case .olive:
            s.hw = 0.085
            s.size = 0.44
            s.body = 0.55
            s.merge = true
            s.sprigs = (2, 4, 4)
            s.pairs = 3
            s.spread = (0.4, 0.8)
            s.reach = (0.6, 0.92)
            s.lens = (0.8, 1.25)
            s.silver = 0.4
            s.gloss = 0
        case .magnolia:
            s.shape = .glossy
            s.hw = 0.2
            s.size = 0.98
            s.sprigs = (2, 3, 3)
            s.pairs = 2
            s.alternate = true
            s.spread = (0.45, 0.8)
            s.reach = (0.5, 0.8)
            s.lens = (0.85, 1.15)
            s.gloss = 0.6
        case .cherry:
            s.shape = .glossy
            s.hw = 0.2
            s.size = 0.5
            s.body = 0.4
            s.flat = true
            s.sprigs = (2, 3, 4)
            s.alternate = true
            s.gloss = 0.3
        case .azalea:
            s.shape = .glossy
            s.hw = 0.21
            s.size = 0.44
            s.body = 0.75
            s.flat = true
            s.sprigs = (3, 4, 5)
            s.pairs = 3
            s.alternate = true
            s.spread = (0.5, 1.0)
            s.reach = (0.5, 0.8)
            s.gloss = 0.2
        default:
            break
        }
        return s
    }
}

extension Path {
    /// A leaf of the given shape from its base at (x, y) along (ca, sa).
    mutating func blade(_ shape: LeafSpec.Shape, _ x: Double, _ y: Double, _ ca: Double, _ sa: Double, _ len: Double, _ hw: Double, _ bend: Double) {
        guard shape != .lance else {
            lance(x, y, ca, sa, len, hw, bend, 0)
            return
        }
        func P(_ u: Double, _ v: Double) -> CGPoint { Self.lancePoint(x, y, ca, sa, len, bend, u, v) }
        let round = shape == .round
        let tipU = round ? 0.8 : 0.62, tipV = round ? 1.3 : 1.0
        move(to: P(0, 0))
        addCurve(to: P(1, 0), control1: P(0.1, hw * 1.9), control2: P(tipU, hw * tipV))
        addCurve(to: P(0, 0), control1: P(tipU, -hw * tipV), control2: P(0.1, -hw * 1.9))
        closeSubpath()
    }
}
