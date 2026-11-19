import SwiftUI

extension TreeCore {
    /// A fruit as the leaves in front of it see it.
    struct Cover {
        var x, y, r: Double
        var index: Int
        var deep: Bool
        /// The one that is cut open has none, so the cut shows.
        var skip = false
    }

    /// Leaves in front of a fruit: one or two across its shoulders or over its
    /// top, a different few for each, so it is seen between them and not hung
    /// on them.
    func cover(_ tree: GraphicsContext, _ items: [Cover], _ ink: Paint, lean: Bool = false) {
        guard !items.isEmpty else { return }
        var full = Path(), lit = Path()
        for h in items where !h.skip {
            let r = h.r, shape = spec.shape, hw = spec.hw
            // Which leaves hang over it varies from fruit to fruit: one over a
            // shoulder, or two meeting over the top, or a low one across its side.
            var specs: [(Double, Double, Double, Double)]
            switch h.index % 4 {
            case 0: specs = [(-0.95, -1.15, 0.85, 1.05), (0.95, -1.1, Double.pi - 0.8, 1.0)]
            case 1: specs = [(-1.05, -0.85, 0.7, 1.1), (0.1, -1.4, Double.pi / 2 + 0.3, 0.85)]
            case 2: specs = [(1.05, -0.95, Double.pi - 0.75, 1.15), (-0.2, -1.35, Double.pi / 2 - 0.35, 0.8)]
            default: specs = [(-0.9, -1.1, 0.95, 1.0), (1.2, -0.3, Double.pi - 0.25, 0.9)]
            }
            // A lean cover leaves most of a fruit in view: one leaf, two for the sunk.
            if lean && !h.deep { specs = Array(specs.prefix(1)) }
            if h.deep { specs.append((-0.3, -0.35, 0.3, 1.1)) }
            for (dx, dy, a, len) in specs {
                let x = h.x + dx * r, y = h.y + dy * r, ca = cos(a), sa = sin(a)
                let bend = 0.1 * (ca < 0 ? -1 : 1)
                full.blade(shape, x, y, ca, sa, r * len, r * len * hw, bend)
                lit.lance(x, y, ca, sa, r * len, r * len * hw, bend, (-sa * L.x + ca * L.y) >= 0 ? 1 : -1)
            }
        }
        guard !full.isEmpty else { return }
        tree.fill(full, with: .color(ink.m))
        tree.fill(lit, with: .color(ink.l))
    }
}
