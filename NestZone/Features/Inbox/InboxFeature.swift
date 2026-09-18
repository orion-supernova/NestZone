import ComposableArchitecture
import Foundation

/// The bell in the corner, and the panel behind it.
///
/// Two feeds that share a button and nothing else: what the *household* did,
/// and what the *app* did. They are separated all the way down — two tables,
/// two queries, two watermarks, two visual languages — because they answer
/// different questions and a single merged list would bury a leaking tap under
/// a release note, or the other way round on a quiet week.
///
/// The lifetimes are the performance story:
///
/// - `task` runs for as long as a home is open and holds **one** subscription,
///   the badge. That query is floored server-side at a fortnight, so the cost
///   of the always-on half does not grow with the household's age.
/// - The feeds themselves are subscribed only while the panel is on screen, and
///   only for the tab being looked at. Switching tabs cancels the other.
/// - History is fetched once per page rather than subscribed. An activity row
///   is immutable, so there is no later state a subscription could deliver —
///   see `InboxClient`.
@Reducer
public struct InboxFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Whose feed this is. Decides which rows are "your own doing" and so
        /// never marked new, matching the server's rule for the badge.
        public var currentUserID: UserID?

        /// What the bell shows. Live for the lifetime of the home.
        public var badge = InboxBadge()

        /// Whether the panel is up. Not `@Presents` — the panel has no state of
        /// its own to present, it *is* this feature's state, and the sheet's
        /// `.task` is what starts and stops the feeds.
        public var isOpen = false
        public var tab: Tab = .activity

        // MARK: The household's feed

        public var activity: IdentifiedArrayOf<HomeActivity> = []
        /// Day-grouped rows, rebuilt whenever the rows or the filters change.
        ///
        /// Stored rather than computed. A computed property on observable state
        /// is re-run on every `body` evaluation, and this one groups, filters
        /// and formats a date header per section — cheap once, wasteful sixty
        /// times a second while somebody scrolls.
        public var sections: [ActivitySection] = []
        public var category: ActivityCategory?
        public var unreadOnly = false
        public var categoryCounts = ActivityCategoryCounts()
        public var isLoadingActivity = true
        public var isLoadingMore = false
        /// Where the next page starts. `nil` once the feed is exhausted.
        public var cursor: Timestamp?
        public var hasMore = false
        /// How long the server keeps a household's log, as the server reports
        /// it — never a number hardcoded here, which could drift from the sweep.
        public var retentionDays = 90

        // MARK: The changelog

        public var updates: IdentifiedArrayOf<AppUpdate> = []
        public var isLoadingUpdates = true

        // MARK: Read state

        /// The watermarks as they stood when the panel was opened.
        ///
        /// Frozen on purpose. The panel marks the feed read the moment it
        /// shows it — that is what a notification centre does — but goes on
        /// drawing the "new" marks against the value it *opened* with, so the
        /// row somebody came to read does not stop looking new while they are
        /// reading it.
        public var seenActivityAt: Timestamp?
        public var seenUpdatesAt: Timestamp?

        @Presents public var admin: InboxAdminFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }

        /// Which side of the panel is showing.
        public enum Tab: String, CaseIterable, Hashable, Sendable, Identifiable {
            case activity, updates

            public var id: String { rawValue }

            public var symbol: String {
                switch self {
                case .activity: "house.fill"
                case .updates: "sparkles"
                }
            }

            public var title: LocalizedStringResource {
                switch self {
                case .activity: L10n.inboxTabActivity
                case .updates: L10n.inboxTabUpdates
                }
            }
        }

        /// Whether a row arrived since this person last looked.
        ///
        /// Two conditions, matching the server's badge exactly: newer than the
        /// watermark the panel opened with, and not something they did
        /// themselves. Being told that you added milk, seconds after adding
        /// milk, is the fastest way to teach somebody that the badge is noise.
        public func isNew(_ row: HomeActivity) -> Bool {
            guard row.actor != currentUserID else { return false }
            return row.isNew(since: seenActivityAt)
        }

        public func isNew(_ update: AppUpdate) -> Bool {
            update.isNew(since: seenUpdatesAt)
        }

        /// The newest row the panel has actually shown, which is what the read
        /// watermark may be moved to — never `now`, which would mark read what
        /// a stale page never displayed.
        public var newestShownActivity: Timestamp? { activity.first?.created }

        public var newestShownUpdate: Timestamp? {
            updates.compactMap(\.publishedAt).max()
        }

        /// Rows after the client-side filters.
        ///
        /// Only "unread only" is applied here; the category filter is a server
        /// index range, because a household with a year of history must not
        /// find the four rows about money by walking the other three thousand.
        ///
        /// Filtering unread client-side is exact rather than approximate: the
        /// feed is sorted by time and the watermark is a time, so every unread
        /// row is above every read one and none of them can be hiding below a
        /// page boundary.
        var visibleRows: [HomeActivity] {
            unreadOnly ? activity.filter(isNew) : Array(activity)
        }

        /// Rebuilds the day sections. The one place grouping happens.
        mutating func rebuildSections() {
            sections = ActivitySection.group(visibleRows)
        }

        /// Whether the empty state should offer to clear the filters rather
        /// than simply saying there is nothing here — which would be a lie
        /// while a filter is hiding it.
        public var isFiltered: Bool { category != nil || unreadOnly }

        /// Release notes, with anything this build does not have yet marked as
        /// such. Ordered as the server sent them: pinned first, then newest.
        public var updateRows: [AppUpdate] { Array(updates) }
    }

    public enum Action: BindableAction {
        /// Opens the badge subscription. Lives as long as the home does.
        case task
        case badgeUpdated(InboxBadge)
        case badgeFailed(AppError)

        case bellTapped
        case closeTapped
        case tabSelected(State.Tab)

        /// Opens the feed for whichever tab is showing. Sent by the sheet's own
        /// `.task`, so the subscriptions exist only while the panel does.
        case panelTask
        case activityUpdated(ActivityPage)
        case activityFailed(AppError)
        case categoriesUpdated(ActivityCategoryCounts)
        case updatesUpdated([AppUpdate])
        case updatesFailed(AppError)

        case categorySelected(ActivityCategory?)
        case unreadOnlyToggled
        case reachedEnd
        case olderLoaded(ActivityPage)
        case olderFailed(AppError)

        case markAllReadTapped
        /// Carries what the counts were, so a refused write can put them back —
        /// a failed mutation changed nothing on the server, so no push is
        /// coming to correct it.
        case markReadFailed(previous: InboxBadge, AppError)

        case rowTapped(HomeActivity)
        case adminTapped

        case admin(PresentationAction<InboxAdminFeature.Action>)
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        public enum Delegate: Equatable {
            /// Somebody tapped a row. The parent knows where each category
            /// lives; this feature deliberately does not.
            case open(ActivityCategory)
        }
    }

    private enum CancelID: Hashable {
        case badge
        case feed
        case categories
    }

    @Dependency(\.inbox) var inbox

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {

            // MARK: The bell

            case .task:
                return .run { [homeID = state.homeID] send in
                    for try await badge in inbox.badge(homeID) {
                        await send(.badgeUpdated(badge))
                    }
                } catch: { error, send in
                    await send(.badgeFailed(AppError(error)))
                }
                .cancellable(id: CancelID.badge, cancelInFlight: true)

            case let .badgeUpdated(badge):
                state.badge = badge
                return .none

            case .badgeFailed:
                // Deliberately silent. The bell is furniture on somebody else's
                // screen — a failure to count is not worth an alert over
                // whatever they were actually doing, and `subscribe` is already
                // re-opening the query on its own.
                return .none

            case .bellTapped:
                state.isOpen = true
                // Frozen here, before anything is marked read, so the rows that
                // brought somebody to the panel still look new once they are in
                // it.
                state.seenActivityAt = state.badge.activityBaseline
                state.seenUpdatesAt = state.badge.updatesBaseline
                // Open on the side with something on it. Household activity
                // wins a tie, because it is the side that is usually urgent —
                // a release note has waited this long and can wait a tap longer.
                if state.badge.activity == 0, state.badge.updates > 0 {
                    state.tab = .updates
                }
                return .none

            case .closeTapped:
                state.isOpen = false
                return .merge(
                    .cancel(id: CancelID.feed),
                    .cancel(id: CancelID.categories)
                )

            case let .tabSelected(tab):
                guard tab != state.tab else { return .none }
                state.tab = tab
                return feedEffect(&state)

            // MARK: The feeds

            case .panelTask:
                return feedEffect(&state)

            case let .activityUpdated(page):
                state.isLoadingActivity = false
                state.retentionDays = page.retentionDays

                // The live subscription owns the *newest* page only. Pages
                // already loaded below it are history and stay: merging rather
                // than replacing is what keeps a scrolled-down panel from
                // snapping back to the top when somebody in the kitchen ticks a
                // chore.
                let known = Set(state.activity.ids)
                let isFirstPage = state.cursor == nil || known.isEmpty
                if isFirstPage {
                    state.activity = IdentifiedArray(uniqueElements: page.rows)
                    state.cursor = page.cursor
                    state.hasMore = page.hasMore
                } else {
                    for row in page.rows.reversed() where !known.contains(row.id) {
                        state.activity.insert(row, at: 0)
                    }
                }
                state.rebuildSections()
                return markActivityRead(&state)

            case let .activityFailed(error):
                state.isLoadingActivity = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .categoriesUpdated(counts):
                state.categoryCounts = counts
                return .none

            case let .updatesUpdated(updates):
                state.isLoadingUpdates = false
                state.updates = IdentifiedArray(uniqueElements: updates)
                return markUpdatesRead(&state)

            case let .updatesFailed(error):
                state.isLoadingUpdates = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // MARK: Filters

            case let .categorySelected(category):
                guard category != state.category else { return .none }
                state.category = category
                // The filter is a different index range on the server, so the
                // page in hand is not a subset of the new one — it is a
                // different question. Cleared rather than filtered.
                state.activity = []
                state.sections = []
                state.cursor = nil
                state.hasMore = false
                state.isLoadingActivity = true
                return feedEffect(&state)

            case .unreadOnlyToggled:
                // Client-side, and exact: every unread row is newer than every
                // read one, so none of them can be below a page boundary.
                state.unreadOnly.toggle()
                state.rebuildSections()
                return .none

            // MARK: Paging

            case .reachedEnd:
                guard state.tab == .activity,
                      state.hasMore,
                      !state.isLoadingMore,
                      !state.unreadOnly,
                      let cursor = state.cursor
                else { return .none }

                state.isLoadingMore = true
                return .run { [homeID = state.homeID, category = state.category] send in
                    let page = try await inbox.olderActivity(homeID, category, cursor)
                    await send(.olderLoaded(page))
                } catch: { error, send in
                    await send(.olderFailed(AppError(error)))
                }

            case let .olderLoaded(page):
                state.isLoadingMore = false
                // Appended through an identified array, which drops anything
                // already held — so a cursor that overlaps by a row cannot
                // double it up.
                for row in page.rows where state.activity[id: row.id] == nil {
                    state.activity.append(row)
                }
                state.cursor = page.cursor
                state.hasMore = page.hasMore && page.cursor != nil
                state.rebuildSections()
                return .none

            case let .olderFailed(error):
                state.isLoadingMore = false
                // Quiet: the rows already on screen are unaffected, and the
                // footer simply offers the tap again. An alert over a page that
                // did not arrive is an alert about scrolling.
                state.hasMore = !error.isSilent
                return .none

            // MARK: Reading

            case .markAllReadTapped:
                let previous = state.badge
                state.badge.activity = 0
                state.badge.updates = 0
                state.badge.latestCategory = nil
                let newestActivity = state.newestShownActivity
                let newestUpdate = state.newestShownUpdate
                return .run { [homeID = state.homeID] send in
                    // Both together: the button says "all".
                    async let activity: Void = inbox.markActivityRead(homeID, newestActivity)
                    async let updates: Void = inbox.markUpdatesRead(newestUpdate)
                    _ = try await (activity, updates)
                } catch: { error, send in
                    await send(.markReadFailed(previous: previous, AppError(error)))
                }

            case let .markReadFailed(previous, error):
                // The write did not land, so the server has nothing new to push
                // and the optimistic zero would sit there forever. Put it back
                // by hand, which is what every optimistic write in this app
                // owes its own failure handler.
                state.badge = previous
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // MARK: Navigation out

            case let .rowTapped(row):
                guard row.category.isRoutable else { return .none }
                state.isOpen = false
                return .merge(
                    .cancel(id: CancelID.feed),
                    .cancel(id: CancelID.categories),
                    .send(.delegate(.open(row.category)))
                )

            case .adminTapped:
                guard state.badge.isAdmin else { return .none }
                state.admin = InboxAdminFeature.State(currentUserID: state.currentUserID)
                return .none

            // Swiped away rather than closed with the button, which never
            // reaches `closeTapped`. Without this the two feed subscriptions
            // would outlive the panel — held open, for a list nobody is
            // looking at, until the home changed.
            case .binding(\.isOpen):
                guard !state.isOpen else { return .none }
                return .merge(
                    .cancel(id: CancelID.feed),
                    .cancel(id: CancelID.categories)
                )

            case .admin, .alert, .binding, .delegate:
                return .none
            }
        }
        .ifLet(\.$admin, action: \.admin) { InboxAdminFeature() }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Effects

    /// Opens the subscriptions the current tab needs, and cancels the other's.
    ///
    /// One tab at a time on purpose. Both feeds live would be a second websocket
    /// query held open for a list nobody is looking at; Convex caches query
    /// results server-side, so coming back to a tab is a re-subscribe and not a
    /// recomputation.
    private func feedEffect(_ state: inout State) -> Effect<Action> {
        switch state.tab {
        case .activity:
            state.isLoadingActivity = state.activity.isEmpty
            return .merge(
                .run { [homeID = state.homeID, category = state.category] send in
                    for try await page in inbox.activity(homeID, category) {
                        await send(.activityUpdated(page))
                    }
                } catch: { error, send in
                    await send(.activityFailed(AppError(error)))
                }
                .cancellable(id: CancelID.feed, cancelInFlight: true),

                // Its own subscription, and not folded into the page above,
                // because the chips are answered once when the panel opens
                // while the feed is re-read on every filter change and every
                // scroll to the bottom. Folding them together would recount the
                // household on every page turn.
                .run { [homeID = state.homeID] send in
                    for try await counts in inbox.activityCategories(homeID) {
                        await send(.categoriesUpdated(counts))
                    }
                } catch: { _, _ in
                    // The chips are an affordance, not information. Losing them
                    // costs a filter, not a fact.
                }
                .cancellable(id: CancelID.categories, cancelInFlight: true)
            )

        case .updates:
            state.isLoadingUpdates = state.updates.isEmpty
            return .merge(
                .cancel(id: CancelID.categories),
                .run { send in
                    for try await updates in inbox.updates() {
                        await send(.updatesUpdated(updates))
                    }
                } catch: { error, send in
                    await send(.updatesFailed(AppError(error)))
                }
                .cancellable(id: CancelID.feed, cancelInFlight: true)
            )
        }
    }

    /// Marks the household's feed read up to the newest row actually shown.
    ///
    /// Fired when a page arrives rather than when the panel opens, because
    /// until then there is nothing to say has been seen. Optimistic, and the
    /// failure puts the count back.
    private func markActivityRead(_ state: inout State) -> Effect<Action> {
        guard state.isOpen, state.tab == .activity, state.badge.activity > 0 else {
            return .none
        }
        let previous = state.badge
        let newest = state.newestShownActivity
        state.badge.activity = 0
        state.badge.latestCategory = nil
        return .run { [homeID = state.homeID] send in
            try await inbox.markActivityRead(homeID, newest)
        } catch: { error, send in
            await send(.markReadFailed(previous: previous, AppError(error)))
        }
    }

    private func markUpdatesRead(_ state: inout State) -> Effect<Action> {
        guard state.isOpen, state.tab == .updates, state.badge.updates > 0 else {
            return .none
        }
        let previous = state.badge
        let newest = state.newestShownUpdate
        state.badge.updates = 0
        return .run { send in
            try await inbox.markUpdatesRead(newest)
        } catch: { error, send in
            await send(.markReadFailed(previous: previous, AppError(error)))
        }
    }
}

// MARK: - Day grouping

/// A day's worth of household activity.
///
/// Days rather than a flat list because a feed without them is a wall: the
/// question somebody brings to it is almost always "what happened *since*", and
/// a date header is the cheapest possible answer to it.
public struct ActivitySection: Identifiable, Equatable, Sendable {
    /// Midnight of the day, which is both the identity and the sort key.
    public let id: Date
    public let rows: [HomeActivity]

    public init(id: Date, rows: [HomeActivity]) {
        self.id = id
        self.rows = rows
    }

    /// Groups rows that are already newest-first into days, preserving order.
    ///
    /// One pass, and no dictionary: the input is sorted, so a day boundary is
    /// simply the point at which the calendar day changes. `Dictionary(grouping:)`
    /// followed by a sort would be two passes and a re-sort of data that arrived
    /// in the right order.
    static func group(_ rows: [HomeActivity]) -> [ActivitySection] {
        guard !rows.isEmpty else { return [] }
        let calendar = Calendar.current
        var sections: [ActivitySection] = []
        var currentDay = calendar.startOfDay(for: rows[0].created.date)
        var bucket: [HomeActivity] = []

        for row in rows {
            let day = calendar.startOfDay(for: row.created.date)
            if day != currentDay {
                sections.append(ActivitySection(id: currentDay, rows: bucket))
                currentDay = day
                bucket = []
            }
            bucket.append(row)
        }
        sections.append(ActivitySection(id: currentDay, rows: bucket))
        return sections
    }

    /// "Today", "Yesterday", or the date.
    ///
    /// Built here rather than in the view so it is computed once per section
    /// per rebuild instead of once per `body`.
    public var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(id) { return String(localized: L10n.inboxDayToday) }
        if calendar.isDateInYesterday(id) { return String(localized: L10n.inboxDayYesterday) }

        // Inside the current week the weekday alone is the most readable
        // answer; past it the date is, because "Tuesday" three weeks back is
        // not a date anybody can place.
        let daysAgo = calendar.dateComponents([.day], from: id, to: .now).day ?? 0
        let style: Date.FormatStyle = daysAgo < 7
            ? Date.FormatStyle().weekday(.wide)
            : Date.FormatStyle(date: .abbreviated, time: .omitted)
        return id.formatted(style.locale(L10n.locale))
    }
}
