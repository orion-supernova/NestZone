import ComposableArchitecture
import SwiftUI

public struct MessagesView: View {
    @Bindable var store: StoreOf<MessagesFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<MessagesFeature>) {
        self.store = store
    }

    /// The conversation list. The stack it pushes chats onto is built by the
    /// tab — see `MessagesStack` — so the tab can put the same avatar and bell
    /// on this screen as on every other.
    public var body: some View {
        list
            .background(Backdrop(tint: theme.accent))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle(Text(L10n.messagesScreenTitle))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { store.send(.composeTapped) } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(Text(L10n.messagesNewMessageButton))
                }
            }
            .task { await store.send(.task).finish() }
            .sheet(item: $store.scope(
                state: \.destination?.compose, action: \.destination.compose
            )) { NewConversationSheet(store: $0) }
            .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var list: some View {
        if store.isLoading {
            SkeletonList(rows: 5, height: 68)
                .padding(.horizontal, Metrics.screenPadding)
                .frame(maxHeight: .infinity, alignment: .top)
        } else if store.conversations.isEmpty {
            EmptyStateView(
                title: L10n.messagesEmptyStateTitle,
                message: L10n.messagesEmptyStateSubtitle,
                symbol: "bubble.left.and.bubble.right",
                action: .init(title: L10n.messagesCreateGroupChatButton) {
                    store.send(.composeTapped)
                }
            )
        } else {
            ScrollView {
                GlassList {
                    ForEach(Array(store.sorted.enumerated()), id: \.element.id) { index, conversation in
                        ConversationRow(
                            title: store.state.title(for: conversation),
                            preview: conversation.lastMessage,
                            timestamp: conversation.lastMessageAt,
                            members: store.state.avatarMembers(for: conversation)
                        ) { store.send(.conversationTapped(conversation)) }
                            // Only the first screenful staggers; a row further
                            // down waiting out its capped delay read as the list
                            // lagging behind the finger.
                            .appearInPlace(index < 8 ? index : 0)
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, Metrics.scrollBottomInset)
            }
        }
    }
}

private struct ConversationRow: View {
    let title: String
    let preview: String?
    let timestamp: Timestamp?
    let members: [AvatarStack.Member]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AvatarStack(members: members, size: 40, maxVisible: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(preview ?? String(localized: L10n.messagesNoMessagesYet))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let timestamp {
                    RelativeTimeText(timestamp)
                        .font(.caption2)
                        .foregroundStyle(Palette.accessory)
                }
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
    }
}

struct ChatView: View {
    @Bindable var store: StoreOf<ChatFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isComposerFocused: Bool
    /// Measured, so the bar can be aligned to a bubble edge and kept on screen.
    @State private var barSize: CGSize = .zero
    /// Off until the thread's first delivery has been drawn, so opening a chat
    /// does not slide its whole history in one bubble at a time.
    @State private var isSettled = false
    /// Your own sends, counted — what the send button's bounce and tap key on.
    @State private var sends = 0

    var body: some View {
        // Sorted once per render. `startsGroup` used to reach for `ordered`
        // itself, which re-sorted the whole thread for every bubble on screen.
        let thread = store.state.ordered
        // The newest bubble, when it is somebody else's. Arrivals animate on
        // this rather than on the count: a send is animated where it is made,
        // and your bubble's echo replacing its stand-in has to stay a silent
        // swap — animated, the stand-in would slide away as its twin rose in.
        let arrival = thread.last.flatMap { store.state.isMine($0) ? nil : $0.id }

        ScrollViewReader { proxy in
            ScrollView {
                // Bubbles are the one place in the app with many glass shapes
                // on screen at once. The container renders them in a single
                // pass instead of one each; `spacing: 0` keeps them from
                // merging into each other, which would blur the thread into
                // blobs.
                GlassEffectContainer(spacing: 0) {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(thread.enumerated()), id: \.element.id) { index, message in
                            MessageBubble(
                                message: message,
                                isMine: store.state.isMine(message),
                                senderName: store.state.senderName(for: message),
                                showsSender: store.state.startsGroup(at: index, in: thread)
                                    && !store.state.isMine(message),
                                isPending: store.state.isPending(message),
                                hasFailed: store.state.hasFailed(message),
                                canModify: store.state.canModify(message),
                                isBeingEdited: store.editing == message.id,
                                showsActions: store.actionsFor == message.id,
                                retry: { store.send(.retryTapped(message.id)) },
                                hold: { store.send(.bubbleHeld(message.id)) },
                                dismiss: dismissEverything,
                                edit: { store.send(.editTapped(message.id)) },
                                delete: { store.send(.deleteTapped(message.id)) }
                            )
                            .id(message.id)
                            // The open bar overhangs its bubble, and a lazy
                            // stack draws later rows over earlier ones.
                            .zIndex(store.actionsFor == message.id ? 1 : 0)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.vertical, Metrics.stackSpacing)
                    // Bubbles had a transition and nothing that ran it: every
                    // push landed outside an animation, so new messages just
                    // appeared.
                    .animation(isSettled ? Motion.spring : nil, value: arrival)
                    // Catches the taps that land beside a bubble rather than on
                    // one. Behind the thread, not around it: a gesture on the
                    // scroll view is simultaneous with the bubbles' own, so the
                    // finger coming up off a hold counted as a tap too and shut
                    // the bar in the same breath that opened it.
                    .background {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { dismissEverything() }
                    }
                }
            }
            // Opens on the newest message. `defaultScrollAnchor` is resolved
            // during layout, unlike a `scrollTo` fired from `onAppear`: that ran
            // before the thread had been measured, which is what left a band of
            // empty space above the first bubble on returning to the tab, and
            // why the smallest scroll made it snap back.
            .defaultScrollAnchor(.bottom)
            .onChange(of: store.state.ordered.last?.id) { _, _ in
                scrollToNewest(proxy, animated: true)
            }
            .onChange(of: store.isLoading, initial: true) { _, loading in
                if !loading { isSettled = true }
            }
        }
        // Drawn over the scroll view, not inside it: an overlay on the bubble
        // is clipped by the scroll view's bounds, which sliced the bar in half
        // whenever the message was near the top of the screen.
        .overlayPreferenceValue(BubbleActionsAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    let bubble = proxy[anchor.bounds]
                    MessageActionsBar(
                        edit: { store.send(.editTapped(anchor.id)) },
                        delete: { store.send(.deleteTapped(anchor.id)) }
                    )
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { barSize = $0 }
                    .position(
                        x: barX(alongside: bubble, isMine: anchor.isMine, within: proxy.size),
                        y: barY(above: bubble, within: proxy.size, insets: proxy.safeAreaInsets)
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(Motion.spring, value: store.actionsFor)
        }
        .background(Backdrop(tint: theme.accent))
        // Swipe the keyboard down; a tap anywhere in the thread does the same,
        // through `dismissEverything`.
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.renameTapped) } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(Text(L10n.messagesRenameTitle))
            }
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        // A plain `.alert` rather than `AlertState`, which has nowhere to put a
        // text field.
        .alert(
            Text(L10n.messagesRenameTitle),
            isPresented: $store.isRenaming,
            actions: {
                TextField(text: $store.renameDraft) {
                    Text(L10n.messagesRenamePlaceholder)
                }
                Button { store.send(.renameSubmitted) } label: { Text(L10n.commonSave) }
                Button(role: .cancel) {} label: { Text(L10n.commonCancel) }
            },
            message: { Text(L10n.messagesRenameMessage) }
        )
    }

    /// What a plain tap in the thread means: put the keyboard away, close the
    /// action bar, and abandon an edit in progress.
    private func dismissEverything() {
        isComposerFocused = false
        store.send(.backgroundTapped)
    }

    /// Lines the bar up with the bubble's own edge — trailing for yours,
    /// leading for theirs — then keeps it on screen.
    private func barX(alongside bubble: CGRect, isMine: Bool, within size: CGSize) -> CGFloat {
        let half = barSize.width / 2
        let anchored = isMine ? bubble.maxX - half : bubble.minX + half
        let margin = Metrics.screenPadding + half
        return min(max(anchored, margin), max(margin, size.width - margin))
    }

    /// Above the bubble, unless it is close enough to the top that the bar would
    /// slide under the navigation bar, in which case below it.
    ///
    /// The scroll view runs edge to edge, so its own top is behind the title —
    /// clamping to zero left the bar readable only through the toolbar's blur.
    private func barY(above bubble: CGRect, within size: CGSize, insets: EdgeInsets) -> CGFloat {
        let half = barSize.height / 2
        let gap: CGFloat = 8
        let preferred = bubble.minY - half - gap
        guard preferred - half < insets.top else { return preferred }
        return min(bubble.maxY + half + gap, size.height - insets.bottom - half - gap)
    }

    private func scrollToNewest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let last = store.state.ordered.last else { return }
        withAnimation(Motion.spring) { proxy.scrollTo(last.id, anchor: .bottom) }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            // Says what the composer is about to do, and offers the way out.
            // Without it, an edit in progress is indistinguishable from a draft.
            if store.isEditing {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                    Text(L10n.messagesEditingBanner)
                        .font(.caption.weight(.medium))
                    Spacer(minLength: 0)

                    // Named and full height, not a 12-point glyph. The icon
                    // alone was both hard to find and hard to hit: `glassEffect`
                    // paints without contributing a hit region, so the tap
                    // target was the drawn cross and nothing around it.
                    Button { store.send(.editCancelled) } label: {
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

            HStack(spacing: 10) {
                TextField(text: $store.draft, axis: .vertical) {
                    Text(L10n.messagesComposePlaceholder)
                }
                .focused($isComposerFocused)
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
        // Editing starts from a context menu, not from the composer, so the
        // keyboard has to be sent for.
        .onChange(of: store.editing) { _, editing in
            if editing != nil { isComposerFocused = true }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.bottom, 8)
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool
    let senderName: String
    let showsSender: Bool
    /// Drawn before the server has confirmed it, and dimmed to say so.
    let isPending: Bool
    let hasFailed: Bool
    /// Your own words, already on the server — the only thing worth a menu.
    let canModify: Bool
    let isBeingEdited: Bool
    let showsActions: Bool
    let retry: () -> Void
    let hold: () -> Void
    let dismiss: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long a press has to be held. `.contextMenu` waits about half a
    /// second; a quarter reads as deliberate without feeling like a stall.
    private static let holdDuration = 0.25

    /// Tracks the finger, so the bubble reacts on touch-down instead of after
    /// the hold completes — the wait was invisible, which is what made the
    /// gesture feel like it had not registered.
    @GestureState private var isPressing = false

    /// A hold opens the bar, a tap dismisses whatever is open — as one
    /// exclusive gesture, so the two can never both fire for the same touch.
    /// Split across views they did: the finger lifting off a completed hold is
    /// still a tap, so the bar closed in the same breath it opened, and the
    /// gesture only appeared to work when a stray millimetre of drift happened
    /// to cancel the tap.
    private var pressGesture: some Gesture {
        LongPressGesture(minimumDuration: Self.holdDuration)
            .updating($isPressing) { current, state, _ in state = canModify && current }
            .onEnded { _ in if canModify { hold() } }
            .exclusively(before: TapGesture().onEnded { dismiss() })
    }

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if showsSender {
                Text(senderName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }

            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(isMine ? .white : .primary)
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
                // Hands the bubble's frame up to `ChatView`, which draws the bar
                // outside the scroll view. Drawn here it was inside the scroll
                // view's clip, so the bar on the topmost bubble was sliced off.
                .anchorPreference(key: BubbleActionsAnchorKey.self, value: .bounds) {
                    showsActions
                        ? BubbleActionsAnchor(id: message.id, bounds: $0, isMine: isMine)
                        : nil
                }
                .contentShape(.rect(cornerRadius: 18, style: .continuous))
                .gesture(pressGesture)
                // Two taps of feedback: one the instant the press registers,
                // one when the bar actually opens.
                .sensoryFeedback(.impact(weight: .light), trigger: isPressing) { _, now in now }
                .sensoryFeedback(.impact(weight: .medium), trigger: showsActions) { _, now in now }
                // Last, so everything above it measures and is touched as the
                // bubble rather than as the full-width row this frame opens up
                // to. Inside it, a hold on the empty half of a line opened the
                // neighbouring bubble's bar, and the bar was pinned to the row.
                .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)

            // A send that failed keeps its bubble and says so, rather than
            // taking the text down with it.
            if hasFailed {
                Button(action: retry) {
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
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .animation(Motion.fade, value: isPending)
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
        .transition(arrival)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(senderName): \(message.content)"))
        .accessibilityValue(hasFailed ? Text(L10n.messagesChatMessageFailed) : Text(""))
        .accessibilityAction(named: Text(L10n.commonRetry)) { if hasFailed { retry() } }
        // A press-and-hold is not reachable under VoiceOver; the same two
        // actions are offered by name instead.
        .accessibilityActions {
            if canModify {
                Button { edit() } label: { Text(L10n.commonEdit) }
                Button { delete() } label: { Text(L10n.commonDelete) }
            }
        }
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
private struct BubbleActionsAnchor {
    let id: MessageID
    let bounds: Anchor<CGRect>
    let isMine: Bool
}

private struct BubbleActionsAnchorKey: PreferenceKey {
    static let defaultValue: BubbleActionsAnchor? = nil

    static func reduce(value: inout BubbleActionsAnchor?, nextValue: () -> BubbleActionsAnchor?) {
        value = value ?? nextValue()
    }
}

/// Edit and Delete, as one glass capsule pinned to the bubble it belongs to.
private struct MessageActionsBar: View {
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 2) {
                button(L10n.commonEdit, symbol: "pencil", action: edit)
                Divider().frame(height: 20)
                button(L10n.commonDelete, symbol: "trash", tint: Palette.danger, action: delete)
            }
            .padding(.horizontal, 4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .fixedSize()
    }

    private func button(
        _ title: LocalizedStringResource,
        symbol: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label { Text(title) } icon: { Image(systemName: symbol) }
                .font(.caption.weight(.medium))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(tint ?? .primary)
                .padding(.horizontal, 12)
                // Full height, not the height of nine-point caption text.
                // Delete sat next to Edit in a 26-point strip, which is a
                // careless place to make a fingertip choose.
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }
}

struct NewConversationSheet: View {
    @Bindable var store: StoreOf<NewConversationFeature>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // A one-person household has nobody to start a thread with,
                    // and an empty picker with a dead Create button does not say
                    // so. The invite code is the actual next step.
                    if store.hasNobodyToMessage {
                        Label {
                            Text(L10n.messagesNobodyToMessage)
                        } icon: {
                            Image(systemName: "person.badge.plus")
                        }
                        .foregroundStyle(.secondary)
                    }

                    ForEach(store.selectableMembers) { member in
                        Button { store.send(.memberToggled(member.id)) } label: {
                            HStack(spacing: 12) {
                                // Inside the member toggle: the tap picks
                                // who is in the conversation.
                                Avatar(
                                    initials: member.initials,
                                    seed: member.id.rawValue,
                                    size: 34,
                                    viewable: false
                                )
                                Text(member.displayName).foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                if store.selected.contains(member.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                } header: {
                    Text(L10n.messagesPickPeople)
                }

                if store.isGroup {
                    Section {
                        TextField(text: $store.title) {
                            Text(L10n.messagesNewGroupNamePlaceholder)
                        }
                    } header: {
                        Text(L10n.messagesGroupNameOptional)
                    }
                }

                if let error = store.inlineError {
                    Section {
                        Label { Text(error) } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                        .foregroundStyle(Palette.danger)
                    }
                }
            }
            .animation(Motion.spring, value: store.selected)
            .navigationTitle(Text(L10n.messagesNewConversationTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.send(.submitTapped) } label: {
                        if store.isSubmitting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(L10n.messagesNewGroupCreate).bold()
                        }
                    }
                    .disabled(!store.canSubmit)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The Chat tab: the conversation list, and the threads pushed on it.
///
/// `root` is whatever the tab draws at the bottom of the stack — the list,
/// dressed with the tab's own toolbar.
public struct MessagesStack<Root: View>: View {
    @Bindable var store: StoreOf<MessagesFeature>
    let root: Root

    public init(store: StoreOf<MessagesFeature>, @ViewBuilder root: () -> Root) {
        self.store = store
        self.root = root()
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            root
        } destination: { store in
            switch store.case {
            case let .chat(store): ChatView(store: store)
            }
        }
    }
}
