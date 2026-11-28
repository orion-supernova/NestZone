import ComposableArchitecture
import Foundation

/// The tour: a few short pages about what the app is for, then (the first
/// time) the way into a home.
///
/// One reducer and one view for both ways in. `.firstRun` is the person's
/// first launch with no home: it ends in the create and join sheets the
/// no-home screen already uses (`CreateHomeFeature`, `JoinHomeFeature`), and
/// says so to its parent, which owns what happens next. `.replay` is Settings'
/// "Take the tour": the same pages, no question and no way into a home, closed
/// by `delegate(.finished)`.
///
/// It never navigates and never writes the "seen" flag: `AppFeature` does,
/// when the person has a home, so a launch killed half way shows it again.
@Reducer
public struct OnboardingFeature: Sendable {
    public enum Mode: Equatable, Sendable { case firstRun, replay }

    public enum Page: Hashable, Sendable {
        case welcome, household, lists, plans, house, nestie
        /// First run's last page: create a home or join one.
        case start
        /// Replay's last page.
        case done
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var pages: [Page]
        public var index = 0
        var household: HouseholdKind?
        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?
        /// The first run's account menu: deleting asks first, then Apple.
        public var isConfirmingDelete = false
        /// Apple's sheet or the server is busy with a deletion.
        public var isLeaving = false

        public init(mode: Mode) {
            self.mode = mode
            switch mode {
            case .firstRun:
                pages = [.welcome, .household, .lists, .plans, .house, .nestie, .start]
            case .replay:
                // The question was answered once; asking again is a form.
                pages = [.welcome, .lists, .plans, .house, .nestie, .done]
            }
            @Shared(.householdKind) var stored
            household = HouseholdKind(rawValue: stored)
        }

        public var page: Page { pages[min(max(index, 0), pages.count - 1)] }
        public var isLast: Bool { index >= pages.count - 1 }
        /// The pages before the last one can be skipped past.
        public var canSkip: Bool { !isLast }
    }

    @Reducer
    public enum Destination {
        case create(CreateHomeFeature)
        case join(JoinHomeFeature)
    }

    public enum Action: BindableAction {
        case continueTapped
        case skipTapped
        case closeTapped
        case householdPicked(HouseholdKind)
        case createTapped
        case joinTapped
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
        case binding(BindingAction<State>)
        case signOutTapped
        case deleteAccountTapped
        /// Confirmed; the view asks Apple for a fresh authorisation.
        case deleteAccountConfirmed
        case deleteAccountAuthorized(code: String?)
        case deleteAccountFailed(AppError)

        public enum Alert: Equatable { case confirmSignOut }

        @CasePathable
        public enum Delegate: Equatable {
            /// Replay is over, by its last page, Skip or Close.
            case finished
            /// A home was created or joined from the last page, and its sheet
            /// has closed. The home itself arrives on `homes:listMine`.
            case homeReady
            /// The person left from the tour's menu (signed out, or deleted
            /// the account): the root ends the session.
            case signedOut
        }
    }

    @Dependency(\.auth) var auth

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .continueTapped:
                if state.isLast {
                    return state.mode == .replay ? .send(.delegate(.finished)) : .none
                }
                state.index += 1
                return .none

            case .skipTapped:
                // First run lands on the way into a home; a replay just ends.
                guard state.mode == .firstRun else { return .send(.delegate(.finished)) }
                state.index = state.pages.count - 1
                return .none

            case .closeTapped:
                return .send(.delegate(.finished))

            case let .householdPicked(kind):
                state.household = kind
                @Shared(.householdKind) var stored
                $stored.withLock { $0 = kind.rawValue }
                return .none

            case .createTapped:
                guard state.mode == .firstRun else { return .none }
                state.destination = .create(CreateHomeFeature.State())
                return .none

            case .joinTapped:
                guard state.mode == .firstRun else { return .none }
                state.destination = .join(JoinHomeFeature.State())
                return .none

            // The write is the live `homes:listMine` stream's to confirm; the
            // sheet only has to close, and the parent to know a home is there.
            case .destination(.presented(.create(.finished))),
                 .destination(.presented(.join(.finished))):
                state.destination = nil
                return .send(.delegate(.homeReady))

            // The tour replaced the screen that used to carry these two, and
            // a person who is not ready to make or join a home still has to be
            // able to leave (and to delete what they made by signing in).
            case .signOutTapped:
                state.alert = AlertState {
                    TextState(String(localized: L10n.settingsLogoutButtonTitle))
                } actions: {
                    ButtonState(role: .destructive, action: .confirmSignOut) {
                        TextState(String(localized: L10n.settingsLogoutButtonTitle))
                    }
                    ButtonState(role: .cancel) { TextState(String(localized: L10n.commonCancel)) }
                } message: {
                    TextState(String(localized: L10n.settingsLogoutConfirmMessage))
                }
                return .none

            case .alert(.presented(.confirmSignOut)):
                return .run { send in
                    await auth.signOut(nil)
                    await send(.delegate(.signedOut))
                }

            case .deleteAccountTapped:
                guard !state.isLeaving else { return .none }
                state.isConfirmingDelete = true
                return .none

            case .deleteAccountConfirmed:
                state.isLeaving = true
                return .none

            case let .deleteAccountAuthorized(code):
                return .run { send in
                    try await auth.deleteAccount(code)
                    await send(.delegate(.signedOut))
                } catch: { error, send in
                    let mapped = AppError(error)
                    // Already gone on the server: it ends like a sign-out.
                    if mapped.meansSessionIsGone { await send(.delegate(.signedOut)) }
                    else { await send(.deleteAccountFailed(mapped)) }
                }

            case let .deleteAccountFailed(error):
                state.isLeaving = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .alert, .destination, .delegate, .binding:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension OnboardingFeature.Destination.State: Equatable {}
