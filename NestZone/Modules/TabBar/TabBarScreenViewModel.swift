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
            
            print("DEBUG: Fetching homes for user:", userId)
            
            // First fetch user details to get home_ids
            let userResponse: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(userId)",
                method: .get,
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            print("DEBUG: User response:", userResponse)
            print("DEBUG: User home_ids:", userResponse.home_id)
            
            // If user has no homes, return empty
            guard !userResponse.home_id.isEmpty else {
                self.homes = []
                isLoading = false
                return
            }
            
            print("DEBUG: Starting to fetch homes...")
            print("DEBUG: Home IDs to fetch:", userResponse.home_id)
            
            // Fix: Use ?= operator with array syntax
            let homeIds = userResponse.home_id.map { "'\($0)'" }.joined(separator: ", ")
            let query = "(id=\(homeIds))"
            let endpoint = "/api/collections/homes/records"
            
            print("DEBUG: Using filter query:", query)
            
            let response: PocketBaseListResponse<Home> = try await pocketBase.request(
                endpoint: endpoint,
                method: .get,
                parameters: ["filter": query],
                requiresAuth: true,
                responseType: PocketBaseListResponse<Home>.self
            )
            self.homes = response.items
            
        } catch let error as PocketBaseManager.PocketBaseError {
            print("DEBUG: PocketBase error in user fetch:", error)
            print("DEBUG: Error description:", error.localizedDescription)
            throw error
        } catch {
            print("DEBUG: Unknown error in user fetch:", error)
            print("DEBUG: Error description:", error.localizedDescription)
            throw error
        }
        
        isLoading = false
    }
}
