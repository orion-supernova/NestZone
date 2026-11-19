import SwiftUI
import Synchronization

/// One clump's blossoms, worked out once in the clump's own units and sorted by
/// the light into classes, exactly as `ClumpArt` holds its leaves. A tree that
/// is covered in flowers (a cherry in bloom, an azalea) paints them over its
/// leaves; a redraw is then a translate, a scale and a few fills per clump.
struct ClumpBloom: Sendable {
    var d = Path(), m = Path(), l = Path(), s = Path()
    /// The heart of each flower: a sakura's red eye, an azalea's throat.
    var hearts = Path()
    /// The same on the sunlit flowers, where it is a deeper mark and not a pale one.
    var heartsLit = Path()
    /// A sakura's notch at each petal tip; an azalea's spots in the throat.
    var spots = Path()
    /// Stamens and their anthers, on the sunlit flowers only.
    var fine = Path()
    /// The same places, before they open: small pointed buds.
    var buds = Path()
    /// Every flower, whatever its class: the shade that parts each from the next.
    var all = Path()
    var count = 0
    /// Where each cluster is centred, where each flower sits, and the thin
    /// stalks from a cluster's middle to its flowers (a path to fill, and the
    /// same as segments for the attach audit), all in the clump's units.
    var hubs: [CGPoint] = []
    var sites: [CGPoint] = []
    var prongs = Path()
    var links: [(CGPoint, CGPoint)] = []
}

/// How a species' flowers are laid over its crown.
struct BloomSpec: Sendable {
    enum Shape: Sendable { case sakura, azalea }
    var shape: Shape
    /// Flowers in a back, a middle and a front clump.
    var counts: (Int, Int, Int)
    /// A flower's radius against its clump's.
    var radius: Double
    /// How many of a clump's flowers sit together in a cluster, and how wide a cluster is.
    var cluster: Int
    var spread: Double
    /// Added to every flower's light: a shrub whose sunlit side should not be most of it.
    var bias = 0.0
    /// Flowers grow in trusses: a few large flowers round a middle one, a gap of leaves between
    /// one truss and the next, and the light on a truss falls on its own sunny side.
    var truss = false

    static func of(_ species: Species) -> BloomSpec? {
        switch species {
        case .cherry: BloomSpec(shape: .sakura, counts: (16, 22, 26), radius: 0.15, cluster: 6, spread: 0.26)
        case .azalea: BloomSpec(shape: .azalea, counts: (7, 7, 14), radius: 0.22, cluster: 7, spread: 0.28, truss: true)
        default: nil
        }
    }
}

final class BloomArt: @unchecked Sendable {
    private struct Key: Hashable { var seed: UInt32, species: String, mood: Int, light: Int, day: Int }
    private static let entries = Mutex<[Key: BloomArt]>([:])

    /// The blossoms of a seed, in this light. The mood and the light are held in
    /// steps, as for the leaves, so a tree easing in does not build them again
    /// every frame.
    static func of(_ canopy: Canopy, leaves: LeafArt, mood: Double, light: Double, day: Double) -> BloomArt? {
        guard let spec = BloomSpec.of(canopy.species) else { return nil }
        let key = Key(seed: Ink.hash(canopy.seed), species: canopy.species.rawValue, mood: Int((mood * 40).rounded()),
                      light: Int((light * 10).rounded()), day: Int((day * 4).rounded()))
        return entries.withLock { entries in
            if let found = entries[key] { return found }
            if entries.count >= 8 { entries.removeAll() }
            let made = BloomArt(canopy, leaves, spec, key)
            entries[key] = made
            return made
        }
    }

    func clump(_ i: Int) -> ClumpBloom {
        built.withLock { built in
            if let found = built[i] { return found }
            let made = build(i)
            built[i] = made
            return made
        }
    }

    private let canopy: Canopy
    private let leaves: LeafArt
    private let spec: BloomSpec
    private let seed: UInt32
    private let L: (x: Double, y: Double)
    /// The share of flowers a tired tree has let go of.
    private let thin: Double
    private let built: Mutex<[ClumpBloom?]>

    private init(_ canopy: Canopy, _ leaves: LeafArt, _ spec: BloomSpec, _ key: Key) {
        self.canopy = canopy
        self.leaves = leaves
        self.spec = spec
        seed = key.seed
        L = LeafArt.sun(light: Double(key.light) / 10, day: Double(key.day) / 4)
        let M = Canopy.Mood(Double(key.mood) / 40)
        thin = 0.25 * M.thirst + 0.3 * M.doze
        built = Mutex(Array(repeating: nil, count: canopy.clumps.count))
    }

    /// One clump's flowers: a few clusters over its dome, each flower filed by
    /// the light that reaches it (the side of the clump, where the clump stands
    /// in the crown, the sun's dapples, a share of luck), so the crown has bright
    /// drifts of blossom and a dusky interior, and not an even pink.
    private func build(_ i: Int) -> ClumpBloom {
        var art = ClumpBloom()
        let c = canopy.clumps[i], tier = c.tier
        guard !c.tuft else { return art }
        var r = Ink.Random(seed: seed &+ UInt32(truncatingIfNeeded: i) &* 2_654_435_761 &+ 0xB10F)
        let crown = leaves.crown
        let spot = crown.spot[i]
        let gx = spot?.x ?? crown.cx, gy = spot?.y ?? crown.cy - crown.hh * 0.3, gR = spot?.R ?? c.R
        let n = tier == 2 ? spec.counts.2 : tier == 1 ? spec.counts.1 : spec.counts.0
        let bias = (tier == 0 ? -0.15 : tier == 1 ? 0.2 : 0.4) + spec.bias
        let clusters = spec.truss ? max(1, n / spec.cluster) : max(2, n / spec.cluster)
        var centres: [CGPoint] = []
        for t in 0..<clusters {
            if spec.truss {
                // Trusses spread round the dome with gaps between: spaced in angle,
                // each at its own distance from the middle.
                let a = (Double(t) + r.next() * 0.6) / Double(clusters) * .pi * 2 - .pi / 2, d = 0.34 + 0.4 * r.next()
                centres.append(CGPoint(x: cos(a) * d * 1.05, y: sin(a) * d * 0.8 - 0.06))
            } else {
                let a = r.next() * .pi * 2, d = r.next().squareRoot() * 0.72
                centres.append(CGPoint(x: cos(a) * d, y: sin(a) * d * 0.8 - 0.1))
            }
        }
        art.hubs = centres
        let Lx = L.x, Ly = L.y
        for k in 0..<n {
            let t = k % clusters, centre = centres[t], slot = k / clusters
            let gone = r.next()
            // A flower that would fall off the clump's dome is drawn again, and
            // after a few tries comes in towards the middle of its cluster.
            var x = 0.0, y = 0.0, tries = 0
            repeat {
                if spec.truss {
                    // The first flower is the truss's middle; the rest ring it.
                    let ring = (Double(slot - 1) + 0.5 * r.next()) / Double(max(1, spec.cluster - 1)) * .pi * 2 + Double(t)
                    let reach = slot == 0 ? 0.0 : spec.spread * (0.8 + 0.25 * r.next())
                    x = centre.x + cos(ring) * reach
                    y = centre.y + sin(ring) * reach * 0.9
                } else {
                    x = centre.x + (r.next() - 0.5) * spec.spread * 2
                    y = centre.y + (r.next() - 0.5) * spec.spread * 1.7
                }
                tries += 1
            } while x * x / 0.9 + y * y / 0.64 > 1 && tries < 5
            if x * x / 0.9 + y * y / 0.64 > 1 { (x, y) = (centre.x * 0.8, centre.y * 0.8) }
            let luck = r.next(), rot = r.next() * .pi * 2, size = Ink.lerp(0.85, 1.15, r.next())
            // A tired tree has let some flowers go.
            if gone < thin { continue }
            let rad = spec.radius * size * (tier == 2 ? 1 : tier == 1 ? 0.9 : 0.8)
            let local = x * Lx + y * Ly
            let u = (gx + x * gR - crown.cx) / crown.hw, v = (gy + y * gR - crown.cy) / crown.hh
            let dapple = leaves.dapple(u, v)
            let under = max(0, min(1, v + 0.15)), core = max(0, 1 - (x * x + y * y).squareRoot() / 0.75)
            var light = 0.35 * local + 0.2 * (u * Lx + v * Ly) - 0.7 * under - 0.25 * core + 1.0 * dapple + (luck - 0.5) * 0.6 + bias
            if spec.truss {
                // The light is on a truss's sunny side: how far the flower sits towards
                // the sun from its truss's middle, and a little of where the clump stands.
                let rel = ((x - centre.x) * Lx + (y - centre.y) * Ly) / spec.spread
                light = 0.5 + 0.8 * rel + 0.25 * (u * Lx + v * Ly) - 0.35 * under + (luck - 0.5) * 0.3 + (tier == 0 ? -0.35 : tier == 1 ? -0.12 : 0)
            }
            let raw = light < 0.05 ? 0 : light < 0.5 ? 1 : light < 0.95 ? 2 : 3
            // Behind, fewer classes: two in the back, two in the middle.
            let cls = tier == 0 ? min(raw, 1) : tier == 1 ? (raw < 2 ? 1 : 2) : raw
            art.count += 1
            art.sites.append(CGPoint(x: x, y: y))
            if (x - centre.x) * (x - centre.x) + (y - centre.y) * (y - centre.y) > 0.0004 {
                art.prongs.twig(centre, CGPoint(x: x, y: y), 0.014, 0.01)
                art.links.append((centre, CGPoint(x: x, y: y)))
            }
            art.buds.oval(x, y, rad * 0.5, rad * 0.34, rot)
            /// Files a flower's shape under its class.
            func file(_ path: Path, _ cls: Int) {
                switch cls {
                case 0: art.d.addPath(path)
                case 1: art.m.addPath(path)
                case 2: art.l.addPath(path)
                default: if tier == 2 { art.s.addPath(path) } else { art.l.addPath(path) }
                }
                if tier > 0 { art.all.addPath(path) }
            }
            guard tier == 2 else {
                // Behind, a flower is a scalloped dot of colour.
                var blob = Path()
                if spec.shape == .sakura && tier == 1 {
                    for p in 0..<5 {
                        let a = rot + Double(p) * 2 * .pi / 5
                        blob.oval(x + cos(a) * rad * 0.52, y + sin(a) * rad * 0.52, rad * 0.55, rad * 0.46, a)
                    }
                } else {
                    blob.lobed(x, y, rad, rot, depth: 0.24, steps: 2)
                }
                file(blob, cls)
                if spec.shape == .azalea && tier == 1 {
                    art.hearts.oval(x, y, rad * 0.3, rad * 0.3)
                }
                continue
            }
            switch spec.shape {
            case .sakura:
                var petals = Path()
                for p in 0..<5 {
                    let a = rot + Double(p) * 2 * .pi / 5
                    petals.oval(x + cos(a) * rad * 0.52, y + sin(a) * rad * 0.52, rad * 0.55, rad * 0.46, a)
                    if cls >= 2 {
                        // The notch in the tip of the petal.
                        let tip = CGPoint(x: x + cos(a) * rad * 1.02, y: y + sin(a) * rad * 1.02)
                        let nx = -sin(a) * rad * 0.07, ny = cos(a) * rad * 0.07
                        art.spots.move(to: CGPoint(x: tip.x + nx, y: tip.y + ny))
                        art.spots.addLine(to: CGPoint(x: tip.x - cos(a) * rad * 0.16, y: tip.y - sin(a) * rad * 0.16))
                        art.spots.addLine(to: CGPoint(x: tip.x - nx, y: tip.y - ny))
                        art.spots.closeSubpath()
                    }
                }
                file(petals, cls)
                art.hearts.oval(x, y, rad * 0.17, rad * 0.17)
                if cls >= 2 {
                    for p in 0..<5 {
                        let a = rot + 0.6 + Double(p) * 2 * .pi / 5
                        art.fine.oval(x + cos(a) * rad * 0.34, y + sin(a) * rad * 0.34, rad * 0.055, rad * 0.055)
                    }
                }
            case .azalea:
                var corolla = Path()
                corolla.lobed(x, y, rad, rot)
                file(corolla, cls)
                art.hearts.oval(x, y, rad * 0.32, rad * 0.32)
                if cls >= 1 {
                    // The spots of the throat, on the three petals that face up.
                    let up = -Double.pi / 2
                    for (j, off) in [-0.5, 0.0, 0.5].enumerated() {
                        let a = up + off, d = rad * (0.3 + 0.06 * Double(j % 2))
                        art.spots.oval(x + cos(a) * d, y + sin(a) * d, rad * 0.055, rad * 0.045)
                    }
                }
                if cls >= 2 {
                    for p in 0..<5 {
                        let a = rot + 0.3 + Double(p) * 2 * .pi / 5
                        let tx = x + cos(a) * rad * 1.12, ty = y + sin(a) * rad * 1.12
                        art.fine.move(to: CGPoint(x: x + cos(a) * rad * 0.1, y: y + sin(a) * rad * 0.1))
                        art.fine.addLine(to: CGPoint(x: tx - sin(a) * rad * 0.016, y: ty + cos(a) * rad * 0.016))
                        art.fine.addLine(to: CGPoint(x: tx + sin(a) * rad * 0.016, y: ty - cos(a) * rad * 0.016))
                        art.fine.closeSubpath()
                        art.fine.oval(tx, ty, rad * 0.07, rad * 0.06)
                    }
                }
            }
        }
        return art
    }
}

extension Path {
    /// A flower seen face on with five rounded lobes: a circle whose edge swells
    /// into a petal at every fifth of the way round, smoothed through its
    /// midpoints.
    mutating func lobed(_ cx: Double, _ cy: Double, _ r: Double, _ rot: Double, lobes: Int = 5, depth: Double = 0.17, steps: Int = 4) {
        let n = lobes * steps
        func pt(_ j: Int) -> CGPoint {
            let t = Double(j) * .pi * 2 / Double(n)
            let w = 1 + depth * cos(Double(lobes) * (t - rot))
            return CGPoint(x: cx + cos(t) * r * w, y: cy + sin(t) * r * w)
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        move(to: mid(pt(0), pt(1)))
        for j in 1...n { addQuadCurve(to: mid(pt(j), pt(j + 1)), control: pt(j)) }
        closeSubpath()
    }
}
