import SwiftUI

/// The switch between the faces of one screen: To do, Done and All; Ours and
/// Explore; Month, Week and Agenda; Overview, Expenses, Bills and Budgets.
///
/// One component for every one of them, so a face switch looks and behaves the
/// same wherever it is. A sliding pill in the theme's accent on glass, not a
/// system segmented control: that draws its own opaque track under the blur,
/// and stacked under the type-set segment switch at the top of a tab it read as
/// one control that had grown a second row (`SegmentSwitch`).
///
/// The caller owns the selection — a TCA state or a binding — and is told about
/// a tap through `select`; this view keeps only the pill's own motion.
struct InnerSwitch<Option: Hashable>: View {
    let options: [Option]
    let selected: Option
    var title: (Option) -> LocalizedStringResource
    /// A glyph beside each name, or none: two short names (Ours, Explore)
    /// read better bare.
    var symbol: ((Option) -> String)?
    /// Side margin. Zero where the host row already insets, as in a `List`.
    var inset: CGFloat = Metrics.screenPadding
    /// Told which one was tapped.
    var select: (Option) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill
    /// One per tap, for the tick: the person's own action, never a value a
    /// live subscription can also change.
    @State private var taps = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button {
                    guard !isSelected else { return }
                    taps += 1
                    select(option)
                } label: {
                    HStack(spacing: 5) {
                        if let symbol {
                            Image(systemName: symbol(option))
                                .font(.caption2.weight(.semibold))
                                // The glyph you just chose acknowledges the
                                // tap; the one you left goes quiet.
                                .bounces(when: isSelected)
                        }
                        Text(title(option))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? theme.onAccent : Palette.textSecondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    // Each slot only marks where the pill can land.
                    .matchedGeometryEffect(id: option, in: pill)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        // One pill for the whole control rather than one per slot: a pill that
        // is a different view in every slot can glide between them, but it
        // cannot stretch on the way, because nothing lives through the move.
        .background {
            Capsule()
                .fill(theme.accentFill)
                .matchedGeometryEffect(id: selected, in: pill, isSource: false)
                // Pulled across rather than slid: a quarter wider mid-way,
                // settling back to its slot as it lands.
                .keyframeAnimator(
                    initialValue: CGFloat(1),
                    trigger: reduceMotion ? nil : selected
                ) { pill, stretch in
                    pill.scaleEffect(x: stretch, y: 1)
                } keyframes: { _ in
                    CubicKeyframe(1.25, duration: 0.14)
                    SpringKeyframe(1, duration: 0.28, spring: .init(duration: 0.3, bounce: 0.3))
                }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, inset)
        // Under Reduce Motion the pill still moves to its slot, with no spring
        // and no stretch; the tick stays.
        .animation(reduceMotion ? Motion.fade : Motion.spring, value: selected)
        .sensoryFeedback(.selection, trigger: taps)
        .accessibilityElement(children: .contain)
    }
}
