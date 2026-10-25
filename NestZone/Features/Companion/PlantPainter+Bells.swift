import SwiftUI

// Two blooms of the tuft that are not a head: lavender's spike of whorled
// florets, and the snowdrop's nodding bell.
extension PlantPainter {
    // MARK: Lavender

    /// A spike of tiny florets that carries on the stem: whorls up it, three
    /// florets to a whorl (one each side, one facing us), a grey-green calyx
    /// under each, deep violet at the base of the spike and lighter at its
    /// tips, and a few buds at the very top. Whorls open from the bottom up;
    /// a quiet house leaves them as grey-green buds.
    func lavenderSpike(_ c: GraphicsContext, from base: CGPoint, heading: Double, length: Double, open: Double, nod: Double) {
        guard let flower = plan.flower else { return }
        let deep = bloom(flower.deep, dim: 0.6), mid = bloom(flower.mid, dim: 0.6), pale = bloom(flower.pale, dim: 0.6)
        let calyxTone = ramp[2].mix(ramp[3], 0.4).mix(RGB(0x8A8AA8), 0.25)
        let toLit = L.x >= 0 ? 1.0 : -1.0
        let tip = CGPoint(x: base.x + cos(heading + nod * 0.25) * length, y: base.y + sin(heading + nod * 0.25) * length)
        let axis = Self.quad(base, CGPoint(x: base.x + cos(heading) * length * 0.55, y: base.y + sin(heading) * length * 0.55), tip, n: 10)
        var calyx = Path(), litA = Path(), shadeA = Path(), facing = Path(), buds = Path(), tipLight = Path()
        let whorls = 8
        for w in 0..<whorls {
            let t = 0.06 + 0.9 * Double(w) / Double(whorls - 1)
            let q = Self.along(axis, t), head = Self.heading(axis, t)
            let size = (7.2 - 2.4 * t) * (0.7 + 0.3 * open)
            // How far open this whorl is: the bottom ones first.
            let o = Ink.smooth(open * 1.7 - t * 0.9)
            let twist = w.isMultiple(of: 2) ? 0.0 : 0.18
            for s in [-1.0, 1.0] {
                let a = head + s * (0.85 + twist)
                if w.isMultiple(of: 2) { calyx.leaf(q.x, q.y, cos(a), sin(a), size * 0.55, size * 0.24, 0.3) }
                let len = size * (0.55 + 0.6 * o)
                var floret = Path()
                floret.leaf(q.x + cos(a) * 0.8, q.y + sin(a) * 0.8, cos(a - s * 0.3), sin(a - s * 0.3), len, len * 0.3, 0.5)
                if s == toLit { litA.addPath(floret) } else { shadeA.addPath(floret) }
                if t > 0.55, s == toLit { tipLight.addPath(floret) }
            }
            // The one facing us: a round, short bloom on the axis.
            facing.addEllipse(in: CGRect(x: q.x - size * 0.34, y: q.y - size * 0.28 - 1, width: size * 0.68, height: size * 0.56))
        }
        for s in [-1.0, 0.0, 1.0] {
            let a = Self.heading(axis, 1) + s * 0.4
            buds.leaf(tip.x, tip.y, cos(a), sin(a), 4.2 - 1.2 * abs(s), 1.4, 0.4)
        }
        c.fill(Self.ribbon(axis, 1.8, 1.2), with: .color(ramp[2].color()))
        c.fill(calyx, with: .color(calyxTone.color()))
        let closed = calyxTone.mix(deep, 0.25)
        c.fill(shadeA, with: .color(closed.mix(deep, open * 0.8).color()))
        c.fill(facing, with: .color(closed.mix(mid, open * 0.8).color()))
        c.fill(litA, with: .color(closed.mix(mid, open * 0.9).color()))
        c.fill(tipLight, with: .color(pale.color(0.5 * open)))
        c.fill(buds, with: .color(closed.mix(pale, open * 0.5).color()))
    }

    // MARK: Snowdrop

    /// A snowdrop: a bell that hangs from the hooked tip of its stem: a green
    /// ovary, three long white outer tepals that flare out like a skirt, and
    /// inside them a short cup of three with a green mark at the mouth. A bud
    /// is one teardrop, pointed and green-streaked. `turn` points the bell
    /// down the stem's hook.
    func snowdropBloom(_ c: GraphicsContext, at: CGPoint, size S: Double, open: Double, turn: Double) {
        guard let flower = plan.flower else { return }
        var h = c
        h.translateBy(x: at.x, y: at.y)
        h.rotate(by: .radians(turn))
        let l = (x: L.x * cos(turn) + L.y * sin(turn), y: -L.x * sin(turn) + L.y * cos(turn))
        let pale = bloom(flower.pale, dim: 0.5), mid = bloom(flower.mid, dim: 0.5), deep = bloom(flower.deep, dim: 0.5), green = bloom(flower.heart, dim: 0.5)
        let k = S * 17
        var ovary = Path()
        ovary.oval(0, -1.2 * S, 2.8 * S, 3.4 * S)
        if open < 0.25 {
            // The bud: a pointed teardrop streaked with green, in its sheath.
            let bk = k * (0.55 + 0.6 * open / 0.25)
            var drop = Path(), streak = Path()
            drop.leaf(0, -1, 0, -1, bk, bk * 0.27, 0.2)
            streak.lens(from: CGPoint(x: 0, y: -bk * 0.3), to: CGPoint(x: 0, y: -bk * 0.95), width: bk * 0.09)
            h.fill(drop, with: .linearGradient(Gradient(colors: [green.mix(pale, 0.2).color(), pale.color(), mid.color()]),
                                               startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: -bk)))
            h.fill(streak, with: .color(green.color(0.6)))
            h.fill(ovary, with: .color(ramp[3].color()))
            return
        }
        let spread = 0.16 + 0.34 * Ink.smooth((open - 0.25) / 0.6)
        let tepal = LeafShape.of(.tepal)
        var outer = Path(), litHalf = Path(), shadeHalf = Path(), veins = Path(), rim = Path()
        // The two at the sides, flaring, then the one in front, straight.
        for (lean, bend, len) in [(-1.0, -0.3, 1.0), (1.0, 0.3, 1.0), (0.0, 0.0, 1.06)] {
            let a = -Double.pi / 2 + lean * spread
            let shape = LeafShape.of(.tepal, bend: bend * open)
            let t = CGAffineTransform(translationX: lean * 1.2, y: -2).rotated(by: a).scaledBy(x: k * len, y: k * len * 0.58)
            outer.addPath(shape.outline, transform: t)
            let toward = -sin(a) * l.x + cos(a) * l.y
            litHalf.addPath(toward >= 0 ? shape.sideA : shape.sideB, transform: t)
            shadeHalf.addPath(toward >= 0 ? shape.sideB : shape.sideA, transform: t)
            veins.addPath(shape.veins, transform: t)
            rim.addPath(toward >= 0 ? shape.rimA : shape.rimB, transform: t)
        }
        _ = tepal
        // The inner cup, at the mouth: three short tepals and the green mark.
        var inner = Path(), marks = Path()
        for lean in [-1.0, 0.0, 1.0] {
            let a = -Double.pi / 2 + lean * spread * 0.5
            inner.leaf(lean * 1.6, -k * 0.7, cos(a), sin(a), k * 0.34, k * 0.12, 0.3)
            marks.leaf(lean * 1.6, -k * 0.8, cos(a), sin(a), k * 0.18, k * 0.07, 0.2)
        }
        h.fill(outer, with: .linearGradient(Gradient(colors: [green.mix(pale, 0.4).color(), pale.color(), pale.mix(mid, 0.5).color()]),
                                            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: -k)))
        h.fill(shadeHalf, with: .color(deep.shifted(-10).color(0.3)))
        h.fill(litHalf, with: .color(pale.mix(glow, 0.3 * (1 - night)).color(0.4)))
        h.fill(veins, with: .color(green.color(0.3)))
        h.fill(rim, with: .color(rimTone.color(0.3 + 0.2 * dusk)))
        h.fill(inner, with: .color(pale.mix(mid, 0.3).color()))
        h.fill(marks, with: .color(green.color(0.9)))
        h.fill(ovary, with: .color(ramp[3].color()))
    }
}
