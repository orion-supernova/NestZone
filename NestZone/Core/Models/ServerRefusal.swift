import Foundation

/// The refusals the server throws on purpose, as `ConvexError` data
/// `{ code: "BLOCKED" }`, which convex-swift hands over as a JSON string.
///
/// Each has copy of its own (`AppError.errorDescription`): they are the few
/// answers a person can do something about, unlike the server's free-text
/// messages, which stay in the log.
public enum ServerRefusal: String, Equatable, Sendable {
    case invalidReaction = "INVALID_REACTION"
    case replyElsewhere = "REPLY_ELSEWHERE"
    case notFound = "NOT_FOUND"
    /// A 1:1 with somebody either side has blocked is closed.
    case blocked = "BLOCKED"
    /// A moderator paused this person's chat. Reading still works.
    case chatSuspended = "CHAT_SUSPENDED"
    case blockLimit = "BLOCK_LIMIT"
    case forbidden = "FORBIDDEN"
    case lastMember = "LAST_MEMBER"
    case invalid = "INVALID"
    /// An invite link or QR code that cannot be used (`invites:redeem`).
    case inviteInvalid = "INVITE_INVALID"
    case inviteFull = "INVITE_FULL"
    case inviteExpired = "INVITE_EXPIRED"

    /// `nil` when the data is not one of these (a Plus refusal, a code a newer
    /// server added, plain text).
    public static func parse(convexErrorData data: String) -> ServerRefusal? {
        guard var object = json(data) else { return nil }
        // A string that is itself JSON, once more.
        if let inner = object as? String, let again = json(inner) { object = again }
        guard let dictionary = object as? [String: Any],
              let code = dictionary["code"] as? String else { return nil }
        return ServerRefusal(rawValue: code)
    }

    private static func json(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}

extension ServerRefusal {
    /// Plain words for what happened and, where there is one, what to do.
    public var copy: LocalizedStringResource {
        switch self {
        case .invalidReaction: L10n.refusalInvalidReaction
        case .replyElsewhere: L10n.refusalReplyElsewhere
        case .notFound: L10n.refusalNotFound
        case .blocked: L10n.refusalBlocked
        case .chatSuspended: L10n.refusalChatSuspended
        case .blockLimit: L10n.refusalBlockLimit
        case .forbidden: L10n.refusalForbidden
        case .lastMember: L10n.refusalLastMember
        case .invalid: L10n.refusalInvalid
        case .inviteInvalid: L10n.inviteStateInvalid
        case .inviteFull: L10n.inviteStateFull
        case .inviteExpired: L10n.inviteStateExpired
        }
    }
}
