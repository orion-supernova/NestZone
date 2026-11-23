import ComposableArchitecture
import Foundation

/// Keeps the person's own calendars in step with the house's, for as long as
/// the tab bar is up.
///
/// App-wide on purpose, like the dock: the Calendar screen being closed (or
/// never opened) must not stop copies following the house. It subscribes to
/// the house's events for the next four months, hands them to
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
        /// When `occurrences` arrived, and the events of the answer before it
        /// when that was whole: how the engine tells a deletion it watched from
        /// a doubt (see `MirrorRequest`).
        var answeredAt: Date = .distantPast
        var previousEventIDs: Set<String>?
        /// What the read in flight was started for. The read is restarted only
        /// when one of these changes: not on every foreground.
        var following: Following?

        struct Following: Equatable {
            var homeID: HomeID
            /// The day the window starts on, so a new day slides it.
            var day: Date
            var wantsAll: Bool
            var hasAccess: Bool
        }

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
    /// copy is made when the window gets there. Four months, not six: the
    /// server stops an answer at 800 occurrences, and a shorter window is a
    /// busy house reaching that later (`MirrorRequest.answerLimit`).
    static let horizon: TimeInterval = 120 * 86_400

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
                    start(&state, restart: true),
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

            case .settingsChanged:
                // A setting, a person, Plus: the read is the same read, and
                // what changed is what is made of it.
                return start(&state, restart: false)

            case .becameActive:
                return start(&state, restart: false, resync: false)

            case .overridesChanged:
                // With copying off, a first pin is what makes the read worth
                // opening at all.
                return start(&state, restart: state.mode == .off)

            case let .occurrencesUpdated(occurrences, window):
                state.previousEventIDs = state.window != nil && state.occurrences.count < MirrorRequest.answerLimit
                    ? Set(state.occurrences.map(\.eventID.rawValue))
                    : nil
                state.answeredAt = now
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
                    now: now,
                    answeredAt: state.answeredAt,
                    previousEventIDs: state.previousEventIDs
                )
                return .run { send in
                    let summary = try await calendarMirror.sync(request, deviceCalendar)
                    await send(.synced(summary))
                } catch: { _, _ in }

            case let .synced(summary):
                // A request folded into a pass already running, or one that
                // stood down, is not a sync "Last synced" should claim.
                guard summary.didSync else { return .none }
                state.$lastSynced.withLock { $0 = now.timeIntervalSince1970 }
                return .none
            }
        }
    }

    /// Starts the read of the house's events, or stops it when there is nothing
    /// to copy or no Plus, and says when it is already doing what is wanted.
    ///
    /// A read already open for the same house, day, mode and access is left
    /// alone: restarting it on every foreground threw away the whole window and
    /// downloaded it again for nothing. What a setting changed is carried out
    /// by syncing the answer already in hand (`resync`).
    private func start(_ state: inout State, restart: Bool, resync: Bool = true) -> Effect<Action> {
        let homeID = state.homeID
        let mode = state.mode
        let isPro = state.pro.isLoaded && state.pro.isPro
        guard isPro else {
            state.following = nil
            return .cancel(id: CancelID.events)
        }

        let from = Calendar.current.startOfDay(for: now).addingTimeInterval(-86_400)
        let window = from...from.addingTimeInterval(Self.horizon)
        let following = State.Following(
            homeID: homeID,
            day: from,
            wantsAll: mode != .off,
            hasAccess: deviceCalendar.access() == .granted
        )
        if !restart, state.following == following {
            return resync && state.window != nil ? .send(.syncDue) : .none
        }
        state.following = following

        guard following.hasAccess else { return .cancel(id: CancelID.events) }
        return .run { send in
            let wanted = mode != .off
            guard wanted else {
                guard await calendarMirror.hasOverrides(homeID) else { return }
                await follow(homeID, window, send)
                return
            }
            await follow(homeID, window, send)
        }
        .cancellable(id: CancelID.events, cancelInFlight: true)
    }

    private func follow(
        _ homeID: HomeID,
        _ window: ClosedRange<Date>,
        _ send: Send<Action>
    ) async {
        await Backoff.retrying(clock: clock) { delivered in
            for try await occurrences in events.inRange(homeID, window.lowerBound, window.upperBound) {
                delivered()
                await send(.occurrencesUpdated(occurrences, window: window))
            }
        }
    }
}
