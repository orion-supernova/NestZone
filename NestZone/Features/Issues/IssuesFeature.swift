import ComposableArchitecture
import Foundation
import SwiftUI

/// House problems: everything in a shared home that is broken, and what the
/// household is doing about it.
///
/// Four faces of one list. The board is the state of repair — how the house is
/// holding up, what is asking for something, what has gone quiet. The list is
/// every problem with the filters over it. The rooms face is a map of the house
/// by where things keep going wrong, and the history face is what the household
/// has already fixed, how long it took and what it cost.
///
/// The screen derives almost nothing. `issues:byHome` arrives with the counters,
/// the room grid, the severity split and the per-problem rollups already
/// computed — the phone does not hold the shopping list or the ledger while it
/// is looking at this screen, so it could not derive "2 parts still to get" or
/// "€180 so far" even if it wanted to. One subscription rather than three, so
/// none of those figures can contradict the rows they sit above.
@Reducer
public struct IssuesFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, so "mine" means something and a row can say "you"
        /// rather than naming the person reading it.
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User> = []

        public var issues: IdentifiedArrayOf<HouseIssue> = []
        public var summary: IssueSummary = .empty
        public var isLoading = true
        /// Whether the server has answered at all.
        ///
        /// Distinct from `!isLoading` for the reason Finance's `hasSummary` is:
        /// an empty board is a real answer — a household with nothing broken —
        /// and one that has not arrived yet looks identical. Without this the
        /// screen opens congratulating a house it knows nothing about.
        public var hasLoaded = false

        public var section: Section = .board

        // The filters. Not persisted: narrowing a list is a "show me this now",
        // not a preference to be remembered a week later.
        public var search = ""
        public var areaFilter: IssueArea?
        public var severityFilter: IssueSeverity?
        public var statusFilter: IssueStatus?
        public var categoryFilter: IssueCategory?
        /// Only what has my name on it.
        public var mineOnly = false
        public var sort: Sort = .attention

        /// Swiped away, but not yet sent. The row is already gone from
        /// `issues`; if the undo window closes without a tap, this is what gets
        /// deleted for real. One at a time — a second swipe commits the first,
        /// the way a mail client does.
        public var pendingDeletion: HouseIssue?
        /// Rows this screen is pretending are gone while a delete sits out its
        /// undo window. The server still has them, so without this mask every
        /// live push would put them straight back.
        public var hidden: Set<IssueID> = []
        /// Bumped when the last outstanding problem is settled. The one thing
        /// on this screen worth celebrating.
        public var allClearCelebration = 0

        @Presents public var detail: IssueDetailFeature.State?
        @Presents public var compose: IssueComposerFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }

        /// The four faces of the screen.
        public enum Section: String, CaseIterable, Hashable, Sendable, Identifiable {
            case board, list, rooms, history

            public var id: String { rawValue }

            public var title: LocalizedStringResource {
                switch self {
                case .board: L10n.issuesSectionBoard
                case .list: L10n.issuesSectionList
                case .rooms: L10n.issuesSectionRooms
                case .history: L10n.issuesSectionHistory
                }
            }

            public var symbol: String {
                switch self {
                case .board: "gauge.with.dots.needle.bottom.50percent"
                case .list: "list.bullet.rectangle"
                case .rooms: "square.grid.3x3.fill"
                case .history: "clock.arrow.circlepath"
                }
            }
        }

        /// How the list is ordered.
        ///
        /// `attention` is the default and the only one that is not a plain
        /// field comparison: it folds severity, an overdue date, silence and how
        /// many people have said it is happening to them into one number, so
        /// the top of the list is what the household should look at next rather
        /// than what happened to be typed most recently.
        public enum Sort: String, CaseIterable, Hashable, Sendable, Identifiable {
            case attention, newest, oldest, due, severity

            public var id: String { rawValue }

            public var title: LocalizedStringResource {
                switch self {
                case .attention: L10n.issuesSortAttention
                case .newest: L10n.issuesSortNewest
                case .oldest: L10n.issuesSortOldest
                case .due: L10n.issuesSortDue
                case .severity: L10n.issuesSortSeverity
                }
            }

            public var symbol: String {
                switch self {
                case .attention: "sparkles"
                case .newest: "arrow.down"
                case .oldest: "arrow.up"
                case .due: "calendar.badge.exclamationmark"
                case .severity: "exclamationmark.triangle"
                }
            }
        }

        // MARK: Derived

        public func member(_ id: UserID?) -> User? {
            id.flatMap { members[id: $0] }
        }

        public func name(for id: UserID?) -> String {
            guard let id else { return String(localized: L10n.issuesNobody) }
            if id == currentUserID { return String(localized: L10n.issuesYou) }
            return members[id: id]?.displayName ?? String(localized: L10n.issuesSomeone)
        }

        public var openIssues: [HouseIssue] { issues.filter(\.isOpen) }
        public var closedIssues: [HouseIssue] { issues.filter { !$0.isOpen } }

        /// Whether any filter is narrowing the list, so an empty result can say
        /// "nothing matches" rather than "nothing is broken" — which on this
        /// screen are opposite pieces of news.
        public var isFiltering: Bool {
            areaFilter != nil || severityFilter != nil || statusFilter != nil
                || categoryFilter != nil || mineOnly
                || !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// Everything the filters leave, in the chosen order.
        ///
        /// The settled problems are in `issues` too, and the list face shows
        /// them only when a status filter asks for them: a screen whose default
        /// answer to "what is wrong with the house" includes two hundred things
        /// that are not wrong any more is a screen nobody scrolls.
        public var filtered: [HouseIssue] {
            let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
            let scope = statusFilter.map { status in
                issues.filter { $0.status == status }
            } ?? openIssues

            let matched = scope.filter { issue in
                if let areaFilter, issue.area != areaFilter { return false }
                if let severityFilter, issue.severity != severityFilter { return false }
                if let categoryFilter, issue.category != categoryFilter { return false }
                if mineOnly, issue.assignedTo != currentUserID { return false }
                guard !needle.isEmpty else { return true }
                return issue.title.localizedCaseInsensitiveContains(needle)
                    || (issue.details?.localizedCaseInsensitiveContains(needle) ?? false)
                    || (issue.vendorName?.localizedCaseInsensitiveContains(needle) ?? false)
                    || String(localized: issue.area.title)
                        .localizedCaseInsensitiveContains(needle)
                    || String(localized: issue.category.title)
                        .localizedCaseInsensitiveContains(needle)
            }
            return Self.sorted(matched, by: sort)
        }

        /// Ordering, in one place so the list face and the board's rail agree.
        ///
        /// Every comparison ends in a tiebreak on the id. Two problems reported
        /// in the same second with the same severity would otherwise swap places
        /// between pushes — `sorted(by:)` is not stable — and a list that
        /// reshuffles under a finger is a list that feels broken.
        static func sorted(_ rows: [HouseIssue], by sort: Sort) -> [HouseIssue] {
            switch sort {
            case .attention:
                return rows.sorted {
                    $0.attention != $1.attention
                        ? $0.attention > $1.attention
                        : $0.id.rawValue < $1.id.rawValue
                }
            case .newest:
                return rows.sorted {
                    let a = $0.created?.milliseconds ?? 0
                    let b = $1.created?.milliseconds ?? 0
                    return a != b ? a > b : $0.id.rawValue < $1.id.rawValue
                }
            case .oldest:
                return rows.sorted {
                    let a = $0.created?.milliseconds ?? 0
                    let b = $1.created?.milliseconds ?? 0
                    return a != b ? a < b : $0.id.rawValue < $1.id.rawValue
                }
            case .due:
                // Anything without a date goes last rather than first: a
                // problem nobody put a deadline on is not the most urgent thing
                // in the house, which is what sorting `nil` as zero would claim.
                return rows.sorted {
                    let a = $0.dueBy?.milliseconds ?? .greatestFiniteMagnitude
                    let b = $1.dueBy?.milliseconds ?? .greatestFiniteMagnitude
                    return a != b ? a < b : $0.id.rawValue < $1.id.rawValue
                }
            case .severity:
                return rows.sorted {
                    $0.severity != $1.severity
                        ? $0.severity > $1.severity
                        : $0.id.rawValue < $1.id.rawValue
                }
            }
        }

        /// The handful the household should look at next.
        public var needsAttention: [HouseIssue] {
            Array(Self.sorted(openIssues.filter { $0.attention >= 20 }, by: .attention).prefix(4))
        }

        /// Open problems nobody has touched in a week — the ones that quietly
        /// became furniture. The same silence the daily sweep nudges about, so
        /// the screen and the notification agree about which they are.
        public var goneQuiet: [HouseIssue] {
            Self.sorted(openIssues.filter(\.isStale), by: .oldest)
        }

        /// Problems with nobody's name on them.
        public var unassigned: [HouseIssue] {
            Self.sorted(openIssues.filter { $0.assignedTo == nil }, by: .attention)
        }

        /// Settled, newest first — the History face.
        public var history: [HouseIssue] {
            closedIssues.sorted { Timestamp.newestFirst($0.resolvedAt, $1.resolvedAt) }
        }

        /// The busiest room's count, so the heat map scales to this household
        /// rather than to an absolute nobody shares.
        public var busiestRoomCount: Int {
            summary.byArea.map(\.count).max() ?? 0
        }

        /// Rooms with something wrong first, then the rest in declaration order
        /// — so the map is a map, always the same shape, but reads busiest-first
        /// down the page.
        public var roomOrder: [IssueArea] {
            let counted = Dictionary(
                uniqueKeysWithValues: summary.byArea.map { ($0.area, $0.count) }
            )
            return IssueArea.allCases.sorted { lhs, rhs in
                let a = counted[lhs] ?? 0
                let b = counted[rhs] ?? 0
                if a != b { return a > b }
                return lhs.rawValue < rhs.rawValue
            }
        }

        public func count(in area: IssueArea) -> Int { summary.count(of: area) }

        /// Whether this household has genuinely never reported anything — as
        /// opposed to having nothing outstanding right now, which is the good
        /// news the board is for.
        ///
        /// Gated on `hasLoaded` rather than on `!isLoading`, for the reason
        /// Finance's `isBlank` is: `isLoading` is true again on every reconnect,
        /// so gating on it would flip the whole screen between "nothing here
        /// yet" and a stack of skeletons and back.
        public var isBlank: Bool {
            hasLoaded && issues.isEmpty
        }

        /// Everything is fixed, and something once was not.
        public var isAllClear: Bool {
            hasLoaded && summary.open == 0 && !issues.isEmpty
        }

        /// The rooms and categories that actually appear, for the filter rows.
        /// Offering all fourteen rooms when three are in use is a menu, not a
        /// filter.
        public var presentAreas: [IssueArea] {
            summary.byArea.filter { $0.count > 0 }.map(\.area)
        }

        public var presentCategories: [IssueCategory] {
            summary.byCategory.filter { $0.count > 0 }.map(\.category)
        }

        /// Every member as a candidate owner, the viewer first — the person
        /// filing the report takes it on far more often than not.
        public var assigneeOptions: [User] {
            members.sorted { lhs, rhs in
                if lhs.id == currentUserID { return true }
                if rhs.id == currentUserID { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                    == .orderedAscending
            }
        }
    }

    public enum Action: BindableAction {
        case task
        case boardUpdated(IssueBoard)
        case membersUpdated([User])
        case loadFailed(AppError)

        case sectionSelected(State.Section)
        case areaFilterTapped(IssueArea?)
        case severityFilterTapped(IssueSeverity?)
        case statusFilterTapped(IssueStatus?)
        case categoryFilterTapped(IssueCategory?)
        case mineToggled
        case sortSelected(State.Sort)
        case filtersCleared

        case addTapped
        case reportInRoomTapped(IssueArea)
        case issueTapped(IssueID)

        /// "This is happening to me too", from a row.
        case meTooTapped(IssueID)
        case meTooFailed(IssueID, [UserID], AppError)

        /// One tap up the ladder, from a row's context menu.
        case advanceTapped(IssueID)
        case statusFailed(IssueID, IssueStatus, AppError)

        case deleteTapped(IssueID)
        case undoDeleteTapped
        case deleteWindowClosed(IssueID)
        case deleteCommitFailed(HouseIssue, AppError)

        case writeFailed(AppError)

        case binding(BindingAction<State>)
        case detail(PresentationAction<IssueDetailFeature.Action>)
        case compose(PresentationAction<IssueComposerFeature.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        /// Nothing to decide: the only alert this screen raises is a failure,
        /// and the one destructive confirmation lives inside the screen that
        /// offered it.
        public enum Alert: Equatable {}

        public enum Delegate: Equatable {
            /// Open the repair visit in the calendar.
            ///
            /// A delegate rather than navigation this screen does itself: the
            /// calendar is a sibling module on the Hub's stack, and Problems
            /// does not get to know that. It says which event; the Hub knows
            /// where events are shown.
            case openEvent(EventID, CalendarDay)
            /// Open the shopping list, where the parts are.
            case openShoppingList
        }
    }

    private enum CancelID { case board, members, undo, handoff }

    /// Roughly one navigation transition. There is no completion callback for a
    /// dismissal, so the push that follows one has to wait it out.
    private static let unwind: Duration = .milliseconds(350)

    /// How long a swipe stays undoable. The same window the shopping list and
    /// the ledger use, so the gesture means one thing app-wide.
    private static let undoWindow: Duration = .seconds(5)

    @Dependency(\.issues) var issuesClient
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
                    .run { send in
                        for try await board in issuesClient.board(homeID) {
                            await send(.boardUpdated(board))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.board, cancelInFlight: true),

                    // Who lives here, for the assignee picker and for putting a
                    // name against a report. A handful of rows, live so a new
                    // housemate can be handed a repair the day they arrive.
                    .run { send in
                        for try await members in homes.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.members, cancelInFlight: true)
                )

            // MARK: Live pushes
            //
            // These land far more often than the data changes: Convex
            // re-publishes every live query in the app whenever the query set is
            // modified, so opening any sheet anywhere re-delivers this board
            // untouched. Comparing before writing costs one comparison and saves
            // an observation notification through every view reading it.

            case let .boardUpdated(board):
                var incoming = IdentifiedArray(uniqueElements: board.issues)
                // Anything the server has already dropped no longer needs
                // hiding; keeping it would leak the mask across a re-report.
                let stillHidden = state.hidden.intersection(incoming.ids)
                if stillHidden != state.hidden { state.hidden = stillHidden }
                for id in stillHidden { incoming.remove(id: id) }

                // The last outstanding problem going away is the one thing on
                // this screen worth celebrating — and only on the transition. A
                // household with nothing broken must not get confetti every
                // time a subscription pushes.
                if state.hasLoaded, state.summary.open > 0, board.summary.open == 0 {
                    state.allClearCelebration += 1
                }

                if incoming != state.issues { state.issues = incoming }
                if board.summary != state.summary { state.summary = board.summary }
                state.isLoading = false
                state.hasLoaded = true
                return .none

            case let .membersUpdated(members):
                let incoming = IdentifiedArray(uniqueElements: members)
                guard incoming != state.members else { return .none }
                state.members = incoming
                // A screen already presented holds its own copy of the household
                // — a new housemate has to reach its picker too.
                state.compose?.members = incoming
                state.detail?.members = incoming
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // MARK: Getting around

            case let .sectionSelected(section):
                state.section = section
                return .none

            case let .areaFilterTapped(area):
                // Tapping the active chip clears it, so the full list is always
                // one tap away without hunting for an "all" control.
                state.areaFilter = state.areaFilter == area ? nil : area
                return .none

            case let .severityFilterTapped(severity):
                state.severityFilter = state.severityFilter == severity ? nil : severity
                return .none

            case let .statusFilterTapped(status):
                state.statusFilter = state.statusFilter == status ? nil : status
                return .none

            case let .categoryFilterTapped(category):
                state.categoryFilter = state.categoryFilter == category ? nil : category
                return .none

            case .mineToggled:
                state.mineOnly.toggle()
                return .none

            case let .sortSelected(sort):
                state.sort = sort
                return .none

            case .filtersCleared:
                state.search = ""
                state.areaFilter = nil
                state.severityFilter = nil
                state.statusFilter = nil
                state.categoryFilter = nil
                state.mineOnly = false
                return .none

            // MARK: Reporting

            case .addTapped:
                state.compose = IssueComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    // Reporting while a room is filtered fills the room in: the
                    // question "where" was already answered by where the button
                    // was pressed.
                    area: state.areaFilter
                )
                return .none

            case let .reportInRoomTapped(area):
                state.compose = IssueComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    area: area
                )
                return .none

            case let .issueTapped(id):
                guard let issue = state.issues[id: id] else { return .none }
                state.detail = IssueDetailFeature.State(
                    issue: issue,
                    homeID: state.homeID,
                    currentUserID: state.currentUserID,
                    members: state.members
                )
                return .none

            // MARK: Agreeing

            // Optimistic, and it owns its rollback. A failed write changed
            // nothing on the server, so there is no push coming to correct the
            // screen — the failure action carries the list that was there
            // before and puts it back itself.
            case let .meTooTapped(id):
                guard let me = state.currentUserID,
                      var issue = state.issues[id: id] else { return .none }
                let previous = issue.meToo
                if issue.meToo.contains(me) {
                    issue.meToo.removeAll { $0 == me }
                } else {
                    issue.meToo.append(me)
                }
                state.issues[id: id] = issue
                return .run { _ in
                    _ = try await issuesClient.toggleMeToo(id)
                } catch: { error, send in
                    await send(.meTooFailed(id, previous, AppError(error)))
                }

            case let .meTooFailed(id, previous, error):
                state.issues[id: id]?.meToo = previous
                return .send(.writeFailed(error))

            // MARK: Moving one along

            case let .advanceTapped(id):
                guard let issue = state.issues[id: id],
                      let next = issue.status.next else { return .none }
                let previous = issue.status
                state.issues[id: id]?.status = next
                return .run { _ in
                    try await issuesClient.setStatus(id, next, nil)
                } catch: { error, send in
                    await send(.statusFailed(id, previous, AppError(error)))
                }

            case let .statusFailed(id, previous, error):
                state.issues[id: id]?.status = previous
                return .send(.writeFailed(error))

            // MARK: Deleting

            case let .deleteTapped(id):
                guard let issue = state.issues[id: id] else { return .none }
                // The row goes now — waiting for the server reads as a swipe
                // that did not take — but the write is held back until the undo
                // window closes, so undo cancels it rather than reversing it.
                state.issues.remove(id: id)
                state.hidden.insert(id)
                let superseded = state.pendingDeletion
                state.pendingDeletion = issue

                return .merge(
                    // A second swipe ends the first one's window; that row was
                    // offered back and the offer was not taken.
                    superseded.map { commitDelete($0) } ?? .none,

                    .run { send in
                        try await clock.sleep(for: Self.undoWindow)
                        await send(.deleteWindowClosed(issue.id))
                    }
                    .cancellable(id: CancelID.undo, cancelInFlight: true)
                )

            case .undoDeleteTapped:
                guard let issue = state.pendingDeletion else { return .none }
                state.pendingDeletion = nil
                state.hidden.remove(issue.id)
                // Nothing was ever sent, so this is the whole restore. The live
                // subscription still holds the row and will agree.
                state.issues.append(issue)
                return .cancel(id: CancelID.undo)

            case let .deleteWindowClosed(id):
                guard let issue = state.pendingDeletion, issue.id == id else { return .none }
                state.pendingDeletion = nil
                return commitDelete(issue)

            case let .deleteCommitFailed(issue, error):
                // The write never happened, and the mask would otherwise keep
                // hiding a row the server still has — a delete that quietly did
                // not delete, until the screen was reopened.
                state.hidden.remove(issue.id)
                state.issues.append(issue)
                return .send(.writeFailed(error))

            // MARK: The screens under this one reporting back

            case .compose(.presented(.delegate(.saved))):
                state.compose = nil
                return .none

            // The detail screen has already asked. The row goes on the same
            // undoable path a swipe takes, rather than confirming separately:
            // two ways to delete the same thing that behave differently is how
            // an undo stops being trusted.
            case let .detail(.presented(.delegate(.deleteRequested(id)))):
                state.detail = nil
                return .send(.deleteTapped(id))

            // Leave the problem, *then* go somewhere else. Never both in one
            // pass.
            //
            // The detail screen is a `navigationDestination(item:)` inside the
            // very stack the Hub's `path` drives, so by the time one of these
            // arrives a destination is already on top of it. Asking SwiftUI to
            // dismiss that and push a sibling underneath it in a single update
            // is what left the recipe screen on screen while the state said
            // "shopping" — see the same dance in `HubFeature`. Unwinding and
            // pushing are each fine; it is doing them in the same breath that
            // it cannot reconcile.
            case let .detail(.presented(.delegate(.openEvent(eventID, day)))):
                state.detail = nil
                return .run { send in
                    try await clock.sleep(for: Self.unwind)
                    await send(.delegate(.openEvent(eventID, day)))
                }
                .cancellable(id: CancelID.handoff, cancelInFlight: true)

            case .detail(.presented(.delegate(.openShoppingList))):
                state.detail = nil
                return .run { send in
                    try await clock.sleep(for: Self.unwind)
                    await send(.delegate(.openShoppingList))
                }
                .cancellable(id: CancelID.handoff, cancelInFlight: true)

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .detail, .compose, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) { IssueDetailFeature() }
        .ifLet(\.$compose, action: \.compose) { IssueComposerFeature() }
        .ifLet(\.$alert, action: \.alert)
    }

    /// The write the swipe was always going to make, once nobody has undone it.
    ///
    /// Takes the whole problem rather than its id so a failure can put the row
    /// back: the screen dropped it optimistically and nothing else remembers it.
    private func commitDelete(_ issue: HouseIssue) -> Effect<Action> {
        .run { _ in
            try await issuesClient.remove(issue.id)
        } catch: { error, send in
            await send(.deleteCommitFailed(issue, AppError(error)))
        }
    }
}
