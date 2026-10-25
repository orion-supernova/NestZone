import SwiftUI

/// The goldfish's bowl, built once: the glass, the water at eight levels (the
/// bowl empties a little when it is thirsty), the gravel, the weed, the
/// highlights on the glass, the pool of light it throws on the floor. Only
/// the fish and the weed move, so everything here is a path to fill. The
/// same box as every pet (120 units, the floor at y = 108).
struct BowlGeometry {
    let glass: Path
    /// The water from a level down, from full (index 0) to low (index 7); each
    /// is cut from the glass the first time its level is drawn, not all eight
    /// on the first frame (`Path.intersection` is the dear part of this).
    private let cache: WaterCache
    func water(_ level: Int) -> Path { cache.water(level) }
    /// Every pebble in one path, for the single lit copy.
    let allPebbles: Path
    /// The level of each, and how wide the bowl is there.
    static let levels: [Double] = [45, 48, 51, 54, 57, 60, 63, 66]
    let halfWidths: [Double]
    let mouth: Path
    let pebbles: [Path]
    /// Highlights on the glass, on the left and on the right, and the thin
    /// bright rim of the lit side.
    let streak: [Path]
    let rimArc: [Path]
    let dots: Path
    let centre = CGPoint(x: 60, y: 69)

    init() {
        let top = 34.0
        var g = Path()
        g.move(to: CGPoint(x: 43, y: top))
        g.addCurve(to: CGPoint(x: 21.5, y: 66), control1: CGPoint(x: 31, y: top + 2), control2: CGPoint(x: 21.5, y: 48))
        g.addCurve(to: CGPoint(x: 38, y: 102.6), control1: CGPoint(x: 21.5, y: 85), control2: CGPoint(x: 28, y: 97))
        g.addCurve(to: CGPoint(x: 82, y: 102.6), control1: CGPoint(x: 48, y: 108.6), control2: CGPoint(x: 72, y: 108.6))
        g.addCurve(to: CGPoint(x: 98.5, y: 66), control1: CGPoint(x: 92, y: 97), control2: CGPoint(x: 98.5, y: 85))
        g.addCurve(to: CGPoint(x: 77, y: top), control1: CGPoint(x: 98.5, y: 48), control2: CGPoint(x: 89, y: top + 2))
        g.closeSubpath()
        glass = g
        mouth = Path(ellipseIn: CGRect(x: 43, y: top - 4.4, width: 34, height: 8.8))

        let outline = FurEdge.outline(g, step: 1.2)
        var widths: [Double] = []
        for level in Self.levels {
            let near = outline.filter { abs($0.y - level) < 1.6 }
            widths.append(((near.map(\.x).max() ?? 98) - (near.map(\.x).min() ?? 22)) / 2)
        }
        cache = WaterCache(glass: g)
        halfWidths = widths

        // Gravel: flat pebbles in three colours heaped at the bottom.
        var r = Ink.Random("bowl-gravel")
        var sand = Path(), lilac = Path(), coral = Path()
        var placed = 0
        while placed < 30 {
            let x = r.between(30, 90), y = r.between(94.5, 105.2)
            let dx = (x - 60) / 36, dy = (y - 69) / 35.5
            guard dx * dx + dy * dy < 0.86 else { continue }
            let rad = r.between(2.0, 3.6)
            let e = Path(ellipseIn: CGRect(x: x - rad, y: y - rad * 0.62, width: rad * 2, height: rad * 1.24))
            switch placed % 3 {
            case 0: sand.addPath(e)
            case 1: lilac.addPath(e)
            default: coral.addPath(e)
            }
            placed += 1
        }
        pebbles = [sand, lilac, coral]
        var every = sand
        every.addPath(lilac); every.addPath(coral)
        allPebbles = every

        // The window on the glass, a long curved bright stroke near the
        // shoulder, and a bright rim along the edge. One of each per side.
        func streakPath(_ s: Double) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 60 + s * 29, y: 46))
            p.addQuadCurve(to: CGPoint(x: 60 + s * 34.5, y: 70), control: CGPoint(x: 60 + s * 37, y: 55))
            p.addQuadCurve(to: CGPoint(x: 60 + s * 30.6, y: 70), control: CGPoint(x: 60 + s * 32.8, y: 62))
            p.addQuadCurve(to: CGPoint(x: 60 + s * 29, y: 46), control: CGPoint(x: 60 + s * 29.6, y: 55))
            p.closeSubpath()
            return p
        }
        streak = [streakPath(-1), streakPath(1)]
        func rim(_ s: Double) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 60 + s * 17.5, y: top + 0.5))
            p.addCurve(to: CGPoint(x: 60 + s * 38.2, y: 66), control1: CGPoint(x: 60 + s * 29, y: top + 3), control2: CGPoint(x: 60 + s * 38.5, y: 49))
            p.addCurve(to: CGPoint(x: 60 + s * 29, y: 96), control1: CGPoint(x: 60 + s * 38, y: 82), control2: CGPoint(x: 60 + s * 34, y: 91))
            return p
        }
        rimArc = [rim(-1), rim(1)]
        var d = Path()
        for (x, y, rad) in [(35.0, 84.0, 1.3), (39.5, 90.5, 0.8), (83.0, 88.0, 1.0)] { d.addEllipse(in: CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)) }
        dots = d
    }
}

/// The water's paths, made on demand and kept.
private final class WaterCache: @unchecked Sendable {
    private let glass: Path
    private let lock = NSLock()
    private var made: [Int: Path] = [:]
    init(glass: Path) { self.glass = glass }

    func water(_ level: Int) -> Path {
        lock.lock(); defer { lock.unlock() }
        if let kept = made[level] { return kept }
        let path = glass.intersection(Path(CGRect(x: 0, y: BowlGeometry.levels[level], width: 120, height: 120)))
        made[level] = path
        return path
    }
}

/// The fish itself, in its own space: origin at the middle of the body,
/// looking left, 29 units long without the tail.
struct FishGeometry {
    let body, belly, scales, gill, pectoral, pelvic: Path

    init() {
        body = .loop([CGPoint(x: -15.4, y: 0.6), CGPoint(x: -12.6, y: -8.2), CGPoint(x: -3.6, y: -12.6), CGPoint(x: 7.6, y: -9.6), CGPoint(x: 14.4, y: -3.2),
                      CGPoint(x: 14.4, y: 3.4), CGPoint(x: 8, y: 9.4), CGPoint(x: -3.4, y: 12.8), CGPoint(x: -12.6, y: 8.4)])
        belly = Path(ellipseIn: CGRect(x: -11, y: 2.4, width: 25, height: 9.6))
        var s = Path()
        for (row, y) in [-7.0, -2.0, 3.0, 8.0].enumerated() {
            for x in stride(from: -3.0 + (row.isMultiple(of: 2) ? 0 : 3), through: 11, by: 6) {
                s.move(to: CGPoint(x: x - 1, y: y - 2.5))
                s.addQuadCurve(to: CGPoint(x: x - 1, y: y + 2.5), control: CGPoint(x: x + 2.4, y: y))
            }
        }
        scales = s
        var g = Path()
        g.move(to: CGPoint(x: -6.4, y: -8.6))
        g.addQuadCurve(to: CGPoint(x: -6.4, y: 9), control: CGPoint(x: -1.4, y: 0.2))
        gill = g
        var pf = Path()
        pf.leaf(0, 0, 0.85, 0.5, 11, 3.4, 0.3)
        pectoral = pf
        var pv = Path()
        pv.leaf(0, 0, 0.5, 0.86, 9, 2.4, 0.3)
        pelvic = pv
    }
}

extension CritterGeometry {
    nonisolated(unsafe) private static var bowlKept: BowlGeometry?
    nonisolated(unsafe) private static var fishKept: FishGeometry?
    private static let bowlLock = NSLock()

    static var bowlArt: BowlGeometry {
        bowlLock.lock(); defer { bowlLock.unlock() }
        if let kept = bowlKept { return kept }
        let made = BowlGeometry()
        bowlKept = made
        return made
    }

    static var fishArt: FishGeometry {
        bowlLock.lock(); defer { bowlLock.unlock() }
        if let kept = fishKept { return kept }
        let made = FishGeometry()
        fishKept = made
        return made
    }
}
