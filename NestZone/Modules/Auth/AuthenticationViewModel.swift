import Foundation

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// The only sign-in path. There is no separate register flow: Apple reports
    /// whether this is a first authorization and the backend creates the account
    /// on demand, so one button covers both cases.
    func signInWithApple(authManager: ConvexAuthManager) async {
        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signInWithApple()
        } catch AppleSignInCoordinator.Failure.cancelled {
            // User dismissed the Apple sheet — that's not an error worth showing.
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
