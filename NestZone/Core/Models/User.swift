import Foundation

/// A NestZone account.
///
/// This replaces the two structs the app used to decode the *same* `users` table
/// into — `NZUser` for the signed-in profile and `PocketBaseUser` for everyone
/// else — which had drifted apart in optionality and field coverage.
public struct User: Codable, Identifiable, Hashable, Sendable {
    public let id: UserID
    public var name: String?
    public var email: String?
    /// `_storage` id of the avatar, when one has been uploaded.
    public var avatar: String?
    /// Every home this user belongs to.
    public var homeIDs: [HomeID]
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, avatar
        case homeIDs = "home_id"
        case created, updated
    }

    public init(
        id: UserID,
        name: String? = nil,
        email: String? = nil,
        avatar: String? = nil,
        homeIDs: [HomeID] = [],
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatar = avatar
        self.homeIDs = homeIDs
        self.created = created
        self.updated = updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UserID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar)
        homeIDs = try c.decodeIfPresent([HomeID].self, forKey: .homeIDs) ?? []
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }
}

extension User {
    /// What to show wherever a person is named. Never empty: falls back through
    /// the email local-part before giving up, because Apple only supplies a name
    /// on a user's *first* authorization and most accounts therefore have none.
    public var displayName: String { Self.displayName(name: name, email: email) }

    /// Up to two letters for an avatar placeholder.
    public var initials: String { Self.initials(from: displayName) }

    /// The same rules, for the places that hold a name and an email but not a
    /// whole `User` — `MemberContribution`, whose rows come from the stats query
    /// rather than from `users:byIds`. Both sides have to agree, or the same
    /// person is labelled differently on two screens.
    public static func displayName(name: String?, email: String?) -> String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        if let local = email?.split(separator: "@").first, !local.isEmpty { return String(local) }
        return String(localized: "user.fallbackName", defaultValue: "Someone")
    }

    public static func initials(from displayName: String) -> String {
        let parts = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        return parts.isEmpty ? "?" : String(parts).uppercased()
    }
}
