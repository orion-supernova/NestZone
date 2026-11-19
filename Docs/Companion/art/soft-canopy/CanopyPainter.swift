import SwiftUI

/// A household's tree drawn as soft, rounded clumps of foliage: the soft-canopy
/// prototype (`tree.html`), ported to `Canvas`.
///
/// Everything the seed decides is worked out once, here, and a picture is then a
/// function of growth, mood and the time of day (`CanopyPainter`). The seed is
/// read in exactly the prototype's order, call for call, so a household's id
/// grows the same tree in the app as in the HTML. Everything that does not
/// depend on the state — the rim light, the depth layers, what hides what, the
/// fit — is measured here too, so a redraw only poses and paints.
struct Canopy: Equatable, Sendable {
    let seed: String
    let species: Species
    /// The one scale that fits the grown tree into the scene: at most 232 tall
    /// and 196 either side of the trunk.
    let fit: Double

    fileprivate let recipe: Recipe
    /// The trunk's top and the control point of its one curve.
    fileprivate let top: XY, bend: XY
    fileprivate let leanSign: Double
    fileprivate let clumps: [Clump]
    fileprivate let limbs: [Limb]
    fileprivate let leaves: [EdgeLeaf]
    fileprivate let clusters: [Cluster]
    fileprivate let fruit: [Fruit]
    fileprivate let ground: [Fallen]
    fileprivate let bark: [BarkMark]
    fileprivate let twinkles: [Twinkle]
    fileprivate let knots: [Knot]
    /// Clump indices by depth layer. No two clumps that overlap share a layer,
    /// so painter's order between them is exact while each layer is still one
    /// batch.
    fileprivate let layers: [[Int]]
    fileprivate let box: Box

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.seed == rhs.seed && lhs.species == rhs.species }

    init(seed: String, species: Species) {
        let S = Recipe(species)
        var r = Ink.Random(seed)
        func span(_ range: ClosedRange<Double>) -> Double { r.between(range.lowerBound, range.upperBound) }
        func count(_ range: ClosedRange<Int>) -> Int {
            range.lowerBound + Int(r.next() * Double(range.upperBound - range.lowerBound + 1))
        }

        // 1. The trunk: one quadratic, leaning and bent by the seed.
        let lean = (r.next() - 0.5) * S.lean
        let hj = r.between(0.94, 1.06), wj = r.between(0.92, 1.08)
        let bend = (r.next() - 0.5) * 2 * S.trunkCurve
        let th = S.trunkHeight * hj
        let T = XY(sin(lean) * th, -cos(lean) * th)
        top = T
        self.bend = XY(T.x / 2 + cos(lean) * bend * th, T.y / 2 + sin(lean) * bend * th)
        leanSign = lean >= 0 ? 1 : -1

        // 2. The canopy's envelope.
        let C = XY(T.x * 1.3 + r.between(-6, 6), -S.cy * hj)
        let cw = S.cw * wj, ch = S.ch * hj

        // 3. Clumps: a ring that makes the silhouette, a few behind it, a few in front.
        var clumps: [Clump] = []
        func addClump(_ tier: Int, _ x: Double, _ y: Double, _ R: Double, _ keep: Double) {
            let nb = count(S.lobes)
            var lobes = [Lobe(x: 0, y: 0.14, r: 0.74, core: true)]
            for j in 0..<nb {
                let u = (Double(j) + 0.5 + (r.next() - 0.5) * 0.4) / Double(nb)
                let a = Ink.lerp(3.40, 6.02, u), d = r.between(0.4, 0.5), lr = r.between(0.46, 0.58)
                lobes.append(Lobe(x: cos(a) * d, y: sin(a) * d, r: lr, core: false))
            }
            for k in lobes.indices {
                for _ in 0..<(lobes[k].core ? 3 : 2) {
                    let a = r.between(0.25, 2.9), d = r.between(0.38, 0.72) * lobes[k].r
                    let turn = r.between(-0.5, 0.5), size = r.between(0.13, 0.19)
                    lobes[k].marks.append(Mark(x: lobes[k].x + cos(a) * d, y: lobes[k].y + sin(a) * d,
                                               a: a + .pi / 2 + turn, s: size))
                }
            }
            var gloss = 1
            for j in 2..<lobes.count {
                if lobes[j].x * Light.x + lobes[j].y * Light.y > lobes[gloss].x * Light.x + lobes[gloss].y * Light.y { gloss = j }
            }
            lobes[gloss].gloss = true
            let rot = (r.next() - 0.5) * 0.4, sq = S.squash * r.between(0.94, 1.06)
            _ = r.between(1.7, 2.6) // the clump's spring: only the wind needs it, but the seed keeps its order
            let phase = r.next() * tau
            clumps.append(Clump(tier: tier, x: x, y: y, R: R, keep: keep, lobes: lobes, rot: rot, sq: sq, phase: phase))
        }
        let a0 = S.arc.lowerBound * .pi / 180, a1 = S.arc.upperBound * .pi / 180
        let nR = count(S.ring.n)
        for k in 0..<nR {
            let u = (Double(k) + 0.5 + (r.next() - 0.5) * 0.5) / Double(nR)
            let a = Ink.lerp(a0, a1, u), rad = S.ring.rad * r.between(0.92, 1.06), R = span(S.ring.r), keep = 0.25 + r.next() * 0.75
            addClump(1, C.x + cos(a) * cw * rad, C.y + sin(a) * ch * rad, R, keep)
        }
        let nB = count(S.back.n)
        for k in 0..<nB {
            let u = (Double(k) + 0.5 + (r.next() - 0.5) * 0.6) / Double(nB)
            let a = Ink.lerp(a0 + 0.25, a1 - 0.25, u), rad = S.back.rad * r.between(0.8, 1.2), R = span(S.back.r), keep = r.next() * 0.8
            addClump(0, C.x + cos(a) * cw * rad, C.y + sin(a) * ch * rad - ch * 0.12, R, keep)
        }
        let nF = count(S.front.n)
        for k in 0..<nF {
            let u = (Double(k) + 0.5 + (r.next() - 0.5) * 0.5) / Double(nF)
            let y = C.y + ch * span(S.front.y), R = span(S.front.r), keep = 1 + r.next()
            addClump(2, C.x + (u - 0.5) * cw * S.front.spread, y, R, keep)
        }
        // The crown: the highest ring clump, the sapling's first, never lost to sleep.
        var crown = 0
        for i in clumps.indices where clumps[i].tier == 1 {
            if clumps[i].y < clumps[crown].y { crown = i }
        }
        clumps[crown].keep = 2

        // 4. Limbs: clumps grouped by their direction from the trunk top, one limb
        // per group and one twig per clump.
        let heading = clumps.map { atan2($0.y - T.y, $0.x - T.x) }
        let idx = clumps.indices.sorted { heading[$0] != heading[$1] ? heading[$0] < heading[$1] : $0 < $1 }
        var limbs: [Limb] = []
        for group in 0..<S.limbs {
            let members = Array(idx[(group * idx.count / S.limbs)..<((group + 1) * idx.count / S.limbs)])
            var gx = 0.0, gy = 0.0
            for i in members { gx += clumps[i].x; gy += clumps[i].y }
            gx /= Double(members.count); gy /= Double(members.count)
            let x = T.x + (gx - T.x) * S.reach, y = T.y + (gy - T.y) * S.reach, len = hypot(x - T.x, y - T.y)
            let lb = (r.next() - 0.5) * 0.35
            let mx = (T.x + x) / 2, my = (T.y + y) / 2, nx = -(y - T.y) / len, ny = (x - T.x) / len
            let side = Ink.clamp((x - T.x) / len * 1.6, -1, 1)
            _ = r.between(1.5, 2.1) // the limb's spring, kept for the seed's order
            limbs.append(Limb(x: x, y: y, cx: mx + nx * lb * len, cy: my + ny * lb * len, members: members, side: side))
            for i in members {
                let c = clumps[i]
                let tl = hypot(c.x - x, c.y - y) == 0 ? 1 : hypot(c.x - x, c.y - y)
                let tb = (r.next() - 0.5) * 0.25
                clumps[i].limb = group
                clumps[i].tcx = (x + c.x) / 2 - (c.y - y) / tl * tb * tl
                clumps[i].tcy = (y + c.y) / 2 + (c.x - x) / tl * tb * tl
                clumps[i].side = Ink.clamp((c.x - x) / tl * 1.6, -1, 1)
            }
        }

        // 5. When each part arrives: the crown first, then outwards from it.
        let reach = clumps.map { hypot($0.x - clumps[crown].x, $0.y - clumps[crown].y) }
        let order = clumps.indices.sorted { reach[$0] != reach[$1] ? reach[$0] < reach[$1] : $0 < $1 }
        for (rank, i) in order.enumerated() {
            clumps[i].birth = 0.24 + 0.58 * Double(rank) / Double(max(1, order.count - 1))
        }
        for k in limbs.indices {
            let first = limbs[k].members.map { clumps[$0].birth }.min() ?? 0.24
            limbs[k].birth = max(0.17, first - 0.13)
        }

        // 6. Single leaves at the canopy's edge only, pointing out and never down.
        var leaves: [EdgeLeaf] = []
        for (i, c) in clumps.enumerated() where c.tier == 1 {
            let n = count(S.edge.n), out = atan2(c.y - C.y, c.x - C.x)
            for _ in 0..<n {
                var a = out + (r.next() - 0.5) * S.edge.spread
                if sin(a) > 0.35 { a = atan2(0.35, cos(a)) }
                let d = r.between(0.82, 0.92), len = span(S.edge.len), w = S.edge.w * r.between(0.85, 1.15)
                let phase = r.next() * tau
                _ = r.between(5, 8) // the flutter's rate
                let keep = r.next(), birth = c.birth + 0.03 + r.next() * 0.04
                leaves.append(EdgeLeaf(clump: i, a: a - c.rot, d: d, len: len, w: w, phase: phase, keep: keep, birth: birth))
            }
        }

        // 7. Blossom clusters and fruit, in clump-local units.
        var clusters: [Cluster] = [], fruit: [Fruit] = []
        for (i, c) in clumps.enumerated() {
            let share = S.bloom.clusters * (c.R / 27) * (c.tier == 0 ? 0.6 : 1) * r.between(0.6, 1.4)
            let n = Int((share + r.next()).rounded(.down))
            for _ in 0..<n {
                let a = r.between(-2.95, 0.25), rho = r.between(0.3, 0.82), nf = count(S.bloom.per)
                var flowers: [Flower] = []
                for _ in 0..<nf {
                    let fa = r.next() * tau
                    let fd = nf > 1 ? r.between(0.6, 1) : 0
                    let size = span(S.bloom.size), turn = r.next() * tau, birth = 0.86 + r.next() * 0.08
                    flowers.append(Flower(fa: fa, fd: fd, size: size, turn: turn, birth: birth))
                }
                clusters.append(Cluster(clump: i, x: cos(a) * rho, y: sin(a) * rho, flowers: flowers))
            }
            if let F = S.fruit, c.tier > 0 {
                let n = Int((F.per * (c.R / 27) + r.next()).rounded(.down))
                for _ in 0..<n {
                    let a = r.between(0.35, 2.8), rho = r.between(0.62, 0.9), size = span(F.size)
                    let stem = F.stem * r.between(0.8, 1.2), phase = r.next() * tau, birth = 0.9 + r.next() * 0.06
                    let k = count(F.cluster)
                    fruit.append(Fruit(clump: i, x: cos(a) * rho, y: sin(a) * rho, size: size, stem: stem,
                                       phase: phase, birth: birth, k: k))
                }
            }
        }
        // A soft glow is one gradient fill, so only about twelve clusters get one.
        let glowShare = min(1, 12 / Double(max(1, clusters.count)))
        for k in clusters.indices { clusters[k].glow = r.next() < glowShare }

        // 8. Where fallen leaves come to rest on the soil, around the trunk.
        ground = (0..<14).map { _ in
            let x = r.between(-38, 38), y = r.between(-3.5, 2.5), rot = r.next() * tau, s = r.between(4.4, 5.6), tone = r.next()
            return Fallen(x: x, y: y, rot: rot, s: s, tone: tone)
        }
        // 9. Bark marks, in trunk space: t along it, u across it.
        var bark: [BarkMark] = []
        for _ in 0..<(S.bark == .bands ? 6 : S.bark == .gnarl ? 7 : 4) {
            let t0 = r.between(0.08, 0.85)
            switch S.bark {
            case .bands:
                let u0 = r.between(-0.3, 0.05), t1 = t0 + r.between(-0.008, 0.008), u1 = u0 + r.between(0.14, 0.24)
                bark.append(BarkMark(t0: t0, t1: t1, u0: u0, u1: u1))
            case .gnarl:
                let u0 = r.between(-0.4, 0.3), t1 = t0 + r.between(0.12, 0.22), u1 = u0 + r.between(0.1, 0.3)
                bark.append(BarkMark(t0: t0, t1: t1, u0: u0, u1: u1))
            case .lines:
                let u0 = r.between(0.05, 0.32), t1 = t0 + r.between(0.1, 0.2), u1 = u0 + r.between(-0.06, 0.06)
                bark.append(BarkMark(t0: t0, t1: t1, u0: u0, u1: u1))
            }
        }
        self.bark = bark
        twinkles = (0..<6).map { i in
            let a = -Double.pi * (0.08 + 0.84 * (Double(i) + r.between(0.15, 0.85)) / 6)
            let d = r.between(0.92, 1.12), s = r.between(2.2, 3.4)
            _ = r.between(1.6, 2.8) // the twinkle's rate
            return Twinkle(a: a, d: d, s: s, phase: r.next() * tau)
        }
        knots = (0..<S.knots).map { i in
            let t = 0.28 + 0.5 * (Double(i) + r.between(0.1, 0.9)) / Double(max(1, S.knots))
            let u = (i % 2 == 1 ? 1 : -1) * r.between(0.05, 0.2)
            return Knot(t: t, u: u, s: r.between(0.09, 0.14))
        }

        // 10. Depth layers. The back clumps are layer 0; the rest go back to front
        // (the ring by height, then the front clumps), each one layer above every
        // earlier clump it overlaps. Capped, so the cost stays fixed.
        let rest = clumps.indices.filter { clumps[$0].tier > 0 }.sorted { p, q in
            let kp = Double(clumps[p].tier) * 1000 + clumps[p].y, kq = Double(clumps[q].tier) * 1000 + clumps[q].y
            return kp != kq ? kp < kq : p < q
        }
        for (n, i) in rest.enumerated() {
            var layer = 1
            for q in 0..<n {
                let o = clumps[rest[q]]
                if hypot(clumps[i].x - o.x, clumps[i].y - o.y) < (clumps[i].R + o.R) * 0.8 { layer = max(layer, o.layer + 1) }
            }
            clumps[i].layer = min(5, layer)
        }
        let deepest = clumps.map(\.layer).max() ?? 0
        layers = (0...deepest).map { k in clumps.indices.filter { clumps[$0].layer == k } }

        // 11. The rim light: only where a lobe's lit edge is the canopy's outer
        // silhouette, the longest run of it that no other lobe covers.
        var discs: [Disc] = []
        var firstDisc: [Int] = []
        for (i, c) in clumps.enumerated() {
            firstDisc.append(discs.count)
            for lb in c.lobes {
                let (x, y) = rotate(lb.x * c.R, lb.y * c.R * c.sq, c.rot)
                discs.append(Disc(x: c.x + x, y: c.y + y, r: lb.r * c.R, clump: i))
            }
        }
        var near: [Disc] = []
        for i in clumps.indices {
            for j in clumps[i].lobes.indices {
                let own = firstDisc[i] + j, disc = discs[own]
                // Only a lobe that reaches this one's edge can cover any of it.
                near.removeAll(keepingCapacity: true)
                for q in discs.indices where q != own {
                    let o = discs[q]
                    if hypot(o.x - disc.x, o.y - disc.y) < disc.r + o.r * 0.985 { near.append(o) }
                }
                var best: (Double, Double)?, run: (Double, Double)?
                for s in 0...18 {
                    let a = Ink.lerp(Light.angle - 1.15, Light.angle + 1.15, Double(s) / 18)
                    let px = disc.x + cos(a) * disc.r, py = disc.y + sin(a) * disc.r
                    var covered = false
                    for o in near {
                        let dx = px - o.x, dy = py - o.y, k = o.r * 0.985
                        if dx * dx + dy * dy < k * k { covered = true; break }
                    }
                    if covered { run = nil; continue }
                    if let open = run { run = (open.0, a) } else { run = (a, a) }
                    if let now = run, best == nil || now.1 - now.0 > best!.1 - best!.0 { best = now }
                }
                if let best, best.1 - best.0 > 0.45 {
                    clumps[i].lobes[j].rim = (best.0 - clumps[i].rot, best.1 - clumps[i].rot)
                }
            }
        }

        // 12. Blossoms, fruit and edge leaves are drawn after every layer, so keep
        // only those no later layer hides.
        func covered(_ x: Double, _ y: Double, above layer: Int, _ k: Double) -> Bool {
            for o in discs where clumps[o.clump].layer > layer {
                let dx = x - o.x, dy = y - o.y, rr = o.r * k
                if dx * dx + dy * dy < rr * rr { return true }
            }
            return false
        }
        func resting(_ c: Clump, _ lx: Double, _ ly: Double) -> (Double, Double) {
            let (x, y) = rotate(lx * c.R, ly * c.R * c.sq, c.rot)
            return (c.x + x, c.y + y)
        }
        for k in clusters.indices {
            let c = clumps[clusters[k].clump], (x, y) = resting(c, clusters[k].x, clusters[k].y)
            clusters[k].hidden = covered(x, y, above: c.layer, 1.08) || covered(x - 5, y, above: c.layer, 1.02)
                || covered(x + 5, y, above: c.layer, 1.02)
        }
        for k in fruit.indices {
            let f = fruit[k], c = clumps[f.clump], (x, y) = resting(c, f.x, f.y)
            fruit[k].hidden = covered(x, y + f.stem + f.size, above: c.layer, 1.05)
        }
        for k in leaves.indices {
            let lf = leaves[k], c = clumps[lf.clump], a = lf.a + c.rot
            let bx = c.x + cos(a) * c.R * lf.d, by = c.y + sin(a) * c.R * lf.d * c.sq
            leaves[k].hidden = covered(bx + cos(a) * lf.len * 0.8, by + sin(a) * lf.len * 0.8, above: c.layer, 1)
        }

        // 13. Measure the grown tree once and fit it.
        var top = 0.0, left = 0.0, right = 0.0, bottom = -1e9
        for o in discs {
            top = min(top, o.y - o.r); left = min(left, o.x - o.r); right = max(right, o.x + o.r)
            if clumps[o.clump].tier == 2 { bottom = max(bottom, o.y + o.r) }
        }
        let margin = S.edge.len.upperBound * 0.9
        top -= margin; left -= margin; right += margin
        fit = min(1, 232 / -top, 196 / max(-left, right))
        box = Box(top: top, bottom: bottom, cx: C.x, cy: C.y, cr: max(cw, ch))

        self.seed = seed
        self.species = species
        recipe = S
        self.clumps = clumps
        self.limbs = limbs
        self.leaves = leaves
        self.clusters = clusters
        self.fruit = fruit
    }
}

// MARK: - The model's parts

extension Canopy {
    fileprivate struct XY: Sendable {
        var x, y: Double
        init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    }

    fileprivate struct Mark: Sendable { var x, y, a, s: Double }

    /// One round bump of a clump, in units of the clump's radius. The core sits
    /// low; the bumps ride its top arc.
    fileprivate struct Lobe: Sendable {
        var x, y, r: Double
        var core: Bool
        var marks: [Mark] = []
        var gloss = false
        /// The lit edge left showing, relative to the clump's rotation.
        var rim: (Double, Double)?
    }

    fileprivate struct Clump: Sendable {
        /// 0 behind the ring, 1 the ring, 2 in front.
        var tier: Int
        var x, y, R, keep: Double
        var lobes: [Lobe]
        var rot, sq, phase: Double
        var limb = 0
        /// The twig's control point, and which way it leans from its limb.
        var tcx = 0.0, tcy = 0.0, side = 0.0
        var birth = 0.0
        var layer = 0
    }

    fileprivate struct Limb: Sendable {
        var x, y, cx, cy: Double
        var members: [Int]
        var side: Double
        var birth = 0.0
    }

    fileprivate struct EdgeLeaf: Sendable {
        var clump: Int
        var a, d, len, w, phase, keep, birth: Double
        var hidden = false
    }

    fileprivate struct Flower: Sendable { var fa, fd, size, turn, birth: Double }

    fileprivate struct Cluster: Sendable {
        var clump: Int
        var x, y: Double
        var flowers: [Flower]
        var glow = false
        var hidden = false
    }

    fileprivate struct Fruit: Sendable {
        var clump: Int
        var x, y, size, stem, phase, birth: Double
        var k: Int
        var hidden = false
    }

    fileprivate struct Fallen: Sendable { var x, y, rot, s, tone: Double }
    fileprivate struct BarkMark: Sendable { var t0, t1, u0, u1: Double }
    fileprivate struct Twinkle: Sendable { var a, d, s, phase: Double }
    fileprivate struct Knot: Sendable { var t, u, s: Double }
    fileprivate struct Box: Sendable { var top, bottom, cx, cy, cr: Double }
    fileprivate struct Disc: Sendable { var x, y, r: Double; var clump: Int }

    /// One light for the whole scene, from the upper left.
    fileprivate enum Light {
        static let x = -0.5, y = -0.866
        static let angle = atan2(y, x)
        static let shadow = angle + .pi
    }
}

private let tau = Double.pi * 2

/// The standard rotation, with y down.
private func rotate(_ x: Double, _ y: Double, _ a: Double) -> (Double, Double) {
    let c = cos(a), s = sin(a)
    return (x * c - y * s, x * s + y * c)
}

/// The shortest way round to an angle.
private func wrap(_ a: Double) -> Double {
    var a = (a + .pi).truncatingRemainder(dividingBy: tau)
    if a < 0 { a += tau }
    return a - .pi
}

// MARK: - Colour

extension Canopy {
    /// A colour as the prototype holds one: channels 0…255, mixed in sRGB, and
    /// only rounded when it is painted.
    fileprivate struct RGB: Sendable {
        var r, g, b: Double

        init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        init(_ hex: UInt32) {
            self.init(Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF))
        }

        static let black = RGB(0, 0, 0)
        static let moon = (0.62, 0.67, 0.92)

        func mix(_ o: RGB, _ t: Double) -> RGB { RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t) }

        /// Night is a multiply toward moonlight, so everything goes dimmer and
        /// cooler together.
        func night(_ n: Double) -> RGB {
            RGB(r * Ink.lerp(1, Self.moon.0, n), g * Ink.lerp(1, Self.moon.1, n), b * Ink.lerp(1, Self.moon.2, n))
        }

        var hsl: (h: Double, s: Double, l: Double) {
            let r = r / 255, g = g / 255, b = b / 255
            let mx = max(r, g, b), mn = min(r, g, b), l = (mx + mn) / 2
            guard mx != mn else { return (0, 0, l) }
            let d = mx - mn
            let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
            let h = mx == r ? (g - b) / d + (g < b ? 6 : 0) : mx == g ? (b - r) / d + 2 : (r - g) / d + 4
            return (h * 60, s, l)
        }

        init(h: Double, s: Double, l: Double) {
            let h = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let a = s * min(l, 1 - l)
            func f(_ n: Double) -> Double {
                let k = (n + h / 30).truncatingRemainder(dividingBy: 12)
                return (l - a * max(-1, min(k - 3, min(9 - k, 1)))) * 255
            }
            self.init(f(0), f(8), f(4))
        }

        /// Saturation scaled then nudged, lightness nudged: the prototype's `hsl()`.
        func shifted(saturation ds: Double = 0, lightness dl: Double = 0, scale: Double = 1) -> RGB {
            let (h, s, l) = hsl
            return RGB(h: h, s: Ink.clamp(s * scale + ds), l: Ink.clamp(l + dl))
        }

        func color(_ alpha: Double = 1) -> Color {
            Color(.sRGB,
                  red: Ink.clamp(r, 0, 255).rounded() / 255,
                  green: Ink.clamp(g, 0, 255).rounded() / 255,
                  blue: Ink.clamp(b, 0, 255).rounded() / 255,
                  opacity: alpha)
        }

        static func list(_ hexes: UInt32...) -> [RGB] { hexes.map { RGB($0) } }
    }

    /// Where a thirsty canopy heads: straw.
    fileprivate static let dry = RGB.list(0x655C36, 0xA39249, 0xD6C37A, 0xF3E7B0)
    fileprivate static let dryWood = RGB(0x8C7D6E)
    fileprivate static let sproutStem = RGB.list(0x4E8F4A, 0x3A6E3E, 0x8CC56E)
}

// MARK: - Species

extension Canopy {
    /// What makes each species itself. Sizes are in points at full growth,
    /// before the fit. `leaf` is shadow, body, light, rim; `wood` is base,
    /// shadow, light.
    fileprivate struct Recipe: Sendable {
        typealias RGB = Canopy.RGB
        enum Bark: Sendable { case lines, bands, gnarl }
        enum Bloom: Sendable { case cup, star4, star5, trumpet }
        enum FruitKind: Sendable { case pom, lemon, olive }

        struct Group: Sendable {
            var n: ClosedRange<Int>, r: ClosedRange<Double>
            var rad = 0.0, y: ClosedRange<Double> = 0...0, spread = 0.0
        }

        struct Flowers: Sendable {
            var kind: Bloom
            var size: ClosedRange<Double>
            var clusters: Double
            var per: ClosedRange<Int>
            var pw: Double
            /// Dark, light, and the centre or blush.
            var cols: [RGB]
            var glow: RGB
            var bud: [RGB]
        }

        struct Fruits: Sendable {
            var kind: FruitKind
            var size: ClosedRange<Double>
            var per, stem: Double
            var cluster: ClosedRange<Int>
            /// Body, shadow, light, spec, and the crown or nub.
            var cols: [RGB]
        }

        struct Edge: Sendable {
            var n: ClosedRange<Int>, len: ClosedRange<Double>
            var w, spread: Double
            /// Olive's own two tones: grey-green on top, a silver underside.
            var cols: [RGB]?
        }

        var trunkHeight: Double
        var trunkWidth: (Double, Double)
        var trunkCurve: Double
        var lean: Double
        var twin = false, bark = Bark.lines, knots = 0
        var cy, cw, ch: Double
        var arc: ClosedRange<Double>
        var ring, back, front: Group
        var limbs: Int
        var reach: Double
        var lobes = 3...4
        var squash: Double
        var leaf, wood: [RGB]
        var bloom: Flowers
        /// Cherry's canopy blushes pink in bloom.
        var canopyBloom: (k: Double, cols: [RGB])?
        var fruit: Fruits?
        var edge: Edge
        var gloss: Double
        /// Olive's leaf marks are silvery rather than dark.
        var lightMarks = false
    }
}

private extension Canopy.Recipe {
    init(_ species: Species) {
        switch species {
        case .cherry:
            self.init(trunkHeight: 68, trunkWidth: (27, 14), trunkCurve: 0.12, lean: 0.16, bark: .bands,
                      cy: 138, cw: 112, ch: 50, arc: 168...372,
                      ring: Group(n: 7...8, r: 24...30, rad: 0.8), back: Group(n: 2...3, r: 24...28, rad: 0.4),
                      front: Group(n: 3...4, r: 25...30, y: 0...0.3, spread: 1),
                      limbs: 4, reach: 0.55, squash: 0.84,
                      leaf: RGB.list(0x2E5D51, 0x5A9B63, 0xA3D185, 0xEAF7C6), wood: RGB.list(0x6C4846, 0x4A302F, 0x956B65),
                      bloom: Flowers(kind: .star5, size: 3.8...4.8, clusters: 1.4, per: 2...4, pw: 0.62,
                                     cols: RGB.list(0xF2A6C4, 0xFFF0F5, 0xE07592), glow: RGB(0xFFC4DA),
                                     bud: RGB.list(0xD9739B, 0xF2A9C4)),
                      canopyBloom: (0.9, RGB.list(0xC98AAE, 0xF3BCD2, 0xFFE4EE, 0xFFF7FA)),
                      edge: Edge(n: 1...2, len: 5.5...7, w: 1, spread: 1.7), gloss: 0.25)
        case .pomegranate:
            self.init(trunkHeight: 50, trunkWidth: (25, 15), trunkCurve: 0.16, lean: 0.12, knots: 1,
                      cy: 136, cw: 92, ch: 62, arc: 155...385,
                      ring: Group(n: 6...7, r: 27...33, rad: 0.76), back: Group(n: 2...2, r: 26...30, rad: 0.38),
                      front: Group(n: 2...3, r: 28...34, y: 0.05...0.4, spread: 0.8),
                      limbs: 3, reach: 0.5, squash: 0.9,
                      leaf: RGB.list(0x143A33, 0x255B42, 0x3F7E4B, 0xC6E79A), wood: RGB.list(0x6F574C, 0x4C3A33, 0x977D70),
                      bloom: Flowers(kind: .trumpet, size: 7...8.5, clusters: 0.55, per: 1...2, pw: 0.42,
                                     cols: RGB.list(0xB92D1E, 0xF35B33, 0xFFD25A), glow: RGB(0xFF8E62),
                                     bud: RGB.list(0xB83424, 0xE8603E)),
                      fruit: Fruits(kind: .pom, size: 6.5...8, per: 0.5, stem: 2.5, cluster: 1...1,
                                    cols: RGB.list(0xC42A3D, 0x861A2D, 0xF2696D, 0xFFE0E0, 0x7A1424)),
                      edge: Edge(n: 1...2, len: 6...7.5, w: 0.85, spread: 1.7), gloss: 0.9)
        case .azalea:
            self.init(trunkHeight: 24, trunkWidth: (21, 14), trunkCurve: 0.08, lean: 0.08,
                      cy: 104, cw: 110, ch: 62, arc: 160...380,
                      ring: Group(n: 7...8, r: 28...34, rad: 0.74), back: Group(n: 3...3, r: 28...32, rad: 0.4),
                      front: Group(n: 3...4, r: 30...35, y: 0.05...0.45, spread: 1),
                      limbs: 4, reach: 0.45, squash: 0.88,
                      leaf: RGB.list(0x22503F, 0x3D7A4E, 0x76AF67, 0xDDF1B2), wood: RGB.list(0x6A4F45, 0x4A3730, 0x937466),
                      bloom: Flowers(kind: .star5, size: 5.5...7, clusters: 1.5, per: 2...4, pw: 0.72,
                                     cols: RGB.list(0xB32B7F, 0xF25AAE, 0xFFE3F2), glow: RGB(0xFF7BC2),
                                     bud: RGB.list(0xA62E78, 0xE0629F)),
                      edge: Edge(n: 1...1, len: 5...6, w: 0.9, spread: 1.6), gloss: 0.35)
        case .lemon:
            self.init(trunkHeight: 68, trunkWidth: (25, 15), trunkCurve: 0.07, lean: 0.08,
                      cy: 146, cw: 84, ch: 70, arc: 130...410,
                      ring: Group(n: 7...8, r: 27...32, rad: 0.74), back: Group(n: 2...3, r: 27...31, rad: 0.36),
                      front: Group(n: 3...3, r: 29...34, y: -0.05...0.35, spread: 0.7),
                      limbs: 3, reach: 0.5, squash: 0.95,
                      leaf: RGB.list(0x2A6844, 0x4E9F4D, 0xA5D86A, 0xF1FAC3), wood: RGB.list(0x7C6A57, 0x594B3E, 0xA6927B),
                      bloom: Flowers(kind: .star5, size: 3.6...4.4, clusters: 0.6, per: 2...3, pw: 0.42,
                                     cols: RGB.list(0xE8DDBF, 0xFFFCF1, 0xF1C84A), glow: RGB(0xFFF4C2),
                                     bud: RGB.list(0xC7A3BE, 0xEBD3E3)),
                      fruit: Fruits(kind: .lemon, size: 7...8.5, per: 0.5, stem: 2.5, cluster: 1...1,
                                    cols: RGB.list(0xF6CF35, 0xD79F1E, 0xFFF08C, 0xFFFFFF, 0xB98F1A)),
                      edge: Edge(n: 1...2, len: 6...7.5, w: 0.85, spread: 1.7), gloss: 0.65)
        case .olive:
            self.init(trunkHeight: 64, trunkWidth: (33, 16), trunkCurve: 0.2, lean: 0.18, twin: true, bark: .gnarl, knots: 3,
                      cy: 140, cw: 118, ch: 48, arc: 168...372,
                      ring: Group(n: 7...8, r: 23...28, rad: 0.82), back: Group(n: 2...2, r: 22...26, rad: 0.42),
                      front: Group(n: 2...3, r: 24...29, y: 0...0.3, spread: 0.9),
                      limbs: 4, reach: 0.58, squash: 0.74,
                      leaf: RGB.list(0x485F51, 0x7B927D, 0xB9C8B2, 0xEFF4E7), wood: RGB.list(0x827569, 0x5B5149, 0xAB9F92),
                      bloom: Flowers(kind: .star4, size: 2.6...3.2, clusters: 0.5, per: 2...3, pw: 0.6,
                                     cols: RGB.list(0xDCD5B2, 0xF6F2DC, 0xE1CF74), glow: RGB(0xFFF9DA),
                                     bud: RGB.list(0xB9B79A, 0xDCDBC4)),
                      fruit: Fruits(kind: .olive, size: 3...3.6, per: 0.9, stem: 4, cluster: 2...3,
                                    cols: RGB.list(0x3F2C46, 0x24182B, 0x6F5578, 0xEADFEE, 0x3F2C46)),
                      edge: Edge(n: 2...3, len: 7.5...9, w: 0.42, spread: 1.8, cols: RGB.list(0x6E8672, 0xD0DACB)),
                      gloss: 0.2, lightMarks: true)
        case .magnolia, .duckling:
            // The duckling is drawn by `PetPainter` and never reaches here.
            self.init(trunkHeight: 58, trunkWidth: (29, 16), trunkCurve: 0.1, lean: 0.14, knots: 1,
                      cy: 145, cw: 80, ch: 70, arc: 150...390,
                      ring: Group(n: 6...7, r: 28...34, rad: 0.74), back: Group(n: 2...2, r: 28...32, rad: 0.35),
                      front: Group(n: 2...3, r: 30...36, y: 0.05...0.4, spread: 0.7),
                      limbs: 3, reach: 0.5, squash: 0.92,
                      leaf: RGB.list(0x2A5956, 0x4A8D60, 0x8FC478, 0xE6F6BF), wood: RGB.list(0x7D6159, 0x573F3B, 0xAB8C7F),
                      bloom: Flowers(kind: .cup, size: 9...11.5, clusters: 0.75, per: 1...2, pw: 0.5,
                                     cols: RGB.list(0xD2689A, 0xFBD3E2, 0xC04F84), glow: RGB(0xFFB0CF),
                                     bud: RGB.list(0x7F8C78, 0xB9C1AA)),
                      edge: Edge(n: 1...2, len: 6.5...8, w: 1, spread: 1.7), gloss: 0.45)
        }
    }
}

// MARK: - Painting

/// Where decorations go on a tree, in the painter's space (trunk base at the
/// origin, up negative, the fit applied).
struct CanopyAnchors: Equatable, Sendable {
    /// The crown's box: the clumps showing, y up negative.
    var left: Double, right: Double, top: Double, bottom: Double
    /// The top of the highest clump showing: where a star sits.
    var crownTop: CGPoint
    /// Points along the lower and outer edges of the clumps showing, spread
    /// left to right: where ornaments and light bulbs hang.
    var hangs: [CGPoint]
    /// Points on bare wood below the clumps: where paper wish notes hang.
    var notes: [CGPoint]
}

/// One still picture of a `Canopy`: no wind and one fixed instant, because it
/// is drawn only when the state changes and the GPU shader adds the sway.
///
/// It draws in the tree's own space: the trunk's base at the origin on the
/// soil line, up negative, with the fit already applied. Every shape of one
/// colour goes into one path and is filled once — about seventy fills for a
/// tree in bloom, whatever the seed.
struct CanopyPainter {
    let canopy: Canopy
    /// 0…1: seed, sprout, sapling, young tree, tree, in bloom.
    var growth: Double
    /// 0…1: 1 bright, .62 content, .3 thirsty, .05 dozing.
    var mood: Double
    /// 1 at noon, 0 at night.
    var day: Double
    /// The bright-mood twinkles around the crown. Off in the app, whose scene
    /// draws its own glints.
    var twinkles = false

    private typealias RGB = Canopy.RGB
    private typealias Light = Canopy.Light

    func draw(_ context: GraphicsContext) {
        let pose = Pose(canopy, growth: growth, mood: mood, day: day)
        fallen(context, pose)
        var tree = context
        tree.scaleBy(x: canopy.fit, y: canopy.fit)
        paint(tree, pose)
    }

    /// Where decorations go, worked out from the same pose `draw` uses.
    func anchors() -> CanopyAnchors {
        let p = Pose(canopy, growth: growth, mood: mood, day: day), fit = canopy.fit
        func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * fit, y: y * fit) }

        // The lobes showing, as drawn.
        var discs: [(x: Double, y: Double, r: Double, layer: Int)] = []
        var left = Double.infinity, right = -Double.infinity, top = Double.infinity, bottom = -Double.infinity
        var crown = CGPoint(x: p.top.x * fit, y: p.top.y * fit)
        for (i, c) in canopy.clumps.enumerated() {
            let cp = p.clumps[i]
            guard cp.rw >= 1 else { continue }
            for lb in c.lobes {
                let (x, y, r) = p.lobe(cp, lb)
                discs.append((x, y, r, c.layer))
                left = min(left, x - r); right = max(right, x + r); bottom = max(bottom, y + r)
                if y - r < top { top = y - r; crown = point(x, y - r) }
            }
        }
        guard !discs.isEmpty else {
            return CanopyAnchors(left: crown.x, right: crown.x, top: crown.y, bottom: crown.y, crownTop: crown, hangs: [], notes: [])
        }
        func covered(_ x: Double, _ y: Double, above layer: Int, by margin: Double) -> Bool {
            discs.contains { $0.layer > layer && hypot(x - $0.x, y - $0.y) < $0.r + margin }
        }

        // Ornaments: just inside the lower and outer edge of each ring and front
        // clump, wherever no nearer clump covers that edge.
        var hangs: [(x: Double, y: Double)] = []
        let around = [0.2, 0.75, 1.2, Double.pi / 2, .pi - 1.2, .pi - 0.75, .pi - 0.2]
        for (i, c) in canopy.clumps.enumerated() where c.tier > 0 {
            let cp = p.clumps[i]
            guard cp.rw >= 1 else { continue }
            for a in around {
                let (x, y) = p.point(cp, cos(a) * 0.6, 0.14 + sin(a) * 0.6)
                if !covered(x, y, above: c.layer, by: 0) { hangs.append((x, y)) }
            }
        }
        // Notes: on bare wood below the clumps, along the limbs and wherever a
        // twig leaves its clump.
        var wood: [(x: Double, y: Double)] = []
        for lp in p.limbs where lp.lg > 0 {
            for t in [0.45, 0.6, 0.75, 0.9] {
                let (x, y) = quad(p.top.x, p.top.y, lp.cx, lp.cy, lp.x, lp.y, t)
                if !covered(x, y, above: 0, by: 3) { wood.append((x, y)) }
            }
        }
        for (i, c) in canopy.clumps.enumerated() where c.tier > 0 {
            let cp = p.clumps[i], lp = p.limbs[c.limb]
            guard cp.tw > 0 else { continue }
            for t in [0.8, 0.65, 0.5, 0.35, 0.2] {
                let (x, y) = quad(lp.x, lp.y, cp.qx, cp.qy, cp.ax, cp.ay, t)
                if !covered(x, y, above: 0, by: 3) { wood.append((x, y)); break }
            }
        }
        // All four tree decorations can be up at once, so a note keeps clear of
        // the ornaments and bulbs.
        let width = right - left
        let hung = Self.spread([hangs], keep: 8...14, gap: width / 9, floor: 10)
        func clear(_ q: (x: Double, y: Double)) -> Bool { hung.allSatisfy { hypot($0.x - q.x, $0.y - q.y) >= 9 } }
        wood = wood.filter(clear)
        var notes = Self.spread([wood], keep: 4...6, gap: width / 6, floor: 12, upright: 0.5)
        if notes.count < 4 {
            // A compact crown shows little wood: the rest hang from the
            // foliage's lower edge.
            var edge: [(x: Double, y: Double)] = []
            for (i, c) in canopy.clumps.enumerated() where c.tier > 0 {
                let cp = p.clumps[i]
                guard cp.rw >= 1 else { continue }
                for a in [Double.pi / 2 - 0.5, .pi / 2, .pi / 2 + 0.5] {
                    let (x, y) = p.point(cp, cos(a) * 0.7, 0.14 + sin(a) * 0.7)
                    if !covered(x, y, above: c.layer, by: 0), clear((x, y)) { edge.append((x, y)) }
                }
            }
            notes = Self.spread([wood, edge], keep: 4...6, gap: width / 6, floor: 12, upright: 0.5)
        }
        return CanopyAnchors(
            left: left * fit, right: right * fit, top: top * fit, bottom: bottom * fit, crownTop: crown,
            hangs: hung.map { point($0.x, $0.y) },
            notes: notes.map { point($0.x, $0.y) }
        )
    }

    /// Thins candidate points to an even spread. Groups are taken in order and
    /// each lowest first; a point is kept only if it is clear of those already
    /// kept, the gap shrinking (never below `floor`, so a small tree gets fewer
    /// rather than a pile) until enough are. Then evenly sampled down to the
    /// most wanted, left to right. A note hangs below its point, so for notes
    /// a vertical gap counts for less (`upright`) than a sideways one.
    private static func spread(_ groups: [[(x: Double, y: Double)]], keep: ClosedRange<Int>, gap: Double,
                               floor: Double, upright: Double = 1) -> [(x: Double, y: Double)] {
        let order = groups.flatMap { $0.sorted { $0.y > $1.y } }
        var gap = max(gap, floor), kept: [(x: Double, y: Double)] = []
        while true {
            kept = []
            for q in order where kept.allSatisfy({ hypot($0.x - q.x, ($0.y - q.y) * upright) >= gap }) { kept.append(q) }
            if kept.count >= keep.lowerBound || gap <= floor { break }
            gap = max(floor, gap * 0.85)
        }
        kept.sort { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard kept.count > keep.upperBound else { return kept }
        let n = keep.upperBound
        return (0..<n).map { kept[Int((Double($0) + 0.5) * Double(kept.count) / Double(n))] }
    }
}

// MARK: - The pose

extension CanopyPainter {
    /// Where everything is for one state: the mood as four numbers, the growth
    /// as a handful of scales, and every limb and clump placed.
    fileprivate struct Pose {
        struct LimbPose { var x, y, cx, cy, angle, lg: Double }
        struct ClumpPose {
            /// The twig's end and control point.
            var ax, ay, qx, qy, tw: Double
            /// The clump's centre, its drawn radius, rotation and squash.
            var x, y, rw, rho, sq, vis: Double
        }

        let recipe: Canopy.Recipe
        let g, vig, dry, sleep, slump, open, night: Double
        let sz, wf, bloomIn, spr: Double
        /// The trunk's lean this moment, its top and its control point.
        let lean: Double
        let top: (x: Double, y: Double), bend: (x: Double, y: Double)
        var limbs: [LimbPose] = []
        var clumps: [ClumpPose] = []
        let box: Canopy.Box

        init(_ m: Canopy, growth g: Double, mood: Double, day: Double) {
            let vig = Ink.smooth((mood - 0.62) / 0.38)
            let dry = Ink.smooth((0.66 - mood) / 0.56)
            let sleep = Ink.smooth((0.32 - mood) / 0.27)
            let slump = dry + 0.6 * sleep
            let sz = Ink.lerp(0.36, 1, Ink.smooth((g - 0.1) / 0.74))
            let tg = Ink.ease((g - 0.085) / 0.16) * Ink.lerp(0.42, 1, Ink.smooth((g - 0.12) / 0.7))
            let szR = pow(sz, 0.6)
            // How far limbs and twigs reach from the trunk top: a young crown is compact.
            let spr = sz * Ink.lerp(0.45, 1, Ink.smooth((g - 0.25) / 0.45))
            let lean = m.leanSign * 0.07 * slump
            let (tx, ty) = rotate(m.top.x * tg, m.top.y * tg, lean)
            recipe = m.recipe
            self.g = g
            self.vig = vig
            self.dry = dry
            self.sleep = sleep
            self.slump = slump
            open = Ink.smooth((mood - 0.22) / 0.4)
            night = 1 - day
            self.sz = sz
            wf = Ink.lerp(0.22, 1, Ink.smooth((g - 0.1) / 0.8))
            bloomIn = Ink.smooth((g - 0.84) / 0.1)
            self.spr = spr
            self.lean = lean
            top = (tx, ty)
            bend = rotate(m.bend.x * tg, m.bend.y * tg, lean * 0.5)

            limbs.reserveCapacity(m.limbs.count)
            for L in m.limbs {
                let lg = Ink.ease((g - L.birth) / 0.12), angle = lean + L.side * (0.2 * slump - 0.1 * vig)
                let (vx, vy) = rotate((L.x - m.top.x) * spr * lg, (L.y - m.top.y) * spr * lg, angle)
                let (qx, qy) = rotate((L.cx - m.top.x) * spr * lg, (L.cy - m.top.y) * spr * lg, angle)
                limbs.append(LimbPose(x: tx + vx, y: ty + vy, cx: tx + qx, cy: ty + qy, angle: angle, lg: lg))
            }
            // Plump or shrunken, lifted or drooping, and when dozing a clump
            // either reads or is gone.
            let ks = 1 + 0.1 * vig - 0.13 * dry - 0.09 * sleep, sqk = 1 + 0.05 * vig - 0.07 * dry
            clumps.reserveCapacity(m.clumps.count)
            for c in m.clumps {
                let L = m.limbs[c.limb], lp = limbs[c.limb], tw = Ink.ease((g - (c.birth - 0.07)) / 0.08)
                let angle = lp.angle + c.side * 0.12 * slump
                let (ux, uy) = rotate((c.x - L.x) * spr * tw, (c.y - L.y) * spr * tw, angle)
                let (qx, qy) = rotate((c.tcx - L.x) * spr * tw, (c.tcy - L.y) * spr * tw, angle)
                let pop = Ink.back((g - c.birth) / 0.07), v0 = Ink.smooth((c.keep - sleep * 0.55) / 0.08 + 1), vis = v0 < 0.45 ? 0 : v0
                let bob = 0.55 * sin(c.phase) * 0.4 * sz
                let sag = (5 * slump * (c.R / 27) - 4 * vig) * sz
                clumps.append(ClumpPose(
                    ax: lp.x + ux, ay: lp.y + uy, qx: lp.x + qx, qy: lp.y + qy, tw: tw,
                    x: lp.x + ux + c.side * 2 * slump * sz, y: lp.y + uy + bob + sag,
                    rw: c.R * szR * pop * vis * ks, rho: c.rot, sq: c.sq * sqk, vis: vis
                ))
            }
            box = Canopy.Box(top: ty + (m.box.top - m.top.y) * spr, bottom: ty + (m.box.bottom - m.top.y) * spr,
                             cx: tx + (m.box.cx - m.top.x) * spr, cy: ty + (m.box.cy - m.top.y) * spr, cr: m.box.cr * spr)
        }

        /// A lobe as drawn: its centre and radius.
        func lobe(_ p: ClumpPose, _ lb: Canopy.Lobe) -> (Double, Double, Double) {
            let (x, y) = rotate(lb.x * p.rw, lb.y * p.rw * p.sq, p.rho)
            return (p.x + x, p.y + y, lb.r * p.rw)
        }

        /// A point in a clump's own units, as drawn.
        func point(_ p: ClumpPose, _ lx: Double, _ ly: Double) -> (Double, Double) {
            let (x, y) = rotate(lx * p.rw, ly * p.rw * p.sq, p.rho)
            return (p.x + x, p.y + y)
        }

        // The colours, from the species, the mood and the clock.

        func leaf(_ i: Int, _ tier: Int, green: Bool = false) -> Canopy.RGB {
            var c = recipe.leaf[i]
            if let blush = recipe.canopyBloom, !green { c = c.mix(blush.cols[i], blush.k * bloomIn * open) }
            c = c.mix(Canopy.dry[i], dry * 0.9)
            var (h, s, l) = c.hsl
            // Bright is more saturated and warmer in the light, content a touch
            // calmer, dozing pale.
            s = Ink.clamp(s * (1 + 0.34 * vig) * (1 - 0.1 * (1 - vig) * (1 - dry)) * (1 - 0.5 * sleep))
            l = Ink.clamp(l + (i >= 2 ? 0.035 : 0.012) * vig)
            if i >= 2 { h -= 7 * vig }
            l = Ink.lerp(l, 0.8, 0.3 * sleep)
            // Distant clumps sit back, cooler; the front ones pop.
            if tier == 0 {
                l *= 0.86
                h += wrap((200 - h) * .pi / 180) * 180 / .pi * 0.08
            } else if tier == 2 {
                l = min(1, l * 1.035)
            }
            return Canopy.RGB(h: h, s: s, l: l).night(night)
        }

        func rim(_ tier: Int) -> Canopy.RGB { leaf(3, tier).mix(Canopy.RGB(205, 214, 255), night * 0.75) }

        func wood(_ i: Int) -> Canopy.RGB {
            var c = recipe.wood[i].mix(Canopy.dryWood, 0.25 * dry).shifted(lightness: 0.08 * sleep, scale: 1 - 0.3 * sleep)
            // A sprout's stem is green.
            if g < 0.36 { c = c.mix(Canopy.sproutStem[i], 1 - Ink.smooth((g - 0.18) / 0.16)) }
            return c.night(night)
        }

        /// Blossoms dim less than the leaves at night, so they glow.
        func bloom(_ c: Canopy.RGB, _ k: Double = 1) -> Canopy.RGB {
            c.shifted(scale: (1 - 0.35 * dry) * (1 + 0.1 * vig)).night(night * k)
        }
    }
}

private func quad(_ x: Double, _ y: Double, _ cx: Double, _ cy: Double, _ x1: Double, _ y1: Double, _ t: Double) -> (Double, Double) {
    let u = 1 - t
    return (u * u * x + 2 * u * t * cx + t * t * x1, u * u * y + 2 * u * t * cy + t * t * y1)
}

private func tangent(_ s: Wood, _ t: Double) -> Double {
    atan2(2 * (1 - t) * (s.cy - s.y) + 2 * t * (s.y1 - s.cy), 2 * (1 - t) * (s.cx - s.x) + 2 * t * (s.x1 - s.cx))
}

/// A tapered quadratic piece of wood: from (x, y) to (x1, y1), w0 wide at the
/// base and w1 at the tip.
private struct Wood {
    var x, y, cx, cy, x1, y1, w0, w1: Double
}

// MARK: - Drawing, back to front

extension CanopyPainter {
    private func fill(_ c: GraphicsContext, _ path: Path, _ color: RGB, _ alpha: Double = 1) {
        guard !path.isEmpty else { return }
        c.fill(path, with: .color(color.color(alpha)))
    }

    private func fill(_ c: GraphicsContext, _ path: Path, _ shading: GraphicsContext.Shading) {
        guard !path.isEmpty else { return }
        c.fill(path, with: shading)
    }

    private func stroke(_ c: GraphicsContext, _ path: Path, _ color: RGB, _ alpha: Double, _ width: Double) {
        guard !path.isEmpty else { return }
        c.stroke(path, with: .color(color.color(alpha)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func stop(_ color: RGB, _ alpha: Double, _ location: Double) -> Gradient.Stop {
        Gradient.Stop(color: color.color(alpha), location: location)
    }

    private func vertical(_ y0: Double, _ y1: Double, _ stops: [Gradient.Stop]) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: 0, y: y0), endPoint: CGPoint(x: 0, y: y1))
    }

    private func radial(_ x: Double, _ y: Double, _ r: Double, _ stops: [Gradient.Stop]) -> GraphicsContext.Shading {
        .radialGradient(Gradient(stops: stops), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r)
    }

    /// Leaves a quiet house has let go of, on the soil around the trunk. Not
    /// scaled by the fit: they lie on the scene's soil, not the tree's.
    private func fallen(_ c: GraphicsContext, _ p: Pose) {
        let n = Int((14 * Ink.clamp((p.dry * 0.55 + p.sleep * 0.45 - 0.12) / 0.88)).rounded())
        guard n > 0, p.g >= 0.3 else { return }
        var dark = Path(), light = Path()
        for q in canopy.ground.prefix(n) {
            if q.tone > 0.5 {
                light.addLeafHalf(q.x, q.y, q.rot, q.s, 0.9, 1)
                dark.addLeafHalf(q.x, q.y, q.rot, q.s, 0.9, -1)
            } else {
                dark.addLeafHalf(q.x, q.y, q.rot, q.s, 0.9, 1)
                light.addLeafHalf(q.x, q.y, q.rot, q.s, 0.9, -1)
            }
        }
        fill(c, dark, RGB(0x9A7A3E).night(p.night))
        fill(c, light, RGB(0xCDAE62).night(p.night))
    }

    private func paint(_ c: GraphicsContext, _ p: Pose) {
        let g = p.g, box = p.box

        // A soft halo behind the crown, so it reads on the night sky.
        if g > 0.2 {
            let k = Ink.smooth((g - 0.2) / 0.3)
            let hc = (p.night > 0.5 ? RGB(200, 184, 255) : RGB(255, 250, 235)).mix(p.recipe.bloom.glow, p.bloomIn * p.open * 0.6)
            let alpha = (0.1 + 0.14 * p.vig + 0.05 * p.night) * k * (1 - 0.6 * p.sleep)
            var halo = Path()
            halo.addDisc(box.cx, box.cy, box.cr * 1.7)
            fill(c, halo, radial(box.cx, box.cy, box.cr * 1.7, [stop(hc, alpha, 0), stop(hc, 0, 1)]))
        }
        // The seed, before it cracks.
        let ksd = 1 - Ink.smooth((g - 0.085) / 0.04)
        if ksd > 0 {
            var s = c
            s.translateBy(x: 0, y: -3)
            s.scaleBy(x: ksd, y: ksd)
            var shell = Path(), shine = Path()
            shell.addOval(0, 0, 8.5, 5.4, -0.3)
            shine.addOval(-2.6, -1.8, 3, 1.4, -0.3)
            fill(s, shell, RGB(0x8A5A3A).night(p.night))
            fill(s, shine, RGB(0xD2A27A).night(p.night), 0.8)
        }
        guard g >= 0.085 else { return }

        // Twigs to the back clumps, hidden behind them.
        let tw0 = p.recipe.trunkWidth.1 * p.wf * 0.42 * 0.85
        var twigs = Path()
        for (i, cl) in canopy.clumps.enumerated() where cl.tier == 0 {
            let cp = p.clumps[i], lp = p.limbs[cl.limb]
            guard cp.tw > 0 else { continue }
            twigs.addLimb(lp.x, lp.y, cp.qx, cp.qy, cp.ax, cp.ay, tw0 * cp.tw.squareRoot(), max(1, tw0 * 0.4))
        }
        fill(c, twigs, p.wood(1))

        // The canopy layer by layer: the back, then the wood, then the rest back to front.
        layer(c, 0, p)
        wood(c, p)
        for k in canopy.layers.indices.dropFirst() { layer(c, k, p) }
        blossoms(c, p)
        fruits(c, p)
        edgeLeaves(c, p)

        // A bright house: a few glints around the crown.
        if twinkles, p.vig > 0.02, g > 0.5 {
            var glints = Path()
            for q in canopy.twinkles {
                let rr = q.s * max(0, sin(q.phase)) * p.vig * p.sz
                guard rr >= 0.35 else { continue }
                let x = box.cx + cos(q.a) * box.cr * q.d * 1.05, y = box.cy + sin(q.a) * box.cr * q.d * 0.9 - 6 * p.sz
                let o = CGPoint(x: x, y: y), e = rr * 2.4
                glints.move(to: CGPoint(x: x, y: y - e))
                glints.addQuadCurve(to: CGPoint(x: x + e, y: y), control: o)
                glints.addQuadCurve(to: CGPoint(x: x, y: y + e), control: o)
                glints.addQuadCurve(to: CGPoint(x: x - e, y: y), control: o)
                glints.addQuadCurve(to: CGPoint(x: x, y: y - e), control: o)
                glints.closeSubpath()
            }
            fill(c, glints, RGB(0xFFF1C4).night(p.night * 0.3), 0.95)
        }
        // The sprout's seed leaves, which fall away as the crown arrives.
        let kc = Ink.back((g - 0.1) / 0.05) * (1 - Ink.smooth((g - 0.27) / 0.06))
        if kc > 0 {
            var dark = Path(), light = Path()
            for side in stride(from: -1.0, through: 1, by: 2) {
                let d = -Double.pi / 2 + side * (1.05 + 0.5 * p.slump), s = 8.5 * kc
                let lit: Double = -sin(d) * Light.x + cos(d) * Light.y > 0 ? 1 : -1
                light.addLeafHalf(p.top.x, p.top.y, d, s, 1.15, lit)
                dark.addLeafHalf(p.top.x, p.top.y, d, s, 1.15, -lit)
            }
            fill(c, dark, RGB(0x3E8A48).shifted(scale: 1 - 0.5 * p.dry).night(p.night))
            fill(c, light, RGB(0x86C76A).shifted(scale: 1 - 0.5 * p.dry).night(p.night))
        }
    }

    /// One depth layer of clumps, as an offset stack: the silhouette in shadow,
    /// the body moved toward the light (leaving a shadow crescent on the far
    /// side), leaf marks, light caps on the upper bumps, a hot spot, the rim
    /// and a gloss.
    private func layer(_ c: GraphicsContext, _ k: Int, _ p: Pose) {
        var shade = Path(), body = Path(), marks = Path(), lite = Path(), hot = Path(), rim = Path(), gloss = Path()
        let lx = Light.x, ly = Light.y
        for i in canopy.layers[k] {
            let clump = canopy.clumps[i], cp = p.clumps[i]
            guard cp.rw >= 0.6 else { continue }
            let dr = cp.rho - clump.rot
            for lb in clump.lobes {
                let (x, y, r) = p.lobe(cp, lb)
                shade.addDisc(x, y, r)
                body.addDisc(x + lx * 0.13 * r, y + ly * 0.13 * r, 0.88 * r)
                if cp.rw > 6 {
                    for mk in lb.marks {
                        let (mx, my) = p.point(cp, mk.x, mk.y)
                        marks.addOval(mx, my, mk.s * cp.rw, mk.s * cp.rw * 0.36, mk.a + cp.rho)
                    }
                }
                if !lb.core, lb.y < 0.05 {
                    lite.addDisc(x + lx * 0.33 * r, y + ly * 0.33 * r, 0.56 * r)
                    if lb.y < -0.12 { hot.addDisc(x + lx * 0.47 * r, y + ly * 0.47 * r, 0.3 * r) }
                }
                if let arc = lb.rim { rim.addRim(x, y, r * 0.955, arc.0 + dr, arc.1 + dr) }
                if lb.gloss { gloss.addOval(x + lx * 0.5 * r, y + ly * 0.5 * r, 0.2 * r, 0.085 * r, Light.angle + .pi / 2) }
            }
        }
        let count = canopy.layers.count, box = p.box
        let tier = k == 0 ? 0 : k >= count - 1 ? 2 : 1
        let depth = k == 0 ? 0 : Double(k - 1) / Double(max(1, count - 2))
        func darken(_ c: RGB) -> RGB { k == 0 ? c : c.mix(.black, 0.06 * (1 - depth)) }
        let cb = darken(p.leaf(1, tier)), cs = darken(p.leaf(0, tier)), cl = darken(p.leaf(2, tier)), edge = p.leaf(3, tier)

        fill(c, shade, vertical(box.top, box.bottom, [stop(cs.mix(cb, 0.45), 1, 0), stop(cs, 1, 1)]))
        fill(c, body, vertical(box.top, box.bottom, [stop(cb.mix(cl, 0.25), 1, 0), stop(cb, 1, 0.55), stop(cb.mix(cs, 0.35), 1, 1)]))
        if k == 0, p.g > 0.3 {
            // The back layer darkens toward its middle, where the canopy closes over the trunk.
            let ax = (p.top.x + box.cx) / 2, ay = Ink.lerp(p.top.y, box.bottom, 0.5), sc = cs.mix(RGB(12, 10, 24), 0.4)
            fill(c, body, radial(ax, ay, box.cr * 0.95, [stop(sc, 0.6, 0), stop(sc, 0.25, 0.6), stop(sc, 0, 1)]))
        }
        if p.recipe.lightMarks {
            fill(c, marks, cl.mix(edge, 0.4), 0.55)
        } else {
            fill(c, marks, cb.mix(cs, 0.6), 0.5)
        }
        let gx = box.cx + lx * box.cr * 0.8, gy = box.cy + ly * box.cr * 0.8
        fill(c, lite, radial(gx, gy, box.cr * 1.9, [stop(cl.mix(edge, 0.22), 1, 0), stop(cl.mix(cb, 0.55), 1, 1)]))
        fill(c, hot, cl.mix(edge, 0.45), 0.18 + 0.42 * p.vig)
        stroke(c, rim, p.rim(tier), 0.7, 1.4)
        let shine = p.recipe.gloss * (0.12 + 0.8 * p.vig) * (1 - 0.85 * p.dry) * (1 - 0.5 * p.night)
        if shine > 0.02 { fill(c, gloss, RGB(255, 255, 255), shine) }
    }

    /// Trunk, limbs and twigs: the base, a shadow side, a light side, bark
    /// marks and knots, and the shade of the canopy over all of it.
    private func wood(_ c: GraphicsContext, _ p: Pose) {
        let S = p.recipe, g = p.g, box = p.box
        let w0 = S.trunkWidth.0 * p.wf, w1 = S.trunkWidth.1 * p.wf, lw0 = w1 * 0.8, lw1 = w1 * 0.42, tw0 = lw1 * 0.85
        let (tx, ty) = p.top, (tcx, tcy) = p.bend

        // The contact shadow, an ellipse squashed onto the soil.
        do {
            let cr = w0 * 1.6 + 4, cc = RGB(0x24140E).night(p.night)
            var s = c
            s.translateBy(x: 0, y: 1)
            s.scaleBy(x: 1, y: 0.24)
            var contact = Path()
            contact.addDisc(0, 0, cr)
            fill(s, contact, radial(0, 0, cr, [stop(cc, 0.42, 0), stop(cc, 0.18, 0.55), stop(cc, 0, 1)]))
        }
        var base = Path(), dark = Path(), lite = Path(), lines = Path(), knots = Path()
        let trunks = S.twin
            ? [Wood(x: -w0 * 0.2, y: 0, cx: tcx + w0 * 0.5, cy: tcy, x1: tx, y1: ty, w0: w0 * 0.66, w1: w1 * 0.78),
               Wood(x: w0 * 0.22, y: 0, cx: tcx - w0 * 0.55, cy: tcy, x1: tx + w1 * 0.1, y1: ty, w0: w0 * 0.6, w1: w1 * 0.72)]
            : [Wood(x: 0, y: 0, cx: tcx, cy: tcy, x1: tx, y1: ty, w0: w0, w1: w1)]
        var segments = trunks
        for lp in p.limbs where lp.lg > 0 {
            segments.append(Wood(x: tx, y: ty, cx: lp.cx, cy: lp.cy, x1: lp.x, y1: lp.y, w0: lw0 * lp.lg.squareRoot(), w1: lw1))
        }
        for s in segments { base.addLimb(s.x, s.y, s.cx, s.cy, s.x1, s.y1, s.w0, s.w1) }
        if g > 0.3 {
            // The root flare.
            let k = Ink.smooth((g - 0.3) / 0.3)
            base.addOval(-w0 * 0.46, -w0 * 0.1, w0 * 0.42 * k, w0 * 0.2 * k, -0.35)
            base.addOval(w0 * 0.46, -w0 * 0.1, w0 * 0.42 * k, w0 * 0.2 * k, 0.35)
        }
        for (i, cl) in canopy.clumps.enumerated() where cl.tier != 0 {
            let cp = p.clumps[i], lp = p.limbs[cl.limb]
            guard cp.tw > 0 else { continue }
            base.addLimb(lp.x, lp.y, cp.qx, cp.qy, cp.ax, cp.ay, tw0 * cp.tw.squareRoot(), max(1, tw0 * 0.4))
        }
        // The shadow and light strips. On a limb they start at t = .22, so they never cross at the fork.
        for (i, s) in segments.enumerated() {
            let t0 = i < trunks.count ? 0 : 0.22
            let (sx, sy) = quad(s.x, s.y, s.cx, s.cy, s.x1, s.y1, t0)
            let from = Wood(x: sx, y: sy, cx: Ink.lerp(s.cx, s.x1, t0), cy: Ink.lerp(s.cy, s.y1, t0), x1: s.x1, y1: s.y1,
                               w0: Ink.lerp(s.w0, s.w1, t0), w1: s.w1)
            dark.addLimb(from, toward: -0.21, width: 0.56)
            lite.addLimb(from, toward: 0.3, width: 0.16)
        }
        if g > 0.3 { dark.addOval(w0 * 0.5, -w0 * 0.08, w0 * 0.3, w0 * 0.14, 0.35) }
        if g > 0.32 {
            for (n, t) in trunks.enumerated() {
                func at(_ along: Double, _ across: Double) -> (Double, Double) {
                    let (px, py) = quad(t.x, t.y, t.cx, t.cy, t.x1, t.y1, along)
                    let angle = tangent(t, along), w = Ink.lerp(t.w0, t.w1, along)
                    return (px - sin(angle) * across * w, py + cos(angle) * across * w)
                }
                for b in canopy.bark {
                    let p0 = at(b.t0, b.u0), p1 = at((b.t0 + b.t1) / 2, (b.u0 + b.u1) / 2 + 0.04), p2 = at(b.t1, b.u1)
                    lines.move(to: CGPoint(x: p0.0, y: p0.1))
                    lines.addQuadCurve(to: CGPoint(x: p2.0, y: p2.1),
                                       control: CGPoint(x: 2 * p1.0 - (p0.0 + p2.0) / 2, y: 2 * p1.1 - (p0.1 + p2.1) / 2))
                }
                if n == 0 {
                    for kn in canopy.knots {
                        let (px, py) = at(kn.t, kn.u), w = Ink.lerp(t.w0, t.w1, kn.t)
                        knots.addOval(px, py, w * kn.s, w * kn.s * 1.5, tangent(t, kn.t) + .pi / 2)
                    }
                }
            }
        }
        fill(c, base, p.wood(0))
        fill(c, dark, p.wood(1))
        fill(c, lite, p.wood(2), 0.85)
        if S.bark == .bands {
            stroke(c, lines, p.wood(2), 0.5, 1.1)
        } else {
            stroke(c, lines, p.wood(1), 0.6, 1.1)
        }
        fill(c, knots, p.wood(1).mix(RGB(20, 12, 10), 0.35))
        if g > 0.3 {
            // The wood darkens as it goes up into the canopy's shade: the same path, refilled.
            let k = Ink.smooth((g - 0.3) / 0.25), y0 = min(ty, box.bottom) - 6 * p.sz, y1 = ty + 38 * p.sz
            let sc = p.leaf(0, 0).mix(p.wood(1), 0.5).mix(RGB(18, 10, 16), 0.45)
            fill(c, base, vertical(y0, y1, [stop(sc, 0.75 * k, 0), stop(sc, 0.35 * k, 0.45), stop(sc, 0, 1)]))
        }
    }

    /// Flowers open with the mood and close to buds that hang when the house
    /// is thirsty. A few clusters get a soft glow behind them.
    private func blossoms(_ c: GraphicsContext, _ p: Pose) {
        let B = p.recipe.bloom, g = p.g, open = p.open, sz = p.sz
        var dark = Path(), light = Path(), mid = Path(), budDark = Path(), budLight = Path()
        var glows: [(x: Double, y: Double, r: Double)] = []
        let kOpen = 0.35 + 0.65 * open, lx = Light.x, ly = Light.y
        let petals = B.kind == .star4 ? 4 : 5
        for cl in canopy.clusters where !cl.hidden {
            let cp = p.clumps[cl.clump]
            guard cp.rw >= 1 else { continue }
            let (cx, cy) = p.point(cp, cl.x, cl.y)
            var rad = 0.0
            for f in cl.flowers {
                let kf = Ink.back((g - f.birth) / 0.05)
                guard kf > 0 else { continue }
                let s0 = f.size * sz * kf * min(1, cp.vis * 1.2)
                let x = cx + cos(f.fa) * f.fd * f.size * sz, y = cy + sin(f.fa) * f.fd * f.size * sz
                rad = max(rad, f.fd * f.size * sz + s0)
                if open > 0.12 {
                    let s = s0 * kOpen
                    switch B.kind {
                    case .cup:
                        // Two outer petals, one centre petal and a deep blush at the base, upright.
                        let tl = sin(f.turn) * 0.25, up = -Double.pi / 2 + tl, (bx, by) = rotate(0, s * 0.38, tl)
                        dark.addPetal(x + bx, y + by, up - 0.42, s * 1.08, s * 0.46)
                        dark.addPetal(x + bx, y + by, up + 0.42, s * 1.08, s * 0.46)
                        light.addPetal(x + bx, y + by, up, s * 1.16, s * 0.5)
                        mid.addOval(x + bx * 0.55, y + by * 0.55, s * 0.3, s * 0.2, tl)
                    case .trumpet:
                        // A tube, three flared petals and a stamen.
                        let tl = sin(f.turn) * 0.35
                        dark.addPetal(x, y + s * 0.55, -Double.pi / 2 + tl, s * 1.05, s * 0.34)
                        let (bx, by) = rotate(0, -s * 0.35, tl)
                        for q in -1...1 { light.addPetal(x + bx, y + by, -Double.pi / 2 + tl + Double(q) * 0.8, s * 0.62, s * 0.44) }
                        let (mx, my) = rotate(0, -s * 0.45, tl)
                        mid.addDisc(x + mx, y + my, s * 0.14)
                    case .star4, .star5:
                        let a0 = f.turn
                        for q in 0..<petals { dark.addPetal(x, y, a0 + Double(q) * tau / Double(petals), s, s * B.pw) }
                        for q in 0..<petals {
                            light.addPetal(x + lx * 0.14 * s, y + ly * 0.14 * s, a0 + Double(q) * tau / Double(petals),
                                           s * 0.76, s * B.pw * 0.76)
                        }
                        mid.addDisc(x, y, s * 0.19)
                    }
                }
                if open < 0.6 {
                    let s = s0 * (1 - open)
                    let a = -Double.pi / 2 + sin(f.turn) * 0.4 + (.pi - 0.4) * (p.dry * 0.5 + p.sleep * 0.3) * (cos(f.turn) > 0 ? 1 : -1)
                    budDark.addPetal(x, y, a, s * 1.15, s * 0.5)
                    budLight.addPetal(x + lx * 0.12 * s, y + ly * 0.12 * s, a, s * 0.8, s * 0.3)
                }
            }
            if cl.glow, rad > 0, open > 0.15 { glows.append((cx, cy, rad * 2.1 + 3 * sz)) }
        }
        let alpha = (0.22 + 0.18 * p.night) * open * (1 - 0.5 * p.sleep), glow = B.glow.night(p.night * 0.5)
        for o in glows {
            var disc = Path()
            disc.addDisc(o.x, o.y, o.r)
            fill(c, disc, radial(o.x, o.y, o.r, [stop(glow, alpha, 0), stop(glow, 0, 1)]))
        }
        fill(c, dark, p.bloom(B.cols[0], 0.75))
        fill(c, light, p.bloom(B.cols[1], 0.75))
        fill(c, mid, p.bloom(B.cols[2], 0.75))
        fill(c, budDark, p.bloom(B.bud[0]))
        fill(c, budLight, p.bloom(B.bud[1]))
    }

    /// Fruit hangs on a stem below its clump, swinging a little off plumb.
    private func fruits(_ c: GraphicsContext, _ p: Pose) {
        guard let F = p.recipe.fruit else { return }
        let g = p.g, sz = p.sz, lx = Light.x, ly = Light.y
        var stem = Path(), body = Path(), shade = Path(), lite = Path(), spec = Path(), tip = Path()
        for f in canopy.fruit where !f.hidden {
            let cp = p.clumps[f.clump]
            guard cp.rw >= 1 else { continue }
            let kf = Ink.back((g - f.birth) / 0.05)
            guard kf > 0 else { continue }
            let (hx, hy) = p.point(cp, f.x, f.y)
            let s = f.size * sz * kf * (1 - 0.12 * p.dry) * min(1, cp.vis * 1.2)
            for q in 0..<f.k {
                let fan = f.k > 1 ? (Double(q) - Double(f.k - 1) / 2) * 0.55 : 0
                let psi = -p.lean * 2 + 0.1 * sin(f.phase + Double(q)) + fan
                let L = f.stem * sz + s * (F.kind == .olive ? 1.1 : 1)
                let fx = hx + sin(-psi) * L, fy = hy + cos(psi) * L
                stem.move(to: CGPoint(x: hx, y: hy))
                stem.addQuadCurve(to: CGPoint(x: fx + sin(-psi) * -s * 0.9, y: fy - cos(psi) * s * 0.9),
                                  control: CGPoint(x: hx, y: hy + L * 0.5))
                switch F.kind {
                case .pom:
                    body.addDisc(fx, fy, s)
                    // The crown, opposite the stem.
                    let cx = fx - sin(-psi) * -s * 0.95, cy = fy + cos(psi) * s * 0.95
                    tip.move(to: CGPoint(x: cx - s * 0.32, y: cy - s * 0.12))
                    tip.addLine(to: CGPoint(x: cx - s * 0.38, y: cy + s * 0.3))
                    tip.addLine(to: CGPoint(x: cx - s * 0.12, y: cy + s * 0.12))
                    tip.addLine(to: CGPoint(x: cx, y: cy + s * 0.36))
                    tip.addLine(to: CGPoint(x: cx + s * 0.12, y: cy + s * 0.12))
                    tip.addLine(to: CGPoint(x: cx + s * 0.38, y: cy + s * 0.3))
                    tip.addLine(to: CGPoint(x: cx + s * 0.32, y: cy - s * 0.12))
                    tip.closeSubpath()
                case .lemon:
                    body.addOval(fx, fy, s * 0.8, s * 1.02, -psi)
                    let (nx, ny) = rotate(0, s * 1.02, -psi)
                    tip.addDisc(fx + nx, fy + ny, s * 0.2)
                case .olive:
                    body.addOval(fx, fy, s * 0.8, s, -psi)
                }
                shade.addCrescent(fx, fy, s * 0.86, Light.shadow - 1.3, Light.shadow + 1.3, s * 0.34)
                lite.addOval(fx + lx * s * 0.36, fy + ly * s * 0.36, s * 0.32, s * 0.42, Light.angle + .pi / 2)
                spec.addDisc(fx + lx * s * 0.5, fy + ly * s * 0.5, s * 0.13)
            }
        }
        let shine = (0.55 + 0.45 * p.vig) * (1 - 0.6 * p.dry)
        func tone(_ i: Int) -> RGB { F.cols[i].shifted(scale: 1 - 0.45 * p.dry).night(p.night) }
        stroke(c, stem, p.wood(1), 1, max(0.8, 1.1 * sz))
        fill(c, body, tone(0))
        fill(c, shade, tone(1), 0.85)
        fill(c, lite, tone(2), 0.55 + 0.35 * shine)
        fill(c, tip, tone(4))
        fill(c, spec, tone(3), 0.85 * shine)
    }

    /// Single leaves breaking the silhouette, hanging when the house is
    /// thirsty and gone when it is dozing.
    private func edgeLeaves(_ c: GraphicsContext, _ p: Pose) {
        var dark = Path(), light = Path(), ribs = Path()
        let g = p.g, dry = p.dry, sleep = p.sleep
        for lf in canopy.leaves where !lf.hidden {
            let cp = p.clumps[lf.clump]
            guard cp.rw >= 1 else { continue }
            let k = Ink.back((g - lf.birth) / 0.06) * Ink.smooth((lf.keep - (dry * 0.35 + sleep * 0.4)) / 0.1 + 0.5)
            guard k > 0 else { continue }
            let a = lf.a + cp.rho, x = cp.x + cos(a) * cp.rw * lf.d, y = cp.y + sin(a) * cp.rw * lf.d * cp.sq
            let d = a + wrap(.pi / 2 - a) * (0.45 * dry + 0.35 * sleep) + 0.05 * sin(lf.phase)
            let s = lf.len * p.sz * k * (1 + 0.05 * p.vig - 0.12 * dry)
            let lit: Double = -sin(d) * Light.x + cos(d) * Light.y > 0 ? 1 : -1
            light.addLeafHalf(x, y, d, s, lf.w, lit)
            dark.addLeafHalf(x, y, d, s, lf.w, -lit)
            ribs.move(to: CGPoint(x: x + cos(d) * s * 0.1, y: y + sin(d) * s * 0.1))
            ribs.addLine(to: CGPoint(x: x + cos(d) * s * 1.35, y: y + sin(d) * s * 1.35))
        }
        let top: RGB, under: RGB
        if let own = p.recipe.edge.cols {
            top = own[0].mix(Canopy.dry[1], dry * 0.9).shifted(lightness: 0.08 * sleep, scale: 1 - 0.4 * sleep).night(p.night)
            under = own[1].mix(Canopy.dry[2], dry * 0.9).shifted(lightness: 0.06 * sleep, scale: 1 - 0.4 * sleep).night(p.night)
        } else {
            top = p.leaf(1, 2, green: true)
            under = p.leaf(2, 2, green: true)
        }
        fill(c, dark, top)
        fill(c, light, under)
        stroke(c, ribs, p.leaf(0, 1, green: true), 0.5, 0.7)
    }
}

// MARK: - Shapes

/// Every filled shape is traced clockwise on screen (increasing angle, y down),
/// so shapes that overlap in one batch union under the non-zero rule instead of
/// punching holes in each other. An arc always starts with a move to its first
/// point: `addArc` joins from the current point with a line.
private extension Path {
    mutating func addDisc(_ x: Double, _ y: Double, _ r: Double) {
        guard r > 0.05 else { return }
        move(to: CGPoint(x: x + r, y: y))
        addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .zero, endAngle: .radians(tau), clockwise: false)
    }

    /// An ellipse as four cubics, rotated by `a`.
    mutating func addOval(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ a: Double) {
        guard rx > 0.05, ry > 0.05 else { return }
        let k = 0.5523, c = cos(a), s = sin(a)
        func at(_ u: Double, _ v: Double) -> CGPoint { CGPoint(x: x + c * u - s * v, y: y + s * u + c * v) }
        move(to: at(rx, 0))
        addCurve(to: at(0, ry), control1: at(rx, k * ry), control2: at(k * rx, ry))
        addCurve(to: at(-rx, 0), control1: at(-k * rx, ry), control2: at(-rx, k * ry))
        addCurve(to: at(0, -ry), control1: at(-rx, -k * ry), control2: at(-k * rx, -ry))
        addCurve(to: at(rx, 0), control1: at(k * rx, -ry), control2: at(rx, -k * ry))
        closeSubpath()
    }

    /// A shadow crescent on a circle's edge between two angles, `t` thick in the middle.
    mutating func addCrescent(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ t: Double) {
        guard r > 0.3 else { return }
        let am = (a0 + a1) / 2
        let p0 = CGPoint(x: x + cos(a0) * r, y: y + sin(a0) * r), p1 = CGPoint(x: x + cos(a1) * r, y: y + sin(a1) * r)
        let mx = x + cos(am) * (r - t), my = y + sin(am) * (r - t)
        move(to: p0)
        addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
        addQuadCurve(to: p0, control: CGPoint(x: 2 * mx - (p0.x + p1.x) / 2, y: 2 * my - (p0.y + p1.y) / 2))
        closeSubpath()
    }

    /// An open arc, for stroking.
    mutating func addRim(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double) {
        guard r > 0.3 else { return }
        move(to: CGPoint(x: x + cos(a0) * r, y: y + sin(a0) * r))
        addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
    }

    /// A petal from its base along angle `a`: `len` long, `wid` its half-width scale.
    mutating func addPetal(_ x: Double, _ y: Double, _ a: Double, _ len: Double, _ wid: Double) {
        guard len > 0.2 else { return }
        let c = cos(a), s = sin(a), o = CGPoint(x: x, y: y)
        func at(_ u: Double, _ v: Double) -> CGPoint { CGPoint(x: x + c * u * len - s * v * wid, y: y + s * u * len + c * v * wid) }
        move(to: o)
        addCurve(to: at(1, 0), control1: at(0.05, -0.9), control2: at(0.85, -1.05))
        addCurve(to: o, control1: at(0.85, 1.05), control2: at(0.05, 0.9))
        closeSubpath()
    }

    /// Half a leaf, on side +1 or −1 of its midrib, traced clockwise either way.
    mutating func addLeafHalf(_ x: Double, _ y: Double, _ a: Double, _ s: Double, _ w: Double, _ side: Double) {
        guard s > 0.2 else { return }
        let c = cos(a), sn = sin(a), o = CGPoint(x: x, y: y)
        func at(_ u: Double, _ v: Double) -> CGPoint {
            CGPoint(x: x + c * u * s - sn * v * s * side * w, y: y + sn * u * s + c * v * s * side * w)
        }
        move(to: o)
        if side < 0 {
            addCurve(to: at(1.65, 0), control1: at(0.3, 0.55), control2: at(1.1, 0.5))
            addLine(to: o)
        } else {
            addLine(to: at(1.65, 0))
            addCurve(to: o, control1: at(1.1, 0.5), control2: at(0.3, 0.55))
        }
        closeSubpath()
    }

    /// A tapered limb: a quadratic centre line with round ends, up the left
    /// side and down the right.
    mutating func addLimb(_ x: Double, _ y: Double, _ cx: Double, _ cy: Double, _ x1: Double, _ y1: Double, _ w0: Double, _ w1: Double) {
        guard w0 > 0.1, hypot(x1 - x, y1 - y) >= 0.2 else { return }
        let a0 = atan2(cy - y, cx - x), a1 = atan2(y1 - cy, x1 - cx), am = atan2(y1 - y, x1 - x), wm = (w0 + w1) / 4
        move(to: CGPoint(x: x + sin(a0) * w0 / 2, y: y - cos(a0) * w0 / 2))
        addQuadCurve(to: CGPoint(x: x1 + sin(a1) * w1 / 2, y: y1 - cos(a1) * w1 / 2),
                     control: CGPoint(x: cx + sin(am) * wm, y: cy - cos(am) * wm))
        addArc(center: CGPoint(x: x1, y: y1), radius: w1 / 2,
               startAngle: .radians(a1 - .pi / 2), endAngle: .radians(a1 + .pi / 2), clockwise: false)
        addQuadCurve(to: CGPoint(x: x - sin(a0) * w0 / 2, y: y + cos(a0) * w0 / 2),
                     control: CGPoint(x: cx - sin(am) * wm, y: cy + cos(am) * wm))
        addArc(center: CGPoint(x: x, y: y), radius: w0 / 2,
               startAngle: .radians(a0 + .pi / 2), endAngle: .radians(a0 + .pi * 1.5), clockwise: false)
        closeSubpath()
    }

    /// The same limb moved across itself toward the light (`k` > 0) or away
    /// from it, and thinned to `f` of its width.
    mutating func addLimb(_ s: Wood, toward k: Double, width f: Double) {
        let am = atan2(s.y1 - s.y, s.x1 - s.x)
        var nx = sin(am), ny = -cos(am)
        if nx * Canopy.Light.x + ny * Canopy.Light.y < 0 { nx = -nx; ny = -ny }
        let wm = (s.w0 + s.w1) / 2
        addLimb(s.x + nx * k * s.w0, s.y + ny * k * s.w0, s.cx + nx * k * wm, s.cy + ny * k * wm,
                s.x1 + nx * k * s.w1, s.y1 + ny * k * s.w1, s.w0 * f, s.w1 * f)
    }
}
