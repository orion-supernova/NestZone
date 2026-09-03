import Foundation

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(authManager: ConvexAuthManager, email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func register(authManager: ConvexAuthManager, email: String, password: String, fullName: String) async {
        isLoading = true
        errorMessage = nil

        // Basic client-side guard retained from the PocketBase flow.
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            isLoading = false
            return
        }

        do {
            try await authManager.signUp(email: email, password: password, name: fullName)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
