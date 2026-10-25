#if DEBUG
import ComposableArchitecture
import SwiftUI

// MARK: - Album and finale

/// The album, the finale and the colours a house opens after it.
struct LabAlbumSection: View {
    let store: StoreOf<CompanionFeature>
    let house: PretendState

    var body: some View {
        Section {
            LabeledContent {
                Text(verbatim: "\(house.album.count) graduates · \(house.grown.count) species").foregroundStyle(.secondary)
            } label: {
                Text(verbatim: "Album")
            }
            LabeledContent {
                Text(verbatim: finale).foregroundStyle(.secondary)
            } label: {
                Text(verbatim: "Finale")
            }
            Menu {
                ForEach([1, 3, 12, 39, 60], id: \.self) { count in
                    Button { store.pretend(.fillAlbum(count)) } label: { Text(verbatim: "\(count) graduates") }
                }
            } label: {
                Label { Text(verbatim: "Fill the album with…") } icon: { Image(systemName: "book.closed") }
            }
            LabButton(title: "All free species grown, the last one ready", symbol: "crown") { store.pretend(.growAllFree) }
            Menu {
                ForEach(1...3, id: \.self) { count in
                    Button { store.pretend(.growColours(count)) } label: {
                        Text(verbatim: count == 1 ? "Colour 1 of every species" : "Colours 1 to \(count) of every species")
                    }
                }
            } label: {
                Label { Text(verbatim: "Grown colourways…") } icon: { Image(systemName: "paintpalette") }
            }
            LabButton(title: "Clear the album", symbol: "xmark.bin", role: .destructive) { store.pretend(.clearAlbum) }
        } header: {
            Text(verbatim: "Album and finale")
        } footer: {
            Text(verbatim: "With every free species grown, graduating the last one plays the finale, and Choose then offers the colours. Grown colourways are added as graduates of their own.")
        }
    }

    private var finale: String {
        if house.finaleAt != nil { return "held" }
        let left = Species.freeToHave.subtracting(house.grown).count
        return left == 0 ? "ready to be held" : "\(left) free species to go"
    }
}

// MARK: - Moments

/// The moments of Nestie, on demand. Each sets the pretend house up and does
/// what a person would, so it plays through the real machinery.
struct LabMomentsSection: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        Section {
            moment("The welcome gift", "gift", .welcome)
            moment("A stage-up", "arrow.up.circle", .stageUp)
            moment("The graduation ceremony", "party.popper", .ceremony)
            moment("A graduation under a new start", "arrow.triangle.swap", .heldGraduation)
            moment("The finale", "crown", .finale)
            moment("The finale under a new start", "crown.fill", .finaleUnderStart)
            moment("A new one arrives", "sparkles", .newOne)
            moment("The vote opens (a house of two)", "hand.raised", .voteOpens)
            NavigationLink {
                LabHolidayList(store: store)
            } label: {
                Label { Text(verbatim: "The holiday chip…") } icon: { Image(systemName: "calendar.badge.plus") }
            }
        } header: {
            Text(verbatim: "Moments")
        } footer: {
            Text(verbatim: "The Lab closes, the house is set up, and then the card plays it: the same actions, pauses and covers as when a person gets there. Open the Lab again from the chip on the card.")
        }
    }

    private func moment(_ title: String, _ symbol: String, _ moment: LabMoment) -> some View {
        LabButton(title: title, symbol: symbol) { store.lab(.moment(moment)) }
    }
}

// MARK: - The house

/// The people in the house, and the vote they hold.
struct LabHouseSection: View {
    let store: StoreOf<CompanionFeature>
    let house: PretendState

    var body: some View {
        Section {
            Picker(selection: store.labBinding(\.members) { .members($0) }) {
                Text(verbatim: "1").tag(1)
                Text(verbatim: "2").tag(2)
                Text(verbatim: "3").tag(3)
            } label: {
                Label { Text(verbatim: "People in the house") } icon: { Image(systemName: "person.2") }
            }
            .pickerStyle(.segmented)
            LabButton(title: "Open a vote", symbol: "hand.raised") { store.pretend(.openVote) }
            if let vote = house.vote {
                status(vote)
                if vote.isOpen {
                    ForEach(Array(vote.others.enumerated()), id: \.offset) { index, _ in
                        NavigationLink {
                            LabBallots(store: store, member: index + 1)
                        } label: {
                            LabeledContent {
                                Text(verbatim: "\(vote.others[index].count) of \(vote.options.count) answered").foregroundStyle(.secondary)
                            } label: {
                                Text(verbatim: "Housemate \(index + 1)'s ballot")
                            }
                        }
                    }
                    LabButton(title: "Housemates answer everything", symbol: "checkmark.bubble") { store.pretend(.othersAnswerAll) }
                    LabButton(title: "Close it: everyone answered", symbol: "person.3") { store.pretend(.closeVote(.everyone)) }
                    LabButton(title: "Close it: the deadline", symbol: "hourglass.bottomhalf.filled") { store.pretend(.closeVote(.deadline)) }
                }
            }
            LabButton(title: "A housemate leaves", symbol: "person.badge.minus", role: .destructive) { store.pretend(.memberLeaves) }
                .disabled(house.members <= 1)
        } header: {
            Text(verbatim: "The house")
        } footer: {
            Text(verbatim: "A house of two or more votes on the next one after a graduation. Answer on the card as yourself, and here as the others. The vote closes when everyone has answered every option, at the deadline, or when someone leaves and the rest have.")
        }
    }

    private func status(_ vote: PretendState.Vote) -> some View {
        LabeledContent {
            Text(verbatim: vote.isOpen
                 ? "open · \(vote.answered) of \(vote.members) answered"
                 : "closed · \(vote.how ?? "?") · \(vote.winner ?? "no winner")")
                .foregroundStyle(.secondary)
        } label: {
            Text(verbatim: "The vote")
        }
    }
}

/// One housemate's answers, option by option.
private struct LabBallots: View {
    let store: StoreOf<CompanionFeature>
    let member: Int

    @State private var house = PretendState()

    var body: some View {
        List {
            if let vote = house.vote, member - 1 < vote.others.count {
                Section {
                    ForEach(vote.options, id: \.self) { option in
                        Picker(selection: Binding<Bool?>(
                            get: { vote.others[member - 1][option] },
                            set: { store.pretend(.ballot(member: member, species: option, answer: $0)) }
                        )) {
                            Text(verbatim: "No answer").tag(Bool?.none)
                            Text(verbatim: "Yes").tag(Bool?.some(true))
                            Text(verbatim: "No").tag(Bool?.some(false))
                        } label: {
                            Text(verbatim: Species(rawValue: option).map { String(localized: $0.title) } ?? option)
                        }
                        .pickerStyle(.menu)
                    }
                } footer: {
                    Text(verbatim: "When everyone has answered every option, the vote closes on its own.")
                }
            }
        }
        .navigationTitle(Text(verbatim: "Housemate \(member)"))
        .navigationBarTitleDisplayMode(.inline)
        .labHouse($house)
    }
}

// MARK: - The server

/// How the pretend server behaves: slow, or not there at all.
struct LabServerSection: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        Section {
            LabSlider(
                title: "Answer time",
                value: Double(store.labSlot.lab.latency),
                range: 0...3_000,
                step: 50,
                describe: { "\(Int($0)) ms" },
                change: { store.lab(.latency(Int($0))) }
            )
            Toggle(isOn: store.labBinding(\.labOffline) { .offline($0) }) {
                Label { Text(verbatim: "Offline") } icon: { Image(systemName: "wifi.slash") }
            }
        } header: {
            Text(verbatim: "Server")
        } footer: {
            Text(verbatim: "Offline fails every write, so each one's rollback and the retry on the purchase card can be seen. Writes give up after 15 seconds.")
        }
    }
}

extension CompanionFeature.State {
    var labOffline: Bool { labSlot.lab.offline }
}
#endif
