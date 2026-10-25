import SwiftUI

// MARK: - The fruit that is split open

extension PomegranatePainter.Look {
    private typealias RGB = Canopy.RGB

    /// How far each point of the torn skin's edge strays from a plain oval:
    /// uneven, because a tear is, and pulled out to a point at each end of the
    /// split, the way a skin gives.
    private static let tear: [Double] = (0..<20).map { (j: Int) -> Double in
        let d = Double(j), t = d * Double.pi * 2 / 20
        let ends: [Double] = [0, Double.pi, Double.pi * 2]
        var tip = 0.0
        for e in ends { tip += exp(-(t - e) * (t - e) / 0.1) }
        let wobble: Double = 0.07 * sin(2.7 * d + 0.4) + 0.06 * sin(5.3 * d + 1.1)
        return 1 + wobble + 0.3 * tip
    }
    /// The same for the inside, which is not the skin's shape: the rind is
    /// thicker in some places than in others.
    private static let hollow: [Double] = (0..<20).map { (j: Int) -> Double in
        let d = Double(j)
        let wobble: Double = 0.09 * sin(1.9 * d + 2.0) + 0.06 * sin(4.3 * d)
        return 0.76 + wobble
    }

    /// The split: the skin torn open along a ragged edge, the thick pale rind
    /// under it, the dark inside, white membranes dividing it into four
    /// chambers and the arils packed into each, every one with its own glint,
    /// a gleam of juice over them, a drop hanging from the lip and an aril that
    /// has rolled out. Drawn on top of the fruit's round body, at its size.
    func cutaway(_ tree: GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ h: Hanging) {
        let sk = h.skin
        let rot = -0.5, ca = cos(rot), sa = sin(rot)
        let cx = x + r * 0.04, cy = y - r * 0.05
        let a = r * 0.7, b = r * 0.5
        let lx = L.x, ly = L.y
        let n = Self.tear.count

        func frame(_ u: Double, _ v: Double, dx: Double = 0, dy: Double = 0) -> CGPoint {
            CGPoint(x: cx + dx + ca * u - sa * v, y: cy + dy + sa * u + ca * v)
        }
        func point(_ j: Int, _ radii: [Double], _ scale: Double, dx: Double, dy: Double) -> CGPoint {
            let t = Double(j) * .pi * 2 / Double(n), w = scale * radii[j % n]
            return frame(cos(t) * a * w, sin(t) * b * w, dx: dx, dy: dy)
        }
        /// A ragged edge, straight between its points.
        func torn(_ scale: Double, dx: Double = 0, dy: Double = 0) -> Path {
            var path = Path()
            for j in 0..<n {
                let pt = point(j, Self.tear, scale, dx: dx, dy: dy)
                if j == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
            return path
        }
        /// The inside, smoothed through the midpoints of its points.
        func hollowed(dx: Double, dy: Double) -> Path {
            var path = Path()
            func mid(_ i: Int, _ j: Int) -> CGPoint {
                let p = point(i, Self.hollow, 1, dx: dx, dy: dy), q = point(j, Self.hollow, 1, dx: dx, dy: dy)
                return CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
            }
            path.move(to: mid(0, 1))
            for j in 1...n { path.addQuadCurve(to: mid(j, j + 1), control: point(j, Self.hollow, 1, dx: dx, dy: dy)) }
            path.closeSubpath()
            return path
        }

        // The skin's torn lip, the rind's thick pale band under it, and the
        // inside, set a touch off-centre so the rind is thicker on one side.
        let lip = sk.shade.mix(sk.mid, 0.4)
        let set = TreeColours.pomegranate(canopy.colourway)
        let pith = RGB.tone(set.pith, day: day, dim: 0.75).mix(sk.mid, 0.2)
        let inside = RGB.tone(set.inside, day: day, dim: 0.5)
        tree.fill(torn(1.13, dx: -lx * r * 0.02, dy: -ly * r * 0.02), with: .color(lip.color()))
        tree.fill(torn(0.97), with: .color(pith.color()))
        let cavity = hollowed(dx: -lx * r * 0.03, dy: -ly * r * 0.03)
        tree.fill(cavity, with: .color(inside.color()))
        // The rind's shadow where it overhangs.
        tree.stroke(cavity, with: .color(RGB(0x1C0208).color(0.36)), style: StrokeStyle(lineWidth: r * 0.1, lineJoin: .round))

        // Four membranes from the middle to the rind, a little bowed, pale as
        // the pith, and the core they meet at.
        let psi = [0.3, 1.9, 3.35, 4.75]
        var walls = Path()
        for t in psi {
            let tip = 0.66
            walls.move(to: frame(cos(t) * a * 0.05, sin(t) * b * 0.05))
            walls.addQuadCurve(to: frame(cos(t) * a * tip, sin(t) * b * tip), control: frame(cos(t + 0.2) * a * tip * 0.5, sin(t + 0.2) * b * tip * 0.5))
        }
        tree.stroke(walls, with: .color(pith.mix(RGB(0xFFFFFF), 0.1).color(0.95)), style: StrokeStyle(lineWidth: r * 0.08, lineCap: .round))
        var core = Path()
        core.oval(cx, cy, r * 0.09, r * 0.075, rot)
        tree.fill(core, with: .color(pith.color()))

        // Arils packed into each chamber in rings, close to its walls, two
        // jewel tones so the packing has depth, each with a glint.
        var lighter = Path(), deeper = Path(), shines = Path(), streaks = Path()
        let rings: [(Double, Int)] = [(0.3, 1), (0.55, 2), (0.8, 3)]
        for (k, start) in psi.enumerated() {
            let end = k + 1 < psi.count ? psi[k + 1] : psi[0] + .pi * 2
            let span = end - start
            for (ring, spec) in rings.enumerated() {
                let (rho, count) = spec
                for m in 0..<count {
                    let jit = Double((k * 7 + ring * 5 + m * 3) % 5) / 4 - 0.5
                    let t = start + span * (0.14 + 0.72 * (Double(m) + 0.5) / Double(count)) + jit * 0.06
                    let rr = rho * 0.62 + jit * 0.03
                    let rad = r * (0.108 - 0.008 * Double(ring % 2) + jit * 0.008)
                    let pt = frame(cos(t) * a * rr * 1.2, sin(t) * b * rr * 1.2)
                    // The aril's long way points to the middle, as a seed packed in a wedge's does.
                    let toward = atan2(cy - pt.y, cx - pt.x)
                    if (k + ring + m) % 2 == 0 { lighter.oval(pt.x, pt.y, rad * 1.15, rad * 0.92, toward) } else { deeper.oval(pt.x, pt.y, rad * 1.15, rad * 0.92, toward) }
                    shines.oval(pt.x + lx * rad * 0.38, pt.y + ly * rad * 0.38, rad * 0.3, rad * 0.2, atan2(ly, lx) + .pi / 2)
                    if (k + ring + m) % 3 == 0 {
                        streaks.move(to: CGPoint(x: pt.x + cos(atan2(ly, lx) - 0.7) * rad * 0.66, y: pt.y + sin(atan2(ly, lx) - 0.7) * rad * 0.66))
                        streaks.arc(pt.x, pt.y, rad * 0.66, atan2(ly, lx) - 0.7, atan2(ly, lx) + 0.45)
                    }
                }
            }
        }
        let reach = r * 0.7
        func jewel(_ hi: UInt32, _ mid: UInt32, _ lo: UInt32) -> GraphicsContext.Shading {
            .linearGradient(Gradient(stops: [.init(color: RGB(hi).mix(RGB(0x7C0C26), 0.5 * night).color(), location: 0),
                                             .init(color: RGB(mid).mix(RGB(0x5A0A22), 0.5 * night).color(), location: 0.5),
                                             .init(color: RGB(lo).mix(RGB(0x3C0818), 0.4 * night).color(), location: 1)]),
                            startPoint: CGPoint(x: cx + lx * reach, y: cy + ly * reach), endPoint: CGPoint(x: cx - lx * reach, y: cy - ly * reach))
        }
        tree.fill(deeper, with: jewel(set.deeper.hi, set.deeper.mid, set.deeper.shade))
        tree.fill(lighter, with: jewel(set.lighter.hi, set.lighter.mid, set.lighter.shade))
        var all = lighter
        all.addPath(deeper)
        tree.stroke(all, with: .color(RGB(0x4A0820).color(0.5)), lineWidth: r * 0.03)
        tree.fill(shines, with: .color(Color.white.opacity(0.88 * (1 - 0.5 * night))))
        tree.stroke(streaks, with: .color(Color.white.opacity(0.5 * (1 - 0.5 * night))), style: StrokeStyle(lineWidth: r * 0.025, lineCap: .round))
        // A wet sheen across the lit side of the packed arils.
        var sheen = Path()
        sheen.oval(cx + lx * r * 0.18, cy + ly * r * 0.18, r * 0.5, r * 0.36, rot)
        tree.fill(sheen, with: .radialGradient(Gradient(colors: [Color.white.opacity(0.2 * (1 - 0.5 * night)), Color.white.opacity(0)]),
                                               center: CGPoint(x: cx + lx * r * 0.18, y: cy + ly * r * 0.18), startRadius: 0, endRadius: r * 0.5))

        // A drop of juice hanging from the lowest point of the lip, and one
        // aril that has rolled out over it.
        var lowest = point(0, Self.tear, 1, dx: 0, dy: 0)
        for j in 0..<n {
            let pt = point(j, Self.tear, 1, dx: 0, dy: 0)
            if pt.y > lowest.y { lowest = pt }
        }
        var drop = Path(), dropShine = Path(), loose = Path(), looseShine = Path()
        drop.oval(lowest.x, lowest.y + r * 0.13, r * 0.058, r * 0.075)
        drop.move(to: CGPoint(x: lowest.x - r * 0.025, y: lowest.y))
        drop.addLine(to: CGPoint(x: lowest.x + r * 0.025, y: lowest.y))
        drop.addLine(to: CGPoint(x: lowest.x, y: lowest.y + r * 0.1))
        drop.closeSubpath()
        dropShine.oval(lowest.x + lx * r * 0.02, lowest.y + r * 0.12 + ly * r * 0.02, r * 0.02, r * 0.026)
        let spot = frame(-a * 0.34, b * 1.12)
        loose.oval(spot.x, spot.y, r * 0.115, r * 0.105)
        looseShine.oval(spot.x + lx * r * 0.04, spot.y + ly * r * 0.04, r * 0.034, r * 0.024, atan2(ly, lx) + .pi / 2)
        let flesh = Gradient(colors: [RGB(0xFF6F82).mix(RGB(0x7C0C26), 0.5 * night).color(), RGB(0xC41A3C).mix(RGB(0x5A0A22), 0.5 * night).color(),
                                      RGB(0x8A0E2C).mix(RGB(0x3C0818), 0.4 * night).color()])
        tree.fill(drop, with: .color(RGB(0xC41A3C).mix(RGB(0x5A0A22), 0.5 * night).color(0.95)))
        tree.fill(dropShine, with: .color(Color.white.opacity(0.9)))
        tree.fill(loose, with: .radialGradient(flesh, center: CGPoint(x: spot.x + lx * r * 0.04, y: spot.y + ly * r * 0.04), startRadius: 0, endRadius: r * 0.15))
        tree.fill(looseShine, with: .color(Color.white.opacity(0.9)))
    }
}
