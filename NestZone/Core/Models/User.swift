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
    ///
    /// The identity of the photo, and what a write names. Not an address: only
    /// the server can turn one of these into a request, which is what
    /// `avatarURL` is for.
    public var avatar: String?
    /// Where the avatar can actually be loaded from, resolved server-side.
    ///
    /// Both halves are carried for the reason `IssuePhoto` carries both: a
    /// signed storage URL is not required to contain the id it was signed for,
    /// so neither one can be worked back out of the other. `nil` covers three
    /// cases the screen treats identically — no photo was ever set, the file
    /// has been deleted out from under the document, or this payload came from
    /// a server too old to resolve it. All three draw initials.
    public var avatarURL: URL?
    /// Every home this user belongs to.
    public var homeIDs: [HomeID]
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, avatar
        case avatarURL = "avatar_url"
        case homeIDs = "home_id"
        case created, updated
    }

    public init(
        id: UserID,
        name: String? = nil,
        email: String? = nil,
        avatar: String? = nil,
        avatarURL: URL? = nil,
        homeIDs: [HomeID] = [],
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatar = avatar
        self.avatarURL = avatarURL
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
        // Lenient on purpose, like every enum in this app: a URL the phone
        // cannot parse degrades this one field to "no photo" rather than
        // throwing and blanking the whole household list.
        avatarURL = (try? c.decodeIfPresent(String.self, forKey: .avatarURL))
            .flatMap { $0.flatMap(URL.init(string:)) }
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
