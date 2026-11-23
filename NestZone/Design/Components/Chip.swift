import SwiftUI

/// A small selectable pill — filters, tags, categories.
///
/// Glass when unselected so it sits over content, solid accent when selected so
/// the choice is unmistakable at a glance.
public struct Chip: View {
    private let title: String
    private let symbol: String?
    private let isSelected: Bool
    private let expandsTapTarget: Bool
    private let action: () -> Void

    @Environment(\.theme) private var theme
    /// Taps on this chip. The tick is keyed on them rather than on
    /// `isSelected`, so a selection somebody else's change moved stays silent.
    @State private var taps = 0

    public init(
        _ title: String,
        symbol: String? = nil,
        isSelected: Bool = false,
        expandsTapTarget: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.isSelected = isSelected
        self.expandsTapTarget = expandsTapTarget
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
            // The label on the accent fill is the theme's `onAccent` (white
            // was 2.5:1 on Neon Night's green and 3.1 to 3.6 on the pinks).
            .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
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
            // The pill stays as drawn; where a chip sits in a row that is the
            // screen's way of choosing, the finger gets the full 44 points.
            .frame(minHeight: expandsTapTarget ? Metrics.minTapTarget : nil)
            .contentShape(.rect)
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
                Image(systemName: symbol).font(.caption.weight(.bold)).foregroundStyle(tint)
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
        // The words are always the label colour: a tint as text on its own
        // 15% wash is 1.9:1 for amber and 2.1:1 for green on white. The tint
        // keeps the wash and the glyph, so the colour still says which kind.
        .foregroundStyle(.primary)
        .background(tint.opacity(0.22), in: .capsule)
        .animation(Motion.fade, value: text)
    }
}
