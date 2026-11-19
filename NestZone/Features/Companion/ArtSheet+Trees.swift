#if DEBUG
import SwiftUI

/// Contact sheets for the five trees brought up to the pomegranate's level,
/// one set of pages for each, named `<tree>-<page>`:
///
///   -artSheet lemon-crown    the grown crown big: day, dusk, night, morning, thirsty, dozing
///   -artSheet lemon-detail   eight close crops: what makes the tree itself
///   -artSheet lemon-young    the stages between a sprout and a crown, enlarged
///   -artSheet lemon-night    the stages and the light by night, and the moods
///   -artSheet lemon-shop     the size of a shop cell, day and night
///
/// Every cell is drawn large rather than scaled up, so the detail is real.
extension ArtSheet {
    static let trees: [Species] = [.lemon, .olive, .magnolia, .cherry, .azalea]

    static func treePage(_ page: String) -> (Species, String)? {
        guard let dash = page.firstIndex(of: "-"), let species = Species(rawValue: String(page[..<dash])), trees.contains(species) else { return nil }
        return (species, String(page[page.index(after: dash)...]))
    }

    /// One crop: what it is called, the growth and the hour it is drawn at, and
    /// where to look, in scene units from the trunk's base (x right, y up).
    struct Crop {
        var label: String
        var progress: Double, hour: Int
        var x: Double, y: Double, width: Double
        var mood: Mood = .content
    }

    /// Where to look for each tree's own parts.
    static func details(_ s: Species) -> (crown: CGPoint, width: Double, crops: [Crop]) {
        switch s {
        case .lemon:
            return (CGPoint(x: 0, y: 110), 215, [
                Crop(label: "flowers", progress: 0.8, hour: 13, x: -10, y: 120, width: 70),
                Crop(label: "flowers, dusk", progress: 0.8, hour: 19, x: -10, y: 120, width: 70),
                Crop(label: "fruit", progress: 0.97, hour: 13, x: 45, y: 90, width: 110),
                Crop(label: "ripening .88", progress: 0.88, hour: 13, x: 45, y: 90, width: 110),
                Crop(label: "cutaway", progress: 0.97, hour: 13, x: 60, y: 82, width: 50),
                Crop(label: "cutaway, night", progress: 0.97, hour: 22, x: 60, y: 82, width: 50),
                Crop(label: "bark", progress: 0.97, hour: 13, x: 0, y: 30, width: 60),
                Crop(label: "thirsty", progress: 0.97, hour: 13, x: 30, y: 85, width: 110, mood: .thirsty)])
        case .olive:
            return (CGPoint(x: 0, y: 110), 215, [
                Crop(label: "flowers", progress: 0.8, hour: 13, x: 5, y: 165, width: 70),
                Crop(label: "leaves, dusk", progress: 0.97, hour: 19, x: 0, y: 140, width: 70),
                Crop(label: "olives", progress: 0.97, hour: 13, x: 40, y: 82, width: 70),
                Crop(label: "ripening .88", progress: 0.88, hour: 13, x: 40, y: 82, width: 70),
                Crop(label: "hollow", progress: 0.97, hour: 13, x: 0, y: 36, width: 46),
                Crop(label: "hollow, night", progress: 0.97, hour: 22, x: 0, y: 36, width: 46),
                Crop(label: "young trunk .38", progress: 0.38, hour: 13, x: 0, y: 30, width: 50),
                Crop(label: "thirsty", progress: 0.97, hour: 13, x: 20, y: 95, width: 110, mood: .thirsty)])
        case .magnolia:
            return (CGPoint(x: 0, y: 115), 230, [
                Crop(label: "bare wood, buds .62", progress: 0.62, hour: 13, x: 0, y: 115, width: 110),
                Crop(label: "budding .8", progress: 0.8, hour: 13, x: 0, y: 140, width: 110),
                Crop(label: "goblet", progress: 0.8, hour: 13, x: 6, y: 160, width: 40),
                Crop(label: "goblet, night", progress: 0.8, hour: 22, x: 6, y: 160, width: 40),
                Crop(label: "leaves, grown", progress: 0.97, hour: 13, x: 0, y: 145, width: 90),
                Crop(label: "leaves, dusk", progress: 0.97, hour: 19, x: 0, y: 145, width: 90),
                Crop(label: "bark", progress: 0.97, hour: 13, x: 0, y: 40, width: 60),
                Crop(label: "petals on the soil", progress: 0.97, hour: 13, x: 0, y: 8, width: 70)])
        case .cherry:
            return (CGPoint(x: 0, y: 110), 230, [
                Crop(label: "blossom", progress: 0.97, hour: 13, x: 21, y: 140, width: 60),
                Crop(label: "blossom, dusk", progress: 0.97, hour: 19, x: 21, y: 140, width: 60),
                Crop(label: "cherries", progress: 0.97, hour: 13, x: 30, y: 95, width: 80),
                Crop(label: "ripening .88", progress: 0.88, hour: 13, x: 30, y: 95, width: 80),
                Crop(label: "budding .8", progress: 0.8, hour: 13, x: 0, y: 125, width: 100),
                Crop(label: "bud .66", progress: 0.66, hour: 13, x: 0, y: 105, width: 100),
                Crop(label: "bark", progress: 0.97, hour: 13, x: 0, y: 35, width: 60),
                Crop(label: "petals", progress: 0.97, hour: 13, x: 0, y: 25, width: 120)])
        default:
            return (CGPoint(x: 0, y: 85), 230, [
                Crop(label: "flowers", progress: 0.97, hour: 13, x: -30, y: 80, width: 60),
                Crop(label: "flowers, dusk", progress: 0.97, hour: 19, x: -30, y: 80, width: 60),
                Crop(label: "throats", progress: 0.97, hour: 13, x: -38, y: 72, width: 28),
                Crop(label: "sunlit, top", progress: 0.97, hour: 13, x: 12, y: 130, width: 60),
                Crop(label: "budding .8", progress: 0.8, hour: 13, x: 0, y: 85, width: 110),
                Crop(label: "bud .62", progress: 0.62, hour: 13, x: 0, y: 75, width: 110),
                Crop(label: "base", progress: 0.97, hour: 13, x: 0, y: 25, width: 60),
                Crop(label: "thirsty", progress: 0.97, hour: 13, x: 0, y: 85, width: 110, mood: .thirsty)])
        }
    }

    func zoomTree(_ species: Species, _ progress: Double, _ h: Int, mood: Mood = .content, at centre: CGPoint, width: Double,
                  cell size: CGSize = CGSize(width: 195, height: 215), _ label: String) -> some View {
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        let f = 360 * size.width / width
        let px = f / 2 + centre.x * f / 360, py = f * 282 / 360 - centre.y * f / 360
        return ScenePortrait(companion: companion, progress: progress, mood: mood, stage: 5, now: hour(h))
            .frame(width: f, height: f)
            .offset(x: size.width / 2 - px, y: size.height / 2 - py)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(alignment: .topLeading) { Text(verbatim: label).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(3) }
    }

    @ViewBuilder
    func treePage(_ species: Species, _ kind: String) -> some View {
        let (crown, crownWidth, crops) = Self.details(species)
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        switch kind {
        case "crown":
            VStack(spacing: 4) {
                ForEach([[("day 13h", 13, Mood.content), ("dusk 19h", 19, .content)], [("night 22h", 22, .content), ("morning 8h", 8, .content)],
                         [("thirsty", 13, .thirsty), ("dozing", 13, .dozing)]], id: \.[0].0) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.0) { item in
                            zoomTree(species, 0.97, item.1, mood: item.2, at: crown, width: crownWidth, item.0)
                        }
                    }
                }
            }
        case "detail":
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(195), spacing: 4), count: 2), spacing: 4) {
                ForEach(crops, id: \.label) { crop in
                    zoomTree(species, crop.progress, crop.hour, mood: crop.mood, at: CGPoint(x: crop.x, y: crop.y), width: crop.width,
                             cell: CGSize(width: 195, height: 195), crop.label)
                }
            }
        case "young":
            let stages: [(Double, String)] = [(0.2, ".20"), (0.3, ".30"), (0.38, "young .38"), (0.46, ".46"), (0.54, ".54"), (0.62, "growing .62")]
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(195), spacing: 4), count: 2), spacing: 4) {
                ForEach(stages, id: \.1) { item in
                    zoomTree(species, item.0, 13, at: CGPoint(x: 0, y: 62), width: 130, cell: CGSize(width: 195, height: 250), item.1)
                }
            }
        case "night":
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(species.rawValue) - night, moods, light").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(Array(Self.plantStages.enumerated()).suffix(3), id: \.offset) { index, item in
                        cell(ScenePortrait(companion: companion, progress: item.1, mood: .content, stage: index, now: hour(22)), item.0 + " 22h")
                    }
                    ForEach([("morning", 8), ("evening", 18), ("moon", 23)], id: \.0) { name, h in
                        cell(ScenePortrait(companion: companion, progress: 0.97, mood: .bright, stage: 5, now: hour(h)), name)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        cell(ScenePortrait(companion: companion, progress: 0.97, mood: mood, stage: 5, now: hour(13)), mood.rawValue)
                    }
                }
            }
            .padding(.horizontal, 4)
        case "shop":
            VStack(alignment: .leading, spacing: 6) {
                ForEach([13, 21], id: \.self) { h in
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach([Mood.bright, .content, .thirsty], id: \.self) { mood in
                            SpeciesPortrait(species: species, seed: Self.seed, hour: h, mood: mood)
                                .aspectRatio(1, contentMode: .fit)
                                .background(h == 13 ? SceneInk.dayWell : SceneInk.duskWell)
                                .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
        default:
            EmptyView()
        }
    }
}
#endif
