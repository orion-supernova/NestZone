#if DEBUG
import SwiftUI

/// Contact sheets for the decoration pass: one item on the companions that
/// meet it, by day, dusk and night, in every mood, at every stage and at the
/// size of a shop cell.
///
///   -artSheet decor-bow-pets      the eight drawn pets wearing it
///   -artSheet decor-bow-moods     a kitten and an owl in the four moods
///   -artSheet decor-bow-stages    a kitten and a duckling from the egg up
///   -artSheet decor-bow-plants    plants and trees
///   -artSheet decor-bow-night     the pets after dark
///   -artSheet decor-watermelon-scene   a floor, overhead or backdrop item in a few scenes
///   -artSheet decor-shop          the new items at the size of a shop tile
extension ArtSheet {
    private static let pets: [Species] = [.kitten, .owl, .duckling, .hamster, .bunny, .puppy, .fox, .hedgehog]

    /// One item put out in the spot it belongs to.
    private func layout(_ item: DecorItem, with others: [DecorItem] = []) -> SceneLayout {
        var layout = SceneLayout()
        for item in [item] + others { layout.place(.item(item)) }
        return layout
    }

    private func companion(_ species: Species) -> Companion {
        Companion(species: species, seed: Self.seed, startedAt: .distantPast)
    }

    private func portrait(_ species: Species, _ item: DecorItem, hour h: Int, mood: Mood = .bright, stage: Int? = nil, progress: Double = 0.97) -> ScenePortrait {
        ScenePortrait(companion: companion(species), progress: progress, mood: mood, stage: stage ?? (species.isPet ? 6 : 5),
                      now: hour(h), layout: layout(item))
    }

    @ViewBuilder
    func decorSheet(_ page: String) -> some View {
        let parts = page.split(separator: "-").map(String.init)
        if parts.count == 2, parts[1] == "shop" {
            decorShop
        } else if parts.count == 3, let item = DecorItem(rawValue: parts[1]) {
            decorGrid(item, kind: parts[2])
        }
    }

    private func decorGrid(_ item: DecorItem, kind: String) -> some View {
        let cells: [(String, ScenePortrait)] = switch kind {
        case "pets": Self.pets.map { ($0.rawValue, portrait($0, item, hour: 13)) }
        case "night": Self.pets.map { ($0.rawValue + " 22h", portrait($0, item, hour: 22)) }
        case "dusk": Self.pets.map { ($0.rawValue + " 19h", portrait($0, item, hour: 19)) }
        case "moods": [Species.kitten, .owl].flatMap { species in
            Mood.allCases.map { (species.rawValue + " " + $0.rawValue, portrait(species, item, hour: 13, mood: $0)) }
        }
        case "stages": [(Species.kitten, 1), (.kitten, 2), (.kitten, 3), (.kitten, 4), (.duckling, 1), (.duckling, 2), (.owl, 2), (.owl, 3)].map { species, stage in
            ("\(species.rawValue) stage \(stage)", portrait(species, item, hour: 13, stage: stage, progress: [0.02, 0.12, 0.28, 0.47, 0.66, 0.85, 0.97][stage]))
        }
        case "plants": [(Species.sunflower, 13), (.monstera, 13), (.cactus, 19), (.bonsai, 13), (.magnolia, 13), (.rose, 19), (.fern, 13), (.basil, 22)].map { species, h in
            ("\(species.rawValue) \(h)h", portrait(species, item, hour: h))
        }
        case "young": [(Species.sunflower, 0.16), (.sunflower, 0.38), (.magnolia, 0.16), (.magnolia, 0.38), (.cactus, 0.16), (.monstera, 0.38), (.rose, 0.38), (.bonsai, 0.38)].map { species, p in
            ("\(species.rawValue) \(Int(p * 100))%", portrait(species, item, hour: 13, stage: p < 0.3 ? 1 : 2, progress: p))
        }
        // A floor, overhead or backdrop item in a few scenes, three times of day.
        default: [(Species.sunflower, 13), (.kitten, 13), (.monstera, 19), (.owl, 19), (.cactus, 23), (.puppy, 23), (.magnolia, 13), (.bunny, 7)].map { species, h in
            ("\(species.rawValue) \(h)h", portrait(species, item, hour: h))
        }
        }
        return VStack(spacing: 3) {
            Text(verbatim: "\(item.rawValue) - \(kind)").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 2), spacing: 3) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, entry in cell(entry.1, entry.0) }
            }
        }
        .padding(.horizontal, 4)
    }

    /// The eight new items as a shop tile shows a thing: a small square, by day and by night.
    private var decorShop: some View {
        let items: [(DecorItem, Species)] = [(.windowsill, .monstera), (.balcony, .sunflower), (.starryRooftop, .kitten), (.windChime, .cactus),
                                             (.bow, .kitten), (.scarf, .owl), (.tinyCrown, .puppy), (.watermelon, .bunny)]
        return VStack(alignment: .leading, spacing: 4) {
            ForEach([13, 22], id: \.self) { h in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, entry in
                        ScenePortrait(companion: companion(entry.1), progress: 0.97, mood: .bright, stage: entry.1.isPet ? 6 : 5, now: hour(h), layout: layout(entry.0))
                            .aspectRatio(1, contentMode: .fit)
                            .background(h == 13 ? SceneInk.dayWell : SceneInk.duskWell)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(alignment: .topLeading) { Text(verbatim: entry.0.rawValue).font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(3) }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}
#endif
