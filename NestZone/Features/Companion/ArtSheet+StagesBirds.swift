#if DEBUG
import SwiftUI

/// Contact sheets for the life-stage pass on the birds, the turtle and the
/// goldfish: every stage in every mood, every colourway through the stages,
/// and the stages in a hat and a bow. `<species>-stages` is the plain
/// version and lives in `ArtSheet`.
///
///   -artSheet stagemoods-duckling        stages 2 to 6, a row each, four moods across
///   -artSheet stagemood-duckling-3       one stage, the four moods large
///   -artSheet stagecolours-duckling      each colourway, stages 2 to 6
///   -artSheet stagecolour-duckling-1     one colourway, the seven stages large
///   -artSheet stagewear-duckling         stages 2 to 6 in a party hat, a bow, a scarf, a crown
///   -artSheet stagenight-duckling        stages 2 to 6 at dusk, by night and by the moon
extension ArtSheet {
    private static let stageProgress: [Double] = [0.02, 0.12, 0.28, 0.47, 0.66, 0.85, 0.97]
    private static let stageNames = ["egg", "pip", "hatchling", "baby", "little", "young", "grown"]

    @ViewBuilder
    func stagesSheet(_ page: String) -> some View {
        let parts = page.split(separator: "-").map(String.init)
        if parts.count >= 2, let species = Species(rawValue: parts[1]) {
            switch parts[0] {
            case "stagemoods": stageMoods(species)
            case "stagemood": stageMoodLarge(species, stage: parts.count > 2 ? Int(parts[2]) ?? 3 : 3)
            case "stagecolours": stageColours(species)
            case "stagecolour": stageColourLarge(species, colour: parts.count > 2 ? Int(parts[2]) ?? 1 : 1)
            case "stagewear": stageWear(species)
            case "stagenight": stageNight(species)
            default: EmptyView()
            }
        }
    }

    private func stageCell(_ species: Species, _ stage: Int, mood: Mood = .content, hour h: Int = 13, colour: Int = 0, item: DecorItem? = nil, label: String) -> some View {
        var layout = SceneLayout()
        if let item { layout.place(.item(item)) }
        return cell(ScenePortrait(companion: Companion(species: species, seed: Self.seed, startedAt: .distantPast), progress: Self.stageProgress[stage], mood: mood,
                                  stage: stage, now: hour(h), layout: layout, colourway: colour), label)
    }

    private func title(_ text: String) -> some View {
        Text(verbatim: text).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
    }

    private func stageMoods(_ species: Species) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            title("\(species.rawValue) - stages 2-6, bright content thirsty dozing")
            ForEach(2...6, id: \.self) { stage in
                HStack(spacing: 3) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        stageCell(species, stage, mood: mood, label: "\(Self.stageNames[stage]) \(mood.rawValue)")
                    }
                }
            }
        }
        .padding(.horizontal, 3)
    }

    private func stageMoodLarge(_ species: Species, stage: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title("\(species.rawValue) - \(Self.stageNames[stage]), the four moods")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    stageCell(species, stage, mood: mood, label: mood.rawValue)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func stageColours(_ species: Species) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            title("\(species.rawValue) - colourways 0-3, stages 2-6")
            ForEach(0...3, id: \.self) { colour in
                HStack(spacing: 3) {
                    ForEach(2...6, id: \.self) { stage in
                        stageCell(species, stage, colour: colour, label: "c\(colour) \(Self.stageNames[stage])")
                    }
                }
            }
        }
        .padding(.horizontal, 3)
    }

    private func stageColourLarge(_ species: Species, colour: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title("\(species.rawValue) - colourway \(colour), the stages")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(0...6, id: \.self) { stage in
                    stageCell(species, stage, colour: colour, label: Self.stageNames[stage])
                }
                stageCell(species, 6, hour: 19, colour: colour, label: "grown, dusk")
            }
        }
        .padding(.horizontal, 4)
    }

    private func stageWear(_ species: Species) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            title("\(species.rawValue) - party hat, bow, scarf, crown on stages 2-6")
            ForEach([DecorItem.partyHat, .bow, .scarf, .tinyCrown], id: \.self) { item in
                HStack(spacing: 3) {
                    ForEach(2...6, id: \.self) { stage in
                        stageCell(species, stage, mood: .bright, item: item, label: "\(item.rawValue) \(Self.stageNames[stage])")
                    }
                }
            }
        }
        .padding(.horizontal, 3)
    }

    private func stageNight(_ species: Species) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            title("\(species.rawValue) - stages 2-6 at dusk, by night, by the moon")
            ForEach([(19, "dusk"), (22, "night"), (1, "moon")], id: \.0) { h, name in
                HStack(spacing: 3) {
                    ForEach(2...6, id: \.self) { stage in
                        stageCell(species, stage, hour: h, label: "\(name) \(Self.stageNames[stage])")
                    }
                }
            }
        }
        .padding(.horizontal, 3)
    }
}
#endif
