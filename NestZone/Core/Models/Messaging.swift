import Foundation

public struct Conversation: Codable, Identifiable, Hashable, Sendable {
    public let id: ConversationID
    public var participants: [UserID]
    public var homeID: HomeID?
    public var isGroupChat: Bool
    public var title: String?
    public var lastMessage: String?
    public var lastMessageAt: Timestamp?
    /// The one message pinned to the top of the thread, as a snapshot.
    public var pinned: PinnedMessage?
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
        case pinned
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
        // A pin this build cannot read costs the pin bar, not the list.
        pinned = try? c.decodeIfPresent(PinnedMessage.self, forKey: .pinned)
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
        pinned: PinnedMessage? = nil,
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
        self.pinned = pinned
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
    /// One row per person per emoji. Empty for a message nobody reacted to.
    public var reactions: [MessageReaction]
    /// What this message answers, copied when it was sent.
    public var replyTo: MessageReply?
    /// People it names, in the thread.
    public var mentions: [UserID]
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
        case reactions
        case replyTo = "reply_to"
        case mentions
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
        // The chat MVP's fields are all optional on the wire, and a thread is
        // decoded as one array: one that cannot be read degrades to "none"
        // rather than blanking every message.
        reactions = (try? c.decodeIfPresent([MessageReaction].self, forKey: .reactions)) ?? []
        replyTo = try? c.decodeIfPresent(MessageReply.self, forKey: .replyTo)
        mentions = (try? c.decodeIfPresent([UserID].self, forKey: .mentions)) ?? []
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
        reactions: [MessageReaction] = [],
        replyTo: MessageReply? = nil,
        mentions: [UserID] = [],
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
        self.reactions = reactions
        self.replyTo = replyTo
        self.mentions = mentions
        self.created = created
        self.updated = updated
    }
}

extension Message {
    public func isRead(by user: UserID) -> Bool { readBy.contains(user) }
}
