//
//  LoginViewModel.swift
//  NestZone
//
//  Created by muratcankoc on 03/06/2025.
//

import SwiftUI
import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    // MARK: - Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Public Methods
    func login(authManager: PocketBaseAuthManager, email: String, password: String) async {
        isLoading = true
        do {
            try await authManager.login(email: email, password: password)
        } catch let error {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
