import SwiftUI

/// A decoration shown alone, as the shop's tiles, its card and the decorate
/// tray show it: put out in a small scene at the hour's light, as one still
/// canvas (`ScenePortrait`), never a live scene.
///
/// What it stands on depends on where it goes: a wearable on a kitten, a pot
/// on a plant, a scene as a small window of that scene with a kitten in front
/// of it, a tree's ornament on a tree, and anything else on the ground line
/// beside a sunflower. A thing not drawn yet (`isDrawn == false`) is its emoji
/// in the same window, as it always was.
///
/// `Equatable` and used with `.equatable()`: the picture is drawn when it
/// scrolls in and not again while the shelf's own state moves under it.
struct DecorPortrait: View, Equatable {
    let decor: Decor
    var hour = 13
    /// The emoji's size, when there is no drawing.
    var fallbackSize: CGFloat = 40

    private var isDrawn: Bool {
        if case let .item(item) = decor { item.isDrawn } else { true }
    }

    /// What the thing is put out on.
    private var stand: Species {
        switch decor.kind {
        case .wearing, .sky: .kitten
        case .pot: .monstera
        case .tree: .magnolia
        case .above, .weather, .floor, .ground: .sunflower
        }
    }

    /// A moon or the bats are drawn at night whatever the well's hour is:
    /// by day there is nothing of them to see.
    private var lightHour: Int {
        guard case let .item(item) = decor else { return hour }
        switch item {
        case .fullMoon, .harvestMoon, .fireworks, .bats: return 21
        case .dusk: return 19
        default: return hour
        }
    }

    private var layout: SceneLayout {
        var layout = SceneLayout()
        layout.place(decor)
        return layout
    }

    var body: some View {
        if isDrawn {
            let species = stand
            ScenePortrait(
                companion: Companion(species: species, seed: "shop", startedAt: .distantPast),
                progress: 0.97, mood: .bright, stage: species.isPet ? 6 : 5,
                now: Calendar.current.date(bySettingHour: lightHour, minute: 0, second: 0, of: Date()) ?? Date(),
                layout: layout
            )
            .allowsHitTesting(false)
        } else {
            Text(verbatim: decor.symbol).font(.system(size: fallbackSize)).padding(.bottom, fallbackSize / 5)
        }
    }
}

extension DecorPortrait {
    /// The pets a decoration's portrait stands on, prepared off the main
    /// thread with the shelf (`CritterGeometry.prepare`).
    static let pets: [Species] = [.kitten]

    /// The kept bitmap this tile's picture is, and the size it is drawn at.
    func still(big: Bool) -> StillSpec {
        let size = big ? CGSize(width: 200, height: 200) : CGSize(width: 100, height: 100)
        return StillSpec(key: "d|\(decor.rawValue)|\(hour)|\(Int(size.width))", size: size)
    }

    /// The picture as a tile shows it: the kept bitmap once there is one.
    func tile(big: Bool) -> some View { Still(spec: still(big: big), live: self).equatable() }
}
