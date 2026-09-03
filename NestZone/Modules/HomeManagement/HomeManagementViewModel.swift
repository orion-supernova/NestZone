import SwiftUI
import Foundation

@MainActor
class HomeManagementViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var homeCreated = false
    @Published var homeJoined = false
    /// Incremented on every rejection so the submit button can shake. A counter
    /// rather than a Bool, so two identical errors in a row still register.
    @Published var errorShakeCount = 0
    
    func createHome(name: String, address: String?, authManager: ConvexAuthManager) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showErrorMessage(LocalizationManager.homeManagementHomeNameEmpty)
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // `homes:create` inserts the home with the caller as the sole member and
            // mirrors the membership onto the user, all server-side, in one transaction.
            // (Free-text `address` isn't sent — the Convex schema expects a {lat,lng}
            //  geopoint; address capture is a follow-up.)
            try await Convex.run("homes:create", args: ["name": trimmed])

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                homeCreated = true
            }
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    func joinHome(inviteCode: String, authManager: ConvexAuthManager) async {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            showErrorMessage(LocalizationManager.homeManagementInviteCodeEmpty)
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // `homes:join` validates the invite code and updates both home.members and
            // user.home_id server-side. An invalid code throws "Invalid invite code".
            try await Convex.run("homes:join", args: ["inviteCode": code])

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                homeJoined = true
            }
        } catch {
            let text = String(describing: error)
            if text.contains("Invalid invite code") {
                showErrorMessage(LocalizationManager.homeManagementInvalidInviteCode)
            } else {
                showErrorMessage(error.localizedDescription)
            }
        }

        isLoading = false
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        errorShakeCount += 1
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
