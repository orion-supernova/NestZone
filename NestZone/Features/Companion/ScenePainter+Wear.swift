import SwiftUI

/// What a plant or a sketched pet wears: the same drawings a pet's own painter
/// puts on its head and throat (`WearArt`), set on a crown or a pot.
extension ScenePainter {
    /// The thing worn, if it is one of the four.
    var worn: DecorItem? {
        guard let raw = frame.layout.wearing, let item = DecorItem(rawValue: raw) else { return nil }
        return item.kind == .wearing ? item : nil
    }

    /// How big a hat is on a crown this wide: a party hat on a seedling is the
    /// seedling's size, and on a grown tree it is still a hat.
    static func hatScale(crownWidth: Double) -> Double { Ink.clamp(crownWidth / 120, 0.7, 1.35) }

    /// A hat standing on `top`, tipped a little. On a plant it moves with the
    /// plant (it is drawn in the tree's layer, under the same wind).
    func hat(_ context: GraphicsContext, _ item: DecorItem, at top: CGPoint, scale: Double = 1) {
        guard item.isDrawn else { context.sketch(item.symbol, top.x, top.y, size: 30); return }
        var c = context
        c.translateBy(x: top.x, y: top.y + 3 * scale)
        c.rotate(by: .radians(item == .partyHat ? -0.12 + (frame.reduceMotion ? 0 : sin(time * 1.6) * 0.03) : 0.04))
        c.scaleBy(x: scale, y: scale)
        switch item {
        case .partyHat: WearArt.partyHat(c, lamp)
        case .tinyCrown:
            let glint = frame.reduceMotion ? 0.55 : max(0, sin(time * 1.9 + 1))
            WearArt.crown(c, lamp, glint: glint)
        default: break
        }
    }

    /// A bow or a scarf tied at `throat`: a pet's chin, a pot's neck.
    /// `span` is half the width it wraps round; `size` scales the knot and the
    /// hanging ends.
    func neckwear(_ context: GraphicsContext, _ item: DecorItem, at throat: CGPoint, span: Double, size: Double = 1) {
        guard item.isDrawn else { context.sketch(item.symbol, throat.x, throat.y, size: 26); return }
        var c = context
        c.translateBy(x: throat.x, y: throat.y)
        c.scaleBy(x: size, y: size)
        switch item {
        case .bow: WearArt.bow(c, lamp, span: span / size)
        case .scarf: WearArt.scarf(c, lamp, span: span / size)
        default: break
        }
    }

    /// Wearing, for a body that draws nothing of its own: the neck piece on a
    /// pot, below its lip, so a vine hangs in front of it.
    func potWear(_ context: GraphicsContext) {
        guard let item = worn, item == .bow || item == .scarf else { return }
        neckwear(context, item, at: CGPoint(x: center, y: SceneSpace.soil + 18), span: 47, size: 2.1)
    }

    /// A sketched pet's hat and neck piece, on points near its emoji: they
    /// are still, where a drawn pet's move with it.
    func wearing(_ context: GraphicsContext, top: CGPoint, neck: CGPoint) {
        guard let item = worn else { return }
        switch item {
        case .partyHat, .tinyCrown: hat(context, item, at: top, scale: 1.1)
        default: neckwear(context, item, at: neck, span: 17, size: 1.2)
        }
    }
}
