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
        /// A conversation a notification asked for before the list had it.
        var pendingOpenID: ConversationID?
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
                // The pin and the title come with the live row, so a message
                // pinned from another phone appears here without a reopen.
                if let live = conversations[id: chat.conversation.id] { chat.absorb(live) }
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
        /// A notification named this conversation. Opened now if the list has
        /// it, otherwise when the list arrives.
        case openRequested(ConversationID)
        case composeTapped
        case path(StackActionOf<Path>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case conversations, members }

    @Dependency(\.messages) var messagesClient
    @Dependency(\.homes) var homesClient
    @Dependency(\.paywall) var paywall
    /// Messages are Plus: a house without it reads what is there, and the
    /// controls that write ask for the paywall instead.
    @Shared(.pro) var pro: ProStatus

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
                state.propagateToOpenChats()
                guard let wanted = state.pendingOpenID else { return .none }
                // The list has answered: a chat that is not in it is gone, and
                // must not open later when something else changes.
                state.pendingOpenID = nil
                guard state.conversations[id: wanted] != nil else { return .none }
                return .send(.openRequested(wanted))

            case let .openRequested(id):
                guard let conversation = state.conversations[id: id] else {
                    // Held only until the list arrives; a list that has
                    // already answered without it means the chat is gone.
                    state.pendingOpenID = state.isLoading ? id : nil
                    return .none
                }
                state.pendingOpenID = nil
                // From the list, so Back lands there and not on another chat.
                state.path.removeAll()
                return .send(.conversationTapped(conversation))

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
                guard pro.isPro else { return .run { _ in paywall.request(.messages) } }
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
