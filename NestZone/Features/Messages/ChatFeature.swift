import ComposableArchitecture
import Foundation

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
        /// What it answers and who it names, kept so a retry sends the same
        /// message and the bubble can draw its quote while it waits.
        public var replyTo: ReplyQuote?
        public var mentions: [UserID] = []

        public var message: Message {
            Message(
                id: id, senderID: senderID, content: content,
                replyTo: replyTo?.reply, mentions: mentions
            )
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
        /// Deleted here, not yet gone on the server. Filtered out of the thread
        /// and out of incoming pushes, which would otherwise resurrect them
        /// between the mutation landing and the subscription catching up.
        public var deleting: Set<MessageID> = []
        /// Reported here: gone from the thread at once. The server leaves them
        /// out of the next push on its own.
        public var hidden: Set<MessageID> = []
        /// The message the composer is answering.
        public var replying: ReplyQuote?
        /// People picked from the `@` list, in the text being written.
        public var mentions: [Mention] = []
        /// Reactions and a pin the person just chose that the live push has not
        /// shown yet. Laid over what the server says until it says the same
        /// (or the write fails), so an unrelated push in between cannot undo
        /// them for a moment.
        public var reactionIntents: [ReactionIntent: Bool] = [:]
        public var pinIntent: PinIntent?
        /// Set once the pin write has been answered, with the pin the thread
        /// showed at that moment: any live change after it is somebody else's
        /// and retires the laid-over pin even if it is not ours.
        var pinSettledAgainst: PinSettle?
        /// What was said after a report, for a few seconds.
        public var notice: ReportNotice?
        @Presents public var report: ReportFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?
        /// Everybody this person has blocked, from the one subscription the tab
        /// bar keeps (`ModerationSessionFeature`).
        @Shared(.blockedPeople) public var blocked: [BlockedPerson]

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
            messages.filter { !deleting.contains($0.id) && !hidden.contains($0.id) }
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
            senderName(forID: message.senderID)
        }

        public func senderName(forID id: UserID) -> String {
            if id == currentUserID { return String(localized: L10n.issuesYou) }
            return members[id: id]?.displayName ?? String(localized: L10n.memberDeleted)
        }

        /// What the server says about a message's reactions, with what the
        /// person just chose laid over it.
        public func reactions(of message: Message) -> [MessageReaction] {
            guard !reactionIntents.isEmpty, let me = currentUserID else { return message.reactions }
            var result = message.reactions
            for (intent, on) in reactionIntents where intent.messageID == message.id {
                let has = result.contains { $0.userID == me && $0.emoji == intent.emoji }
                if on, !has {
                    result.append(MessageReaction(emoji: intent.emoji, userID: me))
                } else if !on, has {
                    result.removeAll { $0.userID == me && $0.emoji == intent.emoji }
                }
            }
            return result
        }

        /// The pinned message as the thread shows it: the server's, with a pin
        /// the person just made or lifted laid over it.
        public var pinned: PinnedMessage? {
            let pin: PinnedMessage? = switch pinIntent {
            case let .pin(pin): pin
            case .unpin: nil
            case nil: conversation.pinned
            }
            guard let pin, !hidden.contains(pin.messageID), !deleting.contains(pin.messageID)
            else { return nil }
            return pin
        }

        /// Takes the live row for this thread, and retires a pin the server has
        /// now caught up with.
        public mutating func absorb(_ live: Conversation) {
            conversation = live
            let matches: Bool = switch pinIntent {
            case let .pin(pin): live.pinned?.messageID == pin.messageID
            case .unpin: live.pinned == nil
            case nil: false
            }
            if matches || (pinSettledAgainst.map { live.pinned != $0.pin } ?? false) {
                pinIntent = nil
                pinSettledAgainst = nil
            }
        }

        /// Who a 1:1 is with. `nil` for a group, which has no one person to block.
        public var directCounterpart: UserID? {
            guard !conversation.isGroupChat else { return nil }
            let others = conversation.counterparts(excluding: currentUserID)
            return others.count == 1 ? others[0] : nil
        }

        public var isCounterpartBlocked: Bool {
            guard let other = directCounterpart else { return false }
            return blocked.contains { $0.id == other }
        }

        // MARK: Mentions

        /// What follows an `@` at the end of the draft, while the person is
        /// still choosing who: `nil` when they are not.
        public var mentionQuery: String? {
            guard let at = draft.lastIndex(of: "@") else { return nil }
            if at > draft.startIndex, !draft[draft.index(before: at)].isWhitespace { return nil }
            let query = draft[draft.index(after: at)...]
            guard !query.contains(where: \.isNewline), query.count <= 30 else { return nil }
            return String(query)
        }

        /// The people in this thread, minus me, whose name contains what has
        /// been typed after the `@`.
        public var mentionSuggestions: [User] {
            guard let query = mentionQuery else { return [] }
            let thread = Set(conversation.participants)
            return members
                .filter { $0.id != currentUserID && thread.contains($0.id) }
                .filter { query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query) }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }

        /// Swaps the half-typed `@query` for `@Name ` and remembers who it was.
        mutating func pickMention(_ userID: UserID) {
            guard let user = members[id: userID], let at = draft.lastIndex(of: "@") else { return }
            let name = user.displayName
            draft = String(draft[..<at]) + "@\(name) "
            if !mentions.contains(where: { $0.userID == userID }) {
                mentions.append(Mention(userID: userID, name: name))
            }
        }

        /// The people still named in the text: a name deleted after it was
        /// picked is not a mention any more.
        func mentionIDs(in text: String) -> [UserID] {
            mentions.filter { text.contains("@\($0.name)") }.map(\.userID)
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
        case blockSenderTapped(MessageID)
        case messageNotLoaded
        case pinWriteSucceeded
        case reactionTapped(MessageID, String)
        case reactionFailed(MessageID, String, on: Bool, AppError)
        case replyTapped(MessageID)
        case replyCleared
        case mentionPicked(UserID)
        case copyTapped(MessageID)
        case pinTapped(MessageID)
        case unpinTapped
        case pinFailed(PinIntent, AppError)
        case reportTapped(MessageID)
        case noticeExpired
        case blockTapped
        case unblockTapped
        case blockFailed(BlockedPerson, AppError)
        case unblockFailed(BlockedPerson, AppError)
        case report(PresentationAction<ReportFeature.Action>)
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

        public enum Alert: Equatable {
            case confirmBlock(UserID)
        }

        @CasePathable
        public enum Delegate: Equatable {
            /// Bubbled so the conversation list can follow the new name.
            case renamed(Conversation)
        }
    }

    private enum CancelID { case messages, notice }

    @Dependency(\.messages) var messagesClient
    @Dependency(\.moderation) var moderation
    @Dependency(\.pasteboard) var pasteboard
    @Dependency(\.continuousClock) var clock
    @Dependency(\.paywall) var paywall
    /// Messages are Plus: sending and editing ask a free house for the paywall.
    /// Reading, deleting your own words and the read receipt stay.
    @Shared(.pro) var pro: ProStatus

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
                // A reaction the server now shows as chosen stops being laid over it.
                state.reactionIntents = state.reactionIntents.filter { intent, on in
                    guard let message = state.messages[id: intent.messageID],
                          let me = state.currentUserID else { return false }
                    let has = message.reactions.contains { $0.userID == me && $0.emoji == intent.emoji }
                    return has != on
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
                // Nothing optimistic is drawn for a write that will be refused.
                guard pro.isPro else { return .run { _ in paywall.request(.messages) } }
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
                let replyTo = state.replying
                let mentions = state.mentionIDs(in: text)
                state.replying = nil
                state.mentions = []
                state.pendingSeq += 1
                let local = MessageID("pending:\(state.pendingSeq)")
                state.pending.append(Pending(
                    id: local,
                    content: text,
                    senderID: state.currentUserID ?? "",
                    replyTo: replyTo,
                    mentions: mentions
                ))
                return send(
                    text, local: local, in: state.conversation.id,
                    replyTo: replyTo?.messageID, mentions: mentions
                )

            case let .retryTapped(local):
                guard let entry = state.pending[id: local], entry.failed else { return .none }
                guard pro.isPro else { return .run { _ in paywall.request(.messages) } }
                state.pending[id: local]?.failed = false
                return send(
                    entry.content, local: local, in: state.conversation.id,
                    replyTo: entry.replyTo?.messageID, mentions: entry.mentions
                )

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
                // A refusal is not a bad connection: retrying says the same
                // no. The words go back into the composer, where they can be
                // copied or sent somewhere else, and the person is told why.
                if case .refused = error, let entry = state.pending[id: local] {
                    state.pending.remove(id: local)
                    if state.draft.isEmpty {
                        state.draft = entry.content
                        state.replying = entry.replyTo
                    }
                    state.alert = .failure(error)
                    return .none
                }
                state.pending[id: local]?.failed = true
                guard case .validation = error else { return .none }
                state.alert = .failure(error)
                return .none

            case let .reactionTapped(id, emoji):
                guard state.messages[id: id] != nil else { return .none }
                // Nothing optimistic is drawn for a write that will be refused.
                guard pro.isPro else { return .run { _ in paywall.request(.messages) } }
                let key = ReactionIntent(messageID: id, emoji: emoji)
                let mine = state.messages[id: id].map { state.reactions(of: $0) }?
                    .contains { $0.userID == state.currentUserID && $0.emoji == emoji } ?? false
                // Explicit, never a toggle: the server is told what this tap
                // chose, so a retry or a double tap cannot flip it back.
                let on = !mine
                state.reactionIntents[key] = on
                return .run { _ in
                    try await messagesClient.react(id, emoji, on)
                } catch: { error, send in
                    await send(.reactionFailed(id, emoji, on: on, AppError(error)))
                }

            case let .reactionFailed(id, emoji, on, error):
                // Nothing changed on the server, so no push is coming to put it
                // back: the choice laid over it is taken off by hand. Only if it
                // is still this one — a later tap on the same chip stands.
                let key = ReactionIntent(messageID: id, emoji: emoji)
                if state.reactionIntents[key] == on { state.reactionIntents[key] = nil }
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .replyTapped(id):
                guard let message = state.messages[id: id] else { return .none }
                // Nothing to reply into: a blocked 1:1 is closed, and a house
                // without Plus is read-only, which sends for the paywall just
                // as the send button does.
                guard !state.isCounterpartBlocked else { return .none }
                guard pro.isPro else { return .run { _ in paywall.request(.messages) } }
                // A reply and a rewrite cannot share the composer.
                if state.editing != nil {
                    state.editing = nil
                    state.draft = ""
                }
                state.replying = ReplyQuote(
                    messageID: id,
                    senderID: message.senderID,
                    snippet: String(message.content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .prefix(Self.snippetLength)),
                    kind: message.kind
                )
                return .none

            case .replyCleared:
                state.replying = nil
                return .none

            case let .mentionPicked(userID):
                state.pickMention(userID)
                return .none

            case let .copyTapped(id):
                guard let message = state.messages[id: id] else { return .none }
                return .run { _ in pasteboard.copy(message.content) }

            case let .pinTapped(id):
                guard let message = state.messages[id: id], message.kind != .system else {
                    return .none
                }
                guard pro.isPro else { return .run { _ in paywall.request(.messages) } }
                let pin = PinnedMessage(
                    messageID: id,
                    senderID: message.senderID,
                    snippet: String(message.content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .prefix(Self.snippetLength)),
                    kind: message.kind,
                    pinnedBy: state.currentUserID
                )
                state.pinIntent = .pin(pin)
                state.pinSettledAgainst = nil
                return .run { [conversation = state.conversation.id] send in
                    try await messagesClient.pin(conversation, id)
                    await send(.pinWriteSucceeded)
                } catch: { error, send in
                    await send(.pinFailed(.pin(pin), AppError(error)))
                }

            case .unpinTapped:
                guard state.pinned != nil else { return .none }
                state.pinIntent = .unpin
                state.pinSettledAgainst = nil
                // Taking a pin down never needs Plus, like every removal.
                return .run { [conversation = state.conversation.id] send in
                    try await messagesClient.unpin(conversation)
                    await send(.pinWriteSucceeded)
                } catch: { error, send in
                    await send(.pinFailed(.unpin, AppError(error)))
                }

            case .pinWriteSucceeded:
                // From here the live thread is the truth. If it already says
                // what was chosen, `absorb` has cleared the overlay; if not,
                // the next change to the pin, ours or not, will.
                if state.pinIntent != nil {
                    state.pinSettledAgainst = PinSettle(pin: state.conversation.pinned)
                }
                return .none

            case let .pinFailed(intent, error):
                if state.pinIntent == intent {
                    state.pinIntent = nil
                    state.pinSettledAgainst = nil
                }
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .reportTapped(id):
                guard let message = state.messages[id: id], !state.isMine(message) else { return .none }
                state.report = ReportFeature.State(
                    subject: ReportSubject(kind: .message, targetID: id.rawValue),
                    preview: message.kind == .image
                        ? String(localized: L10n.messagesPhoto)
                        : message.content
                )
                return .none

            // Filed (or already filed, or past the daily limit): in every case
            // the message is hidden from this person now, and the thanks is
            // said quietly rather than in an alert.
            case let .report(.presented(.delegate(.reported(outcome)))):
                if let target = state.report?.subject.targetID {
                    state.hidden.insert(MessageID(target))
                }
                state.report = nil
                state.notice = ReportNotice(outcome)
                return .run { send in
                    try await clock.sleep(for: ReportNotice.linger)
                    await send(.noticeExpired)
                }
                .cancellable(id: CancelID.notice, cancelInFlight: true)

            case .noticeExpired:
                state.notice = nil
                return .none

            // Somebody else's message in any thread, group included: blocking
            // is not only a 1:1 thing.
            case let .blockSenderTapped(id):
                guard let message = state.messages[id: id], !state.isMine(message) else {
                    return .none
                }
                state.alert = Self.confirmBlockAlert(
                    userID: message.senderID,
                    name: state.members[id: message.senderID]?.displayName
                        ?? String(localized: L10n.memberDeleted)
                )
                return .none

            // A quote or a pin that points past the loaded window: said, not a
            // dead tap.
            case .messageNotLoaded:
                state.notice = .notLoaded
                return .run { send in
                    try await clock.sleep(for: ReportNotice.linger)
                    await send(.noticeExpired)
                }
                .cancellable(id: CancelID.notice, cancelInFlight: true)

            case .blockTapped:
                guard let other = state.directCounterpart else { return .none }
                state.alert = Self.confirmBlockAlert(
                    userID: other,
                    name: state.members[id: other]?.displayName ?? state.title
                )
                return .none

            case let .alert(.presented(.confirmBlock(userID))):
                let person = BlockedPerson(
                    id: userID,
                    name: state.members[id: userID]?.displayName,
                    avatarURL: state.members[id: userID]?.avatarURL
                )
                state.$blocked.withLock { people in
                    if !people.contains(where: { $0.id == userID }) { people.insert(person, at: 0) }
                }
                return .run { _ in
                    try await moderation.block(userID)
                } catch: { error, send in
                    await send(.blockFailed(person, AppError(error)))
                }

            case let .blockFailed(person, error):
                // Nothing was blocked, so no push is coming to say so.
                state.$blocked.withLock { $0.removeAll { $0.id == person.id } }
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .unblockTapped:
                guard let other = state.directCounterpart,
                      let person = state.blocked.first(where: { $0.id == other }) else { return .none }
                state.$blocked.withLock { $0.removeAll { $0.id == other } }
                return .run { _ in
                    try await moderation.unblock(other)
                } catch: { error, send in
                    await send(.unblockFailed(person, AppError(error)))
                }

            case let .unblockFailed(person, error):
                state.$blocked.withLock { people in
                    if !people.contains(where: { $0.id == person.id }) { people.insert(person, at: 0) }
                }
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

                return .none

            // Tapping the thread backs out of everything the composer and the
            // bubbles have going on. Leaving the editor running while the bar
            // and the keyboard both went away read as stuck: the banner stayed,
            // the text stayed, and nothing on screen explained why.
            case .backgroundTapped:
                guard state.editing != nil else { return .none }
                state.editing = nil
                state.draft = ""
                return .none

            case let .editTapped(id):
                guard let message = state.messages[id: id], state.canModify(message) else {
                    return .none
                }
                guard pro.isPro else {
                        return .run { _ in paywall.request(.messages) }
                }
                state.replying = nil
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

            case .binding, .alert, .delegate, .report:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$report, action: \.report) { ReportFeature() }
    }

    private static func confirmBlockAlert(userID: UserID, name: String) -> AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: L10n.chatBlockTitle(name)))
        } actions: {
            ButtonState(role: .destructive, action: .confirmBlock(userID)) {
                TextState(String(localized: L10n.chatBlockConfirm))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.chatBlockMessage))
        }
    }

    /// How much of a message a reply or a pin quotes, as the server cuts it.
    static let snippetLength = 140

    private func send(
        _ text: String,
        local: MessageID,
        in conversation: ConversationID,
        replyTo: MessageID?,
        mentions: [UserID]
    ) -> Effect<Action> {
        .run { send in
            let server = try await messagesClient.send(conversation, text, replyTo, mentions)
            await send(.sendSucceeded(local: local, server: server))
        } catch: { error, send in
            await send(.sendFailed(local: local, AppError(error)))
        }
    }
}
