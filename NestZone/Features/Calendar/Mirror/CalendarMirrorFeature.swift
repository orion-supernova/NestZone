import ComposableArchitecture
import Foundation

/// Keeps the person's own calendars in step with the house's, for as long as
/// the tab bar is up.
///
/// App-wide on purpose, like the dock: the Calendar screen being closed (or
/// never opened) must not stop copies following the house. It subscribes to
/// the house's events for the next half year, hands them to
/// `CalendarMirrorClient`, and syncs again when the house changes, when the
/// phone's calendar database changes, when the app comes back to the
/// foreground and when a setting moves. A phone only syncs while NestZone runs,
/// and Settings says so ("Last synced").
///
/// It runs only when there is something for it to do — copying is on, or an
/// event was pinned from the composer — and only for a house with Plus. A house
/// that loses Plus stops creating and updating copies; the ones that exist are
/// left where they are.
@Reducer
public struct CalendarMirrorFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var userID: UserID?
        /// What the house has in the window, as of the last push.
        public var occurrences: [EventOccurrence] = []
        public var window: ClosedRange<Date>?

        @Shared(.calendarCopyMode) var mode: CalendarCopyMode
        @Shared(.calendarCopyTargetsRaw) var targetsRaw: String
        @Shared(.calendarCopyReminders) var copyReminders: Bool
        @Shared(.calendarLastSynced) var lastSynced: Double
        @Shared(.pro) var pro: ProStatus

        public init(homeID: HomeID, userID: UserID?) {
            self.homeID = homeID
            self.userID = userID
        }
    }

    public enum Action {
        case task
        /// A setting, Plus or the person's choice of calendars moved.
        case settingsChanged
        /// The app came back to the foreground: the window slides forward.
        case becameActive
        case occurrencesUpdated([EventOccurrence], window: ClosedRange<Date>)
        case calendarStoreChanged
        case overridesChanged
        case syncDue
        case synced(MirrorSummary)
    }

    private enum CancelID { case events, store, overrides, sync }

    /// How far ahead the copies reach. Past it nothing is copied yet, and a
    /// copy is made when the window gets there.
    static let horizon: TimeInterval = 180 * 86_400

    @Dependency(\.events) var events
    @Dependency(\.deviceCalendar) var deviceCalendar
    @Dependency(\.calendarMirror) var calendarMirror
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    start(state),
                    // The phone's own calendar database, which the person edits
                    // in other apps: a copy they deleted is found here.
                    .run { send in
                        for await _ in deviceCalendar.changes() { await send(.calendarStoreChanged) }
                    }
                    .cancellable(id: CancelID.store, cancelInFlight: true),
                    .run { send in
                        for await _ in calendarMirror.overridesChanged() { await send(.overridesChanged) }
                    }
                    .cancellable(id: CancelID.overrides, cancelInFlight: true)
                )

            case .settingsChanged, .becameActive, .overridesChanged:
                return start(state)

            case let .occurrencesUpdated(occurrences, window):
                state.occurrences = occurrences
                state.window = window
                return .send(.syncDue)

            case .calendarStoreChanged:
                guard state.window != nil else { return .none }
                // A burst of changes (ours included) is one sync, a second later.
                return .run { send in
                    try await clock.sleep(for: .seconds(1))
                    await send(.syncDue)
                }
                .cancellable(id: CancelID.sync, cancelInFlight: true)

            case .syncDue:
                guard state.pro.isLoaded, state.pro.isPro, let window = state.window else { return .none }
                let request = MirrorRequest(
                    homeID: state.homeID,
                    userID: state.userID,
                    mode: state.mode,
                    targets: CalendarLists.calendars(state.targetsRaw),
                    copyReminders: state.copyReminders,
                    occurrences: state.occurrences,
                    windowStart: window.lowerBound,
                    windowEnd: window.upperBound,
                    now: now
                )
                return .run { send in
                    let summary = try await calendarMirror.sync(request, deviceCalendar)
                    await send(.synced(summary))
                } catch: { _, _ in }

            case .synced:
                state.$lastSynced.withLock { $0 = now.timeIntervalSince1970 }
                return .none
            }
        }
    }

    /// (Re)starts the read of the house's events, or stops it when there is
    /// nothing to copy or no Plus. A fresh read each time so the window starts
    /// today and not on the day the app was launched.
    private func start(_ state: State) -> Effect<Action> {
        let homeID = state.homeID
        let mode = state.mode
        let isPro = state.pro.isLoaded && state.pro.isPro
        let from = Calendar.current.startOfDay(for: now).addingTimeInterval(-86_400)
        let window = from...from.addingTimeInterval(Self.horizon)

        guard isPro else { return .cancel(id: CancelID.events) }
        return .run { send in
            guard deviceCalendar.access() == .granted else { return }
            let wanted = mode != .off
            guard wanted else {
                guard await calendarMirror.hasOverrides(homeID) else { return }
                try await follow(homeID, window, send)
                return
            }
            try await follow(homeID, window, send)
        } catch: { _, _ in }
        .cancellable(id: CancelID.events, cancelInFlight: true)
    }

    private func follow(
        _ homeID: HomeID,
        _ window: ClosedRange<Date>,
        _ send: Send<Action>
    ) async throws {
        for try await occurrences in events.inRange(homeID, window.lowerBound, window.upperBound) {
            await send(.occurrencesUpdated(occurrences, window: window))
        }
    }
}
