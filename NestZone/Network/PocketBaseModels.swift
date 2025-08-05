import Foundation

struct PocketBaseErrorResponse: Codable {
    let status: Int
    let message: String
    let data: [String: String]
}

struct PocketBaseUser: Codable {
    let id: String
    let email: String
    let name: String?
    let avatar: String?
    let home_id: [String]
    let created: String
    let updated: String
    let verified: Bool
    let emailVisibility: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, avatar, created, updated, verified
        case home_id
        case emailVisibility = "emailVisibility"
    }
}

struct PocketBaseListResponse<T: Codable>: Codable {
    let page: Int
    let perPage: Int
    let totalPages: Int
    let totalItems: Int
    let items: [T]
}

// MARK: - Home Collection
struct Home: Codable, Identifiable {
    let id: String
    let name: String
    let address: GeoPoint?
    let members: [String]  // User IDs
    let inviteCode: String?
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case members
        case inviteCode = "invite_code"
        case created
        case updated
    }
}

struct GeoPoint: Codable {
    let lat: Double
    let lng: Double
    
    enum CodingKeys: String, CodingKey {
        case lat
        case lng = "lon"
    }
}

// MARK: - Task Collection
struct PocketBaseTask: Codable {
    let id: String
    let title: String
    let description: String?
    let createdBy: String?  // User ID
    let updatedBy: String?  // User ID
    let assignedTo: String?  // User ID
    let isCompleted: Bool
    let image: String?
    let homeId: String  // Related Home
    let priority: TaskPriority
    let type: TaskType
    let created: String
    let updated: String
    let dueDate: String?
    
    enum TaskType: String, Codable {
        case cleaning = "cleaning"
        case shopping = "shopping"
        case maintenance = "maintenance"
        case general = "general"
    }
    
    enum TaskPriority: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case assignedTo = "assigned_to"
        case isCompleted = "is_completed"
        case image
        case homeId = "home_id"
        case priority
        case type
        case created
        case updated
        case dueDate = "due_date"
    }
}

// MARK: - Shopping List Collection
struct ShoppingItem: Codable {
    let id: String
    let name: String
    let description: String?
    let quantity: Double?
    let isPurchased: Bool
    let category: ShoppingCategory
    let createdBy: String?  // User ID
    let updatedBy: String?  // User ID
    let homeId: String  // Related Home
    let created: String
    let updated: String
    
    enum ShoppingCategory: String, Codable, CaseIterable {
        case groceries = "groceries"
        case household = "household"
        case cleaning = "cleaning"
        case other = "other"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case quantity
        case isPurchased = "is_purchased"
        case category
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case homeId = "home_id"
        case created
        case updated
    }
}

// MARK: - Note Collection
struct PocketBaseNote: Codable, Identifiable {
    let id: String
    let description: String
    let createdBy: String?  // User ID
    let homeId: String  // Related Home
    let image: String?
    let color: String?  // Add color field
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case createdBy = "created_by"
        case homeId = "home_id"
        case image
        case color  // Add color field
        case created
        case updated
    }
}

// MARK: - Messages Collection
struct PocketBaseConversation: Codable, Identifiable {
    let id: String
    let participants: [String]  // User IDs
    let homeId: String  // Related Home
    let isGroupChat: Bool
    let title: String?
    let lastMessage: String?
    let lastMessageAt: String?
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case participants
        case homeId = "home_id"
        case isGroupChat = "is_group_chat"
        case title
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case created
        case updated
    }
}

struct PocketBaseMessage: Codable, Identifiable {
    let id: String
    let conversationId: String  // Related Conversation
    let senderId: String  // User ID
    let content: String
    let messageType: MessageType
    let image: String?
    let readBy: [String]  // User IDs who have read this message
    let created: String
    let updated: String
    
    enum MessageType: String, Codable {
        case text = "text"
        case image = "image"
        case system = "system"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case image
        case readBy = "read_by"
        case created
        case updated
    }
}

struct MessageReadStatus: Codable, Identifiable {
    let id: String
    let messageId: String
    let userId: String
    let conversationId: String
    let readAt: String
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case userId = "user_id"
        case conversationId = "conversation_id"
        case readAt = "read_at"
        case created
        case updated
    }
}

// MARK: - Expense Collection
struct Expense: Codable {
    let id: String
    let title: String
    let amount: Double
    let date: String
    let category: ExpenseCategory
    let paidBy: String  // User ID
    let splitBetween: [String]  // User IDs
    let homeId: String  // Related Home
    let created: String
    let updated: String
    
    enum ExpenseCategory: String, Codable {
        case rent = "rent"
        case utilities = "utilities"
        case groceries = "groceries"
        case household = "household"
        case other = "other"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case amount
        case date
        case category
        case paidBy = "paid_by"
        case splitBetween = "split_between"
        case homeId = "home_id"
        case created
        case updated
    }
}

// MARK: - Calendar Event Collection
struct CalendarEvent: Codable {
    let id: String
    let title: String
    let description: String?
    let startDate: String
    let endDate: String?
    let allDay: Bool
    let category: EventCategory
    let participants: [String]  // User IDs
    let homeId: String  // Related Home
    let createdBy: String  // User ID
    let created: String
    let updated: String
    
    enum EventCategory: String, Codable {
        case social = "social"
        case maintenance = "maintenance"
        case cleaning = "cleaning"
        case other = "other"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case allDay = "all_day"
        case category
        case participants
        case homeId = "home_id"
        case createdBy = "created_by"
        case created
        case updated
    }
}