import ComposableArchitecture
import Foundation

/// Everybody this person has blocked, with a way to undo each.
///
/// The list is the shared `.blockedPeople` key, which the tab bar keeps live
/// (`ModerationSessionFeature`), so there is nothing to load here and the list
/// follows a block made from a chat the moment it is made.
@Reducer
public struct BlockedPeopleFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        @Shared(.blockedPeople) public var people: [BlockedPerson]
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    public enum Action {
        case unblockTapped(BlockedPerson)
        /// Carries the person and where they stood, so a refused write can put
        /// them back: nothing changed on the server, so no push is coming.
        case unblockFailed(BlockedPerson, at: Int, AppError)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.moderation) var moderation

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .unblockTapped(person):
                guard let index = state.people.firstIndex(where: { $0.id == person.id }) else {
                    return .none
                }
                state.$people.withLock { _ = $0.remove(at: index) }
                return .run { _ in
                    try await moderation.unblock(person.id)
                } catch: { error, send in
                    await send(.unblockFailed(person, at: index, AppError(error)))
                }

            case let .unblockFailed(person, index, error):
                state.$people.withLock { people in
                    guard !people.contains(where: { $0.id == person.id }) else { return }
                    people.insert(person, at: min(index, people.count))
                }
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
