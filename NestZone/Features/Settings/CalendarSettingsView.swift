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

            // Sharing the person's own calendars with the house is one more
            // Section here, below these.
        }
        .scrollContentBackground(.hidden)
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
                Label { Text(L10n.calendarCopyTitle) } icon: {
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
                    .foregroundStyle(.secondary)
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
                                .foregroundStyle(theme.accent)
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
                                    .foregroundStyle(theme.accent)
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
                        Text(group.account).font(.caption).foregroundStyle(.secondary)
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
                Text(L10n.calendarCopyReminders)
            }
            .proLocked(.calendar)

            LabeledContent {
                if store.lastSynced > 0 {
                    Text(Date(timeIntervalSince1970: store.lastSynced), format: .relative(presentation: .named, unitsStyle: .wide))
                        .environment(\.locale, L10n.locale)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.calendarCopyNeverSynced).foregroundStyle(.secondary)
                }
            } label: {
                Text(L10n.calendarCopyLastSynced)
            }
        } footer: {
            Text(L10n.calendarCopyRemindersFooter)
        }
    }
}
