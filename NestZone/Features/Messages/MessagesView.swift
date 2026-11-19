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
                    .proLocked(.messages)
                }
            }
            .task { await store.send(.task).finish() }
            // A house without Plus: locked when there is nothing here,
            // read-only under a banner when there is.
            .proModule(
                .messages,
                hasData: !store.conversations.isEmpty,
                isLoaded: !store.isLoading
            )
            .hostedSheet(item: $store.scope(
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
    @Shared(.pro) private var pro
    @FocusState private var isComposerFocused: Bool
    /// Off until the thread's first delivery has been drawn, so opening a chat
    /// does not slide its whole history in one bubble at a time.
    @State private var isSettled = false
    /// Searching what is loaded, on this phone.
    @State private var isSearching = false
    @State private var searchText = ""
    /// Your own reactions, counted — the haptic keys on this and never on the
    /// model, which somebody else's reaction also changes.
    @State private var reactionTaps = 0
    /// Taps on a quote or a pin whose message is not loaded.
    @State private var missTaps = 0

    var body: some View {
        // Sorted once per render. `startsGroup` used to reach for `ordered`
        // itself, which re-sorted the whole thread for every bubble on screen.
        let all = store.state.ordered
        let term = isSearching ? searchText.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let thread = term.isEmpty
            ? all
            : all.filter { $0.content.localizedStandardContains(term) }
        // The newest bubble, when it is somebody else's. Arrivals animate on
        // this rather than on the count: a send is animated where it is made,
        // and your bubble's echo replacing its stand-in has to stay a silent
        // swap — animated, the stand-in would slide away as its twin rose in.
        let arrival = thread.last.flatMap { store.state.isMine($0) ? nil : $0.id }
        let pin = store.state.pinned

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
                            bubble(for: message, at: index, in: thread, term: term, pin: pin, proxy: proxy)
                                .equatable()
                                .id(message.id)
                        }

                        if thread.isEmpty, !term.isEmpty {
                            Text(L10n.chatSearchNoResults)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.vertical, Metrics.stackSpacing)
                    // Bubbles had a transition and nothing that ran it: every
                    // push landed outside an animation, so new messages just
                    // appeared.
                    .animation(isSettled ? Motion.spring : nil, value: arrival)
                    // Catches the taps that land beside a bubble rather than on
                    // one. Behind the thread, not around it.
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
            // The pin and the search sit under the navigation bar, over the
            // thread. Inside the reader so a tap on the pin can scroll to it.
            .safeAreaInset(edge: .top, spacing: 0) {
                topBars(resultCount: thread.count, pin: pin, proxy: proxy)
            }
            .onChange(of: all.last?.id) { _, newest in
                guard !isSearching, let newest else { return }
                withAnimation(Motion.spring) { proxy.scrollTo(newest, anchor: .bottom) }
            }
            .onChange(of: store.isLoading, initial: true) { _, loading in
                if !loading { isSettled = true }
            }
        }
        .background(Backdrop(tint: theme.accent))
        // Swipe the keyboard down; a tap anywhere in the thread does the same,
        // through `dismissEverything`.
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let notice = store.notice {
                    ReportNoticeToast(notice: notice)
                        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity).reduced(reduceMotion))
                }
                // Read-only for a house without Plus: the thread stays readable
                // and the way to the plans takes the composer's place. A 1:1
                // with somebody blocked has no composer either.
                if store.isCounterpartBlocked {
                    BlockedComposerBar(name: store.title) { store.send(.unblockTapped) }
                } else if pro.isPro {
                    ChatComposer(store: store, isFocused: $isComposerFocused)
                } else {
                    ProReadOnlyBanner(feature: .messages)
                }
            }
            .animation(Motion.spring, value: store.notice)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: reactionTaps)
        .sensoryFeedback(.warning, trigger: missTaps)
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { overflow }
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .hostedSheet(item: $store.scope(state: \.report, action: \.report)) {
            ReportSheet(store: $0)
        }
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

    /// The search field or the pinned bar, under the navigation bar.
    @ViewBuilder
    private func topBars(resultCount: Int, pin: PinnedMessage?, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            if isSearching {
                ChatSearchBar(
                    text: $searchText,
                    resultCount: resultCount,
                    close: closeSearch
                )
                .transition(AnyTransition.move(edge: .top).combined(with: .opacity).reduced(reduceMotion))
            }
            if let pin, !isSearching {
                PinnedBar(
                    pin: pin,
                    senderName: pin.senderID.map { store.state.senderName(forID: $0) }
                        ?? String(localized: L10n.memberDeleted),
                    goTo: { scroll(to: pin.messageID, proxy) },
                    unpin: { store.send(.unpinTapped) }
                )
                .transition(AnyTransition.move(edge: .top).combined(with: .opacity).reduced(reduceMotion))
            }
        }
        .animation(Motion.spring, value: isSearching)
        .animation(Motion.spring, value: pin?.messageID)
    }

    // MARK: Rows

    private func bubble(
        for message: Message,
        at index: Int,
        in thread: [Message],
        term: String,
        pin: PinnedMessage?,
        proxy: ScrollViewProxy
    ) -> MessageBubble {
        let state = store.state
        let isMine = state.isMine(message)
        let canHold = !state.isPending(message) && message.kind != .system
        // Only a message that names somebody pays for looking the names up.
        let mentionNames = message.mentions.isEmpty ? [] : message.mentions.compactMap {
            state.members[id: $0]?.displayName
        }
        return MessageBubble(
            message: message,
            isMine: isMine,
            senderName: state.senderName(for: message),
            showsSender: state.startsGroup(at: index, in: thread) && !isMine,
            isPending: state.isPending(message),
            hasFailed: state.hasFailed(message),
            canModify: state.canModify(message),
            canHold: canHold,
            canReply: !state.isCounterpartBlocked,
            isPinned: pin?.messageID == message.id,
            isBeingEdited: store.editing == message.id,
            me: state.currentUserID,
            reactions: state.reactions(of: message),
            quoteName: message.replyTo.map { state.senderName(forID: $0.senderID) },
            mentionNames: mentionNames,
            highlight: term,
            handlers: MessageHandlers(
                retry: { store.send(.retryTapped(message.id)) },
                dismiss: dismissEverything,
                reply: { store.send(.replyTapped(message.id)) },
                copy: { store.send(.copyTapped(message.id)) },
                togglePin: {
                    store.send(pin?.messageID == message.id ? .unpinTapped : .pinTapped(message.id))
                },
                report: { store.send(.reportTapped(message.id)) },
                blockSender: { store.send(.blockSenderTapped(message.id)) },
                edit: { store.send(.editTapped(message.id)) },
                delete: { store.send(.deleteTapped(message.id)) },
                react: { react($0, on: message.id) },
                goTo: { scroll(to: $0, proxy) }
            )
        )
    }

    /// One tap on an emoji, from the panel or a chip.
    private func react(_ emoji: String, on id: MessageID) {
        reactionTaps += 1
        store.send(.reactionTapped(id, emoji))
    }

    // MARK: Toolbar

    /// Search, rename and — in a 1:1 — block, folded into one menu.
    private var overflow: some View {
        Menu {
            Button { openSearch() } label: {
                Label { Text(L10n.chatSearch) } icon: { Image(systemName: "magnifyingglass") }
            }
            Button { store.send(.renameTapped) } label: {
                Label { Text(L10n.messagesRenameTitle) } icon: { Image(systemName: "pencil") }
            }
            if store.state.directCounterpart != nil {
                Divider()
                if store.isCounterpartBlocked {
                    Button { store.send(.unblockTapped) } label: {
                        Label { Text(L10n.chatUnblock) } icon: { Image(systemName: "hand.raised.slash") }
                    }
                } else {
                    Button(role: .destructive) { store.send(.blockTapped) } label: {
                        Label { Text(L10n.chatBlock) } icon: { Image(systemName: "hand.raised") }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text(L10n.commonMore))
    }

    private func openSearch() {
        store.send(.backgroundTapped)
        withAnimation(Motion.spring) { isSearching = true }
    }

    private func closeSearch() {
        withAnimation(Motion.spring) { isSearching = false }
        searchText = ""
    }

    // MARK: Scrolling

    /// What a plain tap in the thread means: put the keyboard away and abandon
    /// an edit in progress.
    private func dismissEverything() {
        isComposerFocused = false
        store.send(.backgroundTapped)
    }

    /// To a quoted or pinned message, if it is among the ones loaded. A quote of
    /// something older says so, rather than doing nothing. Reads the thread as
    /// it is now: the bubble that asked may have been drawn some renders ago.
    private func scroll(to id: MessageID, _ proxy: ScrollViewProxy) {
        guard store.state.ordered.contains(where: { $0.id == id }) else {
            missTaps += 1
            store.send(.messageNotLoaded)
            return
        }
        isComposerFocused = false
        // A search may be hiding it: leave the search, then go.
        if isSearching { closeSearch() }
        withAnimation(Motion.travel) { proxy.scrollTo(id, anchor: .center) }
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
