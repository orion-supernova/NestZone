import SwiftUI

/// Swipe-to-delete for rows that do not live in a `List`.
///
/// `.swipeActions` is a `List` modifier. Applied to a row in a `LazyVStack` it
/// compiles, renders nothing and never fires — which is exactly what the
/// shopping list had. The app's rows are glass cards in a stack, so the gesture
/// has to be built: drag to reveal the button, tap it to confirm, or carry the
/// swipe past the halfway mark to commit it the way Mail and Reminders do.
///
/// `isRevealed` is a binding rather than local state so a list can keep one row
/// open at a time — opening a second closes the first, as the system does.
public struct SwipeToDelete<Content: View>: View {
    private let cornerRadius: CGFloat
    private let title: LocalizedStringResource
    private let onDelete: () -> Void
    @Binding private var isRevealed: Bool
    private let content: Content

    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    /// True once the drag has been claimed as horizontal. Without it every
    /// vertical scroll that starts on a row would drag the row sideways.
    @State private var isTracking = false
    @State private var didCommit = false

    /// Wide enough for the icon and its label, and for a 44pt tap target.
    private let actionWidth: CGFloat = 88

    /// The button is only on screen — and only touchable — once the row has
    /// actually moved.
    private var isOut: Bool { offset < -1 }

    public init(
        cornerRadius: CGFloat = Metrics.tightRadius,
        title: LocalizedStringResource = L10n.commonDelete,
        isRevealed: Binding<Bool>,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.title = title
        self._isRevealed = isRevealed
        self.onDelete = onDelete
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            deleteButton
            content
                // The card is glass, and `glassEffect` contributes no hit
                // region of its own: without this the drag starts only where a
                // glyph happens to be, which on these rows means the label and
                // nothing else.
                .contentShape(.rect)
                .offset(x: offset)
                // While the button is out, a tap anywhere on the row puts it
                // away instead of reaching the control underneath.
                .overlay {
                    if isRevealed {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { setRevealed(false) }
                    }
                }
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        // The row is a glass card, and `glassEffect` contributes no hit region:
        // without this the drag only starts where a glyph happens to be — on the
        // label, not on the padding that makes up most of the row.
        .contentShape(.rect)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .gesture(drag)
        .onChange(of: isRevealed) { _, revealed in
            guard !didCommit else { return }
            withAnimation(Motion.spring) { offset = revealed ? -actionWidth : 0 }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: didCommit) { _, committed in
            committed
        }
        // VoiceOver never sees the gesture, so the action is offered directly.
        .accessibilityAction(named: Text(title)) { commit() }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { commit() } label: {
            VStack(spacing: 3) {
                Image(systemName: "trash.fill").font(.body)
                Text(title).font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white)
            .frame(width: actionWidth)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(Palette.danger)
        // Hidden until the drag starts, or it shows through the row's own
        // rounded corners while the row is at rest.
        .opacity(isOut ? 1 : 0)
        // An `opacity(0)` view still answers taps, and this one is a
        // full-height destructive button sitting under the trailing end of the
        // row — the gaps in the row above it would delete the item outright.
        .allowsHitTesting(isOut)
        .accessibilityHidden(true)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !didCommit else { return }
                if !isTracking {
                    // Let the ScrollView have anything that is mostly vertical.
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        return
                    }
                    isTracking = true
                }
                let base = isRevealed ? -actionWidth : 0
                let proposed = base + value.translation.width
                // Nothing lives on the leading edge, so a pull that way is
                // resisted rather than followed.
                offset = proposed > 0 ? proposed / 6 : max(proposed, -width)
            }
            .onEnded { value in
                guard isTracking, !didCommit else { return }
                isTracking = false
                let base = isRevealed ? -actionWidth : 0
                let projected = base + value.predictedEndTranslation.width

                if projected < -width * 0.55 {
                    commit()
                } else {
                    setRevealed(projected < -actionWidth * 0.5)
                }
            }
    }

    private func setRevealed(_ revealed: Bool) {
        isRevealed = revealed
        withAnimation(Motion.spring) { offset = revealed ? -actionWidth : 0 }
    }

    private func commit() {
        guard !didCommit else { return }
        didCommit = true
        isRevealed = false
        // Carry the row off the edge; the delete is optimistic, so the list
        // removes it in the same frame and the two animations read as one.
        withAnimation(Motion.spring) { offset = -width }
        onDelete()
    }
}
