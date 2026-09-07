import ComposableArchitecture
import Foundation

// The four sheets the Finance screen presents.
//
// They share one habit worth stating once: an amount is *edited as text* and
// stored as whole minor units. Not a `Decimal` binding with a currency format
// style — that field opens already holding "€0.00", so entering a number starts
// with deleting one, every time. A plain string starts empty, shows its
// placeholder, and is parsed by `Money.parse`, which is forgiving about which
// separator a person's keyboard gave them.

// MARK: - Expense

/// Adding or editing one expense.
///
/// The split is the substance of this sheet, not the amount. Three modes, each
/// with a live preview of what every person ends up carrying — the preview is
/// the point, because "two shares for us and one for the lodger" is an
/// abstraction until you can see it land as three numbers.
@Reducer
public struct ExpenseComposerFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var members: IdentifiedArrayOf<User>
        public var currentUserID: UserID?
        /// This expense's own currency. A household can hold a 500-lira bill
        /// and a 20-dollar one at once, so it travels on the document rather
        /// than being a property of the home.
        public var currency: String
        /// What the household already writes in, offered first in the picker.
        public var knownCurrencies: [String]
        /// The expense being edited, if this is an edit.
        public var editing: Expense?

        public var title = ""
        public var amountText = ""
        public var category: SpendCategory = .groceries
        public var paidBy: UserID
        public var spentAt: Date
        public var note = ""

        public var mode: SplitMode = .equal
        /// Who an equal split covers. Everybody, until somebody says otherwise.
        public var participants: Set<UserID> = []
        /// Weights for a share split, keyed by member.
        public var weights: [UserID: Double] = [:]
        /// Typed amounts for an exact split, as they were typed.
        public var exact: [UserID: String] = [:]

        public var isSubmitting = false
        public var inlineError: String?
        /// Bumped to shake the amount field when the exact split does not add
        /// up. A refusal has to be felt, not just read.
        public var shakes = 0

        public init(
            homeID: HomeID,
            members: IdentifiedArrayOf<User>,
            currentUserID: UserID?,
            currency: String,
            knownCurrencies: [String] = [],
            defaultDate: Date = Date(),
            editing: Expense? = nil
        ) {
            self.homeID = homeID
            self.members = members
            self.currentUserID = currentUserID
            self.currency = currency
            self.knownCurrencies = knownCurrencies
            self.editing = editing

            // A new expense was almost always paid by whoever is typing it in.
            self.paidBy = editing?.paidBy ?? currentUserID ?? members.first?.id ?? UserID("")
            self.spentAt = editing?.spentAt.date ?? defaultDate

            if let editing {
                title = editing.title
                amountText = Money.editableText(editing.amount, currency: editing.currency)
                category = editing.category
                note = editing.note ?? ""
                mode = editing.splitMode
                participants = Set(editing.splits.filter { $0.amount > 0 }.map(\.userID))
                // Reopening restores the shares that were *typed*, not the
                // amounts they resolved to — otherwise editing the total of a
                // 2:1 split silently turns it into an exact one.
                weights = Dictionary(
                    uniqueKeysWithValues: (editing.weights ?? []).map { ($0.userID, $0.weight) }
                )
                exact = Dictionary(
                    uniqueKeysWithValues: editing.splits.map {
                        ($0.userID, Money.editableText($0.amount, currency: editing.currency))
                    }
                )
            } else {
                participants = Set(members.ids)
                weights = Dictionary(uniqueKeysWithValues: members.ids.map { ($0, 1.0) })
            }
        }

        public var isEditing: Bool { editing != nil }

        /// The total, in whole minor units — the only form the server accepts.
        public var amountMinor: Int { Money.parse(amountText, currency: currency) }

        public var currencyOptions: [String] { Money.pickerCodes(used: knownCurrencies) }

        /// Members in a stable order, the payer's own row first.
        public var orderedMembers: [User] {
            members.sorted { lhs, rhs in
                if lhs.id == currentUserID { return true }
                if rhs.id == currentUserID { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                    == .orderedAscending
            }
        }

        /// What each person would end up carrying, as the sheet currently
        /// stands. The same arithmetic the server will run, so the preview and
        /// the stored ledger cannot disagree by a cent.
        public var preview: [ExpenseSplit] {
            switch mode {
            case .equal:
                return SplitMath.evenly(
                    amountMinor,
                    among: orderedMembers.map(\.id).filter { participants.contains($0) }
                )
            case .shares:
                return SplitMath.byWeight(
                    amountMinor,
                    weights: orderedMembers.compactMap { member in
                        guard let weight = weights[member.id], weight > 0 else { return nil }
                        return ExpenseWeight(userID: member.id, weight: weight)
                    }
                )
            case .exact:
                return orderedMembers.compactMap { member in
                    guard let typed = exact[member.id] else { return nil }
                    let minor = Money.parse(typed, currency: currency)
                    return minor > 0 ? ExpenseSplit(userID: member.id, amount: minor) : nil
                }
            }
        }

        public func share(of userID: UserID) -> Int {
            preview.first { $0.userID == userID }?.amount ?? 0
        }

        /// What the typed amounts add up to, for the exact mode's running
        /// total.
        public var exactTotal: Int { preview.reduce(0) { $0 + $1.amount } }

        /// How far the exact split is from the expense. Zero means it balances;
        /// the sign says which way it is out.
        public var exactRemainder: Int { amountMinor - exactTotal }

        public var isBalanced: Bool { mode != .exact || exactRemainder == 0 }

        public var canSubmit: Bool {
            guard !isSubmitting else { return false }
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            guard amountMinor > 0 else { return false }
            guard !preview.isEmpty else { return false }
            return isBalanced
        }

        /// The payload this sheet would write.
        var payload: NewExpense {
            NewExpense(
                homeID: homeID,
                title: title,
                amount: amountMinor,
                currency: currency,
                category: category,
                paidBy: paidBy,
                spentAt: spentAt,
                mode: mode,
                // Participants travel whatever the mode: the server reads them
                // for an equal split and uses them as its membership check for
                // the other two.
                participants: orderedMembers.map(\.id).filter { participants.contains($0) },
                weights: orderedMembers.compactMap { member in
                    guard let weight = weights[member.id], weight > 0 else { return nil }
                    return ExpenseWeight(userID: member.id, weight: weight)
                },
                exact: preview,
                note: note
            )
        }
    }

    public enum Action: BindableAction {
        case submitTapped
        case participantToggled(UserID)
        case weightChanged(UserID, Double)
        case everyoneTapped
        case onlyMeTapped
        case deleteTapped
        case saved
        case failed(AppError)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case saved
            /// Hands the delete back to the screen, which already has an
            /// undoable path for it.
            case deleteRequested(ExpenseID)
        }
    }

    @Dependency(\.finance) var finance

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                guard state.canSubmit else {
                    // An exact split that does not add up is the one refusal
                    // this sheet makes, so it says which way it is out rather
                    // than just going grey.
                    if !state.isBalanced {
                        state.shakes += 1
                        state.inlineError = String(localized: L10n.financeExactOff(
                            Money.text(abs(state.exactRemainder), currency: state.currency)
                        ))
                    }
                    return .none
                }
                state.isSubmitting = true
                state.inlineError = nil
                let payload = state.payload
                let editing = state.editing?.id
                return .run { send in
                    if let editing {
                        try await finance.updateExpense(editing, payload)
                    } else {
                        try await finance.createExpense(payload)
                    }
                    await send(.saved)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .participantToggled(id):
                if state.participants.contains(id) {
                    // Never down to nobody: an expense split between no one has
                    // no meaning, and the save button going grey with no
                    // explanation is not an answer.
                    guard state.participants.count > 1 else { return .none }
                    state.participants.remove(id)
                } else {
                    state.participants.insert(id)
                }
                return .none

            case let .weightChanged(id, weight):
                state.weights[id] = max(0, weight)
                return .none

            case .everyoneTapped:
                state.participants = Set(state.members.ids)
                return .none

            case .onlyMeTapped:
                guard let me = state.currentUserID else { return .none }
                state.participants = [me]
                return .none

            case .deleteTapped:
                guard let id = state.editing?.id else { return .none }
                return .send(.delegate(.deleteRequested(id)))

            case .saved:
                state.isSubmitting = false
                return .send(.delegate(.saved))

            case let .failed(error):
                state.isSubmitting = false
                guard !error.isSilent else { return .none }
                state.inlineError = error.errorDescription
                state.shakes += 1
                return .none

            // Switching mode carries the equal split's participants into the
            // other two, so a person who has already said "not the lodger" does
            // not have to say it twice.
            case .binding(\.mode):
                switch state.mode {
                case .equal:
                    break
                case .shares:
                    for member in state.members {
                        if state.weights[member.id] == nil {
                            state.weights[member.id] = state.participants.contains(member.id) ? 1 : 0
                        }
                    }
                case .exact:
                    // Seeded with the equal split, which is both the commonest
                    // starting point and a set of numbers that already adds up.
                    let seeded = SplitMath.evenly(
                        state.amountMinor,
                        among: state.orderedMembers.map(\.id).filter { state.participants.contains($0) }
                    )
                    state.exact = Dictionary(
                        uniqueKeysWithValues: seeded.map {
                            ($0.userID, Money.editableText($0.amount, currency: state.currency))
                        }
                    )
                }
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }
}

// MARK: - Bill

/// Adding or editing a recurring bill.
@Reducer
public struct BillComposerFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var members: IdentifiedArrayOf<User>
        /// This bill's own currency — the rent in one, the streaming service in
        /// another, and neither converted behind anybody's back.
        public var currency: String
        public var knownCurrencies: [String]
        public var editing: Bill?

        public var title = ""
        public var amountText = ""
        public var category: SpendCategory = .utilities
        public var cycle: BillCycle = .monthly
        public var dueDate: Date
        public var responsible: UserID?
        /// Whether paying it splits across the household.
        public var autoSplit = true
        /// Whole days before the due date to nudge everyone. A set, because the
        /// order they were tapped in is not information.
        public var reminders: Set<Int> = []

        public var isSubmitting = false
        public var inlineError: String?
        public var shakes = 0
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            homeID: HomeID,
            members: IdentifiedArrayOf<User>,
            currency: String,
            knownCurrencies: [String] = [],
            editing: Bill? = nil
        ) {
            self.homeID = homeID
            self.members = members
            self.currency = currency
            self.knownCurrencies = knownCurrencies
            self.editing = editing
            // A new bill defaults to next month rather than to today: a bill
            // due the moment it is created would open the screen already
            // overdue.
            self.dueDate = editing?.dueDate.date
                ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())
                ?? Date()

            if let editing {
                title = editing.title
                amountText = Money.editableText(editing.amount, currency: editing.currency)
                category = editing.category
                cycle = editing.cycle
                responsible = editing.responsible
                autoSplit = editing.autoSplit
                reminders = Set(editing.reminders)
            } else {
                // A new bill gets one nudge the day before. The default that
                // makes a reminder feature useful is the one nobody has to find.
                reminders = [1]
            }
        }

        public var isEditing: Bool { editing != nil }
        public var amountMinor: Int { Money.parse(amountText, currency: currency) }
        public var currencyOptions: [String] { Money.pickerCodes(used: knownCurrencies) }

        /// What this bill will cost the household every month, which is the
        /// figure that makes a yearly subscription comparable to the rent.
        public var monthlyCost: Int { cycle.monthlyEquivalent(of: amountMinor) }

        public var canSubmit: Bool {
            !isSubmitting
                && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && amountMinor > 0
        }

        /// Whether another nudge may be added.
        public var canAddReminder: Bool { reminders.count < Bill.maxReminders }

        var payload: NewBill {
            NewBill(
                homeID: homeID,
                title: title,
                amount: amountMinor,
                currency: currency,
                category: category,
                cycle: cycle,
                dueDate: dueDate,
                responsible: responsible,
                autoSplit: autoSplit,
                reminders: reminders.sorted(by: >)
            )
        }
    }

    public enum Action: BindableAction {
        case submitTapped
        case reminderToggled(Int)
        case deleteTapped
        case saved
        case failed(AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {
            case confirmDelete
        }

        public enum Delegate: Equatable {
            case saved
            case deleted(BillID)
        }
    }

    @Dependency(\.finance) var finance

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                let payload = state.payload
                let editing = state.editing?.id
                return .run { send in
                    if let editing {
                        try await finance.updateBill(editing, payload)
                    } else {
                        try await finance.createBill(payload)
                    }
                    await send(.saved)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .reminderToggled(days):
                if state.reminders.contains(days) {
                    state.reminders.remove(days)
                } else {
                    // Silently capped rather than refused: the chips that
                    // cannot be added go dim, so there is nothing to explain.
                    guard state.canAddReminder else { return .none }
                    state.reminders.insert(days)
                }
                return .none

            case .deleteTapped:
                guard state.editing != nil else { return .none }
                // Asked here rather than after the sheet closes: a confirmation
                // that appears on the screen behind the thing it is about has
                // lost the only context that made it answerable.
                state.alert = .confirmDeleteBill()
                return .none

            case .alert(.presented(.confirmDelete)):
                guard let id = state.editing?.id else { return .none }
                return .send(.delegate(.deleted(id)))

            case .saved:
                state.isSubmitting = false
                return .send(.delegate(.saved))

            case let .failed(error):
                state.isSubmitting = false
                guard !error.isSilent else { return .none }
                state.inlineError = error.errorDescription
                state.shakes += 1
                return .none

            case .binding, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == BillComposerFeature.Action.Alert {
    /// Deleting a bill. Says what survives it, because "delete" on a bill that
    /// has been paid for a year reasonably looks like it takes the history too.
    static func confirmDeleteBill() -> Self {
        AlertState {
            TextState(String(localized: L10n.financeDeleteBillTitle))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete) {
                TextState(String(localized: L10n.commonDelete))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.financeDeleteBillMessage))
        }
    }
}

// MARK: - Paying a bill

/// Recording a payment against a bill.
///
/// Prefilled with the bill's own amount, and editable, because half of a
/// household's bills are variable: the power bill is "about ninety" and the
/// water bill is whatever the meter said.
@Reducer
public struct PayBillFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var bill: Bill
        public var members: IdentifiedArrayOf<User>
        public var currentUserID: UserID?
        /// How many ways it splits, for the "each of you pays" line.
        public var memberCount: Int

        public var amountText: String
        public var paidBy: UserID
        public var isSubmitting = false
        public var inlineError: String?

        public init(
            bill: Bill,
            members: IdentifiedArrayOf<User>,
            currentUserID: UserID?,
            memberCount: Int
        ) {
            self.bill = bill
            self.members = members
            self.currentUserID = currentUserID
            self.memberCount = max(memberCount, 1)
            self.amountText = Money.editableText(bill.amount, currency: bill.currency)
            self.paidBy = currentUserID ?? bill.responsible ?? members.first?.id ?? UserID("")
        }

        public var amountMinor: Int { Money.parse(amountText, currency: bill.currency) }

        /// What one person carries, if the bill splits. The number people
        /// actually want before they agree to pay it.
        public var perPerson: Int {
            guard bill.autoSplit else { return amountMinor }
            return SplitMath.evenShare(amountMinor, ways: memberCount)
        }

        /// How far this payment is from the bill's usual figure. `nil` when it
        /// is exactly the expected amount, which is most of the time.
        public var difference: Int? {
            let delta = amountMinor - bill.amount
            return delta == 0 ? nil : delta
        }

        public var canSubmit: Bool { !isSubmitting && amountMinor > 0 }
    }

    public enum Action: BindableAction {
        case payTapped
        case paid
        case failed(AppError)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case paid(BillID)
        }
    }

    @Dependency(\.finance) var finance

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .payTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                let id = state.bill.id
                let payer = state.paidBy
                // Only sent when it differs, so an unchanged bill is paid for
                // exactly what it says rather than for a round-tripped copy of
                // its own figure.
                let override = state.amountMinor == state.bill.amount ? nil : state.amountMinor
                return .run { send in
                    try await finance.payBill(id, payer, override)
                    await send(.paid)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .paid:
                state.isSubmitting = false
                return .send(.delegate(.paid(state.bill.id)))

            case let .failed(error):
                state.isSubmitting = false
                guard !error.isSilent else { return .none }
                state.inlineError = error.errorDescription
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }
}

// MARK: - Budget

/// Setting the monthly ceiling for one category.
@Reducer
public struct BudgetEditorFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var category: SpendCategory
        /// Which categories this sheet may be pointed at. Creating offers every
        /// category without a ceiling yet; editing offers only its own, because
        /// moving a budget to another category is a different budget.
        public var choosableCategories: [SpendCategory]
        /// A budget's own currency. Spend is counted against it in that
        /// currency alone — a grocery budget set in lira must not fill up
        /// because somebody bought coffee in euros.
        public var currency: String
        public var knownCurrencies: [String]
        public var editing: Budget?
        public var limitText: String
        public var isSubmitting = false
        public var inlineError: String?

        public init(
            homeID: HomeID,
            category: SpendCategory,
            choosableCategories: [SpendCategory] = [],
            currency: String,
            knownCurrencies: [String] = [],
            editing: Budget? = nil
        ) {
            self.homeID = homeID
            self.category = category
            self.choosableCategories = choosableCategories.isEmpty ? [category] : choosableCategories
            self.currency = currency
            self.knownCurrencies = knownCurrencies
            self.editing = editing
            self.limitText = editing.map { Money.editableText($0.limit, currency: $0.currency) } ?? ""
        }

        public var isEditing: Bool { editing != nil }
        public var currencyOptions: [String] { Money.pickerCodes(used: knownCurrencies) }
        /// Whether there is a choice to present at all.
        public var canChooseCategory: Bool { !isEditing && choosableCategories.count > 1 }
        public var limitMinor: Int { Money.parse(limitText, currency: currency) }
        public var canSubmit: Bool { !isSubmitting && limitMinor > 0 }

        /// Rounded suggestions, so setting a first budget is a tap rather than
        /// a decision about the exact number of cents.
        public var suggestions: [Int] {
            let scale = NSDecimalNumber(decimal: Money.scale(for: currency)).intValue
            return [50, 100, 200, 400].map { $0 * scale }
        }
    }

    public enum Action: BindableAction {
        case suggestionTapped(Int)
        case submitTapped
        case deleteTapped
        case saved
        case failed(AppError)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case saved
            case deleted(BudgetID)
        }
    }

    @Dependency(\.finance) var finance

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .suggestionTapped(minor):
                state.limitText = Money.editableText(minor, currency: state.currency)
                return .none

            case .submitTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                let (homeID, category, limit, currency) =
                    (state.homeID, state.category, state.limitMinor, state.currency)
                return .run { send in
                    try await finance.setBudget(homeID, category, limit, currency)
                    await send(.saved)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .deleteTapped:
                guard let id = state.editing?.id else { return .none }
                // No confirmation: a budget holds no history, and putting it
                // back is one tap on the category it came from.
                return .send(.delegate(.deleted(id)))

            case .saved:
                state.isSubmitting = false
                return .send(.delegate(.saved))

            case let .failed(error):
                state.isSubmitting = false
                guard !error.isSilent else { return .none }
                state.inlineError = error.errorDescription
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }
}

// MARK: - Settling up

/// Squaring up.
///
/// Opens on the plan the server worked out — the fewest payments that would
/// clear every balance — because "who pays whom" is the question, and a form
/// asking a person to answer it themselves is asking them to do the arithmetic
/// the app was for.
@Reducer
public struct SettleUpFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        public var currency: String
        public var members: IdentifiedArrayOf<User>
        public var balances: [MemberFinance]
        public var transfers: [Transfer]

        /// The payment being recorded. Starts as the suggestion that involves
        /// the viewer, if there is one.
        public var from: UserID?
        public var to: UserID?
        public var amountText = ""
        public var note = ""

        public var isSubmitting = false
        public var inlineError: String?
        /// Which suggestions have already been recorded in this sitting, so a
        /// row cannot be tapped twice while the ledger catches up.
        public var recorded: Set<String> = []

        public init(
            homeID: HomeID,
            currentUserID: UserID?,
            currency: String,
            members: IdentifiedArrayOf<User>,
            balances: [MemberFinance],
            transfers: [Transfer]
        ) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.currency = currency
            self.members = members
            self.balances = balances
            self.transfers = transfers

            // Preload whichever suggested payment the viewer is part of. Most
            // people open this screen to settle their own debt, not to referee
            // somebody else's.
            let mine = transfers.first { $0.from == currentUserID || $0.to == currentUserID }
                ?? transfers.first
            if let mine {
                from = mine.from
                to = mine.to
                amountText = Money.editableText(mine.amount, currency: currency)
            }
        }

        public var amountMinor: Int { Money.parse(amountText, currency: currency) }

        public var canSubmit: Bool {
            guard !isSubmitting, let from, let to else { return false }
            return from != to && amountMinor > 0
        }

        public func name(for id: UserID?) -> String {
            guard let id else { return String(localized: L10n.financeSomeone) }
            if id == currentUserID { return String(localized: L10n.financeYou) }
            return members[id: id]?.displayName
                ?? balances.first { $0.userID == id }?.displayName
                ?? String(localized: L10n.financeSomeone)
        }

        /// The suggestions still worth showing.
        public var openTransfers: [Transfer] {
            transfers.filter { !recorded.contains($0.id) }
        }

        public var isSquare: Bool { balances.allSatisfy(\.isSettled) }
    }

    public enum Action: BindableAction {
        case suggestionTapped(Transfer)
        case recordTapped
        case recorded(String)
        case failed(AppError)
        case swapTapped
        case binding(BindingAction<State>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case settled
        }
    }

    @Dependency(\.finance) var finance

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .suggestionTapped(transfer):
                state.from = transfer.from
                state.to = transfer.to
                state.amountText = Money.editableText(transfer.amount, currency: state.currency)
                state.inlineError = nil
                return .none

            case .swapTapped:
                let from = state.from
                state.from = state.to
                state.to = from
                return .none

            case .recordTapped:
                guard state.canSubmit, let from = state.from, let to = state.to else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                let payment = NewSettlement(
                    homeID: state.homeID,
                    from: from,
                    to: to,
                    amount: state.amountMinor,
                    currency: state.currency,
                    note: state.note
                )
                let key = Transfer(from: from, to: to, amount: state.amountMinor).id
                return .run { send in
                    try await finance.settle(payment)
                    await send(.recorded(key))
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .recorded(key):
                state.isSubmitting = false
                state.recorded.insert(key)
                return .send(.delegate(.settled))

            case let .failed(error):
                state.isSubmitting = false
                guard !error.isSilent else { return .none }
                state.inlineError = error.errorDescription
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }
}
