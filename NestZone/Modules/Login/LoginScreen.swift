import SwiftUI
import AuthenticationServices

/// Sign in with Apple only — NestZone stores no passwords. See convex/auth.ts.
struct LoginScreen: View {
    // MARK: - Properties
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var authManager: ConvexAuthManager
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            Text("NestZone")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(LocalizationManager.authAppleExplainer)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 32)

            ZStack {
                SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .allowsHitTesting(false)
                    .opacity(viewModel.isLoading ? 0.4 : 1)

                // Our own coordinator drives the request so cancellation and the
                // token exchange are handled in one place.
                Button {
                    Task { await viewModel.signInWithApple(authManager: authManager) }
                } label: {
                    Color.clear.frame(height: 50).contentShape(Rectangle())
                }
                .disabled(viewModel.isLoading)

                if viewModel.isLoading {
                    ProgressView().tint(.black)
                }
            }
            .padding(.horizontal, 32)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("Sign in with Apple"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.ignoresSafeArea())
        .alert(
            "Error",
            isPresented: .constant(viewModel.errorMessage != nil),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("OK") { viewModel.errorMessage = nil }
        } message: { item in
            Text(item)
        }
    }
}

// MARK: - Preview
#Preview {
    LoginScreen()
        .environmentObject(ConvexAuthManager())
}
