import SwiftUI

/// The blooms of an orchid's spike gathered by layer, so that however many
/// there are the spike is a dozen fills: sepals, then petals, then the lip and
/// the column, the lit and shaded halves, the veins and the buds.
struct BloomField {
    var stems = Path(), sepals = Path(), petals = Path(), blush = Path()
    var lit = Path(), shade = Path(), veins = Path()
    var lips = Path(), lipLight = Path(), callus = Path(), column = Path()
    var buds = Path(), budTips = Path()

    mutating func stem(from a: CGPoint, to b: CGPoint) {
        stems.addPath(PlantPainter.ribbon([a, CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - 0.8), b], 1.9, 1.4))
    }

    func flush(_ c: GraphicsContext, ramp: [PlantPainter.RGB], flower: PlantPlan.Flower, painter p: PlantPainter) {
        let deep = p.bloom(flower.deep), mid = p.bloom(flower.mid), pale = p.bloom(flower.pale), heart = p.bloom(flower.heart, dim: 0.5)
        let tint = p.bloom(flower.tint), gold = p.bloom(flower.anther, dim: 0.5)
        c.fill(stems, with: .color(ramp[2].mix(PlantPainter.RGB(0x6C3A5C), 0.35).color()))
        c.fill(buds, with: .color(ramp[3].mix(tint, 0.35).color()))
        c.fill(budTips, with: .color(tint.mix(pale, 0.3).color(0.9)))
        c.fill(sepals, with: .color(mid.mix(pale, 0.35).color()))
        c.fill(petals, with: .color(pale.mix(mid, 0.25).color()))
        c.fill(blush, with: .color(tint.color(0.45)))
        c.fill(shade, with: .color(deep.shifted(-8).color(0.2)))
        c.fill(lit, with: .color(pale.mix(p.glow, 0.3 * (1 - p.night)).color(0.4)))
        c.fill(veins, with: .color(deep.color(0.34)))
        c.fill(lips, with: .color(heart.color()))
        c.fill(lipLight, with: .color(tint.mix(deep, 0.2).color(0.85)))
        c.fill(callus, with: .color(gold.color()))
        c.fill(column, with: .color(pale.color()))
    }
}

extension PlantPainter {
    /// One phalaenopsis bloom into the field: three sepals, two broad petals
    /// like wings, a three-lobed lip and a small column. `open` is 0 for a bud
    /// (a teardrop with a pink tip) to 1 flat open; `tilt` turns it, a nod.
    func orchidBloom(_ f: inout BloomField, at: CGPoint, radius R: Double, open: Double, tilt: Double) {
        let toward = { (a: Double) -> Double in -sin(a) * L.x + cos(a) * L.y }
        if open < 0.22 {
            let k = R * (0.8 + 0.5 * open / 0.22)
            let a = -.pi / 2 + tilt + 0.4
            f.buds.leaf(at.x, at.y, cos(a), sin(a), k, k * 0.36, 0.3)
            f.budTips.leaf(at.x + cos(a) * k * 0.55, at.y + sin(a) * k * 0.55, cos(a), sin(a), k * 0.45, k * 0.2, 0.2)
            return
        }
        let k = R * (0.55 + 0.45 * Ink.smooth((open - 0.22) / 0.5))
        let spread = 0.35 + 0.65 * Ink.smooth((open - 0.22) / 0.6)
        func place(_ angle: Double, _ length: Double, _ wide: Double, from: CGPoint? = nil) -> (CGAffineTransform, Double) {
            let a = angle + tilt
            let b = from ?? at
            return (CGAffineTransform(translationX: b.x, y: b.y).rotated(by: a).scaledBy(x: length, y: length * wide), a)
        }
        let tepal = LeafShape.of(.tepal), petal = LeafShape.of(.petal)
        // The dorsal sepal, up; the lateral ones down and out.
        for (angle, len) in [(-Double.pi / 2, 0.86), (.pi / 2 - 0.62 * spread - 0.1, 0.8), (.pi / 2 + 0.62 * spread + 0.1, 0.8)] {
            let (t, _) = place(angle, k * len, 0.62)
            f.sepals.addPath(tepal.outline, transform: t)
        }
        // The petals: two broad wings, a little above level, and the blush at
        // their throats.
        for s in [-1.0, 1.0] {
            let angle = s > 0 ? -0.12 * spread : .pi + 0.12 * spread
            let (t, a) = place(angle, k * 1.02, 0.92 * (0.6 + 0.4 * spread))
            f.petals.addPath(petal.outline, transform: t)
            let towardLight = toward(a) >= 0
            f.lit.addPath(towardLight ? petal.sideA : petal.sideB, transform: t)
            f.shade.addPath(towardLight ? petal.sideB : petal.sideA, transform: t)
            f.veins.addPath(petal.veins, transform: t)
            let (inner, _) = place(angle, k * 0.46, 0.72)
            f.blush.addPath(petal.outline, transform: inner)
        }
        // The lip: two side lobes and a longer middle one, in the throat.
        for s in [-1.0, 1.0] {
            let (t, _) = place(.pi / 2 + s * 0.9, k * 0.36, 0.7, from: CGPoint(x: at.x, y: at.y + k * 0.05))
            f.lips.addPath(tepal.outline, transform: t)
        }
        let (mid, _) = place(.pi / 2, k * 0.46, 0.5, from: CGPoint(x: at.x, y: at.y + k * 0.04))
        f.lips.addPath(tepal.outline, transform: mid)
        let (shine, _) = place(.pi / 2 - 0.1, k * 0.24, 0.3, from: CGPoint(x: at.x, y: at.y + k * 0.1))
        f.lipLight.addPath(tepal.outline, transform: shine)
        f.callus.addEllipse(in: CGRect(x: at.x - k * 0.1, y: at.y + k * 0.02, width: k * 0.2, height: k * 0.16))
        f.column.addEllipse(in: CGRect(x: at.x - k * 0.07, y: at.y - k * 0.08, width: k * 0.14, height: k * 0.16))
    }
}
