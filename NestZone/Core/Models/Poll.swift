import Foundation

/// A "what should we watch?" round. `type` and `status` were bare `String?` on
/// the wire and compared with string literals at a dozen call sites; they are
/// enums here, with the raw value preserved so nothing changes server-side.
public struct Poll: Codable, Identifiable, Hashable, Sendable {
    public let id: PollID
    public var homeID: HomeID?
    /// Who started the round. Only they may close or delete it — the server
    /// enforces this with `requirePollOwner`, so the UI must not offer the
    /// action to anyone else.
    public var ownerID: UserID?
    public var title: String?
    public var kind: Kind
    public var status: Status
    public var genre: String?
    public var created: Timestamp?
    public var updated: Timestamp?

    /// What is being voted on. Not *how* the candidates were chosen — the
    /// server stores that in `genre`, and the picker's options live on
    /// `PollKindFeature`.
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case movie, recipe, generic
    }

    public enum Status: String, Codable, CaseIterable, Sendable {
        case draft, active, closed
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case homeID = "home_id"
        case ownerID = "owner_id"
        case title
        case kind = "type"
        case status, genre, created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(PollID.self, forKey: .id)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        ownerID = try c.decodeIfPresent(UserID.self, forKey: .ownerID)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        kind = c.decodeLenient(Kind.self, forKey: .kind, default: .movie)
        status = c.decodeLenient(Status.self, forKey: .status, default: .active)
        genre = try c.decodeIfPresent(String.self, forKey: .genre)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: PollID,
        homeID: HomeID? = nil,
        ownerID: UserID? = nil,
        title: String? = nil,
        kind: Kind = .movie,
        status: Status = .active,
        genre: String? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.homeID = homeID
        self.ownerID = ownerID
        self.title = title
        self.kind = kind
        self.status = status
        self.genre = genre
        self.created = created
        self.updated = updated
    }

    /// A poll accepting votes. `draft` is reserved and unused by the app.
    public var isOpen: Bool { status == .active }

    public func isOwned(by user: UserID?) -> Bool {
        guard let user, let ownerID else { return false }
        return ownerID == user
    }
}

public struct PollItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var pollID: PollID?
    public var entityType: String?
    /// TMDb id of the candidate movie.
    public var externalID: String
    public var label: String?
    public var thumbnailURL: String?
    public var order: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case pollID = "poll_id"
        case entityType = "entity_type"
        case externalID = "external_id"
        case label
        case thumbnailURL = "thumbnail_url"
        case order
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        pollID = try c.decodeIfPresent(PollID.self, forKey: .pollID)
        entityType = try c.decodeIfPresent(String.self, forKey: .entityType)
        externalID = try c.decodeIfPresent(String.self, forKey: .externalID) ?? ""
        label = try c.decodeIfPresent(String.self, forKey: .label)
        thumbnailURL = try c.decodeIfPresent(String.self, forKey: .thumbnailURL)
        order = try c.decodeIfPresent(Int.self, forKey: .order)
    }

    public init(
        id: String,
        pollID: PollID? = nil,
        entityType: String? = nil,
        externalID: String,
        label: String? = nil,
        thumbnailURL: String? = nil,
        order: Int? = nil
    ) {
        self.id = id
        self.pollID = pollID
        self.entityType = entityType
        self.externalID = externalID
        self.label = label
        self.thumbnailURL = thumbnailURL
        self.order = order
    }
}

extension PollItem {
    /// The catalogue movie this candidate stands for.
    ///
    /// A poll item carries only what the deck needed to draw a card — the TMDb
    /// id, a title and a poster path. That id is enough for `catalog:details`
    /// to fill in the rest, which is what lets a film agreed on in a round be
    /// opened and filed without searching for it again.
    ///
    /// Only meaningful on a `.movie` round; a dinner round's items are recipes
    /// and cuisines.
    public var asMovie: Movie {
        Movie(id: externalID, title: label ?? "", poster: thumbnailURL)
    }
}

public struct PollVote: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var pollID: PollID?
    /// TMDb id of the movie voted on.
    public var targetExternalID: String
    /// `true` = swiped right.
    public var isYes: Bool
    public var userID: UserID

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case pollID = "poll_id"
        case targetExternalID = "target_external_id"
        case isYes = "vote"
        case userID = "user_id"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        pollID = try c.decodeIfPresent(PollID.self, forKey: .pollID)
        targetExternalID = try c.decodeIfPresent(String.self, forKey: .targetExternalID) ?? ""
        isYes = try c.decodeIfPresent(Bool.self, forKey: .isYes) ?? false
        userID = try c.decodeIfPresent(UserID.self, forKey: .userID) ?? ""
    }

    public init(
        id: String,
        pollID: PollID? = nil,
        targetExternalID: String,
        isYes: Bool,
        userID: UserID
    ) {
        self.id = id
        self.pollID = pollID
        self.targetExternalID = targetExternalID
        self.isYes = isYes
        self.userID = userID
    }
}

/// `polls:detail` — the poll, its candidates, every vote, and the caller's own.
public struct PollDetail: Codable, Hashable, Sendable {
    public var poll: Poll
    public var items: [PollItem]
    public var votes: [PollVote]
    public var myVotes: [PollVote]

    public init(poll: Poll, items: [PollItem] = [], votes: [PollVote] = [], myVotes: [PollVote] = []) {
        self.poll = poll
        self.items = items
        self.votes = votes
        self.myVotes = myVotes
    }
}

extension PollDetail {
    /// Movies every voting member swiped right on, richest first.
    ///
    /// The old implementation walked `votes` once per item — O(items × votes)
    /// on every redraw of the results sheet. This groups once.
    public func matches(memberCount: Int) -> [PollItem] {
        guard memberCount > 0 else { return [] }
        var yesCounts: [String: Set<UserID>] = [:]
        for vote in votes where vote.isYes {
            yesCounts[vote.targetExternalID, default: []].insert(vote.userID)
        }
        return items
            .filter { (yesCounts[$0.externalID]?.count ?? 0) >= memberCount }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }

    /// How many *people* said yes to each candidate, best first.
    ///
    /// People, not votes: counted raw, a member who swiped the same card twice
    /// counted twice, which `matches` already guarded against and this did not —
    /// so the ranking could disagree with the agreement it sits next to, and
    /// "2 of 2 said yes" could mean one person swiping twice.
    public var scoreboard: [(item: PollItem, yes: Int)] {
        var yesVoters: [String: Set<UserID>] = [:]
        for vote in votes where vote.isYes {
            yesVoters[vote.targetExternalID, default: []].insert(vote.userID)
        }
        return items
            .map { ($0, yesVoters[$0.externalID]?.count ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    /// Everyone who cast a vote of any kind.
    public var voterCount: Int { Set(votes.map(\.userID)).count }

    /// How many people have been all the way through the deck.
    ///
    /// What the end-of-deck screen is actually waiting for. A round is over
    /// when every member has answered every candidate — not when the first one
    /// has — so finishing your own deck is a cue to wait, not to close it.
    public var finishedVoterCount: Int {
        let targets = Set(items.map(\.externalID))
        guard !targets.isEmpty else { return 0 }
        var answered: [UserID: Set<String>] = [:]
        for vote in votes where targets.contains(vote.targetExternalID) {
            answered[vote.userID, default: []].insert(vote.targetExternalID)
        }
        return answered.values.filter { $0.count == targets.count }.count
    }

    /// How a round actually turned out.
    ///
    /// The history sheet used to take the first unanimous match and, failing
    /// that, fall back to whatever topped the scoreboard — then label it
    /// "Winner". That crowned one person's single swipe in a two-person home,
    /// and in a round where nobody swiped right at all it crowned a film with
    /// no votes whatsoever, because `scoreboard` lists every candidate
    /// including the ones on zero. It also showed only the first agreement when
    /// a household had agreed on several.
    public func outcome(memberCount: Int) -> PollOutcome {
        let agreed = matches(memberCount: memberCount)
        guard agreed.isEmpty else {
            return PollOutcome(result: .agreed(agreed), voters: voterCount, memberCount: memberCount)
        }
        // Only candidates somebody actually wanted; the rest are not "closest",
        // they are untouched.
        let supported = scoreboard.filter { $0.yes > 0 }
        guard let best = supported.first?.yes else {
            return PollOutcome(result: .nothing, voters: voterCount, memberCount: memberCount)
        }
        return PollOutcome(
            result: .closest(supported.filter { $0.yes == best }.map(\.item), yes: best),
            voters: voterCount,
            memberCount: memberCount
        )
    }

    /// Candidates the caller has not swiped yet.
    public var unvotedItems: [PollItem] {
        let seen = Set(myVotes.map(\.targetExternalID))
        return items
            .filter { !seen.contains($0.externalID) }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
}

/// What a finished round came to, and how much of the household took part.
///
/// Three genuinely different endings, which the app used to collapse into one
/// word. "Winner" is only honest for the first of them.
public struct PollOutcome: Equatable, Sendable {
    public enum Result: Equatable, Sendable {
        /// Every member of the home swiped right on these. There can be more
        /// than one, and all of them are worth showing — the household agreed
        /// on a shortlist, not a single film.
        case agreed([PollItem])
        /// Nobody carried the whole house. The best-supported candidates, and
        /// how many people that was. Tied candidates all appear.
        case closest([PollItem], yes: Int)
        /// Not one right-swipe in the entire round.
        case nothing
    }

    public var result: Result
    /// How many people cast a vote of any kind.
    public var voters: Int
    /// How many could have.
    public var memberCount: Int

    public init(result: Result, voters: Int, memberCount: Int) {
        self.result = result
        self.voters = voters
        self.memberCount = memberCount
    }

    /// The candidates worth putting on screen, whichever ending this is.
    public var items: [PollItem] {
        switch result {
        case let .agreed(items): items
        case let .closest(items, _): items
        case .nothing: []
        }
    }

    /// The round closed before everyone had their say. Worth saying out loud:
    /// it is the reason a round can end with nothing agreed.
    public var isPartialTurnout: Bool { voters < memberCount }
}
