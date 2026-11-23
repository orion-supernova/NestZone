import ComposableArchitecture
import SwiftUI

/// One report: what was reported, who by, and the decisions.
struct ReportDetailView: View {
    @Bindable var store: StoreOf<ReportDetailFeature>

    @Environment(\.theme) private var theme

    private var row: ReportRow { store.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                header
                content
                if let note = row.note, !note.isEmpty { noteCard(note) }
                if store.isOpen { actions } else { resolution }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.screenPadding)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(row.kind.title))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .confirmationDialog($store.scope(state: \.confirm, action: \.confirm))
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(row.reason.title).font(.headline)
                } icon: {
                    Image(systemName: row.kind.symbol)
                }
                Spacer(minLength: 8)
                ReportAgeLabel(created: row.created)
            }
            Text(L10n.moderationRowWho(
                row.reporterName ?? String(localized: L10n.avatarSomeone),
                row.targetUserName ?? String(localized: L10n.avatarSomeone)
            ))
            .font(.subheadline)
            .foregroundStyle(.secondaryText)
            if let home = row.homeName, !home.isEmpty {
                Text(home)
                    .font(.footnote)
                    .foregroundStyle(Palette.accessory)
            }
        }
    }

    /// The thing itself: the words, or the picture.
    @ViewBuilder
    private var content: some View {
        if store.isLoading, store.detail == nil {
            SkeletonList(rows: 1, height: 140)
        } else if let detail = store.detail {
            VStack(alignment: .leading, spacing: 12) {
                if let text = detail.snapshot.text, !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(Metrics.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                }
                if let url = detail.fileURL {
                    RemoteImage(
                        url: url,
                        targetSize: CGSize(width: 800, height: 800),
                        contentMode: .fit
                    )
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .clipShape(.rect(cornerRadius: Metrics.cardRadius, style: .continuous))
                    .accessibilityLabel(Text(L10n.moderationPhotoAccessibility))
                }
                if let title = detail.snapshot.issueTitle, !title.isEmpty {
                    Text(L10n.moderationOnProblem(title))
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                }
                statusLines(detail)
            }
        }
    }

    /// Where things stand now, so a decision is not made on a stale picture.
    @ViewBuilder
    private func statusLines(_ detail: ReportDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !detail.stillExists { statusLine("trash", L10n.moderationAlreadyGone) }
            if !detail.targetInHome { statusLine("person.slash", L10n.moderationNotInHome) }
            if detail.targetChatSuspended { statusLine("pause.circle", L10n.moderationChatPaused) }
        }
    }

    private func statusLine(_ symbol: String, _ text: LocalizedStringResource) -> some View {
        Label { Text(text) } icon: { Image(systemName: symbol) }
            .font(.footnote)
            .foregroundStyle(.secondaryText)
    }

    private func noteCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.moderationNoteHeader)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondaryText)
            Text(note).font(.subheadline)
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// The five decisions. Destructive ones are confirmed by the reducer.
    private var actions: some View {
        let detail = store.detail
        let canAct = detail != nil && !store.isWorking
        return VStack(spacing: 10) {
            SecondaryButton(L10n.moderationDismiss, symbol: "xmark") { store.send(.dismissTapped) }
                .disabled(!canAct)

            PrimaryButton(L10n.moderationDelete, symbol: "trash", role: .destructive) {
                store.send(.deleteTapped)
            }
            .disabled(!canAct || detail?.stillExists != true)

            PrimaryButton(L10n.moderationRemove, symbol: "person.crop.circle.badge.minus", role: .destructive) {
                store.send(.removeTapped)
            }
            .disabled(!canAct || detail?.targetInHome != true)

            if detail?.targetChatSuspended == true {
                SecondaryButton(L10n.moderationUnsuspend, symbol: "play.circle") {
                    store.send(.unsuspendTapped)
                }
                .disabled(!canAct)
            } else {
                SecondaryButton(L10n.moderationSuspend, symbol: "pause.circle") {
                    store.send(.suspendTapped)
                }
                .disabled(!canAct)
            }
        }
    }

    /// A report somebody already decided, reached from a link or a push.
    @ViewBuilder
    private var resolution: some View {
        if let by = store.detail?.resolvedByName {
            Label { Text(L10n.moderationResolvedBy(by)) } icon: { Image(systemName: "checkmark.seal") }
                .font(.subheadline)
                .foregroundStyle(.secondaryText)
        }
    }
}
