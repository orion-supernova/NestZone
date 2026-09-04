import ComposableArchitecture
import Foundation

/// The way into the app.
///
/// Sign in with Apple is the only route: there is no email/password form and no
/// separate register flow. Apple reports whether this is a first authorization
/// and the backend creates the account on demand, keyed on Apple's stable `sub`
/// (see `convex/auth.ts`).
@Reducer
public struct AuthFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var isSigningIn = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    public enum Action: Equatable {
        /// The Apple button completed successfully.
        case appleSignInSucceeded(AppleCredential)
        /// The Apple button failed or the user backed out.
        case appleSignInFailed(AppError)
        case signInSucceeded
        case signInFailed(AppError)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.auth) var auth

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .appleSignInSucceeded(credential):
                state.isSigningIn = true
                return .run { send in
                    try await auth.signInWithApple(credential)
                    await send(.signInSucceeded)
                } catch: { error, send in
                    await send(.signInFailed(AppError(error)))
                }

            case let .appleSignInFailed(error):
                state.isSigningIn = false
                // Backing out of the Apple sheet is not a failure worth an alert.
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .signInSucceeded:
                state.isSigningIn = false
                // The root reducer is watching auth state; it swaps the screen.
                return .none

            case let .signInFailed(error):
                state.isSigningIn = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
