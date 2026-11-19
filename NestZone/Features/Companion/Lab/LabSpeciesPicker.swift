#if DEBUG
import ComposableArchitecture
import SwiftUI

/// Every species, by its portrait, in three groups. Tapping one makes it the
/// one growing and stays here, so the card behind can be watched flipping
/// through them.
struct LabSpeciesPicker: View {
    let store: StoreOf<CompanionFeature>

    @State private var house = PretendState()
    @Environment(\.shopStage) private var stage
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let trees = Species.allCases.filter { $0.art == .tree }
    private static let plants = Species.allCases.filter { !$0.isPet && $0.art != .tree }
    private static let pets = Species.allCases.filter(\.isPet)
    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        let seed = house.current?.seed ?? "pretend-0"
        let colour = house.current?.colour ?? 0
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                group("Trees", Self.trees, seed: seed, colour: colour)
                group("Plants", Self.plants, seed: seed, colour: colour)
                group("Pets", Self.pets, seed: seed, colour: colour)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, 12)
        }
        .navigationTitle(Text(verbatim: "Species"))
        .navigationBarTitleDisplayMode(.inline)
        .labHouse($house)
        // The pets' shapes are built off the main thread, and the portraits
        // are drawn one at a time between frames, as Choose does it. A new
        // colour or seed draws its own.
        .task(id: "\(seed)|\(colour)") {
            let plans = Self.pets.compactMap(CritterPlan.of)
            await Task.detached(priority: .utility) { plans.forEach(CritterGeometry.prepare) }.value
            let big = typeSize.isAccessibilitySize
            let jobs = (Self.trees + Self.plants + Self.pets).map { species in
                let portrait = SpeciesPortrait(species: species, seed: seed, hour: stage.portraitHour, colourway: colour)
                return (portrait.still(big: big), AnyView(portrait))
            }
            await StillCache.warm(jobs)
        }
    }

    private func group(_ title: String, _ species: [Species], seed: String, colour: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "\(title) · \(species.count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(species) { kind in
                    Button { store.pretend(.setSpecies(kind)) } label: { tile(kind, seed: seed, colour: colour) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func tile(_ kind: Species, seed: String, colour: Int) -> some View {
        let selected = house.current.map { !$0.undecided && $0.species == kind } ?? false
        return VStack(spacing: 4) {
            SpeciesPortrait(species: kind, seed: seed, hour: stage.portraitHour, colourway: colour)
                .tile(big: typeSize.isAccessibilitySize)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Metrics.tightRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                        .strokeBorder(selected ? theme.accent : .clear, lineWidth: 3)
                }
            Text(kind.title)
                .font(.caption2.weight(selected ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Keeps a screen's copy of the pretend server's house up to date while it is
/// on show.
private struct LabHouseReader: ViewModifier {
    @Dependency(\.pretendHouse) private var pretendHouse
    @Binding var house: PretendState

    func body(content: Content) -> some View {
        content.task {
            for await next in pretendHouse.houses() { house = next }
        }
    }
}

extension View {
    /// Reads the pretend server's own house into `house` while this is shown.
    func labHouse(_ house: Binding<PretendState>) -> some View {
        modifier(LabHouseReader(house: house))
    }
}
#endif
