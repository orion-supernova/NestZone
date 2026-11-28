import ComposableArchitecture
import AuthenticationServices
import SwiftUI

/// The tour, full screen: a progress line and Skip over pages that swipe, and
/// one big Continue. Shared by the first run and Settings' "Take the tour".
struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.authorizationController) private var authorizationController

    var body: some View {
        ZStack {
            Backdrop(tint: theme.accent)

            VStack(spacing: 0) {
                topBar
                TabView(selection: $store.index) {
                    ForEach(Array(store.pages.enumerated()), id: \.element) { index, page in
                        OnboardingPageView(store: store, page: page, isCurrent: index == store.index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                footer
            }
        }
        .animation(reduceMotion ? Motion.fade : Motion.travel, value: store.index)
        // Taps and swipes both: a page turning is the person's own doing.
        .sensoryFeedback(.selection, trigger: store.index)
        .sheet(item: $store.scope(state: \.destination?.create, action: \.destination.create)) {
            CreateHomeSheet(store: $0)
        }
        .sheet(item: $store.scope(state: \.destination?.join, action: \.destination.join)) {
            JoinHomeSheet(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .confirmationDialog(
            Text(L10n.settingsDeleteAccountTitle),
            isPresented: $store.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                store.send(.deleteAccountConfirmed)
                Task { await reauthorizeForDeletion() }
            } label: {
                Text(L10n.settingsDeleteAccountConfirm)
            }
            Button(role: .cancel) {} label: { Text(L10n.commonCancel) }
        } message: {
            Text(String(localized: L10n.settingsDeleteAccountMessage)
                + "\n\n" + String(localized: L10n.settingsDeleteAccountSubscriptionNote))
        }
    }

    /// Deleting an account needs a fresh Sign in with Apple, as in Settings.
    private func reauthorizeForDeletion() async {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        do {
            let result = try await authorizationController.performRequest(request)
            guard case let .appleID(credential) = result else {
                store.send(.deleteAccountFailed(.cancelled))
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            store.send(.deleteAccountAuthorized(code: code))
        } catch {
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                store.send(.deleteAccountFailed(.cancelled))
            } else {
                store.send(.deleteAccountFailed(AppError(error)))
            }
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 12) {
            // Balances Skip, so the progress line stays centred.
            Group {
                if store.mode == .replay {
                    Button { store.send(.closeTapped) } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(.secondaryText)
                    .accessibilityLabel(Text(L10n.commonClose))
                } else if store.mode == .firstRun {
                    // The tour stands where the create-or-join screen was, so
                    // it carries that screen's way out.
                    Menu {
                        Button { store.send(.signOutTapped) } label: {
                            Label { Text(L10n.settingsLogoutButtonTitle) } icon: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                            }
                        }
                        Button(role: .destructive) { store.send(.deleteAccountTapped) } label: {
                            Label { Text(L10n.settingsDeleteAccountButton) } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                            .contentShape(.rect)
                    }
                    .foregroundStyle(.secondaryText)
                    .disabled(store.isLeaving)
                    .accessibilityLabel(Text(L10n.commonMore))
                } else {
                    Color.clear
                }
            }
            .frame(width: 64, alignment: .leading)

            progress
                .frame(maxWidth: .infinity)

            Button { store.send(.skipTapped) } label: {
                Text(L10n.onboardingSkip)
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 44, minHeight: Metrics.minTapTarget, alignment: .trailing)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .foregroundStyle(.secondaryText)
            .opacity(store.canSkip ? 1 : 0)
            .disabled(!store.canSkip)
            .accessibilityHidden(!store.canSkip)
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, Metrics.screenPadding - 8)
        .padding(.top, 4)
    }

    /// One capsule per page: the current one is long and filled.
    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(store.pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= store.index ? AnyShapeStyle(theme.accentFill) : AnyShapeStyle(Palette.inset))
                    .frame(width: index == store.index ? 22 : 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.onboardingProgress("\(store.index + 1)", "\(store.pages.count)")))
    }

    @ViewBuilder
    private var footer: some View {
        // The last page of the first run has its own two choices.
        if store.page != .start {
            PrimaryButton(store.page == .done ? L10n.commonDone : L10n.onboardingContinue) {
                store.send(.continueTapped, animation: reduceMotion ? nil : Motion.travel)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.stackSpacing)
            .accessibilityIdentifier("OnboardingContinue")
        }
    }
}
