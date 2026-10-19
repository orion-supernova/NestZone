import ComposableArchitecture
import Foundation

/// Today: what needs somebody, said in one sentence, with the rest underneath
/// only when it has something in it.
///
/// It used to be six equal sections, each with a header and an empty state,
/// and an empty household spent nearly three quarters of the screen saying
/// that dinner was undecided and there were no chores. A tester called it too
/// complex, and said empty sections took too much room even when there was
/// nothing to do. So the rule now is that a section with nothing in it is not
/// drawn at all — unless this person set it to Always in Customize — and a
/// quiet day reads "All clear" in one line.
@Reducer
public struct HomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var user: User?
        /// How many people live here.
        public var memberCount = 1
        public var stats: HomeStats = .empty
        public var tasks: IdentifiedArrayOf<HouseTask> = []
        /// The next few things in the calendar, soonest first.
        ///
        /// A short capped agenda, not a window: this tab only ever asks "is
        /// anything coming", and `events:upcoming` answers that with at most a
        /// handful of rows however many years of events the household has.
        public var upcoming: [EventOccurrence] = []
        /// Who lives here: the getting-started checklist asks whether anybody
        /// else has joined yet, and a problem's row says who is on it.
        public var members: IdentifiedArrayOf<User> = []
        /// Every bill and every problem, as the server sent them. "Needs you"
        /// is worked out from these against `now` rather than filtered once
        /// on arrival: a bill crosses into the three-day window at midnight
        /// and a problem passes its date in the afternoon, and neither sends a
        /// push when it does.
        public var bills: [Bill] = []
        public var issues: [HouseIssue] = []
        /// Which of the tab's subscriptions have answered.
        ///
        /// Each part of the screen waits on its own answer, so a screen made
        /// of six queries appears in six pieces rather than waiting for the
        /// slowest — and an answer that has not arrived is never mistaken for
        /// one that arrived empty.
        public var loaded: Loaded = []

        public struct Loaded: OptionSet, Equatable, Sendable {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }
            public static let stats = Loaded(rawValue: 1 << 0)
            public static let tasks = Loaded(rawValue: 1 << 1)
            public static let upcoming = Loaded(rawValue: 1 << 2)
            public static let members = Loaded(rawValue: 1 << 3)
            public static let bills = Loaded(rawValue: 1 << 4)
            public static let issues = Loaded(rawValue: 1 << 5)
        }

        /// Tonight's dinner and the calendar's offer of one, handed down by
        /// the tab container, which owns the one dinner sheet the whole tab
        /// bar shares.
        public var tonight: MealPlan?
        public var dinnerSuggestion: EventOccurrence?
        /// Whether the household has a movie round open, also handed down.
        public var movieRoundIsOpen = false
        /// The container's clock, which moves on every half minute. Today reads
        /// the time of day off it — "Tuesday evening" — and so does the
        /// decision about which chores are due.
        public var now: Date

        /// Chores ticked here a moment ago, kept on screen long enough for the
        /// tick to be seen — and to be taken back — before the row leaves.
        public var justTicked: Set<TaskID> = []
        /// Whether the chore list has been opened past its first few rows.
        public var showsAllChores = false

        @Presents public var alert: AlertState<Action.Alert>?

        /// Whether the household has already been asked about notifications.
        /// Persisted, so the soft ask happens once per install rather than on
        /// every visit to this tab.
        @Shared(.hasAskedForNotifications) public var hasAskedForNotifications: Bool

        /// Which sections show, when, and in what order. Live: saving
        /// Customize rearranges this screen without anything being sent to it.
        @Shared(.todayLayoutRaw) public var layoutRaw: String
        @Shared(.todaySetupDone) public var setupDone: Bool

        public init(homeID: HomeID, user: User? = nil, now: Date = Date()) {
            self.homeID = homeID
            self.user = user
            self.now = now
        }

        public var layout: TodayLayout { TodayLayout(raw: layoutRaw) }

        /// Every finished chore on the Done list, when and by whom — what the
        /// companion grows from. A chore ticked a moment ago has no time yet;
        /// it counts when the server's copy arrives with one.
        public var completions: [Completion] {
            tasks.compactMap { task in
                guard task.isCompleted, let at = task.completedAt?.date else { return nil }
                return Completion(at: at, by: task.completedBy)
            }
        }

        /// Bills already late or due within `needsYouBillDays`, soonest first.
        public var billsDue: [Bill] {
            bills
                .filter { !$0.isArchived && $0.daysUntilDue(now: now) <= HomeFeature.needsYouBillDays }
                .sorted { $0.dueDate.date < $1.dueDate.date }
        }

        /// Open problems that are urgent or past their date, worst first.
        public var urgentIssues: [HouseIssue] {
            issues
                .filter { $0.isOpen && ($0.severity == .urgent || $0.isOverdue(now: now)) }
                .sorted {
                    ($0.isOverdue(now: now) ? 0 : 1, -$0.severity.rank)
                        < ($1.isOverdue(now: now) ? 0 : 1, -$1.severity.rank)
                }
        }

        // MARK: Chores

        /// The chores that belong on Today: anything late or due today,
        /// whoever has it, then this person's own and anybody's that nobody
        /// has taken. Everybody else's undated chores live on the Tasks list.
        ///
        /// It used to be the five newest chores *created*, finished ones
        /// included — so a chore struck through yesterday could push today's
        /// out of sight.
        public var chores: [HouseTask] {
            let me = user?.id
            let today = Calendar.current.startOfDay(for: now)
            func tier(_ task: HouseTask) -> Int? {
                if let due = task.dueDate?.date {
                    if due < today { return 0 }
                    if Calendar.current.isDate(due, inSameDayAs: now) { return 1 }
                }
                if task.assignedTo == me, me != nil { return 2 }
                if task.assignedTo == nil { return 3 }
                return nil
            }
            return tasks
                .filter { !$0.isCompleted || justTicked.contains($0.id) }
                .compactMap { task in tier(task).map { (task, $0) } }
                .sorted { lhs, rhs in
                    if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                    switch (lhs.0.dueDate?.date, rhs.0.dueDate?.date) {
                    case let (l?, r?) where l != r: return l < r
                    case (_?, nil): return true
                    case (nil, _?): return false
                    default: return Timestamp.newestFirst(lhs.0.created, rhs.0.created)
                    }
                }
                .map(\.0)
        }

        /// How many rows the chore list shows before "N more".
        static let choreLimit = 4

        public var visibleChores: ArraySlice<HouseTask> {
            showsAllChores ? chores[...] : chores.prefix(Self.choreLimit)
        }

        public var hiddenChoreCount: Int { showsAllChores ? 0 : max(chores.count - Self.choreLimit, 0) }

        // MARK: Needs you

        /// Something wrong in the house, with a date that has passed or a
        /// severity that will not wait.
        public enum Alarm: Equatable, Identifiable, Sendable {
            case issue(HouseIssue)
            case bill(Bill)

            public var id: String {
                switch self {
                case let .issue(issue): "issue-\(issue.id.rawValue)"
                case let .bill(bill): "bill-\(bill.id.rawValue)"
                }
            }
        }

        /// Everything "Needs you" holds, worst first: urgent or overdue
        /// problems, then bills by due date.
        public var needs: [Alarm] {
            urgentIssues.map(Alarm.issue) + billsDue.map(Alarm.bill)
        }

        /// The one thing that gets the big card: an urgent problem or a bill
        /// already late. A normal day has none — a card drawn every day for
        /// whatever happens to be first stops meaning anything.
        public var hero: Alarm? {
            guard layout.visibility(of: .needsYou) != .off else { return nil }
            if let issue = urgentIssues.first { return .issue(issue) }
            if let bill = billsDue.first(where: { $0.urgency(now: now) == .overdue }) { return .bill(bill) }
            return nil
        }

        /// What "Needs you" lists under the card.
        public var needsRows: [Alarm] {
            needs.filter { $0 != hero }
        }

        // MARK: Coming up

        /// What is coming, not what is under way — the dock above the tab bar
        /// already says what is happening now.
        public var comingUp: [EventOccurrence] {
            Array(upcoming.filter { !$0.isInProgress && $0.start > now }.prefix(4))
        }

        /// Events in the next seven days, the way the counters count them.
        public var eventsThisWeek: Int {
            let horizon = now.addingTimeInterval(7 * 24 * 3600)
            return upcoming.count { $0.start <= horizon }
        }

        // MARK: Counters

        /// The counters that are asking for something. "0 to buy" is good
        /// news, and a row of zeros under "Nothing to do" was the clearest
        /// sign the old Today was talking for the sake of it.
        public var counters: [Counter] {
            var counters: [Counter] = []
            if stats.shoppingItems > 0 { counters.append(.shopping(stats.shoppingItems)) }
            if stats.unreadMessages > 0 { counters.append(.unread(stats.unreadMessages)) }
            if stats.openIssues > 0 { counters.append(.problems(stats.openIssues)) }
            if eventsThisWeek > 0 { counters.append(.events(eventsThisWeek)) }
            return counters
        }

        public enum Counter: Equatable, Hashable, Sendable {
            case shopping(Int), unread(Int), problems(Int), events(Int)
        }

        // MARK: Movie night

        /// Whether Automatic shows the movie-night row: while a round is open,
        /// and on Friday and Saturday evenings, which is when people ask.
        public var movieNightIsTimely: Bool {
            if movieRoundIsOpen { return true }
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: now)
            let hour = calendar.component(.hour, from: now)
            return (weekday == 6 || weekday == 7) && hour >= DockItem.eveningStarts
        }

        // MARK: Getting started

        public enum SetupStep: String, CaseIterable, Identifiable, Sendable {
            case invite, firstChore, dinner, customize
            public var id: String { rawValue }
        }

        /// The steps already done, read off the household rather than ticked
        /// by hand, so the list can never claim something that is not true.
        public var finishedSetup: Set<SetupStep> {
            var done: Set<SetupStep> = []
            if members.count > 1 { done.insert(.invite) }
            if !tasks.isEmpty { done.insert(.firstChore) }
            if tonight != nil { done.insert(.dinner) }
            if layoutRaw != TodayLayout.default.raw { done.insert(.customize) }
            return done
        }

        /// The checklist a new household gets in place of the welcome sheet.
        ///
        /// Only for a household that is actually new: nothing at all written
        /// down yet — no chores, nothing to buy, no notes, nothing in the
        /// calendar — whether or not anybody else has joined. A household that
        /// simply does not use chores is not new, and neither is somebody who
        /// has kept a year of shopping lists on their own; a "Getting started"
        /// card over either would be talking to somebody who is not there.
        ///
        /// Not drawn while the answers are still arriving, or it would flash
        /// for everybody — and not on a members list that never arrived: a
        /// real answer always includes the person asking, so an empty one is
        /// a read that failed, not a household of nobody.
        public var showsSetup: Bool {
            guard !setupDone, !members.isEmpty,
                  loaded.contains([.members, .tasks, .stats, .upcoming])
            else { return false }
            let isEmpty = tasks.isEmpty && stats.shoppingItems == 0 && stats.notes == 0 && upcoming.isEmpty
            guard isEmpty else { return false }
            return finishedSetup.count < SetupStep.allCases.count
        }

        // MARK: The sentence

        /// The day in one sentence, from the parts in `GlanceClause`.
        ///
        /// At most three: what is wrong, then tonight, then chores, then what
        /// is next — and "All clear" when the first three have nothing to say,
        /// because a quiet day led by "Ece's birthday on Friday" reads like a
        /// reminder somebody forgot to finish.
        public var glance: [GlanceClause] {
            var clauses: [GlanceClause] = []
            if let hero {
                clauses.append(.alarm(hero))
            } else if let first = needs.first {
                clauses.append(.alarm(first))
            }
            if let event = upcoming.first(where: { $0.isInProgress && !$0.isAllDay }) {
                clauses.append(.happening(event))
            } else if let event = upcoming.first(where: {
                !$0.isAllDay && !$0.isMultiDay && $0.start > now
                    && Calendar.current.isDate($0.start, inSameDayAs: now)
            }) {
                clauses.append(.eventToday(event))
            } else if let tonight {
                clauses.append(.tonight(tonight))
            }
            // Late or due today — the backlog of undated chores is on the
            // list below, but it is not what makes today a busy day, and
            // counting it meant a household with any backlog never read
            // "All clear".
            let endOfToday = Calendar.current.date(
                byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)
            ) ?? now
            let due = chores.count { task in
                guard !task.isCompleted, let date = task.dueDate?.date else { return false }
                return date < endOfToday
            }
            if due > 0 { clauses.append(.chores(due)) }
            guard !clauses.isEmpty else { return [] }
            if clauses.count < 3, let next = comingUp.first(where: {
                !Calendar.current.isDate($0.start, inSameDayAs: now)
            }) {
                clauses.append(.next(next))
            }
            return Array(clauses.prefix(3))
        }

        /// "Tuesday evening" — the eyebrow over the sentence.
        public var dayPart: DayPart { DayPart(now) }

        /// The name to greet: the first word of what the household calls this
        /// person, rather than a whole handle like "muratcankoc".
        public var greetingName: String? {
            guard let name = user?.displayName.split(separator: " ").first else { return nil }
            return String(name)
        }

        /// Whether "Tonight" is drawn: Automatic shows a dinner somebody has
        /// decided or the calendar is offering, because those are facts.
        /// Undecided, it stays off Today — the dock asks in the evening, and
        /// asking every morning is the nag the old card was.
        public var showsTonight: Bool {
            switch layout.visibility(of: .tonight) {
            case .off: false
            case .always: true
            case .automatic: tonight != nil || dinnerSuggestion != nil
            }
        }
    }

    public enum Action: Equatable {
        case task
        case statsUpdated(HomeStats)
        case billsUpdated([Bill])
        case issuesUpdated([HouseIssue])
        case tasksUpdated([HouseTask])
        case upcomingEventsUpdated([EventOccurrence])
        case membersUpdated([User])
        case loadFailed(AppError)
        /// One of the quiet reads failed: its part stops waiting, with nothing
        /// in it, and nobody is shown an alert over a section that would only
        /// ever have said "nothing here".
        case partFailed(State.Loaded)
        case taskToggled(TaskID)
        case toggleFailed(TaskID, wasCompleted: Bool, AppError)
        /// A ticked chore's moment on screen is over.
        case tickSettled(TaskID)
        case showMoreChoresTapped
        /// "I'll handle it" on an urgent problem.
        case issueClaimed(IssueID)
        case claimFailed(IssueID, previous: UserID?, AppError)
        case setupStepTapped(State.SetupStep)
        case setupClosed
        /// Asks about notifications if nobody has yet. Sent by `.task`.
        case askForNotificationsIfNeeded
        /// The tab has settled and nobody has been asked about notifications
        /// yet. Raised by an effect rather than from `.task` directly so the
        /// prompt lands on a drawn screen, not a blank one.
        case notificationPromptReady
        case notificationAuthorizationAnswered(Bool)
        /// Bubbled to the tab container, which owns navigation.
        case delegate(Delegate)
        case alert(PresentationAction<Alert>)

        public enum Delegate: Equatable {
            case openShoppingList
            case openNotes
            case openMessages
            case openMovieNight
            case openTasks
            /// The chore split. The tab holds no contribution state of its own
            /// — the screen behind this subscribes when it opens.
            case openContributions
            case openRecipe(Recipe)
            case openCalendar
            case openIssues
            case openFinance
            /// One problem, opened at itself.
            case openIssue(IssueID)
            case openStats
            case openCustomize
            case openEvent(EventOccurrence)
            /// Opening an event the tab only knows the *id* of — the occasion
            /// a meal plan points at.
            case openEventID(EventID, CalendarDay)
            /// Deciding, accepting or dressing up tonight's dinner: the sheet
            /// for all three belongs to the container.
            case decideDinner
            case acceptDinnerSuggestion
            case makeOccasion
            /// Inviting somebody, which lives in Settings with the invite code.
            case openInvite
            /// Adding a chore where the person is, in Add anything — not a
            /// trip to the chore list to find its add button.
            case addChore
            /// Permission was just granted here. `AppFeature` answers by asking
            /// iOS for a token and registering it with the backend.
            case notificationsEnabled
        }

        public enum Alert: Equatable {
            case enableNotifications
        }
    }

    private enum CancelID { case stats, tasks, events, members, bills, issues }

    /// How close a bill has to be before Today mentions it. Closer than the
    /// Finance screen's "due soon" week: Today is for what needs doing now.
    static let needsYouBillDays = 3

    /// How long a ticked chore stays on Today: long enough to see the tick
    /// land, and to tap it again if it was the wrong one.
    static let tickLinger: Duration = .milliseconds(1200)

    @Dependency(\.stats) var statsClient
    @Dependency(\.finance) var financeClient
    @Dependency(\.issues) var issuesClient
    @Dependency(\.tasks) var tasksClient
    @Dependency(\.events) var eventsClient
    @Dependency(\.homes) var homesClient
    @Dependency(\.push) var push
    @Dependency(\.continuousClock) var clock

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
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.stats, cancelInFlight: true),

                    .run { send in
                        // Only the rows; the Done window that travels with them
                        // is the Tasks screen's business.
                        for try await list in tasksClient.byHome(homeID) {
                            await send(.tasksUpdated(list.tasks))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.tasks, cancelInFlight: true),

                    .run { send in
                        // The same capped agenda At a glance reads, so the
                        // week's count is the same number in both places.
                        for try await events in eventsClient.upcoming(homeID, 20) {
                            await send(.upcomingEventsUpdated(events))
                        }
                    } catch: { _, send in
                        // An empty calendar is the normal case, and a list that
                        // cannot load is not worth an alert over the whole tab.
                        await send(.partFailed(.upcoming))
                    }
                    .cancellable(id: CancelID.events, cancelInFlight: true),

                    .run { send in
                        for try await members in homesClient.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, send in
                        await send(.partFailed(.members))
                    }
                    .cancellable(id: CancelID.members, cancelInFlight: true),

                    // "Needs you": the two things in the house with a date that
                    // can pass. Quiet on failure — the section simply stays
                    // away, which is also what it does when all is well.
                    .run { send in
                        for try await bills in financeClient.bills(homeID) {
                            await send(.billsUpdated(bills))
                        }
                    } catch: { _, send in
                        await send(.partFailed(.bills))
                    }
                    .cancellable(id: CancelID.bills, cancelInFlight: true),

                    .run { send in
                        for try await board in issuesClient.board(homeID) {
                            await send(.issuesUpdated(board.issues))
                        }
                    } catch: { _, send in
                        await send(.partFailed(.issues))
                    }
                    .cancellable(id: CancelID.issues, cancelInFlight: true),

                    .send(.askForNotificationsIfNeeded)
                )

            // The one place a newcomer is asked about notifications. Everyone
            // lands here — creating a home and joining one both end on this
            // tab — and it is the first screen where the ask means something,
            // because there is finally a household to be notified about.
            case .askForNotificationsIfNeeded:
                guard !state.hasAskedForNotifications else { return .none }
                return .run { send in
                    // A permission sheet over a tab that has not finished
                    // drawing reads as an ambush.
                    try? await clock.sleep(for: .seconds(1.5))
                    guard await push.authorizationStatus() == .notDetermined
                    else { return }
                    await send(.notificationPromptReady)
                }

            case let .billsUpdated(bills):
                state.loaded.insert(.bills)
                guard bills != state.bills else { return .none }
                state.bills = bills
                return .none

            case let .issuesUpdated(issues):
                state.loaded.insert(.issues)
                guard issues != state.issues else { return .none }
                state.issues = issues
                return .none

            // A read that failed quietly still stops its part of the screen
            // waiting. Without this a dead `finance:bills` left the sentence
            // greyed out for as long as the tab was open.
            case let .partFailed(part):
                state.loaded.insert(part)
                return .none

            case let .statsUpdated(stats):
                state.loaded.insert(.stats)
                guard stats != state.stats else { return .none }
                state.stats = stats
                return .none

            case let .membersUpdated(members):
                state.loaded.insert(.members)
                let incoming = IdentifiedArray(uniqueElements: members)
                guard incoming != state.members else { return .none }
                state.members = incoming
                return .none

            case let .upcomingEventsUpdated(events):
                // Marked answered before the comparison below, not after: a
                // household with nothing coming delivers an empty array that
                // matches the initial state, and an early return would leave it
                // waiting forever.
                state.loaded.insert(.upcoming)
                guard events != state.upcoming else { return .none }
                state.upcoming = events
                return .none

            case let .tasksUpdated(tasks):
                state.loaded.insert(.tasks)
                var incoming = IdentifiedArray(uniqueElements: tasks)
                // A chore ticked a moment ago keeps the tick the person just
                // gave it until its moment is over, even if the push carrying
                // the write has not landed yet.
                for id in state.justTicked {
                    incoming[id: id]?.isCompleted = state.tasks[id: id]?.isCompleted ?? true
                }
                guard incoming != state.tasks else { return .none }
                state.tasks = incoming
                return .none

            case let .loadFailed(error):
                // Everything stops waiting, not just the query that failed:
                // `loadFailed` does not say which one it was.
                state.loaded = [.stats, .tasks, .upcoming, .members, .bills, .issues]
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .taskToggled(id):
                guard let task = state.tasks[id: id] else { return .none }
                let newValue = !task.isCompleted
                // Optimistic: the checkbox answers the tap immediately, and the
                // live subscription confirms it a moment later. Confirms only —
                // the failure carries the value to put back, because nothing
                // else will.
                state.tasks[id: id]?.isCompleted = newValue
                state.justTicked.insert(id)
                return .merge(
                    .run { _ in
                        try await tasksClient.setCompleted(id, newValue)
                    } catch: { error, send in
                        await send(.toggleFailed(id, wasCompleted: task.isCompleted, AppError(error)))
                    },
                    .run { send in
                        try await clock.sleep(for: Self.tickLinger)
                        await send(.tickSettled(id))
                    }
                    .cancellable(id: id, cancelInFlight: true)
                )

            case let .tickSettled(id):
                state.justTicked.remove(id)
                return .none

            case let .toggleFailed(id, wasCompleted, error):
                // The write never happened, so the server has nothing to push
                // and no correction is on its way. The checkbox goes back here
                // or it stays wrong until something unrelated reloads the list.
                state.tasks[id: id]?.isCompleted = wasCompleted
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .showMoreChoresTapped:
                state.showsAllChores = true
                return .none

            case let .issueClaimed(id):
                guard let me = state.user?.id,
                      let index = state.issues.firstIndex(where: { $0.id == id })
                else { return .none }
                let previous = state.issues[index].assignedTo
                guard previous != me else { return .none }
                state.issues[index].assignedTo = me
                return .run { _ in
                    try await issuesClient.assign(id, me)
                } catch: { error, send in
                    await send(.claimFailed(id, previous: previous, AppError(error)))
                }

            case let .claimFailed(id, previous, error):
                if let index = state.issues.firstIndex(where: { $0.id == id }) {
                    state.issues[index].assignedTo = previous
                }
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .setupStepTapped(step):
                switch step {
                case .invite: return .send(.delegate(.openInvite))
                case .firstChore: return .send(.delegate(.addChore))
                case .dinner: return .send(.delegate(.decideDinner))
                case .customize: return .send(.delegate(.openCustomize))
                }

            // Put away. It does not come back; everything on it is reachable
            // from where it always lives.
            case .setupClosed:
                state.$setupDone.withLock { $0 = true }
                return .none

            case .notificationPromptReady:
                // Marked as asked the moment the alert goes up, not when it is
                // answered: dismissing it is an answer too, and iOS only ever
                // shows its own prompt once.
                state.$hasAskedForNotifications.withLock { $0 = true }
                state.alert = .enableNotifications
                return .none

            case .alert(.presented(.enableNotifications)):
                return .run { send in
                    await send(.notificationAuthorizationAnswered(
                        push.requestAuthorization()
                    ))
                }

            case let .notificationAuthorizationAnswered(granted):
                guard granted else { return .none }
                return .send(.delegate(.notificationsEnabled))

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

/// One part of Today's sentence.
public enum GlanceClause: Equatable, Sendable {
    case alarm(HomeFeature.State.Alarm)
    case happening(EventOccurrence)
    case eventToday(EventOccurrence)
    case tonight(MealPlan)
    case chores(Int)
    case next(EventOccurrence)
}

/// Morning, afternoon, evening or night — said with the weekday in front.
public enum DayPart: Equatable, Sendable {
    case morning, afternoon, evening, night

    public init(_ date: Date, calendar: Calendar = .current) {
        switch calendar.component(.hour, from: date) {
        case 5..<12: self = .morning
        case 12..<DockItem.eveningStarts: self = .afternoon
        case DockItem.eveningStarts..<22: self = .evening
        default: self = .night
        }
    }
}

extension AlertState where Action == HomeFeature.Action.Alert {
    /// The soft ask that stands in front of the system prompt.
    ///
    /// iOS shows its own prompt exactly once per install and a "Don't Allow"
    /// is only reversible in Settings.app, so the reason comes first and the
    /// real prompt only follows a yes.
    static var enableNotifications: Self {
        AlertState {
            TextState(String(localized: L10n.notificationsPromptTitle))
        } actions: {
            ButtonState(action: .enableNotifications) {
                TextState(String(localized: L10n.notificationsPromptAllow))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.notificationsPromptNotNow))
            }
        } message: {
            TextState(String(localized: L10n.notificationsPromptMessage))
        }
    }
}
