#if DEBUG
import SwiftUI

/// Contact sheets for the colourways, one set of pages for each species, named
/// `colours-<species>[-page]`:
///
///   -artSheet colours-kitten         the original and the three colours: the card by day (2 x 2), then
///                                    thirsty, dozing, dusk and night, one row each, 0 | 1 | 2 | 3
///   -artSheet colours-kitten-close   the face (a pet) or the crown (a plant or tree) cropped from a large
///                                    drawing, by day and by night, 0 | 1 / 2 | 3
///   -artSheet colours-kitten-stages  the growing stages, one row each, 0 | 1 | 2 | 3
///   -artSheet colours-kitten-names   what each colourway is called
///
/// Every cell is a `ScenePortrait`, as the shop and the album draw. The first
/// colour is always the original, drawn with an explicit 0 so that `-nestieColour`
/// cannot repaint it.
extension ArtSheet {
    /// `colours-grid-<pets|plants|trees>-<n>`: every species of a family in
    /// colourway n at the size the shop shows them, by day and by night.
    static func coloursGrid(_ page: String) -> ([Species], Int)? {
        let parts = page.split(separator: "-").map(String.init)
        guard parts.count == 4, parts[0] == "colours", parts[1] == "grid", let n = Int(parts[3]) else { return nil }
        switch parts[2] {
        case "pets": return (Species.allCases.filter { $0.isPet && $0.art == .critter }, n)
        case "trees": return ([.magnolia, .cherry, .pomegranate, .azalea, .lemon, .olive], n)
        case "plants": return (Species.allCases.filter { !$0.isPet && $0.art == .plant }, n)
        default: return nil
        }
    }

    func coloursGridSheet(_ species: [Species], _ n: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title("colourway \(n), at the shop's size, day and night")
            ForEach([13, 22], id: \.self) { h in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 5), spacing: 3) {
                    ForEach(species) { s in
                        SpeciesPortrait(species: s, seed: Self.seed, hour: h, mood: .bright, colourway: n)
                            .aspectRatio(1, contentMode: .fit)
                            .background(h == 13 ? SceneInk.dayWell : SceneInk.duskWell)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(.horizontal, 5)
    }

    static func coloursPage(_ page: String) -> (Species, String)? {
        guard page.hasPrefix("colours-") else { return nil }
        let rest = page.dropFirst("colours-".count)
        let parts = rest.split(separator: "-", maxSplits: 1).map(String.init)
        guard let first = parts.first, let species = Species(rawValue: first) else { return nil }
        return (species, parts.count > 1 ? parts[1] : "")
    }

    private func coloured(_ species: Species, _ n: Int) -> Companion {
        Companion(species: species, seed: Self.seed, startedAt: .distantPast, colour: n)
    }

    private func label(_ species: Species, _ n: Int) -> String {
        n == 0 ? "0 original" : "\(n) \(String(localized: species.colourName(n)))"
    }

    private func stageIndex(_ species: Species) -> Int { species.isPet ? 6 : 5 }

    @ViewBuilder
    func colours(_ species: Species, _ kind: String) -> some View {
        switch kind {
        case "close": coloursClose(species)
        case "stages": coloursStages(species)
        case "names": coloursNames(species)
        default: coloursCard(species)
        }
    }

    private func title(_ text: String) -> some View {
        Text(verbatim: text).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
    }

    private func coloursCard(_ species: Species) -> some View {
        let stage = stageIndex(species)
        return VStack(alignment: .leading, spacing: 3) {
            title("\(species.rawValue) - colourways, the card by day, then thirsty, dozing, dusk, night")
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(168), spacing: 4), count: 2), spacing: 4) {
                ForEach(0...Colourway.count, id: \.self) { n in
                    cell(ScenePortrait(companion: coloured(species, n), progress: 0.97, mood: .content, stage: stage, now: hour(13)), label(species, n))
                }
            }
            ForEach([("thirsty", Mood.thirsty, 13), ("dozing", .dozing, 13), ("dusk", .bright, 19), ("night", .content, 22)], id: \.0) { name, mood, h in
                HStack(spacing: 3) {
                    ForEach(0...Colourway.count, id: \.self) { n in
                        cell(ScenePortrait(companion: coloured(species, n), progress: 0.97, mood: mood, stage: stage, now: hour(h)), "\(n) \(name)")
                    }
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private func coloursStages(_ species: Species) -> some View {
        let stages: [(String, Double, Int)] = species.isPet
            ? [("baby", 0.47, 3), ("little", 0.66, 4), ("young", 0.85, 5), ("hatchling", 0.28, 2), ("egg", 0.02, 0)]
            : [("young .38", 0.38, 2), ("growing .62", 0.62, 3), ("budding .8", 0.8, 4), ("grown .97", 0.97, 5), ("seed .04", 0.04, 0)]
        return VStack(alignment: .leading, spacing: 3) {
            title("\(species.rawValue) - colourways through the stages")
            ForEach(stages, id: \.0) { name, progress, stage in
                HStack(spacing: 3) {
                    ForEach(0...Colourway.count, id: \.self) { n in
                        cell(ScenePortrait(companion: coloured(species, n), progress: progress, mood: .content, stage: stage, now: hour(13)), "\(n) \(name)")
                    }
                }
            }
        }
        .padding(.horizontal, 6)
    }

    /// The face of a pet, or the crown of a plant or tree, from a drawing 800
    /// points tall, so the colour, the pattern and the marking are real pixels.
    private func coloursClose(_ species: Species) -> some View {
        let stage = stageIndex(species)
        let focus = Self.coloursFocus(species)
        func crop(_ n: Int, _ h: Int, _ mood: Mood) -> some View {
            let f = 360 * 195 / focus.width
            let px = f / 2 + focus.x * f / 360, py = f * 282 / 360 - focus.y * f / 360
            return ScenePortrait(companion: coloured(species, n), progress: focus.progress, mood: mood, stage: stage, now: hour(h))
                .frame(width: f, height: f)
                .offset(x: 195 / 2 - px, y: 195 / 2 - py)
                .frame(width: 195, height: 195, alignment: .topLeading)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(alignment: .topLeading) { Text(verbatim: "\(label(species, n)) \(h)h").font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(3) }
        }
        return VStack(alignment: .leading, spacing: 3) {
            title("\(species.rawValue) - close, day and night")
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(195), spacing: 4), count: 2), spacing: 4) {
                ForEach(Array([13, 22].flatMap { h in (0...Colourway.count).map { (h, $0) } }.enumerated()), id: \.offset) { _, cell in
                    crop(cell.1, cell.0, .bright)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func coloursNames(_ species: Species) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            title("\(species.rawValue) - names")
            ForEach(1...Colourway.count, id: \.self) { n in
                Text(verbatim: "\(n)  \(String(localized: species.colourName(n)))").font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
            }
        }
        .padding(8)
    }

    /// Where a species' colour is: the face of a pet (its drawing's head, in
    /// the scene), the crown of a plant or tree. Scene units from the foot, x
    /// right and y up, and how wide a crop is.
    struct ColoursFocus { var x, y, width, progress: Double }

    static func coloursFocus(_ species: Species) -> ColoursFocus {
        if species.isPet {
            let head = CritterPainter.faceSpot(CritterPlan.of(species))
            let k = 190.0 / 120
            // The pet stands on the scene's floor, not the plant's soil: from the foot (soil) up.
            let sceneY = SceneSpace.floor - 4 + (head.y - 108) * k
            return ColoursFocus(x: (head.x - 60) * k, y: SceneSpace.soil - sceneY, width: 100, progress: 0.97)
        }
        if let plan = PlantPlan.of(species) {
            let a = PlantPainter(plan: plan, seed: Self.seed, growth: 0.97, mood: 0.62, day: 1, light: -0.5).anchors()
            return ColoursFocus(x: (a.left + a.right) / 2, y: -(a.top * 0.62 + a.bottom * 0.38), width: max(90, min(190, max(a.right - a.left, (a.bottom - a.top) * 0.8) * 0.9)), progress: 0.97)
        }
        let details = Self.details(species)
        return ColoursFocus(x: details.crown.x, y: details.crown.y, width: details.width * 0.75, progress: 0.97)
    }
}
#endif
