import ComposableArchitecture
import Foundation

@Reducer
public struct SettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var home: Home?
        public var user: User?
        public var members: IdentifiedArrayOf<User> = []
        public var didCopyInviteCode = false

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
    }

    @Reducer
    public enum Destination {
        case editName(EditNameFeature)
    }

    public enum Action: BindableAction {
        case task
        case membersUpdated([User])
        case editNameTapped
        case themeSelected(AppTheme)
        case languageSelected(AppLanguage)
        case copyInviteCodeTapped
        case inviteCodeCopyExpired
        case switchHomeTapped
        case signOutTapped
        case signOutConfirmed
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {
            case confirmSignOut
        }

        public enum Delegate: Equatable {
            case switchHomeRequested
            case languageChanged(AppLanguage)
        }
    }

    private enum CancelID { case members, copyReset }

    @Dependency(\.homes) var homes
    @Dependency(\.auth) var auth
    @Dependency(\.continuousClock) var clock
    @Dependency(\.pasteboard) var pasteboard

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                return .run { [homeID = state.homeID] send in
                    for try await members in homes.members(homeID) {
                        await send(.membersUpdated(members))
                    }
                } catch: { _, _ in
                    // A membership list that fails to load is not worth an
                    // alert on a settings screen; the section just stays empty.
                }
                .cancellable(id: CancelID.members, cancelInFlight: true)

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

            case .switchHomeTapped:
                return .send(.delegate(.switchHomeRequested))

            case .signOutTapped:
                state.alert = .confirmSignOut()
                return .none

            case .alert(.presented(.confirmSignOut)), .signOutConfirmed:
                return .run { _ in await auth.signOut() }

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
