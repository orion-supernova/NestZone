import SwiftUI

/// One version's shelf: a single row that opens in place.
///
/// The row is the same size open or closed, so opening one never moves the one
/// under the finger; what it opens is the version's own notes. The open state
/// is the panel's (`InboxPanel`), not this view's, so a lazy stack scrolling
/// the shelf off screen and back does not forget it.
struct UpdateGroupView: View {
    let group: UpdateGroup
    /// The watermark the panel opened with, to mark what was new on arrival.
    let seenAt: Timestamp?
    let isOpen: Bool
    let toggle: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasUnread: Bool { group.entries.contains { $0.isNew(since: seenAt) } }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: toggle) { header }
                .buttonStyle(.pressable)
                .accessibilityValue(Text(isOpen ? L10n.inboxShowLess : L10n.commonMore))

            if isOpen {
                VStack(spacing: 10) {
                    ForEach(group.entries) { entry in
                        if entry.isCompact {
                            UpdateFixesBlock(update: entry, isNew: entry.isNew(since: seenAt))
                        } else {
                            UpdateCard(update: entry, isNew: entry.isNew(since: seenAt))
                        }
                    }
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    if let version = group.displayVersion {
                        Text(verbatim: version)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    } else {
                        Text(L10n.inboxKindAnnouncement)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    if group.isComingSoon {
                        Badge(String(localized: L10n.inboxComingSoon), tint: Palette.amber, symbol: "clock")
                    }
                }
                secondLine
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if hasUnread {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(Text(L10n.inboxNew))
            }
            Text(L10n.inboxUpdatesCount(group.entries.count))
                .font(.caption)
                .foregroundStyle(.secondaryText)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.accessory)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
                .animation(reduceMotion ? nil : Motion.spring, value: isOpen)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tinted: group.isComingSoon ? Palette.amber.opacity(0.10) : nil)
        .contentShape(.rect)
    }

    /// Closed: what is in it. Open: when it came, or when it will.
    @ViewBuilder
    private var secondLine: some View {
        if !isOpen {
            Text(group.summary)
        } else if group.isComingSoon, let version = group.version {
            Text(L10n.inboxArrivesIn(version, AppVersion.current.raw))
        } else {
            RelativeTimeText(group.date)
        }
    }
}
