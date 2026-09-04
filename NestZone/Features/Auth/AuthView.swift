import AuthenticationServices
import ComposableArchitecture
import SwiftUI

/// The sign-in screen.
///
/// The old version stacked a full-screen `LinearGradient`, a blurred circle, two
/// gradient-filled `Text` views and an `AngularGradient` ring behind the icon —
/// then put a transparent `Button` on top of a `SignInWithAppleButton` that had
/// `allowsHitTesting(false)`, so the real Apple button was decoration. Here the
/// Apple button is the actual control, and the only decoration is one soft wash
/// behind the glass.
public struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    public init(store: StoreOf<AuthFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                GlassGroup(spacing: 28) {
                    VStack(spacing: 28) {
                        mark.appear(0)
                        headline.appear(1)
                        signInCard.appear(2)
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)

                Spacer(minLength: 0)

                Text(L10n.authAppleExplainer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    .appear(3)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    /// One vertical wash in the theme accent. It exists so the glass above has
    /// something to refract; anything busier just muddies it.
    private var backdrop: some View {
        LinearGradient(
            colors: [
                theme.accent.opacity(colorScheme == .dark ? 0.28 : 0.16),
                .clear,
            ],
            startPoint: .top,
            endPoint: .center
        )
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }

    private var mark: some View {
        Image(systemName: "house.fill")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(theme.accent)
            .frame(width: 84, height: 84)
            .glassEffect(.regular.tint(theme.accent.opacity(0.18)), in: .circle)
            .symbolEffect(.bounce, options: .nonRepeating)
    }

    private var headline: some View {
        VStack(spacing: 8) {
            Text(L10n.authWelcomeTitle)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(L10n.authSignInSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var signInCard: some View {
        VStack(spacing: 16) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                store.send(handle(result))
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(.rect(cornerRadius: Metrics.tightRadius, style: .continuous))
            .opacity(store.isSigningIn ? 0.5 : 1)
            .disabled(store.isSigningIn)
            .overlay {
                if store.isSigningIn {
                    ProgressView()
                        .tint(colorScheme == .dark ? .black : .white)
                }
            }
            .animation(Motion.fade, value: store.isSigningIn)
        }
        .padding(Metrics.cardPadding)
        .glassCard()
    }

    /// Maps `ASAuthorization` into the feature's vocabulary. Kept out of the
    /// reducer so the reducer never sees an AuthenticationServices type.
    private func handle(
        _ result: Result<ASAuthorization, any Error>
    ) -> AuthFeature.Action {
        switch result {
        case let .success(authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let data = credential.identityToken,
                let token = String(data: data, encoding: .utf8)
            else {
                return .appleSignInFailed(.server(String(
                    localized: "auth.appleNoToken",
                    defaultValue: "Apple didn't return a sign-in token. Please try again."
                )))
            }
            let name = credential.fullName.flatMap { components -> String? in
                let formatted = PersonNameComponentsFormatter
                    .localizedString(from: components, style: .default)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return formatted.isEmpty ? nil : formatted
            }
            return .appleSignInSucceeded(
                AppleCredential(identityToken: token, displayName: name)
            )

        case let .failure(error):
            // Backing out of Apple's sheet is not a failure worth an alert.
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return .appleSignInFailed(.cancelled)
            }
            return .appleSignInFailed(AppError(error))
        }
    }
}

#Preview {
    AuthView(store: Store(initialState: AuthFeature.State()) { AuthFeature() })
        .appTheme(.basic)
}
