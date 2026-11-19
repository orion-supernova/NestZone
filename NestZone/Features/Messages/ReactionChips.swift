import SwiftUI

/// The reactions under a bubble: `emoji count`, filled when one of them is
/// mine. Tapping a chip sets or lifts my own.
///
/// A small view of its own so a reaction arriving redraws this row and not the
/// thread. It is given the reactions of one message, never the whole thread.
struct ReactionChips: View {
    let reactions: [MessageReaction]
    let me: UserID?
    let toggle: (String) -> Void

    @Environment(\.theme) private var theme
    /// Your own taps, counted: the haptic keys on this and never on the model,
    /// which another person's reaction also changes.
    @State private var taps = 0

    var body: some View {
        let tallies = ReactionTally.tally(reactions, me: me)
        FlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach(tallies) { tally in
                Button {
                    taps += 1
                    toggle(tally.emoji)
                } label: {
                    HStack(spacing: 3) {
                        Text(tally.emoji).font(.caption)
                        Text(tally.count, format: .number)
                            .font(.caption2.weight(tally.isMine ? .semibold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(tally.isMine ? .primary : .secondary)
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
                // The haptic is the tap's own, above.
                .buttonStyle(.pressableQuiet)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(tally.isMine
                    ? L10n.reactionChipMine(tally.emoji, tally.count)
                    : L10n.reactionChip(tally.emoji, tally.count)))
                .accessibilityAddTraits(tally.isMine ? .isSelected : [])
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}
