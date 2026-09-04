import Foundation

public struct ShoppingItem: Codable, Identifiable, Hashable, Sendable {
    public let id: ShoppingItemID
    public var name: String
    public var details: String?
    public var quantity: Double?
    public var isPurchased: Bool
    public var category: Category
    public var createdBy: UserID?
    public var updatedBy: UserID?
    public var homeID: HomeID?
    public var created: Timestamp?
    public var updated: Timestamp?

    public enum Category: String, Codable, CaseIterable, Sendable {
        case groceries, household, cleaning, other
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case details = "description"
        case quantity
        case isPurchased = "is_purchased"
        case category
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case homeID = "home_id"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ShoppingItemID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        details = try c.decodeIfPresent(String.self, forKey: .details)
        quantity = try c.decodeIfPresent(Double.self, forKey: .quantity)
        isPurchased = try c.decodeIfPresent(Bool.self, forKey: .isPurchased) ?? false
        category = c.decodeLenient(Category.self, forKey: .category, default: .other)
        createdBy = try c.decodeIfPresent(UserID.self, forKey: .createdBy)
        updatedBy = try c.decodeIfPresent(UserID.self, forKey: .updatedBy)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: ShoppingItemID,
        name: String,
        details: String? = nil,
        quantity: Double? = nil,
        isPurchased: Bool = false,
        category: Category = .other,
        createdBy: UserID? = nil,
        updatedBy: UserID? = nil,
        homeID: HomeID? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.quantity = quantity
        self.isPurchased = isPurchased
        self.category = category
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.homeID = homeID
        self.created = created
        self.updated = updated
    }
}
