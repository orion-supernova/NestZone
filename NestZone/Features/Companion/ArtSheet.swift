#if DEBUG
import SwiftUI

/// A contact sheet for the art pass, so a drawing can be judged at a glance:
/// one species at every stage by day and at dusk and in every mood, the
/// decorations in a scene, or a grid at the size the shop shows them.
///
///   xcrun simctl launch booted com.walhallaa.NestZone -artSheet sunflower
///   xcrun simctl launch booted com.walhallaa.NestZone -artSheet decor
///   xcrun simctl launch booted com.walhallaa.NestZone -artSheet grid
///   xcrun simctl io booted screenshot sheet.png
///
/// Every cell is a `ScenePortrait`, one still canvas, the same thing Choose and
/// the album draw. Nothing here talks to a server.
struct ArtSheet: View {
    let page: String

    private static let seed = "bench-home-0"
    private func hour(_ h: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date()) ?? Date() }

    var body: some View {
        ZStack {
            Color(white: 0.1).ignoresSafeArea()
            switch page {
            case "decor": decor(0)
            case "decor2": decor(1)
            case "grid": grid
            case "pomegranate": pomegranateSheet
            case "pomegranate-night": pomegranateNight
            case "redraw": redraw
            case "pomegranate-close": pomegranateClose
            default:
                if let species = Species(rawValue: page) { speciesPage(species) }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { FrameMeter.shared.startIfAsked() }
    }

    // MARK: One species

    private static let plantStages: [(String, Double)] = [("seed", 0.04), ("sprout", 0.16), ("young", 0.38), ("growing", 0.62), ("budding", 0.8), ("grown", 0.97)]
    private static let petStages: [(String, Double)] = [("egg", 0.02), ("wobbly", 0.12), ("hatchling", 0.28), ("baby", 0.47), ("little", 0.66), ("young", 0.85), ("grown", 0.97)]

    private func speciesPage(_ species: Species) -> some View {
        let stages = species.isPet ? Self.petStages : Self.plantStages
        let columns = species.isPet ? 4 : 3
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        return VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: "\(species.rawValue)  -  day, dusk, moods")
                .font(.system(.footnote, design: .monospaced, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            ForEach([("day", 13), ("dusk", 19)], id: \.0) { name, h in
                Text(verbatim: name).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
                    ForEach(Array(stages.enumerated()), id: \.offset) { index, item in
                        cell(ScenePortrait(companion: companion, progress: item.1, mood: .content, stage: index, now: hour(h)), item.0)
                    }
                }
            }
            Text(verbatim: "moods, grown, day").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 4) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    cell(ScenePortrait(companion: companion, progress: 0.97, mood: mood, stage: species.isPet ? 6 : 5, now: hour(13)), mood.rawValue)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func cell(_ portrait: ScenePortrait, _ label: String) -> some View {
        portrait
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                Text(verbatim: label).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(3)
            }
    }

    // MARK: Redraw stress

    /// Four grown trees whose growth moves every frame, so each is drawn whole
    /// every frame: the worst case for a painter, which the app never asks of
    /// one (the tree layer is drawn only when its state changes). Read the
    /// late frames with `-frameMeter 1`; `-artSheetSpecies magnolia` swaps
    /// the tree, and `-pomegranateLegacy 1` draws the pomegranate the old way.
    ///   -artSheet redraw -frameMeter 1
    private var redraw: some View {
        let species = UserDefaults.standard.string(forKey: "artSheetSpecies").flatMap(Species.init(rawValue:)) ?? .pomegranate
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        let count = max(1, UserDefaults.standard.integer(forKey: "artSheetCount") == 0 ? 4 : UserDefaults.standard.integer(forKey: "artSheetCount"))
        return TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(0..<count, id: \.self) { i in
                    cell(ScenePortrait(companion: companion, progress: 0.8 + 0.17 * sin(t * 2 + Double(i)), mood: .content, stage: 5, now: hour(13)), "\(i)")
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: The pomegranate, the hero

    /// Every stage by day and at dusk, big enough to judge.
    ///   -artSheet pomegranate        day and dusk
    ///   -artSheet pomegranate-night  night, the moods, the light from each side
    private var pomegranateSheet: some View {
        let companion = Companion(species: .pomegranate, seed: Self.seed, startedAt: .distantPast)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "pomegranate - stages at 13h and 19h").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            ForEach([13, 19], id: \.self) { h in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(Array(Self.plantStages.enumerated()), id: \.offset) { index, item in
                        cell(ScenePortrait(companion: companion, progress: item.1, mood: .content, stage: index, now: hour(h)), item.0)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var pomegranateNight: some View {
        let companion = Companion(species: .pomegranate, seed: Self.seed, startedAt: .distantPast)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "pomegranate - night, moods, light").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
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
    }

    /// The grown tree at the size of the card, then close crops of its
    /// fruit and flowers, drawn large (not scaled up) so the detail is real.
    ///   -artSheet pomegranate-close
    private var pomegranateClose: some View {
        let companion = Companion(species: .pomegranate, seed: Self.seed, startedAt: .distantPast)
        func crop(_ progress: Double, _ h: Int, _ dx: Double, _ dy: Double, _ label: String) -> some View {
            ScenePortrait(companion: companion, progress: progress, mood: .content, stage: 5, now: hour(h))
                .frame(width: 1400, height: 1400)
                .offset(x: dx, y: dy)
                .frame(width: 195, height: 195, alignment: .topLeading)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(alignment: .topLeading) { Text(verbatim: label).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(3) }
        }
        return VStack(alignment: .leading, spacing: 4) {
            ScenePortrait(companion: companion, progress: 0.97, mood: .content, stage: 5, now: hour(13))
                .frame(height: 300).clipShape(.rect(cornerRadius: 8))
            ScenePortrait(companion: companion, progress: 0.97, mood: .content, stage: 5, now: hour(19))
                .frame(height: 300).clipShape(.rect(cornerRadius: 8))
            HStack(spacing: 4) {
                crop(0.97, 13, -739, -759, "fruit, split")
                crop(0.80, 13, -778, -553, "flowers")
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Decorations in a scene

    private func decor(_ page: Int) -> some View {
        let hat = DecorItem.partyHat.rawValue, feeder = DecorItem.birdFeeder.rawValue
        func layout(_ wearing: String?, _ left: String?) -> SceneLayout {
            var l = SceneLayout()
            l.wearing = wearing
            l.left = left
            return l
        }
        let all: [[(Species, String)]] = [[(.kitten, "hat and feeder"), (.sunflower, "hat and feeder"), (.owl, "hat")],
                                          [(.monstera, "feeder"), (.duckling, "hat and feeder"), (.cactus, "hat")]]
        let cases = all[page]
        return VStack(spacing: 4) {
            Text(verbatim: "party hat, bird feeder - day, dusk").font(.system(.footnote, design: .monospaced, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(Array(cases.flatMap { item in [13, 19].map { (item, $0) } }.enumerated()), id: \.offset) { _, pair in
                    let (item, h) = pair
                    let l = item.1.contains("hat") && item.1.contains("feeder") ? layout(hat, feeder)
                        : item.1 == "hat" ? layout(hat, nil) : layout(nil, feeder)
                    cell(ScenePortrait(companion: Companion(species: item.0, seed: Self.seed, startedAt: .distantPast), progress: 0.97, mood: .bright,
                                       stage: item.0.isPet ? 6 : 5, now: hour(h), layout: l), "\(item.0.rawValue) \(h)")
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: At the shop's size

    private var grid: some View {
        let species: [Species] = [.sunflower, .basil, .cactus, .monstera, .kitten, .owl, .magnolia, .duckling, .lemon]
        return VStack(alignment: .leading, spacing: 6) {
            ForEach([13, 21], id: \.self) { h in
                Text(verbatim: h == 13 ? "day" : "night").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(species) { s in
                        SpeciesPortrait(species: s, seed: Self.seed, hour: h, mood: .bright)
                            .aspectRatio(1, contentMode: .fit)
                            .background(h == 13 ? SceneInk.dayWell : SceneInk.duskWell)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }
}
#endif
