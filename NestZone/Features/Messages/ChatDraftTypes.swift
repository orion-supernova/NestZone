import Foundation

/// The message the composer is answering, as a snapshot: the reply bar draws
/// it, and the bubble waiting for the server draws it in its quote block.
public struct ReplyQuote: Equatable, Sendable {
    public var messageID: MessageID
    public var senderID: UserID
    public var snippet: String
    public var kind: Message.Kind

    /// What the server will echo back on the sent message.
    public var reply: MessageReply {
        MessageReply(messageID: messageID, senderID: senderID, snippet: snippet, kind: kind)
    }
}

/// Somebody picked from the `@` list. Kept with the name that was typed, so
/// the id is sent only if that name is still in the text.
public struct Mention: Equatable, Sendable {
    public var userID: UserID
    public var name: String
}

/// A reaction the person just chose that the server has not shown back yet.
public struct ReactionIntent: Hashable, Sendable {
    public var messageID: MessageID
    public var emoji: String
}

/// A pin or an unpin the person just chose that the server has not shown back
/// yet.
public enum PinIntent: Equatable, Sendable {
    case pin(PinnedMessage)
    case unpin
}

/// The pin the thread showed when a pin write was answered.
public struct PinSettle: Equatable, Sendable {
    public var pin: PinnedMessage?
}
