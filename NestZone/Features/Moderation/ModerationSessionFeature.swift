import ComposableArchitecture
import Foundation

extension SharedKey where Self == InMemoryKey<[BlockedPerson]>.Default {
    /// Everybody this person has blocked, live. Reset on sign-out.
    public static var blockedPeople: Self {
        Self[.inMemory("blockedPeople"), default: []]
    }
}

/// What this person has reported and blocked, for the life of the tab bar.
///
/// Two subscriptions, written where the screens that need them read: reported
/// photos and faces go to `ModerationDirectory` (which `Avatar` and the
/// problem photos read), and the people blocked go to the shared
/// `.blockedPeople` key (which a chat's menu and Settings read). Messages that
/// were reported or sent by somebody blocked are left out by the server on its
/// own, so they are not listed here.
@Reducer
public struct ModerationSessionFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var userID: UserID?
        @Shared(.blockedPeople) public var blocked: [BlockedPerson]

        public init(homeID: HomeID, userID: UserID?) {
            self.homeID = homeID
            self.userID = userID
        }
    }

    public enum Action: Equatable {
        case task
        case blockedUpdated([BlockedPerson])
    }

    private enum CancelID { case hidden, blocked }

    @Dependency(\.moderation) var moderation

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { [homeID = state.homeID, userID = state.userID] _ in
                        await ModerationDirectory.shared.setSession(userID: userID, homeID: homeID)
                        for try await items in moderation.hidden() {
                            await ModerationDirectory.shared.record(items)
                        }
                    } catch: { _, _ in
                        // A hide that cannot load is a photo that shows again,
                        // not a reason to interrupt anything: the server
                        // refuses nothing here, and `subscribe` re-opens it.
                    }
                    .cancellable(id: CancelID.hidden, cancelInFlight: true),

                    .run { send in
                        for try await people in moderation.blocked() {
                            await send(.blockedUpdated(people))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.blocked, cancelInFlight: true)
                )

            case let .blockedUpdated(people):
                state.$blocked.withLock { $0 = people }
                return .none
            }
        }
    }
}
