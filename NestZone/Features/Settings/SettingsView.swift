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
        ScrollViewReader { proxy in
        Form {
            profileSection
            homeSection
            plusSection
            appearanceSection
            notificationsSection
            preferencesSection
            privacySection
            aboutSection
            accountSection.id("accountSection")
            #if DEBUG
            developerSection
            #endif
        }
        .scrollContentBackground(.hidden)
        .settingsRows()
        #if DEBUG
        // `-settingsScroll 1`: open at the foot, for screenshots of the lower rows.
        .task {
            guard UserDefaults.standard.bool(forKey: "settingsScroll") else { return }
            try? await Task.sleep(for: .seconds(1))
            proxy.scrollTo("accountSection", anchor: .bottom)
        }
        #endif
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.settingsScreenTitle))
        .task { await store.send(.task).finish() }
        .hostedSheet(item: $store.scope(state: \.destination?.editName, action: \.destination.editName)) {
            EditNameSheet(store: $0)
        }
        .hostedSheet(item: $store.scope(state: \.destination?.manageHomes, action: \.destination.manageHomes)) {
            ManageHomesSheet(store: $0)
        }
        .hostedSheet(item: $store.scope(state: \.destination?.blockedPeople, action: \.destination.blockedPeople)) {
            BlockedPeopleView(store: $0)
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
                                    .font(.caption)
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
                    initials: store.user?.ownInitials ?? "?",
                    seed: store.user?.id.rawValue ?? "",
                    name: store.user?.ownDisplayName ?? "",
                    photo: store.user?.avatarURL,
                    size: 52,
                    isBusy: store.isUpdatingAvatar,
                    onSelected: { store.send(.avatarSelected($0)) },
                    onRemoved: { store.send(.avatarRemoved) }
                )

                Button { store.send(.editNameTapped) } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            if store.user.map({ !$0.hasName }) == true {
                                // Not the email: for Hide My Email that is a
                                // random relay handle.
                                Text(L10n.nameReminderLine)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(L10n.profileNameAdd)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.accentText)
                            } else {
                                Text(store.user?.displayName ?? "")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(L10n.settingsProfileCustomizeExperience)
                                    .font(.caption)
                                    .foregroundStyle(.secondaryText)
                            }
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
                                    ? Palette.successText : Palette.textSecondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsInviteCodeTitle)
                                Text(L10n.settingsInviteCodeHelpText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondaryText)
                            }
                        } icon: {
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
                                    Text(member.id == store.user?.id ? member.ownDisplayName : member.displayName)
                                        .font(.subheadline)
                                    Spacer(minLength: 0)
                                    // Not on your own row: leaving is Manage
                                    // Home's, and deleting yourself is below.
                                    if member.id != store.user?.id {
                                        Menu {
                                            Button(role: .destructive) {
                                                store.send(.blockMemberTapped(member))
                                            } label: {
                                                Label {
                                                    Text(L10n.chatBlock)
                                                } icon: {
                                                    Image(systemName: "hand.raised")
                                                }
                                            }
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
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.settingsThemeTitle)
                        Text(L10n.settingsAppearanceThemeFooter)
                            .font(.footnote)
                            .foregroundStyle(.secondaryText)
                    }
                } icon: {
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
        }
    }

    /// One row: what the system allows, and the page where each kind of
    /// notification is switched.
    private var notificationsSection: some View {
        Section {
            NavigationLink(
                item: $store.scope(state: \.destination?.notifications, action: \.destination.notifications)
            ) { isActive in
                if isActive { store.send(.notificationsRowTapped) }
            } destination: { $page in
                NotificationSettingsView(store: page)
            } label: {
                LabeledContent {
                    Text(store.notificationsOn ? L10n.notifRowOn : L10n.notifRowOff)
                        .foregroundStyle(.secondaryText)
                } label: {
                    Label { Text(L10n.settingsNotificationsTitle) } icon: {
                        Image(systemName: store.notificationsOn ? "bell.badge" : "bell.slash")
                    }
                }
            }
        }
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
                    .font(.caption.weight(.semibold))
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
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.accessoryStrong)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: store.didCopyPushToken
                    ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(store.didCopyPushToken
                        ? Palette.successText : Palette.accessoryStrong)
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
                    .foregroundStyle(store.pushTokenIsHealthy ? Palette.textSecondary : Palette.dangerText)
                    .lineLimit(1)
                if store.pushTokenFull != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiaryText)
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
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        PlusTitle(L10n.settingsAdultTitlesTitle)
                        Text(L10n.settingsAdultTitlesFooter)
                            .font(.footnote)
                            .foregroundStyle(.secondaryText)
                    }
                } icon: {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                }
            }
            .proLocked(.matureContent, placement: .inline)

            NavigationLink(
                item: $store.scope(state: \.destination?.calendar, action: \.destination.calendar)
            ) { isActive in
                if isActive { store.send(.calendarRowTapped) }
            } destination: { $calendar in
                CalendarSettingsView(store: calendar)
            } label: {
                LabeledContent {
                    Text(store.calendarRowValue).foregroundStyle(.secondaryText)
                } label: {
                    Label { Text(L10n.calendarSettingsTitle) } icon: {
                        Image(systemName: "calendar")
                    }
                }
            }
        } header: {
            Text(L10n.settingsGeneralTitle)
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
                    .foregroundStyle(.secondaryText)
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

            Button { store.send(.tourTapped) } label: {
                Label { Text(L10n.settingsTakeTour) } icon: {
                    Image(systemName: "sparkles.rectangle.stack")
                }
            }
            .accessibilityIdentifier("SettingsTakeTour")

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
                    .foregroundStyle(.secondaryText)
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
                                .foregroundStyle(.accentText)
                        }
                    }
                } else {
                    Label {
                        Text(L10n.settingsUpdateAvailable(version)).font(.footnote)
                    } icon: {
                        Image(systemName: "arrow.down.circle").foregroundStyle(.accentText)
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
                        .foregroundStyle(.secondaryText)
                } icon: {
                    Image(systemName: "clock").foregroundStyle(Palette.amber)
                }
            } else {
                Label {
                    Text(L10n.settingsUpToDate)
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.successText)
                }
            }
        }
    }

    // MARK: - NestZone Plus

    /// The house's subscription: whether it is on, whose it is, when it
    /// renews, and the two things the App Store wants within reach — managing
    /// it and restoring it.
    private var plusHomeNames: [HomeID: String] {
        Dictionary(store.homes.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private var plusSection: some View {
        let status = store.pro
        return Section {
            plusSummary(status)

            // What Plus includes stays one tap away whether or not the house
            // has it: the paywall's sheet is gone once it is bought.
            NavigationLink {
                PlusDetailsView(status: status, homeNames: plusHomeNames)
            } label: {
                Label { Text(L10n.plusSeeEverything) } icon: { Image(systemName: "list.bullet.rectangle") }
            }
            .listRowSeparator(.hidden, edges: .bottom)

            plusActions(status)

            if let result = store.plusRestoreResult {
                Text(result == .restored ? L10n.plusRestoredOn : L10n.paywallNothingToRestore)
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
            }
        } header: {
            Text(L10n.proFullName)
        }
    }

    /// The card's top: the mark, the name, whether it is on, and one quiet
    /// line that says whose it is, what it covers and when it renews.
    private func plusSummary(_ status: ProStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                PlusLockup(tileSize: 30)
                Spacer(minLength: 8)
                Text(status.isPro ? L10n.plusStatusOn : L10n.plusStatusOff)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.isPro ? AnyShapeStyle(Palette.successText) : AnyShapeStyle(.secondaryText))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        status.isPro ? AnyShapeStyle(Palette.successText.opacity(0.16)) : AnyShapeStyle(Palette.inset),
                        in: .capsule
                    )
            }
            Text(plusSummaryLine(status))
                .font(.subheadline)
                .foregroundStyle(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// "Yours · Covers Bizim Ev, Yazlık · Renews Dec 20, 2026". A free house
    /// gets the one thing worth knowing instead.
    private func plusSummaryLine(_ status: ProStatus) -> String {
        guard status.isPro, status.isLoaded else { return String(localized: L10n.plusFooter) }
        var parts: [String] = []
        if let carrier = status.carrier {
            parts.append(String(localized: status.mine
                ? L10n.plusYours
                : L10n.plusFrom(carrier.name ?? User.displayName(name: nil, email: nil))))
        }
        if status.mine, let coverage = status.coverage {
            let names = coverage.homeIDs.compactMap { plusHomeNames[$0] }.filter { !$0.isEmpty }
            parts.append(String(localized: names.isEmpty
                ? L10n.plusCoversCount(coverage.homeIDs.count, coverage.limit)
                : L10n.plusCoversNames(names.joined(separator: ", "))))
        } else {
            parts.append(String(localized: L10n.plusCoversThisHouse))
        }
        if let end = status.expiresAt {
            // A subscription that is switched off says when it ends, not that
            // it "won't renew"; lifetime has no date at all.
            let date = end.formatted(date: .abbreviated, time: .omitted)
            parts.append(String(localized: status.willRenew == false ? L10n.plusEnds(date) : L10n.plusRenews(date)))
        } else {
            parts.append(String(localized: L10n.plusNoEnd))
        }
        return parts.joined(separator: " · ")
    }

    /// The two things the App Store wants within reach, side by side; a free
    /// house gets the way in instead, with restore small beside it.
    @ViewBuilder
    private func plusActions(_ status: ProStatus) -> some View {
        if status.isPro {
            // Side by side while both labels fit on one line at the same size;
            // stacked, still identical, when they do not (a longer language,
            // larger text). Never one scaled down to fit.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    if status.mine { plusManageButton }
                    plusRestoreButton
                }
                VStack(spacing: 10) {
                    if status.mine { plusManageButton }
                    plusRestoreButton
                }
            }
            // Inside the card, on its own insets, so its rounded bottom shows
            // below the buttons; no rule between the link above and them.
            .listRowSeparator(.hidden, edges: .top)
            .padding(.vertical, 4)
        } else {
            VStack(spacing: 10) {
                PrimaryButton(L10n.plusSeePlans, symbol: PlusStyle.unlockSymbol) {
                    PaywallBroker.shared.request(nil)
                }
                plusRestoreButton
            }
            .listRowSeparator(.hidden, edges: .top)
            .padding(.vertical, 4)
        }
    }

    private var plusManageButton: some View {
        plusActionButton(L10n.plusManage, symbol: "creditcard", busy: false) {
            showsManageSubscription = true
        }
    }

    private var plusRestoreButton: some View {
        plusActionButton(L10n.paywallRestore, symbol: "arrow.clockwise", busy: store.isRestoringPlus) {
            store.send(.plusRestoreTapped)
        }
        .disabled(store.isRestoringPlus)
    }

    private func plusActionButton(
        _ title: LocalizedStringResource,
        symbol: String,
        busy: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if busy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: symbol)
                }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.glass)
        .tint(.primary)
    }

    /// What this person has chosen not to see: the way back from a block.
    private var privacySection: some View {
        Section {
            Button { store.send(.blockedPeopleTapped) } label: {
                LabeledContent {
                    HStack(spacing: 6) {
                        if !store.blocked.isEmpty {
                            Text(store.blocked.count, format: .number)
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.accessory)
                    }
                } label: {
                    Label { Text(L10n.settingsBlockedPeople) } icon: {
                        Image(systemName: "hand.raised.fill")
                    }
                }
            }
        } header: {
            Text(L10n.settingsPrivacyTitle)
        } footer: {
            Text(L10n.settingsBlockedPeopleHelp)
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
                .labelStyle(.settingsRow(.caution))
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
                .labelStyle(.settingsRow(.destructive))
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
                        .foregroundStyle(.secondaryText)
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
