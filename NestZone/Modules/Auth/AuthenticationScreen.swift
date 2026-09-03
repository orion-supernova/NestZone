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

    @State private var animateHeader = false
    @State private var animateContent = false

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
                        .opacity(animateHeader ? 1 : 0)
                        .offset(y: animateHeader ? 0 : -40)

                    explainer
                        .padding(.horizontal, 24)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    signInWithAppleButton
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 40)

                    Spacer(minLength: 60)
                }
            }
            .background(background)
            .navigationTitle(LocalizationManager.authSignInTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { animateHeader = true }
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) { animateContent = true }
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
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                ProgressView().tint(colorScheme == .dark ? .black : .white)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Sign in with Apple"))
    }

        private var background: some View {
            ZStack {
                RadialGradient(
                    colors: [
                        theme.background,
                        theme.primaryColor.opacity(0.08),
                        theme.accent.opacity(0.06)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (theme.secondary.first ?? theme.primaryColor).opacity(0.22),
                                    (theme.secondary.first ?? theme.primaryColor).opacity(0.05)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)
                        .offset(x: -50, y: geo.size.height * 0.22)
                        .blur(radius: 26)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [theme.primaryColor.opacity(0.26), theme.primaryColor.opacity(0.06)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 90
                            )
                        )
                        .frame(width: 160, height: 160)
                        .offset(x: geo.size.width - 70, y: geo.size.height * 0.58)
                        .blur(radius: 30)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [theme.accent.opacity(0.22), theme.accent.opacity(0.05)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 120, height: 120)
                        .offset(x: geo.size.width * 0.35, y: geo.size.height * 0.12)
                        .blur(radius: 24)
                }
            }
            .ignoresSafeArea()    }

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
