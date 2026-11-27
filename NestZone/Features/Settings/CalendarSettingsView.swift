import ComposableArchitecture
import SwiftUI

/// Settings → Calendar. See `CalendarSettingsFeature`.
struct CalendarSettingsView: View {
    @Bindable var store: StoreOf<CalendarSettingsFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        Form {
            if store.access != .granted {
                accessSection
            } else {
                shareSection
                copySection
                if !store.copyRows.isEmpty {
                    housematesSection
                }
                if store.hasSomethingToSync {
                    syncSection
                }
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

    // MARK: Access

    /// Until the phone has said yes there is nothing to choose, so this is the
    /// whole page: one card and the way to the answer.
    private var accessSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label { Text(L10n.calendarAccessTitle) } icon: { Image(systemName: "calendar.badge.checkmark") }
                    .font(.headline)
                accessNote
                if store.access == .notDetermined {
                    Text(L10n.calendarAccessBody)
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                    Button { store.send(.allowAccessTapped) } label: {
                        Text(L10n.calendarAccessAllow).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Your calendars in NestZone

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
            .proLocked(.calendar, placement: .inline)

            if store.isShareOn {
                let count = store.sharedCalendarCount
                NavigationLink {
                    CalendarListPage(store: store)
                } label: {
                    LabeledContent {
                        Text(L10n.calendarShareCountOf(count.shared, count.total))
                            .foregroundStyle(.secondaryText)
                    } label: {
                        Text(L10n.calendarShareCalendarsHeader)
                    }
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

                Toggle(isOn: Binding(
                    get: { store.allowCopy },
                    set: { store.send(.allowCopyToggled($0)) }
                )) {
                    PlusTitle(L10n.calendarShareAllowCopy)
                }
                .proLocked(.calendar, placement: .inline)
            }
        } header: {
            Text(L10n.calendarShareHeader)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.calendarShareOffFooter)
                if store.isShareOn {
                    Text(verbatim: shareStatus)
                }
            }
        }
        .animation(Motion.fade, value: store.isShareOn)
    }

    /// "Sharing 2 calendars · 55 plans": the plans only once a pass has said.
    private var shareStatus: String {
        let calendars = String(localized: L10n.calendarShareStatusCalendars(store.sharedCalendarCount.shared))
        guard store.planCount > 0 else { return calendars }
        return calendars + " · " + String(localized: L10n.calendarShareStatusPlans(store.planCount))
    }

    // MARK: NestZone in your calendar

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
            .proLocked(.calendar, placement: .inline)

            if store.isOn {
                Picker(selection: Binding(
                    get: { store.mode },
                    set: { store.send(.modeSelected($0)) }
                )) {
                    ForEach(CalendarCopyMode.onModes) { mode in
                        Text(mode.title).tag(mode)
                    }
                } label: {
                    Text(L10n.calendarCopyWhatHeader)
                }

                NavigationLink {
                    CalendarIntoPage(store: store)
                } label: {
                    LabeledContent {
                        if let summary = store.intoSummary {
                            Text(verbatim: summary).foregroundStyle(.secondaryText)
                        }
                    } label: {
                        Text(L10n.calendarCopyIntoHeader)
                    }
                }

                Toggle(isOn: Binding(
                    get: { store.copyReminders },
                    set: { store.send(.remindersToggled($0)) }
                )) {
                    PlusTitle(L10n.calendarCopyReminders)
                }
                .proLocked(.calendar, placement: .inline)
            }
        } header: {
            Text(L10n.calendarCopyHeader)
        } footer: {
            Text(L10n.calendarCopyFooter)
        }
        .animation(Motion.fade, value: store.isOn)
    }

    // MARK: Sync

    private var syncSection: some View {
        Section {
            Button { store.send(.syncNowTapped) } label: {
                HStack {
                    Label { Text(L10n.calendarSyncNow) } icon: { Image(systemName: "arrow.triangle.2.circlepath") }
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    switch store.syncPhase {
                    case .idle:
                        EmptyView()
                    case .running:
                        ProgressView()
                    case .done:
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.accentText)
                            .transition(.opacity)
                    }
                }
                .contentShape(.rect)
            }
            .disabled(store.syncPhase == .running)
            .sensoryFeedback(.impact(weight: .light), trigger: store.syncTaps)
            .animation(Motion.fade, value: store.syncPhase)

            LabeledContent {
                if let date = store.lastSyncedDate {
                    Text(date, format: .relative(presentation: .named, unitsStyle: .wide))
                        .environment(\.locale, L10n.locale)
                        .foregroundStyle(.secondaryText)
                } else {
                    Text(L10n.calendarCopyNeverSynced).foregroundStyle(.secondaryText)
                }
            } label: {
                Text(L10n.calendarCopyLastSynced)
            }
        } header: {
            Text(L10n.calendarSyncHeader)
        } footer: {
            Text(L10n.calendarSyncFooter)
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

    /// Housemates who share a calendar with the house. Those who allow copies
    /// get a switch; the rest are greyed with the reason.
    private var housematesSection: some View {
        Section {
            ForEach(store.copyRows, id: \.share.id) { row in
                if row.share.allowCopy {
                    Toggle(isOn: Binding(
                        get: { store.state.isCopying(row.share.id) },
                        set: { store.send(.housemateToggled(row.share.id, $0)) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: row.name)
                            Text(L10n.calendarCopyHousemateToggle)
                                .font(.footnote)
                                .foregroundStyle(.secondaryText)
                        }
                    }
                    .proLocked(.calendar, placement: .inline)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.name)
                        Text(L10n.calendarCopyHousemateNotAllowed(row.name))
                            .font(.footnote)
                    }
                    .foregroundStyle(.secondaryText)
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text(L10n.calendarCopyHousematesHeader)
        } footer: {
            Text(L10n.calendarCopyHousematesFooter)
        }
    }
}
