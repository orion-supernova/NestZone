import Foundation

/// One person's one reaction to a message.
public struct MessageReaction: Codable, Hashable, Sendable {
    public var emoji: String
    public var userID: UserID

    enum CodingKeys: String, CodingKey {
        case emoji
        case userID = "user_id"
    }

    public init(emoji: String, userID: UserID) {
        self.emoji = emoji
        self.userID = userID
    }
}

/// The six reactions, spelled exactly as the server's allow-list spells them
/// (`backend/convex/lib/chat.ts`). The heart carries its variation selector.
public enum ReactionEmoji {
    public static let all: [String] = [
        "\u{1F44D}",         // thumbs up
        "\u{2764}\u{FE0F}",  // red heart
        "\u{1F602}",         // laughing
        "\u{1F62E}",         // surprised
        "\u{1F622}",         // crying
        "\u{1F64F}",         // folded hands
    ]
}

/// A reaction as the row under a bubble draws it: one emoji, how many people
/// chose it, and whether one of them is me.
public struct ReactionTally: Identifiable, Equatable, Sendable {
    public var emoji: String
    public var count: Int
    public var isMine: Bool

    public var id: String { emoji }

    /// Groups reactions by emoji, in the order the picker lists them (anything
    /// else after, in the order it arrived), so a chip does not jump about as
    /// people react.
    public static func tally(_ reactions: [MessageReaction], me: UserID?) -> [ReactionTally] {
        guard !reactions.isEmpty else { return [] }
        var counts: [String: (count: Int, mine: Bool)] = [:]
        var arrival: [String] = []
        for reaction in reactions {
            if counts[reaction.emoji] == nil { arrival.append(reaction.emoji) }
            var entry = counts[reaction.emoji] ?? (0, false)
            entry.count += 1
            if reaction.userID == me { entry.mine = true }
            counts[reaction.emoji] = entry
        }
        let known = ReactionEmoji.all.filter { counts[$0] != nil }
        let rest = arrival.filter { !ReactionEmoji.all.contains($0) }
        return (known + rest).compactMap { emoji in
            counts[emoji].map { ReactionTally(emoji: emoji, count: $0.count, isMine: $0.mine) }
        }
    }
}

/// What a reply quotes, copied by the server when the reply was sent. If the
/// original is deleted later the quote stays; the thread just cannot jump to it.
public struct MessageReply: Codable, Hashable, Sendable {
    public var messageID: MessageID
    public var senderID: UserID
    public var snippet: String
    /// Lets the quote say "Photo" in the reader's language.
    public var kind: Message.Kind?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case senderID = "sender_id"
        case snippet
        case kind = "message_type"
    }

    public init(messageID: MessageID, senderID: UserID, snippet: String, kind: Message.Kind? = nil) {
        self.messageID = messageID
        self.senderID = senderID
        self.snippet = snippet
        self.kind = kind
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messageID = try c.decode(MessageID.self, forKey: .messageID)
        senderID = try c.decodeIfPresent(UserID.self, forKey: .senderID) ?? ""
        snippet = try c.decodeIfPresent(String.self, forKey: .snippet) ?? ""
        kind = c.decodeLenientIfPresent(Message.Kind.self, forKey: .kind)
    }
}

/// A conversation's one pinned message, as a snapshot.
public struct PinnedMessage: Codable, Hashable, Sendable {
    public var messageID: MessageID
    public var senderID: UserID?
    public var snippet: String
    public var kind: Message.Kind?
    public var pinnedBy: UserID?
    public var pinnedAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case senderID = "sender_id"
        case snippet
        case kind = "message_type"
        case pinnedBy = "pinned_by"
        case pinnedAt = "pinned_at"
    }

    public init(
        messageID: MessageID,
        senderID: UserID? = nil,
        snippet: String,
        kind: Message.Kind? = nil,
        pinnedBy: UserID? = nil,
        pinnedAt: Timestamp? = nil
    ) {
        self.messageID = messageID
        self.senderID = senderID
        self.snippet = snippet
        self.kind = kind
        self.pinnedBy = pinnedBy
        self.pinnedAt = pinnedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messageID = try c.decode(MessageID.self, forKey: .messageID)
        senderID = try c.decodeIfPresent(UserID.self, forKey: .senderID)
        snippet = try c.decodeIfPresent(String.self, forKey: .snippet) ?? ""
        kind = c.decodeLenientIfPresent(Message.Kind.self, forKey: .kind)
        pinnedBy = try c.decodeIfPresent(UserID.self, forKey: .pinnedBy)
        pinnedAt = try c.decodeIfPresent(Timestamp.self, forKey: .pinnedAt)
    }
}
