import Foundation

@MainActor
class UserService: ObservableObject {
    static let shared = UserService()
    
    @Published private var userCache: [String: PocketBaseUser] = [:]
    private var failedUserIds: Set<String> = [] // Track failed user fetches to avoid repeated calls
    private let pocketBase = PocketBaseManager.shared
    
    private init() {}
    
    func getUser(id: String) async -> PocketBaseUser? {
        // Don't retry failed user IDs
        if failedUserIds.contains(id) {
            print("DEBUG: UserService - Skipping already failed user ID: \(id)")
            return nil
        }
        
        // Check cache first
        if let cachedUser = userCache[id] {
            print("DEBUG: UserService - Found cached user: \(id) -> \(cachedUser.name ?? "No name")")
            return cachedUser
        }
        
        print("DEBUG: UserService - Attempting to fetch user: \(id)")
        
        do {
            let user: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(id)",
                method: .get,
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            print("DEBUG: UserService - Successfully fetched user: \(id) -> \(user.name ?? "No name")")
            
            // Cache the user
            userCache[id] = user
            return user
            
        } catch {
            print("DEBUG: UserService - Failed to fetch user \(id): \(error)")
            
            // Check if it's a 404 error - if so, try alternative approach
            if let pocketBaseError = error as? PocketBaseManager.PocketBaseError {
                switch pocketBaseError {
                case .notFound:
                    print("DEBUG: UserService - User not found: \(id)")
                case .forbidden:
                    print("DEBUG: UserService - Permission denied for user: \(id)")
                default:
                    print("DEBUG: UserService - Other error for user \(id): \(pocketBaseError)")
                }
            }
            
            // Mark this user ID as failed to avoid repeated calls
            failedUserIds.insert(id)
            return nil
        }
    }
    
    func getAllUsers() async -> [PocketBaseUser] {
        print("DEBUG: UserService - Fetching all users from collection")
        
        do {
            let response: PocketBaseListResponse<PocketBaseUser> = try await pocketBase.request(
                endpoint: "/api/collections/users/records",
                method: .get,
                requiresAuth: true,
                responseType: PocketBaseListResponse<PocketBaseUser>.self
            )
            
            print("DEBUG: UserService - Successfully fetched \(response.items.count) users")
            
            // Cache all users
            for user in response.items {
                userCache[user.id] = user
                print("DEBUG: UserService - Cached user: \(user.id) -> \(user.name ?? "No name")")
            }
            
            return response.items
            
        } catch {
            print("DEBUG: UserService - Failed to fetch all users: \(error)")
            return []
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
        
        // First, try to get all users if cache is mostly empty
        if userCache.count < 2 {
            let allUsers = await getAllUsers()
            for user in allUsers {
                if ids.contains(user.id) {
                    users[user.id] = user
                }
            }
            
            // If we got users from the bulk fetch, return early
            if !users.isEmpty {
                return users
            }
        }
        
        // Check cache first
        for id in ids {
            if let cachedUser = userCache[id] {
                users[id] = cachedUser
            }
        }
        
        // Fetch missing users (excluding failed ones)
        let missingIds = ids.filter { !userCache.keys.contains($0) && !failedUserIds.contains($0) }
        
        if !missingIds.isEmpty {
            print("DEBUG: UserService - Need to fetch \(missingIds.count) missing users: \(missingIds)")
            
            // Limit concurrent requests to avoid overwhelming the server
            let batchSize = 3
            for i in stride(from: 0, to: missingIds.count, by: batchSize) {
                let batch = Array(missingIds[i..<min(i + batchSize, missingIds.count)])
                
                await withTaskGroup(of: (String, PocketBaseUser?).self) { group in
                    for id in batch {
                        group.addTask {
                            let user = await self.getUser(id: id)
                            return (id, user)
                        }
                    }
                    
                    for await (id, user) in group {
                        if let user = user {
                            users[id] = user
                        }
                    }
                }
                
                // Small delay between batches
                if i + batchSize < missingIds.count {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
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