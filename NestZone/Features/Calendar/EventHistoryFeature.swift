import ComposableArchitecture
import Foundation

/// What the household has already done, and what it came to.
///
/// The calendar looks forward; this looks back. A finished event is a record —
/// the sheet it opens is the recap, not the planner — and this is where those
/// records live together: a year of them, newest first, with what each cost and
/// the totals across all of them.
///
/// One live subscription (`events:history`). It is live rather than read once
/// because the past is not quite finished with: the receipt for Saturday gets
/// logged on Monday, and the row should move when it does.
@Reducer
public struct EventHistoryFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var members: IdentifiedArrayOf<User>
        public var currentUserID: UserID?

        public var history: EventHistory?
        public var isLoading = true

        @Presents public var detail: EventDetailFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            homeID: HomeID,
            members: IdentifiedArrayOf<User>,
            currentUserID: UserID?
        ) {
            self.homeID = homeID
            self.members = members
            self.currentUserID = currentUserID
        }

        public var rows: [EventHistory.Row] { history?.rows ?? [] }
    }

    public enum Action {
        case task
        case historyUpdated(EventHistory)
        case historyFailed(AppError)
        case rowTapped(EventID)
        case detail(PresentationAction<EventDetailFeature.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        /// Edits and deletes belong to the calendar, which owns the composer and
        /// the undo window. Handed up rather than re-implemented here.
        public enum Delegate: Equatable {
            case edit(EventOccurrence, EventScope)
            case deleted(EventOccurrence, EventScope)
        }
    }

    /// A year. Long enough to cover last summer's party, short enough that
    /// the totals mean "lately" rather than "ever".
    static let window = 365

    private enum CancelID { case history }

    @Dependency(\.events) var events

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .run { send in
                    for try await history in events.history(homeID, Self.window) {
                        await send(.historyUpdated(history))
                    }
                } catch: { error, send in
                    await send(.historyFailed(AppError(error)))
                }
                .cancellable(id: CancelID.history, cancelInFlight: true)

            case let .historyUpdated(history):
                state.isLoading = false
                guard history != state.history else { return .none }
                state.history = history
                return .none

            case let .historyFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .rowTapped(id):
                guard let row = state.rows.first(where: { $0.id == id }) else { return .none }
                state.detail = EventDetailFeature.State(
                    occurrence: row.occurrence,
                    members: state.members,
                    currentUserID: state.currentUserID
                )
                return .none

            case let .detail(.presented(.delegate(.edit(occurrence, scope)))):
                state.detail = nil
                return .send(.delegate(.edit(occurrence, scope)))

            case let .detail(.presented(.delegate(.deleted(occurrence, scope)))):
                state.detail = nil
                return .send(.delegate(.deleted(occurrence, scope)))

            case .detail, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) { EventDetailFeature() }
        .ifLet(\.$alert, action: \.alert)
    }
}
