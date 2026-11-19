import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct MessagesClient: Sendable {
    public var conversations: @Sendable (HomeID) -> AsyncThrowingStream<[Conversation], any Error> = { _ in .never }
    /// Live messages in a thread. `limit` caps the window the server sends —
    /// the chat screen only ever renders the tail.
    public var messages: @Sendable (ConversationID, Int) -> AsyncThrowingStream<[Message], any Error> = { _, _ in .never }
    /// Returns the stored message's id. The composer draws the bubble before the
    /// round trip finishes, and this id is what tells it which bubble the live
    /// subscription has since echoed back — without it a confirmed message and
    /// its optimistic twin sit side by side.
    ///
    /// `replyTo` is the message this one answers (in the same conversation) and
    /// `mentions` the people it names; the server drops any that are not in the
    /// thread.
    public var send: @Sendable (ConversationID, String, MessageID?, [UserID]) async throws -> MessageID
    public var markRead: @Sendable (ConversationID) async throws -> Void
    /// Rewrites one of your own messages.
    public var edit: @Sendable (MessageID, String) async throws -> Void
    /// Deletes one of your own messages.
    public var delete: @Sendable (MessageID) async throws -> Void
    /// Sets one of your reactions on or off. `on` is explicit, never a toggle:
    /// a retry or a double tap must land on the state the person chose.
    public var react: @Sendable (MessageID, String, Bool) async throws -> Void
    /// Pins a message to the top of its thread, replacing any pin.
    public var pin: @Sendable (ConversationID, MessageID) async throws -> Void
    /// Takes the pin down.
    public var unpin: @Sendable (ConversationID) async throws -> Void
    /// Renames a thread. An empty title clears it, putting the conversation back
    /// on its default name.
    public var rename: @Sendable (ConversationID, String) async throws -> Conversation
    /// Returns the conversation — the new one, or the 1:1 thread that already
    /// existed with these people, which the server reopens rather than
    /// duplicating.
    public var createConversation: @Sendable (HomeID, [UserID], String?, Bool) async throws -> Conversation
}

extension MessagesClient: DependencyKey {
    public static let liveValue = MessagesClient(
        conversations: { homeID in
            ConvexConnection.shared.subscribe(
                to: "conversations:listByHome", args: ["homeId": homeID], as: [Conversation].self
            )
        },
        messages: { conversationID, limit in
            ConvexConnection.shared.subscribe(
                to: "messages:listByConversation",
                // `.convexNumber`, not a bare `Int`: `v.number()` is
                // `v.float64()` and convex-swift encodes `Int` as an int64,
                // which the validator rejects outright — every chat failed to
                // load a single message.
                args: ["conversationId": conversationID, "limit": limit.convexNumber],
                as: [Message].self
            )
        },
        send: { conversationID, content, replyTo, mentions in
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.messageEmpty",
                    defaultValue: "Type a message first."
                ))
            }
            var args: [String: ConvexEncodable?] = [
                "conversationId": conversationID,
                "content": trimmed,
                "messageType": "text",
            ]
            if let replyTo { args["replyToId"] = replyTo }
            if !mentions.isEmpty {
                args["mentions"] = mentions.map { $0 as ConvexEncodable? }
            }
            return try await ConvexConnection.shared.mutate(
                "messages:send", args: args, as: MessageID.self
            )
        },
        markRead: { conversationID in
            try await ConvexConnection.shared.mutate(
                "messages:markRead", args: ["conversationId": conversationID]
            )
        },
        edit: { messageID, content in
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.messageEmpty",
                    defaultValue: "Type a message first."
                ))
            }
            try await ConvexConnection.shared.mutate(
                "messages:edit", args: ["messageId": messageID, "content": trimmed]
            )
        },
        delete: { messageID in
            try await ConvexConnection.shared.mutate(
                "messages:remove", args: ["messageId": messageID]
            )
        },
        react: { messageID, emoji, on in
            try await ConvexConnection.shared.mutate(
                "messages:react",
                args: ["messageId": messageID, "emoji": emoji, "on": on]
            )
        },
        pin: { conversationID, messageID in
            try await ConvexConnection.shared.mutate(
                "conversations:pin",
                args: ["conversationId": conversationID, "messageId": messageID]
            )
        },
        unpin: { conversationID in
            try await ConvexConnection.shared.mutate(
                "conversations:unpin", args: ["conversationId": conversationID]
            )
        },
        rename: { conversationID, title in
            try await ConvexConnection.shared.mutate(
                "conversations:rename",
                args: [
                    "conversationId": conversationID,
                    "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
                ],
                as: Conversation.self
            )
        },
        createConversation: { homeID, participants, title, isGroup in
            var args: [String: ConvexEncodable?] = [
                "homeId": homeID,
                // `[UserID]` is not `ConvexEncodable`; `[ConvexEncodable?]` is,
                // so the array is widened element by element.
                "participants": participants.map { $0 as ConvexEncodable? },
                "isGroupChat": isGroup,
            ]
            if let title, !title.isEmpty { args["title"] = title }
            return try await ConvexConnection.shared.mutate(
                "conversations:create", args: args, as: Conversation.self
            )
        }
    )

    public static let testValue = MessagesClient()
}

extension DependencyValues {
    public var messages: MessagesClient {
        get { self[MessagesClient.self] }
        set { self[MessagesClient.self] = newValue }
    }
}
