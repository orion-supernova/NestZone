import SwiftUI

/// The row for a stretch of the same thing by the same person: "Sam added 6
/// things to Shopping", the names on one line beneath, a tap to open them.
///
/// Opening is the whole job of this row, so it carries a chevron that turns
/// rather than the routing chevron the single rows have; each row inside goes
/// where it always went. It is unread when anything inside it is.
struct ActivityRunHeader: View {
    let run: ActivityRun
    let isNew: Bool
    let isOpen: Bool
    let toggle: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The person in bold, as the single rows have them.
    private var sentence: AttributedString {
        var text = AttributedString(run.sentence ?? "")
        if let name = run.first.shownActorName, let range = text.range(of: name) {
            text[range].font = .subheadline.weight(.bold)
        }
        return text
    }

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .center, spacing: 12) {
                face

                VStack(alignment: .leading, spacing: 2) {
                    Text(sentence)
                        .font(.subheadline)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: run.first.category.symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(run.first.category.tint)
                        Text(run.preview)
                            .font(.footnote)
                            .foregroundStyle(.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    RelativeTimeText(run.first.created)
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                    if isNew {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .animation(reduceMotion ? nil : Motion.spring, value: isOpen)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isNew ? theme.accent.opacity(0.07) : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(Text(isOpen ? L10n.inboxShowLess : L10n.commonMore))
    }

    @ViewBuilder
    private var face: some View {
        if let actor = run.first.actor, let name = run.first.shownActorName {
            Avatar(initials: User.initials(from: name), seed: actor.rawValue, size: 34, viewable: false)
        } else {
            Image(systemName: run.first.category.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(run.first.category.tint)
                .frame(width: 34, height: 34)
                .background(run.first.category.tint.opacity(0.16), in: .circle)
        }
    }
}
