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

    static let seed = "bench-home-0"
    func hour(_ h: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date()) ?? Date() }

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
            case "pomegranate-young": pomegranateYoung
            case "pomegranate-crown": pomegranateCrown
            case "pomegranate-fruit": pomegranateFruit
            case "pomegranate-shop": pomegranateShop
            case "gpu": gpuTest
            case "pet-redraw": petRedraw
            case "pet-variants": petVariants
            default:
                if let (species, kind) = Self.treePage(page) { treePage(species, kind) }
                else if let species = Species(rawValue: page) { speciesPage(species) }
                else if page.hasSuffix("-close"), let species = Species(rawValue: String(page.dropLast(6))), species.isPet { petClose(species) }
                else if page.hasSuffix("-stages"), let species = Species(rawValue: String(page.dropLast(7))), species.isPet { petStagesLarge(species) }
                else if page.hasSuffix("-moods"), let species = Species(rawValue: String(page.dropLast(6))), species.isPet { petMoods(species) }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { FrameMeter.shared.startIfAsked() }
    }

    // MARK: One species

    static let plantStages: [(String, Double)] = [("seed", 0.04), ("sprout", 0.16), ("young", 0.38), ("growing", 0.62), ("budding", 0.8), ("grown", 0.97)]
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

    func cell(_ portrait: ScenePortrait, _ label: String) -> some View {
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
                zoom(0.97, 13, x: -22, y: 56, width: 46, cell: CGSize(width: 195, height: 195), "fruit, split")
                crop(0.80, 13, -778, -553, "flowers")
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: A pet, large

    /// The grown pet at the size of the card by day, at dusk and by night,
    /// then its face cropped out of a drawing 800 points tall, so the eyes,
    /// the muzzle and the fur edge are real pixels rather than a scaled-up
    /// small picture.
    ///   -artSheet kitten-close   (any pet species)
    private func petClose(_ species: Species) -> some View {
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        // The head's centre in the 120-unit box, then in the scene and in a
        // 1400-point drawing of it (the scene is 360 tall, the pet 190).
        let head = CritterPlan.of(species)?.body == .perched ? CGPoint(x: 60, y: 50) : CGPoint(x: 47, y: 49)
        let k = 190.0 / 120, big = 800.0 / SceneSpace.height
        let hx = 400 + (head.x - 60) * k * big, hy = (SceneSpace.floor - 4 + (head.y - 108) * k) * big
        func face(_ h: Int, _ mood: Mood, _ label: String, dx: Double = 0, dy: Double = 0) -> some View {
            ScenePortrait(companion: companion, progress: 0.97, mood: mood, stage: 6, now: hour(h))
                .frame(width: 800, height: 800)
                .offset(x: -(hx - 98) + dx, y: -(hy - 98) + dy)
                .frame(width: 196, height: 196, alignment: .topLeading)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(alignment: .topLeading) { Text(verbatim: label).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(3) }
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(species.rawValue) - the card, day, dusk, night").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            ScenePortrait(companion: companion, progress: 0.97, mood: .content, stage: 6, now: hour(13)).frame(height: 330).clipShape(.rect(cornerRadius: 8))
            HStack(spacing: 4) {
                ScenePortrait(companion: companion, progress: 0.97, mood: .content, stage: 6, now: hour(19)).frame(height: 200).clipShape(.rect(cornerRadius: 8))
                ScenePortrait(companion: companion, progress: 0.97, mood: .content, stage: 6, now: hour(22)).frame(height: 200).clipShape(.rect(cornerRadius: 8))
            }
            HStack(spacing: 4) {
                face(13, .thirsty, "face, day, thirsty", dx: 34, dy: -42)
                face(19, .content, "face, dusk, content")
            }
        }
        .padding(.horizontal, 4)
    }

    /// Every stage, large, two to a row, then the grown pet at dusk.
    ///   -artSheet kitten-stages
    private func petStagesLarge(_ species: Species) -> some View {
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(species.rawValue) - the stages, large").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(Array(Self.petStages.enumerated()), id: \.offset) { index, item in
                    cell(ScenePortrait(companion: companion, progress: item.1, mood: .content, stage: index, now: hour(13)), item.0)
                }
                cell(ScenePortrait(companion: companion, progress: 0.97, mood: .content, stage: 6, now: hour(19)), "grown, dusk")
            }
        }
        .padding(.horizontal, 4)
    }

    /// The four moods, large, by day, and the light across the day.
    ///   -artSheet kitten-moods
    private func petMoods(_ species: Species) -> some View {
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(species.rawValue) - moods, then the light").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    cell(ScenePortrait(companion: companion, progress: 0.97, mood: mood, stage: 6, now: hour(13)), mood.rawValue)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach([("morning", 8), ("evening", 18), ("night", 22), ("moon", 1)], id: \.0) { name, h in
                    cell(ScenePortrait(companion: companion, progress: 0.97, mood: .content, stage: 6, now: hour(h)), name)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    /// The kitten's plan with other numbers: a hamster, a bunny, a puppy and a
    /// fox, content and wanting a drink, none of them in the app. What they
    /// inherit (the eyes, the light, the fur, the bowl, the moods) comes
    /// through `CritterPlan`'s parameters and nothing else.
    ///   -artSheet pet-variants
    private var petVariants: some View {
        let companion = Companion(species: .kitten, seed: Self.seed, startedAt: .distantPast)
        func cell(_ name: String, _ mood: Mood) -> some View {
            Canvas { context, size in
                CritterPlan.debugOverride = CritterPlan.variant(name)
                defer { CritterPlan.debugOverride = nil }
                let snapshot = SceneSnapshot(still: companion, progress: 0.97, mood: mood, stage: 6, now: hour(13), reduceMotion: false)
                snapshot.drawBack(context, size: size, at: snapshot.epoch.addingTimeInterval(mood == .content ? 0 : 3))
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                Text(verbatim: "\(name) \(mood.rawValue)").font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(3)
            }
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "the kitten's plan, four more rows").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(["hamster", "bunny", "puppy", "fox"], id: \.self) { name in
                    cell(name, .content)
                    cell(name, .thirsty)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    /// Four pets drawn every frame, which is what a pet always is: the worst
    /// the app asks of a painter, with the cost logged by `PetTiming`.
    ///   -artSheet pet-redraw -frameMeter 1 [-artSheetSpecies owl] [-artSheetCount 1]
    private var petRedraw: some View {
        let species = UserDefaults.standard.string(forKey: "artSheetSpecies").flatMap(Species.init(rawValue:)) ?? .kitten
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast)
        let count = UserDefaults.standard.integer(forKey: "artSheetCount") == 0 ? 4 : UserDefaults.standard.integer(forKey: "artSheetCount")
        let mood = UserDefaults.standard.string(forKey: "artSheetMood").flatMap(Mood.init(rawValue:)) ?? .content
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    Canvas { context, size in
                        let snapshot = SceneSnapshot(still: companion, progress: 0.97, mood: mood, stage: 6, now: hour(13), reduceMotion: false)
                        snapshot.drawBack(context, size: size, at: timeline.date)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: The pomegranate, round two

    /// A crop of the scene drawn large (not scaled up), centred on a point in
    /// scene units from the trunk's base (x right, y up), `width` units wide.
    private func zoom(_ progress: Double, _ h: Int, mood: Mood = .content, x: Double = 0, y: Double = 90, width: Double = 150,
                      cell: CGSize = CGSize(width: 195, height: 250), _ label: String) -> some View {
        let companion = Companion(species: .pomegranate, seed: Self.seed, startedAt: .distantPast)
        let f = 360 * cell.width / width
        let px = f / 2 + x * f / 360, py = f * 282 / 360 - y * f / 360
        return ScenePortrait(companion: companion, progress: progress, mood: mood, stage: 5, now: hour(h))
            .frame(width: f, height: f)
            .offset(x: cell.width / 2 - px, y: cell.height / 2 - py)
            .frame(width: cell.width, height: cell.height, alignment: .topLeading)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(alignment: .topLeading) { Text(verbatim: label).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).padding(3) }
    }

    /// The young stages, enlarged: the whip and its first sprigs.
    ///   -artSheet pomegranate-young
    private var pomegranateYoung: some View {
        let stages: [(Double, String)] = [(0.2, ".20"), (0.3, ".30"), (0.38, "young .38"), (0.46, ".46"), (0.54, ".54"), (0.62, "growing .62")]
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(195), spacing: 4), count: 2), spacing: 4) {
            ForEach(stages, id: \.1) { item in
                zoom(item.0, 13, y: 62, width: 130, cell: CGSize(width: 195, height: 250), item.1)
            }
        }
    }

    /// The grown crown, big: day, dusk, night, and the moon side.
    ///   -artSheet pomegranate-crown
    private var pomegranateCrown: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                zoom(0.97, 13, y: 105, width: 215, cell: CGSize(width: 195, height: 215), "day 13h")
                zoom(0.97, 19, y: 105, width: 215, cell: CGSize(width: 195, height: 215), "dusk 19h")
            }
            HStack(spacing: 4) {
                zoom(0.97, 22, y: 105, width: 215, cell: CGSize(width: 195, height: 215), "night 22h")
                zoom(0.97, 8, y: 105, width: 215, cell: CGSize(width: 195, height: 215), "morning 8h")
            }
            HStack(spacing: 4) {
                zoom(0.97, 13, mood: .thirsty, y: 105, width: 215, cell: CGSize(width: 195, height: 215), "thirsty")
                zoom(0.97, 13, mood: .dozing, y: 105, width: 215, cell: CGSize(width: 195, height: 215), "dozing")
            }
        }
    }

    /// At the size the shop shows it (a cell of about 110 points), day and night.
    ///   -artSheet pomegranate-shop
    private var pomegranateShop: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach([13, 21], id: \.self) { h in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach([Mood.bright, .content, .thirsty], id: \.self) { mood in
                        SpeciesPortrait(species: .pomegranate, seed: Self.seed, hour: h, mood: mood)
                            .aspectRatio(1, contentMode: .fit)
                            .background(h == 13 ? SceneInk.dayWell : SceneInk.duskWell)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    /// The fruit, nested in the crown, and the split one, close.
    ///   -artSheet pomegranate-fruit
    private var pomegranateFruit: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                zoom(0.97, 13, x: 0, y: 62, width: 110, cell: CGSize(width: 195, height: 195), "fruit, day")
                zoom(0.97, 19, x: 0, y: 62, width: 110, cell: CGSize(width: 195, height: 195), "fruit, dusk")
            }
            HStack(spacing: 4) {
                zoom(0.97, 13, x: -24, y: 53, width: 44, cell: CGSize(width: 195, height: 195), "split, day")
                zoom(0.97, 22, x: -24, y: 53, width: 44, cell: CGSize(width: 195, height: 195), "split, night")
            }
            HStack(spacing: 4) {
                zoom(0.88, 13, x: 0, y: 62, width: 110, cell: CGSize(width: 195, height: 195), "ripening .88")
                zoom(0.97, 13, mood: .thirsty, x: 0, y: 62, width: 110, cell: CGSize(width: 195, height: 195), "thirsty")
            }
        }
    }

    // MARK: What the GPU charges for

    /// Four canvases of 700 leaves redrawn every frame, laid out the way
    /// `-gpuTest N` says, to see what costs the simulator's GPU: a fill per
    /// leaf, a fill per clump, one fill, unit-space paths under a transform,
    /// a gradient. Read the late frames with `-frameMeter 1`.
    private var gpuTest: some View {
        let mode = UserDefaults.standard.integer(forKey: "gpuTest")
        return TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(0..<4, id: \.self) { n in
                    GpuCell(n: n, mode: mode, t: t)
                    .frame(height: 220)
                    .background(Color.gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 4)
        }
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
/// One canvas of `ArtSheet`'s GPU test; its own view so that a new `t`
/// really does draw it again.
private struct GpuCell: View {
    let n: Int, mode: Int, t: Double

    var body: some View {
        Canvas { context, size in
                        var r = Ink.Random(seed: UInt32(n + 1))
                        let shift = sin(t * 3) * 2
                        var all = Path()
                        let classes = (mode == 4 ? 4 : 1)
                        for g in 0..<28 {
                            let cx = 40 + r.next() * (size.width - 80), cy = 40 + r.next() * (size.height - 80)
                            var groups = Array(repeating: Path(), count: classes)
                            var unit = Path()
                            for k in 0..<25 {
                                let a = r.next() * 6.28, d = r.next() * 24, la = r.next() * 6.28
                                let x = cx + cos(a) * d + shift, y = cy + sin(a) * d
                                let ca = cos(la), sa = sin(la), len = 12.0, hw = 2.2
                                var leaf = Path()
                                leaf.lance(x, y, ca, sa, len, hw, 0.1, 0)
                                if mode == 0 { context.fill(leaf, with: .color(.green.opacity(0.9))) }
                                groups[k % classes].addPath(leaf)
                                unit.lance((x - cx) / 24, (y - cy) / 24, ca, sa, len / 24, hw / 24, 0.1, 0)
                            }
                            let color = Color(hue: 0.3, saturation: 0.6, brightness: 0.3 + 0.03 * Double(g % 10))
                            switch mode {
                            case 1, 4: for (c, path) in groups.enumerated() { context.fill(path, with: .color(color.opacity(1 - 0.05 * Double(c)))) }
                            case 2:
                                var u = context
                                u.translateBy(x: cx, y: cy)
                                u.scaleBy(x: 24, y: 24)
                                u.fill(unit, with: .color(color))
                            case 3: all.addPath(groups[0])
                            case 5: context.fill(groups[0], with: .linearGradient(Gradient(colors: [color, .white]), startPoint: CGPoint(x: cx - 20, y: cy - 20), endPoint: CGPoint(x: cx + 20, y: cy + 20)))
                            case 6: context.stroke(groups[0], with: .color(color), lineWidth: 0.6)
                            default: break
                            }
                        }
                        if mode == 3 { context.fill(all, with: .color(.green)) }
                    }
        .drawingGroup()
    }
}

#endif
