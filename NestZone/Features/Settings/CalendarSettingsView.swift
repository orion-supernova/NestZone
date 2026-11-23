import ComposableArchitecture
import SwiftUI

/// Settings → Calendar. See `CalendarSettingsFeature`.
struct CalendarSettingsView: View {
    @Bindable var store: StoreOf<CalendarSettingsFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        Form {
            copySection

            if store.isOn, store.access == .granted {
                modeSection
                intoSection
                optionsSection
            }

            shareSection

            if store.isShareOn, store.access == .granted {
                shareCalendarsSections
                shareOptionsSection
            }
        }
        .scrollContentBackground(.hidden)
        .settingsRows()
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.calendarSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .confirmationDialog($store.scope(state: \.dialog, action: \.dialog))
        .hostedSheet(isPresented: $store.isExplaining) {
            CalendarAccessExplainer(
                isWorking: store.isConnecting,
                onContinue: { store.send(.connectTapped) },
                onNotNow: { store.isExplaining = false }
            )
        }
    }

    // MARK: Sections

    private var copySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { store.isOn },
                set: { store.send(.copyToggled($0)) }
            )) {
                Label { PlusTitle(L10n.calendarCopyTitle) } icon: {
                    Image(systemName: "calendar.badge.plus")
                }
            }
            .proLocked(.calendar)

            accessNote
        } footer: {
            Text(L10n.calendarCopyFooter)
        }
    }

    /// Why nothing can be chosen, when it cannot, and the way to fix it.
    @ViewBuilder
    private var accessNote: some View {
        switch store.access {
        case .denied, .restricted, .writeOnly:
            VStack(alignment: .leading, spacing: 8) {
                Text(store.access == .restricted
                    ? L10n.calendarAccessRestricted
                    : L10n.calendarAccessDenied)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                if store.access != .restricted {
                    Button { store.send(.openSystemSettingsTapped) } label: {
                        Text(L10n.calendarAccessOpenSettings)
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        case .notDetermined, .granted:
            EmptyView()
        }
    }

    private var modeSection: some View {
        Section {
            ForEach(CalendarCopyMode.onModes) { mode in
                Button { store.send(.modeSelected(mode)) } label: {
                    HStack {
                        Text(mode.title).foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        if store.mode == mode {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.accentText)
                                .transition(.opacity)
                        }
                    }
                    .contentShape(.rect)
                }
                .accessibilityAddTraits(store.mode == mode ? [.isButton, .isSelected] : .isButton)
            }
        } header: {
            Text(L10n.calendarCopyWhatHeader)
        }
        .animation(Motion.fade, value: store.mode)
    }

    private var intoSection: some View {
        ForEach(store.groups) { group in
            Section {
                ForEach(group.calendars) { calendar in
                    let isOn = store.targets.contains(calendar.id)
                    Button { store.send(.targetToggled(calendar.id)) } label: {
                        HStack(spacing: 10) {
                            Circle().fill(calendar.color).frame(width: 12, height: 12)
                            Text(calendar.title).foregroundStyle(.primary)
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
                // The first account carries the section's name, so "Into" reads
                // once and the accounts under it are plain headings.
                if group.id == store.groups.first?.id {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.calendarCopyIntoHeader)
                        Text(group.account).font(.caption).foregroundStyle(.secondaryText)
                    }
                } else {
                    Text(group.account)
                }
            } footer: {
                if group.id == store.groups.last?.id {
                    Text(L10n.calendarCopyIntoFooter)
                }
            }
            .animation(Motion.fade, value: store.targetsRaw)
        }
    }

    private var optionsSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { store.copyReminders },
                set: { store.send(.remindersToggled($0)) }
            )) {
                PlusTitle(L10n.calendarCopyReminders)
            }
            .proLocked(.calendar)

            LabeledContent {
                if store.lastSynced > 0 {
                    Text(Date(timeIntervalSince1970: store.lastSynced), format: .relative(presentation: .named, unitsStyle: .wide))
                        .environment(\.locale, L10n.locale)
                        .foregroundStyle(.secondaryText)
                } else {
                    Text(L10n.calendarCopyNeverSynced).foregroundStyle(.secondaryText)
                }
            } label: {
                Text(L10n.calendarCopyLastSynced)
            }
        } footer: {
            Text(L10n.calendarCopyRemindersFooter)
        }
    }

    // MARK: Sharing

    /// The master switch. Per house: it says which house it is about, because
    /// the choices below are this house's alone.
    private var shareSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { store.isShareOn },
                set: { store.send(.shareToggled($0)) }
            )) {
                Label { PlusTitle(L10n.calendarShareToggle) } icon: {
                    Image(systemName: "person.2.badge.gearshape")
                }
            }
            .proLocked(.calendar)
        } header: {
            Text(L10n.calendarShareHeader)
        } footer: {
            if !store.isShareOn {
                Text(L10n.calendarShareOffFooter)
            }
        }
    }

    private var shareCalendarsSections: some View {
        ForEach(store.shareGroups) { group in
            Section {
                ForEach(group.calendars) { calendar in
                    shareRow(calendar)
                }
            } header: {
                shareHeader(group)
            }
        }
    }

    private func shareRow(_ calendar: DeviceCalendar) -> some View {
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

    /// The first account carries the section's name, so "Your calendars" reads
    /// once and the accounts under it are plain headings.
    @ViewBuilder
    private func shareHeader(_ group: CalendarSettingsFeature.State.CalendarGroup) -> some View {
        if group.id == store.shareGroups.first?.id {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.calendarShareCalendarsHeader)
                Text(verbatim: group.account).font(.caption).foregroundStyle(.secondaryText)
            }
        } else {
            Text(verbatim: group.account)
        }
    }

    private var shareOptionsSection: some View {
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

            Picker(selection: Binding(
                get: { store.shareWeeks },
                set: { store.send(.shareWeeksSelected($0)) }
            )) {
                ForEach([4, 8, 12], id: \.self) { weeks in
                    Text(L10n.calendarShareWeeks(weeks)).tag(weeks)
                }
            } label: {
                Text(L10n.calendarShareWindowTitle)
            }

            LabeledContent {
                if let syncedAt = store.shareRow?.syncedAt {
                    Text(syncedAt.date, format: .relative(presentation: .named, unitsStyle: .wide))
                        .environment(\.locale, L10n.locale)
                        .foregroundStyle(.secondaryText)
                } else {
                    Text(L10n.calendarCopyNeverSynced).foregroundStyle(.secondaryText)
                }
            } label: {
                Text(L10n.calendarShareUpdated)
            }
        } footer: {
            Text(L10n.calendarShareFooter)
        }
    }
}
