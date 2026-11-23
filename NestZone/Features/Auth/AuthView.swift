import AuthenticationServices
import ComposableArchitecture
import SwiftUI

/// The sign-in screen.
///
/// The old version stacked a full-screen `LinearGradient`, a blurred circle, two
/// gradient-filled `Text` views and an `AngularGradient` ring behind the icon —
/// then put a transparent `Button` on top of a `SignInWithAppleButton` that had
/// `allowsHitTesting(false)`, so the real Apple button was decoration. Here the
/// Apple button is the actual control, wearing nothing but its own shape — a
/// glass card around it only competed with the one Apple already draws — and
/// the only decoration is one soft wash behind the mark.
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

            // The picture and the words scroll (so a very large type size never
            // clips); the button and the legal line stay put under them. The
            // hero takes a share of the height instead of a fixed size, so a
            // tall phone is filled and a small one is not crowded.
            // The block is centred in the room left above the button, so a tall
            // phone has no empty band between the words and the button; at a
            // large type size it simply scrolls.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        AuthHero()
                            .frame(height: min(max(proxy.size.height * 0.56, 260), 560))
                        headline.appear(6)
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.vertical, 16)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 14) {
                signInButton
                Text(L10n.authLegal)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                    .tint(theme.accent)
                    .multilineTextAlignment(.center)
            }
            .appear(7)
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    /// One vertical wash in the theme accent, so the glass cards have something
    /// to refract; anything busier just muddies them.
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

    private var headline: some View {
        VStack(spacing: 10) {
            Text(L10n.authHeroTitle)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(L10n.authHeroSubtitle)
                .font(.callout)
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var signInButton: some View {
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
