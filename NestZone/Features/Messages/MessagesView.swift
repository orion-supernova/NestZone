import ComposableArchitecture
import SwiftUI

public struct MessagesView: View {
    @Bindable var store: StoreOf<MessagesFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<MessagesFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
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
        } destination: { store in
            switch store.case {
            case let .chat(store): ChatView(store: store)
            }
        }
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
                GlassGroup {
                    VStack(spacing: Metrics.stackSpacing) {
                        ForEach(Array(store.sorted.enumerated()), id: \.element.id) { index, conversation in
                            ConversationRow(
                                title: store.state.title(for: conversation),
                                preview: conversation.lastMessage,
                                timestamp: conversation.lastMessageAt,
                                members: store.state.avatarMembers(for: conversation)
                            ) { store.send(.conversationTapped(conversation)) }
                                .appear(index)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, Metrics.scrollBottomInset)
                }
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
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        // Sorted once per render. `startsGroup` used to reach for `ordered`
        // itself, which re-sorted the whole thread for every bubble on screen.
        let thread = store.state.ordered

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
                                retry: { store.send(.retryTapped(message.id)) }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.vertical, Metrics.stackSpacing)
                }
            }
            .onChange(of: store.state.ordered.last?.id) { _, _ in
                scrollToNewest(proxy, animated: true)
            }
            // `onChange` does not fire for the value a view starts with, so the
            // first page of history — which arrives before the thread is on
            // screen — left the chat parked at the oldest message it had.
            .onAppear { scrollToNewest(proxy, animated: false) }
        }
        .background(Backdrop(tint: theme.accent))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private func scrollToNewest(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let last = store.state.ordered.last else { return }
        guard animated else {
            proxy.scrollTo(last.id, anchor: .bottom)
            return
        }
        withAnimation(Motion.spring) { proxy.scrollTo(last.id, anchor: .bottom) }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(text: $store.draft, axis: .vertical) {
                Text(L10n.messagesComposePlaceholder)
            }
            .focused($isComposerFocused)
            .lineLimit(1...5)

            Button { store.send(.sendTapped) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.pressable)
            .disabled(!store.canSend)
            .opacity(store.canSend ? 1 : 0.4)
            .animation(Motion.fade, value: store.canSend)
            .accessibilityLabel(Text(L10n.messagesComposePlaceholder))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
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
    let retry: () -> Void

    @Environment(\.theme) private var theme

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
                .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)
                .opacity(isPending && !hasFailed ? 0.55 : 1)

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
        .transition(.move(edge: isMine ? .trailing : .leading).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(senderName): \(message.content)"))
        .accessibilityValue(hasFailed ? Text(L10n.messagesChatMessageFailed) : Text(""))
        .accessibilityAction(named: Text(L10n.commonRetry)) { if hasFailed { retry() } }
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
                                Avatar(
                                    initials: member.initials,
                                    seed: member.id.rawValue,
                                    size: 34
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
