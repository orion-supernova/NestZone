import SwiftUI

// The stalk: one stem that climbs and puts out leaves in turn, a bud at its
// tip, then a bloom that opens. A sunflower is this rule; a daisy or a tulip
// is the same stem with another bloom.
//
// Growth: the seed (to .1), two seed leaves and a shoot (.1), the first true
// leaves (.28), a leaf at every hand's width (.5), the bud (.6 to .8), petals
// showing (.82), the head opening (.84 to .98). A thirsty one bends at the top
// and lets its leaves hang and its head hang forward; a dozing one is bowed.
extension PlantPainter {
    /// Leaves up the stem: how high, when it is born, how long.
    private static let nodes: [(height: Double, born: Double, length: Double)] = [
        (20, 0.15, 42), (46, 0.27, 54), (70, 0.36, 56), (94, 0.47, 52), (120, 0.6, 46), (142, 0.72, 38),
    ]

    func stalk(_ c: GraphicsContext?, _ m: inout Marks) {
        let side = seed.side, wilt = self.wilt
        let rise = grown([(0.09, 0), (0.12, 14), (0.3, 58), (0.52, 105), (0.76, 150), (0.9, 168), (1, 172)]) * (plan.height - 33) / 172
        // A young stem stands straight. As it tires it bends over at the top,
        // the way it leans: the control stays high, the tip goes out and down.
        let bendIn = Ink.smooth((p - 0.28) / 0.3)
        let tip = CGPoint(x: seed.lean * 5 * bendIn + side * wilt * 0.46 * rise, y: -rise * (1 - 0.3 * wilt))
        let control = CGPoint(x: seed.lean * 3 * bendIn, y: -rise * 0.82)
        let spine = Self.quad(CGPoint(x: 0, y: 1), control, tip, n: 22)
        let width = Ink.lerp(3.2, 7.2, Ink.smooth(p / 0.9)) * (1 - 0.18 * wilt)
        let stem = Self.ribbon(spine, width, width * 0.62)

        /// The stem's point at a height above the soil.
        func onStem(_ height: Double) -> CGPoint {
            for i in 1..<spine.count where -spine[i].y >= height {
                let a = spine[i - 1], b = spine[i]
                let t = (height + a.y) / max(0.001, a.y - b.y)
                return CGPoint(x: Ink.lerp(a.x, b.x, t), y: -height)
            }
            return spine[spine.count - 1]
        }

        // The seed leaves, which give way to the true ones.
        let seedLeaf = pop(0.1, over: 0.06) * (1 - Ink.smooth((p - 0.3) / 0.12))
        if seedLeaf > 0.02, let c {
            for s in [-1.0, 1] {
                let leaf = Self.blade(at: CGPoint(x: 0, y: -2), angle: s > 0 ? -0.3 + wilt * 0.8 : -.pi + 0.3 - wilt * 0.8,
                                      length: 17 * seedLeaf, halfWidth: 6 * seedLeaf, widest: 0.5, bend: s * (0.25 + wilt * 0.7))
                paint(c, leaf: leaf, tier: 2)
                m.note(leaf.tip)
            }
        }

        // Leaves behind the stem, the stem, then the leaves in front of it.
        for tier in 0..<3 {
            if tier == 1, let c {
                paint(c, stem: stem, along: spine, width: width)
                // The stem has fine hairs, like a gouache brush dragged up it.
                var hairs = Path()
                for i in stride(from: 1, to: spine.count - 1, by: 2) {
                    let q = spine[i]
                    hairs.move(to: CGPoint(x: q.x + width * 0.1, y: q.y))
                    hairs.addLine(to: CGPoint(x: q.x + width * 0.1 + 1.3 * side, y: q.y - 2.2))
                }
                c.stroke(hairs, with: .color(ramp[4].color(0.38)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
            }
            for (i, node) in Self.nodes.enumerated() where i % 3 == tier {
                let k = pop(node.born, over: 0.09)
                guard k > 0.02, rise > node.height else { continue }
                let s = (i.isMultiple(of: 2) ? 1.0 : -1.0) * side
                let base = onStem(node.height)
                let length = node.length * k * (1 - 0.14 * wilt) * seed.between(i, 0.92, 1.08)
                let out = s > 0 ? -0.5 : -.pi + 0.5
                let angle = out + s * (wilt * 1.45 + seed.between(i + 8, -0.12, 0.12))
                let direction = CGPoint(x: cos(angle), y: sin(angle))
                let petiole = CGPoint(x: base.x + direction.x * 7 * k, y: base.y + direction.y * 7 * k)
                let leaf = Self.blade(at: petiole, angle: angle, length: length, halfWidth: length * plan.leafWidth,
                                      widest: plan.widest, bend: s * (0.28 + 0.9 * wilt))
                if let c {
                    c.fill(Self.ribbon([base, petiole], 2.4 * k, 2 * k), with: .color(ramp[1].color()))
                    paint(c, leaf: leaf, tier: tier)
                }
                m.note(leaf.tip)
                m.note(CGPoint(x: (petiole.x + leaf.tip.x) / 2, y: (petiole.y + leaf.tip.y) / 2), reach: length * 0.2, hang: false)
            }
        }
        m.note(CGPoint(x: spine[spine.count - 1].x, y: spine[spine.count - 1].y), reach: 4, hang: false)

        // The bud, and then the head.
        let budK = since(0.6, over: 0.24)
        guard budK > 0.02, rise > 100 else { return }
        let tangent = atan2(tip.y - control.y, tip.x - control.x)
        let heading = CGPoint(x: cos(tangent), y: sin(tangent))
        let open = Ink.smooth((p - 0.84) / 0.14)
        let petal = open * (0.55 + 0.45 * M.open)
        let discR = Ink.lerp(4.5 + 5 * budK, 19, Ink.smooth((p - 0.8) / 0.18))
        let centre = CGPoint(x: tip.x + heading.x * discR * 0.7, y: tip.y + heading.y * discR * 0.7)
        let reach = discR + 33 * petal + 2
        m.note(CGPoint(x: centre.x, y: centre.y), reach: reach, hang: false)
        if let c { head(c, at: centre, radius: discR, petal: petal, bud: budK) }
    }

    /// The head, seen from the front and turned a little: green sepals, two
    /// rings of petals, the dark disc and its spiral of seeds. It turns away
    /// and its petals shorten as the house goes quiet.
    private func head(_ c: GraphicsContext, at centre: CGPoint, radius R: Double, petal: Double, bud: Double) {
        guard let flower = plan.flower else { return }
        var h = c
        h.translateBy(x: centre.x, y: centre.y)
        h.rotate(by: .radians(seed.side * (0.22 + wilt * 1.2 + M.doze * 0.3)))
        h.scaleBy(x: 1, y: 0.94)

        // Sepals, behind everything: green, pointed, drawing in as the head opens.
        let sepalLen = Ink.lerp(R * 1.7, R + 7, Ink.smooth(petal * 2))
        var sepals = Path(), litSepals = Path()
        let spikes = 12
        for i in 0..<spikes {
            let a = Double(i) / Double(spikes) * .pi * 2 + 0.12
            sepals.leaf(0, 0, cos(a), sin(a), sepalLen, R * 0.34, 0)
            litSepals.leaf(-0.6, -0.8, cos(a), sin(a), sepalLen * 0.86, R * 0.2, 0)
        }
        h.fill(sepals, with: .color(ramp[1].color()))
        h.fill(litSepals, with: .color(ramp[3].color(0.9)))

        // Petals: an outer ring and a shorter, brighter one in front.
        if petal > 0.03 {
            let deep = bloom(flower.deep), mid = bloom(flower.mid), pale = bloom(flower.pale)
            let n = flower.petals
            let length = (38 * petal) * (1 - 0.18 * M.thirst) + 2
            let outerGradient = Gradient(colors: [deep.color(), mid.color(), mid.mix(pale, 0.4).color()])
            let innerGradient = Gradient(colors: [deep.mix(mid, 0.4).color(), mid.mix(pale, 0.3).color(), pale.color()])
            for (ring, gradient) in [(0, outerGradient), (1, innerGradient)] {
                var petals = Path(), creases = Path()
                let count = ring == 0 ? n : n - 1
                let reach = ring == 0 ? length : length * 0.8
                for i in 0..<count {
                    let a = (Double(i) + (ring == 0 ? 0 : 0.5)) / Double(count) * .pi * 2 + seed.side * 0.06
                    let wobble = seed.between(i * 2 + ring, 0.92, 1.08)
                    let x = cos(a) * R * 0.6, y = sin(a) * R * 0.6
                    petals.leaf(x, y, cos(a), sin(a), reach * wobble, 7.6 * (0.6 + 0.4 * petal), 0.1)
                    creases.move(to: CGPoint(x: x + cos(a) * 3, y: y + sin(a) * 3))
                    creases.addLine(to: CGPoint(x: x + cos(a) * reach * wobble * 0.8, y: y + sin(a) * reach * wobble * 0.8))
                }
                h.fill(petals, with: .radialGradient(gradient, center: .zero, startRadius: R * 0.5, endRadius: R + reach))
                h.stroke(creases, with: .color(deep.shifted(-8).color(0.45)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
            }
        }

        // The disc: green while it is a bud, brown once it opens.
        let ripe = Ink.smooth((p - 0.82) / 0.14)
        let rim = bloom(0x7A5230, dim: 0.5).mix(ramp[2], 1 - ripe), core = bloom(flower.heart, dim: 0.5).mix(ramp[1], 1 - ripe)
        h.fill(Path(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2)), with: .radialGradient(
            Gradient(colors: [rim.shifted(8).color(), rim.color(), core.color()]),
            center: CGPoint(x: -R * 0.28, y: -R * 0.32), startRadius: 0, endRadius: R * 1.25))
        if ripe > 0.2 {
            var seeds = Path()
            let golden = 2.39996
            for i in 1...30 {
                let r = R * 0.88 * (Double(i) / 30).squareRoot(), a = Double(i) * golden
                let s = 0.8 + 0.5 * Double(i) / 30
                seeds.addEllipse(in: CGRect(x: cos(a) * r - s, y: sin(a) * r - s, width: s * 2, height: s * 2))
            }
            h.fill(seeds, with: .color(bloom(0x9A6C3A, dim: 0.5).color(0.7 * ripe)))
            var shine = Path()
            shine.addArc(center: .zero, radius: R * 0.86, startAngle: .radians(.pi * 0.9), endAngle: .radians(.pi * 1.5), clockwise: false)
            h.stroke(shine, with: .color(Color.white.opacity(0.22 * ripe)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}
