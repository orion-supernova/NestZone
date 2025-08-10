import Foundation

struct Poll: Codable, Identifiable {
    let id: String
    let homeId: String?
    let title: String?
    let status: String?
    let genre: String?
    let created: String?
    let updated: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case title
        case status
        case genre
        case created
        case updated
    }
}

struct PollItem: Codable, Identifiable {
    let id: String
    let pollId: String
    let entityType: String?
    let externalId: String
    let label: String?
    let thumbnailUrl: String?
    let order: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case pollId = "poll_id"
        case entityType = "entity_type"
        case externalId = "external_id"
        case label
        case thumbnailUrl = "thumbnail_url"
        case order
    }
}

struct PollVote: Codable, Identifiable {
    let id: String
    let pollId: String
    let targetExternalId: String?
    let vote: Bool
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case pollId = "poll_id"
        case targetExternalId = "target_external_id"
        case vote
        case userId = "user_id"
    }
    
    // Helper computed property for backward compatibility
    var imdbId: String {
        return targetExternalId ?? ""
    }
}

final class PollsManager: @unchecked Sendable {
    static let shared = PollsManager()
    private init() {}
    
    private let pocketBase = PocketBaseManager.shared
    
    private struct PBListResponse<T: Codable>: Codable {
        let page: Int?
        let perPage: Int?
        let totalItems: Int?
        let items: [T]
    }
    
    private struct HomeLite: Codable {
        let id: String
    }
    
    private func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
    
    // MARK: - Public API
    
    func getActivePoll(homeId: String? = nil) async throws -> Poll? {
        let home = try await resolveHomeIdIfNeeded(homeId)
        let filterRaw = "home_id = '\(home)' && status = 'active' && type = 'movie'"
        let endpoint = "/api/collections/polls/records?filter=\(encode(filterRaw))&sort=-created&perPage=1"
        let response: PBListResponse<Poll> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<Poll>.self)
        return response.items.first
    }
    
    func getPreviousPolls(homeId: String? = nil, limit: Int = 10) async throws -> [Poll] {
        let home = try await resolveHomeIdIfNeeded(homeId)
        let filterRaw = "home_id = '\(home)' && status = 'closed' && type = 'movie'"
        let endpoint = "/api/collections/polls/records?filter=\(encode(filterRaw))&sort=-created&perPage=\(limit)"
        let response: PBListResponse<Poll> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<Poll>.self)
        return response.items
    }
    
    func createPoll(homeId: String? = nil, title: String, candidates: [Movie], genre: String? = nil) async throws -> Poll {
        let home = try await resolveHomeIdIfNeeded(homeId)
        let userId = await getCurrentUserId()
        
        // STEP 1: Create the poll (no candidates array)
        var params: [String: Any] = [
            "home_id": home,
            "owner_id": userId,
            "type": "movie",
            "title": title,
            "status": "active"
        ]
        if let genre { params["genre"] = genre }
        let createdPoll: Poll = try await pocketBase.createRecord(in: "polls", data: params, responseType: Poll.self)
        
        // STEP 2: Create poll_items for ALL movies (no payload)
        for (index, movie) in candidates.enumerated() {
            let itemParams: [String: Any] = [
                "poll_id": createdPoll.id,
                "entity_type": "movie",
                "external_id": movie.id,
                "label": movie.title,
                "thumbnail_url": movie.poster ?? "",
                "order": index
            ]
            
            do {
                let _: PollItem = try await pocketBase.createRecord(in: "poll_items", data: itemParams, responseType: PollItem.self)
                print("✅ Created poll item for: \(movie.title)")
            } catch {
                print("❌ Failed to create poll item for \(movie.title): \(error)")
                // Don't fail the entire poll creation for one item
            }
        }
        
        return createdPoll
    }
    
    func addMovieToPoll(pollId: String, movie: Movie, order: Int) async throws {
        let itemParams: [String: Any] = [
            "poll_id": pollId,
            "entity_type": "movie",
            "external_id": movie.id,
            "label": movie.title,
            "thumbnail_url": movie.poster ?? "",
            "order": order
        ]
        
        let _: PollItem = try await pocketBase.createRecord(in: "poll_items", data: itemParams, responseType: PollItem.self)
    }

    func fetchPollItems(pollId: String) async throws -> [PollItem] {
        let filterRaw = "poll_id = '\(pollId)'"
        let endpoint = "/api/collections/poll_items/records?filter=\(encode(filterRaw))&sort=order&perPage=200"
        let response: PBListResponse<PollItem> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<PollItem>.self)
        print("📊 Fetched \(response.items.count) poll items for poll \(pollId)")
        return response.items
    }
    
    // Helper to resolve a poll_item by external (IMDB) id
    private func findPollItem(pollId: String, imdbId: String) async throws -> PollItem? {
        let filterRaw = "poll_id = '\(pollId)' && external_id = '\(imdbId)'"
        let endpoint = "/api/collections/poll_items/records?filter=\(encode(filterRaw))&perPage=1"
        print("🔍 Looking for poll item: pollId=\(pollId), imdbId=\(imdbId)")
        print("🔍 Filter: \(filterRaw)")
        let response: PBListResponse<PollItem> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<PollItem>.self)
        if let item = response.items.first {
            print("✅ Found poll item: id=\(item.id), external_id=\(item.externalId), order=\(item.order ?? -1)")
        } else {
            print("❌ No poll item found for imdbId=\(imdbId)")
        }
        return response.items.first
    }
    
    func submitVote(pollId: String, imdbId: String, vote: Bool, userId: String? = nil) async throws {
        print("🗳️ SUBMIT VOTE: pollId=\(pollId), imdbId=\(imdbId), vote=\(vote)")
        
        let userIdToUse: String
        if let userId = userId {
            userIdToUse = userId
        } else {
            userIdToUse = await getCurrentUserId()
        }
        print("🗳️ User ID: \(userIdToUse)")
        
        // Remove item_id entirely since target_external_id is working correctly
        // and provides all the identification we need
        let params: [String: Any] = [
            "poll_id": pollId,
            "target_external_id": imdbId,
            "vote": vote,
            "user_id": userIdToUse
        ]
        
        do {
            let _: PollVote = try await pocketBase.createRecord(in: "poll_votes", data: params, responseType: PollVote.self)
            print("✅ Vote submitted: \(vote ? "YES" : "NO") for \(imdbId)")
        } catch {
            print("❌ Failed to submit vote for \(imdbId): \(error)")
            throw error
        }
    }
    
    func fetchVotes(pollId: String) async throws -> [PollVote] {
        let filterRaw = "poll_id = '\(pollId)'"
        let endpoint = "/api/collections/poll_votes/records?filter=\(encode(filterRaw))&perPage=200"
        let response: PBListResponse<PollVote> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<PollVote>.self)
        return response.items
    }
    
    func fetchUserVotes(pollId: String, userId: String? = nil) async throws -> [PollVote] {
        let userIdToUse: String
        if let userId = userId {
            userIdToUse = userId
        } else {
            userIdToUse = await getCurrentUserId()
        }
        
        let filterRaw = "poll_id = '\(pollId)' && user_id = '\(userIdToUse)'"
        let endpoint = "/api/collections/poll_votes/records?filter=\(encode(filterRaw))&perPage=200"
        let response: PBListResponse<PollVote> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<PollVote>.self)
        return response.items
    }
    
    func closePoll(pollId: String) async throws {
        let _: Poll = try await pocketBase.updateRecord(in: "polls", id: pollId, data: ["status": "closed"], responseType: Poll.self)
    }
    
    func getHouseMemberCount(homeId: String? = nil) async throws -> Int {
        let home = try await resolveHomeIdIfNeeded(homeId)
        let endpoint = "/api/collections/homes/records/\(home)"
        
        struct HomeDetail: Codable {
            let members: [String]
        }
        
        let homeDetail: HomeDetail = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: HomeDetail.self)
        return homeDetail.members.count
    }
    
    // MARK: - Helpers
    
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
        let majorityThreshold = max(2, Int(ceil(Double(houseMemberCount) * 0.6))) // 60% of house members or minimum 2
        
        return counts.compactMap { (imdbId, count) in
            // A movie is a match if it has majority yes votes AND more yes than no
            if count.yes >= majorityThreshold && count.yes > count.no {
                return imdbId
            }
            return nil
        }
    }
    
    func getPollWinner(pollId: String) async throws -> Movie? {
        let votes = try await fetchVotes(pollId: pollId)
        if votes.isEmpty { return nil }
        
        let counts = voteCounts(for: votes)
        
        // Find the movie with the most yes votes (and more yes than no)
        let winner = counts
            .filter { $0.value.yes > $0.value.no }
            .max { lhs, rhs in lhs.value.yes < rhs.value.yes }
        
        guard let winnerImdbId = winner?.key else { return nil }
        return await MovieAPI.shared.getDetails(imdbID: winnerImdbId)
    }
    
    private func resolveHomeIdIfNeeded(_ provided: String?) async throws -> String {
        if let provided { return provided }
        // Fallback to first home
        let endpoint = "/api/collections/homes/records?perPage=1"
        let response: PBListResponse<HomeLite> = try await pocketBase.request(endpoint: endpoint, requiresAuth: true, responseType: PBListResponse<HomeLite>.self)
        guard let id = response.items.first?.id else {
            throw PocketBaseManager.PocketBaseError.notFound
        }
        return id
    }
    
    private func getCurrentUserId() async -> String {
        // Extract user ID from the JWT token stored in PocketBaseManager
        guard let token = await pocketBase.getAuthToken() else {
            return ""
        }
        
        // Parse JWT token to extract user ID
        let components = token.split(separator: ".")
        guard components.count >= 2 else {
            return ""
        }
        
        let payloadString = String(components[1])
        // Add padding if needed
        let paddingLength = 4 - payloadString.count % 4
        let paddedPayload = payloadString + String(repeating: "=", count: paddingLength % 4)
        
        guard let payloadData = Data(base64Encoded: paddedPayload),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let userId = payloadJSON["id"] as? String else {
            return ""
        }
        
        return userId
    }
}