//
//  TabBarScreenViewModel.swift
//  NestZone
//
//  Created by muratcankoc on 03/06/2025.
//

import SwiftUI
import Alamofire

@MainActor
class TabBarScreenViewModel: ObservableObject {
    // MARK: - Properties
    private let pocketBase = PocketBaseManager.shared
    @Published var homes: [Home] = []
    @Published var isLoading = true
    
    // MARK: - Public Methods
    func fetchUserHome(authManager: PocketBaseAuthManager) async throws {
        isLoading = true
        
        do {
            guard let userId = authManager.currentUser?.id else {
                throw PocketBaseManager.PocketBaseError.unauthorized
            }
            
            // First try to refresh auth to ensure we have a valid token
            do {
                try await authManager.refreshAuth()
            } catch {
                // If refresh fails, the auth manager will handle logout
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
                self.homes = []
                isLoading = false
                return
            }
            
            // Fetch homes using the user's home_id array
            let homeIds = userResponse.home_id.map { "'\($0)'" }.joined(separator: ", ")
            let query = "(id=\(homeIds))"
            
            let response: PocketBaseListResponse<Home> = try await pocketBase.request(
                endpoint: "/api/collections/homes/records",
                method: .get,
                parameters: ["filter": query],
                requiresAuth: true,
                responseType: PocketBaseListResponse<Home>.self
            )
            
            self.homes = response.items
            
        } catch let error as PocketBaseManager.PocketBaseError {
            // Let the auth manager handle unauthorized errors (will trigger logout)
            throw error
        } catch {
            throw error
        }
        
        isLoading = false
    }
}