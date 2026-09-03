import Foundation
import ConvexMobile

@MainActor
class MessagesManager {
    static let shared = MessagesManager()
    private init() {}

    // MARK: - Conversations

    func fetchConversations(for homeId: String) async throws -> [PocketBaseConversation] {
        let convos: [PocketBaseConversation] = try await Convex.once(
            "conversations:listByHome", args: ["homeId": homeId], as: [PocketBaseConversation].self
        )
        // Most-recent activity first (lastMessageAt, then updated).
        return convos.sorted {
            ($0.lastMessageAt ?? $0.updated ?? 0) > ($1.lastMessageAt ?? $1.updated ?? 0)
        }
    }

    func createConversation(
        participants: [String],
        homeId: String,
        title: String? = nil,
        isGroupChat: Bool = false
    ) async throws -> PocketBaseConversation {
        var args: [String: ConvexEncodable?] = [
            "homeId": homeId,
            "participants": participants.map { $0 as ConvexEncodable? },
            "is_group_chat": isGroupChat,
        ]
        if let title = title, !title.isEmpty { args["title"] = title }

        return try await Convex.client.mutation("conversations:create", with: args)
    }

    // MARK: - Messages

    func fetchMessages(for conversationId: String) async throws -> [PocketBaseMessage] {
        // Live UI subscribes directly; this one-shot is for non-reactive callers.
        try await Convex.once(
            "messages:listByConversation",
            args: ["conversationId": conversationId, "limit": 500],
            as: [PocketBaseMessage].self
        )
    }

    func sendMessage(
        conversationId: String,
        content: String,
        messageType: PocketBaseMessage.MessageType = .text,
        file: String? = nil
    ) async throws {
        var args: [String: ConvexEncodable?] = [
            "conversationId": conversationId,
            "content": content,
            "message_type": convexMessageType(messageType),
        ]
        if let file = file { args["file"] = file }
        // Server also updates the conversation's last_message preview.
        try await Convex.client.mutation("messages:send", with: args)
    }

    /// Mark every message in a conversation as read by the current user.
    func markConversationRead(conversationId: String) async throws {
        try await Convex.client.mutation("messages:markRead", with: ["conversationId": conversationId])
    }

    func getUnreadMessageCount(for conversationId: String, userId: String) async throws -> Int {
        let messages: [PocketBaseMessage] = try await Convex.once(
            "messages:listByConversation",
            args: ["conversationId": conversationId, "limit": 500],
            as: [PocketBaseMessage].self
        )
        return messages.filter { $0.senderId != userId && !$0.readBy.contains(userId) }.count
    }

    // MARK: - User Helpers

    func fetchHouseholdMembers(for homeId: String) async throws -> [PocketBaseUser] {
        try await Convex.once("homes:members", args: ["homeId": homeId], as: [PocketBaseUser].self)
    }

    // MARK: - Helpers

    /// The Convex schema only models text/image/system; map richer client types down.
    private func convexMessageType(_ type: PocketBaseMessage.MessageType) -> String {
        switch type {
        case .text, .system: return type.rawValue
        case .image, .video, .gif, .document, .audio: return "image"
        }
    }
}
