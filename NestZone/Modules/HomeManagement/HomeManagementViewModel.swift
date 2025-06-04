import SwiftUI
import Foundation

@MainActor
class HomeManagementViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var homeCreated = false
    @Published var homeJoined = false
    
    private let pocketBase = PocketBaseManager.shared
    
    func createHome(name: String, address: String?, authManager: PocketBaseAuthManager) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showErrorMessage("Home name cannot be empty")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            guard let userId = authManager.currentUser?.id else {
                throw PocketBaseManager.PocketBaseError.unauthorized
            }
            
            // 1. Create the home
            var parameters: [String: Any] = [
                "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                "members": [userId],
                "invite_code": UUID().uuidString
            ]
            
            if let address = address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parameters["address"] = address.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // First get the user to make sure they exist
            let _: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(userId)",
                method: .get,
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            // Then create the home with the verified user ID
            let newHome: Home = try await pocketBase.createRecord(
                in: "homes",
                data: parameters,
                responseType: Home.self
            )
            
            // Finally update user's home_id array
            let currentUser: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(userId)",
                method: .get,
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            var updatedHomeIds = currentUser.home_id
            updatedHomeIds.append(newHome.id)
            
            let _: PocketBaseUser = try await pocketBase.updateRecord(
                in: "users",
                id: userId,
                data: ["home_id": updatedHomeIds],
                responseType: PocketBaseUser.self
            )
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                homeCreated = true
            }
            
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func joinHome(inviteCode: String, authManager: PocketBaseAuthManager) async {
        guard !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showErrorMessage("Invite code cannot be empty")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            guard let userId = authManager.currentUser?.id else {
                throw PocketBaseManager.PocketBaseError.unauthorized
            }
            
            // 1. Find the home with the invite code
            let response: PocketBaseListResponse<Home> = try await pocketBase.request(
                endpoint: "/api/collections/homes/records",
                method: .get,
                parameters: ["filter": "invite_code = '\(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines))'"],
                requiresAuth: true,
                responseType: PocketBaseListResponse<Home>.self
            )
            
            guard let home = response.items.first else {
                showErrorMessage("Invalid invite code")
                isLoading = false
                return
            }
            
            // Check if user is already a member
            if home.members.contains(userId) {
                showErrorMessage("You're already a member of this home")
                isLoading = false
                return
            }
            
            // 2. Add user to home members using updateRecord
            var updatedMembers = home.members
            updatedMembers.append(userId)
            
            let _: Home = try await pocketBase.updateRecord(
                in: "homes",
                id: home.id,
                data: ["members": updatedMembers],
                responseType: Home.self
            )
            
            // 3. Update user's home_id array using updateRecord
            let currentUser: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(userId)",
                method: .get,
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            var updatedHomeIds = currentUser.home_id
            updatedHomeIds.append(home.id)
            
            let _: PocketBaseUser = try await pocketBase.updateRecord(
                in: "users",
                id: userId,
                data: ["home_id": updatedHomeIds],
                responseType: PocketBaseUser.self
            )
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                homeJoined = true
            }
            
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showError = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showError = false
            }
        }
    }
    
    func resetStates() {
        homeCreated = false
        homeJoined = false
        showError = false
        errorMessage = nil
    }
}
