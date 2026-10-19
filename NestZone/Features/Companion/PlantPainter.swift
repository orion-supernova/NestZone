import SwiftUI

/// A tree grown from a seed: the procedural plant from the prototype
/// (Docs/Companion/prototype/plant.html), ported to `Canvas`.
///
/// Nothing here is a picture. A branch is a curve with a width, a leaf is two
/// Bézier halves, a flower is five ellipses — the "parts kit", drawn once and
/// reused a few hundred times at different angles, sizes and colours. That is
/// what lets every leaf sway on its own, hang when the house has been quiet,
/// fall onto the soil, and lift again when somebody comes back.
struct PlantModel: Equatable, Sendable {
    struct Branch: Equatable, Sendable {
        var parent: Int?
        var angle: Double
        var length: Double
        var depth: Int
        var birth: Double
        var duration: Double
        var kids: [Int] = []
        var phase: Double
        var bend: Double
        /// Whether a decoration hangs here, and which colour.
        var ornament: Double
        var ornamentColor: Int
    }

    struct Leaf: Equatable, Sendable {
        var branch: Int
        var t: Double, side: Double, angle: Double, size: Double, hue: Double, light: Double, phase: Double
        var birth = 0.0
    }

    struct Bloom: Equatable, Sendable {
        var branch: Int
        var born: Double, hue: Double, size: Double, rotation: Double
        var isFruit: Bool
        var birth = 0.0
    }

    struct HSL: Equatable, Sendable {
        var h: Double, s: Double, l: Double
        init(_ h: Double, _ s: Double, _ l: Double) { self.h = h; self.s = s; self.l = l }
    }

    struct Params: Equatable, Sendable {
        var spread = 0.48, decay = 0.76, depth = 5, lean = 0.0, droop = 0.05, bend = 0.14
        var leafHue = 115.0, leafSaturation = 1.0, leafSize = 10.0, trunk = 12.0
        var bloom = HSL(338, 78, 76), pot = HSL(262, 28, 58)
        var band = 0
        var flowerShare = 0.55
        var fruit: HSL?
        var fruitShare = 0.0
    }

    var params: Params
    var branches: [Branch] = []
    var leaves: [Leaf] = []
    var blooms: [Bloom] = []
    /// Fallen leaves' resting places: half on the soil, half on the floor.
    var ground: [(x: Double, y: Double, rotation: Double, hue: Double, light: Double)] = []
    var fit = 1.0

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.params == rhs.params && lhs.branches == rhs.branches }

    /// Grows the whole tree from its seed. Cheap enough to do on appear, and
    /// the same seed always grows the same tree.
    init(seed: String, species: Species) {
        var r = Ink.Random(seed)
        var p = Params()
        p.spread = r.between(0.34, 0.62)
        p.decay = r.between(0.72, 0.8)
        p.depth = 5 + (r.next() < 0.5 ? 1 : 0)
        p.lean = (r.next() - 0.5) * 0.16
        p.droop = r.between(0.02, 0.08)
        p.bend = r.between(0.08, 0.2)
        p.leafHue = r.between(92, 138)
        p.leafSize = r.between(8.5, 11.5)
        p.trunk = r.between(11, 14)
        let blooms = [HSL(338, 78, 76), HSL(16, 88, 74), HSL(276, 62, 78), HSL(46, 92, 72), HSL(205, 72, 80), HSL(352, 74, 68)]
        p.bloom = r.pick(blooms)
        p.pot = r.pick([HSL(16, 52, 52), HSL(205, 30, 56), HSL(152, 22, 48), HSL(36, 42, 60), HSL(262, 28, 58)])
        p.band = Int(r.next() * 3)
        // Each species fixes what makes it itself; the seed does the rest.
        switch species {
        case .magnolia: p.bloom = HSL(332, 70, 80); p.flowerShare = 0.6
        case .cherry: p.bloom = HSL(345, 85, 86); p.flowerShare = 0.85; p.leafHue = 108
        case .pomegranate: p.bloom = HSL(8, 85, 58); p.flowerShare = 0.4; p.fruit = HSL(355, 68, 44); p.fruitShare = 0.3
        case .azalea: p.bloom = HSL(316, 75, 62); p.flowerShare = 0.75
        case .lemon: p.bloom = HSL(48, 45, 94); p.flowerShare = 0.35; p.fruit = HSL(52, 95, 58); p.fruitShare = 0.35; p.leafHue = 120
        case .olive: p.bloom = HSL(60, 30, 92); p.flowerShare = 0.12; p.leafHue = 88; p.leafSaturation = 0.55
            p.fruit = HSL(95, 30, 30); p.fruitShare = 0.4
        case .duckling: break
        }
        params = p
        grow(&r)
        place(&r)
    }

    private mutating func grow(_ r: inout Ink.Random) {
        let p = params
        func branch(parent: Int?, angle: Double, length: Double, depth: Int, birth: Double) {
            let index = branches.count
            branches.append(Branch(
                parent: parent, angle: angle, length: length, depth: depth, birth: birth,
                duration: r.between(0.8, 1.1), phase: r.next() * .pi * 2, bend: (r.next() - 0.5) * p.bend * 2,
                ornament: r.next(), ornamentColor: Int(r.next() * 4)
            ))
            if let parent { branches[parent].kids.append(index) }
            if depth >= 2 {
                let count = 2 + Int(r.next() * 3)
                for i in 0..<count {
                    leaves.append(Leaf(
                        branch: index, t: r.between(0.3, 0.95), side: i.isMultiple(of: 2) ? -1 : 1,
                        angle: r.between(0.55, 1.1), size: p.leafSize * r.between(0.75, 1.2),
                        hue: p.leafHue + r.between(-10, 10), light: r.between(-5, 5), phase: r.next() * .pi * 2
                    ))
                }
            }
            let end = birth + branches[index].duration
            if depth < p.depth {
                let duration = branches[index].duration
                // The leader carries on…
                branch(parent: index, angle: (r.next() - 0.5) * 0.24 + p.lean * 0.5,
                       length: length * r.between(p.decay, 0.86), depth: depth + 1, birth: end - 0.25 * duration)
                // …and laterals fork off it.
                let laterals = depth == 0 ? 2 : (r.next() < 0.35 ? 2 : 1)
                for i in 0..<laterals {
                    let side: Double = (depth + i) % 2 == 1 ? 1 : -1
                    if depth > 1, r.next() < 0.16 { continue }
                    branch(parent: index, angle: side * (p.spread * r.between(0.75, 1.25) + p.droop * Double(depth)),
                           length: length * p.decay * r.between(0.72, 0.94), depth: depth + 1,
                           birth: end - 0.15 * duration + r.next() * 0.3)
                }
            } else {
                leaves.append(Leaf(branch: index, t: 1, side: 0, angle: 0, size: p.leafSize * 1.1, hue: p.leafHue,
                                   light: 3, phase: r.next() * .pi * 2))
                let roll = r.next()
                if roll < p.fruitShare {
                    blooms.append(Bloom(branch: index, born: r.next(), hue: p.fruit?.h ?? 0, size: r.between(4, 6),
                                        rotation: r.next() * .pi * 2, isFruit: true))
                } else if roll < p.fruitShare + p.flowerShare {
                    blooms.append(Bloom(branch: index, born: r.next(), hue: p.bloom.h + r.between(-8, 8),
                                        size: r.between(5.5, 8.5), rotation: r.next() * .pi * 2, isFruit: false))
                }
            }
        }
        branch(parent: nil, angle: p.lean, length: 50, depth: 0, birth: 0)
        // Squeeze every birth into the growth window: seed 0–.08, wood .08–.84,
        // blossom .86–.96.
        let maxEnd = branches.map { $0.birth + $0.duration }.max() ?? 1
        let k = 0.76 / maxEnd
        for i in branches.indices {
            branches[i].birth = 0.08 + branches[i].birth * k
            branches[i].duration *= k
        }
        for i in leaves.indices {
            let b = branches[leaves[i].branch]
            leaves[i].birth = b.birth + b.duration * leaves[i].t * 0.9 + 0.012
        }
        for i in blooms.indices {
            blooms[i].birth = (blooms[i].isFruit ? 0.9 : 0.86) + blooms[i].born * (blooms[i].isFruit ? 0.07 : 0.1)
        }
    }

    private mutating func place(_ r: inout Ink.Random) {
        ground = []
        for i in 0..<16 {
            let onFloor = i.isMultiple(of: 2)
            let side: Double = r.next() < 0.5 ? -1 : 1
            let x: Double = onFloor ? side * r.between(52, 86) : r.between(-40, 40)
            let y: Double = onFloor ? r.between(62, 70) : r.between(-4, 1)
            let rotation: Double = r.next() * .pi * 2
            let hue: Double = onFloor ? r.between(28, 50) : r.between(30, 52)
            let light: Double = onFloor ? r.between(36, 50) : r.between(38, 52)
            ground.append((x: x, y: y, rotation: rotation, hue: hue, light: light))
        }
        // Measure the grown tree once, then fit it to the scene: 234 tall and
        // 165 either side of the trunk.
        let grown = layout(progress: 1, mood: 0.85, time: 0, wind: 0, wobble: 0, fit: 1)
        fit = min(1, 234 / max(-grown.top, 1), 165 / max(max(-grown.left, grown.right), 1))
    }
}

// MARK: - Layout, every frame

extension PlantModel {
    /// One branch as drawn this frame: a quadratic curve and its base width.
    struct Segment {
        var x: Double, y: Double, x1: Double, y1: Double, cx: Double, cy: Double, width: Double, grown: Double
    }

    struct Pose {
        var segments: [Segment?]
        var left = 0.0, right = 0.0, top = 0.0
    }

    /// How far a mood has gone towards wilting: 0 while cared for, 1 after a
    /// long quiet stretch.
    static func wilt(_ mood: Double) -> Double { Ink.smooth((0.72 - mood) / 0.6) }

    /// Where every branch is at this instant. Angles are relative, so sway on
    /// the trunk carries everything above it; a quiet house hangs each branch
    /// outwards and down, and a bright one lifts it.
    func layout(progress p: Double, mood: Double, time: Double, wind: Double, wobble: Double, fit: Double? = nil) -> Pose {
        let scale = fit ?? self.fit
        var pose = Pose(segments: Array(repeating: nil, count: branches.count))
        var ends = Array(repeating: (x: 0.0, y: 0.0, angle: -Double.pi / 2), count: branches.count)
        let gust = max(0, (sin(time * 0.7) + 0.5 * sin(time * 1.9 + 1) + 0.8 * sin(time * 0.23 + 2)) / 2.3)
        let wilt = Self.wilt(mood)
        var first = true
        for (i, b) in branches.enumerated() {
            let start: (x: Double, y: Double, angle: Double)
            if let parent = b.parent {
                guard pose.segments[parent] != nil else { continue }
                start = ends[parent]
            } else {
                start = (0, 0, -Double.pi / 2)
            }
            let g = Ink.ease((p - b.birth) / b.duration)
            guard g > 0 else { continue }
            let m = Ink.clamp((p - b.birth) / (1 - b.birth))
            let d = Double(b.depth)
            let side: Double = b.angle > 0 ? 1 : b.angle < 0 ? -1 : (b.depth % 2 == 1 ? 1 : -1)
            let breeze: Double = sin(time * 1.25 - d * 0.55 + b.phase * 0.3) * 0.03 + gust * 0.05
            let sway: Double = wind * (0.4 + d * 0.25) * breeze * (1.5 - 0.6 * p) + wobble * (0.25 + d * 0.12)
            let lean: Double = params.lean >= 0 ? 1 : -1
            let slump: Double = b.depth == 0 ? lean * wilt * 0.16 : 0
            let droop: Double = wilt * 0.95 * (d / 6 + 0.06)
            let lift: Double = max(0, mood - 0.82) * 0.5 * (d / 6)
            let sag: Double = side * (droop - lift) + slump
            let angle = start.angle + b.angle * Ink.lerp(0.35, 1, g) + sway + sag
            let length = b.length * g * (0.8 + 0.2 * p) * scale
            let x1 = start.x + cos(angle) * length, y1 = start.y + sin(angle) * length
            let cx = (start.x + x1) / 2 - sin(angle) * b.bend * length
            let cy = (start.y + y1) / 2 + cos(angle) * b.bend * length
            let width = max(0.9, params.trunk * pow(0.7, d) * Ink.lerp(0.3, 1, m) * (0.55 + 0.45 * g) * scale)
            pose.segments[i] = Segment(x: start.x, y: start.y, x1: x1, y1: y1, cx: cx, cy: cy, width: width, grown: g)
            ends[i] = (x1, y1, atan2(y1 - cy, x1 - cx))
            if first {
                pose.left = x1; pose.right = x1; pose.top = y1; first = false
            } else {
                pose.left = min(pose.left, x1); pose.right = max(pose.right, x1); pose.top = min(pose.top, y1)
            }
        }
        return pose
    }

    static func point(_ s: Segment, _ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * s.x + 2 * u * t * s.cx + t * t * s.x1, y: u * u * s.y + 2 * u * t * s.cy + t * t * s.y1)
    }

    static func tangent(_ s: Segment, _ t: Double) -> Double {
        atan2(2 * (1 - t) * (s.cy - s.y) + 2 * t * (s.y1 - s.cy), 2 * (1 - t) * (s.cx - s.x) + 2 * t * (s.x1 - s.cx))
    }

    /// Tips of branches with nothing grown above them: where lights hang and a
    /// star finds the top.
    func tips(_ pose: Pose) -> [Int] {
        branches.indices.filter { i in
            pose.segments[i] != nil && branches[i].depth >= 2 && branches[i].kids.allSatisfy { pose.segments[$0] == nil }
        }
    }
}

// MARK: - Drawing

/// Paints the tree for one frame, in the tree's own coordinates: the base of
/// the trunk at the origin, up is negative.
struct PlantPainter {
    let model: PlantModel
    let frame: SceneFrame
    let pose: PlantModel.Pose

    private var day: Double { frame.day }

    /// The clock tints everything dimmer and cooler after dark.
    func tint(_ h: Double, _ s: Double, _ l: Double, _ a: Double = 1) -> Color {
        let dh = ((240 - h + 540).truncatingRemainder(dividingBy: 360)) - 180
        return Ink.hsl(h + dh * 0.1 * (1 - day), s * (0.6 + 0.4 * day), l * (0.56 + 0.44 * day), a)
    }

    func draw(_ context: GraphicsContext) {
        let mood = frame.mood, p = frame.progress
        if p > 0.9 {
            // In bloom: a glow in the flowers' own colour, brighter when happy.
            let k = Ink.smooth((p - 0.9) / 0.08) * (0.4 + 0.6 * mood)
            let cy = pose.top * 0.6
            context.glow(0, cy, 150, tint(model.params.bloom.h, 80, 70, 0.16 * k))
        }
        seed(context)
        // Branches, each with a highlight on the side facing the light.
        let bark = tint(24, 34 - (1 - mood) * 8, 29 + (1 - mood) * 6)
        let barkLight = tint(28, 40, 46, 0.55)
        for segment in pose.segments.compactMap({ $0 }) {
            let tip = max(0.6, segment.width * 0.7)
            context.fill(limb(segment, tip: tip), with: .color(bark))
            var light = segment
            let ox = segment.width * 0.2, oy = segment.width * 0.12
            light.x -= ox; light.x1 -= ox; light.cx -= ox
            light.y -= oy; light.y1 -= oy; light.cy -= oy
            light.width = segment.width * 0.3
            context.fill(limb(light, tip: tip * 0.3), with: .color(barkLight))
        }
        seedLeaves(context)
        leaves(context)
        blooms(context)
    }

    /// The seed, wobbling before it cracks.
    private func seed(_ context: GraphicsContext) {
        let k = 1 - Ink.smooth((frame.progress - 0.085) / 0.04)
        guard k > 0 else { return }
        var c = context
        c.translateBy(x: 0, y: -3)
        let wobble = frame.reduceMotion ? 0 : sin(frame.time * 9) * 0.14 * Ink.smooth((frame.progress - 0.03) / 0.05)
        c.rotate(by: .radians(wobble))
        c.scaleBy(x: k, y: k)
        var shell = c
        shell.rotate(by: .radians(-0.3))
        shell.ellipse(0, 0, 7, 4.5, .color(tint(30, 45, 40)))
        shell.ellipse(-2, -1.5, 2.6, 1.2, .color(tint(34, 50, 60, 0.7)))
    }

    /// The two seed leaves, which fall away as the tree grows.
    private func seedLeaves(_ context: GraphicsContext) {
        guard let root = pose.segments.first ?? nil else { return }
        let k = Ink.back((frame.progress - 0.09) / 0.05) * (1 - Ink.smooth((frame.progress - 0.3) / 0.1))
        guard k > 0 else { return }
        for side in [-1.0, 1] {
            leaf(context, x: root.x1, y: root.y1,
                 angle: -.pi / 2 + side * (1.05 + (1 - frame.mood) * 0.5) + sin(frame.time * 2) * 0.05 * frame.wind,
                 size: 7 * k, hue: 108, light: 6)
        }
    }

    private func leaves(_ context: GraphicsContext) {
        let mood = frame.mood, wilt = PlantModel.wilt(mood)
        let wind = frame.reduceMotion ? 0 : frame.wind
        for leaf in model.leaves {
            guard let segment = pose.segments[leaf.branch] else { continue }
            let k = Ink.back((frame.progress - leaf.birth) / 0.06)
            guard k > 0 else { continue }
            // A wilting plant lets its leaves go; they lie on the soil instead.
            if leaf.phase / (.pi * 2) < wilt * 0.5 { continue }
            let at = PlantModel.point(segment, leaf.t)
            let base = PlantModel.tangent(segment, leaf.t) + leaf.side * leaf.angle * (1 - max(0, mood - 0.85) * 2)
            let hang = Double.pi / 2 + leaf.side * 0.35
            let turn = ((hang - base).truncatingRemainder(dividingBy: .pi * 2) + .pi * 3).truncatingRemainder(dividingBy: .pi * 2) - .pi
            let angle = base + turn * wilt * 0.8
                + sin(frame.time * (2.1 + leaf.phase * 0.2) + leaf.phase) * 0.13 * wind * (1 - wilt * 0.7)
            self.leaf(context, x: at.x, y: at.y, angle: angle,
                      size: leaf.size * k * (0.72 + 0.28 * frame.progress) * (0.8 + 0.2 * mood),
                      hue: leaf.hue, light: leaf.light)
        }
    }

    /// One leaf: two Bézier halves and a vein. Mood is in the colour: deep
    /// green when bright, through olive to straw when the house is quiet.
    func leaf(_ context: GraphicsContext, x: Double, y: Double, angle: Double, size s: Double, hue: Double, light: Double) {
        var c = context
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(angle))
        let mood = frame.mood, dry = pow(1 - mood, 1.15)
        let saturation = (48 * (0.32 + 0.68 * mood) + (mood > 0.85 ? 12 : 0)) * model.params.leafSaturation
        let lightness = light - x / 40 + dry * 7 - (mood > 0.85 ? 2 : 0)
        let h = hue - dry * 64
        var lower = Path()
        lower.move(to: .zero)
        lower.addCurve(to: CGPoint(x: s * 1.65, y: 0), control1: CGPoint(x: s * 0.3, y: s * 0.55), control2: CGPoint(x: s * 1.1, y: s * 0.5))
        lower.closeSubpath()
        c.fill(lower, with: .color(tint(h, saturation, 30 + lightness)))
        var upper = Path()
        upper.move(to: .zero)
        upper.addCurve(to: CGPoint(x: s * 1.65, y: 0), control1: CGPoint(x: s * 0.3, y: -s * 0.55), control2: CGPoint(x: s * 1.1, y: -s * 0.5))
        upper.closeSubpath()
        c.fill(upper, with: .color(tint(h - 8, saturation + 8, 43 + lightness)))
        if dry > 0.45 {
            c.ellipse(s * 1.45, 0, s * 0.25, s * 0.16, .color(tint(28, 45, 30, 0.55 * (dry - 0.45) * 2)))
        }
        var vein = Path()
        vein.move(to: CGPoint(x: s * 0.1, y: 0))
        vein.addLine(to: CGPoint(x: s * 1.35, y: 0))
        c.stroke(vein, with: .color(tint(h, 40, 22, 0.55)), lineWidth: 0.8)
    }

    /// Flowers close to buds as the house goes quiet, and open again when it
    /// comes back. Fruit stays put; it just loses its shine.
    private func blooms(_ context: GraphicsContext) {
        let mood = frame.mood, wilt = PlantModel.wilt(mood)
        let wind = frame.reduceMotion ? 0 : frame.wind
        let open = Ink.smooth((mood - 0.22) / 0.4)
        for bloom in model.blooms {
            guard let segment = pose.segments[bloom.branch] else { continue }
            let k = Ink.back((frame.progress - bloom.birth) / 0.05)
            guard k > 0 else { continue }
            if bloom.isFruit {
                fruit(context, x: segment.x1, y: segment.y1 + 4, size: bloom.size * k)
                continue
            }
            if open > 0.12 {
                flower(context, x: segment.x1, y: segment.y1, size: bloom.size, hue: bloom.hue,
                       rotation: bloom.rotation + sin(frame.time * 0.8 + bloom.rotation) * 0.12 * wind, scale: k * (0.35 + 0.65 * open))
            }
            if open < 0.6 {
                let t = PlantModel.tangent(segment, 1)
                let turn = ((Double.pi / 2 - t).truncatingRemainder(dividingBy: .pi * 2) + .pi * 3).truncatingRemainder(dividingBy: .pi * 2) - .pi
                bud(context, x: segment.x1, y: segment.y1, size: bloom.size, hue: bloom.hue, angle: t + turn * wilt * 0.7, scale: k * (1 - open))
            }
        }
    }

    func flower(_ context: GraphicsContext, x: Double, y: Double, size s: Double, hue: Double, rotation: Double, scale: Double) {
        let bloom = model.params.bloom
        let saturation = bloom.s * (0.4 + 0.6 * frame.mood)
        var c = context
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(rotation))
        c.scaleBy(x: scale, y: scale)
        for _ in 0..<5 {
            c.rotate(by: .radians(.pi * 2 / 5))
            c.ellipse(s * 0.6, 0, s * 0.62, s * 0.42, .color(tint(hue, saturation, bloom.l - 8)))
            c.ellipse(s * 0.7, -s * 0.06, s * 0.38, s * 0.22, .color(tint(hue, saturation, bloom.l + 8, 0.85)))
        }
        c.circle(0, 0, s * 0.3, .color(tint(44, 92, 58)))
    }

    private func bud(_ context: GraphicsContext, x: Double, y: Double, size s: Double, hue: Double, angle: Double, scale: Double) {
        let bloom = model.params.bloom, mood = frame.mood
        var c = context
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(angle))
        c.scaleBy(x: scale, y: scale)
        c.ellipse(s * 0.55, 0, s * 0.6, s * 0.32, .color(tint(hue - 10 * (1 - mood), bloom.s * (0.25 + 0.55 * mood), bloom.l - 20 - (1 - mood) * 10)))
        var sepal = Path()
        sepal.move(to: .zero)
        sepal.addLine(to: CGPoint(x: s * 0.45, y: -s * 0.32))
        sepal.addLine(to: CGPoint(x: s * 0.3, y: 0))
        sepal.addLine(to: CGPoint(x: s * 0.45, y: s * 0.32))
        sepal.closeSubpath()
        c.fill(sepal, with: .color(tint(model.params.leafHue - 40 * (1 - mood), 30, 32)))
    }

    private func fruit(_ context: GraphicsContext, x: Double, y: Double, size: Double) {
        guard let fruit = model.params.fruit else { return }
        let shine = 0.5 + 0.5 * frame.mood
        context.circle(x, y, size, .color(tint(fruit.h, fruit.s * shine, fruit.l)))
        context.circle(x - size * 0.35, y - size * 0.35, size * 0.3, .color(tint(fruit.h, fruit.s * 0.4, min(fruit.l + 30, 95), 0.7 * shine)))
    }

    /// A branch: a tapered quadratic curve with round ends.
    private func limb(_ s: PlantModel.Segment, tip w1: Double) -> Path {
        let a0 = atan2(s.cy - s.y, s.cx - s.x), a1 = atan2(s.y1 - s.cy, s.x1 - s.cx), am = atan2(s.y1 - s.y, s.x1 - s.x)
        let w0 = s.width, wm = (w0 + w1) / 4
        var path = Path()
        path.move(to: CGPoint(x: s.x - sin(a0) * w0 / 2, y: s.y + cos(a0) * w0 / 2))
        path.addQuadCurve(to: CGPoint(x: s.x1 - sin(a1) * w1 / 2, y: s.y1 + cos(a1) * w1 / 2),
                          control: CGPoint(x: s.cx - sin(am) * wm, y: s.cy + cos(am) * wm))
        path.addArc(center: CGPoint(x: s.x1, y: s.y1), radius: w1 / 2,
                    startAngle: .radians(a1 + .pi / 2), endAngle: .radians(a1 - .pi / 2), clockwise: true)
        path.addQuadCurve(to: CGPoint(x: s.x + sin(a0) * w0 / 2, y: s.y - cos(a0) * w0 / 2),
                          control: CGPoint(x: s.cx + sin(am) * wm, y: s.cy - cos(am) * wm))
        path.addArc(center: CGPoint(x: s.x, y: s.y), radius: w0 / 2,
                    startAngle: .radians(a0 - .pi / 2), endAngle: .radians(a0 + .pi / 2), clockwise: true)
        path.closeSubpath()
        return path
    }
}
