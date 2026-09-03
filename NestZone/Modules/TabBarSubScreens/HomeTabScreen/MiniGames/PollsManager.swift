import Foundation
import ConvexMobile

struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String?
    let avatar: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, avatar
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try c.decodeIfPresent(String.self, forKey: .name)) ?? "Member"
        email = try c.decodeIfPresent(String.self, forKey: .email)
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar)
    }
}

struct Poll: Codable, Identifiable {
    let id: String
    let homeId: String?
    let title: String?
    let type: String?
    let status: String?
    let genre: String?
    let created: Double?
    let updated: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case homeId = "home_id"
        case title, type, status, genre, created, updated
    }
}

/// Decoded shape of `polls:detail` — poll + items + all votes + the caller's votes.
struct PollDetail: Codable {
    let poll: Poll
    let items: [PollItem]
    let votes: [PollVote]
    let myVotes: [PollVote]
}

struct PollItem: Codable, Identifiable {
    let id: String
    let pollId: String?
    let entityType: String?
    let externalId: String
    let label: String?
    let thumbnailUrl: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case pollId = "poll_id"
        case entityType = "entity_type"
        case externalId = "external_id"
        case label
        case thumbnailUrl = "thumbnail_url"
        case order
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        pollId = try c.decodeIfPresent(String.self, forKey: .pollId)
        entityType = try c.decodeIfPresent(String.self, forKey: .entityType)
        externalId = (try c.decodeIfPresent(String.self, forKey: .externalId)) ?? ""
        label = try c.decodeIfPresent(String.self, forKey: .label)
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        order = try c.decodeIfPresent(Int.self, forKey: .order)
    }
}

struct PollVote: Codable, Identifiable {
    let id: String
    let pollId: String?
    let targetExternalId: String?
    let vote: Bool
    let userId: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case pollId = "poll_id"
        case targetExternalId = "target_external_id"
        case vote
        case userId = "user_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        pollId = try c.decodeIfPresent(String.self, forKey: .pollId)
        targetExternalId = try c.decodeIfPresent(String.self, forKey: .targetExternalId)
        vote = (try c.decodeIfPresent(Bool.self, forKey: .vote)) ?? false
        userId = (try c.decodeIfPresent(String.self, forKey: .userId)) ?? ""
    }

    // Helper computed property for backward compatibility
    var imdbId: String { targetExternalId ?? "" }
}

@MainActor
final class PollsManager {
    static let shared = PollsManager()
    private init() {}

    enum PollsError: LocalizedError {
        case noHome
        var errorDescription: String? { "No home selected" }
    }

    private func currentHomeId(_ provided: String?) throws -> String {
        if let provided { return provided }
        guard let id = HomeSelectionManager.shared.selectedHomeId else { throw PollsError.noHome }
        return id
    }

    private func moviePolls(homeId: String) async throws -> [Poll] {
        let polls: [Poll] = try await Convex.once(
            "polls:listByHome", args: ["homeId": homeId], as: [Poll].self
        )
        return polls
            .filter { $0.type == "movie" }
            .sorted { ($0.created ?? 0) > ($1.created ?? 0) }
    }

    private func detail(pollId: String) async throws -> PollDetail {
        try await Convex.once("polls:detail", args: ["pollId": pollId], as: PollDetail.self)
    }

    // MARK: - Polls

    func getActivePoll(homeId: String? = nil) async throws -> Poll? {
        let home = try currentHomeId(homeId)
        return try await moviePolls(homeId: home).first { $0.status == "active" }
    }

    func getRecentPoll(homeId: String? = nil) async throws -> Poll? {
        let home = try currentHomeId(homeId)
        return try await moviePolls(homeId: home).first
    }

    func getPreviousPolls(homeId: String? = nil, limit: Int = 10) async throws -> [Poll] {
        let home = try currentHomeId(homeId)
        return Array(try await moviePolls(homeId: home).filter { $0.status == "closed" }.prefix(limit))
    }

    func createPoll(homeId: String? = nil, title: String, candidates: [Movie], genre: String? = nil) async throws -> Poll {
        let home = try currentHomeId(homeId)
        let items: [ConvexEncodable?] = candidates.enumerated().map { index, movie in
            ([
                "external_id": movie.id,
                "label": movie.title,
                "thumbnail_url": movie.poster ?? "",
                "order": Double(index),
            ] as [String: ConvexEncodable?]) as ConvexEncodable?
        }
        var args: [String: ConvexEncodable?] = [
            "homeId": home,
            "title": title,
            "type": "movie",
            "items": items,
        ]
        if let genre { args["genre"] = genre }
        return try await Convex.client.mutation("polls:create", with: args)
    }

    func addMovieToPoll(pollId: String, movie: Movie, order: Int) async throws {
        try await Convex.run("polls:addItem", args: [
            "pollId": pollId,
            "external_id": movie.id,
            "label": movie.title,
            "thumbnail_url": movie.poster ?? "",
            "order": Double(order),
        ])
    }

    func fetchPollItems(pollId: String) async throws -> [PollItem] {
        try await detail(pollId: pollId).items
    }

    func submitVote(pollId: String, imdbId: String, vote: Bool, userId: String? = nil) async throws {
        // Voter identity is taken from the authenticated session server-side.
        try await Convex.run("polls:vote", args: [
            "pollId": pollId,
            "target_external_id": imdbId,
            "vote": vote,
        ])
    }

    func fetchVotes(pollId: String) async throws -> [PollVote] {
        try await detail(pollId: pollId).votes
    }

    func fetchUserVotes(pollId: String, userId: String? = nil) async throws -> [PollVote] {
        // `myVotes` is already scoped to the authenticated user.
        try await detail(pollId: pollId).myVotes
    }

    func closePoll(pollId: String) async throws {
        try await Convex.run("polls:setStatus", args: ["pollId": pollId, "status": "closed"])
    }

    func deletePoll(pollId: String) async throws {
        // Server cascades item + vote deletion.
        try await Convex.run("polls:remove", args: ["pollId": pollId])
    }

    func getHouseMemberCount(homeId: String? = nil) async throws -> Int {
        let home = try currentHomeId(homeId)
        let homeDoc: Home = try await Convex.once("homes:get", args: ["homeId": home], as: Home.self)
        return homeDoc.members.count
    }

    // MARK: - Helpers

    func fetchUsers(userIds: [String]) async throws -> [User] {
        guard !userIds.isEmpty else { return [] }
        return try await Convex.once(
            "users:byIds",
            args: ["ids": userIds.map { $0 as ConvexEncodable? }],
            as: [User].self
        )
    }

    func voteCounts(for votes: [PollVote]) -> [String: (yes: Int, no: Int)] {
        var map: [String: (yes: Int, no: Int)] = [:]
        for v in votes {
            var c = map[v.imdbId] ?? (0, 0)
            if v.vote { c.yes += 1 } else { c.no += 1 }
            map[v.imdbId] = c
        }
        return map
    }

    func getMatches(votes: [PollVote], houseMemberCount: Int) -> [String] {
        let counts = voteCounts(for: votes)
        let majorityThreshold = max(2, Int(ceil(Double(houseMemberCount) * 0.6)))
        return counts.compactMap { imdbId, count in
            (count.yes >= majorityThreshold && count.yes > count.no) ? imdbId : nil
        }
    }

    func getPollWinner(pollId: String) async throws -> Movie? {
        let votes = try await fetchVotes(pollId: pollId)
        if votes.isEmpty { return nil }
        let counts = voteCounts(for: votes)
        let winner = counts
            .filter { $0.value.yes > $0.value.no }
            .max { lhs, rhs in lhs.value.yes < rhs.value.yes }
        guard let winnerImdbId = winner?.key else { return nil }
        return await MovieAPI.shared.getDetails(imdbID: winnerImdbId)
    }
}
