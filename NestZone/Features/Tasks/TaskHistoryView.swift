import ComposableArchitecture
import SwiftUI

/// The household's record of finished work, newest first.
///
/// A `List` for the same reason the Tasks screen is one: the swipe here is the
/// system's, and `UISwipeActionsConfiguration` does not race the glass row's
/// lean the way a hand-rolled gesture does.
public struct TaskHistoryView: View {
    @Bindable var store: StoreOf<TaskHistoryFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<TaskHistoryFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            listingPicker

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
        .navigationTitle(Text(L10n.taskHistoryScreenTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .animation(Motion.spring, value: store.entries)
        .animation(Motion.spring, value: store.listing)
    }

    /// The record, or just what has been put away. Two lists, because the
    /// actions differ: the record is read-only, and the archive is where a
    /// chore can be brought back or — deliberately, behind a dialog — erased.
    private var listingPicker: some View {
        Picker(selection: $store.listing) {
            ForEach(TaskHistoryFeature.State.Listing.allCases, id: \.self) { listing in
                Text(listing.title).tag(listing)
            }
        } label: { EmptyView() }
        .pickerStyle(.segmented)
        .glassListRow(insets: .init(
            top: 0,
            leading: Metrics.screenPadding,
            bottom: Metrics.stackSpacing,
            trailing: Metrics.screenPadding
        ))
    }

    /// What this screen is, in one sentence, before the list of it.
    ///
    /// Worth the space: the whole point of the change that produced this screen
    /// is that the record is not the task list, and somebody who has just
    /// watched a finished chore leave the Done tab needs to be told that it
    /// arrived here and still counts — not left to work it out.
    @ViewBuilder
    private var note: some View {
        if !store.isLoading {
            Label {
                Text(store.listing.note)
            } icon: {
                Image(systemName: store.listing == .archived ? "archivebox" : "checkmark.seal")
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
                title: store.listing == .archived
                    ? L10n.taskHistoryArchivedEmptyTitle
                    : L10n.taskHistoryEmptyTitle,
                message: store.listing == .archived
                    ? L10n.taskHistoryArchivedEmptyMessage
                    : L10n.taskHistoryEmptyMessage,
                symbol: store.listing == .archived ? "archivebox" : "clock.arrow.circlepath"
            )
            .padding(.top, 48)
            .glassListRow()
        } else {
            ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                HistoryRow(
                    entry: entry,
                    isMe: entry.userID != nil && entry.userID == store.currentUserID,
                    isRestoring: store.state.isRestoring(entry),
                    // Redundant in a list where every row is archived. It earns
                    // its place in the record, where it is the one thing
                    // distinguishing these rows from the rest.
                    showsArchivedBadge: store.listing == .all
                )
                .appearInPlace(index < 8 ? index : 0)
                .glassListRow()
                // Deleting a completion is offered in the archive and nowhere
                // else. Putting a chore away is already a statement that the
                // row has done its job; erasing it is a second, separate
                // statement that it should never have existed — and two acts
                // rather than one is the whole difference between this and the
                // single silent swipe it replaces.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if entry.isArchived {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(entry))
                        } label: {
                            Label { Text(L10n.commonDelete) } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    // Only where it would do something. A chore finished longer
                    // ago than the Done window cannot be put back onto a list
                    // that does not reach that far, and the server says so
                    // rather than leaving the screen to guess — see
                    // `canRestore` in convex/tasks.ts. Delete stays available
                    // either way, so no archived chore is ever a dead end.
                    if entry.isArchived, entry.canRestore, !store.state.isRestoring(entry) {
                        Button {
                            store.send(.restoreTapped(entry.taskID))
                        } label: {
                            Label { Text(L10n.taskHistoryRestoreAction) } icon: {
                                Image(systemName: "tray.and.arrow.up")
                            }
                        }
                        .tint(Palette.success)
                    }
                }
            }
        }
    }

    /// Says the list is bounded when it is, rather than implying the household
    /// has done exactly two hundred things.
    @ViewBuilder
    private var footer: some View {
        if !store.isLoading, store.shown.isTruncated {
            Text(L10n.taskHistoryTruncated(store.shown.limit))
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
private struct HistoryRow: View {
    let entry: TaskCompletion
    let isMe: Bool
    let isRestoring: Bool
    let showsArchivedBadge: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let userID = entry.userID {
                Avatar(
                    initials: entry.initials ?? "",
                    seed: userID.rawValue,
                    size: 34
                )
            } else {
                // Work the app cannot attribute — somebody who has left, or a
                // row imported without an author. Drawn rather than dropped, so
                // the history and the split agree on what happened.
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

            VStack(alignment: .trailing, spacing: 5) {
                // Year included: this list reaches back as far as the household
                // does, and "3 Mar" over two years of chores is a date that
                // could be either of them.
                Text(
                    entry.completedAt.date,
                    format: .dateTime.day().month(.abbreviated).year(.twoDigits)
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if entry.isArchived, !isRestoring, showsArchivedBadge {
                    Badge(
                        String(localized: L10n.taskHistoryArchivedBadge),
                        tint: Palette.warning,
                        symbol: "archivebox"
                    )
                }
            }
        }
        .glassRow()
        .accessibilityElement(children: .combine)
    }

    private var credit: String {
        if isMe { return String(localized: L10n.contributionsYou) }
        return entry.displayName ?? String(localized: L10n.contributionsUnattributed)
    }
}
