import ComposableArchitecture
import SwiftUI

/// "Invite someone": the code to scan, who may use it, and a link to send.
struct InviteSheet: View {
    @Bindable var store: StoreOf<InviteFeature>

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Dependency(\.invite) private var invite

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    header.appear(0)
                    codeCard.appear(1)
                    countdown.appear(2)
                    limitPicker.appear(3)
                    shareButton.appear(4)
                    if let message = store.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Palette.dangerText)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.inviteTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(L10n.commonDone) }
                }
            }
        }
        .presentationBackground(.regularMaterial)
        .task { await store.send(.task).finish() }
        // Nothing is made or watched while the app is away.
        .onChange(of: scenePhase) { _, phase in
            store.send(.sceneActiveChanged(phase == .active))
        }
        // A code left on a closed sheet is no use to anybody: take it back.
        .onDisappear {
            guard let code = store.qr else { return }
            let homeID = store.homeID
            Task { try? await invite.revoke(homeID, code.token) }
        }
        .sensoryFeedback(.selection, trigger: store.picks)
        .sheet(item: $store.share) { item in
            ActivityView(items: [item.text]).presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(store.homeName)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(L10n.inviteScanHint)
                .font(.subheadline)
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Code

    private var codeCard: some View {
        ZStack {
            if let code = store.qr {
                QRCodeView(text: code.url.absoluteString)
                    .opacity(store.isCreating || store.isRevoked || store.showsJoined ? 0.12 : 1)
                    .accessibilityLabel(Text(L10n.inviteQRLabel(store.homeName)))
                    .accessibilityHidden(store.isRevoked)
            } else {
                Color.white.opacity(0.0001)
                    .aspectRatio(1, contentMode: .fit)
            }
            overlay
        }
        .frame(maxWidth: 280)
        .animation(reduceMotion ? Motion.fade : Motion.pop, value: store.showsJoined)
        .animation(Motion.fade, value: store.isRevoked)
    }

    @ViewBuilder
    private var overlay: some View {
        if store.showsJoined {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Palette.success)
                    .bounces()
                Text(L10n.inviteJoinedPop).font(.headline)
            }
            .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
        } else if store.isRevoked || (store.qr == nil && store.errorMessage != nil) {
            Button { store.send(.refreshTapped) } label: {
                Label { Text(L10n.inviteTapForNew) } icon: { Image(systemName: "arrow.clockwise") }
                    .font(.headline)
            }
            .buttonStyle(.pressableQuiet)
            .padding(14)
            .glassEffect(.regular.interactive(), in: .capsule)
        } else if store.isCreating {
            ProgressView().accessibilityLabel(Text(L10n.invitePreparing))
        }
    }

    /// "Changes in 9:41", counted by the system (`Text(timerInterval:)` and
    /// `ProgressView(timerInterval:)` draw themselves), so nothing here ticks.
    @ViewBuilder
    private var countdown: some View {
        if let code = store.qr, !store.isRevoked, code.expiresAt > .now {
            let range = code.expiresAt.addingTimeInterval(-600)...code.expiresAt
            VStack(spacing: 8) {
                ProgressView(timerInterval: range, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(theme.accent)
                    .frame(maxWidth: 220)
                HStack(spacing: 4) {
                    Text(L10n.inviteChangesIn)
                    Text(timerInterval: range, countsDown: true, showsHours: false)
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Who can use it

    private var limitPicker: some View {
        VStack(spacing: 10) {
            Text(L10n.inviteUsesTitle)
                .font(.subheadline.weight(.semibold))
            InnerSwitch(
                options: InviteLimit.allCases,
                selected: store.limit,
                title: { $0.title },
                inset: 0
            ) { store.send(.limitPicked($0), animation: reduceMotion ? nil : Motion.spring) }
            if let line = joinedLine {
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : Motion.dataDraw, value: store.status?.uses)
            }
        }
    }

    private var joinedLine: LocalizedStringResource? {
        guard store.qr != nil else { return nil }
        let uses = store.status?.uses ?? 0
        if let max = store.status?.maxUses ?? store.limit.maxUses {
            return L10n.inviteJoinedOf("\(uses)", "\(max)")
        }
        return uses > 0 ? L10n.inviteJoinedCount("\(uses)") : nil
    }

    // MARK: Link

    private var shareButton: some View {
        SecondaryButton(L10n.inviteShareLink, symbol: store.isMakingLink ? nil : "square.and.arrow.up") {
            store.send(.shareLinkTapped)
        }
        .disabled(store.isMakingLink)
        .overlay { if store.isMakingLink { ProgressView() } }
    }
}

extension InviteLimit {
    fileprivate var title: LocalizedStringResource {
        switch self {
        case .one: L10n.inviteLimitOne
        case .three: L10n.inviteLimitThree
        case .five: L10n.inviteLimitFive
        case .anyone: L10n.inviteLimitAnyone
        }
    }
}
