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

    /// Yes-votes per candidate, for the summary sheet's ranking.
    public var scoreboard: [(item: PollItem, yes: Int)] {
        var yesCounts: [String: Int] = [:]
        for vote in votes where vote.isYes {
            yesCounts[vote.targetExternalID, default: 0] += 1
        }
        return items
            .map { ($0, yesCounts[$0.externalID] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    /// Candidates the caller has not swiped yet.
    public var unvotedItems: [PollItem] {
        let seen = Set(myVotes.map(\.targetExternalID))
        return items
            .filter { !seen.contains($0.externalID) }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
}
