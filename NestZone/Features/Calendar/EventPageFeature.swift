import ComposableArchitecture
import Foundation

/// One event as a screen of its own, for an event opened from somewhere that is
/// not the calendar — Today, the dock, a bill's row, a problem's visit.
///
/// The same content as the detail sheet (`EventDetailFeature`), pushed on the
/// stack that asked, so Back lands where the person was and not on a month of a
/// calendar nobody opened. Inside Calendar an event is still a sheet over the
/// grid it came from.
///
/// It owns what the calendar owns for a sheet: finding the event (an id and a
/// day is enough), the household for the roster, the composer for an edit, and
/// the delete.
@Reducer
public struct EventPageFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        /// Which day's occurrence of a repeating series was asked for.
        public var day: CalendarDay
        /// Held until the window delivers the event, as `CalendarFeature`
        /// does for the same caller.
        public var pendingOpenID: EventID?
        public var detail: EventDetailFeature.State?
        public var members: IdentifiedArrayOf<User> = []
        /// The window answered and the event was not in it: deleted, or moved
        /// away from the day it was asked for.
        public var isGone = false
        @Presents public var compose: EventComposerFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        /// Opened by id, from somewhere that only knows which event.
        public init(homeID: HomeID, currentUserID: UserID?, day: CalendarDay, openingEventID: EventID) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.day = day
            self.pendingOpenID = openingEventID
        }

        /// Opened at an occurrence already in hand, which can be drawn before
        /// anything has loaded.
        public init(homeID: HomeID, currentUserID: UserID?, occurrence: EventOccurrence) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.day = CalendarDay(occurrence.start)
            self.detail = EventDetailFeature.State(
                occurrence: occurrence,
                members: [],
                currentUserID: currentUserID
            )
        }
    }

    public enum Action {
        case task
        case occurrencesUpdated([EventOccurrence])
        case membersUpdated([User])
        case loadFailed(AppError)
        case deleteFailed(AppError)
        case detail(EventDetailFeature.Action)
        case compose(PresentationAction<EventComposerFeature.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case events, members }

    @Dependency(\.events) var events
    @Dependency(\.homes) var homes
    @Dependency(\.paywall) var paywall
    @Dependency(\.dismiss) var dismiss
    @Shared(.pro) var pro: ProStatus

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                // The day either side: enough for the occurrence asked for, and
                // for an edit that moves it a little, without reading a month.
                let calendar = Calendar.current
                let day = state.day.date(calendar)
                let from = calendar.date(byAdding: .day, value: -1, to: day) ?? day
                let to = calendar.date(byAdding: .day, value: 2, to: day) ?? day
                return .merge(
                    .run { send in
                        for try await occurrences in events.inRange(homeID, from, to) {
                            await send(.occurrencesUpdated(occurrences))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.events, cancelInFlight: true),
                    .run { send in
                        for try await members in homes.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                    .cancellable(id: CancelID.members, cancelInFlight: true)
                )

            case let .occurrencesUpdated(incoming):
                if let wanted = state.pendingOpenID {
                    state.pendingOpenID = nil
                    let onDay = incoming.filter { CalendarDay($0.start) == state.day }
                    if let occurrence = onDay.first(where: { $0.eventID == wanted })
                        ?? incoming.first(where: { $0.eventID == wanted }) {
                        state.detail = EventDetailFeature.State(
                            occurrence: occurrence,
                            members: state.members,
                            currentUserID: state.currentUserID
                        )
                    } else {
                        state.isGone = true
                    }
                    return .none
                }
                // Already open: an edit, from here or from another phone,
                // reaches the page the way it reaches the grid.
                guard let current = state.detail?.occurrence else { return .none }
                if let fresh = incoming.first(where: { $0.id == current.id })
                    ?? incoming.first(where: { $0.eventID == current.eventID }),
                   fresh != current {
                    state.detail?.occurrence = fresh
                }
                return .none

            case let .membersUpdated(users):
                let incoming = IdentifiedArray(uniqueElements: users)
                guard incoming != state.members else { return .none }
                state.members = incoming
                state.detail?.members = incoming
                state.compose?.members = incoming
                return .none

            case let .loadFailed(error):
                guard state.detail == nil else { return .none }
                state.isGone = true
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .deleteFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // The detail asks; this decides. Editing writes, so a house
            // without Plus gets the paywall; deleting stays free, like the
            // server's `remove`.
            case let .detail(.delegate(.edit(occurrence, scope))):
                return edit(&state, occurrence, scope)

            case let .detail(.delegate(.deleted(occurrence, scope))),
                 let .compose(.presented(.delegate(.deleted(occurrence, scope)))):
                state.compose = nil
                let start = scope == .occurrence ? occurrence.start : nil
                return .run { send in
                    try await events.remove(occurrence.eventID, scope, start)
                    await dismiss()
                } catch: { error, send in
                    await send(.deleteFailed(AppError(error)))
                }

            case .compose(.presented(.delegate(.saved))):
                state.compose = nil
                return .none

            case .detail, .compose, .alert:
                return .none
            }
        }
        .ifLet(\.detail, action: \.detail) { EventDetailFeature() }
        .ifLet(\.$compose, action: \.compose) { EventComposerFeature() }
        .ifLet(\.$alert, action: \.alert)
    }

    private func edit(
        _ state: inout State,
        _ occurrence: EventOccurrence,
        _ scope: EventScope
    ) -> Effect<Action> {
        guard pro.isPro else { return .run { _ in paywall.request(.calendar) } }
        // The last line before the composer: a finished occurrence is a
        // record, and its series is editable only while it carries on.
        guard occurrence.isEditable else { return .none }
        state.compose = EventComposerFeature.State(
            homeID: state.homeID,
            members: state.members,
            currentUserID: state.currentUserID,
            day: CalendarDay(occurrence.start),
            editing: occurrence,
            scope: occurrence.isPast ? .series : scope
        )
        return .none
    }
}

extension EventPageFeature.State {
    /// Two pages are the same when they were opened on the same event, so
    /// asking twice for one leaves one to back out of.
    var eventID: EventID? { detail?.occurrence.eventID ?? pendingOpenID }
}
