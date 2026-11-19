import ComposableArchitecture
import SwiftUI

/// The strip at the bottom of a thread: the @-suggestions, what is being
/// answered or rewritten, and the field.
///
/// Its own view, so a keystroke redraws this and not the thread above it.
struct ChatComposer: View {
    @Bindable var store: StoreOf<ChatFeature>
    var isFocused: FocusState<Bool>.Binding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Your own sends, counted — what the send button's bounce and tap key on.
    @State private var sends = 0

    var body: some View {
        let suggestions = store.mentionSuggestions
        return VStack(spacing: 6) {
            if !suggestions.isEmpty {
                mentionList(suggestions)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Says what the composer is about to do, and offers the way out.
            // Without it, an edit in progress is indistinguishable from a draft.
            if store.isEditing {
                banner(symbol: "pencil", cancel: { store.send(.editCancelled) }) {
                    Text(L10n.messagesEditingBanner)
                        .font(.caption.weight(.medium))
                }
            } else if let reply = store.replying {
                banner(symbol: "arrowshape.turn.up.left.fill", cancel: { store.send(.replyCleared) }) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L10n.chatReplyingTo(store.state.senderName(forID: reply.senderID)))
                            .font(.caption.weight(.semibold))
                        Text(ReplyQuoteView.plain(snippet: reply.snippet, kind: reply.kind))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(text: $store.draft, axis: .vertical) {
                    Text(L10n.messagesComposePlaceholder)
                }
                .focused(isFocused)
                .lineLimit(1...5)

                Button {
                    sends += 1
                    // Animated where it is made, so your bubble rises out of
                    // the composer rather than appearing in the thread.
                    store.send(.sendTapped, animation: Motion.spring)
                } label: {
                    Image(systemName: store.isEditing
                        ? "checkmark.circle.fill"
                        : "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        // Arrow and tick turn into each other, which is what
                        // says the same button now saves instead of sends.
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(
                            .bounce.up,
                            options: .nonRepeating,
                            value: reduceMotion ? 0 : sends
                        )
                }
                // The send gives its own tap; the press doesn't add a second.
                .buttonStyle(.pressableQuiet)
                .disabled(!store.canSend)
                // Grows in when there is something to send, rather than only
                // brightening — the button arriving is the cue that the line
                // can go. Quick and plain on the way back down.
                .scaleEffect(store.canSend || reduceMotion ? 1 : 0.6)
                .animation(store.canSend ? Motion.release : Motion.exit, value: store.canSend)
                .opacity(store.canSend ? 1 : 0.4)
                .animation(Motion.fade, value: store.canSend)
                .sensoryFeedback(.impact(weight: .light), trigger: sends)
                .accessibilityLabel(Text(store.isEditing
                    ? L10n.commonSave
                    : L10n.messagesComposePlaceholder))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .animation(Motion.spring, value: store.isEditing)
        .animation(Motion.spring, value: store.replying)
        .animation(Motion.spring, value: suggestions.map(\.id))
        // Editing starts from the panel, not from the composer, and so does a
        // reply, so the keyboard has to be sent for.
        .onChange(of: store.editing) { _, editing in
            if editing != nil { isFocused.wrappedValue = true }
        }
        .onChange(of: store.replying) { _, reply in
            if reply != nil { isFocused.wrappedValue = true }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.bottom, 8)
    }

    /// "Editing" or "Replying to": a line of glass with the way out.
    private func banner<Content: View>(
        symbol: String,
        cancel: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            content()
            Spacer(minLength: 0)

            // Named and full height, not a 12-point glyph. The icon alone was
            // both hard to find and hard to hit: `glassEffect` paints without
            // contributing a hit region, so the tap target was the drawn cross
            // and nothing around it.
            Button(action: cancel) {
                Label {
                    Text(L10n.commonCancel)
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(.capsule)
            }
            .buttonStyle(.pressable)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .foregroundStyle(.secondary)
        .padding(.leading, 14)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// The thread's other people, as a short list above the field.
    private func mentionList(_ people: [User]) -> some View {
        VStack(spacing: 0) {
            ForEach(people.prefix(4)) { person in
                Button { store.send(.mentionPicked(person.id)) } label: {
                    HStack(spacing: 10) {
                        // Inside the row's button: the tap picks the person.
                        Avatar(
                            initials: person.initials,
                            seed: person.id.rawValue,
                            size: 28,
                            viewable: false
                        )
                        Text(person.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(L10n.chatMentionAccessibility(person.displayName)))
                if person.id != people.prefix(4).last?.id { Divider().padding(.leading, 52) }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
    }
}

/// Where the composer would be, in a 1:1 with somebody this person blocked:
/// nothing can be sent either way, and the way back is one tap.
struct BlockedComposerBar: View {
    let name: String
    let unblock: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.secondary)
            Text(L10n.chatBlockedBanner(name))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(action: unblock) {
                Text(L10n.chatUnblock)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: Metrics.minTapTarget)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pressable)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.leading, 14)
        .padding(.horizontal, Metrics.screenPadding - 14)
        .padding(.bottom, 8)
    }
}
