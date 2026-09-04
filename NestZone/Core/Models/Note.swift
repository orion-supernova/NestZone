import Foundation

public struct Note: Codable, Identifiable, Hashable, Sendable {
    public let id: NoteID
    public var body: String
    public var createdBy: UserID?
    public var homeID: HomeID?
    public var image: String?
    /// Colour chosen in the composer. Stored as a **name** (`"yellow"`,
    /// `"purple"`, …) — that is what every note already in the database holds,
    /// so writing hex here would break the ones that predate this app version.
    /// `StickyColor` reads both, and writes names.
    public var color: String?
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case body = "description"
        case createdBy = "created_by"
        case homeID = "home_id"
        case image
        case color
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(NoteID.self, forKey: .id)
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        createdBy = try c.decodeIfPresent(UserID.self, forKey: .createdBy)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: NoteID,
        body: String,
        createdBy: UserID? = nil,
        homeID: HomeID? = nil,
        image: String? = nil,
        color: String? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.body = body
        self.createdBy = createdBy
        self.homeID = homeID
        self.image = image
        self.color = color
        self.created = created
        self.updated = updated
    }
}

extension Note {
    /// First line, for the collapsed card. Notes have no title field.
    public var headline: String {
        body.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
    }
}
