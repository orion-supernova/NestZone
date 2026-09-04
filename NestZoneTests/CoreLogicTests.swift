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
