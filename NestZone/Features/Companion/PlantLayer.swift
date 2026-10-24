import SwiftUI

/// A drawn plant on a layer of its own, as `TreeLayer` is the tree's: drawn
/// again only when what it shows changes (a mood easing in, growth, the light
/// moving with the clock), and under the same wind, a shear of the picture
/// about its foot, so a plant sways for free.
struct PlantLayer: View, Equatable {
    let plan: PlantPlan
    let state: TreeState

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.state.seed == rhs.state.seed && lhs.state.species == rhs.state.species && lhs.state.mood == rhs.state.mood
            && lhs.state.progress == rhs.state.progress && lhs.state.day == rhs.state.day
    }

    var body: some View {
        Canvas { context, size in Self.paint(context, size: size, plan: plan, state: state) }
            .drawingGroup()
    }

    /// The plant on the scene's soil. Cut to it, so roots and a seed go into
    /// the earth, except a vine, whose stem trails over the pot's rim.
    static func paint(_ context: GraphicsContext, size: CGSize, plan: PlantPlan, state: TreeState) {
        let scale = size.height / SceneSpace.height
        var plant = context
        plant.scaleBy(x: scale, y: scale)
        plant.translateBy(x: size.width / scale / 2, y: SceneSpace.soil)
        if plan.rule != .vine {
            var above = Path(CGRect(x: -size.width, y: -SceneSpace.soil, width: size.width * 2, height: SceneSpace.soil))
            above.addEllipse(in: SceneSpace.soilSurface)
            plant.clip(to: above)
        }
        PlantPainter(plan: plan, seed: state.seed, growth: state.progress, mood: state.mood, day: state.day).draw(plant)
    }
}
