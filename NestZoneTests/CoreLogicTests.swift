import Foundation
import UIKit
import Testing
@testable import NestZone

/// Pure domain logic — no store, no network.
@Suite("Core domain")
struct CoreLogicTests {

    @Test("Display name falls back through email before giving up")
    func displayNameFallback() {
        #expect(User(id: "1", name: "Ada Lovelace").displayName == "Ada Lovelace")
        // Apple only supplies a name on a user's FIRST authorization, so most
        // accounts have none.
        #expect(User(id: "2", email: "ada@example.com").displayName == "ada")
        #expect(User(id: "3", name: "   ", email: "grace@example.com").displayName == "grace")
        #expect(!User(id: "4").displayName.isEmpty)
    }

    @Test("Initials take at most two letters")
    func initials() {
        #expect(User(id: "1", name: "Ada Lovelace").initials == "AL")
        #expect(User(id: "2", name: "Ada Byron King Lovelace").initials == "AB")
        #expect(User(id: "3", name: "Ada").initials == "A")
    }

    @Test("Timestamps convert between epoch-ms and Date")
    func timestamps() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let stamp = Timestamp(date)
        #expect(stamp.milliseconds == 1_700_000_000_000)
        #expect(abs(stamp.date.timeIntervalSince(date)) < 0.001)
    }

    @Test("Newest-first sorting tolerates the null timestamps the import left")
    func newestFirstWithNils() {
        let newer = Timestamp(milliseconds: 2000)
        let older = Timestamp(milliseconds: 1000)
        #expect(Timestamp.newestFirst(newer, older))
        #expect(!Timestamp.newestFirst(older, newer))
        // A missing timestamp sorts last rather than crashing or winning.
        #expect(Timestamp.newestFirst(older, nil))
        #expect(!Timestamp.newestFirst(nil, older))
    }

    @Test("A task is urgent only while high priority and open")
    func urgency() {
        var task = HouseTask(id: "1", title: "Fix the sink", priority: .high)
        #expect(task.isUrgent)
        task.isCompleted = true
        #expect(!task.isUrgent)
    }

    @Test("An overdue task must have a due date in the past and be unfinished")
    func overdue() {
        let past = Timestamp(Date().addingTimeInterval(-3600))
        let future = Timestamp(Date().addingTimeInterval(3600))
        #expect(HouseTask(id: "1", title: "x", dueDate: past).isOverdue)
        #expect(!HouseTask(id: "2", title: "x", dueDate: future).isOverdue)
        #expect(!HouseTask(id: "3", title: "x", isCompleted: true, dueDate: past).isOverdue)
        #expect(!HouseTask(id: "4", title: "x").isOverdue)
    }

    @Test("Total time adds prep and cook, and copes when only one is known")
    func recipeTotalTime() {
        #expect(Recipe(id: "1", title: "a", prepTime: 10, cookTime: 20).totalMinutes == 30)
        #expect(Recipe(id: "2", title: "b", prepTime: 10).totalMinutes == 10)
        #expect(Recipe(id: "3", title: "c", cookTime: 20).totalMinutes == 20)
        #expect(Recipe(id: "4", title: "d").totalMinutes == nil)
    }
}

@Suite("Poll tallying")
struct PollTests {

    private func detail(votes: [(movie: String, user: String, yes: Bool)]) -> PollDetail {
        let items = Set(votes.map(\.movie)).sorted().enumerated().map { index, id in
            PollItem(id: "item-\(id)", externalID: id, label: id, order: index)
        }
        let cast = votes.enumerated().map { index, vote in
            PollVote(
                id: "vote-\(index)",
                targetExternalID: vote.movie,
                isYes: vote.yes,
                userID: UserID(vote.user)
            )
        }
        return PollDetail(
            poll: Poll(id: "poll"),
            items: items,
            votes: cast,
            myVotes: []
        )
    }

    @Test("A match needs a yes from every member")
    func matchesRequireUnanimity() {
        let detail = detail(votes: [
            ("dune", "a", true), ("dune", "b", true),
            ("barbie", "a", true), ("barbie", "b", false),
        ])
        #expect(detail.matches(memberCount: 2).map(\.externalID) == ["dune"])
        // A third member who hasn't voted means nothing has matched yet.
        #expect(detail.matches(memberCount: 3).isEmpty)
    }

    @Test("A member voting yes twice cannot manufacture a match")
    func duplicateVotesDoNotCount() {
        let detail = detail(votes: [
            ("dune", "a", true), ("dune", "a", true),
        ])
        #expect(detail.matches(memberCount: 2).isEmpty)
    }

    @Test("One person voting alone is not an agreement")
    func loneVoterIsNotAWinner() {
        // Exactly what the history sheet used to crown: in a home of three, one
        // member swiped right on one film and it was reported as the winner.
        let detail = detail(votes: [("dune", "a", true), ("barbie", "a", false)])
        let outcome = detail.outcome(memberCount: 3)

        guard case let .closest(items, yes) = outcome.result else {
            Issue.record("one voter out of three cannot carry the house")
            return
        }
        #expect(items.map(\.externalID) == ["dune"])
        #expect(yes == 1)
        #expect(outcome.isPartialTurnout, "and the sheet should say only one person voted")
        #expect(outcome.voters == 1)
    }

    @Test("A household that agreed on several keeps all of them")
    func everyAgreementSurvives() {
        let detail = detail(votes: [
            ("dune", "a", true), ("dune", "b", true),
            ("barbie", "a", true), ("barbie", "b", true),
            ("tenet", "a", true), ("tenet", "b", false),
        ])
        guard case let .agreed(items) = detail.outcome(memberCount: 2).result else {
            Issue.record("expected an agreement")
            return
        }
        // Both, not just the first — the sheet used to show one and drop the rest.
        #expect(Set(items.map(\.externalID)) == ["dune", "barbie"])
    }

    @Test("A round nobody swiped right in has no winner at all")
    func noRightSwipesMeansNothing() {
        // `scoreboard` lists every candidate including the ones on zero, so the
        // old fallback crowned a film with no votes whatsoever.
        let detail = detail(votes: [("dune", "a", false), ("barbie", "a", false)])
        guard case .nothing = detail.outcome(memberCount: 2).result else {
            Issue.record("nothing was voted for, so nothing won")
            return
        }
    }

    @Test("A solo household agreeing with itself is a real agreement")
    func singleMemberHomeCanAgree() {
        let detail = detail(votes: [("dune", "a", true)])
        guard case let .agreed(items) = detail.outcome(memberCount: 1).result else {
            Issue.record("one member is the whole household")
            return
        }
        #expect(items.map(\.externalID) == ["dune"])
        #expect(!detail.outcome(memberCount: 1).isPartialTurnout)
    }

    @Test("Ties at the top all show, rather than an arbitrary one")
    func tiedRunnersUpAllShow() {
        let detail = detail(votes: [
            ("dune", "a", true), ("barbie", "b", true),
        ])
        guard case let .closest(items, yes) = detail.outcome(memberCount: 3).result else {
            Issue.record("expected a near miss")
            return
        }
        #expect(Set(items.map(\.externalID)) == ["dune", "barbie"])
        #expect(yes == 1)
    }

    @Test("The scoreboard counts people, not swipes")
    func scoreboardCountsPeople() {
        let detail = detail(votes: [("dune", "a", true), ("dune", "a", true)])
        #expect(detail.scoreboard.first(where: { $0.item.externalID == "dune" })?.yes == 1)
    }

    @Test("Scoreboard ranks by yes-votes")
    func scoreboardOrder() {
        let detail = detail(votes: [
            ("dune", "a", true), ("dune", "b", true),
            ("barbie", "a", true),
            ("tenet", "a", false),
        ])
        let ranked = detail.scoreboard
        #expect(ranked.map(\.item.externalID) == ["dune", "barbie", "tenet"])
        #expect(ranked.map(\.yes) == [2, 1, 0])
    }

    @Test("Unvoted items exclude anything the caller already swiped")
    func unvotedItems() {
        var detail = detail(votes: [("dune", "a", true), ("barbie", "a", true)])
        detail.myVotes = [
            PollVote(id: "mine", targetExternalID: "dune", isYes: true, userID: "a")
        ]
        #expect(detail.unvotedItems.map(\.externalID) == ["barbie"])
    }

    @Test("No members means no matches, rather than everything matching")
    func zeroMembers() {
        let detail = detail(votes: [("dune", "a", true)])
        #expect(detail.matches(memberCount: 0).isEmpty)
    }
}

@Suite("Wire decoding")
struct DecodingTests {

    @Test("A home decodes Convex's _id and snake_case invite code")
    func homeDecoding() throws {
        let json = Data("""
        {
          "_id": "home123",
          "name": "The Nest",
          "members": ["u1", "u2"],
          "invite_code": "ABC123",
          "created": 1700000000000
        }
        """.utf8)
        let home = try JSONDecoder().decode(Home.self, from: json)
        #expect(home.id == HomeID("home123"))
        #expect(home.members == [UserID("u1"), UserID("u2")])
        #expect(home.inviteCode == "ABC123")
        #expect(home.created?.milliseconds == 1_700_000_000_000)
    }

    @Test("Missing optional fields decode to sensible defaults, not a throw")
    func sparseDecoding() throws {
        let json = Data(#"{"_id": "home123"}"#.utf8)
        let home = try JSONDecoder().decode(Home.self, from: json)
        #expect(home.name.isEmpty)
        #expect(home.members.isEmpty)
        #expect(home.inviteCode == nil)
    }

    @Test("A task with an unknown priority falls back rather than failing")
    func taskDefaults() throws {
        let json = Data(#"{"_id": "t1", "title": "Dishes"}"#.utf8)
        let task = try JSONDecoder().decode(HouseTask.self, from: json)
        #expect(task.priority == .medium)
        #expect(task.kind == .general)
        #expect(!task.isCompleted)
    }

    @Test("Poll status and type decode into the server's vocabulary")
    func pollDecoding() throws {
        // `type` is the entity being voted on, and `status` is draft/active/
        // closed — the server writes "active" for a live round, not "open".
        let json = Data("""
        {"_id": "p1", "home_id": "h1", "owner_id": "u1", "title": "Friday",
         "type": "movie", "status": "active"}
        """.utf8)
        let poll = try JSONDecoder().decode(Poll.self, from: json)
        #expect(poll.kind == .movie)
        #expect(poll.status == .active)
        #expect(poll.isOpen)
        #expect(poll.isOwned(by: "u1"))
        #expect(!poll.isOwned(by: "u2"))
        #expect(!poll.isOwned(by: nil))
    }

    @Test("An unknown enum value degrades the field instead of failing the row")
    func lenientEnumDecoding() throws {
        // A whole screen is decoded as one array, so a single row carrying a
        // value this build doesn't know must not take the list down.
        let poll = try JSONDecoder().decode(Poll.self, from: Data("""
        {"_id": "p1", "type": "boardgame", "status": "paused"}
        """.utf8))
        #expect(poll.kind == .movie)
        #expect(poll.status == .active)

        let task = try JSONDecoder().decode(HouseTask.self, from: Data("""
        {"_id": "t1", "title": "x", "priority": "urgent", "type": "gardening"}
        """.utf8))
        #expect(task.priority == .medium)
        #expect(task.kind == .general)

        let item = try JSONDecoder().decode(ShoppingItem.self, from: Data("""
        {"_id": "s1", "name": "Milk", "category": "frozen"}
        """.utf8))
        #expect(item.category == .other)
    }

    @Test("Typed ids encode as bare strings on the wire")
    func idEncoding() throws {
        let encoded = try JSONEncoder().encode(HomeID("abc"))
        #expect(String(decoding: encoded, as: UTF8.self) == "\"abc\"")
    }
}

/// The maths behind the Home tab's split bar and the contributions screen.
@Suite("Contributions")
struct ContributionsMathTests {

    private static func member(
        _ id: UserID,
        _ name: String,
        completed: Int,
        openAssigned: Int = 0,
        overdue: Int = 0
    ) -> MemberContribution {
        MemberContribution(
            userID: id,
            name: name,
            completed: completed,
            openAssigned: openAssigned,
            overdue: overdue
        )
    }

    private static func contributions(
        _ members: [MemberContribution],
        unattributed: Int = 0
    ) -> HomeContributions {
        HomeContributions(
            windowDays: 30,
            totalCompleted: members.reduce(0) { $0 + $1.completed } + unattributed,
            unattributed: unattributed,
            members: members
        )
    }

    @Test("Shares are measured against everything done, unattributed included")
    func sharesIncludeUnattributed() {
        let ada = Self.member("u1", "Ada", completed: 6)
        let grace = Self.member("u2", "Grace", completed: 2)
        let data = Self.contributions([ada, grace], unattributed: 2)

        #expect(data.totalCompleted == 10)
        #expect(data.attributed == 8)
        #expect(data.share(of: ada) == 0.6)
        #expect(data.share(of: grace) == 0.2)
        #expect(data.unattributedShare == 0.2)
        // The bar has to fill exactly, or it reads as missing data.
        let total = data.share(of: ada) + data.share(of: grace) + data.unattributedShare
        #expect(abs(total - 1) < 0.000_001)
    }

    @Test("An empty window divides by nothing")
    func emptyWindow() {
        let data = Self.contributions([Self.member("u1", "Ada", completed: 0)])
        #expect(data.isEmpty)
        #expect(data.share(of: data.members[0]) == 0)
        #expect(data.balance == nil)
        // The activity chart scales against this; zero would be a crash.
        #expect(data.busiestDay == 1)
    }

    @Test("Ranking is busiest first, and ties never flicker")
    func ranking() {
        let data = Self.contributions([
            Self.member("u1", "Zoe", completed: 3),
            Self.member("u2", "Ada", completed: 9),
            Self.member("u3", "Grace", completed: 3),
        ])
        #expect(data.ranked.map(\.displayName) == ["Ada", "Grace", "Zoe"])
    }

    @Test("Balance runs from an even split to one person doing everything")
    func balance() {
        let even = Self.contributions([
            Self.member("u1", "Ada", completed: 5),
            Self.member("u2", "Grace", completed: 5),
        ])
        #expect(even.balance == 1)

        let allOnOne = Self.contributions([
            Self.member("u1", "Ada", completed: 10),
            Self.member("u2", "Grace", completed: 0),
        ])
        #expect(allOnOne.balance == 0)

        let tilted = Self.contributions([
            Self.member("u1", "Ada", completed: 7),
            Self.member("u2", "Grace", completed: 3),
        ])
        let score = try! #require(tilted.balance)
        #expect(score > 0 && score < 1)

        // A household of one has no split to be unfair about.
        #expect(Self.contributions([Self.member("u1", "Ada", completed: 4)]).balance == nil)
    }

    @Test("The verdict reads the balance score, not the raw counts")
    func verdict() {
        #expect(ContributionsFeature.State.Verdict(balance: 0.95) == .even)
        #expect(ContributionsFeature.State.Verdict(balance: 0.8) == .even)
        #expect(ContributionsFeature.State.Verdict(balance: 0.6) == .tilted)
        #expect(ContributionsFeature.State.Verdict(balance: 0.2) == .lopsided)
    }

    @Test("Work kinds come back biggest first, with the zeroes dropped")
    func byKind() {
        let member = MemberContribution(
            userID: "u1", name: "Ada", completed: 9,
            cleaning: 5, shopping: 0, maintenance: 1, general: 3
        )
        #expect(member.byKind.map(\.kind) == [.cleaning, .general, .maintenance])
        #expect(member.byKind.map(\.count) == [5, 3, 1])
    }

    @Test("A member row decodes the stats payload's camelCase keys")
    func decoding() throws {
        let json = Data("""
        {"windowDays": 7, "totalCompleted": 4, "unattributed": 1,
         "members": [{"userId": "u1", "name": null, "email": "ada@example.com",
                      "completed": 3, "openAssigned": 2, "overdue": 1, "streak": 5,
                      "cleaning": 1, "shopping": 1, "maintenance": 0, "general": 1}],
         "days": [{"start": 1757116800000, "total": 3,
                   "counts": [{"userId": "u1", "count": 3}]}]}
        """.utf8)
        let data = try JSONDecoder().decode(HomeContributions.self, from: json)

        let member = try #require(data.members.first)
        #expect(member.userID == UserID("u1"))
        // Same fallback as `User.displayName`, so one person is not labelled two
        // different ways on two screens.
        #expect(member.displayName == "ada")
        #expect(member.initials == "A")
        #expect(member.streak == 5)
        #expect(data.days.first?.counts.first?.count == 3)
        #expect(data.busiestDay == 3)
    }

    @Test("Every window maps to the days the query expects")
    func windows() {
        #expect(ContributionWindow.week.days == 7)
        #expect(ContributionWindow.month.days == 30)
        // 0 is what `stats:contributions` reads as "no lower bound".
        #expect(ContributionWindow.allTime.days == 0)
    }
}

/// The household ledger's arithmetic — the part that has to be exactly right.
@Suite("Household money")
struct FinanceLogicTests {

    // MARK: Formatting and parsing

    @Test("Minor units survive the round trip, including currencies with no cents")
    func minorUnitRoundTrip() {
        #expect(Money.minorUnits(Decimal(string: "12.34")!, currency: "EUR") == 1234)
        #expect(Money.decimal(1234, currency: "EUR") == Decimal(string: "12.34"))
        // Yen has no subunit: 1200 is ¥1,200, not ¥12.00.
        #expect(Money.minorUnits(Decimal(1200), currency: "JPY") == 1200)
        #expect(Money.decimal(1200, currency: "JPY") == 1200)
        // Three-digit subunits are rare but real.
        #expect(Money.minorUnits(Decimal(string: "1.234")!, currency: "KWD") == 1234)
    }

    @Test("A typed amount is read the same way whichever separator the keyboard gave")
    func parsingSeparators() {
        #expect(Money.parse("12.34", currency: "EUR") == 1234)
        #expect(Money.parse("12,34", currency: "EUR") == 1234)
        // The last separator is the decimal one, so a grouped figure pasted in
        // from either convention reads the same.
        #expect(Money.parse("1.234,56", currency: "EUR") == 123_456)
        #expect(Money.parse("1,234.56", currency: "EUR") == 123_456)
        // Symbols and spaces are noise, not an error.
        #expect(Money.parse("€ 40", currency: "EUR") == 4000)
        // Nothing readable is zero, which the save button already refuses —
        // a better answer than an error about a half-typed field.
        #expect(Money.parse("", currency: "EUR") == 0)
        #expect(Money.parse("abc", currency: "EUR") == 0)
    }

    @Test("Rounding a typed amount never loses the last cent")
    func parsingRounds() {
        // Truncation would make this 1233 — an expense a cent short of what was
        // typed, every time, in one direction.
        #expect(Money.parse("12.335", currency: "EUR") == 1234)
        #expect(Money.parse("12.344", currency: "EUR") == 1234)
    }

    @Test("An editable amount carries no symbol and no grouping")
    func editableText() {
        #expect(Money.editableText(0, currency: "EUR").isEmpty)
        #expect(!Money.editableText(123_456, currency: "EUR").contains("€"))
    }

    // MARK: Splitting

    @Test("An equal split always adds up to the total")
    func equalSplitIsExact() {
        let people: [UserID] = ["u1", "u2", "u3"]
        let split = SplitMath.evenly(1000, among: people)
        // 3.34 + 3.33 + 3.33, not 3.33 three times — which would lose a cent.
        #expect(split.map(\.amount) == [334, 333, 333])
        #expect(split.reduce(0) { $0 + $1.amount } == 1000)
        #expect(split.map(\.userID) == people)
    }

    @Test("An equal split of nothing between nobody is empty rather than a crash")
    func equalSplitEdges() {
        #expect(SplitMath.evenly(1000, among: []).isEmpty)
        #expect(SplitMath.evenly(0, among: ["u1", "u2"]).map(\.amount) == [0, 0])
    }

    @Test("A weighted split hands the rounding remainder to whoever lost most to it")
    func weightedSplit() {
        let split = SplitMath.byWeight(1000, weights: [
            ExpenseWeight(userID: "u1", weight: 2),
            ExpenseWeight(userID: "u2", weight: 1),
        ])
        #expect(split.map(\.amount) == [667, 333])
        #expect(split.reduce(0) { $0 + $1.amount } == 1000)
    }

    @Test("A weighted split drops the people given no share, and still adds up")
    func weightedSplitZeroes() {
        let split = SplitMath.byWeight(100, weights: [
            ExpenseWeight(userID: "u1", weight: 1),
            ExpenseWeight(userID: "u2", weight: 0),
            ExpenseWeight(userID: "u3", weight: 1),
        ])
        #expect(split.map(\.userID) == ["u1", "u3"])
        #expect(split.reduce(0) { $0 + $1.amount } == 100)
        // No positive weights at all has no answer, so it gives none rather
        // than dividing by zero.
        #expect(SplitMath.byWeight(100, weights: []).isEmpty)
    }

    // MARK: Expenses

    @Test("An expense's effect on one person is what they put in minus their share")
    func expenseImpact() {
        let expense = Expense(
            id: "e1",
            title: "Lasagne",
            amount: 3000,
            paidBy: "u1",
            splits: [
                ExpenseSplit(userID: "u1", amount: 1000),
                ExpenseSplit(userID: "u2", amount: 1000),
                ExpenseSplit(userID: "u3", amount: 1000),
            ]
        )
        #expect(expense.impact(on: "u1") == 2000)
        #expect(expense.impact(on: "u2") == -1000)
        // Somebody who was not on it is unaffected, not owed nothing-in-error.
        #expect(expense.impact(on: "u9") == 0)
        #expect(expense.involves("u2"))
        #expect(!expense.involves("u9"))
    }

    // MARK: Bills

    @Test("A bill's urgency is measured in whole days, not hours")
    func billUrgency() {
        let now = Date()
        func bill(daysFromNow: Int) -> Bill {
            Bill(
                id: "b1",
                title: "Power",
                amount: 5000,
                dueDate: Timestamp(Calendar.current.date(byAdding: .day, value: daysFromNow, to: now)!)
            )
        }
        // A bill due in nine hours is "due today", and the countdown flips to
        // overdue at midnight rather than at the stroke of the stamp.
        #expect(bill(daysFromNow: 0).urgency(now: now) == .dueToday)
        #expect(bill(daysFromNow: -1).urgency(now: now) == .overdue)
        #expect(bill(daysFromNow: 3).urgency(now: now) == .dueSoon)
        #expect(bill(daysFromNow: 30).urgency(now: now) == .upcoming)
        // Sorted so the ones asking for something come first.
        #expect(Bill.Urgency.overdue < Bill.Urgency.upcoming)
    }

    @Test("Every cycle is comparable once said per month")
    func monthlyEquivalents() {
        #expect(BillCycle.monthly.monthlyEquivalent(of: 100_000) == 100_000)
        #expect(BillCycle.yearly.monthlyEquivalent(of: 120_000) == 10_000)
        #expect(BillCycle.quarterly.monthlyEquivalent(of: 30_000) == 10_000)
        // A one-off is a date, not a standing cost, so it commits nothing.
        #expect(BillCycle.once.monthlyEquivalent(of: 100_000) == 0)
    }

    // MARK: Budgets

    @Test("A budget's health warns before it is spent, not after")
    func budgetHealth() {
        func health(spent: Int) -> BudgetProgress.Health {
            BudgetProgress(category: .groceries, limit: 10_000, spent: spent).health
        }
        #expect(health(spent: 5_000) == .healthy)
        #expect(health(spent: 8_500) == .close)
        #expect(health(spent: 10_000) == .over)
        #expect(health(spent: 14_000) == .over)

        let over = BudgetProgress(category: .groceries, limit: 10_000, spent: 14_000)
        #expect(over.isOver)
        #expect(over.remaining == -4_000)
        // Uncapped: a ring has to know it is at 140%, not merely that it is full.
        #expect(over.progress == 1.4)
    }

    // MARK: Months

    @Test("Months step across a year boundary and refuse to run ahead")
    func calendarMonth() {
        let december = CalendarMonth(year: 2026, month: 12)
        #expect(december.advanced(by: 1) == CalendarMonth(year: 2027, month: 1))
        #expect(december.advanced(by: -12) == CalendarMonth(year: 2025, month: 12))
        #expect(CalendarMonth(year: 2020, month: 1) < december)
        #expect(CalendarMonth.current.isCurrent)
        #expect(!CalendarMonth.current.isInFuture)
        #expect(CalendarMonth.current.advanced(by: 1).isInFuture)
    }

    // MARK: Summary

    @Test("Balances read as a settle-up list, and a settled house says so")
    func summaryBalances() {
        let summary = FinanceSummary(
            year: 2026, month: 9, currency: "EUR",
            monthTotal: 12_000, previousMonthTotal: 10_000,
            members: [
                MemberFinance(userID: "u1", name: "Ada", net: 4_000, paidThisMonth: 8_000),
                MemberFinance(userID: "u2", name: "Grace", net: -4_000, paidThisMonth: 4_000),
                MemberFinance(userID: "u3", name: "Idle", net: 0),
            ],
            transfers: [Transfer(from: "u2", to: "u1", amount: 4_000)]
        )
        // Whoever is square is not in the list — a settled household shows one
        // calm line rather than three zeroes.
        #expect(summary.outstanding.map(\.userID) == ["u1", "u2"])
        #expect(!summary.isSquare)
        #expect(summary.net(for: "u1") == 4_000)
        #expect(summary.net(for: "u9") == 0)
        #expect(summary.monthChange == 0.2)
        #expect(summary.transfers(involving: "u1").count == 1)
        #expect(summary.transfers(involving: "u3").isEmpty)
        #expect(summary.payers.map(\.userID) == ["u1", "u2"])

        var settled = summary
        settled.members = settled.members.map {
            var member = $0
            member.net = 0
            return member
        }
        settled.transfers = []
        #expect(settled.isSquare)
    }

    @Test("A month with no history before it reports no trend rather than an infinite one")
    func monthChangeWithoutHistory() {
        let summary = FinanceSummary(monthTotal: 5_000, previousMonthTotal: 0)
        #expect(summary.monthChange == nil)
        // At least one, so an empty history draws a baseline rather than
        // dividing by zero.
        #expect(summary.busiestMonth == 1)
    }
}

extension FinanceLogicTests {
    @Test("One person's share of an evenly split bill is the largest of them")
    func evenShare() {
        // 3.34, not 3.33: the figure somebody might actually be asked for.
        #expect(SplitMath.evenShare(1000, ways: 3) == 334)
        #expect(SplitMath.evenShare(1000, ways: 2) == 500)
        #expect(SplitMath.evenShare(1000, ways: 1) == 1000)
        // Nobody to split between is not a division at all.
        #expect(SplitMath.evenShare(1000, ways: 0) == 1000)
    }
}

extension FinanceLogicTests {
    @Test("A currency picker offers what the household uses before the rest of the world")
    func currencyPickerOrder() {
        let codes = Money.pickerCodes(used: ["TRY", "SEK"])
        #expect(codes.first == "TRY")
        #expect(codes[1] == "SEK")
        // The device's own follows, then everything else — and nothing twice.
        #expect(codes.contains(Money.deviceDefault))
        #expect(Set(codes).count == codes.count)
        #expect(codes.count > 10)
    }

    @Test("Amounts are scaled by their own currency, not by a shared assumption")
    func perCurrencyScale() {
        // The same typed string is a different number of minor units depending
        // on the currency it is written in, which is why currency travels on
        // the document rather than on the home.
        #expect(Money.parse("1000", currency: "TRY") == 100_000)
        #expect(Money.parse("1000", currency: "JPY") == 1_000)
        #expect(Money.parse("1000", currency: "KWD") == 1_000_000)
    }
}

extension FinanceLogicTests {
    @Test("An absurd amount is clamped rather than turned into a nonsense number")
    func hugeAmountsAreClamped() {
        // `NSDecimalNumber.intValue` past `Int.max` returns nonsense rather than
        // failing, so without the clamp a pasted seventy-digit number became an
        // arbitrary amount in the ledger.
        let absurd = String(repeating: "9", count: 70)
        let parsed = Money.parse(absurd, currency: "EUR")
        #expect(parsed == Money.maximumMinorUnits)
        #expect(parsed > 0)

        // And the cap stays inside what float64 carries exactly, because the
        // server does integer arithmetic on these over the wire.
        #expect(Money.maximumMinorUnits < 1 << 53)

        // Ordinary amounts are untouched.
        #expect(Money.parse("1234.56", currency: "EUR") == 123_456)
        // As is the boundary itself.
        #expect(Money.minorUnits(Decimal(Money.maximumMinorUnits), currency: "JPY")
            == Money.maximumMinorUnits)
    }

    @Test("Nothing readable, or nothing positive, is zero rather than a crash")
    func degenerateAmounts() {
        #expect(Money.parse(".", currency: "EUR") == 0)
        #expect(Money.parse("0.000", currency: "EUR") == 0)
        #expect(Money.parse("-5", currency: "EUR") == 500)
    }
}

@Suite("Avatar geometry")
struct AvatarCropTests {

    /// 2000×1000 drawn into a 300-point square: the photo is fitted to its
    /// shorter edge, so it overhangs by 300 points on each side.
    private func landscape(scale: CGFloat = 1, offset: CGSize = .zero) -> AvatarCrop {
        AvatarCrop(
            imageSize: CGSize(width: 2000, height: 1000),
            viewport: 300,
            scale: scale,
            offset: offset
        )
    }

    @Test("Untouched, the circle takes the middle of the photo")
    func centredByDefault() {
        #expect(landscape().sourceRect == CGRect(x: 500, y: 0, width: 1000, height: 1000))
    }

    @Test("The photo is fitted to its shorter edge, so the circle is always full")
    func fillsTheViewport() {
        let crop = landscape()
        #expect(crop.fillScale == 0.3)
        #expect(crop.displayedSize == CGSize(width: 600, height: 300))
        // Only the overhanging axis may move. Panning the other one would show
        // background inside the circle.
        #expect(crop.maximumOffset == CGSize(width: 150, height: 0))
    }

    @Test("Pushing the photo right shows what was to its left")
    func panMovesTheWindowAgainstIt() {
        let crop = landscape(offset: CGSize(width: 150, height: 0))
        #expect(crop.sourceRect == CGRect(x: 0, y: 0, width: 1000, height: 1000))
    }

    @Test("A pan past the edge settles at the edge rather than showing nothing")
    func panIsClamped() {
        let far = landscape(offset: CGSize(width: 4000, height: 900))
        #expect(far.clamped().offset == CGSize(width: 150, height: 0))
        // And the rectangle it produces is the same as the one at the limit.
        #expect(far.sourceRect == landscape(offset: CGSize(width: 150, height: 0)).sourceRect)
    }

    @Test("Zooming in narrows the window onto the source")
    func zoomShrinksTheSourceWindow() {
        #expect(landscape(scale: 2).sourceRect == CGRect(x: 750, y: 250, width: 500, height: 500))
    }

    @Test("Zoom stays within range, so the circle can never be under-filled")
    func zoomIsClamped() {
        #expect(landscape(scale: 0.2).clamped().scale == AvatarCrop.minimumScale)
        #expect(landscape(scale: 99).clamped().scale == AvatarCrop.maximumScale)
    }

    @Test("A portrait photo pans vertically and is pinned horizontally")
    func portraitPinsTheOtherAxis() {
        let crop = AvatarCrop(
            imageSize: CGSize(width: 1000, height: 2000),
            viewport: 300
        )
        #expect(crop.maximumOffset == CGSize(width: 0, height: 150))
        #expect(crop.sourceRect == CGRect(x: 0, y: 500, width: 1000, height: 1000))
    }

    @Test("The crop is always square, and always inside the photo")
    func staysSquareAndInBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        for scale in stride(from: 1.0, through: 6.0, by: 0.7) {
            for dx in stride(from: -900.0, through: 900.0, by: 150) {
                let rect = landscape(scale: scale, offset: CGSize(width: dx, height: 0)).sourceRect
                #expect(rect.width == rect.height)
                #expect(bounds.contains(rect))
            }
        }
    }

    @Test("A photo with no size at all does not produce a broken rectangle")
    func degenerateImage() {
        let crop = AvatarCrop(imageSize: .zero, viewport: 300)
        #expect(crop.fillScale == 1)
        #expect(crop.sourceRect == .zero)
    }
}

@Suite("Avatar sizing")
struct AvatarPhotoTests {

    @Test("Every avatar in the app lands on one of two decoded sizes")
    func renderSizesAreBucketed() {
        // The sizes actually used across the eight features that draw a member.
        let drawn: [CGFloat] = [18, 26, 28, 34, 36, 40, 52]
        #expect(Set(drawn.map(AvatarPhoto.renderSize(for:))) == [56])
        #expect(AvatarPhoto.renderSize(for: 96) == 128)
        // Nothing falls off the end of the ladder.
        #expect(AvatarPhoto.renderSize(for: 400) == 128)
    }

    /// A square of structureless detail: the hardest thing any encoder can be
    /// handed, and far worse than any photograph of a person.
    private func noise(edge: Int) throws -> UIImage {
        let context = try #require(CGContext(
            data: nil,
            width: edge,
            height: edge,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        // Filled through the context's own buffer rather than from a Swift
        // array, whose lifetime would end before `CGContext` was finished with
        // the pointer.
        let buffer = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        var seed: UInt64 = 0x2545_F491
        for index in 0 ..< (context.bytesPerRow * edge) {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            buffer[index] = UInt8(truncatingIfNeeded: seed >> 33)
        }
        return UIImage(cgImage: try #require(context.makeImage()), scale: 1, orientation: .up)
    }

    @Test("An avatar is compressed to a stated ceiling, not a hoped-for one")
    func staysUnderBudget() throws {
        let selection = try #require(AvatarPhoto.compress(try noise(edge: 1024)))
        // The whole point of a budget: a quality setting is a knob on an
        // encoder, and this image is the case that proves it is not a size.
        // Uncompressible detail forces the ladder down through four qualities
        // and onto a smaller square, and it still has to land under the ceiling.
        #expect(selection.upload.byteCount <= AvatarPhoto.byteBudget)
    }

    @Test("The bytes are labelled with what they actually are")
    func labelsTheFormat() throws {
        let selection = try #require(AvatarPhoto.compress(try noise(edge: 256)))
        // Either is correct — HEIC needs a hardware encoder the simulator does
        // not always have, and the fallback is the point. What must never
        // happen is a constant: Convex serves back whatever content type it was
        // told, so a mislabelled avatar stays mislabelled for everyone.
        #expect(["image/heic", "image/jpeg"].contains(selection.upload.contentType))
    }

    @Test("The bitmap handed back is the one that was actually encoded")
    func returnsWhatWasEncoded() throws {
        let selection = try #require(AvatarPhoto.compress(try noise(edge: 1024)))
        // It primes the cache under the URL the server answers with, so if the
        // budget forced a smaller square this has to be that square — otherwise
        // the local copy and the remote one are two different pictures sharing
        // one address.
        #expect(selection.image.size.width == selection.image.size.height)
        #expect(selection.image.size.width <= AvatarPhoto.storedEdge)
        #expect(AvatarPhoto.edgeLadder.contains(selection.image.size.width))
    }

    @Test("A plain photograph keeps the full square, and is nowhere near the ceiling")
    func anOrdinaryPhotoIsCheap() throws {
        // A smooth gradient stands in for an ordinary portrait: structure an
        // encoder can model. This is the common case, and it should settle on
        // the top rung — full resolution, best quality — with room to spare.
        let edge = 1024
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: edge, height: edge)
        let gradient = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemPink.withAlphaComponent(0.6).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 120, y: 120, width: 700, height: 700))
        }
        let selection = try #require(AvatarPhoto.compress(gradient))
        #expect(selection.upload.byteCount <= AvatarPhoto.byteBudget)
        // No rung was given up to get there.
        #expect(selection.image.size.width == AvatarPhoto.storedEdge)
    }

    @Test("The stored square is big enough for the largest thing done with it")
    func storedEdgeCoversTheViewer() {
        // Which is no longer a 52-point circle but a full-screen photo, so the
        // upload has to out-resolve the viewer's request on a 3x screen.
        #expect(AvatarPhoto.storedEdge >= AvatarPhoto.viewerEdge * 2)
    }
}

@Suite("Photo zoom")
struct PhotoZoomTests {

    private let screen = CGSize(width: 390, height: 844)

    /// A square avatar — which is the only kind there is — on a tall screen.
    private func zoom(_ scale: CGFloat = 1, _ offset: CGSize = .zero) -> PhotoZoom {
        PhotoZoom(
            imageSize: CGSize(width: 1, height: 1),
            viewport: screen,
            scale: scale,
            offset: offset
        )
    }

    @Test("At rest the whole photo is visible, and there is nothing to pan")
    func atRestItIsPinned() {
        #expect(zoom().displayedSize == CGSize(width: 390, height: 390))
        #expect(zoom().maximumOffset == .zero)
        #expect(zoom().isAtRest)
        // Which is what lets a downward drag mean "close this" instead.
        #expect(zoom(1, CGSize(width: 200, height: 200)).clamped().offset == .zero)
    }

    @Test("Zoomed in it pans exactly as far as it overflows, and no further")
    func panMatchesTheOverflow() {
        let zoomed = zoom(3)
        #expect(zoomed.displayedSize == CGSize(width: 1170, height: 1170))
        #expect(zoomed.maximumOffset == CGSize(width: 390, height: 163))
        #expect(!zoomed.isAtRest)
        #expect(zoom(3, CGSize(width: 9999, height: 9999)).clamped().offset
            == CGSize(width: 390, height: 163))
    }

    @Test("Zoom stays in range")
    func zoomIsClamped() {
        #expect(zoom(0.1).clamped().scale == PhotoZoom.minimumScale)
        #expect(zoom(99).clamped().scale == PhotoZoom.maximumScale)
    }

    @Test("A double tap zooms in, and on the way out recentres rather than stranding it")
    func doubleTapToggles() {
        #expect(zoom().toggledZoom().scale == PhotoZoom.doubleTapScale)
        let dragged = zoom(3, CGSize(width: 300, height: 100))
        #expect(dragged.toggledZoom().scale == PhotoZoom.minimumScale)
        // A photo that fits has exactly one right position, and nothing left to
        // drag it back with.
        #expect(dragged.toggledZoom().offset == .zero)
    }

    @Test("A viewer fits where a crop fills — the one word that separates them")
    func fitsRatherThanFills() {
        let square = CGSize(width: 1000, height: 2000)
        let fit = PhotoZoom(imageSize: square, viewport: CGSize(width: 300, height: 300))
        let fill = AvatarCrop(imageSize: square, viewport: 300)
        // Fit shows all of it and leaves bars; fill covers and overhangs.
        #expect(fit.displayedSize == CGSize(width: 150, height: 300))
        #expect(fill.displayedSize == CGSize(width: 300, height: 600))
    }

    @Test("A degenerate viewport does not divide by zero")
    func degenerate() {
        let empty = PhotoZoom(imageSize: .zero, viewport: .zero)
        #expect(empty.fitScale == 1)
        #expect(empty.clamped().offset == .zero)
    }
}

@Suite("Avatar directory")
@MainActor
struct AvatarDirectoryTests {

    private func user(_ id: String, photo: String?) -> User {
        User(id: UserID(rawValue: id), name: "Ada", avatarURL: photo.flatMap(URL.init(string:)))
    }

    @Test("A face recorded once is found by id from anywhere")
    func recordsByID() {
        let directory = AvatarDirectory()
        directory.record([user("u1", photo: "https://example.com/1.jpg")])
        #expect(directory.url(for: "u1") == URL(string: "https://example.com/1.jpg"))
        #expect(directory.url(for: "u2") == nil)
    }

    @Test("Taking a photo off puts the initials back everywhere, but keeps the name")
    func removalIsAFactToo() {
        let directory = AvatarDirectory()
        directory.record([user("u1", photo: "https://example.com/1.jpg")])
        // Not "no news": a user who arrives without a photo has had it removed,
        // and leaving the old URL would strand a stale face on every screen but
        // the one that made the change.
        directory.record([user("u1", photo: nil)])
        #expect(directory.url(for: "u1") == nil)
        // The name is still true, and a tappable avatar needs it.
        #expect(directory.name(for: "u1") == "Ada")
    }

    @Test("The name travels with the face, so no call site has to pass one")
    func recordsTheName() {
        let directory = AvatarDirectory()
        directory.record([user("u1", photo: "https://example.com/1.jpg")])
        #expect(directory.name(for: "u1") == "Ada")
        #expect(directory.name(for: "nobody") == nil)
    }

    @Test("A session that has ended leaves no faces behind")
    func clearingForgetsTheHousehold() {
        let directory = AvatarDirectory()
        directory.record([user("u1", photo: "https://example.com/1.jpg")])
        directory.clear()
        #expect(directory.url(for: "u1") == nil)
    }
}

@Suite("User payload")
struct UserDecodingTests {

    private func decode(_ json: String) throws -> User {
        try JSONDecoder().decode(User.self, from: Data(json.utf8))
    }

    @Test("A resolved avatar URL travels with the user")
    func decodesAvatarURL() throws {
        let user = try decode("""
        {"_id":"u1","name":"Ada","avatar":"storage-1","avatar_url":"https://example.com/a.jpg"}
        """)
        #expect(user.avatar == "storage-1")
        #expect(user.avatarURL == URL(string: "https://example.com/a.jpg"))
    }

    @Test("A user with no photo, and a URL the phone cannot parse, both mean initials")
    func degradesToInitials() throws {
        #expect(try decode(#"{"_id":"u1","name":"Ada"}"#).avatarURL == nil)
        // Degrades this one field rather than throwing and blanking the whole
        // household list — the same contract `decodeLenient` gives enums.
        #expect(try decode(#"{"_id":"u1","name":"Ada","avatar_url":123}"#).avatarURL == nil)
    }
}

@Suite("House-problem photos")
struct IssuePhotoTests {

    /// A wide picture, so the aspect-ratio behaviour is actually exercised —
    /// a photo of a leak is never square.
    private func photograph(width: Int, height: Int) throws -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width, height: height)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemBrown.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemGray.withAlphaComponent(0.7).setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: 40, y: 40, width: width - 80, height: height - 80)
            )
        }
        return try #require(image.jpegData(compressionQuality: 1))
    }

    @Test("A picked photo yields both sizes, each inside its own ceiling")
    func bothSizesAreBudgeted() throws {
        let encoded = try #require(IssuePhoto.encode(try photograph(width: 4032, height: 3024)))
        #expect(encoded.full.byteCount <= IssuePhoto.plan.byteBudget)
        #expect(encoded.thumbnail.byteCount <= IssuePhoto.thumbnailPlan.byteBudget)
    }

    @Test("The board downloads a fraction of what the detail screen does")
    func theThumbnailIsTheWholePoint() throws {
        let encoded = try #require(IssuePhoto.encode(try photograph(width: 4032, height: 3024)))
        // The board used to draw its 44-point square by downloading the full
        // picture. This ratio is the reason it no longer does.
        #expect(encoded.thumbnail.byteCount < encoded.full.byteCount / 2)
    }

    @Test("House-problem photos stay JPEG, where an avatar may be HEIC")
    func staysReadableEverywhere() throws {
        let encoded = try #require(IssuePhoto.encode(try photograph(width: 1200, height: 900)))
        // Deliberate, and the one place the two plans disagree: this is the
        // kind of picture somebody forwards to a plumber, and a signed storage
        // URL opened in a browser that cannot decode HEIC is a broken image at
        // the moment it is most needed.
        #expect(encoded.full.contentType == "image/jpeg")
        #expect(encoded.thumbnail.contentType == "image/jpeg")
        #expect(!IssuePhoto.plan.allowsHEIC)
        #expect(AvatarPhoto.plan.allowsHEIC)
    }

    @Test("Unreadable bytes are refused rather than uploaded as a blank")
    func refusesRubbish() {
        #expect(IssuePhoto.encode(Data("not an image".utf8)) == nil)
    }
}

@Suite("Photo compression")
struct PhotoCompressorTests {

    private func image(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    @Test("Resizing keeps the proportions — a wide photo does not become square")
    func resizingKeepsProportions() {
        let resized = PhotoCompressor.resized(image(width: 4000, height: 3000), longEdge: 2000)
        #expect(resized.size == CGSize(width: 2000, height: 1500))
    }

    @Test("A picture already smaller than the limit is left alone, not upscaled")
    func neverUpscales() {
        let small = image(width: 300, height: 200)
        let resized = PhotoCompressor.resized(small, longEdge: 2000)
        #expect(resized.size == small.size)
    }

    @Test("The long edge is the one that is limited, whichever it is")
    func limitsTheLongEdge() {
        let tall = PhotoCompressor.resized(image(width: 1000, height: 4000), longEdge: 2000)
        #expect(tall.size == CGSize(width: 500, height: 2000))
    }
}

