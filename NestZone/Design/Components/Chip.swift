import SwiftUI

/// A small selectable pill — filters, tags, categories.
///
/// Glass when unselected so it sits over content, solid accent when selected so
/// the choice is unmistakable at a glance.
public struct Chip: View {
    private let title: String
    private let symbol: String?
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.theme) private var theme
    /// Taps on this chip. The tick is keyed on them rather than on
    /// `isSelected`, so a selection somebody else's change moved stays silent.
    @State private var taps = 0

    public init(
        _ title: String,
        symbol: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.semibold))
                        // The chip you just chose hops; the one you left goes
                        // quiet. Silent under Reduce Motion.
                        .bounces(when: isSelected)
                }
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                if isSelected {
                    Capsule().fill(theme.accent)
                }
            }
            .glassEffect(
                isSelected ? .identity : .regular.interactive(),
                in: .capsule
            )
            // An unselected chip draws no background, so without a content
            // shape only the label glyphs are tappable.
            .contentShape(.capsule)
        }
        // Quiet: the tap's tick below is this chip's one haptic.
        .buttonStyle(.pressableQuiet)
        .animation(Motion.spring, value: isSelected)
        .sensoryFeedback(.selection, trigger: taps)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// A non-interactive label — a count, a status, a category marker.
public struct Badge: View {
    private let text: String
    private let tint: Color
    private let symbol: String?

    public init(_ text: String, tint: Color, symbol: String? = nil) {
        self.text = text
        self.tint = tint
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                // Most badges in this app are counts — overdue bills, items
                // due — and a count that cuts from 3 to 2 reads as a redraw
                // rather than as one going away. Keyed and animated here so no
                // call site has to remember to.
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: .capsule)
        .animation(Motion.fade, value: text)
    }
}
