import ComposableArchitecture
import Foundation

/// The household's conversations.
@Reducer
public struct MessagesFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        public var conversations: IdentifiedArrayOf<Conversation> = []
        public var members: IdentifiedArrayOf<User> = []
        public var isLoading = true
        public var path = StackState<Path.State>()
        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }

        /// Most recently active first.
        public var sorted: [Conversation] {
            conversations.sorted {
                Timestamp.newestFirst($0.lastMessageAt ?? $0.created, $1.lastMessageAt ?? $1.created)
            }
        }

        /// A 1:1 chat is named after the other person; a group keeps its title.
        public func title(for conversation: Conversation) -> String {
            if let title = conversation.title, !title.isEmpty { return title }
            let others = conversation.counterparts(excluding: currentUserID)
            let names = others.compactMap { members[id: $0]?.displayName }
            if names.isEmpty { return String(localized: L10n.messagesConversationUntitled) }
            return names.formatted(.list(type: .and))
        }

        public func avatarMembers(for conversation: Conversation) -> [AvatarStack.Member] {
            conversation.counterparts(excluding: currentUserID).map { id in
                AvatarStack.Member(
                    id: id.rawValue,
                    initials: members[id: id]?.initials ?? "?"
                )
            }
        }

        /// Hands the session down to every chat already on the stack.
        ///
        /// A chat takes its copy of the roster when it is pushed. Members and the
        /// signed-in user both arrive asynchronously, so without this a thread
        /// opened before either landed would keep drawing "Member" over every
        /// bubble — and, with no `currentUserID`, would draw the user's own
        /// messages as somebody else's, left-aligned and in glass.
        mutating func propagateToOpenChats() {
            for id in path.ids {
                guard case var .chat(chat) = path[id: id] else { continue }
                chat.members = members
                chat.currentUserID = currentUserID
                chat.title = title(for: chat.conversation)
                path[id: id] = .chat(chat)
            }
        }

        /// Mirrors the session in, then down. Called by `MainFeature`.
        public mutating func apply(currentUserID: UserID?) {
            self.currentUserID = currentUserID
            propagateToOpenChats()
        }
    }

    @Reducer
    public enum Path {
        case chat(ChatFeature)
    }

    @Reducer
    public enum Destination {
        case compose(NewConversationFeature)
    }

    public enum Action {
        case task
        case conversationsUpdated([Conversation])
        case membersUpdated([User])
        case loadFailed(AppError)
        case conversationTapped(Conversation)
        case composeTapped
        case path(StackActionOf<Path>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case conversations, members }

    @Dependency(\.messages) var messagesClient
    @Dependency(\.homes) var homesClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .merge(
                    .run { send in
                        for try await conversations in messagesClient.conversations(homeID) {
                            await send(.conversationsUpdated(conversations))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.conversations, cancelInFlight: true),

                    // Member profiles are needed to name every 1:1 thread; one
                    // subscription serves the whole list.
                    .run { send in
                        for try await members in homesClient.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.members, cancelInFlight: true)
                )

            case let .conversationsUpdated(conversations):
                state.isLoading = false
                state.conversations = IdentifiedArray(uniqueElements: conversations)
                return .none

            case let .membersUpdated(members):
                state.members = IdentifiedArray(uniqueElements: members)
                state.propagateToOpenChats()
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .conversationTapped(conversation):
                state.path.append(.chat(ChatFeature.State(
                    conversation: conversation,
                    title: state.title(for: conversation),
                    currentUserID: state.currentUserID,
                    members: state.members
                )))
                return .none

            case .composeTapped:
                state.destination = .compose(NewConversationFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.currentUserID,
                    members: state.members
                ))
                return .none

            // A conversation you just made opens straight into its thread —
            // being dropped back on the list to hunt for the row you just
            // created is what made the sheet feel like it had done nothing.
            // The row is inserted here rather than waited for: the subscription
            // will confirm it a moment later, and re-sending the same id into an
            // `IdentifiedArray` overwrites rather than duplicates.
            case let .destination(.presented(.compose(.finished(conversation)))):
                state.destination = nil
                state.conversations[id: conversation.id] = conversation
                state.path.append(.chat(ChatFeature.State(
                    conversation: conversation,
                    title: state.title(for: conversation),
                    currentUserID: state.currentUserID,
                    members: state.members
                )))
                return .none

            case .path, .destination, .alert:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

/// One thread.
@Reducer
public struct ChatFeature: Sendable {
    /// How many messages the server sends. The chat renders the tail; older
    /// history is not something this app has ever surfaced, and asking for the
    /// whole thread made the first paint scale with the conversation's age.
    static let messageWindow = 100

    /// A bubble that exists on this device only, until the live subscription
    /// echoes it back.
    public struct Pending: Identifiable, Equatable, Sendable {
        /// Namespaced so it can never collide with a Convex document id, which
        /// lets pending and confirmed bubbles share one `[Message]` for display.
        public let id: MessageID
        public var content: String
        public var senderID: UserID
        /// Filled in when the mutation returns. Identifies this bubble's echo.
        public var serverID: MessageID?
        public var failed = false

        public var message: Message {
            Message(id: id, senderID: senderID, content: content)
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var conversation: Conversation
        public var title: String
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User>
        public var messages: IdentifiedArrayOf<Message> = []
        public var pending: IdentifiedArrayOf<Pending> = []
        public var isLoading = true
        public var draft = ""
        @Presents public var alert: AlertState<Action.Alert>?

        /// Names the next optimistic bubble. A counter rather than a UUID so the
        /// reducer stays a pure function of its state and needs no clock or
        /// randomness to be testable.
        var pendingSeq = 0

        public init(
            conversation: Conversation,
            title: String,
            currentUserID: UserID?,
            members: IdentifiedArrayOf<User>
        ) {
            self.conversation = conversation
            self.title = title
            self.currentUserID = currentUserID
            self.members = members
        }

        /// Oldest first, which is the order a chat reads in, with anything still
        /// in flight tacked on the end — it is by definition the newest.
        public var ordered: [Message] {
            messages.sorted { Timestamp.newestFirst($1.created, $0.created) }
                + pending.map(\.message)
        }

        public var canSend: Bool {
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        public func isMine(_ message: Message) -> Bool {
            message.senderID == currentUserID
        }

        public func isPending(_ message: Message) -> Bool {
            pending[id: message.id] != nil
        }

        public func hasFailed(_ message: Message) -> Bool {
            pending[id: message.id]?.failed == true
        }

        public func senderName(for message: Message) -> String {
            members[id: message.senderID]?.displayName
                ?? String(localized: L10n.notesAuthorMember)
        }

        /// Whether this message starts a new run from the same person, which is
        /// the only time the sender's name and avatar are drawn.
        ///
        /// Takes the list rather than reaching for `ordered`: called once per row,
        /// it used to re-sort the entire thread for every bubble on screen.
        public func startsGroup(at index: Int, in list: [Message]) -> Bool {
            guard index > 0, index < list.count else { return true }
            return list[index - 1].senderID != list[index].senderID
        }

        /// Whether anything here is still unread by me. Guards the read receipt:
        /// `markRead` writes, every write pushes the subscription, and answering
        /// every push with another `markRead` is a round trip per message for as
        /// long as the thread is open.
        var hasUnread: Bool {
            guard let me = currentUserID else { return false }
            return messages.contains { $0.senderID != me && !$0.isRead(by: me) }
        }
    }

    public enum Action: BindableAction {
        case task
        case messagesUpdated([Message])
        case loadFailed(AppError)
        case sendTapped
        case retryTapped(MessageID)
        case sendSucceeded(local: MessageID, server: MessageID)
        case sendFailed(local: MessageID, AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case messages }

    @Dependency(\.messages) var messagesClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                let id = state.conversation.id
                // No `markRead` here: the first push arrives immediately and
                // answers it, and firing both sent the same mutation twice on
                // every open.
                return .run { send in
                    for try await messages in messagesClient.messages(id, Self.messageWindow) {
                        await send(.messagesUpdated(messages))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.messages, cancelInFlight: true)

            case let .messagesUpdated(messages):
                state.isLoading = false
                state.messages = IdentifiedArray(uniqueElements: messages)
                // A bubble the server has now sent back stops being optimistic.
                let confirmed = state.messages.ids
                state.pending.removeAll { pending in
                    guard let server = pending.serverID else { return false }
                    return confirmed.contains(server)
                }
                guard state.hasUnread else { return .none }
                return .run { [id = state.conversation.id] _ in
                    try? await messagesClient.markRead(id)
                }

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .sendTapped:
                guard state.canSend else { return .none }
                let text = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                // Clear immediately: the field must be ready for the next line
                // before the round trip completes.
                state.draft = ""
                state.pendingSeq += 1
                let local = MessageID("pending:\(state.pendingSeq)")
                state.pending.append(Pending(
                    id: local,
                    content: text,
                    senderID: state.currentUserID ?? ""
                ))
                return send(text, local: local, in: state.conversation.id)

            case let .retryTapped(local):
                guard let entry = state.pending[id: local], entry.failed else { return .none }
                state.pending[id: local]?.failed = false
                return send(entry.content, local: local, in: state.conversation.id)

            case let .sendSucceeded(local, server):
                // The echo can beat the mutation's own reply. If the message is
                // already in the list, the bubble goes now; otherwise the id is
                // parked and the next push retires it. Without both, a message
                // that arrived early would sit on screen twice, forever.
                if state.messages[id: server] != nil {
                    state.pending.remove(id: local)
                } else {
                    state.pending[id: local]?.serverID = server
                }
                return .none

            case let .sendFailed(local, error):
                // The bubble stays put, marked, and can be tapped to retry —
                // the text was previously dropped on the floor with the draft
                // already cleared, so a failed send lost what you wrote.
                state.pending[id: local]?.failed = true
                guard case .validation = error else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func send(
        _ text: String,
        local: MessageID,
        in conversation: ConversationID
    ) -> Effect<Action> {
        .run { send in
            let server = try await messagesClient.send(conversation, text)
            await send(.sendSucceeded(local: local, server: server))
        } catch: { error, send in
            await send(.sendFailed(local: local, AppError(error)))
        }
    }
}

/// Starting a new thread.
@Reducer
public struct NewConversationFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User>
        public var selected: Set<UserID> = []
        public var title = ""
        public var isSubmitting = false
        public var inlineError: String?

        public init(
            homeID: HomeID,
            currentUserID: UserID?,
            members: IdentifiedArrayOf<User>
        ) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.members = members
        }

        /// You are always in the thread, so you are never in the picker.
        public var selectableMembers: [User] {
            members.filter { $0.id != currentUserID }
        }

        public var isGroup: Bool { selected.count > 1 }

        public var canSubmit: Bool { !isSubmitting && !selected.isEmpty }

        /// There is nobody else in the home to talk to yet. Distinct from "you
        /// have not picked anyone", which is what a disabled Create button says.
        public var hasNobodyToMessage: Bool { selectableMembers.isEmpty }
    }

    public enum Action: Equatable, BindableAction {
        case memberToggled(UserID)
        case submitTapped
        case failed(AppError)
        case finished(Conversation)
        case binding(BindingAction<State>)
    }

    @Dependency(\.messages) var messages

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .memberToggled(id):
                if state.selected.contains(id) {
                    state.selected.remove(id)
                } else {
                    state.selected.insert(id)
                }
                return .none

            case .submitTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                // Sorted so the request is reproducible; `Set` has no order and
                // an unstable participant list makes a failure hard to read back.
                var participants = state.selected.sorted { $0.rawValue < $1.rawValue }
                if let me = state.currentUserID { participants.append(me) }
                return .run { [
                    homeID = state.homeID,
                    participants,
                    title = state.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    isGroup = state.isGroup
                ] send in
                    let conversation = try await messages.createConversation(
                        homeID, participants, title.isEmpty ? nil : title, isGroup
                    )
                    await send(.finished(conversation))
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .failed(error):
                state.isSubmitting = false
                state.inlineError = error.errorDescription
                return .none

            case .finished:
                // The sheet is on its way out, but a parent that keeps this
                // state around must not find it stuck mid-submit.
                state.isSubmitting = false
                return .none

            case .binding:
                return .none
            }
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension MessagesFeature.Path.State: Equatable {}
extension MessagesFeature.Destination.State: Equatable {}
