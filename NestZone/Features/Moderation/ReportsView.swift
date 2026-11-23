import ComposableArchitecture
import SwiftUI

/// The moderators' queue, as a sheet from the bell's menu.
struct ReportsView: View {
    @Bindable var store: StoreOf<ReportsFeature>

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack {
                Backdrop(tint: theme.accent)

                if store.isLoading {
                    SkeletonList(rows: 4, height: 96)
                        .padding(.horizontal, Metrics.screenPadding)
                        .frame(maxHeight: .infinity, alignment: .top)
                } else if store.rows.isEmpty {
                    EmptyStateView(
                        title: L10n.moderationQueueEmptyTitle,
                        message: L10n.moderationQueueEmptyMessage,
                        symbol: "checkmark.shield"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.rows) { row in
                                ReportRowView(row: row) { store.send(.rowTapped(row)) }
                                    .onAppear {
                                        if row.id == store.rows.last?.id { store.send(.reachedEnd) }
                                    }
                            }
                            if store.isLoadingMore {
                                ProgressView().padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, Metrics.screenPadding)
                        .padding(.bottom, Metrics.screenPadding)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                }
            }
            .navigationTitle(Text(L10n.moderationTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(L10n.commonDone) }
                }
            }
            .task { await store.send(.task).finish() }
            .alert($store.scope(state: \.alert, action: \.alert))
        } destination: { store in
            switch store.case {
            case let .detail(store): ReportDetailView(store: store)
            }
        }
        .presentationDragIndicator(.visible)
    }
}

/// How long ago, going red once a report has waited past the twelve hours the
/// moderators promise to answer within. Its own view so the colour follows the
/// clock rather than the row's last redraw.
struct ReportAgeLabel: View {
    let created: Timestamp

    /// The server reminds the moderators at the same mark.
    static let staleAfter: TimeInterval = 12 * 3600

    var body: some View {
        let _ = RelativeTimeClock.shared.tick
        let isStale = Date.now.timeIntervalSince(created.date) > Self.staleAfter
        RelativeTime.text(for: created.date)
            .font(.caption.weight(isStale ? .semibold : .regular))
            .foregroundStyle(isStale ? Palette.danger : Palette.accessory)
            .accessibilityValue(isStale ? Text(L10n.moderationOverdue) : Text(""))
    }
}

extension ReportKind {
    var symbol: String {
        switch self {
        case .message: "bubble.left.fill"
        case .issuePhoto: "photo.fill"
        case .avatar: "person.crop.circle.fill"
        case .calendarItem: "calendar"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .message: L10n.moderationKindMessage
        case .issuePhoto: L10n.moderationKindPhoto
        case .avatar: L10n.moderationKindFace
        case .calendarItem: L10n.moderationKindCalendar
        }
    }
}

private struct ReportRowView: View {
    let row: ReportRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.kind.symbol)
                    .font(.body)
                    .foregroundStyle(.secondaryText)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.reason.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        ReportAgeLabel(created: row.created)
                    }
                    if let preview = row.preview, !preview.isEmpty {
                        Text(preview)
                            .font(.footnote)
                            .foregroundStyle(.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Text(L10n.moderationRowWho(
                        row.reporterName ?? String(localized: L10n.avatarSomeone),
                        row.targetUserName ?? String(localized: L10n.avatarSomeone)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondaryText)
                    .lineLimit(1)
                    if let home = row.homeName, !home.isEmpty {
                        Text(home)
                            .font(.caption2)
                            .foregroundStyle(Palette.accessory)
                            .lineLimit(1)
                    }
                }
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
        .accessibilityElement(children: .combine)
    }
}
