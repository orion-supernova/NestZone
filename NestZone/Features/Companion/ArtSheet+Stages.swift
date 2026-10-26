#if DEBUG
import SwiftUI

/// The life stages of a mammal pet side by side, for the art pass
/// (`RULES-pets.md`, "Life stages"). Every cell is a `ScenePortrait`, zoomed on
/// the pet so the proportions can be judged at a glance.
///
///   -artSheet kitten-life      every stage from baby to grown, in the four moods
///   -artSheet kitten-life3     one stage large, in the four moods (3, 4, 5, 6)
///   -artSheet kitten-lifedusk  the four stages by dusk and by moonlight
///   -artSheet kitten-lifewear  every stage in a party hat, a crown, a bow and a scarf
///   -artSheet kitten-lifecolour  every stage in the original and the three colourways
extension ArtSheet {
    static let lifeStages: [(String, Double, Int)] = [("baby", 0.47, 3), ("little", 0.66, 4), ("young", 0.85, 5), ("grown", 0.97, 6)]

    func isLifePage(_ page: String) -> Species? {
        for suffix in ["-lifewear", "-lifecolour", "-lifedusk", "-life3", "-life4", "-life5", "-life6", "-life"] where page.hasSuffix(suffix) {
            if let species = Species(rawValue: String(page.dropLast(suffix.count))), species.isPet { return species }
        }
        return nil
    }

    @ViewBuilder
    func lifeSheet(_ species: Species, page: String) -> some View {
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        if page.hasSuffix("-lifewear") {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "\(species.rawValue) - hat, crown, bow, scarf").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                ForEach(Self.lifeStages, id: \.2) { row in
                    HStack(spacing: 3) {
                        ForEach([DecorItem.partyHat, .tinyCrown, .bow, .scarf], id: \.self) { item in
                            var layout = SceneLayout()
                            let _ = layout.place(.item(item))
                            lifeCell(ScenePortrait(companion: companion, progress: row.1, mood: .content, stage: row.2, now: hour(13), layout: layout), "\(row.0) \(item.rawValue)")
                        }
                    }
                }
            }
            .padding(.horizontal, 3)
        } else if page.hasSuffix("-lifecolour") {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "\(species.rawValue) - the original, then colourways 1 to 3").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                ForEach(Self.lifeStages, id: \.2) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { colour in
                            lifeCell(ScenePortrait(companion: companion, progress: row.1, mood: .content, stage: row.2, now: hour(13), colourway: colour), "\(row.0) colour \(colour)")
                        }
                    }
                }
            }
            .padding(.horizontal, 3)
        } else if page.hasSuffix("-lifedusk") {
            lifeGrid(companion, rows: Self.lifeStages, columns: [("dusk", .content, 19), ("night", .content, 22), ("moon", .content, 1), ("dusk bright", .bright, 19)])
        } else if let n = ["3", "4", "5", "6"].first(where: { page.hasSuffix("-life" + $0) }), let stage = Int(n), let row = Self.lifeStages.first(where: { $0.2 == stage }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(species.rawValue) - \(row.0), the four moods").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        cell(ScenePortrait(companion: companion, progress: row.1, mood: mood, stage: stage, now: hour(13)), mood.rawValue)
                    }
                }
            }
            .padding(.horizontal, 4)
        } else {
            lifeGrid(companion, rows: Self.lifeStages, columns: Mood.allCases.map { ($0.rawValue, $0, 13) })
        }
    }

    private func lifeCell(_ portrait: ScenePortrait, _ label: String) -> some View {
        portrait
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(1.6, anchor: UnitPoint(x: 0.5, y: 0.97))
            .clipShape(.rect(cornerRadius: 6))
            .overlay(alignment: .topLeading) { Text(verbatim: label).font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(2) }
    }

    private func lifeGrid(_ companion: Companion, rows: [(String, Double, Int)], columns: [(String, Mood, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: "\(companion.species.rawValue) - baby, little, young, grown").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            ForEach(rows, id: \.2) { row in
                HStack(spacing: 3) {
                    ForEach(columns, id: \.0) { column in
                        lifeCell(ScenePortrait(companion: companion, progress: row.1, mood: column.1, stage: row.2, now: hour(column.2)), "\(row.0) \(column.0)")
                    }
                }
            }
        }
        .padding(.horizontal, 3)
    }
}
#endif
