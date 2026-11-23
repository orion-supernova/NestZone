import SwiftUI

/// The reactions under a bubble: `emoji count`, filled when one of them is
/// mine. Tapping a chip sets or lifts my own.
///
/// A small view of its own so a reaction arriving redraws this row and not the
/// thread. It is given the reactions of one message, never the whole thread.
struct ReactionChips: View {
    let reactions: [MessageReaction]
    let me: UserID?
    /// Which edge the row hugs: the bubble's own, so it sits right under it.
    var alignment: HorizontalAlignment = .leading
    let toggle: (String) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tallies = ReactionTally.tally(reactions, me: me)
        FlowLayout(spacing: 4, lineSpacing: 4, alignment: alignment) {
            ForEach(tallies) { tally in
                // The one haptic for the tap is the thread's (`ChatView.react`),
                // which every route to a reaction goes through.
                Button { toggle(tally.emoji) } label: {
                    HStack(spacing: 3) {
                        Text(tally.emoji).font(.caption)
                        Text(tally.count, format: .number)
                            .font(.caption.weight(tally.isMine ? .semibold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(tally.isMine ? .primary : Palette.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        if tally.isMine {
                            Capsule().fill(theme.accent).opacity(0.25)
                        } else {
                            Capsule().fill(.quaternary)
                        }
                    }
                    .overlay {
                        if tally.isMine {
                            Capsule().strokeBorder(theme.accent, lineWidth: 1)
                        }
                    }
                    .contentShape(Capsule().inset(by: -4))
                }
                .buttonStyle(.pressableQuiet)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(tally.isMine
                    ? L10n.reactionChipMine(tally.emoji, tally.count)
                    : L10n.reactionChip(tally.emoji, tally.count)))
                .accessibilityAddTraits(tally.isMine ? .isSelected : [])
                .transition(AnyTransition.scale(scale: 0.6).combined(with: .opacity).reduced(reduceMotion))
            }
        }
    }
}
