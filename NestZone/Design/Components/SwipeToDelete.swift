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
///
/// **The live drag is `@GestureState`, never `@State`.** A drag inside a
/// `ScrollView` is routinely *cancelled* rather than ended: the scroll view
/// claims the touch the moment the finger turns vertical, and when it does
/// `onEnded` never runs. An offset written from `onChanged` into `@State` is
/// then stranded wherever the finger left it — the row sits half open, while
/// `isRevealed` still reads `false`, so the next drag measures from a base that
/// does not match what is on screen and the row can never be pushed back. That
/// was the stuck row. `@GestureState` is the one piece of state SwiftUI resets
/// on a cancel as well as on an end, which is the guarantee this needs, and the
/// row's position is *derived* from it rather than stored, so there is no
/// second copy of the truth to fall out of step with.
public struct SwipeToDelete<Content: View>: View {
    private let cornerRadius: CGFloat
    private let title: LocalizedStringResource
    private let onDelete: () -> Void
    @Binding private var isRevealed: Bool
    private let content: Content

    /// The translation of the drag in flight. SwiftUI clears it when the
    /// gesture ends *or is cancelled*.
    @GestureState private var translation: CGFloat = 0
    @State private var width: CGFloat = 0

    /// Wide enough for the icon and its label, and for a 44pt tap target.
    private let actionWidth: CGFloat = 88

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

    /// Where the row sits: its settled position plus whatever the finger is
    /// adding right now. Computed, so it cannot disagree with `isRevealed`.
    private var offset: CGFloat {
        let proposed = (isRevealed ? -actionWidth : 0) + translation
        // Nothing lives on the leading edge, so a pull that way is resisted
        // rather than followed.
        return proposed > 0 ? proposed / 6 : max(proposed, -width)
    }

    /// How much of the action is showing. The panel is exactly this wide, which
    /// is what makes it grow out of the edge under the finger.
    private var revealed: CGFloat { max(0, -offset) }

    /// Past this the release deletes outright, and the panel has taken over
    /// enough of the row to say so.
    private var isFullSwipe: Bool { width > 0 && revealed > width * 0.55 }

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
        // No animation while the finger is down, or the row lags behind it
        // instead of tracking it. The spring is for the settle — which is also
        // what runs when the gesture is cancelled, so a row the scroll view
        // stole the touch from glides home instead of freezing mid-swipe.
        .animation(translation == 0 ? Motion.spring : nil, value: offset)
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        // The row is a glass card, and `glassEffect` contributes no hit region:
        // without this the drag only starts where a glyph happens to be — on the
        // label, not on the padding that makes up most of the row.
        .contentShape(.rect)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // Simultaneous, not exclusive: `.gesture` wins the touch outright and
        // the enclosing ScrollView never sees the pan, so a list of these rows
        // cannot be scrolled by starting on one. Sharing it lets the scroll
        // view take the vertical drags this gesture deliberately ignores.
        .simultaneousGesture(drag)
        .sensoryFeedback(.impact(weight: .medium), trigger: isFullSwipe) { _, full in full }
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
            // The label holds its own width against the trailing edge, so it
            // stays put while the panel grows behind it rather than sliding
            // around inside it.
            .frame(width: actionWidth)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // As wide as the row has actually been pulled — the way a system swipe
        // action behaves. It used to be a fixed 88pt panel parked under the row
        // and faded in with `opacity`, which is what made the gesture read as
        // something other than a swipe action: the button did not come *out of*
        // the edge, it appeared behind a hole.
        .frame(width: revealed, alignment: .trailing)
        .background(Palette.danger)
        .clipped()
        // A zero-width panel still answers taps at its edge, and this one is
        // destructive.
        .allowsHitTesting(revealed > 1)
        .accessibilityHidden(true)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($translation) { value, state, _ in
                // Follow the finger only once it is clearly sideways: a small
                // horizontal wobble at the start of a scroll must not pull the
                // row open. Below the threshold neither direction has won, so
                // the row stays where it is and the scroll view gets the touch.
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else {
                    return
                }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else {
                    return
                }
                let projected = (isRevealed ? -actionWidth : 0) + value.predictedEndTranslation.width
                if projected < -width * 0.55 {
                    commit()
                } else {
                    setRevealed(projected < -actionWidth * 0.5)
                }
            }
    }

    private func setRevealed(_ revealed: Bool) {
        isRevealed = revealed
    }

    /// Runs the action and returns the row to rest.
    ///
    /// It deliberately does *not* carry the row off the edge and hold it there.
    /// That flourish assumed `onDelete` deletes, which is only true where the
    /// write is optimistic — the shopping list removes the item in the same
    /// frame, so the row was gone before the animation mattered. Recipes asks
    /// first: `deleteTapped` raises a confirmation alert and removes nothing. A
    /// row parked off the edge behind a latched flag therefore never came back,
    /// and cancelling the alert left the recipe in the list with no row to show
    /// for it. Springing home costs nothing in the optimistic case (the item
    /// leaves the list anyway, and the list's own transition covers it) and is
    /// the only correct thing in the confirmed one — which is also what the
    /// system does when a swipe action puts up a confirmation.
    private func commit() {
        isRevealed = false
        onDelete()
    }
}
