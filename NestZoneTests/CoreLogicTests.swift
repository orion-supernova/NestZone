import Foundation
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
