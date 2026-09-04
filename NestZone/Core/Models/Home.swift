import Foundation

/// A shared household. Everything else in the app hangs off one of these.
public struct Home: Codable, Identifiable, Hashable, Sendable {
    public let id: HomeID
    public var name: String
    public var address: HomeAddress?
    public var members: [UserID]
    public var inviteCode: String?
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, address, members
        case inviteCode = "invite_code"
        case created, updated
    }

    public init(
        id: HomeID,
        name: String,
        address: HomeAddress? = nil,
        members: [UserID] = [],
        inviteCode: String? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.members = members
        self.inviteCode = inviteCode
        self.created = created
        self.updated = updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(HomeID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        address = try c.decodeIfPresent(HomeAddress.self, forKey: .address)
        members = try c.decodeIfPresent([UserID].self, forKey: .members) ?? []
        inviteCode = try c.decodeIfPresent(String.self, forKey: .inviteCode)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }
}

public struct HomeAddress: Codable, Hashable, Sendable {
    public var lat: Double
    public var lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}
