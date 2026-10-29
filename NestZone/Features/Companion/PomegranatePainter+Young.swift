import SwiftUI

// MARK: - The whip

extension PomegranatePainter.Look {
    /// How far a young tree's canes are spread, 1 at the start and 0 from about
    /// .62: the household's skeleton stands its three stems nearly side by side
    /// until the limbs fork, which draws as a column. A tree that is going to be
    /// a vase should look like one from the start, so the pose is opened out
    /// with height (a horizontal stretch about the trunk, more the higher up
    /// and the younger), limbs and clumps together. Only the picture moves; the
    /// skeleton, the fit and the anchors are the tree's own.
    static func splayed(_ pose: Canopy.Pose, growth p: Double) -> Canopy.Pose {
        let s = 1 - Ink.smooth((p - 0.3) / 0.32)
        guard s > 0.01 else { return pose }
        var pose = pose
        func open(_ x: Double, _ y: Double) -> Double { x * (1 + 1.5 * s * min(1.3, max(0, -y) / 42)) }
        for i in pose.limbs.indices {
            guard var q = pose.limbs[i] else { continue }
            q.x = open(q.x, q.y)
            q.x1 = open(q.x1, q.y1)
            q.cx = open(q.cx, q.cy)
            pose.limbs[i] = q
        }
        for i in pose.clumps.indices {
            guard var q = pose.clumps[i] else { continue }
            q.x = open(q.x, q.y)
            q.ax = open(q.ax, q.ay)
            pose.clumps[i] = q
        }
        return pose
    }

    /// A young pomegranate is a few slender canes with leaves in pairs along
    /// them, set well apart so the cane shows between, and a tuft at each tip.
    /// The pairs are drawn on the limbs themselves and shrink away as the
    /// crown's own clumps take over (from about .5 to .72).
    func youngSprigs(_ tree: GraphicsContext) {
        let young = 1 - Ink.smooth((p - 0.5) / 0.22)
        guard young > 0.02 else { return }
        let ink = inks[5]
        var shade = Path(), middle = Path(), lit = Path(), rim = Path()
        func leaf(_ x: Double, _ y: Double, _ a: Double, _ len: Double) {
            let ca = cos(a), sa = sin(a), face = ca * L.x + sa * L.y
            let bend = (ca >= 0 ? 1.0 : -1) * (0.1 + 0.2 * M.wilt)
            let side = (-sa * L.x + ca * L.y) >= 0 ? 1.0 : -1
            if face > 0.3 {
                lit.lance(x, y, ca, sa, len, len * 0.2, bend, 0)
                rim.lanceEdge(x, y, ca, sa, len, len * 0.2, bend, side)
            } else if face > -0.35 {
                middle.lance(x, y, ca, sa, len, len * 0.2, bend, 0)
            } else {
                shade.lance(x, y, ca, sa, len, len * 0.2, bend, 0)
            }
        }
        for (i, node) in canopy.limbs.enumerated() {
            guard let q = pose.limbs[i] else { continue }
            let dx = q.x1 - q.x, dy = q.y1 - q.y, span = (dx * dx + dy * dy).squareRoot()
            guard span > 3 else { continue }
            let am = atan2(dy, dx)
            // Leaves shrink with the cane's growth and with the crown taking over.
            let size = max(7, min(16, span * 0.5)) * (0.45 + 0.55 * q.g) * young.squareRoot()
            let pairs = 2
            for n in 0..<pairs {
                let u = node.depth == 0 ? 0.5 + 0.34 * Double(n) : (Double(n) + 1) / (Double(pairs) + 0.6) * 0.9
                let c = along(q, u)
                // Opposite pairs, a little out of step, held out from the cane.
                let spread = 1.15 - 0.25 * u
                let s = size * (1 - 0.25 * u)
                leaf(c.x, c.y, am - spread, s)
                leaf(c.x, c.y, am + spread + (n % 2 == 0 ? 0.1 : -0.1), s * 0.95)
            }
            // The cane's growing end: a pair and a leaf.
            leaf(q.x1, q.y1, am - 0.55, size * 0.8)
            leaf(q.x1, q.y1, am + 0.55, size * 0.8)
            leaf(q.x1, q.y1, am, size * 0.85)
        }
        guard !(shade.isEmpty && middle.isEmpty && lit.isEmpty) else { return }
        tree.fill(shade, with: .color(ink.d))
        tree.fill(middle, with: .color(ink.m))
        tree.fill(lit, with: .color(ink.l))
        tree.fill(rim, with: .color(ink.rim))
    }
}
