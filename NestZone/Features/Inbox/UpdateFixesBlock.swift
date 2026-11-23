import SwiftUI

/// A version's small fixes, as the list they are.
///
/// No card and no story: a glyph and a title, then one line per fix. It sits
/// straight on the backdrop so a version with a handful of fixes does not cost
/// a glass surface of its own.
struct UpdateFixesBlock: View {
    let update: AppUpdate
    let isNew: Bool

    @Environment(\.theme) private var theme

    private var text: LocalizedUpdate { update.text() }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: update.kind.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(update.kind.tint)
                    .accessibilityHidden(true)
                Text(text.title)
                    .font(.subheadline.weight(.semibold))
                if isNew {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel(Text(L10n.inboxNew))
                }
            }

            // The sentence only when there are no lines to say it with.
            if text.highlights.isEmpty {
                Text(text.body)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(text.highlights.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Circle()
                        .fill(update.kind.tint)
                        .frame(width: 5, height: 5)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
