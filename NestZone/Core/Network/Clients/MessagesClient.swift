import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct MessagesClient: Sendable {
    public var conversations: @Sendable (HomeID) -> AsyncThrowingStream<[Conversation], any Error> = { _ in .never }
    /// Live messages in a thread. `limit` caps the window the server sends —
    /// the chat screen only ever renders the tail.
    public var messages: @Sendable (ConversationID, Int) -> AsyncThrowingStream<[Message], any Error> = { _, _ in .never }
    public var send: @Sendable (ConversationID, String) async throws -> Void
    public var markRead: @Sendable (ConversationID) async throws -> Void
    public var createConversation: @Sendable (HomeID, [UserID], String?, Bool) async throws -> Void
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
            guard !trimmed.isEmpty else { return }
            try await ConvexConnection.shared.mutate(
                "messages:send",
                args: ["conversationId": conversationID, "content": trimmed, "message_type": "text"]
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
                "participants": participants.map { $0 as ConvexEncodable? },
                "is_group_chat": isGroup,
            ]
            if let title, !title.isEmpty { args["title"] = title }
            try await ConvexConnection.shared.mutate("conversations:create", args: args)
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
