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

            case .destination(.presented(.compose(.finished))):
                state.destination = nil
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

    @ObservableState
    public struct State: Equatable {
        public var conversation: Conversation
        public var title: String
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User>
        public var messages: IdentifiedArrayOf<Message> = []
        public var isLoading = true
        public var draft = ""
        @Presents public var alert: AlertState<Action.Alert>?

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

        /// Oldest first, which is the order a chat reads in.
        public var ordered: [Message] {
            messages.sorted { Timestamp.newestFirst($1.created, $0.created) }
        }

        public var canSend: Bool {
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        public func isMine(_ message: Message) -> Bool {
            message.senderID == currentUserID
        }

        public func senderName(for message: Message) -> String {
            members[id: message.senderID]?.displayName
                ?? String(localized: L10n.notesAuthorMember)
        }

        /// Whether this message starts a new run from the same person, which is
        /// the only time the sender's name and avatar are drawn.
        public func startsGroup(at index: Int) -> Bool {
            let list = ordered
            guard index > 0 else { return true }
            return list[index - 1].senderID != list[index].senderID
        }
    }

    public enum Action: BindableAction {
        case task
        case messagesUpdated([Message])
        case loadFailed(AppError)
        case sendTapped
        case sendFailed(AppError)
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
                return .merge(
                    .run { send in
                        for try await messages in messagesClient.messages(id, Self.messageWindow) {
                            await send(.messagesUpdated(messages))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.messages, cancelInFlight: true),

                    .run { _ in try? await messagesClient.markRead(id) }
                )

            case let .messagesUpdated(messages):
                state.isLoading = false
                state.messages = IdentifiedArray(uniqueElements: messages)
                // Anything arriving while the thread is open is read on arrival.
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
                let text = state.draft
                // Clear immediately: the field must be ready for the next line
                // before the round trip completes.
                state.draft = ""
                return .run { [id = state.conversation.id] send in
                    try await messagesClient.send(id, text)
                } catch: { error, send in
                    await send(.sendFailed(AppError(error)))
                }

            case let .sendFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
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
    }

    public enum Action: Equatable, BindableAction {
        case memberToggled(UserID)
        case submitTapped
        case failed(AppError)
        case finished
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
                var participants = Array(state.selected)
                if let me = state.currentUserID { participants.append(me) }
                return .run { [
                    homeID = state.homeID,
                    participants,
                    title = state.title,
                    isGroup = state.isGroup
                ] send in
                    try await messages.createConversation(
                        homeID, participants, title.isEmpty ? nil : title, isGroup
                    )
                    await send(.finished)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .failed(error):
                state.isSubmitting = false
                state.inlineError = error.errorDescription
                return .none

            case .finished, .binding:
                return .none
            }
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension MessagesFeature.Path.State: Equatable {}
extension MessagesFeature.Destination.State: Equatable {}
