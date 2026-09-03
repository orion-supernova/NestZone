import Foundation
import ConvexMobile

@MainActor
class UserService: ObservableObject {
    static let shared = UserService()

    @Published private var userCache: [String: PocketBaseUser] = [:]
    private var failedUserIds: Set<String> = [] // Track failed user fetches to avoid repeated calls

    private init() {}

    func getUser(id: String) async -> PocketBaseUser? {
        if let cachedUser = userCache[id] { return cachedUser }
        let users = await fetchUsers(ids: [id])
        return users[id]
    }

    /// Returns whatever users are currently cached. (Convex has no "list all users"
    /// endpoint by design; users are fetched on demand by id.)
    func getAllUsers() async -> [PocketBaseUser] {
        Array(userCache.values)
    }

    /// Fetch the given user ids from Convex `users:byIds`, caching results.
    private func fetchUsers(ids: [String]) async -> [String: PocketBaseUser] {
        let wanted = ids.filter { !$0.isEmpty }
        guard !wanted.isEmpty else { return [:] }
        do {
            let users: [PocketBaseUser] = try await Convex.once(
                "users:byIds",
                args: ["ids": wanted.map { $0 as ConvexEncodable? }],
                as: [PocketBaseUser].self
            )
            for user in users { userCache[user.id] = user }
            // Any ids that didn't come back are missing — don't hammer them again.
            let returned = Set(users.map { $0.id })
            for id in wanted where !returned.contains(id) { failedUserIds.insert(id) }
            return Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        } catch {
            return [:]
        }
    }
    
    func getUserName(for userId: String?) -> String {
        guard let userId = userId else { return "Unknown User" }
        
        // Check if this user failed before
        if failedUserIds.contains(userId) {
            // Create a readable fallback name
            if let cachedUser = userCache[userId] {
                return cachedUser.name ?? "User"
            }
            return "User \(String(userId.suffix(4)))"
        }
        
        // Check cache for immediate response
        if let cachedUser = userCache[userId] {
            return cachedUser.name ?? "User"
        }
        
        // Return placeholder while fetching
        return "Loading..."
    }
    
    func getUsers(ids: [String]) async -> [String: PocketBaseUser] {
        var users: [String: PocketBaseUser] = [:]

        // Serve from cache where possible.
        for id in ids {
            if let cachedUser = userCache[id] { users[id] = cachedUser }
        }

        // One batched Convex call for everything not cached or known-missing.
        let missingIds = ids.filter { !userCache.keys.contains($0) && !failedUserIds.contains($0) }
        if !missingIds.isEmpty {
            let fetched = await fetchUsers(ids: missingIds)
            for (id, user) in fetched { users[id] = user }
        }

        return users
    }
    
    func clearCache() {
        userCache.removeAll()
        failedUserIds.removeAll()
    }
    
    func retryFailedUser(id: String) async -> PocketBaseUser? {
        failedUserIds.remove(id) // Remove from failed set to allow retry
        return await getUser(id: id)
    }
}