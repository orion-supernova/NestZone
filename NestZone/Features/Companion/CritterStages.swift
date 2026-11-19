import SwiftUI

/// What growing up does to a bird, a turtle or a fish, which is more than
/// getting bigger: the down gives way to feathers, the neck lengthens, the
/// shell domes, the colour comes in. Each species' stages live in its own
/// `CritterStages+<Species>.swift`; what they share is here.
///
/// The seven pet stages are egg (0), the egg with its pip (1), hatchling (2),
/// baby (3), little one (4), young (5) and grown (6). A stage is never a scale:
/// `scale` below only says how big the animal stands, and what the stage *is*
/// is its silhouette, proportions, coat and what it does.
extension CritterPainter {
    /// How big a non-mammal stands against its grown self. Small steps on
    /// purpose, because the shape is what changes (the mammals still use
    /// `PetMotion.scales`).
    static func stageScale(_ plan: CritterPlan, _ stage: Int) -> Double {
        switch plan.body {
        case .waddler: [1, 1, 0.84, 0.86, 0.92, 0.96, 1][stage]
        case .perched: [1, 1, 1, 0.84, 0.9, 0.96, 1][stage]
        case .shelled: [1, 1, 1, 0.84, 0.9, 0.95, 1][stage]
        case .swimmer: [1, 1, 1, 1, 1, 1, 1][stage]
        case .sitter: PetMotion.mammalScales[stage]
        }
    }

    /// A bird's colourway marks that only the grown bird has: they come in
    /// with the adult plumage, so a young one wears the juvenile version.
    var isAdult: Bool { stage >= 6 }

    /// This pet as it will be grown: the colours a younger stage is still
    /// growing into (a bronze goldfish's gold).
    var grownPlan: CritterPlan { CritterPlan.of(plan.species, colourway: plan.colourway) ?? plan }

    /// The tone of a coat wet from the egg: darker, flatter, a touch cooler.
    func wetTone(_ c: RGB, _ amount: Double) -> RGB { c.mix(look.dark, 0.38 * amount).shifted(-4 * amount) }

    /// Layers of feather tips over a form, in the form's own light: a lit
    /// edge on the sky's side, the ramp, and a short shadow under each tip.
    /// `levels` are cumulative (`Plumage.scallops`), `coverage` 0...1 picks how
    /// many are in.
    func feathers(_ c: GraphicsContext, _ levels: [Path], coverage: Double, centre: CGPoint, radius: Double,
                  _ light: RGB, _ mid: RGB, _ dark: RGB) {
        guard coverage > 0.02, !levels.isEmpty else { return }
        let index = min(levels.count - 1, max(0, Int((coverage * Double(levels.count)).rounded(.up)) - 1))
        let path = levels[index]
        let L = look.L
        var shade = c
        shade.translateBy(x: -L.x * 1.1, y: -L.y * 1.1 + 0.7)
        shade.fill(path, with: .color(look.cool.color(min(0.7, look.coolAlpha * 3))))
        var lit = c
        lit.translateBy(x: L.x * 0.8, y: L.y * 0.8)
        lit.fill(path, with: .color(look.lifted(light, 0.4).color(0.9)))
        c.fill(path, with: ramp(centre, radius, light, mid, dark))
    }
}

/// Feather tips and quills, built once per plan (`CritterGeometry`'s habit):
/// a painter only fills the paths.
enum Plumage {
    /// Rounded feather tips laid in staggered rows over a region. `weight`
    /// answers 0...1 for a point (how soon a feather comes in there, 1 first)
    /// or nil outside the region. Returns `levels` cumulative paths, so a
    /// later stage is a longer one of the same list, and a bird with its
    /// feathers half in has them where the weight said, with some scatter.
    static func scallops(seed: String, bounds: CGRect, pitch: CGSize, size: CGSize, tilt: Double = -0.4,
                         levels: Int = 4, weight: (CGPoint) -> Double?) -> [Path] {
        var rand = Ink.Random(seed)
        var cells: [(key: Double, path: Path)] = []
        var row = 0
        for y in stride(from: bounds.minY, through: bounds.maxY, by: pitch.height) {
            for x in stride(from: bounds.minX + (row.isMultiple(of: 2) ? 0 : pitch.width / 2), through: bounds.maxX, by: pitch.width) {
                let p = CGPoint(x: x + rand.between(-0.8, 0.8), y: y + rand.between(-0.7, 0.7))
                guard let w = weight(p) else { continue }
                let key = (1 - Ink.clamp(w)) * 0.72 + rand.next() * 0.28
                let s = rand.between(0.9, 1.12)
                cells.append((key, tip(at: p, size: CGSize(width: size.width * s, height: size.height * s), angle: tilt + rand.between(-0.18, 0.18))))
            }
            row += 1
        }
        return (1...levels).map { i in
            var path = Path()
            let cut = Double(i) / Double(levels)
            for cell in cells where cell.key <= cut || i == levels { path.addPath(cell.path) }
            return path
        }
    }

    /// One feather's visible tip: a rounded shield, point down, turned by `angle`.
    static func tip(at p: CGPoint, size: CGSize, angle: Double) -> Path {
        let w = size.width, h = size.height
        var path = Path()
        path.move(to: CGPoint(x: -w / 2, y: -h * 0.55))
        path.addQuadCurve(to: CGPoint(x: 0, y: h * 0.55), control: CGPoint(x: -w * 0.6, y: h * 0.3))
        path.addQuadCurve(to: CGPoint(x: w / 2, y: -h * 0.55), control: CGPoint(x: w * 0.6, y: h * 0.3))
        path.closeSubpath()
        return path.applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: p.x, y: p.y)))
    }

    /// Pin feathers: a thin shaft with a paler sheath at its tip, still in its
    /// case, standing out from where a feather will grow. Each is
    /// (root, angle, length); two paths, shafts to stroke and sheaths to fill.
    static func quills(_ items: [(CGPoint, Double, Double)]) -> (shafts: Path, sheaths: Path) {
        var shafts = Path(), sheaths = Path()
        for (root, angle, length) in items {
            let end = CGPoint(x: root.x + cos(angle) * length, y: root.y + sin(angle) * length)
            shafts.move(to: root)
            shafts.addLine(to: end)
            sheaths.addPath(Path.leaf(from: CGPoint(x: root.x + cos(angle) * length * 0.55, y: root.y + sin(angle) * length * 0.55), to: end, width: 1.1))
        }
        return (shafts, sheaths)
    }
}

extension Path {
    /// A small pointed leaf from one point to another, `width` across at its
    /// middle: a quill's sheath, a wisp of down.
    static func leaf(from a: CGPoint, to b: CGPoint, width: Double) -> Path {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(0.001, hypot(dx, dy))
        let nx = -dy / len * width, ny = dx / len * width
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: CGPoint(x: mid.x + nx, y: mid.y + ny))
        p.addQuadCurve(to: a, control: CGPoint(x: mid.x - nx, y: mid.y - ny))
        p.closeSubpath()
        return p
    }
}
