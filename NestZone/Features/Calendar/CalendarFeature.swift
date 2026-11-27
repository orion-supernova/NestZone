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
        /// What this phone shares with this house, for the quiet nudge at the
        /// top while nothing is.
        @Shared(.calendarShareChoicesRaw) public var shareChoicesRaw: String
        /// The phone's answer to "may NestZone read your calendars", read when
        /// the screen opens.
        public var deviceAccess: DeviceCalendarAccess = .notDetermined

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

        /// Housemates' own calendars in the window, as they chose to share them.
        /// Not events: nothing in this feature edits, answers, plans or counts
        /// them, and nothing outside the Calendar screen reads them.
        public var shared: IdentifiedArrayOf<SharedBusyItem> = []
        /// Reported in this session, ahead of the server's own read dropping
        /// them. Keyed by row id; the server hides by what the item is, so a
        /// sync that replaces the rows cannot bring one back.
        public var sharedHidden: Set<String> = []
        /// The shared items on each day, after the filters, like `dayIndex`.
        public var sharedDayIndex: [CalendarDay: [String]] = [:]
        /// Whether housemates' calendars are drawn at all. The quick switch in
        /// the bar; lasting, per-person choices are `hiddenSharersRaw`, and an
        /// item is drawn only when both allow it.
        @Shared(.calendarShowShared) public var showShared: Bool
        /// Housemates this person switched off in Settings → Calendar, per
        /// house. Read it as `hiddenSharers`.
        @Shared(.calendarHiddenSharersRaw) public var hiddenSharersRaw: String
        /// Housemates who share a calendar with the house, once known.
        public var sharers: Set<UserID>?
        /// Whether this person shares one of their own, once known: their own
        /// items come back in the same read, and are never hidden.
        public var sharesOwn: Bool?
        /// Whether the read of shared items is running.
        public var isFetchingShared = true

        public var isLoading = true
        /// Filters. Not persisted, bar the people: narrowing a calendar by kind
        /// or search is a "show me this now", not a preference to be remembered
        /// next week, but whose calendar a person looks at is one.
        public var search = ""
        public var kindFilter: EventKind?
        /// Who the calendar is narrowed to, as comma-joined ids, kept on this
        /// phone. Empty is Everyone. Read it as `people`.
        @Shared(.calendarPeopleRaw) public var peopleRaw: String
        /// The members the row draws, the viewer first and then by name.
        /// Stored when the members arrive, so `body` sorts nothing.
        public var peopleRow: [User] = []
        /// Events I am invited to and have not answered.
        public var needsAnswer = false
        /// Events with a budget, a menu or a ticket — the ones with work on
        /// them.
        public var withPlan = false

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
            kindFilter != nil || !people.isEmpty || needsAnswer || withPlan
                || !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// How many occurrences survive the filters, out of how many the window
        /// holds.
        ///
        /// Said out loud because a filter that removes nothing and a filter that
        /// is broken look identical otherwise: the chip lights up, a few dots
        /// quietly leave the grid, and there is no way to tell "3 of 3" from
        /// "the button does nothing". Several of these filters are frequently
        /// no-ops on real data — an event that names nobody belongs to every
        /// person picked, so in a household that never uses the invite list the
        /// people row excludes nothing.
        public var visibleCount: Int {
            var seen = Set<EventOccurrence.ID>()
            for ids in dayIndex.values { seen.formUnion(ids) }
            return seen.count
        }

        public var totalCount: Int { occurrences.count }

        /// The people the calendar is narrowed to: what was stored, less anyone
        /// who is no longer a member. Until the members have arrived nothing
        /// can be said to have left, so the stored choice stands.
        ///
        /// This is the one place a phase that draws other people's shared
        /// calendars reads the selection from: a shared row belongs to the
        /// person whose calendar it is, and shows for exactly these people.
        public var people: Set<UserID> {
            let stored = Set(CalendarLists.users(peopleRaw, home: homeID))
            return members.isEmpty ? stored : stored.intersection(members.ids)
        }

        /// Whether `occurrence` survives the people filter. Nobody picked is
        /// everyone; otherwise it must concern at least one of them, and an
        /// event that names nobody is the whole house's and concerns all.
        public func passesPeople(_ occurrence: EventOccurrence) -> Bool {
            let people = people
            return people.isEmpty || occurrence.involvesAny(of: people)
        }

        /// Filters are on and they have hidden everything in the window.
        public var isFilteredEmpty: Bool {
            isFiltering && totalCount > 0 && visibleCount == 0
        }

        /// What was typed, trimmed. Empty means nobody is searching.
        public var needle: String {
            search.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var isSearchActive: Bool { !needle.isEmpty }

        /// Every event that survives the filters, across the whole window,
        /// soonest first.
        ///
        /// Searching is a "find it" action, not a "browse this month" one, and
        /// this is what the search box was missing. The needle always reached
        /// `reindex`, so matches were filtered correctly — but in month and week
        /// mode the only list on screen is the *selected day's*. Typing the name
        /// of a party three weeks out therefore emptied the list you were
        /// looking at, changed some dots you were not, and left the match
        /// unreachable without knowing which cell to tap. Which reads, exactly
        /// as reported, as search doing nothing.
        public var matches: [EventOccurrence] {
            var seen = Set<EventOccurrence.ID>()
            var found: [EventOccurrence] = []
            for ids in dayIndex.values {
                for id in ids where seen.insert(id).inserted {
                    if let occurrence = occurrences[id: id] { found.append(occurrence) }
                }
            }
            return found.sorted { $0.start < $1.start }
        }

        public func occurrences(on day: CalendarDay) -> [EventOccurrence] {
            (dayIndex[day] ?? []).compactMap { occurrences[id: $0] }
        }

        public func count(on day: CalendarDay) -> Int { dayIndex[day]?.count ?? 0 }

        public func sharedItems(on day: CalendarDay) -> [SharedBusyItem] {
            (sharedDayIndex[day] ?? []).compactMap { shared[id: $0] }
        }

        public func sharedCount(on day: CalendarDay) -> Int { sharedDayIndex[day]?.count ?? 0 }

        public var hiddenSharers: Set<UserID> { Set(CalendarLists.users(hiddenSharersRaw, home: homeID)) }

        /// Whether there is anybody whose items would be drawn. Until both
        /// answers are in this says yes, so the read starts as it always did;
        /// once they are, a house where every sharer is hidden and the person
        /// shares nothing does not ask the server at all.
        public var wantsShared: Bool {
            guard let sharers, let sharesOwn else { return true }
            return sharesOwn || !sharers.subtracting(hiddenSharers).isEmpty
        }

        /// Every shared item that survives the filters, soonest first.
        public var sharedMatches: [SharedBusyItem] {
            var seen = Set<String>()
            var found: [SharedBusyItem] = []
            for ids in sharedDayIndex.values {
                for id in ids where seen.insert(id).inserted {
                    if let item = shared[id: id] { found.append(item) }
                }
            }
            return found.sorted { $0.startsAt < $1.startsAt }
        }

        /// How many shared items the filters keep. Said beside "x of y", which
        /// is about house events only: a housemate's item is not an event, and
        /// folding it into the count would make "3 of 12" mean two things.
        public var sharedVisibleCount: Int {
            var seen = Set<String>()
            for ids in sharedDayIndex.values { seen.formUnion(ids) }
            return seen.count
        }

        /// Whether the "their own calendars" switch is worth drawing: there is
        /// something for it to hide, or it is off and has to be able to come
        /// back on.
        public var canToggleShared: Bool {
            let hidden = hiddenSharers
            return shared.contains { $0.userID == currentUserID || !hidden.contains($0.userID) } || !showShared
        }

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
        public var agendaDays: [(day: CalendarDay, items: [EventOccurrence], shared: [SharedBusyItem])] {
            Set(dayIndex.keys).union(sharedDayIndex.keys)
                .filter { $0 >= selectedDay }
                .sorted()
                .compactMap { day in
                    let items = occurrences(on: day)
                    let theirs = sharedItems(on: day)
                    return items.isEmpty && theirs.isEmpty ? nil : (day, items, theirs)
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
        ///
        /// And nothing at all when only one kind is in use: a chip that keeps
        /// every event it is shown beside is a control that cannot do anything,
        /// which is the whole reason these read as broken.
        public var presentKinds: [EventKind] {
            var seen: [EventKind] = []
            for occurrence in occurrences where !seen.contains(occurrence.kind) {
                seen.append(occurrence.kind)
            }
            guard seen.count > 1 else { return [] }
            return seen.sorted { $0.rawValue < $1.rawValue }
        }

        // The rule every chip below follows: a filter is offered only when it
        // would change what is on screen. A household where nobody uses the
        // invite list has no "just mine" to draw, and one where nothing is
        // planned has no "has a plan" — and an always-present control that
        // never removes a row is indistinguishable from one that is broken.

        /// Whether there is anyone to pick: a house of one has nobody to
        /// narrow to, and a row of a single "Me" beside "Everyone" cannot
        /// change what is drawn.
        public var canFilterPeople: Bool { peopleRow.count > 1 }

        public func needsMyAnswer(_ occurrence: EventOccurrence) -> Bool {
            guard let me = currentUserID else { return false }
            return occurrence.attendees.contains(me) && occurrence.rsvp(of: me) == nil
        }

        public var canFilterNeedsAnswer: Bool {
            occurrences.contains { needsMyAnswer($0) }
        }

        /// Something has been organised on it: money, a menu or a ticket.
        public func isPlanned(_ occurrence: EventOccurrence) -> Bool {
            occurrence.budget != nil
                || !occurrence.recipeIDs.isEmpty
                || occurrence.url?.isEmpty == false
        }

        public var canFilterPlanned: Bool {
            let planned = occurrences.count { isPlanned($0) }
            return planned > 0 && planned < occurrences.count
        }

        /// Whether the filter row has anything worth drawing. An active filter
        /// always keeps it on screen, or turning one on could hide the control
        /// that turns it off.
        public var showsShareNudge: Bool {
            guard deviceAccess != .denied, deviceAccess != .restricted else { return false }
            let house = CalendarShareChoices.decode(shareChoicesRaw).house(homeID)
            return !house.isOn || !house.levels.values.contains { $0.isShared }
        }

        public var showsFilterRow: Bool {
            isFiltering
                || !presentKinds.isEmpty
                || canFilterPeople
                || canFilterNeedsAnswer
                || canFilterPlanned
                || canToggleShared
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
        /// Whether this house has ever had an event, as far as this screen has
        /// seen: what a house without Plus is told, to decide between the
        /// read-only calendar and the locked one.
        public var sawEvents = false
        public var isBlank: Bool { hasLoadedOnce && occurrences.isEmpty && !isFiltering && month.isCurrent }
    }

    @Reducer
    public enum Destination {
        case compose(EventComposerFeature)
        case detail(EventDetailFeature)
        case history(EventHistoryFeature)
        /// A housemate's own calendar item: read-only, and reportable.
        case sharedItem(SharedItemDetailFeature)
    }

    public enum Action: BindableAction {
        @CasePathable
        public enum Delegate: Equatable {
            /// Settings → Calendar, as a screen on this tab's stack.
            case openSettings
        }

        case task
        /// Tagged with the window it was asked for. The payload is a bare array
        /// with no range on it, so the subscription has to say — otherwise the
        /// last push from the month you just left lands on the one you are now
        /// looking at.
        case occurrencesUpdated(String, [EventOccurrence])
        case sharedUpdated(String, [SharedBusyItem])
        case sharedToggled
        case sharersUpdated([HousemateShare])
        case ownShareUpdated(Bool)
        /// The lasting choice of whose calendars are drawn moved (Settings, or
        /// the sheet): the grid and the read follow it.
        case hiddenSharersChanged
        case sharedItemTapped(String)
        case membersUpdated([User])
        case loadFailed(AppError)
        /// There is something still to come, for a house without Plus.
        case eventsAhead

        case modeSelected(State.Mode)
        case monthStepped(by: Int)
        case monthSelected(CalendarMonth)
        case daySelected(CalendarDay)
        case todayTapped

        case kindFilterTapped(EventKind?)
        /// One person added to or taken out of the people filter.
        case personToggled(UserID)
        /// The Everyone chip: clears the people filter.
        case everyoneTapped
        case needsAnswerToggled
        case withPlanToggled
        /// One control that undoes every filter at once. Clearing them one by
        /// one means knowing which are on, and the kind chip only clears by
        /// finding and tapping the active one again.
        case filtersCleared

        case addTapped
        case historyTapped
        /// The ⋯ menu's "Calendar settings".
        case settingsTapped
        case delegate(Delegate)
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

    private enum CancelID: Hashable { case events, shared, sharers, ownShare, members, undo }

    /// How long a delete stays undoable. The same window the ledger and the
    /// shopping list use, so the gesture means one thing app-wide.
    private static let undoWindow: Duration = .seconds(5)

    @Dependency(\.events) var events
    @Dependency(\.calendarShare) var calendarShare
    @Dependency(\.deviceCalendar) var deviceCalendar
    @Dependency(\.homes) var homes
    @Dependency(\.paywall) var paywall
    @Dependency(\.continuousClock) var clock
    /// The calendar is Plus: a house without it reads what is there and the
    /// controls that write ask for the paywall instead.
    @Shared(.pro) var pro: ProStatus

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            if !pro.isPro, Self.writes(action) {
                return .run { _ in paywall.request(.calendar) }
            }
            switch action {
            case .eventsAhead:
                state.sawEvents = true
                return .none

            case .task:
                let homeID = state.homeID
                state.deviceAccess = deviceCalendar.access()
                // One look ahead for a house without Plus, whose calendar is
                // only drawn read-only when it has something in it.
                let ahead: Effect<Action> = pro.isPro ? .none : .run { send in
                    for try await upcoming in events.upcoming(homeID, 1) {
                        if !upcoming.isEmpty { await send(.eventsAhead) }
                        break
                    }
                } catch: { _, _ in }
                return .merge(
                    ahead,
                    subscribe(state.homeID, state.month, state.mode, shared: state.wantsShared),
                    // Who shares, so the read of their items can be skipped when
                    // nobody left to show does.
                    .run { send in
                        await Backoff.retrying(clock: clock) { delivered in
                            for try await rows in calendarShare.housemates(homeID) {
                                delivered()
                                await send(.sharersUpdated(rows))
                            }
                        }
                    }
                    .cancellable(id: CancelID.sharers, cancelInFlight: true),
                    .run { send in
                        await Backoff.retrying(clock: clock) { delivered in
                            for try await row in calendarShare.mine(homeID) {
                                delivered()
                                await send(.ownShareUpdated(!(row?.calendars.isEmpty ?? true)))
                            }
                        }
                    }
                    .cancellable(id: CancelID.ownShare, cancelInFlight: true),
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
                if !incoming.isEmpty { state.sawEvents = true }
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

            case let .sharedUpdated(windowID, incoming):
                guard windowID == state.windowID else { return .none }
                var array = IdentifiedArray(uniqueElements: incoming)
                let stillHidden = state.sharedHidden.intersection(array.ids)
                if stillHidden != state.sharedHidden { state.sharedHidden = stillHidden }
                for id in stillHidden { array.remove(id: id) }
                guard array != state.shared else { return .none }
                state.shared = array
                reindex(&state)
                return .none

            case .sharedToggled:
                state.$showShared.withLock { $0.toggle() }
                reindex(&state)
                return .none

            case let .sharersUpdated(rows):
                let ids = Set(rows.map(\.userID))
                guard ids != state.sharers else { return .none }
                state.sharers = ids
                return refreshShared(&state)

            case let .ownShareUpdated(isSharing):
                guard isSharing != state.sharesOwn else { return .none }
                state.sharesOwn = isSharing
                return refreshShared(&state)

            case .hiddenSharersChanged:
                reindex(&state)
                return refreshShared(&state)

            case let .sharedItemTapped(id):
                guard let item = state.shared[id: id] else { return .none }
                state.destination = .sharedItem(SharedItemDetailFeature.State(
                    item: item,
                    member: state.member(item.userID),
                    name: state.name(for: item.userID),
                    isMine: item.userID == state.currentUserID
                ))
                return .none

            case let .membersUpdated(members):
                let incoming = IdentifiedArray(uniqueElements: members)
                guard incoming != state.members else { return .none }
                state.members = incoming
                state.peopleRow = Self.peopleRow(incoming, me: state.currentUserID)
                // A member who left drops out of the stored choice, so it
                // cannot keep narrowing the calendar to nobody.
                let homeID = state.homeID
                let kept = Self.ordered(state.people, in: state.peopleRow)
                if kept != CalendarLists.users(state.peopleRaw, home: homeID) {
                    state.$peopleRaw.withLock { $0 = CalendarLists.raw(users: kept, home: homeID, in: $0) }
                }
                reindex(&state)
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
                case var .history(history):
                    history.members = incoming
                    if var detail = history.detail {
                        detail.members = incoming
                        history.detail = detail
                    }
                    state.destination = .history(history)
                case .sharedItem, .none:
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
                state.isFetchingShared = state.wantsShared
                return subscribe(state.homeID, state.month, mode, shared: state.isFetchingShared)

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

            case let .personToggled(id):
                var people = state.people
                if !people.insert(id).inserted { people.remove(id) }
                let homeID = state.homeID
                let ordered = Self.ordered(people, in: state.peopleRow)
                state.$peopleRaw.withLock { $0 = CalendarLists.raw(users: ordered, home: homeID, in: $0) }
                reindex(&state)
                return .none

            case .everyoneTapped:
                let homeID = state.homeID
                guard !CalendarLists.users(state.peopleRaw, home: homeID).isEmpty else { return .none }
                state.$peopleRaw.withLock { $0 = CalendarLists.raw(users: [UserID](), home: homeID, in: $0) }
                reindex(&state)
                return .none

            case .needsAnswerToggled:
                state.needsAnswer.toggle()
                reindex(&state)
                return .none

            case .withPlanToggled:
                state.withPlan.toggle()
                reindex(&state)
                return .none

            case .filtersCleared:
                state.kindFilter = nil
                let homeID = state.homeID
                state.$peopleRaw.withLock { $0 = CalendarLists.raw(users: [UserID](), home: homeID, in: $0) }
                state.needsAnswer = false
                state.withPlan = false
                state.search = ""
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

            case .settingsTapped:
                return .send(.delegate(.openSettings))

            case .delegate:
                return .none

            case .historyTapped:
                state.destination = .history(EventHistoryFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID
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
                // The last line before the composer: a finished occurrence is
                // a record, and its series is editable only while it carries on.
                guard occurrence.isEditable else { return .none }
                let scope: EventScope = occurrence.isPast ? .series : scope
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
                      !occurrence.isPast,
                      !state.rsvpInFlight.contains(occurrence.eventID) else { return .none }
                let eventID = occurrence.eventID
                let previous = occurrence.rsvps
                // Tapping the answer you already gave withdraws it, which is the
                // only way back to "undecided".
                let next: RSVPStatus? = occurrence.rsvp(of: userID) == status ? nil : status

                let start = occurrence.start
                state.rsvpInFlight.insert(eventID)
                setRSVP(&state, series: eventID, user: userID, status: next)

                return .run { send in
                    try await events.rsvp(eventID, next, start)
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

            // Past events hand edits and deletes back here, which owns the
            // composer and the undo window.
            case let .destination(.presented(.history(.delegate(.edit(occurrence, scope))))):
                state.destination = nil
                return .send(.editTapped(occurrence, scope))

            case let .destination(.presented(.history(.delegate(.deleted(occurrence, scope))))):
                state.destination = nil
                return .send(.deleteTapped(occurrence, scope))

            // The detail sheet owns the RSVP while it is open, and hands the
            // answer back so the grid behind it agrees the moment it closes.
            case let .destination(.presented(.detail(.delegate(.rsvpChanged(eventID, rsvps))))):
                restoreRSVPs(&state, series: eventID, to: rsvps)
                return .none

            // A report hides the item at once, whatever the server answered;
            // the sheet says thanks and closes itself.
            case let .destination(.presented(.sharedItem(.delegate(.reported(id))))):
                state.sharedHidden.insert(id)
                state.shared.remove(id: id)
                reindex(&state)
                return .none

            // "Hide this person's calendar": the same choice as the switch in
            // Settings, so one place undoes it. The sheet says so and closes
            // itself.
            case let .destination(.presented(.sharedItem(.delegate(.hideSharer(userID))))):
                guard userID != state.currentUserID else { return .none }
                let homeID = state.homeID
                state.$hiddenSharersRaw.withLock { raw in
                    var hidden = CalendarLists.users(raw, home: homeID)
                    if !hidden.contains(userID) { hidden.append(userID) }
                    raw = CalendarLists.raw(users: hidden, home: homeID, in: raw)
                }
                reindex(&state)
                return refreshShared(&state)

            case .destination(.presented(.sharedItem(.delegate(.finished)))):
                state.destination = nil
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
        state.shared = []
        state.sharedDayIndex = [:]
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
        state.isFetchingShared = state.wantsShared
        return subscribe(state.homeID, month, state.mode, shared: state.isFetchingShared)
    }

    private func subscribe(
        _ homeID: HomeID,
        _ month: CalendarMonth,
        _ mode: State.Mode,
        shared: Bool
    ) -> Effect<Action> {
        let window = State.window(for: month, mode: mode)
        let windowID = "\(mode.rawValue)-\(month.id)"
        return .merge(
            .run { send in
                for try await occurrences in events.inRange(homeID, window.from, window.to) {
                    await send(.occurrencesUpdated(windowID, occurrences))
                }
            } catch: { error, send in
                await send(.loadFailed(AppError(error)))
            }
            .cancellable(id: CancelID.events, cancelInFlight: true),

            shared
                ? sharedFeed(homeID, window, windowID)
                : .cancel(id: CancelID.shared)
        )
    }

    /// Housemates' own calendars for the same window. Open to every house, and
    /// never an error worth a screen: the house's events are the calendar,
    /// these are a bonus.
    private func sharedFeed(
        _ homeID: HomeID,
        _ window: (from: Date, to: Date),
        _ windowID: String
    ) -> Effect<Action> {
        .run { send in
            await Backoff.retrying(clock: clock) { delivered in
                for try await items in calendarShare.inRange(homeID, window.from, window.to, true) {
                    delivered()
                    await send(.sharedUpdated(windowID, items))
                }
            }
        }
        .cancellable(id: CancelID.shared, cancelInFlight: true)
    }

    /// Starts or stops the read of shared items when whether anybody is left to
    /// show has changed. Stopping empties the rows, so a person turned back on
    /// is not drawn from a stale window.
    private func refreshShared(_ state: inout State) -> Effect<Action> {
        let wants = state.wantsShared
        guard wants != state.isFetchingShared else { return .none }
        state.isFetchingShared = wants
        if wants {
            return sharedFeed(state.homeID, State.window(for: state.month, mode: state.mode), state.windowID)
        }
        state.shared = []
        reindex(&state)
        return .cancel(id: CancelID.shared)
    }

    /// The viewer first, then everybody else by name.
    static func peopleRow(_ members: IdentifiedArrayOf<User>, me: UserID?) -> [User] {
        members.sorted { lhs, rhs in
            if lhs.id == me { return true }
            if rhs.id == me { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    /// `people` in the order of the row, so what is stored does not depend on
    /// the order of taps.
    static func ordered(_ people: Set<UserID>, in row: [User]) -> [UserID] {
        let known = row.map(\.id).filter(people.contains)
        // Members not drawn yet (the row is empty before the first answer) keep
        // what was stored rather than losing it.
        return known + people.filter { id in !row.contains { $0.id == id } }.sorted { $0.rawValue < $1.rawValue }
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
        let people = state.people
        let needsAnswer = state.needsAnswer
        let withPlan = state.withPlan
        let calendar = Calendar.current

        var index: [CalendarDay: [EventOccurrence.ID]] = [:]
        // The server sends them in order, so appending keeps each day's list
        // sorted without a second pass.
        for occurrence in state.occurrences {
            if let kind, occurrence.kind != kind { continue }
            if !people.isEmpty, !occurrence.involvesAny(of: people) { continue }
            if needsAnswer, !state.needsMyAnswer(occurrence) { continue }
            if withPlan, !state.isPlanned(occurrence) { continue }
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

        // Housemates' items follow the same people filter, and are left out
        // when a filter is about something only a house event has (its kind, an
        // answer owed, a plan).
        var sharedIndex: [CalendarDay: [String]] = [:]
        if state.showShared, kind == nil, !needsAnswer, !withPlan {
            let hidden = state.hiddenSharers
            let me = state.currentUserID
            for item in state.shared {
                // Own items are never hidden: the choice is about housemates.
                if item.userID != me, hidden.contains(item.userID) { continue }
                if !people.isEmpty, !people.contains(item.userID) { continue }
                if !needle.isEmpty {
                    let matches = (item.shownTitle?.localizedCaseInsensitiveContains(needle) ?? false)
                        || (item.location?.localizedCaseInsensitiveContains(needle) ?? false)
                        || item.calendarName.localizedCaseInsensitiveContains(needle)
                        || state.name(for: item.userID).localizedCaseInsensitiveContains(needle)
                    if !matches { continue }
                }
                for day in item.days(calendar) {
                    sharedIndex[day, default: []].append(item.id)
                }
            }
        }
        state.sharedDayIndex = sharedIndex
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

extension CalendarFeature {
    /// The actions that start writing something, which a house without Plus
    /// is stopped at. Deleting stays free, like the server's `remove`.
    static func writes(_ action: Action) -> Bool {
        switch action {
        case .addTapped, .addOnDayTapped, .rsvpTapped, .editTapped: true
        default: false
        }
    }
}
