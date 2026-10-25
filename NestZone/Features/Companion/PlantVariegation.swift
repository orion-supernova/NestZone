import SwiftUI
import Synchronization

/// What a variegated leaf is marked with: the pale part, and for a margin the
/// soft edge inside it.
struct LeafVariegation: Sendable {
    var hard: Path
    var soft = Path()
}

/// The pattern of a variegated leaf, built from the leaf's own shape once and
/// kept, as every other shape of a plant is: an albo monstera's white sector, a
/// Thai constellation's flecks, a cream margin. A plant with a pattern draws it
/// as a fill or two a tier (`LeafBatch.pale`), so a colourway is the same fills as
/// the original, and one or two more.
///
/// The patterns are polygons made from the leaf's edge, a few dozen points each,
/// and not boolean cuts of the outline: a cut comes back as hundreds of tiny
/// segments a leaf, and a plant redrawn while it grows moves every one of them
/// through a transform every frame (the first try cost a monstera nine times what
/// it cost before; RULES.md, section 17).
extension LeafShape {
    private static let patterns = Mutex<[Int: LeafVariegation?]>([:])

    /// The pattern for this leaf, or `nil` where it is plain (a variegated plant
    /// is not marked on every leaf). `variant` says which of five marks this leaf has.
    func variegation(_ pattern: PlantPlan.Variegation.Pattern, variant: Int) -> LeafVariegation? {
        let step = Int((max(-1.2, min(1.2, bend)) / 0.15).rounded())
        // A margin is the same on every leaf.
        let variant = pattern == .margin ? 0 : variant
        let key = ((kind.rawValue * 100 + step + 50) * 4 + pattern.rawValue) * 8 + variant
        return Self.patterns.withLock { cache in
            if let found = cache[key] { return found }
            let made = make(pattern, variant)
            cache[key] = made
            return made
        }
    }

    private func centre(_ u: Double) -> CGPoint {
        guard abs(bend) > 0.01 else { return CGPoint(x: u, y: 0) }
        return CGPoint(x: sin(bend * u) / bend, y: (1 - cos(bend * u)) / bend)
    }

    private func place(_ u: Double, _ v: Double) -> CGPoint {
        guard abs(bend) > 0.01 else { return CGPoint(x: u, y: v) }
        let phi = bend * u, c = centre(u)
        return CGPoint(x: c.x - sin(phi) * v, y: c.y + cos(phi) * v)
    }

    /// A closed polygon, wound the one way whatever order it was given in.
    private static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 2 else { return path }
        var area = 0.0
        for i in 0..<points.count {
            let p = points[i], q = points[(i + 1) % points.count]
            area += p.x * q.y - q.x * p.y
        }
        path.addLines(area < 0 ? Array(points.reversed()) : points)
        path.closeSubpath()
        return path
    }

    /// A small hexagon at (u, v), `rad` across, bent with the leaf.
    private func hexagon(_ u: Double, _ v: Double, _ rad: Double) -> Path {
        let hex = (0..<6).map { k -> CGPoint in
            let a = Double(k) / 6 * 2 * .pi
            return place(u + cos(a) * rad, v + sin(a) * rad * 0.9)
        }
        return Self.polygon(hex)
    }

    private func inside(_ u: Double, _ v: Double, _ rad: Double) -> Bool {
        [CGPoint(x: u, y: v), CGPoint(x: u + rad * 1.4, y: v), CGPoint(x: u - rad * 1.4, y: v),
         CGPoint(x: u, y: v + rad * 1.4), CGPoint(x: u, y: v - rad * 1.4)].allSatisfy { outline.contains($0, eoFill: true) }
    }

    private func make(_ pattern: PlantPlan.Variegation.Pattern, _ variant: Int) -> LeafVariegation? {
        switch pattern {
        case .albo:
            switch variant {
            case 0, 1: return sector(sign: variant == 0 ? 1 : -1, from: 0.04, variant)
            case 2, 3: return sector(sign: variant == 2 ? 1 : -1, from: 0.42, variant)
            default: return marbled(variant)
            }
        case .flecks: return flecks(variant)
        case .margin: return margin()
        }
    }

    // MARK: An albo's sector

    /// White over one side of the leaf, from `u0` out to the tip, and not a clean
    /// cut: the green comes into it as streaks along the veins, forward-swept,
    /// of different depths, and the white runs up to the rib in between; a few
    /// green flecks lie in the white and a few white ones in the green beside it
    /// (marbling). Every point is the leaf's own edge or a jitter off the rib.
    private func sector(sign: Double, from u0: Double, _ variant: Int) -> LeafVariegation? {
        var r = Ink.Random(seed: UInt32(truncatingIfNeeded: kind.rawValue * 977 + variant * 131 + 11))
        let outer = edgePts.filter { $0.x >= u0 && $0.y > 0.004 }.map { place($0.x, sign * $0.y) }
        guard outer.count > 3 else { return nil }
        // The side towards the rib, from the tip back to the start: between the streaks the
        // white reaches the rib; each streak is a thin wedge of green swept along its vein.
        var inner: [CGPoint] = [place(1, sign * 0.004)]
        var u = 0.9
        while u > u0 + 0.08 {
            let base = r.between(0.0, 0.05)
            let window = edgePts.filter { abs($0.x - (u + 0.05)) < 0.07 && $0.y > 0.01 }.map(\.y)
            let reach = (window.min() ?? 0.2) * r.between(0.4, 0.86)
            inner.append(place(u + 0.035, sign * base))
            inner.append(place(u + 0.05 + r.between(-0.012, 0.016), sign * reach))
            inner.append(place(u - 0.018, sign * base))
            u -= r.between(0.085, 0.115)
        }
        // Where a tip sector starts: a ragged line, not a chord.
        if u0 > 0.2 {
            inner.append(place(u0 + 0.06, sign * r.between(0.02, 0.06)))
            inner.append(place(u0 + 0.02, sign * (edgePts.filter { abs($0.x - u0) < 0.05 && $0.y > 0.01 }.map(\.y).min() ?? 0.2) * 0.4))
        }
        let white = Self.polygon(outer + inner)
        var path = white
        // The holes of a monstera that lie in the white stay open.
        for part in holeParts where part.side == sign {
            let box = part.path.boundingRect
            if white.contains(CGPoint(x: box.midX, y: box.midY), eoFill: true) { path.addPath(part.path) }
        }
        // Marbling: green in the white and white in the green, each a hexagon wholly in the leaf.
        var greens = 0, whites = 0, tries = 0
        while (greens < 3 || whites < 3) && tries < 120 {
            tries += 1
            let fu = u0 + 0.08 + (0.95 - u0 - 0.08) * r.next(), fv = sign * r.between(0.05, 0.42) * min(1, 0.4 + fu)
            let rad = r.between(0.009, 0.02)
            guard inside(fu, fv, rad) else { continue }
            let p = place(fu, fv)
            let inWhite = white.contains(p, eoFill: true)
            if inWhite, greens < 3 { path.addPath(hexagon(fu, fv, rad)); greens += 1 }
            else if !inWhite, whites < 3 { path.addPath(hexagon(fu, fv, rad)); whites += 1 }
        }
        return LeafVariegation(hard: path)
    }

    /// A leaf that is green and marbled: white flecks of two sizes and a few streaks of white along its veins.
    private func marbled(_ variant: Int) -> LeafVariegation? {
        var r = Ink.Random(seed: UInt32(truncatingIfNeeded: kind.rawValue * 613 + variant + 3))
        var path = Path()
        var placed = 0, tries = 0
        while placed < 12 && tries < 100 {
            tries += 1
            let u = 0.12 + 0.8 * r.next(), v = (r.next() * 2 - 1) * 0.4 * min(1, 0.5 + u)
            let rad = (0.01 + 0.016 * r.next()) * (placed % 4 == 0 ? 1.6 : 1)
            guard inside(u, v, rad) else { continue }
            path.addPath(hexagon(u, v, rad))
            placed += 1
        }
        return placed > 0 ? LeafVariegation(hard: path) : nil
    }

    // MARK: Flecks

    /// A scatter of small cream dots, each a hexagon wholly inside the leaf.
    private func flecks(_ variant: Int) -> LeafVariegation? {
        guard variant < 4 else { return nil }
        var r = Ink.Random(seed: UInt32(truncatingIfNeeded: kind.rawValue * 31 + variant + 7))
        var dots = Path()
        var placed = 0, tries = 0
        while placed < 16 && tries < 90 {
            tries += 1
            let u = 0.12 + 0.82 * r.next(), v = (r.next() * 2 - 1) * 0.42 * min(1, 0.5 + u)
            let rad = (0.008 + 0.012 * r.next()) * (placed % 6 == 0 ? 1.7 : 1)
            guard inside(u, v, rad) else { continue }
            dots.addPath(hexagon(u, v, rad))
            placed += 1
        }
        return placed > 0 ? LeafVariegation(hard: dots) : nil
    }

    // MARK: A margin

    /// A neat rim: a band of one width all the way round the leaf, from its
    /// edge in by a constant `inset` along the edge's own normal (the edge is
    /// smoothed first, so a toothed leaf does not make a ragged band), and
    /// inside it a second, narrower band that is drawn half as strong, so the
    /// inner boundary is soft. The band ends where the leaf is too narrow to hold it.
    private func margin() -> LeafVariegation? {
        let inset = 0.05, soft = 0.04
        var hard = Path(), fade = Path()
        for sign in [1.0, -1.0] {
            let raw = edgePts.filter { $0.x > 0.04 && $0.x < 0.97 && $0.y > 0.035 }
            guard raw.count > 6 else { continue }
            // Smoothed, every third point.
            let smooth = raw.indices.map { i -> CGPoint in
                let a = raw[max(0, i - 2)], b = raw[i], c = raw[min(raw.count - 1, i + 2)]
                return CGPoint(x: (a.x + b.x + c.x) / 3, y: (a.y + b.y + c.y) / 3)
            }
            var outer: [CGPoint] = [], mid: [CGPoint] = [], inner: [CGPoint] = []
            for i in stride(from: 0, to: raw.count, by: 3) {
                let a = smooth[max(0, i - 2)], b = smooth[min(raw.count - 1, i + 2)]
                let tx = b.x - a.x, ty = b.y - a.y, len = max(1e-6, (tx * tx + ty * ty).squareRoot())
                // Inwards: to the right of the way the edge runs, base to tip, on the upper side.
                let nx = ty / len, ny = -tx / len
                let p = raw[i]
                guard p.y > inset * 1.5 else { continue }
                outer.append(place(p.x, sign * p.y))
                mid.append(place(p.x + nx * inset, sign * max(0.012, p.y + ny * inset)))
                inner.append(place(p.x + nx * (inset + soft), sign * max(0.012, p.y + ny * (inset + soft))))
            }
            guard outer.count > 3 else { continue }
            hard.addPath(Self.polygon(outer + mid.reversed()))
            fade.addPath(Self.polygon(mid + inner.reversed()))
        }
        return hard.isEmpty ? nil : LeafVariegation(hard: hard, soft: fade)
    }
}
