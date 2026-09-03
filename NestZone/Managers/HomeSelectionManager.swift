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

    private init() {
        // Try to load the last selected home ID
        loadPersistedSelection()
    }

    var selectedHomeId: String? {
        selectedHome?.id
    }

    // Fetch all homes for the current user via Convex `homes:listMine`.
    // The `authManager` param is retained for source compatibility with call sites;
    // authentication is implicit in the shared Convex client.
    func fetchUserHomes(authManager: ConvexAuthManager) async throws {
        let homes: [Home] = try await Convex.once("homes:listMine", as: [Home].self)

        self.availableHomes = homes

        // If user has no homes, clear any stale selection.
        guard !homes.isEmpty else {
            self.selectedHome = nil
            clearPersistedSelection()
            return
        }

        // If there's a persisted selection, try to find it in available homes
        if let persistedId = UserDefaults.standard.string(forKey: selectedHomeIdKey),
           let home = homes.first(where: { $0.id == persistedId }) {
            self.selectedHome = home
        }
        // If only one home, auto-select it
        else if homes.count == 1 {
            selectHome(homes[0])
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