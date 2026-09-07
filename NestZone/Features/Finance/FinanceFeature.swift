import ComposableArchitecture
import Foundation
import SwiftUI

/// Bills & Finance: the household's shared money.
///
/// Four views of one ledger, behind a month scrubber — what the month looks
/// like, every expense in it, the bills that are coming, and the ceilings the
/// household set itself. Balances are the exception and are deliberately not
/// month-scoped: what you owe somebody does not reset in January.
///
/// The screen holds almost no derived money. `summary` arrives computed —
/// balances, the settle-up plan, the category split, six months of history and
/// every budget's progress — because deriving those on-device would mean
/// downloading the whole ledger to draw one ring, which is the mistake the Home
/// tab's counters were built to stop making.
@Reducer
public struct FinanceFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, so their own row can say "You" and the balance card
        /// can be about them rather than about the household in the abstract.
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User> = []

        /// The month every figure on this screen except the balances is about.
        public var month: CalendarMonth = .current
        /// Which currency the aggregates are about. `nil` until somebody
        /// chooses — the server opens on whichever the household mostly uses
        /// and says which one that was.
        ///
        /// Scoped rather than converted, because adding 500 lira to 20 dollars
        /// is not a number and inventing a rate on a household's behalf is
        /// worse than showing them two sets of figures.
        public var selectedCurrency: String?
        public var section: Section = .overview

        public var summary: FinanceSummary = .empty
        public var expenses: IdentifiedArrayOf<Expense> = []
        public var bills: IdentifiedArrayOf<Bill> = []
        public var budgets: IdentifiedArrayOf<Budget> = []

        public var isLoading = true
        /// The ledger's filters. Not persisted: narrowing a list is a "show me
        /// this now", not a preference to be remembered a week later.
        public var search = ""
        public var categoryFilter: SpendCategory?
        /// Which slice of the donut is picked out, which is a different
        /// question from which category the ledger is filtered to.
        public var selectedSlice: SpendCategory?

        /// Swiped away, but not yet sent. The row is already gone from
        /// `expenses`; if the undo window closes without a tap, this is what
        /// gets deleted for real. One at a time — a second swipe commits the
        /// first, the way a mail client does.
        public var pendingDeletion: Expense?
        /// Rows this screen is pretending are gone while a delete sits out its
        /// undo window. The server still has them, so without this mask every
        /// live push would put them straight back.
        public var hidden: Set<ExpenseID> = []
        /// Bills whose payment is still in flight, so the button can say so
        /// rather than looking like it did nothing.
        public var paying: Set<BillID> = []
        /// Bumped when the household reaches square. Drives the one burst of
        /// confetti this app allows itself.
        public var settledCelebration = 0

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }

        /// The four faces of the screen.
        public enum Section: String, CaseIterable, Hashable, Sendable, Identifiable {
            case overview, ledger, bills, budgets

            public var id: String { rawValue }

            public var title: LocalizedStringResource {
                switch self {
                case .overview: L10n.financeSectionOverview
                case .ledger: L10n.financeSectionLedger
                case .bills: L10n.financeSectionBills
                case .budgets: L10n.financeSectionBudgets
                }
            }

            public var symbol: String {
                switch self {
                case .overview: "chart.pie.fill"
                case .ledger: "list.bullet.rectangle"
                case .bills: "calendar.badge.clock"
                case .budgets: "target"
                }
            }
        }

        // MARK: Derived

        /// What the household writes its money in. Comes from the ledger rather
        /// than from this device's locale, so two members on two phones read
        /// the same number the same way.
        public var currency: String { summary.displayCurrency }

        /// Every currency the household writes in. One is the normal case, and
        /// the picker stays off screen for it.
        public var currencies: [String] { summary.currencies }
        public var hasSeveralCurrencies: Bool { currencies.count > 1 }

        public func member(_ id: UserID?) -> User? {
            id.flatMap { members[id: $0] }
        }

        public func name(for id: UserID?) -> String {
            guard let id else { return String(localized: L10n.financeSomeone) }
            if id == currentUserID { return String(localized: L10n.financeYou) }
            return members[id: id]?.displayName
                ?? summary.members.first { $0.userID == id }?.displayName
                ?? String(localized: L10n.financeSomeone)
        }

        /// The viewer's own balance: positive if the household owes them.
        public var yourNet: Int { summary.net(for: currentUserID) }

        /// The payments this person is part of, which is the only part of the
        /// settle-up plan most people ever act on.
        public var yourTransfers: [Transfer] {
            summary.transfers(involving: currentUserID)
        }

        /// The ledger, after the currency chips, the search field and the
        /// category chips.
        ///
        /// The currency is a filter and not just a heading: a day total that
        /// added 500 lira to 20 euros would be a number with no meaning, and
        /// the running total under the search field would be worse. A household
        /// that writes in one currency — nearly all of them — never sees this
        /// narrow anything.
        public var filteredExpenses: [Expense] {
            let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
            let scoped = hasSeveralCurrencies
                ? expenses.filter { $0.currency == currency }
                : Array(expenses)
            return scoped.filter { expense in
                if let categoryFilter, expense.category != categoryFilter { return false }
                guard !needle.isEmpty else { return true }
                return expense.title.localizedCaseInsensitiveContains(needle)
                    || (expense.note?.localizedCaseInsensitiveContains(needle) ?? false)
            }
        }

        /// The ledger under day headings, newest day first.
        ///
        /// Grouped by the *local* start of day: an expense entered at 11pm and
        /// one entered at 1am are two different days to the person who entered
        /// them, whatever the epoch stamps do.
        public var ledgerDays: [(day: Date, items: [Expense])] {
            let calendar = Calendar.current
            return Dictionary(grouping: filteredExpenses) {
                calendar.startOfDay(for: $0.spentAt.date)
            }
            .map { day, items in
                (day, items.sorted { Timestamp.newestFirst($0.spentAt, $1.spentAt) })
            }
            .sorted { $0.day > $1.day }
        }

        public func total(on day: Date) -> Int {
            ledgerDays.first { $0.day == day }?.items.reduce(0) { $0 + $1.amount } ?? 0
        }

        /// What the filtered ledger adds up to — the number that has to move
        /// when a filter is applied, or the filter looks broken.
        public var filteredTotal: Int {
            filteredExpenses.reduce(0) { $0 + $1.amount }
        }

        public var isFiltering: Bool {
            categoryFilter != nil || !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// The categories that actually appear this month, for the filter row.
        /// Offering all ten when three are in use is a menu, not a filter.
        public var presentCategories: [SpendCategory] {
            let scoped = hasSeveralCurrencies
                ? expenses.filter { $0.currency == currency }
                : Array(expenses)
            var seen: [SpendCategory] = []
            for expense in scoped where !seen.contains(expense.category) {
                seen.append(expense.category)
            }
            return seen.sorted { $0.rawValue < $1.rawValue }
        }

        /// Bills that have come due, soonest first — the ones that are actually
        /// asking for something.
        public var billsNeedingAttention: [Bill] {
            bills
                .filter { $0.urgency() <= .dueSoon }
                .sorted { $0.dueDate < $1.dueDate }
        }

        public var upcomingBills: [Bill] {
            bills
                .filter { $0.urgency() == .upcoming }
                .sorted { $0.dueDate < $1.dueDate }
        }

        // The bill counters are derived here rather than read off the summary.
        //
        // The summary is scoped to one currency, but the bill *list* is not —
        // every bill the household has is on screen whatever it is written in.
        // Taking the badges from the summary meant "2 overdue" over a list
        // showing three. These are a handful of rows already in memory, so
        // counting them where they are shown is both cheaper and honest.

        /// Bills already past their date, in any currency.
        public var overdueCount: Int {
            bills.count { $0.urgency() == .overdue }
        }

        /// Bills due within the week, in any currency.
        public var dueSoonCount: Int {
            bills.count { $0.urgency() == .dueToday || $0.urgency() == .dueSoon }
        }

        /// Every recurring bill in the selected currency, normalised to what it
        /// costs per month. Scoped, because this one is a sum.
        public var monthlyCommitted: Int {
            bills
                .filter { $0.currency == currency }
                .reduce(0) { $0 + $1.monthlyCost }
        }

        /// A budget with its id, so it can be edited, joined to the spend the
        /// server counted for it.
        ///
        /// The two halves arrive from different places on purpose: the limits
        /// are documents this screen can write, the spend is a figure only the
        /// server can total. In trouble first.
        public var budgetRows: [(budget: Budget, progress: BudgetProgress)] {
            budgets
                .map { budget in
                    // Spend comes from the server, counted in the budget's own
                    // currency rather than the one the screen is showing.
                    let spent = summary.budgets
                        .first { $0.category == budget.category }?.spent ?? 0
                    return (
                        budget,
                        BudgetProgress(
                            category: budget.category,
                            limit: budget.limit,
                            spent: spent,
                            currency: budget.currency
                        )
                    )
                }
                .sorted { $0.progress.progress > $1.progress.progress }
        }

        /// What the calendar is costing, newest first.
        ///
        /// Comes off the summary whole — the server scopes it to this screen's
        /// currency and totals each event over the event, not over the month on
        /// the scrubber. Which is the point: an expense for a party is dated to
        /// the party, so a deposit paid two months early is invisible in every
        /// month somebody would think to look in.
        public var eventRows: [EventSpend] { summary.events }

        /// Only worth a card once there is something in it.
        public var hasEventSpend: Bool { !summary.events.isEmpty }

        /// The title to print under a ledger row that was spent on something in
        /// the calendar. `nil` for ordinary money, and for a row whose event has
        /// since been deleted — the expense outlives the link.
        public func eventLabel(for expense: Expense) -> String? {
            guard expense.eventID != nil else { return nil }
            guard let title = expense.eventTitle?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ), !title.isEmpty else { return nil }
            return title
        }

        /// Categories with no ceiling yet, for the "add a budget" menu.
        public var unbudgetedCategories: [SpendCategory] {
            let taken = Set(budgets.map(\.category))
            return SpendCategory.allCases.filter { !taken.contains($0) }
        }

        /// Whether anything has arrived at all. Until it has, the balance card
        /// would be telling a household it knows nothing about that it is all
        /// square — which is the one thing it must never say by default.
        public var hasSummary: Bool { !summary.members.isEmpty }

        /// Whether this household has genuinely never tracked any money — as
        /// opposed to a quiet month in one that uses this all the time.
        ///
        /// Deliberately not `expenses.isEmpty`: that is only about the month on
        /// screen, so scrubbing to a quiet September would replace the whole
        /// overview with "no money tracked yet" and then replace it back. The
        /// test is `paid`, which is all-time — if nobody has ever put money
        /// down, and there are no bills and no budgets, there is nothing here.
        ///
        /// And deliberately `hasSummary` rather than `!isLoading`, which is the
        /// same trap one level up. Every month step sets `isLoading`, so gating
        /// on it *inverted this flag on every tap of the chevron*: a household
        /// with nothing tracked sat on the empty state, flipped to a full stack
        /// of redacted cards for as long as the month took to load, and flipped
        /// back. The whole screen changed twice to report nothing at all. What
        /// the guard is actually for is "we have not heard from the server
        /// yet", and that is what `hasSummary` says — it stays true across a
        /// reload, so this answer no longer depends on when it is asked.
        public var isBlank: Bool {
            hasSummary && bills.isEmpty && budgets.isEmpty
                && summary.members.allSatisfy { $0.paid == 0 && $0.isSettled }
        }

        /// Every member as a candidate payer, the viewer first — the person
        /// entering an expense paid for it far more often than not.
        public var payerOptions: [User] {
            members.sorted { lhs, rhs in
                if lhs.id == currentUserID { return true }
                if rhs.id == currentUserID { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                    == .orderedAscending
            }
        }
    }

    @Reducer
    public enum Destination {
        case composeExpense(ExpenseComposerFeature)
        case composeBill(BillComposerFeature)
        case payBill(PayBillFeature)
        case settleUp(SettleUpFeature)
        case editBudget(BudgetEditorFeature)
    }

    public enum Action: BindableAction {
        case task
        case summaryUpdated(FinanceSummary)
        /// Tagged with the month it was asked for. The payload is a bare array
        /// with no month on it, so the subscription has to say — otherwise the
        /// last push from the month you just left lands on the one you are now
        /// looking at.
        case expensesUpdated(CalendarMonth, [Expense])
        case billsUpdated([Bill])
        case budgetsUpdated([Budget])
        case membersUpdated([User])
        case loadFailed(AppError)

        case monthStepped(by: Int)
        case monthSelected(CalendarMonth)
        case currencySelected(String)
        case sectionSelected(State.Section)
        case categoryFilterTapped(SpendCategory?)
        case sliceSelected(SpendCategory?)

        case addExpenseTapped
        case expenseTapped(ExpenseID)
        case deleteExpenseTapped(ExpenseID)
        case undoDeleteTapped
        case deleteWindowClosed(ExpenseID)
        case deleteCommitFailed(Expense, AppError)

        case addBillTapped
        case billTapped(BillID)
        case payBillTapped(BillID)
        case quickPayTapped(BillID)
        case billPaid(BillID)
        case payFailed(BillID, AppError)

        case addBudgetTapped
        case budgetTapped(BudgetID)
        case billRestored(Bill)
        case budgetRestored(Budget)

        case settleUpTapped
        case writeFailed(AppError)

        case eventTapped(EventID, CalendarDay)

        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        /// Nothing to decide: the only alert this screen raises is a failure,
        /// and both destructive confirmations live inside the sheet that
        /// offered them — confirming a delete next to the thing being deleted
        /// beats confirming it on a screen the sheet has just uncovered.
        public enum Alert: Equatable {}

        public enum Delegate: Equatable {
            /// Open the event this money was spent on.
            ///
            /// A delegate rather than navigation this screen does itself: the
            /// calendar is a sibling module on the Hub's stack, and Finance
            /// does not get to know that. It says which event; the Hub knows
            /// where events are shown.
            case openEvent(EventID, CalendarDay)
        }
    }

    private enum CancelID { case summary, expenses, bills, budgets, members, undo }

    /// How long a swipe stays undoable. Long enough to notice the mistake,
    /// short enough that leaving the screen rarely cuts it short. The same
    /// window the shopping list uses, so the gesture means one thing app-wide.
    private static let undoWindow: Duration = .seconds(5)

    @Dependency(\.finance) var finance
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
                    subscribeToMonth(state.homeID, state.month, state.selectedCurrency),

                    .run { send in
                        for try await bills in finance.bills(homeID) {
                            await send(.billsUpdated(bills))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.bills, cancelInFlight: true),

                    .run { send in
                        for try await budgets in finance.budgets(homeID) {
                            await send(.budgetsUpdated(budgets))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.budgets, cancelInFlight: true),

                    .run { send in
                        for try await members in homes.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.members, cancelInFlight: true)
                )

            // MARK: Live pushes
            //
            // Every one of these lands far more often than the data changes.
            // Convex re-publishes *every* live query in the app whenever the
            // query set is modified, and stepping a month modifies it twice —
            // the summary and the expense subscriptions are both replaced — so
            // one tap on the chevron re-delivers identical bills, budgets and
            // members two or three times over.
            //
            // Assigning them anyway is not free. TCA skips the observation
            // notification only when the new value's *identity* matches, and a
            // plain model array has no identity to compare, so an identical
            // payload still invalidated every view reading it. Each handler
            // therefore compares before it writes, and a redundant push costs
            // nothing but the comparison.

            case let .summaryUpdated(summary):
                // The server echoes the month it was asked about. A payload for
                // any other one belongs to a month that has been scrubbed past
                // — applying it would put August's totals under September's
                // heading for as long as it took the right answer to arrive.
                guard CalendarMonth(year: summary.year, month: summary.month) == state.month else {
                    return .none
                }
                // Likewise for a currency that has been switched away from.
                if let wanted = state.selectedCurrency, summary.currency != wanted {
                    return .none
                }
                if summary != state.summary {
                    // Everyone square, having not been a moment ago. The one
                    // thing on this screen worth celebrating, and only on the
                    // transition — a household that is already settled gets no
                    // confetti every time the subscription pushes.
                    if !state.summary.isSquare, summary.isSquare, !state.summary.members.isEmpty {
                        state.settledCelebration += 1
                    }
                    state.summary = summary
                }
                // Only the summary clears this, and deliberately so. The
                // expense list is the smaller query and usually answers first;
                // letting it call the screen loaded showed every month-scoped
                // card still holding the *previous* month's figures until the
                // summary caught up.
                if state.isLoading { state.isLoading = false }
                return .none

            case let .expensesUpdated(month, expenses):
                guard month == state.month else { return .none }
                var incoming = IdentifiedArray(uniqueElements: expenses)
                // Anything the server has already dropped no longer needs
                // hiding; keeping it would leak the mask across a re-add.
                let stillHidden = state.hidden.intersection(incoming.ids)
                if stillHidden != state.hidden { state.hidden = stillHidden }
                for id in stillHidden { incoming.remove(id: id) }
                guard incoming != state.expenses else { return .none }
                state.expenses = incoming
                return .none

            case let .billsUpdated(bills):
                let incoming = IdentifiedArray(uniqueElements: bills)
                guard incoming != state.bills else { return .none }
                state.bills = incoming
                return .none

            case let .budgetsUpdated(budgets):
                let incoming = IdentifiedArray(uniqueElements: budgets)
                guard incoming != state.budgets else { return .none }
                state.budgets = incoming
                return .none

            case let .membersUpdated(members):
                let incoming = IdentifiedArray(uniqueElements: members)
                guard incoming != state.members else { return .none }
                state.members = incoming
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // MARK: Navigating the ledger

            case let .monthStepped(by: step):
                let next = state.month.advanced(by: step)
                // A ledger has no future. Stepping past the current month would
                // show an empty screen that looks like data loss.
                guard !next.isInFuture else { return .none }
                return move(&state, to: next)

            case let .monthSelected(month):
                guard !month.isInFuture, month != state.month else { return .none }
                return move(&state, to: month)

            // Another currency is another set of figures, which means another
            // subscription — the same shape as changing the month.
            case let .currencySelected(currency):
                guard currency != state.currency || state.selectedCurrency == nil else {
                    return .none
                }
                state.selectedCurrency = currency
                state.isLoading = true
                state.selectedSlice = nil
                return subscribeToMonth(state.homeID, state.month, currency)

            case let .sectionSelected(section):
                state.section = section
                return .none

            case let .categoryFilterTapped(category):
                // Tapping the active chip clears it, so the full list is always
                // one tap away without hunting for an "all" control.
                state.categoryFilter = state.categoryFilter == category ? nil : category
                return .none

            case let .sliceSelected(category):
                state.selectedSlice = category
                return .none

            // MARK: Expenses

            case .addExpenseTapped:
                state.destination = .composeExpense(ExpenseComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    currency: state.currency,
                    knownCurrencies: state.currencies,
                    // Adding an expense while looking at March should date it in
                    // March, not today — but only if March is over. Backfilling
                    // a past month is exactly why somebody scrubs to it.
                    defaultDate: state.month.isCurrent ? Date() : state.month.date
                ))
                return .none

            case let .expenseTapped(id):
                guard let expense = state.expenses[id: id] else { return .none }
                state.destination = .composeExpense(ExpenseComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    currency: expense.currency,
                    knownCurrencies: state.currencies,
                    editing: expense
                ))
                return .none

            case let .deleteExpenseTapped(id):
                guard let expense = state.expenses[id: id] else { return .none }
                // The row goes now — waiting for the server reads as a swipe
                // that did not take — but the write is held back until the undo
                // window closes, so undo cancels it rather than reversing it.
                state.expenses.remove(id: id)
                state.hidden.insert(id)
                let superseded = state.pendingDeletion
                state.pendingDeletion = expense

                return .merge(
                    // A second swipe ends the first one's window; that row was
                    // offered back and the offer was not taken.
                    superseded.map { commitDelete($0) } ?? .none,

                    .run { send in
                        try await clock.sleep(for: Self.undoWindow)
                        await send(.deleteWindowClosed(expense.id))
                    }
                    .cancellable(id: CancelID.undo, cancelInFlight: true)
                )

            case .undoDeleteTapped:
                guard let expense = state.pendingDeletion else { return .none }
                state.pendingDeletion = nil
                state.hidden.remove(expense.id)
                // Nothing was ever sent, so this is the whole restore. The live
                // subscription still holds the row and will agree.
                state.expenses.append(expense)
                return .cancel(id: CancelID.undo)

            case let .deleteWindowClosed(id):
                guard let expense = state.pendingDeletion, expense.id == id else { return .none }
                state.pendingDeletion = nil
                return commitDelete(expense)

            case let .deleteCommitFailed(expense, error):
                // The write never happened, and the mask would otherwise keep
                // hiding a row the server still has — a delete that quietly did
                // not delete, until the screen was reopened.
                state.hidden.remove(expense.id)
                state.expenses.append(expense)
                return .send(.writeFailed(error))

            // MARK: Bills

            case .addBillTapped:
                state.destination = .composeBill(BillComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currency: state.currency,
                    knownCurrencies: state.currencies
                ))
                return .none

            case let .billTapped(id):
                guard let bill = state.bills[id: id] else { return .none }
                state.destination = .composeBill(BillComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currency: bill.currency,
                    knownCurrencies: state.currencies,
                    editing: bill
                ))
                return .none

            case let .payBillTapped(id):
                guard let bill = state.bills[id: id], !state.paying.contains(id) else {
                    return .none
                }
                // A sheet rather than a straight write: half these bills are
                // variable — power, water — and paying one for last month's
                // figure is worse than one more tap. The fixed ones get the
                // one-tap path through `quickPayTapped` instead.
                state.destination = .payBill(PayBillFeature.State(
                    bill: bill,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    memberCount: max(state.members.count, 1)
                ))
                return .none

            // Rent, the same number every month: paying it should not need a
            // form. The row shows the amount, so this is not a blind write.
            case let .quickPayTapped(id):
                guard state.bills[id: id] != nil, !state.paying.contains(id) else { return .none }
                state.paying.insert(id)
                return .run { [payer = state.currentUserID] send in
                    try await finance.payBill(id, payer, nil)
                    await send(.billPaid(id))
                } catch: { error, send in
                    await send(.payFailed(id, AppError(error)))
                }

            case let .billPaid(id):
                state.paying.remove(id)
                return .none

            case let .payFailed(id, error):
                state.paying.remove(id)
                return .send(.writeFailed(error))

            // MARK: Budgets

            // One way in, from all three entry points: the sheet asks which
            // category. Two buttons that both said "Set a budget" and then did
            // different things — one jumping straight into whichever category
            // happened to be free first — was the confusing part.
            case .addBudgetTapped:
                state.destination = .editBudget(BudgetEditorFeature.State(
                    homeID: state.homeID,
                    category: state.unbudgetedCategories.first ?? .groceries,
                    choosableCategories: state.unbudgetedCategories,
                    currency: state.currency,
                    knownCurrencies: state.currencies
                ))
                return .none

            case let .budgetTapped(id):
                guard let budget = state.budgets[id: id] else { return .none }
                state.destination = .editBudget(BudgetEditorFeature.State(
                    homeID: state.homeID,
                    category: budget.category,
                    choosableCategories: [budget.category],
                    currency: budget.currency,
                    knownCurrencies: state.currencies,
                    editing: budget
                ))
                return .none

            // MARK: Settling up

            case .settleUpTapped:
                guard !state.summary.isSquare else { return .none }
                state.destination = .settleUp(SettleUpFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.currentUserID,
                    currency: state.currency,
                    members: state.members,
                    balances: state.summary.members,
                    transfers: state.summary.transfers
                ))
                return .none

            // MARK: Sheets reporting back

            // Every composer's save is optimistic in the same sense the rest of
            // the app's writes are: the sheet closes on success and the live
            // subscription brings the row in. Nothing is inserted by hand.
            case .destination(.presented(.composeExpense(.delegate(.saved)))),
                 .destination(.presented(.composeBill(.delegate(.saved)))),
                 .destination(.presented(.editBudget(.delegate(.saved)))),
                 .destination(.presented(.settleUp(.delegate(.settled)))):
                state.destination = nil
                return .none

            case .destination(.presented(.payBill(.delegate(.paid)))):
                state.destination = nil
                return .none

            // Deleting from the editor takes the same undoable path a swipe
            // does, rather than confirming separately: two ways to delete the
            // same row that behave differently is how an undo stops being
            // trusted.
            case let .destination(.presented(.composeExpense(.delegate(.deleteRequested(id))))):
                state.destination = nil
                return .send(.deleteExpenseTapped(id))

            // The sheet has already asked. The row goes now and comes back only
            // if the write actually failed.
            case let .destination(.presented(.composeBill(.delegate(.deleted(id))))):
                state.destination = nil
                let removed = state.bills.remove(id: id)
                return .run { _ in
                    try await finance.removeBill(id)
                } catch: { error, send in
                    if let removed { await send(.billRestored(removed)) }
                    await send(.writeFailed(AppError(error)))
                }

            case let .destination(.presented(.editBudget(.delegate(.deleted(id))))):
                state.destination = nil
                let removed = state.budgets.remove(id: id)
                return .run { _ in
                    try await finance.removeBudget(id)
                } catch: { error, send in
                    if let removed { await send(.budgetRestored(removed)) }
                    await send(.writeFailed(AppError(error)))
                }

            case let .billRestored(bill):
                state.bills.append(bill)
                return .none

            case let .budgetRestored(budget):
                state.budgets.append(budget)
                return .none

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .eventTapped(eventID, day):
                return .send(.delegate(.openEvent(eventID, day)))

            case .binding, .destination, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Effects

    /// Moves the whole screen to another month.
    ///
    /// Changing the month changes the arguments of two queries, which means two
    /// different subscriptions. `cancelInFlight` on a shared id retires the old
    /// pair, so a fast scrub cannot leave August's totals sitting under
    /// September's heading.
    private func move(_ state: inout State, to month: CalendarMonth) -> Effect<Action> {
        state.month = month
        state.isLoading = true
        state.selectedSlice = nil
        // The rows belong to the month being left. Holding them would show
        // August's expenses under September's day headings until the new list
        // arrived; the ledger's own skeleton covers the gap instead.
        state.expenses = []
        // The chip row only offers categories that appear in the month on
        // screen, so a filter carried across to a month without that category
        // would be invisible — and therefore impossible to clear.
        state.categoryFilter = nil
        return subscribeToMonth(state.homeID, month, state.selectedCurrency)
    }

    private func subscribeToMonth(
        _ homeID: HomeID,
        _ month: CalendarMonth,
        _ currency: String?
    ) -> Effect<Action> {
        .merge(
            .run { send in
                for try await summary in finance.summary(homeID, month, currency) {
                    await send(.summaryUpdated(summary))
                }
            } catch: { error, send in
                await send(.loadFailed(AppError(error)))
            }
            .cancellable(id: CancelID.summary, cancelInFlight: true),

            .run { send in
                for try await expenses in finance.expenses(homeID, month) {
                    await send(.expensesUpdated(month, expenses))
                }
            } catch: { error, send in
                await send(.loadFailed(AppError(error)))
            }
            .cancellable(id: CancelID.expenses, cancelInFlight: true)
        )
    }

    /// The write the swipe was always going to make, once nobody has undone it.
    ///
    /// Takes the whole expense rather than its id so a failure can put the row
    /// back: the screen dropped it optimistically and nothing else remembers it.
    private func commitDelete(_ expense: Expense) -> Effect<Action> {
        .run { _ in
            try await finance.removeExpense(expense.id)
        } catch: { error, send in
            await send(.deleteCommitFailed(expense, AppError(error)))
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly; declared
// here rather than via the deprecated `@Reducer(state:)` argument.
extension FinanceFeature.Destination.State: Equatable {}
