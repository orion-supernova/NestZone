import Foundation

struct PocketBaseErrorResponse: Codable {
    let status: Int
    let message: String
    let data: [String: String]
}

// Convex shape: _id, optional profile fields, numeric ms timestamps. (Type name kept
// for source compatibility across the app; no longer PocketBase-specific.)
struct PocketBaseUser: Codable {
    let id: String
    let email: String?
    let name: String?
    let avatar: String?
    let home_id: [String]
    let created: Double?
    let updated: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, name, avatar, home_id, created, updated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar)
        home_id = (try c.decodeIfPresent([String].self, forKey: .home_id)) ?? []
        created = try c.decodeIfPresent(Double.self, forKey: .created)
        updated = try c.decodeIfPresent(Double.self, forKey: .updated)
    }

    // Memberwise init for local construction / previews.
    init(id: String, email: String? = nil, name: String? = nil, avatar: String? = nil,
         home_id: [String] = [], created: Double? = nil, updated: Double? = nil) {
        self.id = id; self.email = email; self.name = name; self.avatar = avatar
        self.home_id = home_id; self.created = created; self.updated = updated
    }
}

struct PocketBaseListResponse<T: Codable>: Codable {
    let page: Int
    let perPage: Int
    let totalPages: Int
    let totalItems: Int
    let items: [T]
}

// NOTE: `Home` and `GeoPoint` moved to Network/Convex/ConvexModels.swift (Convex shape).

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
    let homeId: String?  // Related Home
    let priority: TaskPriority
    let type: TaskType
    let created: Double?
    let updated: Double?
    let dueDate: Double?
    
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
        case id = "_id"
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
    let homeId: String?  // Related Home
    let created: Double?
    let updated: Double?

    enum ShoppingCategory: String, Codable, CaseIterable {
        case groceries = "groceries"
        case household = "household"
        case cleaning = "cleaning"
        case other = "other"
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
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

// MARK: - Note Collection (Convex shape: _id, numeric ms timestamps)
struct PocketBaseNote: Codable, Identifiable {
    let id: String
    let description: String
    let createdBy: String?  // User ID
    let homeId: String?  // Related Home
    let image: String?
    let color: String?
    let created: Double?
    let updated: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case description
        case createdBy = "created_by"
        case homeId = "home_id"
        case image
        case color
        case created
        case updated
    }
}

// MARK: - Messages Collection
struct PocketBaseConversation: Codable, Identifiable, Hashable {
    let id: String
    let participants: [String]  // User IDs
    let homeId: String?  // Related Home
    let isGroupChat: Bool
    let title: String?
    let lastMessage: String?
    let lastMessageAt: Double?
    let created: Double?
    let updated: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case participants
        case homeId = "home_id"
        case isGroupChat = "is_group_chat"
        case title
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case created
        case updated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        participants = (try c.decodeIfPresent([String].self, forKey: .participants)) ?? []
        homeId = try c.decodeIfPresent(String.self, forKey: .homeId)
        isGroupChat = (try c.decodeIfPresent(Bool.self, forKey: .isGroupChat)) ?? false
        title = try c.decodeIfPresent(String.self, forKey: .title)
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage)
        lastMessageAt = try c.decodeIfPresent(Double.self, forKey: .lastMessageAt)
        created = try c.decodeIfPresent(Double.self, forKey: .created)
        updated = try c.decodeIfPresent(Double.self, forKey: .updated)
    }

    // Memberwise init for previews / local construction.
    init(id: String, participants: [String], homeId: String?, isGroupChat: Bool,
         title: String? = nil, lastMessage: String? = nil, lastMessageAt: Double? = nil,
         created: Double? = nil, updated: Double? = nil) {
        self.id = id; self.participants = participants; self.homeId = homeId
        self.isGroupChat = isGroupChat; self.title = title; self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt; self.created = created; self.updated = updated
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PocketBaseConversation, rhs: PocketBaseConversation) -> Bool {
        return lhs.id == rhs.id
    }
}

struct PocketBaseMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String?  // Related Conversation
    let senderId: String  // User ID
    let content: String
    let messageType: MessageType
    let file: String?  // Can be image, video, gif, document, etc.
    let readBy: [String]  // User IDs who have read this message
    let created: Double?
    let updated: Double?

    enum MessageType: String, Codable {
        case text = "text"
        case image = "image"
        case video = "video"
        case gif = "gif"
        case document = "document"
        case audio = "audio"
        case system = "system"
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case file = "file"
        case readBy = "read_by"
        case created
        case updated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        conversationId = try c.decodeIfPresent(String.self, forKey: .conversationId)
        senderId = (try c.decodeIfPresent(String.self, forKey: .senderId)) ?? ""
        content = (try c.decodeIfPresent(String.self, forKey: .content)) ?? ""
        messageType = (try c.decodeIfPresent(MessageType.self, forKey: .messageType)) ?? .text
        file = try c.decodeIfPresent(String.self, forKey: .file)
        readBy = (try c.decodeIfPresent([String].self, forKey: .readBy)) ?? []
        created = try c.decodeIfPresent(Double.self, forKey: .created)
        updated = try c.decodeIfPresent(Double.self, forKey: .updated)
    }

    // Memberwise init for previews / local construction.
    init(id: String, conversationId: String?, senderId: String, content: String,
         messageType: MessageType, file: String?, readBy: [String],
         created: Double? = nil, updated: Double? = nil) {
        self.id = id; self.conversationId = conversationId; self.senderId = senderId
        self.content = content; self.messageType = messageType; self.file = file
        self.readBy = readBy; self.created = created; self.updated = updated
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PocketBaseMessage, rhs: PocketBaseMessage) -> Bool { lhs.id == rhs.id }
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

// MARK: - Recipes Collection
struct Recipe: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let ingredients: [String]?
    let steps: [String]?
    let tags: [String]?
    let prepTime: Int?
    let cookTime: Int?
    let servings: Int?
    let difficulty: Difficulty?
    let image: String?
    let homeId: String?
    let createdBy: String?
    let created: Double?
    let updated: Double?

    enum Difficulty: String, Codable, CaseIterable {
        case easy = "easy"
        case medium = "medium"
        case hard = "hard"
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case description
        case ingredients
        case steps
        case tags
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case servings
        case difficulty
        case image
        case homeId = "home_id"
        case createdBy = "created_by"
        case created
        case updated
    }
}