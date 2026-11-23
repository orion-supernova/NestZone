import ComposableArchitecture
import SwiftUI

/// Settings → Notifications. See `NotificationSettingsFeature`.
struct NotificationSettingsView: View {
    @Bindable var store: StoreOf<NotificationSettingsFeature>

    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    /// The groups drawn, in order. Nestie's only when the companion is on.
    private static let groups: [NotificationGroup] = NotificationGroup.allCases.filter {
        $0 != .nestie || CompanionFlag.isEnabled
    }

    var body: some View {
        Form {
            if !store.systemOn {
                systemSection
            }

            quietSection

            ForEach(Self.groups) { group in
                groupSection(group)
            }
            // The switches stay usable, but read as "not yet" while the system
            // would drop everything they let through.
            .opacity(store.systemOn ? 1 : 0.55)
            .animation(Motion.fade, value: store.systemOn)

            Section {} footer: {
                Text(L10n.notifFeedFooter)
            }
        }
        .scrollContentBackground(.hidden)
        .settingsRows()
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.settingsNotificationsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.send(.refreshStatus) }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: System permission

    private var systemSection: some View {
        let denied = store.status == .denied
        return Section {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text(L10n.notifSystemOffTitle).font(.headline)
                } icon: {
                    Image(systemName: "bell.slash.fill").foregroundStyle(Palette.warning)
                }
                Text(denied ? L10n.notifSystemDenied : L10n.notifSystemUndetermined)
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
                Button {
                    store.send(denied ? .openSystemSettingsTapped : .turnOnTapped)
                } label: {
                    Text(denied ? L10n.settingsNotificationsOpenSettings : L10n.notifSystemTurnOn)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text(L10n.notifSystemFooter)
        }
    }

    // MARK: Quiet hours

    private var quietSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { store.prefs.quiet != nil },
                set: { store.send(.quietToggled($0)) }
            )) {
                Label { Text(L10n.notifQuietTitle) } icon: {
                    Image(systemName: "moon.fill").foregroundStyle(Palette.indigo)
                }
            }
            .disabled(!store.isLoaded)

            if let quiet = store.prefs.quiet {
                DatePicker(
                    selection: timeBinding(quiet.start) { store.send(.quietTimesChanged(start: $0, end: quiet.end)) },
                    displayedComponents: .hourAndMinute
                ) { Text(L10n.notifQuietFrom) }

                DatePicker(
                    selection: timeBinding(quiet.end) { store.send(.quietTimesChanged(start: quiet.start, end: $0)) },
                    displayedComponents: .hourAndMinute
                ) { Text(L10n.notifQuietUntil) }
            }
        } footer: {
            Text(L10n.notifQuietFooter)
        }
        .animation(Motion.fade, value: store.prefs.quiet != nil)
    }

    /// Minutes after midnight, as the picker's date. Only the hour and minute
    /// are read back, so the day it sits on does not matter.
    private func timeBinding(_ minutes: Int, set: @escaping (Int) -> Void) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                set((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
            }
        )
    }

    // MARK: Groups

    private func groupSection(_ group: NotificationGroup) -> some View {
        let isLocked = group.feature != nil && !store.pro.isPro
        return Section {
            if group.hasMasterSwitch {
                masterRow(group, isLocked: isLocked)
            }
            ForEach(group.topics) { topic in
                topicRow(topic, in: group)
            }
        } header: {
            if !group.hasMasterSwitch {
                Text(group.title)
            }
        } footer: {
            groupFooter(group, isLocked: isLocked)
        }
    }

    /// The group's own switch: on while anything in it is, off for all.
    private func masterRow(_ group: NotificationGroup, isLocked: Bool) -> some View {
        let total = group.topics.count
        let on = store.prefs.onCount(in: group)
        let count = String(localized: L10n.notifGroupCount(on, total))
        return Toggle(isOn: Binding(
            get: { on > 0 },
            set: { store.send(.groupToggled(group, $0)) }
        )) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(group.title).font(.headline)
                        if group.feature != nil { PlusMark(isLocked: isLocked, style: .headline) }
                    }
                    Text(count)
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                        .accessibilityHidden(true)
                }
            } icon: {
                Image(systemName: group.symbol).foregroundStyle(group.tint)
            }
        }
        .disabled(!store.isLoaded)
        .accessibilityValue(Text(count))
    }

    private func topicRow(_ topic: NotificationTopic, in group: NotificationGroup) -> some View {
        Toggle(isOn: Binding(
            get: { store.prefs.isOn(topic) },
            set: { store.send(.topicToggled(topic, $0)) }
        )) {
            if group.hasMasterSwitch {
                Text(topic.title)
            } else {
                Label { Text(topic.title) } icon: {
                    Image(systemName: topic.symbol).foregroundStyle(group.tint)
                }
            }
        }
        .disabled(!store.isLoaded)
    }

    @ViewBuilder
    private func groupFooter(_ group: NotificationGroup, isLocked: Bool) -> some View {
        if group == .messages || isLocked, let feature = group.feature {
            VStack(alignment: .leading, spacing: 6) {
                if group == .messages {
                    Text(L10n.notifMentionsFooter)
                }
                if isLocked {
                    Text(L10n.notifNeedsPlus)
                    Button { PaywallBroker.shared.request(feature) } label: {
                        Text(L10n.notifSeePlus).font(.footnote.weight(.semibold))
                    }
                }
            }
        }
    }
}
