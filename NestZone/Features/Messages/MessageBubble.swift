import SwiftUI

/// Everything a bubble can ask for, as one value, so `ChatView` builds it once
/// per row instead of the bubble taking a dozen closures.
struct MessageHandlers {
    var retry: () -> Void
    var hold: () -> Void
    var dismiss: () -> Void
    var reply: () -> Void
    var copy: () -> Void
    var togglePin: () -> Void
    var report: () -> Void
    var edit: () -> Void
    var delete: () -> Void
    var react: (String) -> Void
    /// Asks the thread to scroll to a message, if it is loaded.
    var goTo: (MessageID) -> Void
}

struct MessageBubble: View {
    let message: Message
    let isMine: Bool
    let senderName: String
    let showsSender: Bool
    /// Drawn before the server has confirmed it, and dimmed to say so.
    let isPending: Bool
    let hasFailed: Bool
    /// The author's, already on the server: edit and delete.
    let canModify: Bool
    /// Already on the server and not the app's own line: has a menu.
    let canHold: Bool
    let isPinned: Bool
    let isBeingEdited: Bool
    let showsActions: Bool
    let me: UserID?
    /// What the server says, with the person's own choice laid over it.
    let reactions: [MessageReaction]
    /// Who a reply is quoting, by name; `nil` for a message that is not a reply.
    let quoteName: String?
    let mentionNames: [String]
    /// What the chat search is looking for, empty when it is closed.
    let highlight: String
    let handlers: MessageHandlers

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long a press has to be held. `.contextMenu` waits about half a
    /// second; a quarter reads as deliberate without feeling like a stall.
    private static let holdDuration = 0.25
    /// How far the bubble has to be dragged for letting go to mean "reply".
    private static let swipeThreshold: CGFloat = 56
    private static let quoteWell = Color.black.opacity(0.14)

    /// Tracks the finger, so the bubble reacts on touch-down instead of after
    /// the hold completes — the wait was invisible, which is what made the
    /// gesture feel like it had not registered.
    @GestureState private var isPressing = false
    /// How far the bubble is being pulled towards the trailing edge.
    @GestureState private var swipe: CGFloat = 0

    /// A hold opens the panel, a tap dismisses whatever is open — as one
    /// exclusive gesture, so the two can never both fire for the same touch.
    /// Split across views they did: the finger lifting off a completed hold is
    /// still a tap, so the panel closed in the same breath it opened, and the
    /// gesture only appeared to work when a stray millimetre of drift happened
    /// to cancel the tap.
    private var pressGesture: some Gesture {
        LongPressGesture(minimumDuration: Self.holdDuration)
            .updating($isPressing) { current, state, _ in state = canHold && current }
            .onEnded { _ in if canHold { handlers.hold() } }
            .exclusively(before: TapGesture().onEnded { handlers.dismiss() })
    }

    /// Swipe right to reply. Only a drag that is mostly sideways counts, so
    /// scrolling the thread never pulls a bubble.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .updating($swipe) { value, state, _ in
                guard canHold, Self.isSideways(value.translation) else { state = 0; return }
                state = min(max(value.translation.width, 0), Self.swipeThreshold * 1.4)
            }
            .onEnded { value in
                guard canHold, Self.isSideways(value.translation),
                      value.translation.width >= Self.swipeThreshold else { return }
                handlers.reply()
            }
    }

    private static func isSideways(_ translation: CGSize) -> Bool {
        translation.width > 0 && translation.width > abs(translation.height) * 1.6
    }

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            group

            // Their own row, outside the bubble's single accessibility element:
            // each chip is a control and has to stay reachable.
            if !reactions.isEmpty {
                ReactionChips(reactions: reactions, me: me, toggle: handlers.react)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .animation(Motion.fade, value: isPending)
        .animation(Motion.spring, value: reactions)
        .transition(arrival)
    }

    /// Sender, bubble and the retry note: what VoiceOver reads as one message.
    private var group: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if showsSender {
                Text(senderName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    if isMine {
                        // The sender's own bubble is solid so the thread is
                        // readable at a glance; everyone else's is glass.
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.accent)
                    }
                }
                .glassEffect(
                    isMine ? .identity : .regular,
                    in: .rect(cornerRadius: 18, style: .continuous)
                )
                .opacity(isPending && !hasFailed ? 0.55 : 1)
                .scaleEffect(isPressing || showsActions ? 0.96 : 1)
                .animation(Motion.press, value: isPressing)
                .animation(Motion.spring, value: showsActions)
                // Hands the bubble's frame up to `ChatView`, which draws the
                // panel outside the scroll view. Drawn here it was inside the
                // scroll view's clip, so the panel on the topmost bubble was
                // sliced off.
                .anchorPreference(key: BubbleActionsAnchorKey.self, value: .bounds) {
                    showsActions
                        ? BubbleActionsAnchor(id: message.id, bounds: $0, isMine: isMine)
                        : nil
                }
                .contentShape(.rect(cornerRadius: 18, style: .continuous))
                .gesture(pressGesture)
                .simultaneousGesture(swipeGesture)
                // Two taps of feedback: one the instant the press registers,
                // one when the panel actually opens.
                .sensoryFeedback(.impact(weight: .light), trigger: isPressing) { _, now in now }
                .sensoryFeedback(.impact(weight: .medium), trigger: showsActions) { _, now in now }
                // Once, as the pull crosses the line past which letting go
                // replies — the felt "it will take".
                .sensoryFeedback(.impact(weight: .light), trigger: swipe >= Self.swipeThreshold) { _, now in now }
                .offset(x: reduceMotion ? 0 : swipe)
                // Last, so everything above it measures and is touched as the
                // bubble rather than as the full-width row this frame opens up
                // to. Inside it, a hold on the empty half of a line opened the
                // neighbouring bubble's panel, and the panel was pinned to the
                // row.
                .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)
                .background(alignment: .leading) { replyGlyph }

            // A send that failed keeps its bubble and says so, rather than
            // taking the text down with it.
            if hasFailed {
                Button(action: handlers.retry) {
                    Label {
                        Text(L10n.messagesChatMessageFailed)
                    } icon: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Palette.danger)
                    .padding(.horizontal, 12)
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
            }
        }
        // Marks which bubble the composer is currently rewriting.
        .overlay(alignment: isMine ? .topLeading : .topTrailing) {
            if isBeingEdited {
                Image(systemName: "pencil.circle.fill")
                    .font(.caption)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityValue(hasFailed ? Text(L10n.messagesChatMessageFailed) : Text(""))
        .accessibilityAction(named: Text(L10n.commonRetry)) { if hasFailed { handlers.retry() } }
        // A press-and-hold and a swipe are not reachable under VoiceOver; the
        // same things are offered by name instead.
        .accessibilityActions {
            if canHold {
                Button { handlers.reply() } label: { Text(L10n.messagesReply) }
                Button { handlers.copy() } label: { Text(L10n.messagesCopy) }
                Button { handlers.togglePin() } label: {
                    Text(isPinned ? L10n.messagesUnpin : L10n.messagesPin)
                }
                ForEach(ReactionEmoji.all, id: \.self) { emoji in
                    Button { handlers.react(emoji) } label: {
                        Text(L10n.reactionPickerAdd(emoji))
                    }
                }
                if canModify {
                    Button { handlers.edit() } label: { Text(L10n.commonEdit) }
                    Button { handlers.delete() } label: { Text(L10n.commonDelete) }
                } else {
                    Button { handlers.report() } label: { Text(L10n.messagesReport) }
                }
            }
        }
    }

    /// The quote, if this is a reply, and the words.
    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reply = message.replyTo, let quoteName {
                ReplyQuoteView(
                    name: quoteName,
                    snippet: reply.snippet,
                    kind: reply.kind,
                    isMine: isMine
                ) { handlers.goTo(reply.messageID) }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isMine ? AnyShapeStyle(Self.quoteWell) : AnyShapeStyle(.quaternary))
                    }
            }
            MessageText(
                content: message.content,
                mentionNames: mentionNames,
                highlight: highlight,
                isMine: isMine
            )
            .font(.subheadline)
            .foregroundStyle(isMine ? Color.white : Color.primary)
        }
    }

    /// What the pull reveals behind the bubble. Fades in with the pull; under
    /// Reduce Motion the bubble does not travel and the glyph does not appear —
    /// the haptic and the reply bar are the feedback.
    @ViewBuilder
    private var replyGlyph: some View {
        if swipe > 0, !reduceMotion {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(min(swipe / Self.swipeThreshold, 1))
                .scaleEffect(swipe >= Self.swipeThreshold ? 1.15 : 0.85)
                .padding(.leading, 4)
        }
    }

    private var accessibilityText: String {
        var text = "\(senderName): \(message.content)"
        if let reply = message.replyTo, let quoteName {
            text = String(localized: L10n.replyQuoteAccessibility(
                quoteName, ReplyQuoteView.plain(snippet: reply.snippet, kind: reply.kind)
            )) + " " + text
        }
        return text
    }

    /// Theirs slide in from their side of the thread. Yours rise out of the
    /// composer, the place they were just typed, growing from its corner —
    /// and leave the way theirs do. A fade under Reduce Motion.
    private var arrival: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let sideways = AnyTransition.move(edge: isMine ? .trailing : .leading)
            .combined(with: .opacity)
        guard isMine else { return sideways }
        return .asymmetric(
            insertion: AnyTransition.offset(y: 40)
                .combined(with: .scale(scale: 0.9, anchor: .bottomTrailing))
                .combined(with: .opacity),
            removal: sideways
        )
    }
}

/// Which bubble is open, where it is, and which way it faces.
struct BubbleActionsAnchor {
    let id: MessageID
    let bounds: Anchor<CGRect>
    let isMine: Bool
}

struct BubbleActionsAnchorKey: PreferenceKey {
    static let defaultValue: BubbleActionsAnchor? = nil

    static func reduce(value: inout BubbleActionsAnchor?, nextValue: () -> BubbleActionsAnchor?) {
        value = value ?? nextValue()
    }
}
