import ComposableArchitecture
import Foundation
import SwiftUI

/// Calendar & Events: what the household is doing, and what has to be ready
/// before it does it.
///
/// Three views of one window — a month grid, a week timeline, an agenda — and a
/// single subscription behind all of them. The server expands every recurring
/// series into concrete occurrences for exactly the range on screen, so this
/// reducer never does recurrence arithmetic and never holds an event it is not
/// showing. Stepping a month replaces the subscription rather than filtering a
/// larger one; that is what keeps a phone's copy of the calendar the size of
/// what is visible rather than the size of the household's history.
///
/// The other half of the feature is the *plan*. An event links out to money,
/// shopping and recipes — see `EventDetailFeature`, which owns that screen and
/// its own rollup subscription.
@Reducer
public struct CalendarFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, so "just mine" means something and an RSVP knows
        /// whose it is.
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User> = []

        public var mode: Mode = .month
        /// The month the scrubber is on. Drives the subscription window in
        /// every mode, so the same control means the same thing everywhere.
        public var month: CalendarMonth = .current
        public var selectedDay: CalendarDay = .today

        /// Everything in the window, as the server expanded it.
        public var occurrences: IdentifiedArrayOf<EventOccurrence> = []

        /// Which occurrences fall on which day, precomputed.
        ///
        /// Rebuilt when the events or the filters change — a tap, a few times a
        /// visit — rather than derived in a computed property. A month grid asks
        /// this question 42 times per layout pass and a computed
        /// `Dictionary(grouping:)` would rebuild the whole month for each of
        /// them, on every frame of the scroll. Ids rather than values, so a
        /// five-day trip is one struct and five string references instead of
        /// five copies.
        public var dayIndex: [CalendarDay: [EventOccurrence.ID]] = [:]

        public var isLoading = true
        /// Filters. Not persisted: narrowing a calendar is a "show me this now",
        /// not a preference to be remembered next week.
        public var search = ""
        public var kindFilter: EventKind?
        /// Only what involves the viewer — they are expected, they answered, or
        /// they wrote it.
        public var onlyMine = false

        /// Swiped away, but not yet sent. Already gone from `occurrences`; if
        /// the undo window closes without a tap, this is what gets deleted for
        /// real. One at a time — a second swipe commits the first, the way the
        /// ledger and the shopping list do.
        public var pendingDeletion: PendingDelete?
        /// Occurrences this screen is pretending are gone while a delete sits
        /// out its undo window. The server still has them, so without this mask
        /// every live push would put them straight back.
        public var hidden: Set<EventOccurrence.ID> = []
        /// Series whose RSVP is still in flight, so a second tap cannot race the
        /// first.
        public var rsvpInFlight: Set<EventID> = []

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        /// An event to open as soon as the window delivers it.
        ///
        /// For the callers that hold an id but not an occurrence — the meal plan
        /// the Home tab shows knows which party it belongs to and nothing else,
        /// and a notification will be the same shape. Cleared the moment it is
        /// used, and dropped if the window turns out not to contain it, so it
        /// cannot fire later against a month somebody has scrubbed to.
        public var pendingOpenID: EventID?

        public init(
            homeID: HomeID,
            currentUserID: UserID? = nil,
            day: CalendarDay = .today,
            showing: EventOccurrence? = nil,
            openingEventID: EventID? = nil
        ) {
            self.pendingOpenID = openingEventID
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.selectedDay = showing.map { CalendarDay($0.start) } ?? day
            self.month = selectedDay.month_

            // Opened *at* an event — from the Home tab's "up next", or a
            // notification. Landing on the right day is not the same as opening
            // the thing that was tapped, and stopping at the day means the tap
            // has to be repeated on a grid the person is not looking for.
            //
            // The sheet carries its own copy of the occurrence, so it can be
            // presented before the window's subscription has delivered anything.
            // `members` arrives later and is written through on every push —
            // see `.membersUpdated`.
            if let showing {
                self.destination = .detail(EventDetailFeature.State(
                    occurrence: showing,
                    members: [],
                    currentUserID: currentUserID
                ))
            }
        }

        /// A delete waiting out its undo window, with everything needed to put
        /// it back if the write is refused.
        public struct PendingDelete: Equatable, Sendable {
            public var occurrence: EventOccurrence
            public var scope: EventScope
        }

        /// The three faces of the screen.
        ///
        /// Not three screens: they are the same window seen at three
        /// resolutions, which is why they share a scrubber, a filter row and a
        /// subscription.
        public enum Mode: String, CaseIterable, Hashable, Sendable, Identifiable {
            case month, week, agenda

            public var id: String { rawValue }

            public var title: LocalizedStringResource {
                switch self {
                case .month: L10n.calendarModeMonth
                case .week: L10n.calendarModeWeek
                case .agenda: L10n.calendarModeAgenda
                }
            }

            public var symbol: String {
                switch self {
                case .month: "calendar"
                case .week: "calendar.day.timeline.left"
                case .agenda: "list.bullet.rectangle.portrait"
                }
            }
        }

        // MARK: Derived

        /// The window this screen is subscribed to.
        ///
        /// Month and week share one — a week is always inside the month grid, so
        /// switching between them costs nothing. The agenda deliberately asks
        /// for more: it is the "what is coming" view, and four months of a
        /// household's events is a smaller payload than one photo.
        public var window: (from: Date, to: Date) {
            State.window(for: month, mode: mode)
        }

        static func window(for month: CalendarMonth, mode: Mode) -> (from: Date, to: Date) {
            let calendar = Calendar.current
            switch mode {
            case .month, .week:
                // The grid shows the days either side that complete its first
                // and last weeks, and they have to carry their dots.
                let grid = MonthGrid(month: month, calendar: calendar)
                return (
                    grid.days.first?.date(calendar) ?? month.date,
                    (grid.days.last?.date(calendar) ?? month.date)
                        .addingTimeInterval(24 * 3600 - 1)
                )
            case .agenda:
                let from = month.date
                let to = calendar.date(byAdding: .month, value: 4, to: from) ?? from
                return (from, to)
            }
        }

        /// A stable name for the window, so a push can be matched to the
        /// subscription that asked for it.
        ///
        /// Without it, the last payload of the month you just scrubbed past
        /// lands on the one you are now looking at — the same trap the Finance
        /// ledger tags its month-scoped pushes to avoid.
        public var windowID: String { "\(mode.rawValue)-\(month.id)" }

        public var visibleWeek: [CalendarDay] {
            MonthGrid.week(containing: selectedDay)
        }

        public var grid: MonthGrid { MonthGrid(month: month) }

        /// Whether anything passes the filters, which is a different question
        /// from whether the household has any events.
        public var isFiltering: Bool {
            kindFilter != nil || onlyMine
                || !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        public func occurrences(on day: CalendarDay) -> [EventOccurrence] {
            (dayIndex[day] ?? []).compactMap { occurrences[id: $0] }
        }

        public func count(on day: CalendarDay) -> Int { dayIndex[day]?.count ?? 0 }

        /// The dots under a day cell: up to three, in the order the events
        /// happen, de-duplicated by colour so a day of four dinners is one
        /// orange dot and not four.
        public func dots(on day: CalendarDay) -> [EventKind] {
            var seen: [EventKind] = []
            for id in dayIndex[day] ?? [] {
                guard let kind = occurrences[id: id]?.kind else { continue }
                if !seen.contains(kind) { seen.append(kind) }
                if seen.count == 3 { break }
            }
            return seen
        }

        /// The agenda: every day in the window that has something on it, in
        /// order, from the selected day forward.
        ///
        /// Forward only. An agenda that opens on the middle of a list has
        /// already lost the argument for being an agenda.
        public var agendaDays: [(day: CalendarDay, items: [EventOccurrence])] {
            dayIndex.keys
                .filter { $0 >= selectedDay }
                .sorted()
                .compactMap { day in
                    let items = occurrences(on: day)
                    return items.isEmpty ? nil : (day, items)
                }
        }

        /// The next thing that has not happened yet, anywhere in the window.
        ///
        /// The one card on the screen that answers "what now" rather than "what
        /// then", so it is deliberately not filtered — hiding the next thing
        /// because somebody typed in the search box would be a good way to miss
        /// it.
        public var nextUp: EventOccurrence? {
            let now = Date()
            return occurrences.first { $0.end >= now }
        }

        /// The kinds actually present in the window, for the filter row.
        /// Offering all nineteen when three are in use is a menu, not a filter.
        public var presentKinds: [EventKind] {
            var seen: [EventKind] = []
            for occurrence in occurrences where !seen.contains(occurrence.kind) {
                seen.append(occurrence.kind)
            }
            return seen.sorted { $0.rawValue < $1.rawValue }
        }

        public func member(_ id: UserID?) -> User? { id.flatMap { members[id: $0] } }

        public func name(for id: UserID?) -> String {
            guard let id else { return String(localized: L10n.calendarSomeone) }
            if id == currentUserID { return String(localized: L10n.financeYou) }
            return members[id: id]?.displayName ?? String(localized: L10n.calendarSomeone)
        }

        /// Whether the household has genuinely never put anything in the
        /// calendar, as opposed to a quiet month in one that uses it constantly.
        ///
        /// Deliberately not `occurrences.isEmpty`: that is only about the window
        /// on screen, so scrubbing to a free August would replace the grid with
        /// "nothing here yet" and then replace it back. And deliberately gated
        /// on having heard from the server at all, so the empty state cannot
        /// flash during a load.
        public var hasLoadedOnce = false
        public var isBlank: Bool { hasLoadedOnce && occurrences.isEmpty && !isFiltering && month.isCurrent }
    }

    @Reducer
    public enum Destination {
        case compose(EventComposerFeature)
        case detail(EventDetailFeature)
    }

    public enum Action: BindableAction {
        case task
        /// Tagged with the window it was asked for. The payload is a bare array
        /// with no range on it, so the subscription has to say — otherwise the
        /// last push from the month you just left lands on the one you are now
        /// looking at.
        case occurrencesUpdated(String, [EventOccurrence])
        case membersUpdated([User])
        case loadFailed(AppError)

        case modeSelected(State.Mode)
        case monthStepped(by: Int)
        case monthSelected(CalendarMonth)
        case daySelected(CalendarDay)
        case todayTapped

        case kindFilterTapped(EventKind?)
        case onlyMineToggled

        case addTapped
        case addOnDayTapped(CalendarDay)
        case eventTapped(EventOccurrence.ID)
        case editTapped(EventOccurrence, EventScope)

        case rsvpTapped(EventOccurrence, RSVPStatus?)
        case rsvpFailed(EventID, [EventRSVP], AppError)

        case deleteTapped(EventOccurrence, EventScope)
        case undoDeleteTapped
        case deleteWindowClosed(EventOccurrence.ID)
        case deleteCommitFailed(State.PendingDelete, AppError)

        case writeFailed(AppError)

        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        /// The only alert this screen raises is a failure. Both destructive
        /// confirmations live next to the thing being destroyed — a swipe is
        /// undoable, and deleting a whole series is confirmed inside the sheet
        /// that offered it.
        public enum Alert: Equatable {}
    }

    private enum CancelID: Hashable { case events, members, undo }

    /// How long a delete stays undoable. The same window the ledger and the
    /// shopping list use, so the gesture means one thing app-wide.
    private static let undoWindow: Duration = .seconds(5)

    @Dependency(\.events) var events
    @Dependency(\.homes) var homes
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .merge(
                    subscribe(state.homeID, state.month, state.mode),
                    .run { send in
                        for try await members in homes.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.members, cancelInFlight: true)
                )

            // MARK: Live pushes

            case let .occurrencesUpdated(windowID, incoming):
                // A payload for a window that has been scrubbed past belongs to
                // a month nobody is looking at.
                guard windowID == state.windowID else { return .none }
                state.isLoading = false
                state.hasLoadedOnce = true
                apply(&state, incoming)

                // Opened by id: resolve it now that the window has arrived. The
                // day picks *which* occurrence of a repeating series, which is
                // why it is not enough to match on the event alone.
                if let wanted = state.pendingOpenID {
                    state.pendingOpenID = nil
                    let onDay = state.occurrences(on: state.selectedDay)
                    if let occurrence = onDay.first(where: { $0.eventID == wanted })
                        ?? state.occurrences.first(where: { $0.eventID == wanted }) {
                        state.destination = .detail(EventDetailFeature.State(
                            occurrence: occurrence,
                            members: state.members,
                            currentUserID: state.currentUserID
                        ))
                    }
                }
                return .none

            case let .membersUpdated(members):
                let incoming = IdentifiedArray(uniqueElements: members)
                guard incoming != state.members else { return .none }
                state.members = incoming
                // Written through to whatever is open, rather than only being
                // read when a sheet is created. A sheet presented before the
                // membership arrived — the deep-open path above — would
                // otherwise show every attendee as "Someone" for as long as it
                // stayed open, and one presented before somebody joined the home
                // would never learn about them.
                // Rebound rather than assigned through: `@Reducer enum` case
                // paths are read-only, so the case has to be rewritten whole.
                switch state.destination {
                case var .detail(detail):
                    detail.members = incoming
                    state.destination = .detail(detail)
                case var .compose(compose):
                    compose.members = incoming
                    state.destination = .compose(compose)
                case .none:
                    break
                }
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // MARK: Moving around

            case let .modeSelected(mode):
                guard mode != state.mode else { return .none }
                let previous = state.mode
                state.mode = mode
                // Month and week share a window, so switching between them must
                // not tear the screen down and put a skeleton up for nothing.
                guard State.window(for: state.month, mode: mode).from
                        != State.window(for: state.month, mode: previous).from
                        || mode == .agenda || previous == .agenda else {
                    return .none
                }
                state.isLoading = true
                return subscribe(state.homeID, state.month, mode)

            case let .monthStepped(by: step):
                return move(&state, to: state.month.advanced(by: step))

            case let .monthSelected(month):
                guard month != state.month else { return .none }
                return move(&state, to: month)

            case let .daySelected(day):
                state.selectedDay = day
                // Tapping into a trailing cell of the grid is a request for that
                // month, not just that day.
                guard day.month_ != state.month else { return .none }
                return move(&state, to: day.month_, keepingDay: day)

            case .todayTapped:
                let today = CalendarDay.today
                state.selectedDay = today
                guard today.month_ != state.month else { return .none }
                return move(&state, to: today.month_, keepingDay: today)

            // MARK: Filters

            case let .kindFilterTapped(kind):
                // Tapping the active chip clears it, so the whole calendar is
                // always one tap away without hunting for an "all" control.
                state.kindFilter = state.kindFilter == kind ? nil : kind
                reindex(&state)
                return .none

            case .onlyMineToggled:
                state.onlyMine.toggle()
                reindex(&state)
                return .none

            // MARK: Events

            case .addTapped:
                return .send(.addOnDayTapped(state.selectedDay))

            case let .addOnDayTapped(day):
                state.destination = .compose(EventComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    day: day
                ))
                return .none

            case let .eventTapped(id):
                guard let occurrence = state.occurrences[id: id] else { return .none }
                state.destination = .detail(EventDetailFeature.State(
                    occurrence: occurrence,
                    members: state.members,
                    currentUserID: state.currentUserID
                ))
                return .none

            case let .editTapped(occurrence, scope):
                state.destination = .compose(EventComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    day: CalendarDay(occurrence.start),
                    editing: occurrence,
                    scope: scope
                ))
                return .none

            // MARK: RSVP
            //
            // Optimistic, and the rollback is real: a refused write changed
            // nothing on the server, so no push is coming to correct the button
            // — this has to put the old answer back itself.
            //
            // An RSVP is per *series*, so every occurrence of it in the window
            // moves together. Updating only the one that was tapped would show
            // a household member as going on Tuesday and undecided on the
            // Tuesday after.

            case let .rsvpTapped(occurrence, status):
                guard let userID = state.currentUserID,
                      !state.rsvpInFlight.contains(occurrence.eventID) else { return .none }
                let eventID = occurrence.eventID
                let previous = occurrence.rsvps
                // Tapping the answer you already gave withdraws it, which is the
                // only way back to "undecided".
                let next: RSVPStatus? = occurrence.rsvp(of: userID) == status ? nil : status

                state.rsvpInFlight.insert(eventID)
                setRSVP(&state, series: eventID, user: userID, status: next)

                return .run { send in
                    try await events.rsvp(eventID, next)
                } catch: { error, send in
                    await send(.rsvpFailed(eventID, previous, AppError(error)))
                }
                .cancellable(id: eventID, cancelInFlight: true)

            case let .rsvpFailed(eventID, previous, error):
                state.rsvpInFlight.remove(eventID)
                restoreRSVPs(&state, series: eventID, to: previous)
                return .send(.writeFailed(error))

            // MARK: Deleting

            case let .deleteTapped(occurrence, scope):
                // The row goes now — waiting for the server reads as a swipe
                // that did not take — but the write is held back until the undo
                // window closes, so undo cancels it rather than reversing it.
                let removed = State.PendingDelete(occurrence: occurrence, scope: scope)
                let superseded = state.pendingDeletion
                hide(&state, occurrence, scope: scope)
                state.pendingDeletion = removed

                return .merge(
                    // A second delete ends the first one's window; that event
                    // was offered back and the offer was not taken.
                    superseded.map { commit($0) } ?? .none,

                    .run { send in
                        try await clock.sleep(for: Self.undoWindow)
                        await send(.deleteWindowClosed(occurrence.id))
                    }
                    .cancellable(id: CancelID.undo, cancelInFlight: true)
                )

            case .undoDeleteTapped:
                guard let pending = state.pendingDeletion else { return .none }
                state.pendingDeletion = nil
                unhide(&state, pending)
                return .cancel(id: CancelID.undo)

            case let .deleteWindowClosed(id):
                guard let pending = state.pendingDeletion,
                      pending.occurrence.id == id else { return .none }
                state.pendingDeletion = nil
                return commit(pending)

            case let .deleteCommitFailed(pending, error):
                // The write never happened, and the mask would otherwise keep
                // hiding rows the server still has — a delete that quietly did
                // not delete, until the screen was reopened.
                unhide(&state, pending)
                return .send(.writeFailed(error))

            // MARK: Sheets reporting back

            // Every save is optimistic in the sense the rest of the app's writes
            // are: the sheet closes and the live subscription brings the row in.
            // Nothing is inserted by hand.
            case .destination(.presented(.compose(.delegate(.saved)))):
                // The id is for callers that have to point something at the new
                // event; this screen's own subscription brings it in.

                state.destination = nil
                return .none

            case let .destination(.presented(.compose(.delegate(.deleted(occurrence, scope))))):
                state.destination = nil
                return .send(.deleteTapped(occurrence, scope))

            case let .destination(.presented(.detail(.delegate(.edit(occurrence, scope))))):
                state.destination = nil
                return .send(.editTapped(occurrence, scope))

            case let .destination(.presented(.detail(.delegate(.deleted(occurrence, scope))))):
                state.destination = nil
                return .send(.deleteTapped(occurrence, scope))

            // The detail sheet owns the RSVP while it is open, and hands the
            // answer back so the grid behind it agrees the moment it closes.
            case let .destination(.presented(.detail(.delegate(.rsvpChanged(eventID, rsvps))))):
                restoreRSVPs(&state, series: eventID, to: rsvps)
                return .none

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding(\.search):
                reindex(&state)
                return .none

            case .binding, .destination, .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - State transitions

    /// Moves the whole screen to another month.
    ///
    /// Changing the month changes the arguments of the query, which means a
    /// different subscription. `cancelInFlight` on a shared id retires the old
    /// one, so a fast scrub cannot leave August's events under September's
    /// heading.
    private func move(
        _ state: inout State,
        to month: CalendarMonth,
        keepingDay day: CalendarDay? = nil
    ) -> Effect<Action> {
        guard month != state.month || day != nil else { return .none }
        state.month = month
        state.isLoading = true
        // The events belong to the month being left. Holding them would draw
        // August's dots under September's grid until the new list arrived; the
        // skeleton covers the gap instead.
        state.occurrences = []
        state.dayIndex = [:]
        // A kind filter carried into a month without that kind would be
        // invisible, and therefore impossible to clear.
        state.kindFilter = nil
        state.selectedDay = day ?? {
            // Landing on a month keeps the day of the month where it makes
            // sense — scrubbing from the 14th to the next month should not
            // silently select the 1st — but the current month always lands on
            // today, which is where anybody scrubbing back means to go.
            month.isCurrent
                ? .today
                : CalendarDay(year: month.year, month: month.month, day: 1)
        }()
        return subscribe(state.homeID, month, state.mode)
    }

    private func subscribe(
        _ homeID: HomeID,
        _ month: CalendarMonth,
        _ mode: State.Mode
    ) -> Effect<Action> {
        let window = State.window(for: month, mode: mode)
        let windowID = "\(mode.rawValue)-\(month.id)"
        return .run { send in
            for try await occurrences in events.inRange(homeID, window.from, window.to) {
                await send(.occurrencesUpdated(windowID, occurrences))
            }
        } catch: { error, send in
            await send(.loadFailed(AppError(error)))
        }
        .cancellable(id: CancelID.events, cancelInFlight: true)
    }

    /// Takes a live push, minus anything a pending delete is hiding.
    private func apply(_ state: inout State, _ incoming: [EventOccurrence]) {
        var array = IdentifiedArray(uniqueElements: incoming)
        // Anything the server has already dropped no longer needs hiding, and
        // keeping the mask would leak it across a re-add.
        let stillHidden = state.hidden.intersection(array.ids)
        if stillHidden != state.hidden { state.hidden = stillHidden }
        for id in stillHidden { array.remove(id: id) }
        guard array != state.occurrences else { return }
        state.occurrences = array
        reindex(&state)
    }

    /// Rebuilds the day buckets from the current events and filters.
    ///
    /// The filters are applied *here* rather than at the call site so the grid,
    /// the week and the agenda are all reading one already-filtered index —
    /// three views filtering the same list three different ways is how they
    /// start disagreeing about which days have dots.
    private func reindex(_ state: inout State) {
        let needle = state.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = state.kindFilter
        let onlyMine = state.onlyMine
        let me = state.currentUserID
        let calendar = Calendar.current

        var index: [CalendarDay: [EventOccurrence.ID]] = [:]
        // The server sends them in order, so appending keeps each day's list
        // sorted without a second pass.
        for occurrence in state.occurrences {
            if let kind, occurrence.kind != kind { continue }
            if onlyMine, !occurrence.involves(me) { continue }
            if !needle.isEmpty {
                let matches = occurrence.title.localizedCaseInsensitiveContains(needle)
                    || (occurrence.location?.localizedCaseInsensitiveContains(needle) ?? false)
                    || (occurrence.notes?.localizedCaseInsensitiveContains(needle) ?? false)
                if !matches { continue }
            }
            for day in occurrence.days(calendar) {
                index[day, default: []].append(occurrence.id)
            }
        }
        state.dayIndex = index
    }

    /// Applies one member's answer across every occurrence of a series.
    private func setRSVP(
        _ state: inout State,
        series: EventID,
        user: UserID,
        status: RSVPStatus?
    ) {
        for id in state.occurrences.ids where state.occurrences[id: id]?.eventID == series {
            var rsvps = state.occurrences[id: id]?.rsvps ?? []
            rsvps.removeAll { $0.userID == user }
            if let status { rsvps.append(EventRSVP(userID: user, status: status)) }
            state.occurrences[id: id]?.rsvps = rsvps
        }
    }

    private func restoreRSVPs(_ state: inout State, series: EventID, to rsvps: [EventRSVP]) {
        for id in state.occurrences.ids where state.occurrences[id: id]?.eventID == series {
            state.occurrences[id: id]?.rsvps = rsvps
        }
    }

    /// Takes an occurrence — or a whole series — off the screen, ahead of the
    /// write that will make it true.
    private func hide(_ state: inout State, _ occurrence: EventOccurrence, scope: EventScope) {
        switch scope {
        case .occurrence:
            state.hidden.insert(occurrence.id)
            state.occurrences.remove(id: occurrence.id)
        case .series:
            // Deleting "every Tuesday" has to clear every Tuesday on screen, not
            // just the one that was swiped.
            let doomed = state.occurrences
                .filter { $0.eventID == occurrence.eventID }
                .map(\.id)
            for id in doomed {
                state.hidden.insert(id)
                state.occurrences.remove(id: id)
            }
        }
        reindex(&state)
    }

    private func unhide(_ state: inout State, _ pending: State.PendingDelete) {
        // Nothing was ever sent, so the live subscription still holds these and
        // will agree. Restoring them here is only about the frames between now
        // and the next push.
        switch pending.scope {
        case .occurrence:
            state.hidden.remove(pending.occurrence.id)
            state.occurrences.append(pending.occurrence)
        case .series:
            let series = pending.occurrence.eventID
            let restored = state.hidden.filter { $0.hasPrefix("\(series.rawValue):") }
            state.hidden.subtract(restored)
            if state.occurrences[id: pending.occurrence.id] == nil {
                state.occurrences.append(pending.occurrence)
            }
        }
        state.occurrences.sort { $0.startsAt < $1.startsAt }
        reindex(&state)
    }

    /// The write the swipe was always going to make, once nobody has undone it.
    private func commit(_ pending: State.PendingDelete) -> Effect<Action> {
        let start = pending.scope == .occurrence ? pending.occurrence.start : nil
        return .run { _ in
            try await events.remove(pending.occurrence.eventID, pending.scope, start)
        } catch: { error, send in
            await send(.deleteCommitFailed(pending, AppError(error)))
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly; declared
// here rather than via the deprecated `@Reducer(state:)` argument.
extension CalendarFeature.Destination.State: Equatable {}
