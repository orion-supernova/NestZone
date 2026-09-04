import Foundation

public struct Conversation: Codable, Identifiable, Hashable, Sendable {
    public let id: ConversationID
    public var participants: [UserID]
    public var homeID: HomeID?
    public var isGroupChat: Bool
    public var title: String?
    public var lastMessage: String?
    public var lastMessageAt: Timestamp?
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case participants
        case homeID = "home_id"
        case isGroupChat = "is_group_chat"
        case title
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ConversationID.self, forKey: .id)
        participants = try c.decodeIfPresent([UserID].self, forKey: .participants) ?? []
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        isGroupChat = try c.decodeIfPresent(Bool.self, forKey: .isGroupChat) ?? false
        title = try c.decodeIfPresent(String.self, forKey: .title)
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage)
        lastMessageAt = try c.decodeIfPresent(Timestamp.self, forKey: .lastMessageAt)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: ConversationID,
        participants: [UserID] = [],
        homeID: HomeID? = nil,
        isGroupChat: Bool = false,
        title: String? = nil,
        lastMessage: String? = nil,
        lastMessageAt: Timestamp? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.participants = participants
        self.homeID = homeID
        self.isGroupChat = isGroupChat
        self.title = title
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.created = created
        self.updated = updated
    }
}

extension Conversation {
    /// Everyone in the thread except me — what a 1:1 chat is titled by.
    public func counterparts(excluding me: UserID?) -> [UserID] {
        participants.filter { $0 != me }
    }
}

public struct Message: Codable, Identifiable, Hashable, Sendable {
    public let id: MessageID
    public var conversationID: ConversationID?
    public var senderID: UserID
    public var content: String
    public var kind: Kind
    public var file: String?
    public var readBy: [UserID]
    public var created: Timestamp?
    public var updated: Timestamp?

    public enum Kind: String, Codable, Sendable {
        case text, image, video, gif, document, audio, system
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case content
        case kind = "message_type"
        case file
        case readBy = "read_by"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(MessageID.self, forKey: .id)
        conversationID = try c.decodeIfPresent(ConversationID.self, forKey: .conversationID)
        senderID = try c.decodeIfPresent(UserID.self, forKey: .senderID) ?? ""
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        kind = c.decodeLenient(Kind.self, forKey: .kind, default: .text)
        file = try c.decodeIfPresent(String.self, forKey: .file)
        readBy = try c.decodeIfPresent([UserID].self, forKey: .readBy) ?? []
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: MessageID,
        conversationID: ConversationID? = nil,
        senderID: UserID,
        content: String,
        kind: Kind = .text,
        file: String? = nil,
        readBy: [UserID] = [],
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.content = content
        self.kind = kind
        self.file = file
        self.readBy = readBy
        self.created = created
        self.updated = updated
    }
}

extension Message {
    public func isRead(by user: UserID) -> Bool { readBy.contains(user) }
}
