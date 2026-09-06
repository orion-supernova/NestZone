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
    public var send: @Sendable (ConversationID, String) async throws -> MessageID
    public var markRead: @Sendable (ConversationID) async throws -> Void
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
                args: ["conversationId": conversationID, "limit": limit],
                as: [Message].self
            )
        },
        send: { conversationID, content in
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.messageEmpty",
                    defaultValue: "Type a message first."
                ))
            }
            return try await ConvexConnection.shared.mutate(
                "messages:send",
                args: ["conversationId": conversationID, "content": trimmed, "messageType": "text"],
                as: MessageID.self
            )
        },
        markRead: { conversationID in
            try await ConvexConnection.shared.mutate(
                "messages:markRead", args: ["conversationId": conversationID]
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
