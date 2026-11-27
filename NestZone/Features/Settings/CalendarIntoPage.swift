import ComposableArchitecture
import SwiftUI

/// Settings → Calendar → Into: which of the phone's calendars the house's
/// plans are copied into, by account.
struct CalendarIntoPage: View {
    @Bindable var store: StoreOf<CalendarSettingsFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        Form {
            ForEach(store.groups) { group in
                Section {
                    ForEach(group.calendars) { calendar in
                        let isOn = store.targets.contains(calendar.id)
                        Button { store.send(.targetToggled(calendar.id)) } label: {
                            HStack(spacing: 10) {
                                Circle().fill(calendar.color).frame(width: 12, height: 12)
                                Text(verbatim: calendar.title).foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.accentText)
                                        .transition(.opacity)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                    }
                } header: {
                    Text(verbatim: group.account)
                } footer: {
                    if group.id == store.groups.last?.id {
                        Text(L10n.calendarCopyIntoFooter)
                    }
                }
            }
        }
        .animation(Motion.fade, value: store.targetsRaw)
        .scrollContentBackground(.hidden)
        .settingsRows()
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.calendarCopyIntoHeader))
        .navigationBarTitleDisplayMode(.inline)
    }
}
