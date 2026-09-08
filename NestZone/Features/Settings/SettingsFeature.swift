import ComposableArchitecture
import Foundation
import UIKit
import UserNotifications

@Reducer
public struct SettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var home: Home?
        public var user: User?
        public var members: IdentifiedArrayOf<User> = []
        /// Every home the user belongs to. Copied down by `AppFeature` from the
        /// single app-wide `homes:listMine` subscription rather than fetched
        /// again here.
        public var homes: IdentifiedArrayOf<Home> = []
        public var didCopyInviteCode = false
        /// Where this device stands with APNs and with the server. Owned by
        /// `AppFeature`, which outlives every tab container, and copied down
        /// here — this screen displays it, and sign-out unregisters it.
        public var pushRegistration: PushRegistration = .none
        public var notificationStatus: UNAuthorizationStatus = .notDetermined
        public var isSendingTestPush = false
        /// The row shows the first eight characters, which is all you need to
        /// pick this device out of a list. Matching one against a backend row,
        /// or pasting it into an APNs request by hand, needs all of it.
        public var isShowingFullPushToken = false
        public var didCopyPushToken = false
        /// The stack shows four avatars and a "+2". Who those people are is a
        /// question the row can answer in place.
        public var isShowingMembers = false

        /// `.denied` can only be undone in Settings.app, so the row becomes a
        /// link there rather than a toggle that would silently do nothing.
        public var notificationsDenied: Bool { notificationStatus == .denied }
        public var notificationsOn: Bool {
            [.authorized, .provisional, .ephemeral].contains(notificationStatus)
        }

        /// The row's whole answer to "can a push land on this phone?", in
        /// words. It used to be the token prefix, its length and the gateway
        /// crammed into one trailing string, which was too long for the slot
        /// and wrapped — and a wrapped trailing value reads as a mistake.
        ///
        /// Permission being granted does not mean iOS ever handed over a token,
        /// and holding a token does not mean the server took it, so all four
        /// states get their own words. A row that says "not registered" when
        /// the truth is "registering" sends people looking for a bug that
        /// resolves itself a second later.
        public var pushStatusLabel: String {
            switch pushRegistration {
            case .none:
                String(localized: L10n.settingsNotificationsNoDevice)
            case .pending:
                String(localized: L10n.settingsNotificationsDevicePending)
            case .registered:
                String(localized: L10n.settingsNotificationsDeviceRegistered)
            case .failed:
                String(localized: L10n.settingsNotificationsDeviceFailed)
            }
        }

        /// Red for anything a push cannot land on, so the row reads at a glance.
        public var pushTokenIsHealthy: Bool { pushRegistration.isRegistered }

        /// The whole token, for the expanded row and the clipboard.
        public var pushTokenFull: String? { pushRegistration.token }

        /// The two facts that decide whether a token can be delivered at all,
        /// shown under the token they describe rather than in a row that has no
        /// space for them.
        public var pushTokenDetail: String? {
            guard let token = pushRegistration.token else { return nil }
            return String(localized: L10n.settingsNotificationsDeviceDetail(
                token.count / 2, APNSEnvironment.current
            ))
        }

        @Shared(.theme) public var theme: AppTheme
        @Shared(.language) public var language: AppLanguage
        @Shared(.includeAdultTitles) public var includeAdultTitles: Bool

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, home: Home? = nil, user: User? = nil) {
            self.homeID = homeID
            self.home = home
            self.user = user
        }

        /// Belonging to more than one home turns "Manage Home" into
        /// "Switch Home"; the sheet behind it is the same either way.
        public var hasMultipleHomes: Bool { homes.count > 1 }

        /// Keeps the sheet's copy of the list in step while it is open, so a
        /// home left on another device stops being offered here.
        public mutating func applyHomes(_ homes: IdentifiedArrayOf<Home>) {
            self.homes = homes
            if case var .manageHomes(manage) = destination {
                manage.homes = homes
                destination = .manageHomes(manage)
            }
        }
    }

    @Reducer
    public enum Destination {
        case editName(EditNameFeature)
        case manageHomes(ManageHomesFeature)
    }

    public enum Action: BindableAction {
        case task
        case notificationStatusLoaded(UNAuthorizationStatus)
        case notificationsToggled(Bool)
        case openSystemSettingsTapped
        case sendTestPushTapped
        case testPushFinished(Result<PushResult, AppError>)
        case pushRegistrationChanged(PushRegistration)
        case membersRowTapped
        case deviceRowTapped
        case copyPushTokenTapped
        case pushTokenCopyExpired
        case membersUpdated([User])
        case editNameTapped
        case themeSelected(AppTheme)
        case languageSelected(AppLanguage)
        case copyInviteCodeTapped
        case inviteCodeCopyExpired
        case manageHomesTapped
        case signOutTapped
        case signOutConfirmed
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {
            case confirmSignOut
        }

        @CasePathable
        public enum Delegate: Equatable {
            case homeSwitched(HomeID)
            case languageChanged(AppLanguage)
            case notificationsEnabled
        }
    }

    private enum CancelID { case members, copyReset, pushTokenCopyReset }

    @Dependency(\.homes) var homes
    @Dependency(\.auth) var auth
    @Dependency(\.continuousClock) var clock
    @Dependency(\.pasteboard) var pasteboard
    @Dependency(\.push) var push
    @Dependency(\.devices) var devices
    @Dependency(\.openURL) var openURL

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { [homeID = state.homeID] send in
                        for try await members in homes.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in
                        // A membership list that fails to load is not worth an
                        // alert on a settings screen; the section stays empty.
                    }
                    .cancellable(id: CancelID.members, cancelInFlight: true),

                    .run { send in
                        await send(.notificationStatusLoaded(push.authorizationStatus()))
                    }
                )

            case let .notificationStatusLoaded(status):
                state.notificationStatus = status
                return .none

            case let .notificationsToggled(isOn):
                guard isOn else {
                    // iOS gives no API to revoke permission; only Settings.app
                    // can. Send them there rather than pretending.
                    return .send(.openSystemSettingsTapped)
                }
                return .run { send in
                    let granted = await push.requestAuthorization()
                    await send(.notificationStatusLoaded(push.authorizationStatus()))
                    if granted { await send(.delegate(.notificationsEnabled)) }
                }

            case .openSystemSettingsTapped:
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }

            case .sendTestPushTapped:
                guard !state.isSendingTestPush else { return .none }
                state.isSendingTestPush = true
                return .run { send in
                    await send(.testPushFinished(
                        Result { try await devices.sendTestToSelf() }
                            .mapError(AppError.init)
                    ))
                }

            // The whole point of this button is to answer "can you reach my
            // phone?", so every answer but yes has to be said out loud. It used
            // to swallow the error and stop the spinner, which looks identical
            // to a push that was sent and simply never arrived.
            case let .testPushFinished(result):
                state.isSendingTestPush = false
                switch result {
                case let .success(push) where push.sent == 0:
                    // APNs accepted nothing. Either no device is registered
                    // against this account or every token it had is dead — and
                    // `dropped` says which, so the copy can be specific.
                    state.alert = .failure(.validation(String(
                        localized: push.dropped > 0
                            ? L10n.settingsNotificationsTestDropped
                            : L10n.settingsNotificationsTestNoDevices
                    )))
                case .success:
                    break
                case let .failure(error):
                    state.alert = .failure(error)
                }
                return .none

            case let .pushRegistrationChanged(registration):
                state.pushRegistration = registration
                return .none

            case .membersRowTapped:
                guard !state.members.isEmpty else { return .none }
                state.isShowingMembers.toggle()
                return .none

            case .deviceRowTapped:
                // Nothing to expand to when there is no token; the row is
                // already saying everything it knows.
                guard state.pushRegistration.token != nil else { return .none }
                state.isShowingFullPushToken.toggle()
                return .none

            case .copyPushTokenTapped:
                guard let token = state.pushRegistration.token else { return .none }
                pasteboard.copy(token)
                state.didCopyPushToken = true
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.pushTokenCopyExpired)
                }
                // Its own id: copying a token must not cut short the invite
                // code's confirmation, or either one's tick vanishes early.
                .cancellable(id: CancelID.pushTokenCopyReset, cancelInFlight: true)

            case .pushTokenCopyExpired:
                state.didCopyPushToken = false
                return .none

            case let .membersUpdated(members):
                state.members = IdentifiedArray(uniqueElements: members)
                return .none

            case .editNameTapped:
                state.destination = .editName(
                    EditNameFeature.State(name: state.user?.name ?? "")
                )
                return .none

            case let .themeSelected(theme):
                state.$theme.withLock { $0 = theme }
                return .none

            case let .languageSelected(language):
                state.$language.withLock { $0 = language }
                return .send(.delegate(.languageChanged(language)))

            case .copyInviteCodeTapped:
                guard let code = state.home?.inviteCode else { return .none }
                pasteboard.copy(code)
                state.didCopyInviteCode = true
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.inviteCodeCopyExpired)
                }
                .cancellable(id: CancelID.copyReset, cancelInFlight: true)

            case .inviteCodeCopyExpired:
                state.didCopyInviteCode = false
                return .none

            case .manageHomesTapped:
                state.destination = .manageHomes(
                    ManageHomesFeature.State(homes: state.homes, currentHomeID: state.homeID)
                )
                return .none

            // Switching rebuilds the tab container around the new home, which
            // takes this screen with it — so the sheet is dismissed first.
            case let .destination(.presented(.manageHomes(.delegate(.switchRequested(id))))):
                state.destination = nil
                return .send(.delegate(.homeSwitched(id)))

            case .destination(.presented(.manageHomes(.delegate(.dismissRequested)))):
                state.destination = nil
                return .none

            case .signOutTapped:
                state.alert = .confirmSignOut()
                return .none

            case .alert(.presented(.confirmSignOut)), .signOutConfirmed:
                // Deliberately `token` and not "the token the server told us
                // it took": an earlier launch may have registered this same
                // token successfully, and skipping the unregister because
                // *this* launch could not confirm it leaves the device
                // receiving a household's notifications after leaving it.
                return .run { [token = state.pushRegistration.token] _ in
                    await auth.signOut(token)
                }

            case .destination(.presented(.editName(.finished))):
                state.destination = nil
                return .none

            case .binding, .destination, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == SettingsFeature.Action.Alert {
    static func confirmSignOut() -> Self {
        AlertState {
            TextState(String(localized: L10n.settingsLogoutButtonTitle))
        } actions: {
            ButtonState(role: .destructive, action: .confirmSignOut) {
                TextState(String(localized: L10n.settingsLogoutButtonTitle))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.settingsLogoutConfirmMessage))
        }
    }
}

/// Renaming yourself.
///
/// This exists because Apple hands over a display name only on a user's very
/// first authorization. Anyone who had already authorized NestZone before the
/// name was captured has none, and without this there is no way to set one.
@Reducer
public struct EditNameFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var name: String
        public var isSubmitting = false
        public var inlineError: String?

        public init(name: String) { self.name = name }

        public var canSubmit: Bool {
            !isSubmitting && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: Equatable, BindableAction {
        case submitTapped
        case failed(AppError)
        case finished
        case binding(BindingAction<State>)
    }

    @Dependency(\.auth) var auth

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                return .run { [name = state.name] send in
                    try await auth.updateDisplayName(name)
                    // No refetch: `currentUser` is a live `users:me`
                    // subscription, so the new name arrives on its own.
                    await send(.finished)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .failed(error):
                state.isSubmitting = false
                state.inlineError = error.errorDescription
                return .none

            case .finished, .binding:
                return .none
            }
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension SettingsFeature.Destination.State: Equatable {}
