import SwiftUI
import Synchronization

/// A leaf or a petal worked out once in its own units (its base the origin, its
/// tip at (1, 0), the side it widens to +y) and kept, the way `ClumpArt` keeps
/// a clump of the pomegranate: a plant is then a transform and an `addPath` per
/// leaf into a few merged paths, not a few hundred outlines built again. The
/// bend (how far the leaf curls, in steps of 0.15) is part of the key, so a
/// thirsty plant's curled leaves are cached too.
///
/// Everything a leaf needs is a *fill*: the outline, its two halves (the one
/// that faces the light gets the lighter tone), the veins as thin triangles,
/// a strip of light on each edge and a glint, so a leaf costs nothing a stroke
/// would (RULES.md section 8).
struct LeafShape: Sendable {
    enum Kind: Int, CaseIterable, Sendable {
        case heart, ovate, strap, spoon, leaflet, lobed
        /// Round B: a mint leaf (a puckered, toothed oval), an orchid's thick
        /// broad leaf, a pumpkin's palmate leaf and a fern's pinna.
        case mint, broad, palmate, pinna, needle
        /// Petals: a long narrow ray, a broad rounded one, a pointed tepal.
        case ray, petal, tepal, rose
        /// A monstera leaf by how grown it is: a whole heart, then slit, then holed.
        case monstera0, monstera1, monstera2, monstera3
    }

    var outline = Path()
    /// The two halves either side of the midrib, both wound the same way so
    /// that merging them never leaves a hole where two overlap.
    var sideA = Path(), sideB = Path()
    var veins = Path()
    var glossA = Path(), glossB = Path()
    var rimA = Path(), rimB = Path()
    /// The broad margin of a petal that rolls back (a rose's), and the thin
    /// shade where the roll meets the petal.
    var rollA = Path(), rollB = Path()
    var foldA = Path(), foldB = Path()
    var tip = CGPoint(x: 1, y: 0)
    /// Whether the outline has holes in it (a monstera), and wants an even-odd fill.
    var holes = false

    private static let cache = Mutex<[Int: LeafShape]>([:])

    static func of(_ kind: Kind, bend: Double = 0) -> LeafShape {
        let step = Int((max(-1.2, min(1.2, bend)) / 0.15).rounded())
        let key = kind.rawValue * 100 + step + 50
        return cache.withLock { cache in
            if let found = cache[key] { return found }
            let made = LeafShape(kind, bend: Double(step) * 0.15)
            cache[key] = made
            return made
        }
    }

    // MARK: Building

    private struct Spec {
        var edge: [CGPoint]
        var teeth = 0.0
        var tooth = 3
        var veinsAt: [Double] = []
        var parallel: [Double] = []
        var rib = 0.016
        var slits: [(s: Double, depth: Double)] = []
        var holes: [(u: Double, v: Double, rx: Double, ry: Double)] = []
        var ruffle = 0.0
        /// Veins that fan out from near the base: angle from the rib and length.
        var fan: [(angle: Double, length: Double)] = []
    }

    private static func pts(_ list: [(Double, Double)]) -> [CGPoint] { list.map { CGPoint(x: $0.0, y: $0.1) } }

    private static func spec(_ kind: Kind) -> Spec {
        switch kind {
        case .heart:
            return Spec(edge: pts([(0.05, 0), (-0.02, 0.07), (-0.06, 0.2), (-0.02, 0.34), (0.08, 0.44), (0.22, 0.5), (0.38, 0.5),
                                   (0.54, 0.43), (0.7, 0.3), (0.85, 0.15), (0.95, 0.05), (1, 0)]),
                        teeth: 0.011, veinsAt: [0.05, 0.2, 0.38, 0.56], rib: 0.02)
        case .ovate:
            return Spec(edge: pts([(0, 0), (0.03, 0.1), (0.12, 0.27), (0.28, 0.4), (0.46, 0.44), (0.64, 0.36), (0.8, 0.22), (0.93, 0.09), (1, 0)]),
                        teeth: 0.006, veinsAt: [0.1, 0.26, 0.44, 0.62], rib: 0.022)
        case .strap:
            return Spec(edge: pts([(0, 0.05), (0.1, 0.1), (0.3, 0.125), (0.55, 0.12), (0.8, 0.075), (0.94, 0.03), (1, 0)]),
                        parallel: [0.035, 0.075], rib: 0.012)
        case .lobed:
            // A peony's: an oval cut by deep slits into lobes.
            return Spec(edge: pts([(0, 0), (0.02, 0.14), (0.1, 0.34), (0.26, 0.5), (0.46, 0.54), (0.66, 0.44), (0.84, 0.26), (0.95, 0.1), (1, 0)]),
                        teeth: 0.007, veinsAt: [0.1, 0.28, 0.46, 0.64], rib: 0.02, slits: [(0.14, 0.82), (0.3, 0.88), (0.46, 0.88), (0.62, 0.8), (0.78, 0.6)])
        case .spoon:
            return Spec(edge: pts([(0, 0.02), (0.12, 0.05), (0.3, 0.12), (0.52, 0.2), (0.72, 0.22), (0.88, 0.16), (0.97, 0.07), (1, 0)]),
                        teeth: 0.016, tooth: 4, veinsAt: [0.4, 0.58], rib: 0.026)
        case .leaflet:
            return Spec(edge: pts([(0, 0), (0.05, 0.12), (0.2, 0.3), (0.42, 0.38), (0.64, 0.31), (0.82, 0.17), (0.94, 0.06), (1, 0)]),
                        teeth: 0.017, tooth: 2, veinsAt: [0.18, 0.36, 0.54, 0.7], rib: 0.026)
        case .ray:
            return Spec(edge: pts([(0, 0.035), (0.14, 0.11), (0.5, 0.15), (0.82, 0.12), (0.97, 0.05), (1, 0)]), rib: 0.02)
        case .petal:
            return Spec(edge: pts([(0, 0.05), (0.08, 0.26), (0.32, 0.46), (0.68, 0.5), (0.92, 0.34), (1, 0.12), (1.02, 0)]), rib: 0.014, ruffle: 0.018)
        case .rose:
            return Spec(edge: pts([(0, 0.04), (0.1, 0.28), (0.35, 0.48), (0.7, 0.5), (0.93, 0.34), (1, 0.12), (1.02, 0)]), rib: 0.012)
        case .tepal:
            return Spec(edge: pts([(0, 0.1), (0.14, 0.3), (0.42, 0.4), (0.76, 0.3), (0.95, 0.11), (1, 0)]), rib: 0.012)
        case .mint:
            return Spec(edge: pts([(0.03, 0), (-0.01, 0.1), (0.04, 0.26), (0.2, 0.4), (0.42, 0.46), (0.64, 0.38), (0.82, 0.22), (0.94, 0.08), (1, 0)]),
                        teeth: 0.02, tooth: 2, veinsAt: [0.08, 0.2, 0.32, 0.44, 0.56, 0.68], rib: 0.026)
        case .broad:
            return Spec(edge: pts([(0, 0.05), (0.08, 0.15), (0.3, 0.22), (0.6, 0.235), (0.86, 0.18), (0.97, 0.09), (1, 0)]),
                        parallel: [0.05, 0.1, 0.16], rib: 0.026)
        case .needle:
            return Spec(edge: pts([(0, 0.025), (0.2, 0.052), (0.6, 0.05), (0.9, 0.03), (1, 0)]), rib: 0.012)
        case .palmate:
            return Spec(edge: pts([(0.14, 0), (0.02, 0.08), (-0.08, 0.24), (-0.05, 0.4), (0.0, 0.46), (0.1, 0.38), (0.14, 0.3), (0.24, 0.42), (0.36, 0.6),
                                   (0.46, 0.66), (0.56, 0.58), (0.66, 0.36), (0.72, 0.26), (0.82, 0.24), (0.94, 0.1), (1, 0)]),
                        teeth: 0.01, tooth: 2, rib: 0.026, fan: [(0, 0.88), (1.0, 0.74), (1.9, 0.4)])
        case .pinna:
            // Small enough that a tooth is under a pixel: none, and fewer points.
            return Spec(edge: pts([(0, 0.07), (0.15, 0.17), (0.5, 0.2), (0.8, 0.13), (0.95, 0.05), (1, 0)]), rib: 0.03)
        case .monstera0:
            return monstera(slits: [], holes: [])
        case .monstera1:
            return monstera(slits: [(0.46, 0.26), (0.58, 0.32), (0.7, 0.3)],
                            holes: [(0.3, 0.2, 0.014, 0.03), (0.5, 0.18, 0.012, 0.026)])
        case .monstera2:
            return monstera(slits: [(0.32, 0.4), (0.43, 0.52), (0.54, 0.56), (0.65, 0.54), (0.76, 0.46)],
                            holes: [(0.26, 0.24, 0.02, 0.046), (0.4, 0.22, 0.018, 0.04), (0.55, 0.2, 0.016, 0.034)])
        default:
            return monstera(slits: [(0.27, 0.46), (0.37, 0.6), (0.47, 0.66), (0.57, 0.68), (0.67, 0.64), (0.77, 0.54), (0.86, 0.4)],
                            holes: [(0.24, 0.26, 0.022, 0.05), (0.38, 0.24, 0.02, 0.046), (0.52, 0.22, 0.018, 0.04), (0.65, 0.2, 0.014, 0.03)])
        }
    }

    private static func monstera(slits: [(s: Double, depth: Double)], holes: [(u: Double, v: Double, rx: Double, ry: Double)]) -> Spec {
        Spec(edge: pts([(0.06, 0), (-0.04, 0.1), (-0.1, 0.26), (-0.06, 0.42), (0.06, 0.52), (0.24, 0.57), (0.42, 0.53),
                        (0.6, 0.43), (0.78, 0.27), (0.92, 0.1), (1, 0)]),
             veinsAt: [0.1, 0.24, 0.38, 0.52, 0.66], rib: 0.022, slits: slits, holes: holes)
    }

    /// The edge as a dense polyline through the hand-placed points
    /// (Catmull-Rom), with each point's place along it, 0...1.
    private static func dense(_ edge: [CGPoint], steps: Int) -> [(p: CGPoint, s: Double)] {
        var out: [(CGPoint, Double)] = []
        let n = edge.count
        for i in 0..<(n - 1) {
            let p0 = edge[max(0, i - 1)], p1 = edge[i], p2 = edge[i + 1], p3 = edge[min(n - 1, i + 2)]
            for k in 0..<steps {
                let t = Double(k) / Double(steps), t2 = t * t, t3 = t2 * t
                let x = 0.5 * (2 * p1.x + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
                let y = 0.5 * (2 * p1.y + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
                out.append((CGPoint(x: x, y: y), (Double(i) + t) / Double(n - 1)))
            }
        }
        out.append((edge[n - 1], 1))
        return out
    }

    private static func area(_ points: [CGPoint]) -> Double {
        var a = 0.0
        for i in 0..<points.count {
            let p = points[i], q = points[(i + 1) % points.count]
            a += p.x * q.y - q.x * p.y
        }
        return a
    }

    /// A closed polygon, wound the one way whatever order it was given in.
    private static func poly(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 2 else { return path }
        let list = area(points) < 0 ? Array(points.reversed()) : points
        path.addLines(list)
        path.closeSubpath()
        return path
    }

    /// A thin triangle from `a`, `width` across there, to a point at `b`.
    private static func tri(_ path: inout Path, _ a: CGPoint, _ b: CGPoint, _ width: Double) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(1e-6, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len * width / 2, ny = dx / len * width / 2
        path.addLines([CGPoint(x: a.x + nx, y: a.y + ny), b, CGPoint(x: a.x - nx, y: a.y - ny)])
        path.closeSubpath()
    }

    private init(_ kind: Kind, bend: Double) {
        let spec = Self.spec(kind)
        // Slits and ruffles need their points close; a plain leaf at card size does not.
        let fine: Bool
        switch kind {
        case .monstera0, .monstera1, .monstera2, .monstera3, .lobed, .petal, .palmate: fine = true
        default: fine = false
        }
        var edge = Self.dense(spec.edge, steps: fine ? 9 : (kind == .pinna || kind == .needle ? 3 : 5))

        // Serration and ruffle ride the edge, and a monstera's slits cut into it.
        for i in 0..<edge.count {
            var (p, s) = edge[i]
            if spec.teeth > 0, s > 0.04, s < 0.97 {
                p.y += (i / spec.tooth).isMultiple(of: 2) ? spec.teeth : -spec.teeth * 0.4
            }
            if spec.ruffle > 0 { p.y += spec.ruffle * sin(s * 30) * (s > 0.5 ? 1 : 0.4) }
            for slit in spec.slits {
                // A slit rises slowly from the margin and returns quickly, so it
                // is swept towards the tip as a real one is.
                let a = 0.02, b = 0.006
                var d = 0.0
                if s >= slit.s, s < slit.s + a { d = (s - slit.s) / a }
                else if s >= slit.s + a, s < slit.s + a + b { d = 1 - (s - slit.s - a) / b }
                if d > 0 {
                    p.y *= 1 - slit.depth * d
                    // Slits run along the veins: the inner end is nearer the base than the margin.
                    p.x -= slit.depth * d * 0.13
                }
            }
            edge[i] = (p, s)
        }

        func centre(_ u: Double) -> CGPoint {
            guard abs(bend) > 0.01 else { return CGPoint(x: u, y: 0) }
            let phi = bend * u
            return CGPoint(x: sin(phi) / bend, y: (1 - cos(phi)) / bend)
        }
        func place(_ u: Double, _ v: Double) -> CGPoint {
            guard abs(bend) > 0.01 else { return CGPoint(x: u, y: v) }
            let phi = bend * u, c = centre(u)
            return CGPoint(x: c.x - sin(phi) * v, y: c.y + cos(phi) * v)
        }

        let a = edge.map { place($0.p.x, $0.p.y) }
        let b = edge.map { place($0.p.x, -$0.p.y) }
        let rib = (0...16).map { centre(Double($0) / 16) }
        tip = centre(1)

        var out = Path()
        out.addPath(Self.poly(a + b.reversed()))
        // The two halves: the edge on one side and the rib.
        sideA = Self.poly(a + rib.reversed())
        sideB = Self.poly(b + rib.reversed())

        // Holes of a monstera, in whichever half they fall, cut by even-odd.
        if !spec.holes.isEmpty {
            holes = true
            for h in spec.holes {
                for sign in [1.0, -1.0] {
                    var hole = Path()
                    hole.addEllipse(in: CGRect(x: -h.rx, y: -h.ry, width: h.rx * 2, height: h.ry * 2))
                    let rot = sign * 0.9 - 0.2 * bend
                    let c = place(h.u, sign * h.v)
                    let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: rot)
                    out.addPath(hole, transform: t)
                    if sign > 0 { sideA.addPath(hole, transform: t) } else { sideB.addPath(hole, transform: t) }
                }
            }
        }
        outline = out

        // Veins: the midrib, then pairs sweeping out and forward.
        var veins = Path()
        let left = (0...12).map { i -> CGPoint in let u = Double(i) / 12 * 0.94; return place(u, spec.rib * (1 - 0.7 * u)) }
        let right = (0...12).map { i -> CGPoint in let u = Double(i) / 12 * 0.94; return place(u, -spec.rib * (1 - 0.7 * u)) }
        veins.addPath(Self.poly(left + right.reversed()))
        for u in spec.veinsAt {
            // Where the vein ends: the edge a little further along, drawn in a bit.
            let target = edge.filter { $0.p.y > 0.05 && $0.s > 0.02 }.min { abs($0.p.x - (u + 0.15)) < abs($1.p.x - (u + 0.15)) }?.p ?? CGPoint(x: u + 0.15, y: 0.2)
            for sign in [1.0, -1.0] {
                let from = centre(u)
                let end = place(Ink.lerp(u, target.x, 0.88), sign * target.y * 0.86)
                Self.tri(&veins, from, end, spec.rib * 0.62)
            }
        }
        for v in spec.parallel {
            for sign in [1.0, -1.0] {
                Self.tri(&veins, place(0.04, sign * v), place(0.92, sign * v * 0.35), 0.008)
            }
        }
        for f in spec.fan {
            for sign in [1.0, -1.0] {
                let from = place(0.1, 0)
                let to = CGPoint(x: 0.1 + cos(f.angle) * f.length, y: sign * sin(f.angle) * f.length)
                Self.tri(&veins, from, place(to.x, to.y), spec.rib * 0.8)
            }
        }
        self.veins = veins

        // A strip of light along the edge of each half, and a glint beside the rib.
        let inset: (Double) -> Double = { 0.9 - 0.12 * $0 }
        func strip(_ sign: Double, from: Double = 0.12, to: Double = 0.9, outer scale: (Double) -> Double = { _ in 1 }, _ inset: (Double) -> Double) -> Path {
            let lo = edge.filter { $0.s > from && $0.s < to }
            let outer = lo.map { place($0.p.x, sign * $0.p.y * scale($0.s)) }
            let inner = lo.map { place($0.p.x, sign * $0.p.y * inset($0.s)) }
            return Self.poly(outer + inner.reversed())
        }
        rimA = strip(1, inset)
        rimB = strip(-1, inset)
        if kind == .rose {
            // A rolled margin: broad, over most of the petal's edge.
            let roll: (Double) -> Double = { 0.74 - 0.08 * $0 }
            rollA = strip(1, from: 0.2, to: 0.97, roll)
            rollB = strip(-1, from: 0.2, to: 0.97, roll)
            // Where the roll meets the petal: a thin line of shade just inside it.
            let atRoll: (Double) -> Double = { 0.74 - 0.08 * $0 }
            let inside: (Double) -> Double = { _ in 0.88 }
            foldA = strip(1, from: 0.24, to: 0.94, outer: atRoll, inside)
            foldB = strip(-1, from: 0.24, to: 0.94, outer: atRoll, inside)
        }
        func glint(_ sign: Double) -> Path {
            var path = Path()
            let p0 = place(0.2, sign * 0.07), p1 = place(0.62, sign * 0.1)
            let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            path.addLines([p0, CGPoint(x: mid.x, y: mid.y - sign * 0.02), p1, CGPoint(x: mid.x, y: mid.y + sign * 0.012)])
            path.closeSubpath()
            return path
        }
        glossA = glint(1)
        glossB = glint(-1)
    }
}

// MARK: - Batching

/// Leaves gathered by tone so a tier of a plant is a few fills, however many
/// leaves it has: the three classes of green, the half of each leaf that
/// faces the light, the veins, the edge light and the glints, and one shadow
/// for the lot.
struct LeafBatch {
    var shade = Path(), mid = Path(), lit = Path()
    var halves = Path(), veins = Path(), rim = Path(), gloss = Path()
    var shadow = Path(), stalks = Path()

    /// A leaf with its base at `base`, pointing along `angle` and `length` long.
    /// `bright` 0...1 says which class of green it is; `L` is the light.
    mutating func add(_ shape: LeafShape, base: CGPoint, angle: Double, length: Double, light L: (x: Double, y: Double),
                      bright: Double, glossy: Bool = false, shadowed: Bool = true) {
        let t = CGAffineTransform(translationX: base.x, y: base.y).rotated(by: angle).scaledBy(x: length, y: length)
        if bright < 0.36 { shade.addPath(shape.outline, transform: t) }
        else if bright < 0.68 { mid.addPath(shape.outline, transform: t) }
        else { lit.addPath(shape.outline, transform: t) }
        // The half whose side of the midrib looks at the light.
        let across = -sin(angle) * L.x + cos(angle) * L.y
        let litA = across >= 0
        halves.addPath(litA ? shape.sideA : shape.sideB, transform: t)
        veins.addPath(shape.veins, transform: t)
        if bright > 0.4 { rim.addPath(litA ? shape.rimA : shape.rimB, transform: t) }
        if glossy && bright > 0.5 { gloss.addPath(litA ? shape.glossA : shape.glossB, transform: t) }
        if shadowed { shadow.addPath(shape.outline, transform: t.concatenating(CGAffineTransform(translationX: 0.8, y: 1.3))) }
    }

    /// A small leaf (a pinna, a needle cluster): its outline in its class, the
    /// lit half and, if asked, a shadow; no veins, rim or glint, which at that
    /// size nobody sees and which cost a path each.
    mutating func addLite(_ shape: LeafShape, base: CGPoint, angle: Double, length: Double, light L: (x: Double, y: Double),
                          bright: Double, shadowed: Bool = false, lightHalf: Bool = true) {
        let t = CGAffineTransform(translationX: base.x, y: base.y).rotated(by: angle).scaledBy(x: length, y: length)
        if bright < 0.36 { shade.addPath(shape.outline, transform: t) }
        else if bright < 0.68 { mid.addPath(shape.outline, transform: t) }
        else { lit.addPath(shape.outline, transform: t) }
        if lightHalf {
            let across = -sin(angle) * L.x + cos(angle) * L.y
            halves.addPath(across >= 0 ? shape.sideA : shape.sideB, transform: t)
        }
        if shadowed { shadow.addPath(shape.outline, transform: t.concatenating(CGAffineTransform(translationX: 0.8, y: 1.3))) }
    }

    /// Draws the batch back to front. `holes` leaves are drawn with an even-odd
    /// fill, so a batch of those holds one leaf.
    func flush(_ c: GraphicsContext, _ ink: PlantPainter.LeafInk, holes: Bool = false, casting: Bool = true) {
        let rule = FillStyle(eoFill: holes)
        if casting, !shadow.isEmpty { c.fill(shadow, with: .color(ink.shadow), style: rule) }
        if !stalks.isEmpty { c.fill(stalks, with: .color(ink.stalk)) }
        if !shade.isEmpty { c.fill(shade, with: .color(ink.d), style: rule) }
        if !mid.isEmpty { c.fill(mid, with: .color(ink.m), style: rule) }
        if !lit.isEmpty { c.fill(lit, with: .color(ink.l), style: rule) }
        if !halves.isEmpty { c.fill(halves, with: .color(ink.half), style: rule) }
        if !veins.isEmpty { c.fill(veins, with: .color(ink.vein)) }
        if !rim.isEmpty { c.fill(rim, with: .color(ink.rim)) }
        if !gloss.isEmpty { c.fill(gloss, with: .color(ink.gloss)) }
    }
}

extension Path {
    /// A thin triangle from `a`, `width` across there, to a point at `b`: a
    /// spine, a hair, a thorn or a vein, which costs a fill and not a stroke.
    mutating func spike(from a: CGPoint, to b: CGPoint, width: Double) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(1e-6, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len * width / 2, ny = dx / len * width / 2
        addLines([CGPoint(x: a.x + nx, y: a.y + ny), b, CGPoint(x: a.x - nx, y: a.y - ny)])
        closeSubpath()
    }

    /// A lens: pointed at both ends, `width` across at the middle.
    mutating func lens(from a: CGPoint, to b: CGPoint, width: Double, lean: Double = 0) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(1e-6, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len, ny = dx / len
        let m = CGPoint(x: (a.x + b.x) / 2 + nx * lean, y: (a.y + b.y) / 2 + ny * lean)
        move(to: a)
        addQuadCurve(to: b, control: CGPoint(x: m.x + nx * width, y: m.y + ny * width))
        addQuadCurve(to: a, control: CGPoint(x: m.x - nx * width, y: m.y - ny * width))
        closeSubpath()
    }
}
