import Foundation

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let pocketBase = PocketBaseManager.shared
    
    func login(authManager: PocketBaseAuthManager, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func register(authManager: PocketBaseAuthManager, email: String, password: String, fullName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.register(email: email, password: password, fullName: fullName)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}