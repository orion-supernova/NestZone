import SwiftUI

/// Everything a bubble can ask for, as one value, so `ChatView` builds it once
/// per row instead of the bubble taking a dozen closures. Not compared: the
/// closures only ever name the message by id and go through the store, so one
/// built for an earlier render does the same thing.
struct MessageHandlers {
    var retry: () -> Void
    var dismiss: () -> Void
    var reply: () -> Void
    var copy: () -> Void
    var togglePin: () -> Void
    var report: () -> Void
    var blockSender: () -> Void
    var edit: () -> Void
    var delete: () -> Void
    var react: (String) -> Void
    /// Asks the thread to scroll to a message, if it is loaded.
    var goTo: (MessageID) -> Void
}

/// One message. Equatable over what it draws (never the handlers), so opening
/// a menu or a reaction arriving redraws the one bubble it concerns and not
/// every bubble on screen.
struct MessageBubble: View, Equatable {
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
    /// Replying makes sense: not in a thread closed by a block.
    let canReply: Bool
    let isPinned: Bool
    let isBeingEdited: Bool
    let me: UserID?
    /// What the server says, with the person's own choice laid over it.
    let reactions: [MessageReaction]
    /// Who a reply is quoting, by name; `nil` for a message that is not a reply.
    let quoteName: String?
    let mentionNames: [String]
    /// What the chat search is looking for, empty when it is closed.
    let highlight: String
    let handlers: MessageHandlers

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message && lhs.isMine == rhs.isMine
            && lhs.senderName == rhs.senderName && lhs.showsSender == rhs.showsSender
            && lhs.isPending == rhs.isPending && lhs.hasFailed == rhs.hasFailed
            && lhs.canModify == rhs.canModify && lhs.canHold == rhs.canHold
            && lhs.canReply == rhs.canReply && lhs.isPinned == rhs.isPinned
            && lhs.isBeingEdited == rhs.isBeingEdited && lhs.me == rhs.me
            && lhs.reactions == rhs.reactions && lhs.quoteName == rhs.quoteName
            && lhs.mentionNames == rhs.mentionNames && lhs.highlight == rhs.highlight
    }

    @Environment(\.theme) private var theme
    @Environment(\.chatMenuRegistry) private var menuRegistry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the bubble has to be dragged for letting go to mean "reply".
    private static let swipeThreshold: CGFloat = 56
    private static let quoteWell = Color.black.opacity(0.14)

    /// How far the bubble is being pulled, in the direction that has room: your
    /// own towards the leading edge, everybody else's towards the trailing one.
    @GestureState private var swipe: CGFloat = 0

    /// Swipe to reply. Only a drag that is mostly sideways, in the right
    /// direction, counts, so scrolling the thread never pulls a bubble; a
    /// slightly diagonal one still does.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($swipe) { value, state, _ in
                guard canHold, canReply, let pull = Self.pull(value.translation, mine: isMine) else {
                    state = 0
                    return
                }
                state = min(pull, Self.swipeThreshold * 1.4)
            }
            .onEnded { value in
                guard canHold, canReply,
                      let pull = Self.pull(value.translation, mine: isMine),
                      pull >= Self.swipeThreshold else { return }
                handlers.reply()
            }
    }

    /// How far a drag has gone the way this bubble can be pulled, or `nil` when
    /// it is going another way or mostly up and down.
    private static func pull(_ translation: CGSize, mine: Bool) -> CGFloat? {
        let along = mine ? -translation.width : translation.width
        guard along > 0, along > abs(translation.height) else { return nil }
        return along
    }

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            group

            // Their own row, outside the bubble's single accessibility element:
            // each chip is a control and has to stay reachable.
            if !reactions.isEmpty {
                ReactionChips(reactions: reactions, me: me, alignment: isMine ? .trailing : .leading, toggle: handlers.react)
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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }

            bubble

            // A send that failed keeps its bubble and says so, rather than
            // taking the text down with it.
            if hasFailed {
                Button(action: handlers.retry) {
                    Label {
                        Text(L10n.messagesChatMessageFailed)
                    } icon: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.dangerText)
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
                    .foregroundStyle(.secondaryText)
                    .padding(4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAction(named: Text(L10n.commonRetry)) { if hasFailed { handlers.retry() } }
        // The menu and the swipe are not reachable under VoiceOver; the same
        // things are offered by name instead.
        .accessibilityActions {
            if canHold {
                if canReply {
                    Button { handlers.reply() } label: { Text(L10n.messagesReply) }
                }
                if let reply = message.replyTo {
                    Button { handlers.goTo(reply.messageID) } label: {
                        Text(L10n.chatGoToQuoted)
                    }
                }
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
                    Button { handlers.blockSender() } label: {
                        Text(L10n.messagesBlockSender(senderName))
                    }
                }
            }
        }
    }

    /// The bubble: surface, swipe and — for a sent message — the system menu.
    @ViewBuilder
    private var bubble: some View {
        let tappable = surface
            .opacity(isPending && !hasFailed ? 0.55 : 1)
            // A plain tap puts the keyboard away.
            .contentShape(.rect(cornerRadius: 18, style: .continuous))
            .onTapGesture { handlers.dismiss() }

        if canHold {
            // The system lays the menu out and gives the lift and the haptic;
            // The thread's one UIKit interaction (`MessageMenuInteraction`) asks
            // the registry what is under the finger; the bubble reports where
            // it is and what its menu holds.
            positioned(
                tappable
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                        menuRegistry?.setFrame(message.id, $0)
                    }
                    .onChange(of: self, initial: true) { _, bubble in
                        menuRegistry?.setMenu(message.id, model: bubble.menuModel, preview: bubble.previewImage)
                    }
                    .onDisappear { menuRegistry?.remove(message.id) }
            )
        } else {
            positioned(tappable)
        }
    }

    /// The swipe, the glyph it reveals and the bubble's width cap.
    private func positioned(_ view: some View) -> some View {
        view
            .simultaneousGesture(swipeGesture)
            // Once, as the pull crosses the line past which letting go
            // replies — the felt "it will take".
            .sensoryFeedback(.impact(weight: .light), trigger: swipe >= Self.swipeThreshold) { _, now in now }
            .offset(x: reduceMotion ? 0 : (isMine ? -swipe : swipe))
            // The glyph waits at the bubble's own edge, where the pull reveals it.
            .background(alignment: isMine ? .trailing : .leading) { replyGlyph }
            // Last, so everything above it measures and is touched as the
            // bubble rather than as the full-width row this frame opens up to.
            .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)
    }

    private var surface: some View {
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
    }

    /// What the menu is built from, read when it opens.
    private var menuModel: MessageMenuModel {
        MessageMenuModel(
            myEmoji: Set(reactions.filter { $0.userID == me }.map(\.emoji)),
            canReply: canReply,
            canCopy: message.kind != .image,
            isPinned: isPinned,
            canModify: canModify,
            senderName: senderName,
            handlers: handlers
        )
    }

    /// The bubble as a still picture for the lifted preview: a context-menu
    /// preview is a snapshot, and glass does not draw into one, so the
    /// others' bubbles stand in as a flat fill.
    private func previewImage(size: CGSize, scale: CGFloat, scheme: ColorScheme) -> UIImage? {
        let flat = content
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(width: size.width, height: size.height, alignment: .leading)
            .background(isMine ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Palette.bubblePreview))
            .environment(\.theme, theme)
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: flat)
        renderer.scale = scale
        return renderer.uiImage
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
            .foregroundStyle(isMine ? theme.onAccent : Color.primary)
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
                .foregroundStyle(.secondaryText)
                .opacity(min(swipe / Self.swipeThreshold, 1))
                .scaleEffect(swipe >= Self.swipeThreshold ? 1.15 : 0.85)
                .padding(.horizontal, 6)
        }
    }

    private var accessibilityText: String {
        var text = "\(senderName): \(message.content)"
        if let reply = message.replyTo, let quoteName {
            text = String(localized: L10n.replyQuoteAccessibility(
                quoteName, ReplyQuoteView.plain(snippet: reply.snippet, kind: reply.kind)
            )) + " " + text
        }
        if hasFailed { text += ", " + String(localized: L10n.messagesChatMessageFailed) }
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


/// Emoji drawn as images for the reaction palette, cached: the menu asks for
/// them every time it opens.
@MainActor
enum EmojiGlyph {
    private static var cache: [String: UIImage] = [:]

    static func image(_ emoji: String, chosen: Bool) -> UIImage {
        let key = chosen ? emoji + "#" : emoji
        if let hit = cache[key] { return hit }
        let side: CGFloat = 34
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            if chosen {
                UIColor(Palette.violet).withAlphaComponent(0.45).setFill()
                UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side)).fill()
            }
            let font = UIFont.systemFont(ofSize: 24)
            let text = emoji as NSString
            let size = text.size(withAttributes: [.font: font])
            text.draw(at: CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2), withAttributes: [.font: font])
        }.withRenderingMode(.alwaysOriginal)
        cache[key] = image
        return image
    }
}
