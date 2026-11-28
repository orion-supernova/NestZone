import ComposableArchitecture
import SwiftUI

/// The card an invite link opens: whose house, who asked, who lives there.
struct InviteJoinSheet: View {
    let store: StoreOf<InviteJoinFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Backdrop(tint: theme.accent)
            Group {
                if store.didJoin {
                    joined
                } else if let preview = store.preview {
                    if preview.state == .ok || preview.state == .alreadyMember {
                        ask(preview)
                    } else {
                        unusable(preview.state)
                    }
                } else if let message = store.loadError {
                    failed(message)
                } else {
                    ProgressView().accessibilityLabel(Text(L10n.invitePreparing))
                }
            }
            .padding(Metrics.screenPadding)
            .transition(.opacity)
        }
        .animation(reduceMotion ? Motion.fade : Motion.spring, value: store.didJoin)
        .animation(Motion.fade, value: store.preview?.state)
        .presentationDetents([.height(440)])
        .presentationBackground(.regularMaterial)
        .interactiveDismissDisabled(store.isJoining)
        .task { await store.send(.task).finish() }
        .sensoryFeedback(.success, trigger: store.didJoin) { _, joined in joined }
        .sensoryFeedback(.impact(weight: .light), trigger: store.joinTaps)
    }

    private func ask(_ preview: InvitePreview) -> some View {
        VStack(spacing: Metrics.stackSpacing) {
            Image(systemName: "house.fill")
                .font(.title)
                .foregroundStyle(.accentText)
                .frame(width: 64, height: 64)
                .glassEffect(.regular.tint(theme.accent.opacity(0.18)), in: .circle)
                .appear(0)

            VStack(spacing: 6) {
                Text(L10n.inviteJoinTitle(preview.homeName ?? ""))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let inviter = preview.inviter {
                    Text(L10n.inviteJoinInvitedBy(inviter.displayName))
                        .font(.subheadline)
                        .foregroundStyle(.secondaryText)
                }
            }
            .appear(1)

            if !preview.members.isEmpty {
                VStack(spacing: 8) {
                    AvatarStack(
                        members: preview.members.map { .init(id: $0.id.rawValue, initials: $0.initials) },
                        size: 40, maxVisible: 5
                    )
                    if let count = preview.memberCount {
                        Text(L10n.inviteJoinMembers("\(count)"))
                            .font(.footnote)
                            .foregroundStyle(.secondaryText)
                    }
                }
                .appear(2)
            }

            if let message = store.inlineError {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Palette.dangerText)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                PrimaryButton(L10n.inviteJoinButton, isLoading: store.isJoining) {
                    store.send(.joinTapped)
                }
                SecondaryButton(L10n.inviteNotNow) { store.send(.notNowTapped) }
                    .disabled(store.isJoining)
            }
            .appear(3)
        }
    }

    private var joined: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Palette.success)
                .bounces()
            Text(L10n.inviteJoinedSuccess).font(.headline)
        }
    }

    private func unusable(_ state: InvitePreview.State) -> some View {
        VStack(spacing: Metrics.stackSpacing) {
            Image(systemName: "link.badge.plus")
                .font(.title)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 64, height: 64)
                .glassEffect(.regular, in: .circle)
            VStack(spacing: 6) {
                Text(message(for: state))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.inviteAskForNew)
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            PrimaryButton(L10n.inviteGotIt) { store.send(.notNowTapped) }
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: Metrics.stackSpacing) {
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            PrimaryButton(L10n.inviteTryAgain) { store.send(.task) }
            SecondaryButton(L10n.inviteNotNow) { store.send(.notNowTapped) }
        }
    }

    private func message(for state: InvitePreview.State) -> LocalizedStringResource {
        switch state {
        case .expired: L10n.inviteStateExpired
        case .full: L10n.inviteStateFull
        case .revoked: L10n.inviteStateRevoked
        case .ok, .alreadyMember, .invalid: L10n.inviteStateInvalid
        }
    }
}
