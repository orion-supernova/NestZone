import ComposableArchitecture
import SwiftUI

/// Settings, rebuilt on `Form`.
///
/// The old screen hand-drew every row as a `GlassCard` with its own gradient
/// icon chip and nine drop shadows, which meant it had to re-derive grouping,
/// separators, dynamic-type behaviour and VoiceOver order that `Form` already
/// gets right — and it lost the system's own Liquid Glass treatment.
public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One curve for both disclosures, applied to the disclosing row and never
    /// to its `Section`. Section-wide it animated every sibling row too, which
    /// is what made opening one row shove the rest of the screen around.
    ///
    /// `Motion.spring` is the app's token for anything that changes size, and a
    /// row growing is exactly that. Under Reduce Motion the height still has to
    /// change — there is no way to add a row without it — so the content fades
    /// instead of springing.
    private var disclosure: Animation { reduceMotion ? Motion.fade : Motion.spring }

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            profileSection
            homeSection
            appearanceSection
            notificationsSection
            preferencesSection
            accountSection
        }
        .scrollContentBackground(.hidden)
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.settingsScreenTitle))
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(state: \.destination?.editName, action: \.destination.editName)) {
            EditNameSheet(store: $0)
        }
        .sheet(item: $store.scope(state: \.destination?.manageHomes, action: \.destination.manageHomes)) {
            ManageHomesSheet(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            Button { store.send(.editNameTapped) } label: {
                HStack(spacing: 14) {
                    Avatar(
                        initials: store.user?.initials ?? "?",
                        seed: store.user?.id.rawValue ?? "",
                        size: 52
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.user?.displayName ?? "")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(L10n.settingsProfileCustomizeExperience)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Home

    @ViewBuilder
    private var homeSection: some View {
        Section {
            LabeledContent {
                Text(store.home?.name ?? "")
            } label: {
                Label { Text(L10n.settingsCurrentHomeTitle) } icon: {
                    Image(systemName: "house.fill")
                }
            }

            if let code = store.home?.inviteCode {
                Button { store.send(.copyInviteCodeTapped) } label: {
                    LabeledContent {
                        HStack(spacing: 6) {
                            Text(code).monospaced()
                            Image(systemName: store.didCopyInviteCode
                                ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(store.didCopyInviteCode
                                    ? Palette.success : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    } label: {
                        Label { Text(L10n.settingsInviteCodeTitle) } icon: {
                            Image(systemName: "key.fill")
                        }
                    }
                }
                .sensoryFeedback(.success, trigger: store.didCopyInviteCode) { _, copied in
                    copied
                }
            }

            if !store.members.isEmpty {
                // Same shape as the device row: expands in place rather than
                // opening a sheet. A household is a handful of people, and a
                // modal to read four names is a lot of ceremony for a list
                // that fits under the row it came from.
                VStack(alignment: .leading, spacing: 10) {
                    Button { store.send(.membersRowTapped) } label: { membersRow }
                        .buttonStyle(.plain)

                    if store.isShowingMembers {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.members) { member in
                                HStack(spacing: 10) {
                                    Avatar(
                                        initials: member.initials,
                                        seed: member.id.rawValue,
                                        size: 26
                                    )
                                    Text(member.displayName)
                                        .font(.subheadline)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.inset, in: .rect(cornerRadius: 10))
                        .transition(.opacity)
                    }
                }
                .animation(disclosure, value: store.isShowingMembers)
            }

            Button { store.send(.manageHomesTapped) } label: {
                LabeledContent {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                } label: {
                    // One home is managed, several are switched between — but
                    // both open the same sheet, which is also the only way to
                    // leave or delete a home.
                    Label {
                        Text(store.hasMultipleHomes
                            ? L10n.homeSelectionSwitchTitle
                            : L10n.manageHomesButton)
                    } icon: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                }
            }
        } header: {
            Text(L10n.settingsHomeManagementTitle)
        } footer: {
            if store.home?.inviteCode != nil {
                Text(L10n.settingsInviteCodeHelpText)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Picker(selection: Binding(
                get: { store.theme },
                set: { store.send(.themeSelected($0)) }
            )) {
                ForEach(AppTheme.allCases) { theme in
                    Label {
                        Text(theme.displayName)
                    } icon: {
                        Circle().fill(theme.gradient).frame(width: 18, height: 18)
                    }
                    .tag(theme)
                }
            } label: {
                Label { Text(L10n.settingsThemeTitle) } icon: {
                    Image(systemName: "paintpalette.fill")
                }
            }
            .pickerStyle(.navigationLink)

            Picker(selection: Binding(
                get: { store.language },
                set: { store.send(.languageSelected($0)) }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.endonym).tag(language)
                }
            } label: {
                Label { Text(L10n.settingsLanguageTitle) } icon: {
                    Image(systemName: "globe")
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text(L10n.settingsAppearanceTitle)
        } footer: {
            Text(L10n.settingsAppearanceThemeFooter)
        }
    }

    private var notificationsSection: some View {
        Section {
            if store.notificationsDenied {
                Button { store.send(.openSystemSettingsTapped) } label: {
                    Label {
                        Text(L10n.settingsNotificationsOpenSettings)
                    } icon: {
                        Image(systemName: "bell.slash")
                    }
                }
            } else {
                Toggle(isOn: Binding(
                    get: { store.notificationsOn },
                    set: { store.send(.notificationsToggled($0)) }
                )) {
                    Label {
                        Text(L10n.settingsNotificationsToggle)
                    } icon: {
                        Image(systemName: "bell.badge")
                    }
                }
            }

            if store.notificationsOn {
                Button { store.send(.sendTestPushTapped) } label: {
                    HStack {
                        Label {
                            Text(L10n.settingsNotificationsSendTest)
                        } icon: {
                            Image(systemName: "paperplane")
                        }
                        Spacer(minLength: 0)
                        if store.isSendingTestPush {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .disabled(store.isSendingTestPush)

                // Whether this particular device is actually reachable.
                //
                // "Notifications are on" and "the server can reach this phone"
                // are different claims, and only the second one delivers
                // anything. A device whose token never arrived looks identical
                // to a working one from this screen, which turned a five-minute
                // question — which of these rows is my phone? — into an
                // afternoon of guessing.
                // One row, not two. Split across a `Form` separator the token
                // sat at the left margin under a right-aligned value and read
                // as a stray line rather than part of the row it belongs to.
                //
                // Tappable only when there is something to expand to: a row
                // that highlights under the finger and then does nothing reads
                // as a bug in the screen you came here to debug.
                VStack(alignment: .leading, spacing: 10) {
                    if store.pushTokenFull == nil {
                        deviceRow
                    } else {
                        Button { store.send(.deviceRowTapped) } label: { deviceRow }
                            .buttonStyle(.plain)
                    }

                    if store.isShowingFullPushToken, let token = store.pushTokenFull {
                        VStack(alignment: .leading, spacing: 6) {
                            pushTokenBlock(token)
                            if let detail = store.pushTokenDetail {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(Palette.accessory)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(disclosure, value: store.isShowingFullPushToken)
            }
        } header: {
            Text(L10n.settingsNotificationsTitle)
        } footer: {
            Text(store.notificationsDenied
                ? L10n.settingsNotificationsDenied
                : L10n.settingsNotificationsFooter)
        }
        .animation(Motion.spring, value: store.notificationStatus)
    }

    /// Collapsed: the overlapping stack. The chevron is what says there is a
    /// list of names behind it.
    private var membersRow: some View {
        LabeledContent {
            HStack(spacing: 6) {
                AvatarStack(members: store.members.map {
                    AvatarStack.Member(id: $0.id.rawValue, initials: $0.initials)
                })
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
                    .rotationEffect(.degrees(store.isShowingMembers ? 90 : 0))
            }
        } label: {
            Label { Text(L10n.homeMembersLabel) } icon: {
                Image(systemName: "person.2.fill")
            }
        }
    }

    /// The whole token, quoted as a block so it reads as detail belonging to
    /// the row above rather than a line of text at the margin. Tapping it
    /// copies — the block is the target, because a 160-character string is
    /// nobody's idea of something to select by hand.
    private func pushTokenBlock(_ token: String) -> some View {
        Button { store.send(.copyPushTokenTapped) } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(token)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Palette.accessoryStrong)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: store.didCopyPushToken
                    ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(store.didCopyPushToken
                        ? Palette.success : Palette.accessoryStrong)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(10)
            .background(Palette.inset, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.settingsNotificationsDevice))
        .sensoryFeedback(.success, trigger: store.didCopyPushToken) { _, copied in
            copied
        }
    }

    /// One line, always: where this device stands, and a chevron if there is
    /// a token to look at.
    private var deviceRow: some View {
        LabeledContent {
            HStack(spacing: 6) {
                // Deliberately not monospaced any more: this is a word, not
                // an identifier, and it has to fit the slot at every Dynamic
                // Type size without wrapping.
                Text(store.pushStatusLabel)
                    .font(.subheadline)
                    .foregroundStyle(store.pushTokenIsHealthy ? Color.secondary : Color.red)
                    .lineLimit(1)
                if store.pushTokenFull != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(store.isShowingFullPushToken ? 90 : 0))
                }
            }
        } label: {
            Label {
                Text(L10n.settingsNotificationsDevice)
            } icon: {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
            }
        }
    }

    private var preferencesSection: some View {
        Section {
            Toggle(isOn: $store.includeAdultTitles) {
                Label { Text(L10n.settingsAdultTitlesTitle) } icon: {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                }
            }
        } header: {
            Text(L10n.settingsGeneralTitle)
        } footer: {
            Text(L10n.settingsAdultTitlesFooter)
        }
    }

    private var accountSection: some View {
        Section {
            Button(role: .destructive) { store.send(.signOutTapped) } label: {
                Label { Text(L10n.settingsLogoutButtonTitle) } icon: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
        } header: {
            Text(L10n.settingsAccountTitle)
        }
    }
}

struct EditNameSheet: View {
    @Bindable var store: StoreOf<EditNameFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)

                VStack(spacing: Metrics.sectionSpacing) {
                    Text(L10n.settingsEditNameMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    GlassTextField(
                        L10n.settingsEditNameTitle,
                        text: $store.name,
                        symbol: "person",
                        error: store.inlineError.map { LocalizedStringResource(stringLiteral: $0) }
                    )
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { store.send(.submitTapped) }

                    PrimaryButton(L10n.commonSave, isLoading: store.isSubmitting) {
                        store.send(.submitTapped)
                    }
                    .disabled(!store.canSubmit)

                    Spacer(minLength: 0)
                }
                .padding(Metrics.screenPadding)
            }
            .navigationTitle(Text(L10n.settingsEditNameTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationBackground(.regularMaterial)
    }
}
