#if DEBUG
import ComposableArchitecture
import SwiftUI

extension Spot {
    /// What the Lab calls a spot.
    var labTitle: String {
        switch self {
        case .above: "Above"
        case .sky: "Sky and backdrop"
        case .weather: "Weather"
        case .tree: "On the tree"
        case .wearing: "Wearing"
        case .pot: "Pot"
        case .left: "Left"
        case .right: "Right"
        case .ground: "Ground"
        }
    }

    /// The things that go there: every decoration of its kind, and for the
    /// overhead spot a string of flags for any holiday.
    var labChoices: [Decor] {
        var choices = DecorItem.allCases.filter { $0.kind == kind }.map(Decor.item)
        if self == .above { choices += Holiday.all.map { Decor.flags($0.id) } }
        return choices
    }
}

extension Decor {
    /// What it is called in the Lab.
    var labTitle: String {
        switch self {
        case let .item(item): String(localized: item.title)
        case let .flags(holiday): "Flags · \(String(localized: holiday.title))"
        }
    }
}

/// What is out in the scene, spot by spot, and the shortcuts: a backdrop, a
/// wearable, everything at once, nothing at all. Anything can be put
/// anywhere it fits, owned or not; owning it comes with putting it out.
struct LabSceneSection: View {
    let store: StoreOf<CompanionFeature>
    let house: PretendState

    private static let backdrops: [DecorItem] = DecorItem.allCases.filter(\.isBackdrop)
    private static let wearables: [DecorItem] = DecorItem.allCases.filter { $0.kind == .wearing }

    var body: some View {
        let spots = store.isPet ? Spot.forPets : Spot.allCases
        Section {
            ForEach(spots) { spot in
                NavigationLink {
                    LabDecorPicker(store: store, spot: spot)
                } label: {
                    LabeledContent {
                        Text(verbatim: describe(spot)).foregroundStyle(.secondary).lineLimit(1)
                    } label: {
                        Text(verbatim: spot.labTitle)
                    }
                }
            }
            backdrop
            wearable
            LabButton(title: "Everything at once", symbol: "square.stack.3d.up.fill") { store.pretend(.fillScene) }
            LabButton(title: "Clear the scene", symbol: "xmark.bin") { store.pretend(.clearScene) }
        } header: {
            Text(verbatim: "Scene")
        } footer: {
            Text(verbatim: "A pet's scene has no tree and no pot, so those spots wait for a plant. Everything at once owns every decoration and fills every spot with one that is drawn each frame or lit at night.")
        }
    }

    private func describe(_ spot: Spot) -> String {
        if spot == .tree {
            return house.layout.tree.isEmpty ? "—" : house.layout.tree.compactMap { Decor(rawValue: $0)?.labTitle }.joined(separator: ", ")
        }
        return house.layout[spot].flatMap { Decor(rawValue: $0)?.labTitle } ?? "—"
    }

    /// One of the three scenes behind the companion, or none.
    private var backdrop: some View {
        Picker(selection: Binding<String?>(
            get: { house.layout.sky.flatMap { raw in Self.backdrops.contains { $0.rawValue == raw } ? raw : nil } },
            set: { raw in
                if let raw { store.pretend(.place(raw, .sky)) } else { store.pretend(.clearSpot(.sky)) }
            }
        )) {
            Text(verbatim: "None").tag(String?.none)
            ForEach(Self.backdrops, id: \.rawValue) { item in
                Text(item.title).tag(String?.some(item.rawValue))
            }
        } label: {
            Label { Text(verbatim: "Scene backdrop") } icon: { Image(systemName: "window.vertical.open") }
        }
    }

    private var wearable: some View {
        Picker(selection: Binding<String?>(
            get: { house.layout.wearing },
            set: { raw in
                if let raw { store.pretend(.place(raw, .wearing)) } else { store.pretend(.clearSpot(.wearing)) }
            }
        )) {
            Text(verbatim: "None").tag(String?.none)
            ForEach(Self.wearables, id: \.rawValue) { item in
                Text(item.title).tag(String?.some(item.rawValue))
            }
        } label: {
            Label { Text(verbatim: store.isPet ? "Wearing (on the pet)" : "Wearing (on the plant)") } icon: { Image(systemName: "crown") }
        }
    }
}

// MARK: - Choosing a decoration by its picture

/// Every decoration that fits one spot, as the shop shows it. Tapping one puts
/// it out (and owns it); tapping the one that is out takes it away.
struct LabDecorPicker: View {
    let store: StoreOf<CompanionFeature>
    let spot: Spot

    @State private var house = PretendState()
    @Environment(\.shopStage) private var stage
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    var body: some View {
        let choices = spot.labChoices
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: columns, spacing: 10) {
                    Button { store.pretend(.clearSpot(spot)) } label: {
                        cell(selected: isEmpty) {
                            Image(systemName: "nosign").font(.title2).foregroundStyle(.secondary)
                        } title: { "None" }
                    }
                    .buttonStyle(.plain)
                    ForEach(choices, id: \.rawValue) { decor in
                        Button { tap(decor) } label: {
                            cell(selected: isOut(decor)) {
                                DecorPortrait(decor: decor, hour: stage.portraitHour).tile(big: typeSize.isAccessibilitySize)
                            } title: { decor.labTitle }
                        }
                        .buttonStyle(.plain)
                    }
                }
                if spot == .tree {
                    LabNote("The tree takes up to four things at a time.").padding(.top, 4)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, 12)
        }
        .navigationTitle(Text(verbatim: spot.labTitle))
        .navigationBarTitleDisplayMode(.inline)
        .labHouse($house)
        .task {
            let big = typeSize.isAccessibilitySize
            await StillCache.warm(choices.map { decor in
                let portrait = DecorPortrait(decor: decor, hour: stage.portraitHour)
                return (portrait.still(big: big), AnyView(portrait))
            })
        }
    }

    private var isEmpty: Bool { spot == .tree ? house.layout.tree.isEmpty : house.layout[spot] == nil }

    private func isOut(_ decor: Decor) -> Bool { house.layout.holds(decor.rawValue, in: spot) }

    private func tap(_ decor: Decor) {
        if spot == .tree {
            store.pretend(.toggleTree(decor.rawValue))
        } else if isOut(decor) {
            store.pretend(.clearSpot(spot))
        } else {
            store.pretend(.place(decor.rawValue, spot))
        }
    }

    private func cell<Art: View>(selected: Bool, @ViewBuilder art: () -> Art, title: () -> String) -> some View {
        VStack(spacing: 4) {
            art()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(Palette.inset, in: .rect(cornerRadius: Metrics.tightRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                        .strokeBorder(selected ? theme.accent : .clear, lineWidth: 3)
                }
            Text(verbatim: title())
                .font(.caption2.weight(selected ? .bold : .regular))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
