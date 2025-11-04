import Foundation
import SwiftUI

// Notification for home selection change
extension Notification.Name {
    static let homeDidChange = Notification.Name("homeDidChange")
}

@MainActor
class HomeSelectionManager: ObservableObject {
    static let shared = HomeSelectionManager()
    
    @Published var selectedHome: Home? {
        didSet {
            // Post notification when home changes
            if oldValue?.id != selectedHome?.id {
                NotificationCenter.default.post(name: .homeDidChange, object: selectedHome)
            }
        }
    }
    @Published var availableHomes: [Home] = []
    
    private let selectedHomeIdKey = "selectedHomeId"
    private let pocketBase = PocketBaseManager.shared
    
    private init() {
        // Try to load the last selected home ID
        loadPersistedSelection()
    }
    
    var selectedHomeId: String? {
        selectedHome?.id
    }
    
    // Fetch all homes for the current user
    func fetchUserHomes(authManager: PocketBaseAuthManager) async throws {
        guard let userId = authManager.currentUser?.id else {
            throw PocketBaseManager.PocketBaseError.unauthorized
        }
        
        // Fetch user details to get home_ids
        let userResponse: PocketBaseUser = try await pocketBase.request(
            endpoint: "/api/collections/users/records/\(userId)",
            method: .get,
            requiresAuth: true,
            responseType: PocketBaseUser.self
        )
        
        // If user has no homes, return empty
        guard !userResponse.home_id.isEmpty else {
            self.availableHomes = []
            self.selectedHome = nil
            clearPersistedSelection()
            return
        }
        
        // Fetch homes using OR filter for multiple IDs
        // Format: id='id1' || id='id2' || id='id3'
        let filterConditions = userResponse.home_id.map { "id='\($0)'" }
        let filter = filterConditions.joined(separator: " || ")
        
        let response: PocketBaseListResponse<Home> = try await pocketBase.request(
            endpoint: "/api/collections/homes/records",
            method: .get,
            parameters: ["filter": filter],
            requiresAuth: true,
            responseType: PocketBaseListResponse<Home>.self
        )
        
        self.availableHomes = response.items
        
        // If there's a persisted selection, try to find it in available homes
        if let persistedId = UserDefaults.standard.string(forKey: selectedHomeIdKey),
           let home = response.items.first(where: { $0.id == persistedId }) {
            self.selectedHome = home
        }
        // If only one home, auto-select it
        else if response.items.count == 1 {
            selectHome(response.items[0])
        }
        // If multiple homes and no valid selection, selectedHome remains nil
        // This will trigger the home selection UI
    }
    
    func selectHome(_ home: Home) {
        self.selectedHome = home
        persistSelection()
    }
    
    func clearSelection() {
        self.selectedHome = nil
        clearPersistedSelection()
    }
    
    private func persistSelection() {
        if let homeId = selectedHome?.id {
            UserDefaults.standard.set(homeId, forKey: selectedHomeIdKey)
        }
    }
    
    private func loadPersistedSelection() {
        // Note: We only load the ID here. The actual Home object will be set
        // when fetchUserHomes is called and matches the persisted ID
        _ = UserDefaults.standard.string(forKey: selectedHomeIdKey)
    }
    
    private func clearPersistedSelection() {
        UserDefaults.standard.removeObject(forKey: selectedHomeIdKey)
    }
    
    // Helper method to check if user needs to select a home
    var needsHomeSelection: Bool {
        return !availableHomes.isEmpty && selectedHome == nil
    }
    
    // Helper to check if user has multiple homes
    var hasMultipleHomes: Bool {
        return availableHomes.count > 1
    }
}