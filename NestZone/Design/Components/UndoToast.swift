import SwiftUI

/// A short-lived bar offering to put back what was just removed.
///
/// The app has no trash and no restore endpoint on purpose: a destructive
/// action here is held for a few seconds on the device and only then sent, so
/// undo cancels the write rather than reversing it. That keeps recovery at the
/// one moment a person is actually looking at the row they lost.
///
/// A ring around the glyph empties over that hold, so how long is left can be
/// seen rather than guessed — when it closes, so does the offer.
public struct UndoToast: View {
    private let message: LocalizedStringResource
    private let symbol: String
    private let window: Duration
    private let action: () -> Void

    /// Bumped when the bar is reused for a different removal — a second swipe
    /// inside the first one's window starts a fresh hold, so the ring has to
    /// start again too.
    @State private var hold = 0

    /// - Parameter symbol: what just happened. The bar is offered for more than
    ///   one verb now — a chore can be thrown away or put away, and those are
    ///   different enough that the icon should not claim both were a delete.
    /// - Parameter window: how long the removal is held before it is sent. Every
    ///   screen that offers undo holds for five seconds; one that ever holds for
    ///   a different time says so here, or the ring and the offer disagree.
    public init(
        _ message: LocalizedStringResource,
        symbol: String = "trash",
        window: Duration = .seconds(5),
        action: @escaping () -> Void
    ) {
        self.message = message
        self.symbol = symbol
        self.window = window
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background {
                    Countdown(window: window)
                        .id(hold)
                }

            Text(message)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Button(action: action) {
                Text(L10n.commonUndo)
                    .font(.subheadline.weight(.semibold))
                    // The bar is narrow, so the label needs the room around it
                    // to reach a comfortable target.
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pressable)
        }
        // The ring sits concentric with the capsule's rounded end: at the
        // default text size the bar is 44pt tall, so its end is a 22pt radius
        // about a centre 22pt in, and a 26pt ring is centred there from 9pt in.
        .padding(.leading, 9)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onChange(of: message) { hold += 1 }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(L10n.commonUndo), action)
    }
}

extension UndoToast {
    /// The undo window, running out. Linear, because time is, and once per
    /// hold: it empties and stays empty. Under Reduce Motion the ring stays
    /// whole and fades over the same seconds instead of sweeping round.
    private struct Countdown: View {
        let window: Duration

        @State private var remaining: Double = 1
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: reduceMotion ? 1 : remaining)
                    .stroke(.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(reduceMotion ? remaining : 1)
            }
            .accessibilityHidden(true)
            .onAppear {
                let (seconds, attoseconds) = window.components
                let duration = Double(seconds) + Double(attoseconds) / 1e18
                withAnimation(.linear(duration: duration)) { remaining = 0 }
            }
        }
    }
}
