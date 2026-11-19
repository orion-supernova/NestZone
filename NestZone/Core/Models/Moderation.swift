import Foundation

public enum ReportsTable {}
public typealias ReportID = ConvexID<ReportsTable>

/// What can be reported (App Store guideline 1.2).
public enum ReportKind: String, Codable, Sendable {
    case message, issuePhoto, avatar
}

/// The reasons the report sheet offers, in the order it lists them.
public enum ReportReason: String, CaseIterable, Codable, Identifiable, Sendable {
    case abuse, harassment, sexual, spam, other

    public var id: String { rawValue }
}

/// How `moderation:report` answered. Whatever it is, the thing is hidden from
/// the reporter.
public enum ReportOutcome: String, Equatable, Sendable {
    /// A report was filed.
    case filed
    /// The same thing was already reported by this person and is still open.
    case already
    /// Twenty reports today: hidden for them, nothing filed.
    case limited
}

/// What `moderation:report` is asked about. `issueID` goes with a problem
/// photo, `homeID` with a face.
public struct ReportSubject: Equatable, Sendable {
    public var kind: ReportKind
    public var targetID: String
    public var issueID: IssueID?
    public var homeID: HomeID?

    public init(kind: ReportKind, targetID: String, issueID: IssueID? = nil, homeID: HomeID? = nil) {
        self.kind = kind
        self.targetID = targetID
        self.issueID = issueID
        self.homeID = homeID
    }
}

/// Something this person reported and so no longer sees: a problem photo (by
/// storage id) or a face (by user id). Messages are left out by the server.
public struct HiddenItem: Decodable, Equatable, Sendable {
    public var kind: ReportKind
    public var targetID: String

    enum CodingKeys: String, CodingKey {
        case kind
        case targetID = "target_id"
    }

    public init(kind: ReportKind, targetID: String) {
        self.kind = kind
        self.targetID = targetID
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = c.decodeLenient(ReportKind.self, forKey: .kind, default: .message)
        targetID = try c.decode(String.self, forKey: .targetID)
    }
}

/// Somebody this person has blocked.
public struct BlockedPerson: Decodable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UserID
    public var name: String?
    public var avatarURL: URL?
    public var created: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case name
        case avatarURL = "avatar_url"
        case created
    }

    public init(id: UserID, name: String? = nil, avatarURL: URL? = nil, created: Timestamp? = nil) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.created = created
    }

    /// A person who has since left or been deleted has no name to show.
    public var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        return String(localized: L10n.avatarSomeone)
    }

    public var initials: String { User.initials(from: displayName) }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UserID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        avatarURL = (try? c.decodeIfPresent(String.self, forKey: .avatarURL)).flatMap { URL(string: $0) }
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
    }
}

// MARK: - The moderators' queue

public enum ReportStatus: String, Codable, Sendable {
    case open, dismissed, actioned
}

/// One line of the queue.
public struct ReportRow: Decodable, Identifiable, Equatable, Hashable, Sendable {
    public var id: ReportID
    public var kind: ReportKind
    public var reason: ReportReason
    public var status: ReportStatus
    public var created: Timestamp
    public var note: String?
    public var homeName: String?
    public var reporterName: String?
    public var targetUserID: UserID?
    public var targetUserName: String?
    /// The reported text, cut to 200 characters; the photo's title otherwise.
    public var preview: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case kind, reason, status, created, note, preview
        case homeName = "home_name"
        case reporterName = "reporter_name"
        case targetUserID = "target_user_id"
        case targetUserName = "target_user_name"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ReportID.self, forKey: .id)
        kind = c.decodeLenient(ReportKind.self, forKey: .kind, default: .message)
        reason = c.decodeLenient(ReportReason.self, forKey: .reason, default: .other)
        status = c.decodeLenient(ReportStatus.self, forKey: .status, default: .open)
        created = try c.decode(Timestamp.self, forKey: .created)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        preview = try c.decodeIfPresent(String.self, forKey: .preview)
        homeName = try c.decodeIfPresent(String.self, forKey: .homeName)
        reporterName = try c.decodeIfPresent(String.self, forKey: .reporterName)
        targetUserID = try c.decodeIfPresent(UserID.self, forKey: .targetUserID)
        targetUserName = try c.decodeIfPresent(String.self, forKey: .targetUserName)
    }
}

/// A page of open reports, newest first.
public struct ReportPage: Decodable, Equatable, Sendable {
    public var rows: [ReportRow]
    public var isDone: Bool
    public var cursor: String?

    enum CodingKeys: String, CodingKey {
        case rows = "page"
        case isDone
        case cursor = "continueCursor"
    }
}

/// What was reported, as it stood when it was.
public struct ReportSnapshot: Decodable, Equatable, Sendable {
    public var text: String?
    public var messageKind: Message.Kind?
    public var issueTitle: String?
    public var userName: String?

    enum CodingKeys: String, CodingKey {
        case text
        case messageKind = "message_type"
        case issueTitle = "issue_title"
        case userName = "user_name"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        messageKind = c.decodeLenientIfPresent(Message.Kind.self, forKey: .messageKind)
        issueTitle = try c.decodeIfPresent(String.self, forKey: .issueTitle)
        userName = try c.decodeIfPresent(String.self, forKey: .userName)
    }
}

/// One report in full, and where things stand now.
public struct ReportDetail: Decodable, Equatable, Sendable {
    public var report: ReportRow
    public var snapshot: ReportSnapshot
    /// The reported picture, if there is one (a photo, a face, a message's image).
    public var fileURL: URL?
    public var stillExists: Bool
    public var targetInHome: Bool
    public var targetChatSuspended: Bool
    public var resolvedByName: String?
    public var resolvedAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case report, snapshot
        case fileURL = "file_url"
        case stillExists = "still_exists"
        case targetInHome = "target_in_home"
        case targetChatSuspended = "target_chat_suspended"
        case resolvedByName = "resolved_by_name"
        case resolvedAt = "resolved_at"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        report = try c.decode(ReportRow.self, forKey: .report)
        snapshot = try c.decode(ReportSnapshot.self, forKey: .snapshot)
        fileURL = (try? c.decodeIfPresent(String.self, forKey: .fileURL)).flatMap { URL(string: $0) }
        stillExists = try c.decodeIfPresent(Bool.self, forKey: .stillExists) ?? false
        targetInHome = try c.decodeIfPresent(Bool.self, forKey: .targetInHome) ?? false
        targetChatSuspended = try c.decodeIfPresent(Bool.self, forKey: .targetChatSuspended) ?? false
        resolvedByName = try c.decodeIfPresent(String.self, forKey: .resolvedByName)
        resolvedAt = try c.decodeIfPresent(Timestamp.self, forKey: .resolvedAt)
    }
}
