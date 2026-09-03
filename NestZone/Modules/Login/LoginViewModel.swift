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
    func signInWithApple(authManager: ConvexAuthManager) async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.signInWithApple()
        } catch AppleSignInCoordinator.Failure.cancelled {
            // User dismissed the Apple sheet — not an error.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
