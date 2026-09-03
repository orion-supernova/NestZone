//
//  ConvexModels.swift
//  NestZone
//
//  Codable DTOs for the Convex backend. Replaces PocketBaseModels.swift.
//
//  Convex conventions (see Docs/Convex-Migration/iOS-Migration-Guide.md §5):
//  - Document id is `_id` (not `id`); `id` is exposed as a computed alias.
//  - `created` / `updated` / `*_at` are epoch-MS numbers (Double), not ISO strings.
//    Convert with `Date(timeIntervalSince1970: ms / 1000)`.
//  - Relation fields are plain `String` ids (or arrays of them); pass them straight
//    back to mutations as args.
//  - Field names deliberately keep the PocketBase names (home_id, sender_id, …).
//

import Foundation

extension Date {
    /// Convex stores timestamps as epoch-milliseconds (Double).
    init(convexMillis ms: Double) { self.init(timeIntervalSince1970: ms / 1000) }
    var convexMillis: Double { timeIntervalSince1970 * 1000 }
}

/// The signed-in user's profile (from `users:me`).
struct NZUser: Codable, Identifiable, Equatable {
    let _id: String
    var id: String { _id }
    let name: String?
    let email: String?
    /// Array of home `_id`s the user belongs to.
    let home_id: [String]?
    let avatar: String?
    let created: Double?
    let updated: Double?
}

/// A shared household. Keeps the type name `Home` (used widely across views) but
/// decodes the Convex shape: `_id`, numeric timestamps, and `invite_code`.
struct Home: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let address: HomeAddress?
    let members: [String]   // user `_id`s
    let inviteCode: String?
    let created: Double?
    let updated: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case address
        case members
        case inviteCode = "invite_code"
        case created
        case updated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        address = try c.decodeIfPresent(HomeAddress.self, forKey: .address)
        members = (try c.decodeIfPresent([String].self, forKey: .members)) ?? []
        inviteCode = try c.decodeIfPresent(String.self, forKey: .inviteCode)
        created = try c.decodeIfPresent(Double.self, forKey: .created)
        updated = try c.decodeIfPresent(Double.self, forKey: .updated)
    }

    // Memberwise init for any local construction / previews.
    init(id: String, name: String, address: HomeAddress? = nil, members: [String] = [],
         inviteCode: String? = nil, created: Double? = nil, updated: Double? = nil) {
        self.id = id; self.name = name; self.address = address; self.members = members
        self.inviteCode = inviteCode; self.created = created; self.updated = updated
    }
}

struct HomeAddress: Codable, Equatable {
    let lat: Double
    let lng: Double
}
