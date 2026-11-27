import ComposableArchitecture
import SwiftUI

/// Settings → Calendar → Calendars: every calendar on the phone, by account,
/// and how much of each the house sees. Pushed inside Settings' own stack, so
/// the main page stays the length of its switches however many calendars there
/// are.
struct CalendarListPage: View {
    @Bindable var store: StoreOf<CalendarSettingsFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        Form {
            ForEach(store.shareGroups) { group in
                Section {
                    ForEach(group.calendars) { calendar in
                        row(calendar)
                    }
                } header: {
                    Text(verbatim: group.account)
                }
            }

            Section {
                Picker(selection: Binding(
                    get: { store.shareDefaultLevel },
                    set: { store.send(.shareDefaultSelected($0)) }
                )) {
                    ForEach(CalendarShareLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                } label: {
                    Text(L10n.calendarShareDefaultTitle)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.calendarShareFooter)
                    Text(L10n.calendarShareMissingFooter)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .settingsRows()
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.calendarShareCalendarsHeader))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ calendar: DeviceCalendar) -> some View {
        let level = Binding<CalendarShareLevel>(
            get: { store.state.shareLevel(of: calendar.key) },
            set: { store.send(.shareLevelSelected(calendar.key, $0)) }
        )
        return LabeledContent {
            Picker(selection: level) {
                ForEach(CalendarShareLevel.allCases) { option in
                    Text(option.title).tag(option)
                }
            } label: {
                Text(verbatim: calendar.title)
            }
            .pickerStyle(.menu)
            .labelsHidden()
        } label: {
            HStack(spacing: 10) {
                Circle().fill(calendar.color).frame(width: 12, height: 12)
                Text(verbatim: calendar.title)
            }
        }
    }
}
