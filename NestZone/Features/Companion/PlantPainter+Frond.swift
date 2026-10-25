import SwiftUI

// The frond: arching pinnate fronds out of one crown, the centre ones upright
// and the outer ones bowing over the pot's rim, each a dark rachis with pairs
// of pinnae that are longest a third of the way up and shorten to the tip. A
// fern is this rule.
//
// What makes it a fern is the young ones: a frond comes up as a fiddlehead, a
// bronze coil on a short stalk, and unrolls as it grows, the coil at its tip
// getting smaller until it is gone. The first things to show (.1 to .3) are
// three croziers standing in the soil. A fully grown fern shows the brown dots
// of spores on the outer fronds.
//
// A thirsty one lets the fronds bow further and the pinnae hang and curl; a
// dozing one is folded down.
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
            let u = (raw < 0 ? -1.0 : 1.0) * pow(abs(raw), 1.45) * side
            let a = abs(u)
            fronds.append(Frond(u: u, born: 0.1 + 0.05 * Double(rank), length: plan.height * (1.08 + 0.1 * a) * seed.between(i, 0.94, 1.06), tier: a < 0.34 ? 0 : a < 0.7 ? 1 : 2))
        }
        var tiers = [LeafBatch(), LeafBatch(), LeafBatch()]
        var rachises = [Path(), Path(), Path()]
        var coils = Path(), fuzz = Path(), spores = Path()
        let shape = LeafShape.of(.pinna, bend: 0.25)
        let shapeL = LeafShape.of(.pinna, bend: -0.25)
        let pairs = 11

        for (n, f) in fronds.enumerated() {
            let r = Ink.smooth((p - f.born) / 0.46)
            guard r > 0.02 else { continue }
            let dir = f.u >= 0 ? 1.0 : -1.0
            let a = abs(f.u)
            // Out of the crown, tilted out, and bowing over as it grows: the
            // rachis is walked, its heading turning a little at every step.
            let steps = 18
            let total = (0.2 + 0.95 * a * a + 0.3 * a) * (0.55 + 0.45 * r) + wilt * (0.5 + 0.7 * a)
            let start = -.pi / 2 + dir * (0.04 + 0.4 * a) * (0.7 + 0.3 * r)
            var pts = [CGPoint(x: f.u * 4, y: 1)]
            let length = f.length * r * (1 - 0.1 * wilt)
            for k in 1...steps {
                let t = Double(k) / Double(steps)
                let head = start + dir * total * pow(t, 1.35)
                let last = pts[k - 1]
                pts.append(CGPoint(x: last.x + cos(head) * length / Double(steps), y: last.y + sin(head) * length / Double(steps)))
            }
            let tipHead = start + dir * total
            // The grown part: every pair of pinnae, shorter at both ends. A
            // frond still rolling has none at its tip (the coil is there).
            let unrolled = Ink.smooth((r - 0.55) / 0.4)
            if c != nil {
                rachises[f.tier].addPath(Self.ribbon(pts, 2.6, 0.8))
                for k in 0..<pairs {
                    let t = 0.08 + 0.9 * Double(k) / Double(pairs - 1)
                    guard t < 0.35 + 0.65 * unrolled else { continue }
                    let q = Self.along(pts, t), head = Self.heading(pts, t)
                    let age = min(1, ((0.35 + 0.65 * unrolled) - t) * 5 + 0.2)
                    let size = plan.leafLength * (0.4 + 0.6 * sin(.pi * Ink.clamp(t * 0.85 + 0.05))) * (1 - 0.32 * t) * age * (1 - 0.1 * wilt) * (0.85 + 0.3 * r)
                    for s in [-1.0, 1.0] {
                        let angle = head + s * (1.25 - 0.45 * t) + s * dir * 0.0 + s * wilt * 0.5
                        let bri = bright(angle, luck: luck(n * 13 + k * 2 + (s > 0 ? 1 : 0)), tier: f.tier)
                        tiers[f.tier].addLite(s > 0 ? shape : shapeL, base: q, angle: angle, length: size, light: L, bright: bri, shadowed: f.tier == 2 && k.isMultiple(of: 3), lightHalf: f.tier > 0)
                        if p > 0.82, f.tier == 2, k % 3 == 1, k > 2 {
                            let sx = q.x + cos(angle) * size * 0.62, sy = q.y + sin(angle) * size * 0.62
                            spores.addEllipse(in: CGRect(x: sx - 0.9, y: sy - 0.7, width: 1.8, height: 1.4))
                        }
                    }
                    if k.isMultiple(of: 3) { m.note(CGPoint(x: q.x + cos(head + 1.0) * size * 0.6, y: q.y + sin(head + 1.0) * size * 0.6)) }
                }
            }
            // The coil at the tip: big on a young frond, gone on a grown one.
            let coil = (1 - unrolled) * (3 + 11 * (1 - r))
            if coil > 0.8, c != nil {
                let tip = pts[steps]
                var spiral: [CGPoint] = []
                for k in 0...14 {
                    let t = Double(k) / 14
                    let ang = tipHead + dir * (-.pi / 2 + t * 2.6 * .pi)
                    let rad = coil * (1 - 0.88 * t)
                    // The coil sits on the inside of the curve the frond is making.
                    let cx = tip.x + cos(tipHead + dir * .pi / 2) * coil, cy = tip.y + sin(tipHead + dir * .pi / 2) * coil
                    spiral.append(CGPoint(x: cx + cos(ang + .pi) * rad * 1, y: cy + sin(ang + .pi) * rad))
                    if k.isMultiple(of: 2), k > 2 { fuzz.addEllipse(in: CGRect(x: spiral[k].x - 1.2, y: spiral[k].y - 1.2, width: 2.4, height: 2.4)) }
                }
                coils.addPath(Self.ribbon(spiral, 3.0, 1.2))
            }
            m.note(CGPoint(x: pts[steps].x, y: pts[steps].y - coil), reach: 3, hang: false)
        }

        guard let c else { return }
        let stalk = ramp[1].mix(RGB(0x5A4630), 0.45 - 0.2 * M.thirst)
        let bronze = ramp[3].mix(RGB(0xC8A25A), 0.4)
        for tier in 0..<3 {
            c.fill(rachises[tier], with: .color(stalk.mix(ramp[2], 0.15 * Double(tier)).color()))
            tiers[tier].flush(c, inks[tier], casting: tier > 0)
        }
        c.fill(coils, with: .color(bronze.color()))
        c.fill(fuzz, with: .color(ramp[4].mix(RGB(0xE8D4A0), 0.5).color(0.7)))
        c.fill(spores, with: .color(RGB.night(28, 40, 34, day: day, dim: 0.9).color(0.8)))
    }
}
