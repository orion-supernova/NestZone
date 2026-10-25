import SwiftUI
import Synchronization

/// The pattern of a variegated leaf, built from the leaf's own shape once and
/// kept, as every other shape of a plant is: an albo monstera's white half or
/// tip, a Thai constellation's flecks, a cream margin. A plant with a pattern
/// draws it as one fill a tier (`LeafBatch.pale`), so a colourway is the same
/// fills as the original, and one more.
///
/// The patterns are polygons made from the leaf's edge, a few dozen points each,
/// and not boolean cuts of the outline: a cut comes back as hundreds of tiny
/// segments a leaf, and a plant redrawn while it grows moves every one of them
/// through a transform every frame (the first try cost a monstera nine times what
/// it cost before; RULES.md, section 17).
extension LeafShape {
    private static let patterns = Mutex<[Int: Path?]>([:])

    /// The pale part of this leaf for a pattern, or `nil` where this leaf is
    /// plain (a variegated plant is not marked on every leaf). `variant` says
    /// which of five marks this leaf has.
    func variegation(_ pattern: PlantPlan.Variegation.Pattern, variant: Int) -> Path? {
        let step = Int((max(-1.2, min(1.2, bend)) / 0.15).rounded())
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

    private func make(_ pattern: PlantPlan.Variegation.Pattern, _ variant: Int) -> Path? {
        switch pattern {
        case .albo:
            // Half a leaf white (a half-moon), or just its tip, one side or the other.
            switch variant {
            case 0: return sideA
            case 1: return sideB
            case 2, 3:
                let sign = variant == 2 ? 1.0 : -1.0
                // From 0.7 out, past the holes of a monstera, which are all nearer the base.
                let outer = edgePts.filter { $0.x >= 0.7 }.map { place($0.x, sign * $0.y) }
                let rib = (0...5).map { centre(1 - Double($0) / 5 * 0.3) }
                return outer.count > 2 ? Self.polygon(outer + rib) : nil
            default: return nil
            }
        case .flecks:
            // A scatter of small cream dots, each a hexagon wholly inside the leaf.
            guard variant < 4 else { return nil }
            var r = Ink.Random(seed: UInt32(truncatingIfNeeded: kind.rawValue * 31 + variant + 7))
            var dots = Path()
            var placed = 0, tries = 0
            while placed < 16 && tries < 90 {
                tries += 1
                let u = 0.12 + 0.82 * r.next(), v = (r.next() * 2 - 1) * 0.42 * min(1, 0.5 + u)
                let rad = (0.008 + 0.012 * r.next()) * (placed % 6 == 0 ? 1.7 : 1)
                let probes = [CGPoint(x: u, y: v), CGPoint(x: u + rad * 1.4, y: v), CGPoint(x: u - rad * 1.4, y: v),
                              CGPoint(x: u, y: v + rad * 1.4), CGPoint(x: u, y: v - rad * 1.4)]
                guard probes.allSatisfy({ outline.contains($0, eoFill: true) }) else { continue }
                let hex = (0..<6).map { k -> CGPoint in
                    let a = Double(k) / 6 * 2 * .pi
                    return place(u + cos(a) * rad, v + sin(a) * rad * 0.9)
                }
                dots.addLines(hex)
                dots.closeSubpath()
                placed += 1
            }
            return placed > 0 ? dots : nil
        case .margin:
            // A band along the edge of each half, a third of the way in.
            guard variant < 4 else { return nil }
            var band = Path()
            for sign in [1.0, -1.0] {
                let edge = edgePts.enumerated().filter { $0.element.x > 0.05 && $0.element.x < 0.97 && $0.element.y > 0.02 && $0.offset % 2 == 0 }.map(\.element)
                guard edge.count > 2 else { continue }
                let outer = edge.map { place($0.x, sign * $0.y) }
                let inner = edge.map { place($0.x, sign * $0.y * 0.66) }
                band.addPath(Self.polygon(outer + inner.reversed()))
            }
            return band.isEmpty ? nil : band
        }
    }
}
