import Foundation

@MainActor
class MessagesManager {
    static let shared = MessagesManager()
    private let pocketBase = PocketBaseManager.shared
    private init() {}
    
    // MARK: - Conversations
    func fetchConversations(for homeId: String) async throws -> [PocketBaseConversation] {
        let response: PocketBaseListResponse<PocketBaseConversation> = try await pocketBase.getCollection(
            "conversations",
            responseType: PocketBaseListResponse<PocketBaseConversation>.self,
            filter: "home_id = '\(homeId)'",
            sort: "-last_message_at,-updated"
        )
        return response.items
    }
    
    func createConversation(
        participants: [String],
        homeId: String,
        title: String? = nil,
        isGroupChat: Bool = false
    ) async throws -> PocketBaseConversation {
        let data: [String: Any] = [
            "participants": participants,
            "home_id": homeId,
            "is_group_chat": isGroupChat,
            "title": title ?? ""
        ]
        
        return try await pocketBase.createRecord(
            in: "conversations",
            data: data,
            responseType: PocketBaseConversation.self
        )
    }
    
    func updateConversationLastMessage(
        conversationId: String,
        lastMessage: String,
        timestamp: String
    ) async throws -> PocketBaseConversation {
        let data: [String: Any] = [
            "last_message": lastMessage,
            "last_message_at": timestamp
        ]
        
        return try await pocketBase.updateRecord(
            in: "conversations",
            id: conversationId,
            data: data,
            responseType: PocketBaseConversation.self
        )
    }
    
    // MARK: - Messages
    func fetchMessages(for conversationId: String) async throws -> [PocketBaseMessage] {
        let response: PocketBaseListResponse<PocketBaseMessage> = try await pocketBase.getCollection(
            "messages",
            responseType: PocketBaseListResponse<PocketBaseMessage>.self,
            filter: "conversation_id = '\(conversationId)'",
            sort: "created"
        )
        return response.items
    }
    
    func sendMessage(
        conversationId: String,
        senderId: String,
        content: String,
        messageType: PocketBaseMessage.MessageType = .text
    ) async throws -> PocketBaseMessage {
        let data: [String: Any] = [
            "conversation_id": conversationId,
            "sender_id": senderId,
            "content": content,
            "message_type": messageType.rawValue,
            "read_by": [senderId] // Sender automatically reads their own message
        ]
        
        let message = try await pocketBase.createRecord(
            in: "messages",
            data: data,
            responseType: PocketBaseMessage.self
        )
        
        // Update conversation's last message
        let timestamp = ISO8601DateFormatter().string(from: Date())
        try await updateConversationLastMessage(
            conversationId: conversationId,
            lastMessage: content,
            timestamp: timestamp
        )
        
        return message
    }
    
    func markMessageAsRead(messageId: String, userId: String) async throws {
        // Get current message to update read_by array
        let message: PocketBaseMessage = try await pocketBase.request(
            endpoint: "/api/collections/messages/records/\(messageId)",
            requiresAuth: true,
            responseType: PocketBaseMessage.self
        )
        
        // Add user to read_by if not already there
        var updatedReadBy = message.readBy
        if !updatedReadBy.contains(userId) {
            updatedReadBy.append(userId)
        }
        
        let data: [String: Any] = [
            "read_by": updatedReadBy
        ]
        
        let _: PocketBaseMessage = try await pocketBase.updateRecord(
            in: "messages",
            id: messageId,
            data: data,
            responseType: PocketBaseMessage.self
        )
    }
    
    func getUnreadMessageCount(for conversationId: String, userId: String) async throws -> Int {
        // Get all messages in conversation where user is NOT in read_by array
        let response: PocketBaseListResponse<PocketBaseMessage> = try await pocketBase.getCollection(
            "messages",
            responseType: PocketBaseListResponse<PocketBaseMessage>.self,
            filter: "conversation_id = '\(conversationId)' && sender_id != '\(userId)' && read_by !~ '\(userId)'"
        )
        
        return response.totalItems
    }
    
    // MARK: - User Helpers
    func fetchHouseholdMembers(for homeId: String) async throws -> [PocketBaseUser] {
        let response: PocketBaseListResponse<PocketBaseUser> = try await pocketBase.getCollection(
            "users",
            responseType: PocketBaseListResponse<PocketBaseUser>.self,
            filter: "home_id ~ '\(homeId)'"
        )
        return response.items
    }
}