#if DEBUG
import ComposableArchitecture
import SwiftUI

/// The one growing: which, in what colour, how far along, since when.
struct LabCompanionSection: View {
    let store: StoreOf<CompanionFeature>
    let house: PretendState

    var body: some View {
        Section {
            if let current = house.current {
                species(current)
                if !current.undecided {
                    colour(current)
                    stage(current)
                    LabSlider(
                        title: "Progress in this stage",
                        value: CompanionMath.nextStageShare(progress: current.points / PretendRules.graduateAt, isPet: current.species.isPet),
                        range: 0...1,
                        describe: { "\(Int(($0 * 100).rounded()))%" },
                        change: { store.pretend(.setStageShare($0)) }
                    )
                    LabeledContent {
                        Text(verbatim: "\(current.points.formatted(.number.precision(.fractionLength(1)))) / \(Int(PretendRules.graduateAt))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(verbatim: "Points")
                    }
                    LabButton(title: "Ready now", symbol: "party.popper.fill") { store.pretend(.makeReady) }
                    LabButton(title: "Stage up (pays the stage)", symbol: "arrow.up.circle") { store.pretend(.stageUp) }
                }
                days(current)
                LabButton(title: "New seed (a different random tree)", symbol: "dice") { store.pretend(.newSeed) }
                LabButton(title: "Remove the companion", symbol: "xmark.circle", role: .destructive) {
                    store.pretend(.removeCompanion)
                }
            } else {
                LabButton(title: "Give the house a magnolia", symbol: "leaf") { store.pretend(.giveCompanion(.magnolia)) }
            }
        } header: {
            Text(verbatim: "Companion")
        } footer: {
            Text(verbatim: "A ready one needs the points and six days. Stage and progress set the points directly and do not pay the jar; Stage up does.")
        }
    }

    private func species(_ current: PretendState.Current) -> some View {
        NavigationLink {
            LabSpeciesPicker(store: store)
        } label: {
            LabeledContent {
                Text(verbatim: current.undecided ? "A seed (not chosen)" : String(localized: current.species.title))
            } label: {
                Text(verbatim: "Species")
            }
        }
    }

    private func colour(_ current: PretendState.Current) -> some View {
        Picker(selection: Binding(
            get: { current.colour ?? 0 },
            set: { store.pretend(.setColour($0 == 0 ? nil : $0)) }
        )) {
            Text(verbatim: "Original").tag(0)
            ForEach(Array(Colourway.range), id: \.self) { colour in
                Text(verbatim: String(localized: current.species.colourName(colour))).tag(colour)
            }
        } label: {
            Text(verbatim: "Colourway")
        }
    }

    private func stage(_ current: PretendState.Current) -> some View {
        let isPet = current.species.isPet
        let count = CompanionMath.stageCount(isPet: isPet)
        return Picker(selection: Binding(
            get: { house.stage(of: current) },
            set: { store.pretend(.setStage($0)) }
        )) {
            ForEach(0..<count, id: \.self) { index in
                let name = CompanionMath.stageTitle(
                    index, isPet: isPet, isReady: index == count - 1, potted: current.species.growsInPot, species: current.species
                )
                Text(verbatim: "\(index + 1). \(String(localized: name))").tag(index)
            }
        } label: {
            Text(verbatim: "Stage")
        }
    }

    private func days(_ current: PretendState.Current) -> some View {
        let grown = max(Int(store.now.timeIntervalSince(current.startedAt) / PretendRules.day), 0)
        return Stepper(value: Binding(get: { grown }, set: { store.pretend(.setDaysGrown($0)) }), in: 0...60) {
            LabeledContent {
                Text(verbatim: "\(grown)").monospacedDigit().foregroundStyle(.secondary)
            } label: {
                Text(verbatim: "Days grown")
            }
        }
    }
}

#endif
