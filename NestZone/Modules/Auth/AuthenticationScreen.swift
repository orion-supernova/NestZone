import SwiftUI
import AuthenticationServices

/// Sign in with Apple is the only way into NestZone. There is no email/password
/// form and no separate register flow: Apple reports whether this is a first
/// authorization, and the backend creates the account on demand keyed on Apple's
/// stable `sub`. See convex/auth.ts.
struct AuthenticationScreen: View {
    @EnvironmentObject private var authManager: ConvexAuthManager
    @StateObject private var viewModel = AuthenticationViewModel()
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme

    private var theme: ThemeColors {
        selectedTheme.colors(for: colorScheme)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .appear(step: 0)

                    explainer
                        .padding(.horizontal, 24)
                        .appear(step: 1)

                    signInWithAppleButton
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .appear(step: 2)

                    Spacer(minLength: 60)
                }
            }
            .background(background)
            .navigationTitle(LocalizationManager.authSignInTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(LocalizationManager.commonErrorTitle, isPresented: .constant(viewModel.errorMessage != nil)) {
            Button(LocalizationManager.commonOkButton) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var explainer: some View {
        Text(LocalizationManager.authAppleExplainer)
            .font(.system(size: 14, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(theme.secondaryPrimaryColor)
            .frame(maxWidth: .infinity)
    }

    private var signInWithAppleButton: some View {
        ZStack {
            SignInWithAppleButton(.signIn) { _ in
                // The request is built and run by AppleSignInCoordinator so the
                // same flow is reachable from LoginScreen too; this closure is
                // only here to satisfy the button's API.
            } onCompletion: { _ in }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .allowsHitTesting(false)
                .opacity(viewModel.isLoading ? 0.4 : 1)

            // Transparent tap target: drives our own coordinator rather than the
            // button's built-in request, so cancellation and token exchange are
            // handled in one place.
            Button {
                Task { await viewModel.signInWithApple(authManager: authManager) }
            } label: {
                Color.clear.frame(height: 52).contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                ProgressView().tint(colorScheme == .dark ? .black : .white)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Sign in with Apple"))
    }

        /// Deliberately plain: a soft vertical wash and one very low-contrast
    /// shape. The old version stacked three blurred radial "glow" circles, which
    /// fought with the content and cost a full-screen blur every frame.
    private var background: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    theme.primaryColor.opacity(colorScheme == .dark ? 0.14 : 0.07),
                    theme.background
                ],
                startPoint: .top,
                endPoint: .center
            )
            Circle()
                .fill(theme.primaryColor.opacity(0.05))
                .frame(width: 320, height: 320)
                .offset(y: -190)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.authWelcomeTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(LocalizationManager.authSignInSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.secondaryPrimaryColor, theme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: theme.primary + [theme.accent],
                            center: .center
                        )
                    )
                    .frame(width: 52, height: 52)
                Circle()
                    .fill(theme.background)
                    .frame(width: 48, height: 48)
                Image(systemName: "house.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }}
