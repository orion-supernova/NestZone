import Foundation

// The household's money.
//
// Three shapes, deliberately kept apart:
//
//   `Expense`    — money that left the house, and who it left on behalf of
//   `Settlement` — money moved *between* members to square up. Never a spend,
//                  so it must never reach a category total or a budget
//   `Bill`       — a schedule, not a spend. Paying one writes an `Expense`
//
// Everything is in **minor units** — whole cents, kuruş, pence — as `Int`.
// Splitting is why: a three-way division of 10.00 has to come out as
// 3.34 + 3.33 + 3.33, and in `Double` euros it does not. The server owns that
// arithmetic (see `convex/finance.ts`); this side only ever displays it.

// MARK: - Money

/// Formatting and parsing for amounts held as whole minor units.
///
/// Not a wrapper type: an amount and its currency arrive as two fields on the
/// wire, arithmetic happens on the server, and a `Money` struct would only add
/// a box around an `Int` that every call site would immediately unwrap.
public enum Money {

    /// Currencies with no subunit at all. A yen amount of `1200` is ¥1,200, not
    /// ¥12.00, and dividing it by 100 would quietly make the household a
    /// hundred times poorer.
    ///
    /// Foundation exposes no public "minor units for this code" lookup, so this
    /// is the short list that actually turns up. Anything unknown gets two
    /// digits, which is right for all but a handful of currencies.
    private static let zeroDecimal: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG",
        "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF",
    ]

    /// Currencies with three subunit digits rather than two.
    private static let threeDecimal: Set<String> = ["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"]

    public static func fractionDigits(for currency: String) -> Int {
        let code = currency.uppercased()
        if zeroDecimal.contains(code) { return 0 }
        if threeDecimal.contains(code) { return 3 }
        return 2
    }

    /// The scale factor between the stored integer and the displayed amount.
    public static func scale(for currency: String) -> Decimal {
        Decimal(sign: .plus, exponent: fractionDigits(for: currency), significand: 1)
    }

    /// The displayable amount — `1234` in EUR becomes `12.34`.
    public static func decimal(_ minorUnits: Int, currency: String) -> Decimal {
        Decimal(minorUnits) / scale(for: currency)
    }

    /// The largest amount this app will carry, in minor units.
    ///
    /// Not an arbitrary tidiness limit. Amounts cross the wire as `v.number()`,
    /// which is float64 and exact only to 2^53, and the server does integer
    /// arithmetic on them — splitting, summing balances, totalling a month. A
    /// value past that stops adding up silently, which is the worst way for a
    /// ledger to fail. This sits three orders of magnitude below the limit and
    /// is still ten billion in any major unit.
    public static let maximumMinorUnits = 1_000_000_000_000

    /// How many characters an amount field will accept, which is what actually
    /// stops somebody reaching the cap. Room for the largest allowed amount
    /// plus its separator and subunits.
    public static let maximumInputLength = 15

    /// The other direction, rounded to the nearest whole minor unit and clamped
    /// to what the wire can carry.
    ///
    /// `NSDecimalRound` rather than `Int(truncating:)`: a typed 12.34 can land
    /// as 12.339999… once it has been through a text field, and truncation
    /// turns that into 1233 — an expense a cent short of what the person typed,
    /// every time, in one direction.
    ///
    /// The clamp is not decoration either: `NSDecimalNumber.intValue` on a
    /// value past `Int.max` returns nonsense rather than failing, so a pasted
    /// seventy-digit number would otherwise become an arbitrary amount.
    public static func minorUnits(_ amount: Decimal, currency: String) -> Int {
        var raw = amount * scale(for: currency)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 0, .plain)
        if rounded <= 0 { return 0 }
        if rounded >= Decimal(maximumMinorUnits) { return maximumMinorUnits }
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// The full form: `€12.34`.
    public static func text(_ minorUnits: Int, currency: String) -> String {
        decimal(minorUnits, currency: currency)
            .formatted(.currency(code: currency).locale(L10n.locale))
    }

    /// The same amount with the subunits dropped — `€12`.
    ///
    /// For the places where the cents are noise rather than information: a
    /// six-month bar chart's axis, a category legend, a tile on the Hub. Never
    /// for a row in the ledger, where the exact figure is the whole point.
    public static func compactText(_ minorUnits: Int, currency: String) -> String {
        decimal(minorUnits, currency: currency)
            .formatted(
                .currency(code: currency)
                    .locale(L10n.locale)
                    .precision(.fractionLength(0))
            )
    }

    /// Reads what somebody actually typed into an amount field.
    ///
    /// Deliberately forgiving. The field is a `decimalPad`, so the separator a
    /// person gets depends on their locale — and a shared household can have
    /// two locales on two phones. Everything but digits and separators is
    /// dropped, and the **last** separator is taken as the decimal point, which
    /// reads "1.234,56" and "1,234.56" identically. Grouping separators are not
    /// typed on a number pad, so there is nothing ambiguous left to lose.
    ///
    /// Anything unreadable comes back as zero rather than throwing: the save
    /// button is already disabled at zero, which is a better answer than an
    /// error message about a field somebody is still halfway through.
    public static func parse(_ text: String, currency: String) -> Int {
        let kept = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !kept.isEmpty else { return 0 }

        var normalised = kept
        if let separator = kept.lastIndex(where: { $0 == "." || $0 == "," }) {
            let whole = kept[..<separator].filter(\.isNumber)
            let fraction = kept[kept.index(after: separator)...].filter(\.isNumber)
            normalised = "\(whole).\(fraction)"
        }
        guard let value = Decimal(string: normalised, locale: Locale(identifier: "en_US_POSIX")) else {
            return 0
        }
        return minorUnits(value, currency: currency)
    }

    /// The plain form for an editable field: no symbol, no grouping, and the
    /// locale's own decimal separator so the keyboard and the text agree.
    public static func editableText(_ minorUnits: Int, currency: String) -> String {
        guard minorUnits != 0 else { return "" }
        return decimal(minorUnits, currency: currency).formatted(
            .number
                .locale(L10n.locale)
                .grouping(.never)
                .precision(.fractionLength(0...fractionDigits(for: currency)))
        )
    }

    /// What a household writes its money in, when nothing has been written yet.
    public static var deviceDefault: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// The codes a picker should offer, in the order somebody would look for
    /// them: what this household already uses, then this device's own, then
    /// everything else alphabetically.
    ///
    /// `commonISOCurrencyCodes` rather than the full ISO list — the full one
    /// includes funds and metals, and nobody splits a dinner in palladium.
    public static func pickerCodes(used: [String]) -> [String] {
        var seen = Set<String>()
        var codes: [String] = []
        for code in used + [deviceDefault] where seen.insert(code).inserted {
            codes.append(code)
        }
        for code in Locale.commonISOCurrencyCodes.sorted() where seen.insert(code).inserted {
            codes.append(code)
        }
        return codes
    }

    /// A currency's name in the reader's language, for a picker row that has to
    /// distinguish "SEK" from "SGD" at a glance.
    public static func name(for currency: String) -> String {
        L10n.locale.localizedString(forCurrencyCode: currency) ?? currency
    }
}

// MARK: - Category

/// Where a household's money goes.
///
/// Shared by expenses, bills and budgets — a budget that could name a category
/// no expense can carry would silently never fill. Presentation (colour,
/// symbol, title) lives in `Design`, the same way a contribution slice's colour
/// does.
public enum SpendCategory: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case groceries, utilities, rent, household, dining
    case transport, health, entertainment, subscriptions, other

    public var id: String { rawValue }
}

/// How an expense was divided.
public enum SplitMode: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    /// Straight down the middle, between whoever was picked.
    case equal
    /// Weighted — two shares for the couple, one for the lodger.
    case shares
    /// Typed amounts that have to add up to the total.
    case exact

    public var id: String { rawValue }
}

/// How often a bill comes round.
public enum BillCycle: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case once, weekly, biweekly, monthly, quarterly, yearly

    public var id: String { rawValue }

    /// What this cycle costs per month, for the "committed each month" figure.
    /// A one-off commits nothing: it is a single date, not a standing cost.
    public func monthlyEquivalent(of amount: Int) -> Int {
        switch self {
        case .once: 0
        case .weekly: Int((Double(amount) * 52 / 12).rounded())
        case .biweekly: Int((Double(amount) * 26 / 12).rounded())
        case .monthly: amount
        case .quarterly: Int((Double(amount) / 3).rounded())
        case .yearly: Int((Double(amount) / 12).rounded())
        }
    }
}

// MARK: - Expense

public struct ExpenseSplit: Codable, Hashable, Sendable, Identifiable {
    public let userID: UserID
    /// This person's share, in minor units.
    public var amount: Int

    public var id: UserID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case amount
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(UserID.self, forKey: .userID)
        amount = c.decodeNumber(forKey: .amount)
    }

    public init(userID: UserID, amount: Int) {
        self.userID = userID
        self.amount = amount
    }
}

/// What a split was *authored* as, so reopening the editor shows the two shares
/// somebody typed rather than the amounts those resolved to.
public struct ExpenseWeight: Codable, Hashable, Sendable, Identifiable {
    public let userID: UserID
    public var weight: Double

    public var id: UserID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case weight
    }

    public init(userID: UserID, weight: Double) {
        self.userID = userID
        self.weight = weight
    }
}

public struct Expense: Codable, Identifiable, Hashable, Sendable {
    public let id: ExpenseID
    public var title: String
    /// Total, in minor units.
    public var amount: Int
    public var currency: String
    public var category: SpendCategory
    /// Who actually put the money down.
    public var paidBy: UserID
    /// The resolved shares. Sums to `amount` exactly — the server sees to that.
    public var splits: [ExpenseSplit]
    public var splitMode: SplitMode
    public var weights: [ExpenseWeight]?
    public var note: String?
    /// When the money was spent, which is not always when it was entered.
    public var spentAt: Timestamp
    /// Set when this expense was logged by paying a recurring bill.
    public var billID: BillID?
    /// Set when the money was spent *on* something in the calendar — the
    /// caterer for Saturday's party, the tickets for the gig. A link, not an
    /// owner: deleting the event clears this and leaves the expense alone,
    /// because the money still moved.
    public var eventID: EventID?
    public var createdBy: UserID?
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, amount, currency, category, splits, note
        case paidBy = "paid_by"
        case splitMode = "split_mode"
        case weights
        case spentAt = "spent_at"
        case billID = "bill_id"
        case eventID = "event_id"
        case createdBy = "created_by"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ExpenseID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        amount = c.decodeNumber(forKey: .amount)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? Money.deviceDefault
        category = c.decodeLenient(SpendCategory.self, forKey: .category, default: .other)
        paidBy = try c.decode(UserID.self, forKey: .paidBy)
        splits = try c.decodeIfPresent([ExpenseSplit].self, forKey: .splits) ?? []
        splitMode = c.decodeLenient(SplitMode.self, forKey: .splitMode, default: .equal)
        weights = try c.decodeIfPresent([ExpenseWeight].self, forKey: .weights)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        spentAt = try c.decodeIfPresent(Timestamp.self, forKey: .spentAt)
            ?? Timestamp(milliseconds: 0)
        billID = try c.decodeIfPresent(BillID.self, forKey: .billID)
        eventID = try c.decodeIfPresent(EventID.self, forKey: .eventID)
        createdBy = try c.decodeIfPresent(UserID.self, forKey: .createdBy)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: ExpenseID,
        title: String,
        amount: Int,
        currency: String = "EUR",
        category: SpendCategory = .other,
        paidBy: UserID,
        splits: [ExpenseSplit] = [],
        splitMode: SplitMode = .equal,
        weights: [ExpenseWeight]? = nil,
        note: String? = nil,
        spentAt: Timestamp = Timestamp(Date()),
        billID: BillID? = nil,
        eventID: EventID? = nil,
        createdBy: UserID? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.paidBy = paidBy
        self.splits = splits
        self.splitMode = splitMode
        self.weights = weights
        self.note = note
        self.spentAt = spentAt
        self.billID = billID
        self.eventID = eventID
        self.createdBy = createdBy
        self.created = created
        self.updated = updated
    }
}

extension Expense {
    /// What one person carries of this expense.
    public func share(of userID: UserID) -> Int {
        splits.first { $0.userID == userID }?.amount ?? 0
    }

    /// Whether somebody is on the hook for any of it.
    public func involves(_ userID: UserID) -> Bool {
        paidBy == userID || splits.contains { $0.userID == userID && $0.amount != 0 }
    }

    /// The effect on one person's balance: positive if the house owes them for
    /// this, negative if they owe the house.
    public func impact(on userID: UserID) -> Int {
        (paidBy == userID ? amount : 0) - share(of: userID)
    }

    /// Came from paying a recurring bill rather than being typed by hand.
    public var isFromBill: Bool { billID != nil }

    /// Spent on something in the calendar.
    public var isForEvent: Bool { eventID != nil }
}

// MARK: - Settlement

/// A payment between two members, squaring up what the expenses say they owe.
public struct Settlement: Codable, Identifiable, Hashable, Sendable {
    public let id: SettlementID
    public var fromUser: UserID
    public var toUser: UserID
    public var amount: Int
    public var currency: String
    public var note: String?
    public var settledAt: Timestamp
    public var created: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case fromUser = "from_user"
        case toUser = "to_user"
        case amount, currency, note
        case settledAt = "settled_at"
        case created
    }

    public init(
        id: SettlementID,
        fromUser: UserID,
        toUser: UserID,
        amount: Int,
        currency: String = "EUR",
        note: String? = nil,
        settledAt: Timestamp = Timestamp(Date()),
        created: Timestamp? = nil
    ) {
        self.id = id
        self.fromUser = fromUser
        self.toUser = toUser
        self.amount = amount
        self.currency = currency
        self.note = note
        self.settledAt = settledAt
        self.created = created
    }
}

// MARK: - Bill

public struct Bill: Codable, Identifiable, Hashable, Sendable {
    public let id: BillID
    public var title: String
    public var amount: Int
    public var currency: String
    public var category: SpendCategory
    public var cycle: BillCycle
    /// Next payment due.
    public var dueDate: Timestamp
    /// Whose job it is to actually pay it.
    public var responsible: UserID?
    /// Whether paying it splits equally across the household.
    public var autoSplit: Bool
    public var isArchived: Bool
    /// Whole days before `dueDate` to nudge the household, e.g. `[3, 1, 0]`.
    /// At most three — a bill that pings four times is a bill people mute.
    public var reminders: [Int]
    public var lastPaidAt: Timestamp?
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, amount, currency, category, cycle, responsible, reminders
        case dueDate = "due_date"
        case autoSplit = "auto_split"
        case isArchived = "is_archived"
        case lastPaidAt = "last_paid_at"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(BillID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        amount = c.decodeNumber(forKey: .amount)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? Money.deviceDefault
        category = c.decodeLenient(SpendCategory.self, forKey: .category, default: .other)
        cycle = c.decodeLenient(BillCycle.self, forKey: .cycle, default: .monthly)
        dueDate = try c.decodeIfPresent(Timestamp.self, forKey: .dueDate)
            ?? Timestamp(milliseconds: 0)
        responsible = try c.decodeIfPresent(UserID.self, forKey: .responsible)
        autoSplit = try c.decodeIfPresent(Bool.self, forKey: .autoSplit) ?? true
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        // `v.number()` is float64, so the day offsets arrive as doubles.
        reminders = ((try? c.decodeIfPresent([Double].self, forKey: .reminders)) ?? [])?
            .map { Int($0.rounded()) } ?? []
        lastPaidAt = try c.decodeIfPresent(Timestamp.self, forKey: .lastPaidAt)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: BillID,
        title: String,
        amount: Int,
        currency: String = "EUR",
        category: SpendCategory = .utilities,
        cycle: BillCycle = .monthly,
        dueDate: Timestamp = Timestamp(Date()),
        responsible: UserID? = nil,
        autoSplit: Bool = true,
        isArchived: Bool = false,
        reminders: [Int] = [],
        lastPaidAt: Timestamp? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.cycle = cycle
        self.dueDate = dueDate
        self.responsible = responsible
        self.autoSplit = autoSplit
        self.isArchived = isArchived
        self.reminders = reminders
        self.lastPaidAt = lastPaidAt
        self.created = created
        self.updated = updated
    }
}

extension Bill {
    /// The offsets a reminder may be set to, furthest out first. Not a free
    /// number field: "remind me 11 days before" is a setting nobody wants, and
    /// every extra option is one more thing to read past.
    public static let reminderChoices = [7, 3, 2, 1, 0]

    /// A bill that pings four times is a bill people mute.
    public static let maxReminders = 3

    /// How urgent this bill is right now.
    ///
    /// Measured in whole days rather than in hours, because that is the unit
    /// the copy uses: a bill due in nine hours is "due today", and a countdown
    /// that flips to "overdue" at midnight is telling the truth.
    public enum Urgency: Int, Comparable, Hashable, Sendable {
        case overdue, dueToday, dueSoon, upcoming

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Days from `now` until it is due; negative once it is late.
    public func daysUntilDue(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let due = calendar.startOfDay(for: dueDate.date)
        return calendar.dateComponents([.day], from: today, to: due).day ?? 0
    }

    /// Anything landing inside this many days reads as "due soon".
    public static let dueSoonWindow = 7

    public func urgency(now: Date = Date()) -> Urgency {
        let days = daysUntilDue(now: now)
        if days < 0 { return .overdue }
        if days == 0 { return .dueToday }
        if days <= Self.dueSoonWindow { return .dueSoon }
        return .upcoming
    }

    /// What this bill commits the household to every month.
    public var monthlyCost: Int { cycle.monthlyEquivalent(of: amount) }
}

// MARK: - Budget

public struct Budget: Codable, Identifiable, Hashable, Sendable {
    public let id: BudgetID
    public var category: SpendCategory
    /// Monthly ceiling, in minor units.
    public var limit: Int
    public var currency: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case category, limit, currency
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(BudgetID.self, forKey: .id)
        category = c.decodeLenient(SpendCategory.self, forKey: .category, default: .other)
        limit = c.decodeNumber(forKey: .limit)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? Money.deviceDefault
    }

    public init(id: BudgetID, category: SpendCategory, limit: Int, currency: String = "EUR") {
        self.id = id
        self.category = category
        self.limit = limit
        self.currency = currency
    }
}

// MARK: - Summary

/// Everything the Finance screen draws, computed server-side in one pass.
///
/// Balances are all-time and the spend figures are month-scoped, and that
/// asymmetry is the point: what you owe somebody does not reset in January, but
/// what the household spent very much does.
public struct FinanceSummary: Codable, Hashable, Sendable {
    public var year: Int
    public var month: Int
    /// What the household actually writes its money in, taken from the ledger
    /// rather than from this device's locale — so two members on two phones
    /// read the same number the same way. `nil` until anything has been logged.
    public var currency: String?
    /// Every currency the household actually writes in, most-used first. The
    /// screen offers these and nothing else — a picker of 150 ISO codes is a
    /// worse answer than the three a household really uses.
    public var currencies: [String]
    public var monthTotal: Int
    public var previousMonthTotal: Int
    public var expenseCount: Int
    public var members: [MemberFinance]
    /// The fewest payments that would clear every balance.
    public var transfers: [Transfer]
    public var series: [SpendPoint]
    public var categories: [CategoryTotal]
    public var budgets: [BudgetProgress]

    enum CodingKeys: String, CodingKey {
        case year, month, currency, currencies, monthTotal, previousMonthTotal, expenseCount
        case members, transfers, series, categories, budgets
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        year = c.decodeNumber(forKey: .year)
        month = c.decodeNumber(forKey: .month)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        currencies = try c.decodeIfPresent([String].self, forKey: .currencies) ?? []
        monthTotal = c.decodeNumber(forKey: .monthTotal)
        previousMonthTotal = c.decodeNumber(forKey: .previousMonthTotal)
        expenseCount = c.decodeNumber(forKey: .expenseCount)
        members = try c.decodeIfPresent([MemberFinance].self, forKey: .members) ?? []
        transfers = try c.decodeIfPresent([Transfer].self, forKey: .transfers) ?? []
        series = try c.decodeIfPresent([SpendPoint].self, forKey: .series) ?? []
        categories = try c.decodeIfPresent([CategoryTotal].self, forKey: .categories) ?? []
        budgets = try c.decodeIfPresent([BudgetProgress].self, forKey: .budgets) ?? []
    }

    public init(
        year: Int = 0,
        month: Int = 0,
        currency: String? = nil,
        currencies: [String] = [],
        monthTotal: Int = 0,
        previousMonthTotal: Int = 0,
        expenseCount: Int = 0,
        members: [MemberFinance] = [],
        transfers: [Transfer] = [],
        series: [SpendPoint] = [],
        categories: [CategoryTotal] = [],
        budgets: [BudgetProgress] = []
    ) {
        self.year = year
        self.month = month
        self.currency = currency
        self.currencies = currencies
        self.monthTotal = monthTotal
        self.previousMonthTotal = previousMonthTotal
        self.expenseCount = expenseCount
        self.members = members
        self.transfers = transfers
        self.series = series
        self.categories = categories
        self.budgets = budgets
    }

    public static let empty = FinanceSummary()
}

/// One person's standing in the household ledger.
public struct MemberFinance: Codable, Identifiable, Hashable, Sendable {
    public let userID: UserID
    public var name: String?
    public var email: String?
    /// False for somebody who has left but still owes or is owed. Their balance
    /// stays visible rather than walking out of the house with them.
    public var isMember: Bool
    /// All-time, in minor units.
    public var paid: Int
    public var owed: Int
    /// Positive means the household owes them.
    public var net: Int
    public var paidThisMonth: Int
    public var shareThisMonth: Int

    public var id: UserID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case name, email, isMember, paid, owed, net, paidThisMonth, shareThisMonth
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(UserID.self, forKey: .userID)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        isMember = try c.decodeIfPresent(Bool.self, forKey: .isMember) ?? true
        paid = c.decodeNumber(forKey: .paid)
        owed = c.decodeNumber(forKey: .owed)
        net = c.decodeNumber(forKey: .net)
        paidThisMonth = c.decodeNumber(forKey: .paidThisMonth)
        shareThisMonth = c.decodeNumber(forKey: .shareThisMonth)
    }

    public init(
        userID: UserID,
        name: String? = nil,
        email: String? = nil,
        isMember: Bool = true,
        paid: Int = 0,
        owed: Int = 0,
        net: Int = 0,
        paidThisMonth: Int = 0,
        shareThisMonth: Int = 0
    ) {
        self.userID = userID
        self.name = name
        self.email = email
        self.isMember = isMember
        self.paid = paid
        self.owed = owed
        self.net = net
        self.paidThisMonth = paidThisMonth
        self.shareThisMonth = shareThisMonth
    }
}

extension MemberFinance {
    /// The same fallback chain as `User.displayName`, so the same person is
    /// named the same way on every screen.
    public var displayName: String { User.displayName(name: name, email: email) }
    public var initials: String { User.initials(from: displayName) }
    public var isSettled: Bool { net == 0 }
}

/// One payment that would move the household closer to square.
public struct Transfer: Codable, Identifiable, Hashable, Sendable {
    public let from: UserID
    public let to: UserID
    public var amount: Int

    public var id: String { "\(from.rawValue)->\(to.rawValue)" }

    enum CodingKeys: String, CodingKey { case from, to, amount }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        from = try c.decode(UserID.self, forKey: .from)
        to = try c.decode(UserID.self, forKey: .to)
        amount = c.decodeNumber(forKey: .amount)
    }

    public init(from: UserID, to: UserID, amount: Int) {
        self.from = from
        self.to = to
        self.amount = amount
    }
}

/// One bar of the six-month spend chart.
public struct SpendPoint: Codable, Identifiable, Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var total: Int

    public var id: String { "\(year)-\(month)" }

    enum CodingKeys: String, CodingKey { case year, month, total }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        year = c.decodeNumber(forKey: .year)
        month = c.decodeNumber(forKey: .month)
        total = c.decodeNumber(forKey: .total)
    }

    public init(year: Int, month: Int, total: Int) {
        self.year = year
        self.month = month
        self.total = total
    }

    /// First of the month, for formatting the label.
    public var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
    }
}

public struct CategoryTotal: Codable, Identifiable, Hashable, Sendable {
    public var category: SpendCategory
    public var total: Int

    public var id: SpendCategory { category }

    enum CodingKeys: String, CodingKey { case category, total }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        category = c.decodeLenient(SpendCategory.self, forKey: .category, default: .other)
        total = c.decodeNumber(forKey: .total)
    }

    public init(category: SpendCategory, total: Int) {
        self.category = category
        self.total = total
    }
}

/// A budget and how much of it the month has eaten.
public struct BudgetProgress: Codable, Identifiable, Hashable, Sendable {
    public var category: SpendCategory
    public var limit: Int
    public var spent: Int
    /// The budget's own currency, which is not necessarily the one the screen
    /// is showing: a grocery budget set in lira is about lira groceries, and it
    /// must not fill up because somebody bought coffee in euros.
    public var currency: String

    public var id: SpendCategory { category }

    enum CodingKeys: String, CodingKey { case category, limit, spent, currency }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        category = c.decodeLenient(SpendCategory.self, forKey: .category, default: .other)
        limit = c.decodeNumber(forKey: .limit)
        spent = c.decodeNumber(forKey: .spent)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? Money.deviceDefault
    }

    public init(category: SpendCategory, limit: Int, spent: Int, currency: String = "EUR") {
        self.category = category
        self.limit = limit
        self.spent = spent
        self.currency = currency
    }

    /// How much of the ceiling is used, uncapped — a ring needs to know it is
    /// at 140%, not that it is full.
    public var progress: Double {
        limit > 0 ? Double(spent) / Double(limit) : 0
    }

    public var remaining: Int { limit - spent }
    public var isOver: Bool { spent > limit }

    /// The band the ring draws in. `.close` starts at four fifths, which is far
    /// enough in to be a warning and late enough not to cry wolf all month.
    public enum Health: Hashable, Sendable {
        case healthy, close, over

        init(progress: Double) {
            switch progress {
            case ..<0.8: self = .healthy
            case 0.8..<1: self = .close
            default: self = .over
            }
        }
    }

    public var health: Health { Health(progress: progress) }
}

// MARK: - Derived

extension FinanceSummary {
    /// Nothing has been spent in the selected month *and* nobody owes anybody —
    /// i.e. there is genuinely nothing to draw, rather than a quiet month.
    public var isEmpty: Bool {
        monthTotal == 0 && members.allSatisfy(\.isSettled)
    }

    /// The currency to format in. Falls back to the device only while the
    /// ledger is empty and has nothing to say about it.
    public var displayCurrency: String { currency ?? Money.deviceDefault }

    public func member(_ userID: UserID?) -> MemberFinance? {
        userID.flatMap { id in members.first { $0.userID == id } }
    }

    /// One person's balance: positive if the house owes them.
    public func net(for userID: UserID?) -> Int { member(userID)?.net ?? 0 }

    /// Everyone the viewer is square with, dropped — a settled household shows
    /// one calm line rather than four zeroes.
    public var outstanding: [MemberFinance] {
        members
            .filter { !$0.isSettled }
            .sorted { $0.net > $1.net }
    }

    public var isSquare: Bool { outstanding.isEmpty }

    /// Month-over-month change as a fraction. `nil` when the previous month was
    /// empty, where a percentage would be either infinite or a lie.
    public var monthChange: Double? {
        guard previousMonthTotal > 0 else { return nil }
        return Double(monthTotal - previousMonthTotal) / Double(previousMonthTotal)
    }

    /// The tallest bar in the six-month chart. At least 1, so an empty history
    /// draws a flat baseline rather than dividing by zero.
    public var busiestMonth: Int { max(series.map(\.total).max() ?? 0, 1) }

    /// The month the screen is showing, as a date, for formatting its name.
    public var monthDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
    }

    /// Category shares of the month's spend, biggest first, as fractions of 1.
    public var categoryShares: [(total: CategoryTotal, share: Double)] {
        guard monthTotal > 0 else { return [] }
        return categories.map { ($0, Double($0.total) / Double(monthTotal)) }
    }

    /// Everyone who put money down this month, biggest first. Ties break on
    /// name so the order never flickers between two people on the same figure.
    public var payers: [MemberFinance] {
        members
            .filter { $0.paidThisMonth > 0 }
            .sorted {
                $0.paidThisMonth != $1.paidThisMonth
                    ? $0.paidThisMonth > $1.paidThisMonth
                    : $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    /// The biggest single share of this month's spend, for scaling the bars.
    public var topPayment: Int { max(payers.first?.paidThisMonth ?? 0, 1) }

    /// Budgets in the order they matter: the ones in trouble first.
    public var rankedBudgets: [BudgetProgress] {
        budgets.sorted {
            $0.progress != $1.progress
                ? $0.progress > $1.progress
                : $0.category.rawValue < $1.category.rawValue
        }
    }

    /// Transfers that involve one particular person, which is the only part of
    /// the settle-up plan most people ever act on.
    public func transfers(involving userID: UserID?) -> [Transfer] {
        guard let userID else { return transfers }
        return transfers.filter { $0.from == userID || $0.to == userID }
    }
}

// MARK: - Month

/// A year and a month, which is the unit this screen navigates in.
///
/// Not a `Date`: "September 2026" is a calendar page, not an instant, and every
/// bug in a month scrubber comes from picking an instant inside the month and
/// then watching a timezone or a 31st push it into a neighbour. Arithmetic goes
/// through `Calendar`, so December advances to January of the next year.
public struct CalendarMonth: Hashable, Sendable, Comparable, Identifiable, Codable {
    public var year: Int
    /// 1-12.
    public var month: Int

    public var id: String { "\(year)-\(month)" }

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(containing date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.year = parts.year ?? 1970
        self.month = parts.month ?? 1
    }

    public static var current: Self { Self(containing: Date()) }

    /// First instant of the month, local — for formatting its name.
    public var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
    }

    /// `offset` months later; negative goes back.
    public func advanced(by offset: Int) -> Self {
        let calendar = Calendar.current
        guard let moved = calendar.date(byAdding: .month, value: offset, to: date) else {
            return self
        }
        return Self(containing: moved, calendar: calendar)
    }

    public var isCurrent: Bool { self == .current }

    /// Whether this month has not happened yet. The scrubber refuses to go
    /// past it — a ledger has no future to show.
    public var isInFuture: Bool { self > .current }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.year != rhs.year ? lhs.year < rhs.year : lhs.month < rhs.month
    }
}

// MARK: - Writes

/// Everything needed to write an expense. The split is described rather than
/// resolved: the server does the arithmetic, so no client version can write a
/// ledger whose shares do not add up to its total.
public struct NewExpense: Equatable, Sendable {
    public var homeID: HomeID
    public var title: String
    /// Minor units.
    public var amount: Int
    public var currency: String
    public var category: SpendCategory
    public var paidBy: UserID
    public var spentAt: Date
    public var mode: SplitMode
    /// Who it is split between, for an equal split.
    public var participants: [UserID]
    /// Weights, for a share split.
    public var weights: [ExpenseWeight]
    /// Typed amounts, for an exact split. Must add up to `amount`.
    public var exact: [ExpenseSplit]
    public var note: String?
    /// The event this was spent on, when the composer was opened from one.
    /// Carried through the composer untouched — the sheet never shows it,
    /// because "which event" was answered by where the button was.
    public var eventID: EventID?

    public init(
        homeID: HomeID,
        title: String,
        amount: Int,
        currency: String,
        category: SpendCategory = .other,
        paidBy: UserID,
        spentAt: Date = Date(),
        mode: SplitMode = .equal,
        participants: [UserID] = [],
        weights: [ExpenseWeight] = [],
        exact: [ExpenseSplit] = [],
        note: String? = nil,
        eventID: EventID? = nil
    ) {
        self.homeID = homeID
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.paidBy = paidBy
        self.spentAt = spentAt
        self.mode = mode
        self.participants = participants
        self.weights = weights
        self.exact = exact
        self.note = note
        self.eventID = eventID
    }
}

public struct NewBill: Equatable, Sendable {
    public var homeID: HomeID
    public var title: String
    public var amount: Int
    public var currency: String
    public var category: SpendCategory
    public var cycle: BillCycle
    public var dueDate: Date
    public var responsible: UserID?
    public var autoSplit: Bool
    /// Whole days before the due date to nudge the household.
    public var reminders: [Int]

    public init(
        homeID: HomeID,
        title: String,
        amount: Int,
        currency: String,
        category: SpendCategory = .utilities,
        cycle: BillCycle = .monthly,
        dueDate: Date = Date(),
        responsible: UserID? = nil,
        autoSplit: Bool = true,
        reminders: [Int] = []
    ) {
        self.homeID = homeID
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.cycle = cycle
        self.dueDate = dueDate
        self.responsible = responsible
        self.autoSplit = autoSplit
        self.reminders = reminders
    }
}

public struct NewSettlement: Equatable, Sendable {
    public var homeID: HomeID
    public var from: UserID
    public var to: UserID
    public var amount: Int
    public var currency: String
    public var note: String?

    public init(
        homeID: HomeID,
        from: UserID,
        to: UserID,
        amount: Int,
        currency: String,
        note: String? = nil
    ) {
        self.homeID = homeID
        self.from = from
        self.to = to
        self.amount = amount
        self.currency = currency
        self.note = note
    }
}

// MARK: - Splitting

/// The division of an expense across a household.
///
/// The server owns the split that gets *stored* — no client version can write a
/// ledger whose shares do not add up to its total (see `convex/finance.ts`).
/// This is the same arithmetic, on this side, for one job only: showing the
/// composer what it is about to save. A preview that disagreed with the result
/// by a cent would be worse than no preview at all, so the two implementations
/// are deliberately the same algorithm rather than merely both "fair".
public enum SplitMath {

    /// Divides `total` as evenly as it goes, handing the remainder out one
    /// minor unit at a time.
    ///
    /// The parts always sum to `total`. Rounding each share independently does
    /// not: three ways of 10.00 rounds to 3.33 each and loses a cent.
    public static func evenly(_ total: Int, among people: [UserID]) -> [ExpenseSplit] {
        guard !people.isEmpty else { return [] }
        let base = total / people.count
        let remainder = total - base * people.count
        return people.enumerated().map { index, id in
            ExpenseSplit(userID: id, amount: base + (index < remainder ? 1 : 0))
        }
    }

    /// The largest of `ways` equal shares.
    ///
    /// What one person carries when a bill splits evenly — the figure people
    /// want before they agree to pay it. The largest share rather than the
    /// average, because that is the one somebody might actually be asked for.
    public static func evenShare(_ total: Int, ways: Int) -> Int {
        guard ways > 0 else { return total }
        let base = total / ways
        return total - base * ways > 0 ? base + 1 : base
    }

    /// Divides `total` in proportion to weights, by largest remainder.
    ///
    /// Each share is floored, then the minor units that fall out of the
    /// flooring go to the shares that lost the most to it — so the parts sum to
    /// `total` and the person rounded down hardest is the one rounded back up.
    public static func byWeight(_ total: Int, weights: [ExpenseWeight]) -> [ExpenseSplit] {
        let positive = weights.filter { $0.weight > 0 }
        let sum = positive.reduce(0) { $0 + $1.weight }
        guard sum > 0 else { return [] }

        var parts = positive.enumerated().map { index, weight -> (index: Int, id: UserID, amount: Int, fraction: Double) in
            let exact = Double(total) * weight.weight / sum
            let floor = Int(exact.rounded(.down))
            return (index, weight.userID, floor, exact - Double(floor))
        }

        var remainder = total - parts.reduce(0) { $0 + $1.amount }
        // Biggest loser to the flooring first; ties by original order, so the
        // same input always produces the same split on both sides of the wire.
        let order = parts
            .sorted { $0.fraction != $1.fraction ? $0.fraction > $1.fraction : $0.index < $1.index }
            .map(\.index)
        for index in order {
            guard remainder > 0 else { break }
            if let slot = parts.firstIndex(where: { $0.index == index }) {
                parts[slot].amount += 1
                remainder -= 1
            }
        }

        return parts.map { ExpenseSplit(userID: $0.id, amount: $0.amount) }
    }
}
