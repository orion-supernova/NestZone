//
//  TabBarScrenViewModel.swift
//  NestZone
//
//  Created by muratcankoc on 03/06/2025.
//

import SwiftUI
import Alamofire

@MainActor
class TabBarScrenViewModel: ObservableObject {
    // MARK: - Properties
    private let pocketBase = PocketBaseManager.shared
    @Published var homes: [Home] = []
    
    // MARK: - Public Methods
    func fetchUserHome(authManager: PocketBaseAuthManager) async throws {
        do {
            guard let userId = authManager.currentUser?.id else {
                throw PocketBaseManager.PocketBaseError.unauthorized
            }
            
            let response: PocketBaseListResponse<Home> = try await pocketBase.request(
                endpoint: "/api/collections/homes/records",
                method: .get,
                parameters: ["filter": "members ~ '\(userId)'"],
                responseType: PocketBaseListResponse<Home>.self
            )
            self.homes = response.items
        } catch let error as PocketBaseManager.PocketBaseError {
            switch error {
            case .badRequest:
                print("Invalid filter or request format")
                throw error
            case .unauthorized:
                print("Authorization required")
                throw error
            case .forbidden:
                print("Only superusers can access this action")
                throw error
            case .serverError(let message):
                print("Server error: \(message)")
                throw error
            default:
                print("Unknown error: \(error)")
                throw error
            }
        } catch {
            print("Error fetching homes: \(error)")
            throw error
        }
    }
}
