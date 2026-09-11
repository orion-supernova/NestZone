import ComposableArchitecture
import SwiftUI

/// The chores that have aged off the Done list, newest first.
///
/// A `List` for the same reason the Tasks screen is one: the swipe here is the
/// system's, and `UISwipeActionsConfiguration` does not race the glass row's
/// lean the way a hand-rolled gesture does.
public struct TaskArchiveView: View {
    @Bindable var store: StoreOf<TaskArchiveFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<TaskArchiveFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            note

            content

            footer
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, Metrics.scrollBottomInset, for: .scrollContent)
        .environment(\.defaultMinListRowHeight, 0)
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.taskArchiveScreenTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .animation(Motion.spring, value: store.entries)
    }

    /// What this list is, before the rows rather than after them — the same
    /// rule the Tasks screen follows.
    ///
    /// Worth the space: somebody arriving here has just watched a finished
    /// chore leave the Done tab, and the two things they need to know are that
    /// it landed here and that it still counts. Neither is guessable.
    @ViewBuilder
    private var note: some View {
        if !store.isLoading {
            Label {
                Text(L10n.taskArchiveNote(store.archive.windowDays))
            } icon: {
                Image(systemName: "archivebox")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassListRow(insets: .init(
                top: 0,
                leading: Metrics.screenPadding,
                bottom: Metrics.stackSpacing,
                trailing: Metrics.screenPadding
            ))
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading {
            SkeletonList(rows: 6, height: 56)
                .glassListRow()
        } else if store.entries.isEmpty {
            EmptyStateView(
                title: L10n.taskArchiveEmptyTitle,
                message: L10n.taskArchiveEmptyMessage(store.archive.windowDays),
                symbol: "archivebox"
            )
            .padding(.top, 48)
            .glassListRow()
        } else {
            ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                ArchiveRow(
                    entry: entry,
                    isMe: entry.userID != nil && entry.userID == store.currentUserID
                )
                .appearInPlace(index < 8 ? index : 0)
                .glassListRow()
                // No full swipe. Deleting a completion moves the contribution
                // split, and a gesture that fires by carrying on past the edge
                // is not the gesture for that — even with the dialog behind it,
                // the swipe itself should take a deliberate stop.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.send(.deleteTapped(entry))
                    } label: {
                        Label { Text(L10n.commonDelete) } icon: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }

    /// Says the list is bounded when it is, rather than implying the household
    /// has done exactly two hundred things.
    @ViewBuilder
    private var footer: some View {
        if !store.isLoading, store.archive.isTruncated {
            Text(L10n.taskArchiveTruncated(store.archive.limit))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Metrics.stackSpacing)
                .glassListRow(insets: .init(
                    top: 0,
                    leading: Metrics.screenPadding,
                    bottom: 0,
                    trailing: Metrics.screenPadding
                ))
        }
    }
}

// MARK: - Row

/// One finished chore: what it was, who did it, when.
private struct ArchiveRow: View {
    let entry: TaskCompletion
    let isMe: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let userID = entry.userID {
                Avatar(initials: entry.initials ?? "", seed: userID.rawValue, size: 34)
            } else {
                // Work the app cannot attribute — somebody who has left, or a
                // row imported without an author. Drawn rather than dropped, so
                // the archive and the split agree on what happened.
                Circle()
                    .fill(.quaternary)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "person.fill.questionmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(credit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Label {
                        Text(entry.kind.title)
                    } icon: {
                        Image(systemName: entry.kind.symbol)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            // Year included: this list reaches back as far as the household
            // does, and "3 Mar" over two years of chores is a date that could
            // be either of them.
            Text(
                entry.completedAt.date,
                format: .dateTime.day().month(.abbreviated).year(.twoDigits)
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .glassRow()
        .accessibilityElement(children: .combine)
    }

    private var credit: String {
        if isMe { return String(localized: L10n.contributionsYou) }
        return entry.displayName ?? String(localized: L10n.contributionsUnattributed)
    }
}
