import ComposableArchitecture
import Foundation

/// The household's conversations.
@Reducer
public struct MessagesFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        /// Names an untitled group chat. `MainFeature` keeps it current.
        public var homeName: String?
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

        /// What a thread is called.
        ///
        /// A name the household chose always wins. Failing that a 1:1 is named
        /// after the other person — which is the useful answer, and short. A
        /// group is named after the house: listing every member produced titles
        /// like "Ada, Grace and Alan" that only got longer as the home grew, and
        /// read as a list of people rather than as the name of a place to talk.
        public func title(for conversation: Conversation) -> String {
            if let title = conversation.title, !title.isEmpty { return title }
            let others = conversation.counterparts(excluding: currentUserID)
            if conversation.isGroupChat || others.count > 1 {
                guard let homeName, !homeName.isEmpty else {
                    return String(localized: L10n.messagesConversationCardHouseholdChat)
                }
                return String(localized: L10n.messagesGroupDefaultTitle(homeName))
            }
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
        public mutating func apply(currentUserID: UserID?, homeName: String?) {
            self.currentUserID = currentUserID
            self.homeName = homeName
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

            // The list row has to follow the thread's new name without waiting
            // for the subscription; the push confirms it a moment later.
            case let .path(.element(id: _, action: .chat(.delegate(.renamed(conversation))))):
                state.conversations[id: conversation.id] = conversation
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
        /// Renaming runs in an alert with a text field, so the draft and the
        /// presentation flag live here rather than in an `AlertState`, which
        /// cannot carry input.
        public var isRenaming = false
        public var renameDraft = ""
        /// The message the composer is rewriting, if any. Editing borrows the
        /// composer rather than opening an alert: a message can be paragraphs
        /// long, and a one-line alert field is no place to rework it.
        public var editing: MessageID?
        /// The bubble showing its actions. A hand-built bar rather than
        /// `.contextMenu`: that one takes half a second to appear, gives no
        /// feedback while you wait, and previews whatever view it is attached
        /// to — which for a chat row is the full width of the screen, so the
        /// menu never looked like it belonged to a particular bubble.
        public var actionsFor: MessageID?
        /// Deleted here, not yet gone on the server. Filtered out of the thread
        /// and out of incoming pushes, which would otherwise resurrect them
        /// between the mutation landing and the subscription catching up.
        public var deleting: Set<MessageID> = []
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
            messages.filter { !deleting.contains($0.id) }
                .sorted { Timestamp.newestFirst($1.created, $0.created) }
                + pending.map(\.message)
        }

        public var canSend: Bool {
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        public var isEditing: Bool { editing != nil }

        /// Only your own words, and only once they exist on the server — there
        /// is nothing to edit or delete about a bubble still in flight.
        public func canModify(_ message: Message) -> Bool {
            isMine(message) && pending[id: message.id] == nil
        }

        /// Which side of the thread a bubble sits on: yours right, theirs left.
        ///
        /// Anything still in flight is yours by construction. Deciding that on
        /// `senderID` alone would put your own message on the left for as long
        /// as `currentUserID` is nil — which it is until the session propagates.
        public func isMine(_ message: Message) -> Bool {
            if pending[id: message.id] != nil { return true }
            guard let currentUserID else { return false }
            return message.senderID == currentUserID
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
        case bubbleHeld(MessageID)
        case actionsDismissed
        case backgroundTapped
        case editTapped(MessageID)
        case editCancelled
        case editFailed(MessageID, String, AppError)
        case deleteTapped(MessageID)
        case deleteFailed(MessageID, AppError)
        case renameTapped
        case renameSubmitted
        case renameFinished(Conversation)
        case renameFailed(AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        @CasePathable
        public enum Delegate: Equatable {
            /// Bubbled so the conversation list can follow the new name.
            case renamed(Conversation)
        }
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
                // A delete that has landed drops out of the push; anything still
                // arriving is a row the server has not removed yet, and stays
                // hidden rather than blinking back onto the screen.
                state.deleting.formIntersection(state.messages.ids)
                // Editing something that has since been deleted elsewhere would
                // leave the composer pointed at nothing.
                if let editing = state.editing, state.messages[id: editing] == nil {
                    state.editing = nil
                    state.draft = ""
                }
                if let open = state.actionsFor, state.messages[id: open] == nil {
                    state.actionsFor = nil
                }
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

                // The composer is rewriting an existing message rather than
                // writing a new one.
                if let id = state.editing {
                    let previous = state.messages[id: id]?.content ?? ""
                    state.editing = nil
                    state.draft = ""
                    guard text != previous else { return .none }
                    state.messages[id: id]?.content = text
                    return .run { _ in
                        try await messagesClient.edit(id, text)
                    } catch: { error, send in
                        await send(.editFailed(id, previous, AppError(error)))
                    }
                }

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

            case let .bubbleHeld(id):
                guard let message = state.messages[id: id], state.canModify(message) else {
                    return .none
                }
                state.actionsFor = state.actionsFor == id ? nil : id
                return .none

            case .actionsDismissed:
                state.actionsFor = nil
                return .none

            // Tapping the thread backs out of everything the composer and the
            // bubbles have going on. Leaving the editor running while the bar
            // and the keyboard both went away read as stuck: the banner stayed,
            // the text stayed, and nothing on screen explained why.
            case .backgroundTapped:
                state.actionsFor = nil
                guard state.editing != nil else { return .none }
                state.editing = nil
                state.draft = ""
                return .none

            case let .editTapped(id):
                guard let message = state.messages[id: id], state.canModify(message) else {
                    return .none
                }
                state.actionsFor = nil
                state.editing = id
                state.draft = message.content
                return .none

            case .editCancelled:
                state.editing = nil
                state.draft = ""
                return .none

            case let .editFailed(id, previous, error):
                state.messages[id: id]?.content = previous
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .deleteTapped(id):
                guard let message = state.messages[id: id], state.canModify(message) else {
                    return .none
                }
                state.actionsFor = nil
                // Gone from the thread now; the subscription makes it official.
                state.deleting.insert(id)
                if state.editing == id {
                    state.editing = nil
                    state.draft = ""
                }
                return .run { _ in
                    try await messagesClient.delete(id)
                } catch: { error, send in
                    await send(.deleteFailed(id, AppError(error)))
                }

            case let .deleteFailed(id, error):
                // Nothing changed on the server, so no push is coming to put it
                // back. It has to be restored here or it is gone until the next
                // unrelated write.
                state.deleting.remove(id)
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .renameTapped:
                // Seeded with the name on screen, so renaming is an edit rather
                // than a retype — including when that name is the default.
                state.renameDraft = state.title
                state.isRenaming = true
                return .none

            case .renameSubmitted:
                state.isRenaming = false
                let title = state.renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                // Clearing the name is allowed: it puts the thread back on its
                // default. But a rename to exactly the default is a no-op, not a
                // reason to pin that text as a real title.
                let wanted = title == state.title ? state.conversation.title ?? "" : title
                guard wanted != state.conversation.title ?? "" else { return .none }
                return .run { [id = state.conversation.id] send in
                    await send(.renameFinished(try await messagesClient.rename(id, wanted)))
                } catch: { error, send in
                    await send(.renameFailed(AppError(error)))
                }

            case let .renameFinished(conversation):
                state.conversation = conversation
                state.title = conversation.title?.isEmpty == false
                    ? conversation.title!
                    : state.title
                return .send(.delegate(.renamed(conversation)))

            case let .renameFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .alert, .delegate:
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
