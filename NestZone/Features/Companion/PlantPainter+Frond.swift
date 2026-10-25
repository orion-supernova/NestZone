import SwiftUI

// The frond: a fountain of long arching fronds from one crown, the middle ones
// nearly upright and the outer ones bowing over the pot's rim. A fern is this
// rule.
//
// A frond is one cached shape (`FrondShape`: a rachis and, closely packed along
// it, many narrow serrated pinnae that shorten to a fine tip), placed with a
// transform and four fills. Its body is toned by how it faces the light; the
// pinnae on the side towards the light (the upper side of a bowing frond) are
// lighter and the others a tone darker, so an arch has a lit back and a dark
// underside.
//
// What makes it a fern is the young ones: a frond comes up as a fiddlehead, a
// bronze coil on a short stalk, and unrolls as it grows, the coil at its tip
// getting smaller until it is gone. The first things to show (.1 to .3) are
// croziers in the soil, and a grown fern keeps two uncurling at its centre
// because a fern is always making new ones.
//
// A thirsty one lets the fronds bow further, a dozing one is folded down.
extension PlantPainter {
    private struct Frond {
        var u: Double
        var born: Double
        var length: Double
        var tier: Int
    }

    func frond(_ c: GraphicsContext?, _ m: inout Marks) {
        let side = seed.side, wilt = self.wilt
        let count = plan.basal
        // Centre first: the order they come up in.
        let order = (0..<count).sorted { abs(Double($0) / Double(count - 1) * 2 - 1) < abs(Double($1) / Double(count - 1) * 2 - 1) }
        var fronds: [Frond] = []
        for (rank, i) in order.enumerated() {
            // More of them stand near the middle than lean out: a vase, not a fan.
            let raw = Double(i) / Double(count - 1) * 2 - 1
            let u = (raw < 0 ? -1.0 : 1.0) * pow(abs(raw), 1.3) * side
            let a = abs(u)
            fronds.append(Frond(u: u, born: 0.1 + 0.05 * Double(rank), length: plan.height * (1.18 + 0.2 * a) * seed.between(i, 0.94, 1.06), tier: a < 0.34 ? 0 : a < 0.7 ? 1 : 2))
        }
        var tiers = [LeafBatch(), LeafBatch(), LeafBatch()]
        var darks = [Path(), Path(), Path()], rachises = [Path(), Path(), Path()]
        var coils = Path(), fuzz = Path()

        for (n, f) in fronds.enumerated() {
            let r = Ink.smooth((p - f.born) / 0.46)
            guard r > 0.02 else { continue }
            let dir = f.u >= 0 ? 1.0 : (f.u < 0 ? -1.0 : seed.side)
            let a = abs(f.u)
            // How far the rachis turns over its length: a little for the
            // upright ones, past a right angle for the outer ones; and a tired
            // house bows them further.
            let total = (0.4 + 1.5 * a * a + 0.5 * a) * (0.6 + 0.4 * r) + wilt * (0.5 + 0.7 * a)
            let start = -.pi / 2 + dir * (0.04 + 0.34 * a) * (0.7 + 0.3 * r)
            let bend = dir * total
            let shape = FrondShape.of(bend: bend, reach: r)
            let unrolled: Double = r / shape.reach
            let settle: Double = 0.7 + 0.3 * min(1, r * 1.6)
            let length: Double = f.length * unrolled * (1 - 0.1 * wilt) * settle
            let base = CGPoint(x: f.u * 4, y: 1)
            let t = CGAffineTransform(translationX: base.x, y: base.y).rotated(by: start).scaledBy(x: length, y: length)
            // The way the middle of it faces, to pick the lit side.
            let mid = start + bend * shape.reach * 0.5
            let flip: Double = bend >= 0 ? 1 : -1
            let upperLit = flip * (sin(mid) * L.x - cos(mid) * L.y) >= 0
            let bri = bright(mid, luck: luck(n + 20), tier: f.tier)
            if c != nil {
                if bri < 0.36 { tiers[f.tier].shade.addPath(shape.body, transform: t) }
                else if bri < 0.68 { tiers[f.tier].mid.addPath(shape.body, transform: t) }
                else { tiers[f.tier].lit.addPath(shape.body, transform: t) }
                tiers[f.tier].halves.addPath(upperLit ? shape.upper : shape.lower, transform: t)
                darks[f.tier].addPath(upperLit ? shape.lower : shape.upper, transform: t)
                rachises[f.tier].addPath(shape.rachis, transform: t)
                if f.tier == 2 { tiers[f.tier].shadow.addPath(shape.body, transform: t.concatenating(CGAffineTransform(translationX: 0.8, y: 1.3))) }
            }
            let tip = shape.tip.applying(t)
            let tipHead = start + shape.tipHeading
            // The coil at the tip: big on a young frond, gone on a grown one.
            let coil = max(0, 1 - Ink.smooth((r - 0.55) / 0.4)) * (3 + 11 * (1 - r))
            if coil > 0.8, c != nil {
                var spiral: [CGPoint] = []
                let toward: Double = tipHead + dir * .pi / 2
                let centre = CGPoint(x: tip.x + cos(toward) * coil, y: tip.y + sin(toward) * coil)
                for k in 0...14 {
                    let u = Double(k) / 14
                    let ang = tipHead - dir * .pi / 2 + dir * u * 2.6 * .pi
                    let rad = coil * (1 - 0.88 * u)
                    spiral.append(CGPoint(x: centre.x + cos(ang) * rad, y: centre.y + sin(ang) * rad))
                    if k.isMultiple(of: 2), k > 2 { fuzz.addEllipse(in: CGRect(x: spiral[k].x - 1.2, y: spiral[k].y - 1.2, width: 2.4, height: 2.4)) }
                }
                coils.addPath(Self.ribbon(spiral, 3.0, 1.2))
            }
            m.note(CGPoint(x: tip.x, y: tip.y - coil), reach: 3, hang: false)
            // Hang decorations on the pinnae a third of the way up the arch.
            m.note(CGPoint(x: shape.tip.x * 0.55, y: shape.tip.y * 0.55).applying(t))
        }

        // Fiddleheads at the heart: a fern is always making new fronds.
        if p > 0.3 {
            for (k, (dx, height, lean)) in [(-5.0, 30.0, -0.22), (6.0, 22.0, 0.28)].enumerated() {
                let grow = pop(0.3 + 0.18 * Double(k), over: 0.1)
                guard grow > 0.03 else { continue }
                let h = height * grow, s = side
                let foot = CGPoint(x: dx * s, y: 1)
                let top = CGPoint(x: foot.x + lean * s * h, y: -h)
                let stalk = Self.quad(foot, CGPoint(x: foot.x + lean * s * h * 0.2, y: -h * 0.6), top, n: 8)
                rachises[2].addPath(Self.ribbon(stalk, 2.6, 1.6))
                let head = Self.heading(stalk, 1)
                let coil = 8.5 * grow
                let turn: Double = lean >= 0 ? 1.0 : -1.0
                let toward: Double = head + turn * .pi / 2
                let centre = CGPoint(x: top.x + cos(toward) * coil, y: top.y + sin(toward) * coil)
                var spiral: [CGPoint] = []
                for j in 0...16 {
                    let u = Double(j) / 16
                    let ang = head - turn * .pi / 2 + turn * u * 2.8 * .pi
                    let rad = coil * (1 - 0.88 * u)
                    spiral.append(CGPoint(x: centre.x + cos(ang) * rad, y: centre.y + sin(ang) * rad))
                    if j.isMultiple(of: 2), j > 2 { fuzz.addEllipse(in: CGRect(x: spiral[j].x - 1.3, y: spiral[j].y - 1.3, width: 2.6, height: 2.6)) }
                }
                coils.addPath(Self.ribbon(spiral, 4.2, 1.6))
                m.note(CGPoint(x: top.x, y: top.y - coil), reach: 2, hang: false)
            }
        }

        guard let c else { return }
        let stalk = ramp[1].mix(RGB(0x5A4630), 0.45 - 0.2 * M.thirst)
        let bronze = ramp[3].mix(RGB(0xB08440), 0.6)
        for tier in 0..<3 {
            tiers[tier].flush(c, inks[tier], casting: tier > 0)
            // The underside of each arch is a tone darker; the rachis runs over.
            c.fill(darks[tier], with: .color(ramp[0].mix(RGB(0x061A10), 0.3).color(0.32)))
            c.fill(rachises[tier], with: .color(stalk.mix(ramp[2], 0.15 * Double(tier)).color()))
        }
        c.fill(coils, with: .color(bronze.color()))
        c.fill(fuzz, with: .color(ramp[4].mix(RGB(0xE8D4A0), 0.5).color(0.7)))
    }
}
