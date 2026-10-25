#if DEBUG
import ComposableArchitecture
import SwiftUI

extension StoreOf<CompanionFeature> {
    /// A control for one thing the card pretends about how it looks.
    func lookBinding<Value>(_ keyPath: WritableKeyPath<LabLook, Value>) -> Binding<Value> {
        Binding(
            get: { self.state.labLook[keyPath: keyPath] },
            set: {
                var look = self.state.labLook
                look[keyPath: keyPath] = $0
                self.send(.lab(.look(look)))
            }
        )
    }
}

// MARK: - Mood

/// How the house seems to be doing. The pretended mood is a look and works on
/// either house; the rest sets what the pretend house has done, so the real
/// logic arrives at the mood by itself.
struct LabMoodSection: View {
    let store: StoreOf<CompanionFeature>
    let house: PretendState?

    private static let moods: [Mood?] = [nil, .bright, .content, .thirsty, .dozing]

    var body: some View {
        Section {
            Picker(selection: store.lookBinding(\.mood)) {
                ForEach(Self.moods, id: \.self) { mood in
                    Text(verbatim: mood.map { String(localized: $0.title(isPet: store.isPet)) } ?? "Real").tag(mood)
                }
            } label: {
                Text(verbatim: "Mood")
            }
            .pickerStyle(.menu)
            LabeledContent {
                Text(verbatim: String(localized: store.mood.title(isPet: store.isPet))).foregroundStyle(.secondary)
            } label: {
                Text(verbatim: "On the card now")
            }
            if store.isPretend, let house, let current = house.current {
                pretendRows(house, current)
            }
        } header: {
            Text(verbatim: "Mood")
        } footer: {
            Text(verbatim: store.isPretend
                 ? "A forced mood is only how the card looks; caring clears a quiet one. The rest changes what the pretend house has done, so the real rules find the mood themselves."
                 : "Only how the card looks. Your house keeps its own mood.")
        }
    }

    @ViewBuilder
    private func pretendRows(_ house: PretendState, _ current: PretendState.Current) -> some View {
        Menu {
            ForEach([0, 2, 4, 8], id: \.self) { days in
                Button { store.pretend(.quiet(days: days)) } label: {
                    Text(verbatim: days == 0 ? "Not quiet at all" : "Quiet for \(days) days")
                }
            }
        } label: {
            Label { Text(verbatim: "Nobody has come by for…") } icon: { Image(systemName: "moon.zzz") }
        }
        Menu {
            Button { store.pretend(.setLastCare(hoursAgo: 0)) } label: { Text(verbatim: "Just now") }
            Button { store.pretend(.setLastCare(hoursAgo: 1)) } label: { Text(verbatim: "An hour ago") }
            Button { store.pretend(.setLastCare(hoursAgo: 24)) } label: { Text(verbatim: "Yesterday") }
            Button { store.pretend(.setLastCare(hoursAgo: 72)) } label: { Text(verbatim: "Three days ago") }
            Button { store.pretend(.setLastCare(hoursAgo: 192)) } label: { Text(verbatim: "Eight days ago") }
            Button { store.pretend(.setLastCare(hoursAgo: nil)) } label: { Text(verbatim: "Never") }
        } label: {
            LabeledContent {
                Text(verbatim: current.lastCare.map { $0.formatted(.relative(presentation: .named)) } ?? "never")
                    .foregroundStyle(.secondary)
            } label: {
                Label { Text(verbatim: "Last care") } icon: { Image(systemName: "clock") }
            }
        }
        let streak = current.careDays.count
        Stepper(
            value: Binding(get: { streak }, set: { store.pretend(.setCareStreak($0, today: current.careDays.first == house.dayKey(store.now))) }),
            in: 0...14
        ) {
            LabeledContent {
                Text(verbatim: "\(streak)").monospacedDigit().foregroundStyle(.secondary)
            } label: {
                Text(verbatim: "Care streak (days)")
            }
        }
        LabButton(title: store.isPet ? "Pet it now" : "Water it now", symbol: store.isPet ? "heart.fill" : "drop.fill") {
            store.send(.careTapped)
        }
        LabButton(title: "A housemate finishes a chore", symbol: "checkmark.circle") { store.pretend(.chore(by: "u1")) }
        LabButton(title: "I finish a chore", symbol: "checkmark.circle.fill") { store.pretend(.chore(by: "u0")) }
    }
}

// MARK: - Time and place

/// The hour, the day, where on Earth and who has a birthday. The hour and
/// the day are looks and work on either house; the hemisphere is a look on
/// the real house and the pretend house's own region in the other.
struct LabTimeSection: View {
    let store: StoreOf<CompanionFeature>
    let house: PretendState?

    private static let hours: [(String, Double)] = [
        ("Dawn", 6), ("Morning", 9), ("Noon", 13), ("Golden hour", 17.5), ("Dusk", 19.5), ("Night", 23),
    ]

    private static let zones: [(String, Int)] = [
        ("UTC−08:00", -480), ("UTC−05:00", -300), ("UTC±00:00", 0), ("UTC+01:00", 60), ("UTC+03:00", 180),
        ("UTC+05:30", 330), ("UTC+08:00", 480), ("UTC+09:00", 540), ("UTC+10:00", 600), ("UTC+13:00", 780),
    ]

    var body: some View {
        Section {
            hour
            presets
            day
            LabButton(title: "Back to now", symbol: "clock.arrow.circlepath") {
                var look = store.labLook
                look.date = nil
                store.lab(.look(look))
            }
            .disabled(store.labLook.date == nil)
            NavigationLink {
                LabHolidayList(store: store)
            } label: {
                Label { Text(verbatim: "Holidays") } icon: { Image(systemName: "calendar") }
            }
            hemisphere
            if store.isPretend, let house {
                zone(house)
                LabButton(title: "Celebrate every holiday", symbol: "party.popper") { store.pretend(.celebrateAll(true)) }
                LabButton(title: "Back to the region's holidays", symbol: "arrow.uturn.backward") { store.pretend(.celebrateAll(false)) }
            }
            Toggle(isOn: store.lookBinding(\.birthday)) {
                Label { Text(verbatim: "A birthday today") } icon: { Image(systemName: "birthday.cake") }
            }
        } header: {
            Text(verbatim: "Time and place")
        } footer: {
            Text(verbatim: store.isPretend
                 ? "The hour and day are a pretend clock for the card and the shop. The hemisphere and time zone are the pretend house's own."
                 : "The hour and day are a pretend clock for the card. While one is on, decorating and holidays are not saved, so a pretend day never writes your house.")
        }
    }

    private var hour: some View {
        let clock = store.clock
        let calendar = Calendar.current
        let value = Double(calendar.component(.hour, from: clock)) + Double(calendar.component(.minute, from: clock)) / 60
        return LabSlider(
            title: "Hour",
            value: value,
            range: 0...23.75,
            step: 0.25,
            describe: { String(format: "%02d:%02d", Int($0), Int(($0 - Double(Int($0))) * 60)) },
            change: { setHour($0) }
        )
    }

    private var presets: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Self.hours, id: \.0) { name, hour in
                    Button { setHour(hour) } label: { Text(verbatim: name).font(.footnote.weight(.semibold)).fixedSize() }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var day: some View {
        DatePicker(selection: Binding(get: { store.clock }, set: { setDay($0) }), displayedComponents: .date) {
            Text(verbatim: "Day")
        }
    }

    private var hemisphere: some View {
        Picker(selection: Binding<String?>(
            get: { store.isPretend ? (store.southern ? "AU" : "TR") : store.labLook.region },
            set: { region in
                if store.isPretend {
                    store.pretend(.setRegion(region ?? "TR"))
                } else {
                    var look = store.labLook
                    look.region = region
                    store.lab(.look(look))
                }
            }
        )) {
            if !store.isPretend { Text(verbatim: "Real").tag(String?.none) }
            Text(verbatim: "North").tag(String?.some("TR"))
            Text(verbatim: "South").tag(String?.some("AU"))
        } label: {
            Label { Text(verbatim: "Hemisphere") } icon: { Image(systemName: "globe") }
        }
    }

    private func zone(_ house: PretendState) -> some View {
        Picker(selection: Binding(get: { house.tzOffset ?? 180 }, set: { store.pretend(.setTzOffset($0)) })) {
            ForEach(Self.zones, id: \.1) { name, offset in Text(verbatim: name).tag(offset) }
        } label: {
            Label { Text(verbatim: "Time zone of the house") } icon: { Image(systemName: "clock.badge") }
        }
    }

    /// The pretend clock at this hour, on the day it is on.
    private func setHour(_ hour: Double) {
        let whole = Int(hour)
        let minutes = Int(((hour - Double(whole)) * 60).rounded())
        guard let date = Calendar.current.date(bySettingHour: whole, minute: minutes, second: 0, of: store.clock) else { return }
        var look = store.labLook
        look.date = date
        store.lab(.look(look))
    }

    /// The pretend clock on this day, at the hour it is at.
    private func setDay(_ day: Date) {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: store.clock)
        guard let date = calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: day) else { return }
        var look = store.labLook
        look.date = date
        store.lab(.look(look))
    }
}

// MARK: - Colour (the real house)

/// A colourway to try on the one growing. On the real house a look; in the
/// pretend house the companion's own colour (Companion).
struct LabColourSection: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        if let species = store.species {
            Section {
                Picker(selection: store.lookBinding(\.colour)) {
                    Text(verbatim: "Real").tag(Int?.none)
                    ForEach(Array(Colourway.range), id: \.self) { colour in
                        Text(verbatim: String(localized: species.colourName(colour))).tag(Int?.some(colour))
                    }
                } label: {
                    Label { Text(verbatim: "Colourway") } icon: { Image(systemName: "paintpalette") }
                }
            } header: {
                Text(verbatim: "Colour")
            } footer: {
                Text(verbatim: "Draws \(String(localized: species.title)) in a colour it may not have grown yet. Only how the card looks.")
            }
        }
    }
}

// MARK: - Holidays

/// Every holiday, with its date for the house's region, to set the day to.
struct LabHolidayList: View {
    let store: StoreOf<CompanionFeature>

    private struct Row: Identifiable {
        let id: Holiday.ID
        let symbol: String
        let title: String
        let date: Date?
    }

    @State private var rows: [Row] = []

    var body: some View {
        List {
            Section {
                ForEach(rows) { row in
                    Button { store.lab(.moment(.holidayChip(row.id)), animation: Motion.spring) } label: {
                        LabeledContent {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(verbatim: row.date?.formatted(.dateTime.day().month(.abbreviated).year()) ?? "—")
                                if store.celebrated.contains(row.id) {
                                    Text(verbatim: "celebrated").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        } label: {
                            Text(verbatim: "\(row.symbol) \(row.title)")
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } footer: {
                Text(verbatim: store.isPretend
                     ? "Sets the day to the holiday's first day at noon, makes the pretend house celebrate it and clears the scene, so the card offers to put its things out."
                     : "Sets the day to the holiday's first day at noon. The chip shows only if your house celebrates that holiday.")
            }
        }
        .navigationTitle(Text(verbatim: "Holidays"))
        .navigationBarTitleDisplayMode(.inline)
        // Calendar arithmetic for sixty holidays is not a thing for `body`.
        .task(id: store.placeRegion) {
            let region = store.placeRegion
            let now = store.now
            rows = await Task.detached {
                Holiday.all.map {
                    Row(id: $0.id, symbol: $0.symbol, title: String(localized: $0.id.title), date: $0.next(after: now, region: region))
                }
            }.value
        }
    }
}
#endif
