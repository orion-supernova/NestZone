import SwiftUI

/// A `Chip` for a person: their face and their name.
///
/// Same pill, same press, same tick as `Chip`, with the avatar where the glyph
/// would be. Used where a filter or a choice is about *who*, the people row of
/// the calendar first. The avatar is not viewable here: a tap on it is a tap on
/// the chip.
public struct PersonChip: View {
    private let name: String
    private let initials: String
    private let seed: String
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var taps = 0

    /// - Parameter seed: the user's id, which is what the avatar's tint and
    ///   photo lookup are keyed on everywhere in the app.
    public init(
        name: String,
        initials: String,
        seed: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.initials = initials
        self.seed = seed
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 6) {
                Avatar(initials: initials, seed: seed, size: 22, viewable: false)
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? theme.onAccent : Color.primary)
            .background {
                if isSelected {
                    Capsule().fill(theme.accent)
                }
            }
            .glassEffect(
                isSelected ? .identity : .regular.interactive(),
                in: .capsule
            )
            .contentShape(.capsule)
            // The pill stays as drawn; the finger gets the full 44 points.
            .frame(minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressableQuiet)
        .animation(Motion.spring, value: isSelected)
        .sensoryFeedback(.selection, trigger: taps)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
