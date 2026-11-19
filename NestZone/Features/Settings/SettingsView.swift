import AuthenticationServices
import ComposableArchitecture
import StoreKit
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
    @Environment(\.authorizationController) private var authorizationController

    /// One curve for both disclosures, applied to the disclosing row and never
    /// to its `Section`. Section-wide it animated every sibling row too, which
    /// is what made opening one row shove the rest of the screen around.
    ///
    /// `Motion.spring` is the app's token for anything that changes size, and a
    /// row growing is exactly that. Under Reduce Motion the height still has to
    /// change — there is no way to add a row without it — so the content fades
    /// instead of springing.
    private var disclosure: Animation { reduceMotion ? Motion.fade : Motion.spring }

    @State private var showsManageSubscription = false

    #if DEBUG
    /// `GlassListLab` opens from here, with local state rather than through the
    /// reducer, because it is scaffolding and not a feature — nothing about the
    /// real Settings navigation changes for it.
    ///
    /// It needs a door at all because Xcode's canvas cannot run it: swift-
    /// navigation swizzles `viewDidAppear:` in `+load`, preview injection loads
    /// that image more than once, and the swizzled method ends up calling
    /// itself until the stack runs out. Nothing in the lab causes that, and
    /// nothing in the lab can avoid it.
    @State private var showsGlassLab = false
    #endif

    /// One page holds both; the terms are its anchor.
    private static let privacyURL = URL(string: "https://walhallaa.com/nestzone-privacy-terms")!
    private static let termsURL = URL(string: "https://walhallaa.com/nestzone-privacy-terms#terms")!

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            profileSection
            homeSection
            plusSection
            appearanceSection
            notificationsSection
            preferencesSection
            aboutSection
            accountSection
            #if DEBUG
            developerSection
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.settingsScreenTitle))
        .task { await store.send(.task).finish() }
        .hostedSheet(item: $store.scope(state: \.destination?.editName, action: \.destination.editName)) {
            EditNameSheet(store: $0)
        }
        .hostedSheet(item: $store.scope(state: \.destination?.manageHomes, action: \.destination.manageHomes)) {
            ManageHomesSheet(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .confirmationDialog(
            Text(L10n.settingsDeleteAccountTitle),
            isPresented: $store.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                store.send(.deleteAccountConfirmed)
                Task { await reauthorizeForDeletion() }
            } label: {
                Text(L10n.settingsDeleteAccountConfirm)
            }
            Button(role: .cancel) {} label: { Text(L10n.commonCancel) }
        } message: {
            // An Apple subscription is not ours to cancel: deleting the account
            // does not stop it billing.
            Text(String(localized: L10n.settingsDeleteAccountMessage)
                + "\n\n" + String(localized: L10n.settingsDeleteAccountSubscriptionNote))
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscription)
        #if DEBUG
        .hostedSheet(isPresented: $showsGlassLab) {
            NavigationStack {
                GlassListLab()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button { showsGlassLab = false } label: { Text(L10n.commonDone) }
                        }
                    }
            }
        }
        #endif
    }

    #if DEBUG
    /// Debug-only, so the copy is literal: a String Catalog entry here would be
    /// a key nobody could ever delete.
    private var developerSection: some View {
        Section {
            Button { showsGlassLab = true } label: {
                Label { Text(verbatim: "Glass list lab") } icon: {
                    Image(systemName: "slider.horizontal.3")
                }
            }

            // Nestie's Lab, with its "Pretend house" switch at the top of it:
            // the house the card draws is Today's, so the Lab opens there.
            Button { store.send(.nestieLabTapped) } label: {
                Label { Text(verbatim: "Nestie Lab") } icon: {
                    Image(systemName: "flask.fill")
                }
            }

            if store.notificationsOn {
                Button { store.send(.sendTestPushTapped) } label: {
                    HStack {
                        Label { Text(verbatim: "Send a test notification") } icon: {
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
                // "Notifications are on" and "the server can reach this phone"
                // are different claims, and only the second one delivers
                // anything. One row, not two: split across a `Form` separator
                // the token sat at the left margin and read as a stray line.
                // Tappable only when there is a token to expand to.
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
            Text(verbatim: "Developer")
        } footer: {
            Text(verbatim: "Debug builds only: the Nestie Lab, a test push to this phone, and this device's push token.")
        }
    }
    #endif

    // MARK: - Profile

    /// Two controls in one row, not one.
    ///
    /// The row used to be a single button that edited the name, with the avatar
    /// inside it as decoration — so the one thing on the screen that looks most
    /// like "tap me to change my picture" changed your name instead. Splitting
    /// them means the photo answers for itself and the rest of the row still
    /// goes where it always went.
    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                AvatarPickerButton(
                    initials: store.user?.initials ?? "?",
                    seed: store.user?.id.rawValue ?? "",
                    name: store.user?.displayName ?? "",
                    photo: store.user?.avatarURL,
                    size: 52,
                    isBusy: store.isUpdatingAvatar,
                    onSelected: { store.send(.avatarSelected($0)) },
                    onRemoved: { store.send(.avatarRemoved) }
                )

                Button { store.send(.editNameTapped) } label: {
                    HStack(spacing: 0) {
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
                    // Without this the button is only tappable on the text
                    // itself, and the gap beside it — most of the row — does
                    // nothing.
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(L10n.settingsEditNameTitle))
            }
            .padding(.vertical, 4)
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
                                    // Not on your own row: leaving is Manage
                                    // Home's, and deleting yourself is below.
                                    if member.id != store.user?.id {
                                        Menu {
                                            Button(role: .destructive) {
                                                store.send(.removeMemberTapped(member))
                                            } label: {
                                                Label {
                                                    Text(L10n.settingsRemoveMemberButton)
                                                } icon: {
                                                    Image(systemName: "person.crop.circle.badge.minus")
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .foregroundStyle(Palette.accessory)
                                                .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                                                .contentShape(.rect)
                                        }
                                        .accessibilityLabel(Text(L10n.settingsMemberOptions(member.displayName)))
                                    }
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
            Button { store.send(.customizeTapped) } label: {
                Label { Text(L10n.settingsCustomizeTitle) } icon: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
            .accessibilityIdentifier("SettingsCustomize")

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

    #if DEBUG
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
        .accessibilityLabel(Text(verbatim: "Push token"))
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
                Text(verbatim: "Push token")
            } icon: {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
            }
        }
    }
    #endif

    private var preferencesSection: some View {
        Section {
            // Plus: a free house sees it off and locked, and the stored
            // choice waits untouched for an upgrade.
            Toggle(isOn: store.pro.isPro ? $store.includeAdultTitles : .constant(false)) {
                Label { Text(L10n.settingsAdultTitlesTitle) } icon: {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                }
            }
            .proLocked(.matureContent)
        } header: {
            Text(L10n.settingsGeneralTitle)
        } footer: {
            Text(L10n.settingsAdultTitlesFooter)
        }
    }

    // MARK: - About

    /// What this build is, and whether it is the newest one.
    ///
    /// Two versions are worth saying and they are different facts. The App
    /// Store's is what tapping Update would actually get you. The changelog's
    /// runs *ahead* of it — release notes are published when the work lands and
    /// the build is still in review — so "there is something coming" is a true
    /// and useful thing to say to somebody who is already up to date.
    ///
    /// The comparison happens here rather than on the server, for the same
    /// reason a release note draws itself as "coming soon" on an older phone:
    /// only this build knows what this build is.
    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(verbatim: AppVersion.current.raw)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } label: {
                Label { Text(L10n.settingsVersionTitle) } icon: {
                    Image(systemName: "app.badge.checkmark")
                }
            }

            Button { store.send(.checkForUpdatesTapped) } label: {
                HStack {
                    Label { Text(L10n.settingsCheckUpdates) } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Spacer(minLength: 8)
                    if case .checking = store.updateCheck {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(store.updateCheck == .checking)

            updateOutcome

            // Required in the app for a subscription (3.1.2), and for
            // anybody who wants to read them.
            Link(destination: Self.privacyURL) {
                Label { Text(L10n.settingsPrivacyPolicy) } icon: {
                    Image(systemName: "hand.raised")
                }
            }
            Link(destination: Self.termsURL) {
                Label { Text(L10n.settingsTermsOfUse) } icon: {
                    Image(systemName: "doc.text")
                }
            }
        } header: {
            Text(L10n.settingsAboutTitle)
        } footer: {
            if case let .result(check) = store.updateCheck {
                Text(L10n.settingsCheckedAt(
                    check.checkedAt.date.formatted(
                        Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale)
                    )
                ))
            }
        }
    }

    /// What the check found, as a row rather than an alert.
    @ViewBuilder
    private var updateOutcome: some View {
        switch store.updateCheck {
        case .idle, .checking:
            EmptyView()

        case .failed:
            Label {
                Text(L10n.settingsCheckFailed)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(Palette.amber)
            }
            .font(.footnote)

        case let .result(check):
            // The store's answer first: it is the only one somebody can act on.
            if let version = check.storeVersion,
               AppVersion(version) > AppVersion.current {
                if let url = check.storeURL {
                    Button { store.send(.openAppStoreTapped(url)) } label: {
                        Label {
                            Text(L10n.settingsUpdateAvailable(version))
                                .font(.footnote.weight(.semibold))
                        } icon: {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(theme.accent)
                        }
                    }
                } else {
                    Label {
                        Text(L10n.settingsUpdateAvailable(version)).font(.footnote)
                    } icon: {
                        Image(systemName: "arrow.down.circle").foregroundStyle(theme.accent)
                    }
                }
            } else if let coming = check.changelogVersion,
                      AppVersion(coming) > AppVersion.current {
                // Up to date as far as the store is concerned, but the notes
                // for a newer version are already written. Saying so is the
                // honest version of "nothing to do" — and it is what the
                // Updates tab is already showing as "coming soon".
                Label {
                    Text(L10n.settingsUpdateComing(coming))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "clock").foregroundStyle(Palette.amber)
                }
            } else {
                Label {
                    Text(L10n.settingsUpToDate)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.emerald)
                }
            }
        }
    }

    // MARK: - NestZone Plus

    /// The house's subscription: whether it is on, whose it is, when it
    /// renews, and the two things the App Store wants within reach — managing
    /// it and restoring it.
    private var plusSection: some View {
        let status = store.pro
        return Section {
            LabeledContent {
                Text(status.isPro ? L10n.plusStatusOn : L10n.plusStatusOff)
                    .foregroundStyle(status.isPro ? Palette.success : Color.secondary)
            } label: {
                Label { Text(L10n.proFullName) } icon: { Image(systemName: "sparkles") }
            }

            if status.isPro, status.isLoaded {
                if let carrier = status.carrier {
                    Text(status.mine
                        ? L10n.paywallCarriedByYou
                        : L10n.paywallCarriedBy(carrier.name ?? User.displayName(name: nil, email: nil)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let end = status.expiresAt {
                    // A subscription that is switched off says when it ends, not
                    // that it "won't renew"; lifetime has no date at all.
                    Text(status.willRenew == false
                        ? L10n.plusEnds(end.formatted(date: .abbreviated, time: .omitted))
                        : L10n.plusRenews(end.formatted(date: .abbreviated, time: .omitted)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.plusNoEnd).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            if status.isPro, status.mine {
                Button { showsManageSubscription = true } label: {
                    Label { Text(L10n.plusManage) } icon: { Image(systemName: "creditcard") }
                }
            } else if !status.isPro {
                Button { PaywallBroker.shared.request(nil) } label: {
                    Label { Text(L10n.plusSeePlans) } icon: { Image(systemName: "lock.open.fill") }
                }
            }

            Button { store.send(.plusRestoreTapped) } label: {
                HStack {
                    Label { Text(L10n.paywallRestore) } icon: { Image(systemName: "arrow.clockwise") }
                    if store.isRestoringPlus {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(store.isRestoringPlus)

            if let result = store.plusRestoreResult {
                Text(result == .restored ? L10n.plusRestoredOn : L10n.paywallNothingToRestore)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.proFullName)
        } footer: {
            Text(L10n.plusFooter)
        }
    }

    private var accountSection: some View {
        Section {
            Button(role: .destructive) { store.send(.signOutTapped) } label: {
                HStack {
                    Label { Text(L10n.settingsLogoutButtonTitle) } icon: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    // Waiting for the launch's restore to answer before the
                    // device is unregistered; see `SettingsFeature`.
                    if store.isSigningOut {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(store.isSigningOut || store.isDeletingAccount || store.isAuthorizingDelete)

            // Guideline 5.1.1(v): an account made in the app can be deleted in
            // it. Destructive, last, and behind a dialog that says what goes.
            Button(role: .destructive) { store.send(.deleteAccountTapped) } label: {
                HStack {
                    Label { Text(L10n.settingsDeleteAccountButton) } icon: {
                        Image(systemName: "person.crop.circle.badge.minus")
                    }
                    if store.isDeletingAccount {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(store.isSigningOut || store.isDeletingAccount || store.isAuthorizingDelete)
        } header: {
            Text(L10n.settingsAccountTitle)
        }
    }

    /// Asks Apple again, so the server gets a fresh `authorizationCode` to
    /// revoke the Apple token with, and hands the answer to the reducer. Backing
    /// out of Apple's sheet stops the deletion, quietly.
    private func reauthorizeForDeletion() async {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        do {
            let result = try await authorizationController.performRequest(request)
            guard case let .appleID(credential) = result else {
                store.send(.deleteAccountAuthorizationFailed(.cancelled))
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            store.send(.deleteAccountAuthorized(code: code))
        } catch {
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                store.send(.deleteAccountAuthorizationFailed(.cancelled))
            } else {
                store.send(.deleteAccountAuthorizationFailed(AppError(error)))
            }
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
