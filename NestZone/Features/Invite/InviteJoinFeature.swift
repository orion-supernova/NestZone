import ComposableArchitecture
import Foundation

/// "Join <House>?": what an opened invite link asks. Live, so a code used up
/// or revoked while the card is open says so at once.
///
/// It never switches houses itself. A join, or a link to a house the person is
/// already in, is said to the root, which moves to that house the way every
/// other switch does.
@Reducer
public struct InviteJoinFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public let token: String
        public var preview: InvitePreview?
        public var isJoining = false
        public var didJoin = false
        /// The preview could not be read (offline, a failed subscription).
        public var loadError: String?
        public var inlineError: String?
        /// The person's own tap, for the haptic.
        public var joinTaps = 0

        public init(token: String) { self.token = token }
    }

    public enum Action: Equatable {
        case task
        case previewUpdated(InvitePreview)
        case previewFailed(AppError)
        case joinTapped
        case joined(InviteRedeemed)
        case joinFailed(AppError)
        case notNowTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Joined, or already in: go to this house.
            case joined(HomeID, already: Bool)
            /// A second house needs Plus: the root shows the paywall.
            case proRequired
            case dismissed
        }
    }

    private enum CancelID { case preview }

    @Dependency(\.invite) var invite
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.loadError = nil
                return .run { [token = state.token] send in
                    for try await preview in invite.preview(token) {
                        await send(.previewUpdated(preview))
                    }
                } catch: { error, send in
                    await send(.previewFailed(AppError(error)))
                }
                .cancellable(id: CancelID.preview, cancelInFlight: true)

            case let .previewUpdated(preview):
                state.loadError = nil
                // While the redeem is in flight the live answer turns into
                // "already a member": acting on it would end the card (and
                // the redeem with it) before the root knew this was a join.
                guard !state.didJoin, !state.isJoining else { return .none }
                state.preview = preview
                // Already in: nothing to ask, only to take them there.
                if preview.state == .alreadyMember, let home = preview.homeID {
                    return .send(.delegate(.joined(home, already: true)))
                }
                return .none

            case let .previewFailed(error):
                guard !error.isSilent else { return .none }
                state.loadError = error.errorDescription
                return .none

            case .joinTapped:
                guard !state.isJoining, state.preview?.state == .ok else { return .none }
                state.isJoining = true
                state.inlineError = nil
                state.joinTaps += 1
                return .merge(
                    .cancel(id: CancelID.preview),
                    .run { [token = state.token] send in
                        await send(.joined(try await invite.redeem(token)))
                    } catch: { error, send in
                        await send(.joinFailed(AppError(error)))
                    }
                )

            case let .joined(result):
                state.isJoining = false
                state.didJoin = true
                return .merge(
                    .cancel(id: CancelID.preview),
                    // A beat on the success mark, then the house opens.
                    .run { send in
                        try await clock.sleep(for: .milliseconds(650))
                        await send(.delegate(.joined(result.homeID, already: result.already)))
                    }
                )

            case let .joinFailed(error):
                state.isJoining = false
                if case .proRequired = error { return .send(.delegate(.proRequired)) }
                // The live preview was stopped for the redeem; take it up again.
                guard !error.isSilent else { return .send(.task) }
                state.inlineError = error.errorDescription
                return .send(.task)

            case .notNowTapped:
                return .merge(.cancel(id: CancelID.preview), .send(.delegate(.dismissed)))

            case .delegate:
                return .none
            }
        }
    }
}
