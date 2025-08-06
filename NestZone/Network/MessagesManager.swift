import Foundation

@MainActor
class MessagesManager {
    static let shared = MessagesManager()
    private let pocketBase = PocketBaseManager.shared
    private init() {}
    
    // MARK: - Conversations
    func fetchConversations(for homeId: String) async throws -> [PocketBaseConversation] {
        print("DEBUG: Fetching conversations with filter: home_id = '\(homeId)'")
        
        let response: PocketBaseListResponse<PocketBaseConversation> = try await pocketBase.getCollection(
            "conversations",
            responseType: PocketBaseListResponse<PocketBaseConversation>.self,
            filter: "home_id = '\(homeId)'",
            sort: "-last_message_at,-updated"
        )
        
        print("DEBUG: Raw conversation response:")
        for (index, conversation) in response.items.enumerated() {
            print("DEBUG: Conversation \(index): id=\(conversation.id)")
            print("DEBUG:   - title: '\(conversation.title ?? "nil")'")
            print("DEBUG:   - last_message: '\(conversation.lastMessage ?? "nil")'")
            print("DEBUG:   - last_message_at: '\(conversation.lastMessageAt ?? "nil")'")
            print("DEBUG:   - updated: '\(conversation.updated)'")
        }
        
        return response.items
    }
    
    func createConversation(
        participants: [String],
        homeId: String,
        title: String? = nil,
        isGroupChat: Bool = false
    ) async throws -> PocketBaseConversation {
        print("DEBUG: Creating conversation with data:")
        print("  - participants: \(participants)")
        print("  - homeId: \(homeId)")
        print("  - title: \(title ?? "nil")")
        print("  - isGroupChat: \(isGroupChat)")
        
        let data: [String: Any] = [
            "participants": participants,
            "home_id": homeId,
            "is_group_chat": isGroupChat,
            "title": title ?? ""
        ]
        
        let conversation = try await pocketBase.createRecord(
            in: "conversations",
            data: data,
            responseType: PocketBaseConversation.self
        )
        
        print("DEBUG: Conversation created successfully: \(conversation.id)")
        return conversation
    }
    
    func updateConversationLastMessage(
        conversationId: String,
        lastMessage: String,
        timestamp: String
    ) async throws -> PocketBaseConversation {
        print("DEBUG: Updating conversation \(conversationId)")
        print("DEBUG: Setting last_message to: '\(lastMessage)'")
        print("DEBUG: Setting last_message_at to: '\(timestamp)'")
        
        let data: [String: Any] = [
            "last_message": lastMessage,
            "last_message_at": timestamp
        ]
        
        print("DEBUG: Update data: \(data)")
        
        let updatedConversation = try await pocketBase.updateRecord(
            in: "conversations",
            id: conversationId,
            data: data,
            responseType: PocketBaseConversation.self
        )
        
        print("DEBUG: Conversation updated successfully")
        print("DEBUG: New last_message: '\(updatedConversation.lastMessage ?? "nil")'")
        print("DEBUG: New last_message_at: '\(updatedConversation.lastMessageAt ?? "nil")'")
        
        return updatedConversation
    }
    
    // MARK: - Messages
    func fetchMessages(for conversationId: String) async throws -> [PocketBaseMessage] {
        do {
            // Use the correct field name that matches PocketBase schema
            let filter = "conversation_id='\(conversationId)'"
            
            print("DEBUG: Fetching messages with filter: \(filter)")
            
            // Explicitly fetch up to 500 messages to avoid pagination issues
            // This prevents missing messages that would be on other pages
            let response: PocketBaseListResponse<PocketBaseMessage> = try await pocketBase.getCollection(
                "messages",
                responseType: PocketBaseListResponse<PocketBaseMessage>.self,
                filter: filter,
                sort: "created"
            )
            
            print("DEBUG: Successfully fetched \(response.items.count) messages")
            print("DEBUG: Total items available: \(response.totalItems)")
            
            // If there are more items than we fetched, we need to fetch all pages
            // For simplicity, let's increase the page size to reduce chances of misses
            if response.totalItems > response.items.count {
                print("DEBUG: There are more messages than fetched, fetching with larger page size")
                
                // Make a second request with perPage parameter to get more messages
                let largeResponse: PocketBaseListResponse<PocketBaseMessage> = try await pocketBase.request(
                    endpoint: "/api/collections/messages/records?filter=\(filter)&sort=created&perPage=500",
                    requiresAuth: true,
                    responseType: PocketBaseListResponse<PocketBaseMessage>.self
                )
                
                print("DEBUG: Fetched \(largeResponse.items.count) messages with larger page size")
                return largeResponse.items
            }
            
            return response.items
        } catch {
            print("DEBUG: Error fetching messages: \(error)")
            // If messages collection doesn't exist or is empty, return empty array
            if let pocketBaseError = error as? PocketBaseManager.PocketBaseError,
               case .badRequest = pocketBaseError {
                print("DEBUG: Messages collection might not exist yet, returning empty array")
                return []
            }
            throw error
        }
    }
    
    func sendMessage(
        conversationId: String,
        senderId: String,
        content: String,
        messageType: PocketBaseMessage.MessageType = .text,
        file: String? = nil
    ) async throws -> PocketBaseMessage {
        print("DEBUG: Sending message with data:")
        print("  - conversationId: \(conversationId)")
        print("  - senderId: \(senderId)")
        print("  - content: \(content)")
        print("  - messageType: \(messageType.rawValue)")
        print("  - file: \(file ?? "none")")
        
        // Use the correct field name that matches PocketBase schema
        var data: [String: Any] = [
            "conversation_id": conversationId,
            "sender_id": senderId,
            "content": content,
            "message_type": messageType.rawValue,
            "read_by": [senderId] // Sender automatically reads their own message
        ]
        
        // Add file if provided
        if let file = file {
            data["file"] = file
        }
        
        print("DEBUG: Creating message with data: \(data)")
        
        let message = try await pocketBase.createRecord(
            in: "messages",
            data: data,
            responseType: PocketBaseMessage.self
        )
        
        print("DEBUG: Message created successfully: \(message.id)")
        
        // Update conversation's last message with appropriate preview text
        let previewText = getMessagePreview(content: content, messageType: messageType)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        print("DEBUG: Updating conversation last message with preview: '\(previewText)'")
        print("DEBUG: Using timestamp: '\(timestamp)'")
        
        // Make sure this completes successfully
        try await updateConversationLastMessage(
            conversationId: conversationId,
            lastMessage: previewText,
            timestamp: timestamp
        )
        
        print("DEBUG: Conversation update completed")
        
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
        do {
            // Use the correct field name that matches PocketBase schema
            let filter = "conversation_id='\(conversationId)'"
            
            print("DEBUG: Getting unread messages with filter: \(filter)")
            
            let response: PocketBaseListResponse<PocketBaseMessage> = try await pocketBase.getCollection(
                "messages",
                responseType: PocketBaseListResponse<PocketBaseMessage>.self,
                filter: filter
            )
            
            // Filter locally to avoid complex PocketBase queries
            let unreadMessages = response.items.filter { message in
                message.senderId != userId && !message.readBy.contains(userId)
            }
            
            print("DEBUG: Found \(unreadMessages.count) unread messages out of \(response.items.count) total")
            return unreadMessages.count
        } catch {
            print("DEBUG: Error getting unread count: \(error)")
            // If the query fails (e.g., no messages collection exists yet), return 0
            return 0
        }
    }
    
    // MARK: - User Helpers
    func fetchHouseholdMembers(for homeId: String) async throws -> [PocketBaseUser] {
        // First get the home to see the member IDs
        let home: Home = try await pocketBase.request(
            endpoint: "/api/collections/homes/records/\(homeId)",
            requiresAuth: true,
            responseType: Home.self
        )
        
        guard !home.members.isEmpty else {
            return []
        }
        
        // Fetch each user individually to avoid query syntax issues
        var users: [PocketBaseUser] = []
        
        for memberId in home.members {
            do {
                let user: PocketBaseUser = try await pocketBase.request(
                    endpoint: "/api/collections/users/records/\(memberId)",
                    requiresAuth: true,
                    responseType: PocketBaseUser.self
                )
                users.append(user)
            } catch {
                // If we can't fetch a specific user, just skip them
                // This handles cases where a user might have been deleted but still in home.members
                continue
            }
        }
        
        return users
    }
    
    // MARK: - Debug / Test Functions
    func testMessagesCollection() async {
        do {
            print("DEBUG: Testing if messages collection exists...")
            
            // Try to get any messages (even if empty)
            let response: PocketBaseListResponse<PocketBaseMessage> = try await pocketBase.getCollection(
                "messages",
                responseType: PocketBaseListResponse<PocketBaseMessage>.self
            )
            
            print("DEBUG: Messages collection exists! Total items: \(response.totalItems)")
            
        } catch {
            print("DEBUG: Messages collection test failed: \(error)")
            print("DEBUG: This might mean the messages collection doesn't exist in PocketBase yet")
            print("DEBUG: You may need to create it manually in the PocketBase admin interface")
        }
    }
    
    // Helper function to generate appropriate preview text for different message types
    private func getMessagePreview(content: String, messageType: PocketBaseMessage.MessageType) -> String {
        switch messageType {
        case .text:
            return content
        case .image:
            return "📷 Photo"
        case .video:
            return "🎥 Video"
        case .gif:
            return "🎞️ GIF"
        case .document:
            return "📄 Document"
        case .audio:
            return "🎵 Audio"
        case .system:
            return content
        }
    }
}