import SwiftUI
import Synchronization

/// One clump's leaves, worked out once in the clump's own units (its centre
/// the origin, one unit its radius) and sorted by the light into classes. A
/// redraw at any growth is then a translate, a scale and a fill per class, and
/// not a few dozen leaves built again.
struct ClumpArt: Sendable {
    /// The dark mass behind the leaves, and the twigs in it.
    var body = Path()
    var d = Path(), m = Path(), l = Path(), s = Path()
    /// The light on the edge of the sunstruck leaves, and their midribs and glints.
    var rim = Path()
    /// The undersides of the leaves that have turned over, for a tree whose
    /// leaves are another colour below (an olive's silver).
    var u = Path()
    /// Whether the clump has leaves and wood behind it for its shadow to fall on,
    /// and not sky: the ones low and at the edge of the crown do not.
    var casts = false
    var leaves = 0
}

/// What every clump of one seed shares: where the clumps stand on the grown
/// tree (so a leaf's place in the crown, which decides how much light reaches
/// it, does not move while the tree grows) and which fruit lives in which.
struct PomegranateCrown: Sendable {
    var spot: [Canopy.Pose.Spot?]
    var cx = 0.0, cy = 0.0, hw = 1.0, hh = 1.0
    var fruitsOf: [[Int]]

    init(_ canopy: Canopy) {
        let grown = Canopy.Pose(canopy, growth: 1, mood: Canopy.Mood(0.62))
        spot = grown.clumps
        var x0 = Double.infinity, x1 = -Double.infinity, y0 = Double.infinity, y1 = -Double.infinity
        for (i, c) in canopy.clumps.enumerated() where c.tier > 0 && !c.tuft {
            guard let q = grown.clumps[i] else { continue }
            x0 = min(x0, q.x - q.R)
            x1 = max(x1, q.x + q.R)
            y0 = min(y0, q.y - q.R)
            y1 = max(y1, q.y + q.R * 0.8)
        }
        if x0 < x1 {
            cx = (x0 + x1) / 2
            cy = (y0 + y1) / 2
            hw = max(1, (x1 - x0) / 2)
            hh = max(1, (y1 - y0) / 2)
        }
        fruitsOf = Array(repeating: [], count: canopy.clumps.count)
        for (i, f) in canopy.fruits.enumerated() { fruitsOf[f.clump].append(i) }
    }
}

/// A clump's leaves for one seed, mood and light, each built the first time
/// it is asked for and kept. The mood and the light are held in steps (40 and
/// 10 across their range, the day in quarters) so the picture is the same
/// to the eye and a tree easing in does not build it again every frame.
final class LeafArt: @unchecked Sendable {
    private struct Key: Hashable { var seed: UInt32, species: String, colourway: Int, clumps: Int, mood: Int, light: Int, day: Int }
    private static let entries = Mutex<[Key: LeafArt]>([:])
    /// Keyed on the species and the clump count as well as the seed: a new
    /// companion keeps the old seed until something graduates, and a crown
    /// laid out for another tree's clumps indexes off the end of this one's.
    private struct CrownKey: Hashable { var seed: UInt32, species: String, clumps: Int }
    private static let crowns = Mutex<[CrownKey: PomegranateCrown]>([:])

    /// Towards the light, a unit vector, y up negative. Overhead noon would
    /// light a tree flat, so the light is never quite above it: at least a
    /// quarter of the way to a side, and higher by day than at dusk.
    static func sun(light: Double, day: Double) -> (x: Double, y: Double) {
        let sx = abs(light) < 0.25 ? (light > 0 ? 0.25 : -0.25) : light
        let sy = -(0.45 + 0.4 * day)
        let len = (sx * sx * 0.81 + sy * sy).squareRoot()
        return (sx * 0.9 / len, sy / len)
    }

    static func of(_ canopy: Canopy, mood: Double, light: Double, day: Double) -> LeafArt {
        let seed = Ink.hash(canopy.seed)
        let key = Key(seed: seed, species: canopy.species.rawValue, colourway: canopy.colourway, clumps: canopy.clumps.count, mood: Int((mood * 40).rounded()),
                      light: Int((light * 10).rounded()), day: Int((day * 4).rounded()))
        return entries.withLock { entries in
            if let found = entries[key] { return found }
            // A scene holds a few trees at most; a day's light is a dozen more.
            if entries.count >= 8 { entries.removeAll() }
            let crownKey = CrownKey(seed: seed, species: canopy.species.rawValue, clumps: canopy.clumps.count)
            let crown = crowns.withLock { crowns in
                if let found = crowns[crownKey] { return found }
                if crowns.count >= 8 { crowns.removeAll() }
                let made = PomegranateCrown(canopy)
                crowns[crownKey] = made
                return made
            }
            let made = LeafArt(canopy, crown, key)
            entries[key] = made
            return made
        }
    }

    /// The first clump drawn is the one that pays for building it; the rest
    /// are built as they appear.
    func clump(_ i: Int) -> ClumpArt {
        built.withLock { built in
            if let found = built[i] { return found }
            #if DEBUG
            let started = CACurrentMediaTime()
            #endif
            let made = build(i)
            #if DEBUG
            TreeTiming.built(i, leaves: made.leaves, since: started)
            #endif
            built[i] = made
            return made
        }
    }

    let canopy: Canopy
    let crown: PomegranateCrown
    private let seed: UInt32
    private let L: (x: Double, y: Double)
    let spec: LeafSpec
    private let drop, curl, lenK, wK, pull, bodyK, foldK: Double
    private let blobs: [Blob]
    private let built: Mutex<[ClumpArt?]>
    /// The front clumps the sun reaches most, and where on each its pool of
    /// light lies: for the soft wash `Look.dapple` pours over them.
    let pools: [(Int, CGPoint)]

    /// A patch of sun in the crown, in the crown's own units: where, how
    /// strong, and how tight (the gaussian's `1 / 2σ²`).
    private struct Blob { var u, v, s, k: Double }

    private init(_ canopy: Canopy, _ crown: PomegranateCrown, _ key: Key) {
        self.canopy = canopy
        self.crown = crown
        seed = key.seed
        spec = LeafSpec.of(canopy.species, colourway: canopy.colourway)
        let M = Canopy.Mood(Double(key.mood) / 40)
        let sun = Self.sun(light: Double(key.light) / 10, day: Double(key.day) / 4)
        L = sun
        drop = (0.12 * M.thirst + 0.08 * M.doze) * spec.calm
        curl = (0.5 * M.thirst + 0.3 * M.doze) * spec.calm
        lenK = 1 - 0.1 * M.wilt
        wK = 1 - 0.22 * M.wilt - 0.12 * M.doze * spec.calm
        // Asleep a tree's leaves fold up towards their twig, as a mimosa's or a bean's do at night.
        foldK = 1 - 0.45 * M.doze * spec.calm
        pull = 0.1 + 0.2 * M.wilt + 0.07 * M.doze - 0.05 * M.glow
        bodyK = 1 - 0.45 * (M.thirst + M.doze) * spec.calm
        built = Mutex(Array(repeating: nil, count: canopy.clumps.count))

        // Five patches of sun, on the light's side of the crown and a little
        // to either side of it.
        var r = Ink.Random(seed: key.seed ^ 0x9E37_79B9)
        let toward = atan2(sun.y, sun.x)
        var blobs: [Blob] = []
        for _ in 0..<7 {
            let a = toward + (r.next() - 0.5) * 3.4, d = Ink.lerp(0.1, 0.9, r.next())
            let sigma = Ink.lerp(0.12, 0.22, r.next())
            blobs.append(Blob(u: cos(a) * d, v: sin(a) * d * 0.9, s: Ink.lerp(0.6, 1.0, r.next()), k: 1 / (2 * sigma * sigma)))
        }
        self.blobs = blobs

        // The three front clumps the light reaches most.
        var best: [(score: Double, i: Int)] = []
        for (i, c) in canopy.clumps.enumerated() where c.tier == 2 && !c.tuft {
            guard let q = crown.spot[i] else { continue }
            let score = (q.x - crown.cx) / crown.hw * sun.x + (q.y - crown.cy) / crown.hh * sun.y + (r.next() - 0.5) * 0.3
            if q.y < crown.cy + crown.hh * 0.2 { best.append((score, i)) }
        }
        best.sort { $0.score > $1.score }
        pools = best.prefix(2).map { ($0.i, CGPoint(x: (r.next() - 0.5) * 0.3, y: (r.next() - 0.5) * 0.2)) }
    }

    /// How much of a patch of sun a point on the grown crown is in: `u` and `v`
    /// are across and up it, -1 to 1. For arts that are not leaves but are lit
    /// the same way (the blossoms of a cherry and an azalea).
    func dapple(_ u: Double, _ v: Double) -> Double {
        var sum = 0.0
        for b in blobs {
            let du = u - b.u, dv = v - b.v
            sum += b.s * exp(-(du * du + dv * dv) * b.k)
        }
        return sum
    }

    /// Which way a heading sags under its own weight: towards the side it points.
    private func fall(_ h: Double) -> Double { cos(h) >= 0 ? 1 : -1 }

    // MARK: Building a clump

    /// One clump: a dark body for the depth between the leaves, then sprigs.
    /// Each sprig is a twig that bends as it goes, with a pair of lance leaves
    /// at every node and one at the tip. Every leaf is given the light that
    /// reaches it and filed by class: the light on its side of the clump, how
    /// squarely it faces the sun, where it stands in the crown (the top and the
    /// sun's side are bright, the underside and the interior are not), the
    /// dapples, and a little of its sprig's own luck, so a whole sprig is lit
    /// or in shade and the crown is patchy and not speckled.
    private func build(_ i: Int) -> ClumpArt {
        let c = canopy.clumps[i], tier = c.tier
        var r = Ink.Random(seed: seed &+ UInt32(truncatingIfNeeded: i) &* 2_654_435_761 &+ 97)
        var art = ClumpArt()
        // A young tip's whorl of leaves is drawn broader than its small clump.
        let k = c.tuft ? 1.3 : 1.0
        let sprigs = c.tuft ? spec.sprigs.tuft : (tier == 2 ? spec.sprigs.front : spec.sprigs.back)
        let total = c.tuft ? sprigs : sprigs + (tier == 2 && spec.underSprig ? 1 : 0)
        let pairs = spec.pairs
        let spot = crown.spot[i]
        let gx = spot?.x ?? crown.cx, gy = spot?.y ?? crown.cy - crown.hh * 0.3, gR = spot?.R ?? c.R
        let bias = c.tuft ? 0.1 : tier == 0 ? -0.45 : tier == 1 ? -0.1 : 0.12
        let Lx = L.x, Ly = L.y

        func leaf(_ x: Double, _ y: Double, _ a0: Double, _ len0: Double, _ luck: Double) {
            let keep = r.next(), curlR = r.next(), glossR = r.next(), lenJ = r.next(), flip = r.next()
            let over: Double
            if spec.silver == 0 { over = 1 }
            else if spec.silverByPlace { let h = sin(x * 127.1 + y * 311.7 + Double(i) * 74.7) * 43758.5453; over = h - h.rounded(.down) }
            else { over = r.next() }
            // No two leaves quite parallel: a sprig is a fan, a crown should not be.
            let a = a0 + (flip - 0.5) * 0.5
            if keep < drop { return }
            let curled = curlR < curl
            let len = len0 * Ink.lerp(spec.lens.0, spec.lens.1, lenJ) * lenK * (curled ? 0.62 : 1)
            let hw = len * spec.hw * wK * (curled ? 0.8 : 1)
            let ca = cos(a), sa = sin(a)
            let bend = fall(a) * (0.08 + pull - 0.1 + (curled ? 0.2 : 0))

            let local = x * Lx + y * Ly, face = ca * Lx + sa * Ly
            let u = (gx + x * gR - crown.cx) / crown.hw, v = (gy + y * gR - crown.cy) / crown.hh
            var dapple = 0.0
            for b in blobs {
                let du = u - b.u, dv = v - b.v
                dapple += b.s * exp(-(du * du + dv * dv) * b.k)
            }
            let under = max(0, min(1, v + 0.15)), core = max(0, 1 - (x * x + y * y).squareRoot() / 0.75)
            let light = 0.35 * local + 0.25 * face + 0.2 * (u * Lx + v * Ly) - 0.75 * under - 0.3 * core
                + 1.2 * dapple + (luck - 0.5) * 0.7 + (flip - 0.5) * 0.36 + bias
            let raw = light < 0.05 ? 0 : light < 0.5 ? 1 : light < 0.98 ? 2 : 3
            let cls = spec.flat ? min(raw, tier < 2 ? 1 : 2) : spec.merge ? (tier == 0 ? min(raw, 1) : tier == 1 ? min(raw, 2) : raw) : raw

            let side = (-sa * Lx + ca * Ly) >= 0 ? 1.0 : -1
            art.leaves += 1
            // Some leaves are turned over and show their other side.
            if over < spec.silver * (cls == 0 ? 0.3 : 1) && !(cls == 3 && tier == 2) {
                art.u.blade(spec.shape, x, y, ca, sa, len, hw, bend)
                return
            }
            switch cls {
            case 0: art.d.blade(spec.shape, x, y, ca, sa, len, hw, bend)
            case 1: art.m.blade(spec.shape, x, y, ca, sa, len, hw, bend)
            case 2: art.l.blade(spec.shape, x, y, ca, sa, len, hw, bend)
            default:
                if tier == 2 && !c.tuft {
                    art.s.blade(spec.shape, x, y, ca, sa, len, hw, bend)
                    art.rim.lanceVein(x, y, ca, sa, len, hw, bend)
                } else { art.l.blade(spec.shape, x, y, ca, sa, len, hw, bend) }
            }
            if cls == 3 { art.rim.lanceEdge(x, y, ca, sa, len, hw, bend, side) }
            if cls == 3 && glossR < spec.gloss && !curled { art.rim.lanceGloss(x, y, ca, sa, len, hw, bend, side) }
        }

        for s in 0..<total {
            let under = s >= sprigs
            let f = (Double(s) + 0.5) / Double(sprigs)
            let jitter = (r.next() - 0.5) * 0.5
            // A tuft is a whorl of leaves, so its sprigs spread wide.
            let arc = c.tuft ? 0.18 : 0.1
            var h = under ? 0.5 * .pi + jitter * 2.5 : Ink.lerp(.pi * (1 + arc), .pi * (2 - arc), f) + jitter
            let reach = k * Ink.lerp(spec.reach.0, spec.reach.1, r.next()) * (under ? 0.8 : 1)
            let step = reach / 4, lean = (r.next() - 0.5) * 0.3
            let ob = under ? 0.12 : 0.1
            let luck = r.next()
            var x = cos(h) * k * ob, y = sin(h) * k * ob + k * 0.04
            for n in 1...4 {
                h += pull * 0.5 * fall(h) * abs(cos(h)) + lean
                let from = CGPoint(x: x, y: y)
                x += cos(h) * step
                y += sin(h) * step
                // Every sprig has its twig, at the back as in front: a leaf at the end
                // of one that is not drawn floats clear of the crown.
                if tier == 2 || TreeAttach.on { art.body.twig(from, CGPoint(x: x, y: y), 0.03 - 0.005 * Double(n), 0.03 - 0.005 * Double(n + 1)) }
                let size = k * spec.size * (1 - 0.07 * Double(n))
                if n < 4 && n <= pairs {
                    let spread = Ink.lerp(spec.spread.0, spec.spread.1, r.next()) * foldK
                    if spec.alternate {
                        leaf(x, y, h + (n % 2 == 0 ? spread : -spread), size, luck)
                    } else {
                        leaf(x, y, h - spread, size, luck)
                        leaf(x, y, h + spread, size, luck)
                    }
                } else if n == 4 {
                    leaf(x, y, h, size * 1.05, luck)
                }
            }
        }

        // Now and then a long young shoot stands up out of the crown, which
        // breaks the dome's outline the way a real one is broken.
        if !c.tuft && tier >= 1 && r.next() < 0.4 {
            var h = -Double.pi / 2 + (r.next() - 0.5) * 0.7
            var x = (r.next() - 0.5) * 0.5, y = -0.3
            let step = 0.3
            for n in 1...4 {
                h += pull * 0.25 * fall(h) * abs(cos(h)) + 0.05 * fall(h)
                let from = CGPoint(x: x, y: y)
                x += cos(h) * step
                y += sin(h) * step
                art.body.twig(from, CGPoint(x: x, y: y), 0.03 - 0.005 * Double(n), 0.03 - 0.005 * Double(n + 1))
                if n < 4 {
                    leaf(x, y, h - 0.8, 0.46, 0.85)
                    leaf(x, y, h + 0.8, 0.46, 0.85)
                } else {
                    leaf(x, y, h, 0.5, 0.85)
                }
            }
        }

        if !c.tuft { art.body.oval(0, 0.08, 0.56 * bodyK * spec.body, 0.44 * bodyK * spec.body) }
        art.casts = tier == 2 && !c.tuft && abs(gx - crown.cx) / crown.hw < 0.6 && (gy - crown.cy) / crown.hh < 0.2
        return art
    }
}
