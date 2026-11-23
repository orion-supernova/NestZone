import SwiftUI

/// One feature note, as a card that costs about a third of a screen.
///
/// Title, two lines of the story and the first three highlights; one button
/// opens the rest. Everything stays reachable, none of it is in the way. A
/// small-fixes entry is not this card (`UpdateFixesBlock`), and the version,
/// state and date live on the shelf (`UpdateGroupView`) unless the note is
/// pinned out on its own and has to say which version it is.
struct UpdateCard: View {
    let update: AppUpdate
    let isNew: Bool
    /// A pinned note sits outside any version's shelf, so it names its own.
    var showsVersion = false

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private static let collapsedHighlights = 3

    /// In the language this app is set to, English when it was never written.
    private var text: LocalizedUpdate { update.text() }

    /// About two lines at the card's width; a shorter body has nothing to open.
    private var isLongBody: Bool { text.body.count > 85 || text.body.contains("\n") }

    private var hiddenHighlights: Int {
        max(0, text.highlights.count - Self.collapsedHighlights)
    }

    private var canExpand: Bool { isLongBody || hiddenHighlights > 0 }

    private var shownHighlights: ArraySlice<String> {
        isExpanded ? text.highlights[...] : text.highlights.prefix(Self.collapsedHighlights)
    }

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                header

                Text(text.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                if !shownHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(shownHighlights.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Circle()
                                    .fill(update.kind.tint)
                                    .frame(width: 5, height: 5)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                                Text(line)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if canExpand {
                    Button {
                        withAnimation(reduceMotion ? Motion.fade : Motion.spring) { isExpanded.toggle() }
                    } label: {
                        Text(label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.accentText)
                            .frame(minHeight: 24, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var label: LocalizedStringResource {
        if isExpanded { return L10n.inboxShowLess }
        return hiddenHighlights > 0 ? L10n.inboxMoreCount(hiddenHighlights) : L10n.commonMore
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: update.kind.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(update.kind.tint)
                .accessibilityHidden(true)

            Text(text.title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if update.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondaryText)
                    .accessibilityLabel(Text(L10n.inboxPinned))
            }
            if showsVersion, let version = update.version, !version.isEmpty {
                Text(L10n.inboxVersionChip(version))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondaryText)
            }
            if isNew {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(Text(L10n.inboxNew))
            }
        }
    }
}
