#if DEBUG
import OSLog
import SwiftUI

/// Whether a plant or a tree is whole at every growth, not only at the stages:
/// a foliage, blossom or fruit with no wood to hold it shows here. The pages,
/// for any tree or potted plant:
///
///   -artSheet magnolia-growth        twelve growths from seed to grown, by day
///   -artSheet magnolia-growth-wood   the same with the skeleton (cyan), the twigs
///                                    (yellow), each leaf mass (green ring), a green
///                                    dot on what is held and a red ring on what is not
///   -artSheet magnolia-scrub         the growth sweeping 0 to 1 and back, wood overlaid
///   -artSheet attach-scan            every tree at a hundred growths, four moods and
///                                    four seeds: how many things were looked at and
///                                    how many were not on wood (logged, category Attach)
///
/// `-artSheetMood dozing` and `-artSheetHour 21` pick the mood and the hour,
/// `-artSheetColour 2` a colourway, `-attachFix 0` the way it was drawn before.
extension ArtSheet {
    static let growths: [Double] = [0.06, 0.12, 0.2, 0.3, 0.4, 0.5, 0.58, 0.66, 0.74, 0.82, 0.9, 0.97]

    static func growthPage(_ page: String) -> (species: Species, kind: String)? {
        for kind in ["growth-wood", "growth", "scrub", "sleep"] where page.hasSuffix("-" + kind) {
            guard let species = Species(rawValue: String(page.dropLast(kind.count + 1))), !species.isPet else { return nil }
            return (species, kind)
        }
        return nil
    }

    private var sheetMood: Mood {
        UserDefaults.standard.string(forKey: "artSheetMood").flatMap(Mood.init(rawValue:)) ?? .content
    }

    private var sheetHour: Int {
        UserDefaults.standard.object(forKey: "artSheetHour") == nil ? 13 : UserDefaults.standard.integer(forKey: "artSheetHour")
    }

    /// One cell: the plant at this growth, framed to the height it has reached.
    func growthCell(_ companion: Companion, _ g: Double, wood: Bool, pixels: Bool = true, size: CGSize) -> some View {
        GrowthCell(companion: companion, g: g, wood: wood, pixels: pixels, size: size, mood: sheetMood, at: hour(sheetHour))
    }

    @ViewBuilder
    func growthSheet(_ species: Species, _ kind: String) -> some View {
        let colour = UserDefaults.standard.integer(forKey: "artSheetColour")
        let companion = Companion(species: species, seed: Self.seed, startedAt: .distantPast, colour: colour)
        let wood = kind != "growth"
        if kind == "sleep" {
            // Awake and asleep, side by side, at three sizes, the whole scene: the pot and its cozy,
            // the leaves, the blossoms and the z's.
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(species.rawValue) - awake, asleep - \(sheetHour)h").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                    ForEach([0.3, 0.66, 0.97], id: \.self) { g in
                        ForEach([Mood.content, .dozing], id: \.self) { mood in
                            cell(ScenePortrait(companion: companion, progress: g, mood: mood, stage: 5, now: hour(sheetHour)), "\(String(format: "%.2f", g)) \(mood.rawValue)")
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        } else if kind == "scrub" {
            ScrubSheet(companion: companion, mood: sheetMood, at: hour(sheetHour))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(species.rawValue) - growth\(wood ? ", wood" : "") - \(sheetMood.rawValue) \(sheetHour)h")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(130), spacing: 4), count: 3), spacing: 4) {
                    ForEach(Self.growths, id: \.self) { g in
                        growthCell(companion, g, wood: wood, size: CGSize(width: 130, height: 150))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: The scan

    /// Every tree at a hundred growths, four moods and four seeds.
    @ViewBuilder
    var attachScan: some View {
        AttachScanView(pixels: false)
    }

    @ViewBuilder
    var pixelScan: some View {
        AttachScanView(pixels: true)
    }
}

/// The growth sweeping up and down, the way the card's stepper scrubs it but faster, with the
/// skeleton drawn. A view of its own: a `TimelineView` inside `growthSheet`'s own conditional
/// kept every page of the sheet from ever laying out.
private struct ScrubSheet: View {
    let companion: Companion
    let mood: Mood
    let at: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            // Up and down in eight seconds.
            let g = 0.5 - 0.5 * cos(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 8)
            VStack(spacing: 6) {
                Text(verbatim: "\(companion.species.rawValue) \(String(format: "%.3f", g))").font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                GrowthCell(companion: companion, g: g, wood: true, pixels: false, size: CGSize(width: 380, height: 440), mood: mood, at: at)
            }
        }
    }
}

private struct GrowthCell: View {
    let companion: Companion
    let g: Double
    let wood: Bool
    let pixels: Bool
    let size: CGSize
    let mood: Mood
    let at: Date
    @State private var floaters: [PixelAudit.Floater] = []

    var body: some View {
        let width = g < 0.3 ? 90.0 : g < 0.5 ? 140 : g < 0.7 ? 190 : 250
        let f = 360 * size.width / width
        let px = f / 2, py = f * 282 / 360 - width * 0.48 * f / 360
        ScenePortrait(companion: companion, progress: g, mood: mood, stage: 5, now: at, debugWood: wood)
            .frame(width: f, height: f)
            .overlay {
                // Pieces the pixel audit finds floating, in red.
                Canvas { context, _ in
                    for floater in floaters {
                        let k = f / 360, r = CGRect(x: floater.rect.minX * k, y: floater.rect.minY * k, width: floater.rect.width * k, height: floater.rect.height * k).insetBy(dx: -2, dy: -2)
                        context.stroke(Path(roundedRect: r, cornerRadius: 2), with: .color(.red), lineWidth: 1.5)
                    }
                }
            }
            .offset(x: size.width / 2 - px, y: size.height / 2 - py)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(alignment: .topLeading) {
                Text(verbatim: String(format: "%.2f", g) + (floaters.isEmpty ? "" : "  \(floaters.count) off"))
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(floaters.isEmpty ? .black.opacity(0.6) : .red).padding(3)
            }
            .task(id: g) {
                guard wood, pixels else { return }
                floaters = PixelAudit.floaters(companion, progress: g, mood: mood, hour: at)
            }
    }
}

private struct AttachScanView: View {
    let pixels: Bool
    @State private var lines: [String] = ["scanning..."]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(8)
        }
        .task { lines = pixels ? await Self.pixelScan() : await Self.scan() }
    }

    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Attach")

    /// Every tree and plant, drawn at fifty growths in four moods, and what floats in the picture.
    @MainActor
    private static func pixelScan() async -> [String] {
        var out: [String] = []
        let only = UserDefaults.standard.string(forKey: "pixelSpecies")
        let step = UserDefaults.standard.double(forKey: "pixelStep") > 0 ? UserDefaults.standard.double(forKey: "pixelStep") : 0.02
        let species = Species.allCases.filter { !$0.isPet && (only == nil || $0.rawValue == only) && (PlantPlan.of($0) != nil || $0.art == .tree) }
        var total = (0, 0)
        let day = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()
        for s in species {
            var renders = 0, bad = 0, worst = 0.0, worstAt = ""
            var growths = Set<Int>()
            let companion = Companion(species: s, seed: ArtSheet.seed, startedAt: .distantPast, colour: UserDefaults.standard.integer(forKey: "artSheetColour"))
            for mood in Mood.allCases {
                for g in stride(from: step, through: 1.0001, by: step) {
                    renders += 1
                    let found = PixelAudit.floaters(companion, progress: g, mood: mood, hour: day)
                    guard !found.isEmpty else { continue }
                    bad += found.count
                    growths.insert(Int((g * 100).rounded()))
                    if let big = found.max(by: { $0.area < $1.area }), big.area > worst {
                        worst = big.area
                        worstAt = "g \(String(format: "%.2f", g)) \(mood.rawValue) at \(Int(big.rect.midX)),\(Int(big.rect.midY))"
                    }
                }
                await Task.yield()
            }
            let line = "pixel \(s.rawValue): \(renders) pictures, \(bad) floating pieces" + (bad > 0 ? ", largest \(String(format: "%.0f", worst)) pt2 at \(worstAt), growths \(growths.sorted().prefix(14))" : "")
            out.append(line)
            log.info("\(line, privacy: .public)")
            total.0 += renders
            total.1 += bad
        }
        out.append("total pictures \(total.0), floating pieces \(total.1)")
        log.info("total pictures \(total.0), floating pieces \(total.1)")
        return out
    }

    @MainActor
    private static func scan() async -> [String] {
        var out: [String] = ["attach scan, fix \(TreeAttach.on ? "on" : "off")"]
        let species: [Species] = [.pomegranate, .lemon, .olive, .magnolia, .cherry, .azalea]
        let moods: [Mood] = [.bright, .content, .thirsty, .dozing]
        var total = (0, 0)
        for s in species {
            var checked = 0, bad = 0, worst = 0.0, worstAt = ""
            var byKind: [String: Int] = [:]
            var growthsBad = Set<Int>()
            for (n, seed) in [ArtSheet.seed, "scan-1", "scan-2", "scan-3"].enumerated() {
                let canopy = Canopy(seed: seed, species: s)
                let step = n == 0 ? 0.01 : 0.025
                for g in stride(from: 0.02, through: 1.0001, by: step) {
                    for mood in moods {
                        guard let subject = TreeAudit.subject(canopy, growth: g, mood: mood.level) else { continue }
                        let r = TreeAudit.check(subject)
                        checked += r.checked
                        for f in r.findings {
                            bad += 1
                            byKind[f.kind, default: 0] += 1
                            growthsBad.insert(Int((g * 100).rounded()))
                            if f.gap > worst { worst = f.gap; worstAt = "\(seed) g \(String(format: "%.2f", g)) \(mood.rawValue) \(f.kind)" }
                        }
                    }
                }
                await Task.yield()
            }
            let kinds = byKind.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            let line = "\(s.rawValue): checked \(checked), off the wood \(bad)\(bad > 0 ? " (\(kinds)), worst \(String(format: "%.1f", worst)) pt at \(worstAt), growths \(growthsBad.sorted().prefix(12))" : "")"
            out.append(line)
            log.info("\(line, privacy: .public)")
            total.0 += checked
            total.1 += bad
        }
        out.append("total checked \(total.0), off the wood \(total.1)")
        log.info("total checked \(total.0), off the wood \(total.1)")
        return out
    }
}
#endif
