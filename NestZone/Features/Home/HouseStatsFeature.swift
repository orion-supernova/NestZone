import ComposableArchitecture
import Foundation

/// House → At a glance: the six counters, on a screen of their own.
///
/// Where every counter lives, whatever this person set Today to show. The
/// same two reads Today uses — `stats:forHome` and the capped agenda — so the
/// numbers here and there are the same numbers.
@Reducer
public struct HouseStatsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var stats: HomeStats = .empty
        public var upcoming: [EventOccurrence] = []
        public var statsLoaded = false
        public var eventsLoaded = false

        public init(homeID: HomeID) {
            self.homeID = homeID
        }

        /// Events in the next seven days, counted the way Today counts them.
        public var eventsThisWeek: Int {
            let horizon = Date().addingTimeInterval(7 * 24 * 3600)
            return upcoming.count { $0.start <= horizon }
        }
    }

    public enum Action: Equatable {
        case task
        case statsUpdated(HomeStats)
        case upcomingUpdated([EventOccurrence])
        case tileTapped(HouseStatTile)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case open(HubModule)
            case openMessages
        }
    }

    private enum CancelID { case stats, events }

    @Dependency(\.stats) var statsClient
    @Dependency(\.events) var eventsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .merge(
                    .run { send in
                        for try await stats in statsClient.forHome(homeID) {
                            await send(.statsUpdated(stats))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.stats, cancelInFlight: true),
                    .run { send in
                        for try await events in eventsClient.upcoming(homeID, 20) {
                            await send(.upcomingUpdated(events))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.events, cancelInFlight: true)
                )

            case let .statsUpdated(stats):
                state.stats = stats
                state.statsLoaded = true
                return .none

            case let .upcomingUpdated(events):
                state.upcoming = events
                state.eventsLoaded = true
                return .none

            case let .tileTapped(tile):
                switch tile {
                case .tasks: return .send(.delegate(.open(.tasks)))
                case .shopping: return .send(.delegate(.open(.shopping)))
                case .notes: return .send(.delegate(.open(.notes)))
                case .issues: return .send(.delegate(.open(.maintenance)))
                case .events: return .send(.delegate(.open(.calendar)))
                case .messages: return .send(.delegate(.openMessages))
                }

            case .delegate:
                return .none
            }
        }
    }
}
