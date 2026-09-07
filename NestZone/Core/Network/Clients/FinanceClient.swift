import ComposableArchitecture
import Foundation
import ConvexMobile

/// The household ledger: expenses, bills, budgets and who owes whom.
///
/// Every read is a live subscription, so an expense typed on one phone appears
/// on the other without either of them asking again. `summary` is the one the
/// screen actually draws from — balances, the settle-up plan, the category
/// split, six months of history and the budget progress all arrive computed
/// (see `convex/finance.ts`), rather than the phone downloading the ledger to
/// derive them the way the Home tab's counters used to be derived.
@DependencyClient
public struct FinanceClient: Sendable {
    /// One month of the ledger, newest first.
    public var expenses: @Sendable (HomeID, CalendarMonth)
        -> AsyncThrowingStream<[Expense], any Error> = { _, _ in .never }
    /// Everything the screen draws that is not a row, for one currency.
    ///
    /// Scoped to a currency because adding 500 lira to 20 dollars is not a
    /// number. `nil` asks for whichever the household mostly uses, which is
    /// what the screen opens on; the answer says which one it picked.
    public var summary: @Sendable (HomeID, CalendarMonth, String?)
        -> AsyncThrowingStream<FinanceSummary, any Error> = { _, _, _ in .never }
    /// Live bills, soonest due first.
    public var bills: @Sendable (HomeID) -> AsyncThrowingStream<[Bill], any Error> = { _ in .never }
    public var budgets: @Sendable (HomeID) -> AsyncThrowingStream<[Budget], any Error> = { _ in .never }
    /// The most recent squarings-up.
    public var settlements: @Sendable (HomeID)
        -> AsyncThrowingStream<[Settlement], any Error> = { _ in .never }

    public var createExpense: @Sendable (NewExpense) async throws -> Void
    /// Edits keep the id and re-resolve the split, because changing the total
    /// of an equal split has to move everybody's share with it.
    public var updateExpense: @Sendable (ExpenseID, NewExpense) async throws -> Void
    public var removeExpense: @Sendable (ExpenseID) async throws -> Void

    public var createBill: @Sendable (NewBill) async throws -> Void
    public var updateBill: @Sendable (BillID, NewBill) async throws -> Void
    /// Writes the expense the bill just became and rolls its schedule forward,
    /// in one mutation. `amount` overrides the bill's own for a variable bill —
    /// power, water — and `paidBy` defaults to whoever tapped.
    public var payBill: @Sendable (BillID, UserID?, Int?) async throws -> Void
    public var removeBill: @Sendable (BillID) async throws -> Void

    /// Sets or replaces the monthly ceiling for one category.
    public var setBudget: @Sendable (HomeID, SpendCategory, Int, String) async throws -> Void
    public var removeBudget: @Sendable (BudgetID) async throws -> Void

    public var settle: @Sendable (NewSettlement) async throws -> Void
}

extension FinanceClient: DependencyKey {
    public static let liveValue = FinanceClient(
        expenses: { homeID, month in
            ConvexConnection.shared.subscribe(
                to: "finance:listExpenses",
                args: monthArgs(homeID, month),
                as: [Expense].self
            )
        },
        summary: { homeID, month, currency in
            var args = monthArgs(homeID, month)
            if let currency { args["currency"] = currency }
            return ConvexConnection.shared.subscribe(
                to: "finance:summary", args: args, as: FinanceSummary.self
            )
        },
        bills: { homeID in
            ConvexConnection.shared.subscribe(
                to: "finance:listBills", args: ["homeId": homeID], as: [Bill].self
            )
        },
        budgets: { homeID in
            ConvexConnection.shared.subscribe(
                to: "finance:listBudgets", args: ["homeId": homeID], as: [Budget].self
            )
        },
        settlements: { homeID in
            ConvexConnection.shared.subscribe(
                to: "finance:listSettlements", args: ["homeId": homeID], as: [Settlement].self
            )
        },

        createExpense: { new in
            try await ConvexConnection.shared.mutate(
                "finance:createExpense", args: try expenseArgs(new, homeID: new.homeID)
            )
        },
        updateExpense: { id, new in
            var args = try expenseArgs(new, homeID: nil)
            args["id"] = id
            try await ConvexConnection.shared.mutate("finance:updateExpense", args: args)
        },
        removeExpense: { id in
            try await ConvexConnection.shared.mutate("finance:removeExpense", args: ["id": id])
        },

        createBill: { new in
            var args = try billArgs(new)
            args["homeId"] = new.homeID
            try await ConvexConnection.shared.mutate("finance:createBill", args: args)
        },
        updateBill: { id, new in
            var args = try billArgs(new)
            args["id"] = id
            try await ConvexConnection.shared.mutate("finance:updateBill", args: args)
        },
        payBill: { id, paidBy, amount in
            var args: [String: ConvexEncodable?] = ["id": id]
            if let paidBy { args["paidBy"] = paidBy }
            if let amount { args["amount"] = amount.convexNumber }
            try await ConvexConnection.shared.mutate("finance:payBill", args: args)
        },
        removeBill: { id in
            try await ConvexConnection.shared.mutate("finance:removeBill", args: ["id": id])
        },

        setBudget: { homeID, category, limit, currency in
            guard limit > 0 else { throw AppError.validation(String(localized: L10n.financeErrorAmount)) }
            try await ConvexConnection.shared.mutate(
                "finance:setBudget",
                args: [
                    "homeId": homeID,
                    "category": category.rawValue,
                    "limit": limit.convexNumber,
                    "currency": currency,
                ]
            )
        },
        removeBudget: { id in
            try await ConvexConnection.shared.mutate("finance:removeBudget", args: ["id": id])
        },

        settle: { payment in
            guard payment.amount > 0 else {
                throw AppError.validation(String(localized: L10n.financeErrorAmount))
            }
            var args: [String: ConvexEncodable?] = [
                "homeId": payment.homeID,
                "fromUser": payment.from,
                "toUser": payment.to,
                "amount": payment.amount.convexNumber,
                "currency": payment.currency,
            ]
            if let note = payment.note, !note.isEmpty { args["note"] = note }
            try await ConvexConnection.shared.mutate("finance:settle", args: args)
        }
    )

    public static let testValue = FinanceClient()
}

// MARK: - Argument building

/// The month the query is being asked about, plus the offset it has to be read
/// in.
///
/// The server has no timezone. Without `tzOffsetMinutes` the month boundaries
/// would be UTC's, and a household in UTC+13 would find the first evening of
/// every month filed under the previous one.
private func monthArgs(_ homeID: HomeID, _ month: CalendarMonth) -> [String: ConvexEncodable?] {
    [
        "homeId": homeID,
        // `.convexNumber`, not a bare `Int`: convex-swift encodes an `Int` as
        // int64 and `v.number()` is float64, which the validator rejects
        // outright — the whole request, not just the field.
        "year": month.year.convexNumber,
        "month": month.month.convexNumber,
        "tzOffsetMinutes": (TimeZone.current.secondsFromGMT() / 60).convexNumber,
    ]
}

/// Shapes an expense for the wire.
///
/// Only the fields the chosen split mode actually uses are sent. An exact split
/// carrying leftover equal-split participants would have the server resolve the
/// wrong one of the two, and the amounts a person typed would silently not be
/// the amounts stored.
private func expenseArgs(
    _ new: NewExpense,
    homeID: HomeID?
) throws -> [String: ConvexEncodable?] {
    let title = new.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
        throw AppError.validation(String(localized: L10n.financeErrorTitle))
    }
    guard new.amount > 0 else {
        throw AppError.validation(String(localized: L10n.financeErrorAmount))
    }

    var args: [String: ConvexEncodable?] = [
        "title": title,
        "amount": new.amount.convexNumber,
        "currency": new.currency,
        "category": new.category.rawValue,
        "paidBy": new.paidBy,
        "spentAt": new.spentAt.convexMillis,
        "mode": new.mode.rawValue,
        // Always sent: the server reads it for an equal split and uses it as
        // the membership check for the others.
        "participants": new.participants.map { $0 as ConvexEncodable? },
    ]
    if let homeID { args["homeId"] = homeID }
    // Only on the way in. An edit that did not come from an event must not
    // silently unlink one that did — `finance:updateExpense` reads an absent
    // `eventId` as "leave it alone" and an explicit null as "unlink", and this
    // composer has no control that means the latter.
    if let eventID = new.eventID { args["eventId"] = eventID }

    switch new.mode {
    case .equal:
        guard !new.participants.isEmpty else {
            throw AppError.validation(String(localized: L10n.financeErrorParticipants))
        }
    case .shares:
        let weights = new.weights.filter { $0.weight > 0 }
        guard !weights.isEmpty else {
            throw AppError.validation(String(localized: L10n.financeErrorShares))
        }
        args["weights"] = weights.map {
            ExpenseWeightArgs(userId: $0.userID, weight: $0.weight) as ConvexEncodable?
        }
    case .exact:
        let exact = new.exact.filter { $0.amount > 0 }
        let sum = exact.reduce(0) { $0 + $1.amount }
        guard sum == new.amount else {
            throw AppError.validation(String(
                localized: L10n.financeErrorExactMismatch(
                    Money.text(sum, currency: new.currency),
                    Money.text(new.amount, currency: new.currency)
                )
            ))
        }
        args["exact"] = exact.map {
            ExpenseShareArgs(userId: $0.userID, amount: $0.amount.convexNumber) as ConvexEncodable?
        }
    }

    if let note = new.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
        args["note"] = note
    }
    return args
}

private func billArgs(_ new: NewBill) throws -> [String: ConvexEncodable?] {
    let title = new.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
        throw AppError.validation(String(localized: L10n.financeErrorTitle))
    }
    guard new.amount > 0 else {
        throw AppError.validation(String(localized: L10n.financeErrorAmount))
    }
    var args: [String: ConvexEncodable?] = [
        "title": title,
        "amount": new.amount.convexNumber,
        "currency": new.currency,
        "category": new.category.rawValue,
        "cycle": new.cycle.rawValue,
        "dueDate": new.dueDate.convexMillis,
        "autoSplit": new.autoSplit,
        // Always sent, so clearing every reminder actually clears them rather
        // than leaving the previous set standing.
        "reminders": new.reminders
            .sorted(by: >)
            .prefix(Bill.maxReminders)
            .map { $0.convexNumber as ConvexEncodable? },
    ]
    if let responsible = new.responsible { args["responsible"] = responsible }
    return args
}

/// The wire shape of one weighted share.
///
/// A dedicated `Encodable` rather than the model type: `ExpenseWeight` codes
/// its key as `user_id`, which is right for a *document* field, and mutation
/// arguments are camelCase. Convex validates strictly and rejects the whole
/// request on a name mismatch.
private struct ExpenseWeightArgs: Encodable, ConvexEncodable {
    let userId: UserID
    let weight: Double
}

private struct ExpenseShareArgs: Encodable, ConvexEncodable {
    let userId: UserID
    let amount: Double
}

extension DependencyValues {
    public var finance: FinanceClient {
        get { self[FinanceClient.self] }
        set { self[FinanceClient.self] = newValue }
    }
}
