#if DEBUG
import ComposableArchitecture
import SwiftUI

/// The jar and the shop: how much is in it, what is owned, and what the next
/// purchase will be told.
struct LabJarSection: View {
    let store: StoreOf<CompanionFeature>
    let house: PretendState

    private static let outcomes: [(String, String?)] = [
        ("Honest", nil), ("Already owned", "owned"), ("Short", "short"),
        ("Not available", "unavailable"), ("Price changed", "priceChanged"),
    ]

    var body: some View {
        Section {
            LabSlider(
                title: "Leaves",
                value: Double(house.leaves),
                range: 0...1_000,
                step: 10,
                describe: { "\(Int($0))" },
                change: { store.pretend(.setLeaves(Int($0))) }
            )
            LabSlider(
                title: "Sparkles",
                value: Double(house.sparkles),
                range: 0...2_000,
                step: 10,
                describe: { "\(Int($0))" },
                change: { store.pretend(.setSparkles(Int($0))) }
            )
            HStack {
                Button { empty() } label: { Text(verbatim: "Empty jar").font(.footnote.weight(.semibold)) }
                Spacer()
                Button { store.pretend(.setLeaves(500)); store.pretend(.setSparkles(500)) } label: {
                    Text(verbatim: "500 and 500").font(.footnote.weight(.semibold))
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            NavigationLink {
                LabJustShort(store: store)
            } label: {
                Label { Text(verbatim: "Just short of a price…") } icon: { Image(systemName: "bag.badge.minus") }
            }
            NavigationLink {
                LabOwned(store: store)
            } label: {
                LabeledContent {
                    Text(verbatim: "\(house.owned.count) things · \(house.ownedSpecies.count) species").foregroundStyle(.secondary)
                } label: {
                    Label { Text(verbatim: "Owned") } icon: { Image(systemName: "checklist") }
                }
            }
            Picker(selection: store.labBinding(\.labNextBuy) { .nextBuy($0) }) {
                ForEach(Self.outcomes, id: \.0) { name, mode in Text(verbatim: name).tag(mode) }
            } label: {
                Label { Text(verbatim: "Next purchase is") } icon: { Image(systemName: "creditcard") }
            }
            LabButton(title: "Open the Sparkles store", symbol: "sparkle") { store.send(.storeTapped) }
        } header: {
            Text(verbatim: "Jar and shop")
        } footer: {
            Text(verbatim: "The next purchase is answered as chosen, once, whatever the jar says: that is how every purchase card is reached. The store is the test store: it charges nothing and credits the pretend jar.")
        }
    }

    private func empty() {
        store.pretend(.setLeaves(0))
        store.pretend(.setSparkles(0))
    }
}

extension CompanionFeature.State {
    /// The answer the Lab has armed for the next purchase.
    var labNextBuy: String? { labSlot.nextBuy }
}

extension LabSlot {
    var nextBuy: String? { lab.nextBuy }
}

/// Things with a price, to put the jar one short of.
private struct LabJustShort: View {
    let store: StoreOf<CompanionFeature>
    @Environment(\.dismiss) private var dismiss

    private struct Entry: Identifiable {
        let id: String
        let title: String
        let price: Price
    }

    private static let entries: [Entry] = {
        let decor = DecorItem.allCases.compactMap { item in
            item.price.map { Entry(id: "d.\(item.rawValue)", title: String(localized: item.title), price: $0) }
        }
        let species = Species.allCases.compactMap { kind in
            kind.access.price.map { Entry(id: "s.\(kind.rawValue)", title: String(localized: kind.title), price: $0) }
        }
        return (decor + species).sorted { $0.title < $1.title }
    }()

    var body: some View {
        List(Self.entries) { entry in
            Button {
                switch entry.price {
                case let .leaves(amount):
                    store.pretend(.setLeaves(amount - 1))
                    store.pretend(.setSparkles(0))
                case let .sparkles(amount):
                    store.pretend(.setLeaves(0))
                    store.pretend(.setSparkles(amount - 1))
                }
                dismiss()
            } label: {
                LabeledContent {
                    switch entry.price {
                    case let .leaves(amount): Text(verbatim: "\(amount) Leaves")
                    case let .sparkles(amount): Text(verbatim: "\(amount) Sparkles")
                    }
                } label: {
                    Text(verbatim: entry.title)
                }
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle(Text(verbatim: "Just short of…"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Access {
    /// What it costs from the jar, if it can be bought.
    fileprivate var price: Price? {
        switch self {
        case let .buy(price): price
        case let .pack(pack): pack.price
        default: nil
        }
    }
}

/// Everything that can be owned, to own or not.
private struct LabOwned: View {
    let store: StoreOf<CompanionFeature>

    @State private var house = PretendState()

    var body: some View {
        List {
            Section {
                LabButton(title: "Own everything", symbol: "checkmark.circle.fill") {
                    store.pretend(.ownAllDecor(true))
                    store.pretend(.ownAllSpecies(true))
                }
                LabButton(title: "Own nothing", symbol: "circle") {
                    store.pretend(.ownAllDecor(false))
                    store.pretend(.ownAllSpecies(false))
                }
            }
            Section {
                ForEach(DecorItem.allCases, id: \.rawValue) { item in
                    Toggle(isOn: Binding(
                        get: { house.owned.contains(item.rawValue) },
                        set: { store.pretend(.ownDecor(item.rawValue, $0)) }
                    )) {
                        Text(item.title)
                    }
                }
            } header: {
                Text(verbatim: "Decorations · \(DecorItem.allCases.count)")
            }
            Section {
                ForEach(Species.allCases) { kind in
                    Toggle(isOn: Binding(
                        get: { house.ownedSpecies.contains(kind.rawValue) },
                        set: { store.pretend(.ownSpecies(kind, $0)) }
                    )) {
                        Text(kind.title)
                    }
                }
            } header: {
                Text(verbatim: "Species · \(Species.allCases.count)")
            }
        }
        .navigationTitle(Text(verbatim: "Owned"))
        .navigationBarTitleDisplayMode(.inline)
        .labHouse($house)
    }
}
#endif
