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
    /// Set when the item came from a recipe. The title travels with it so the
    /// list can head a group without subscribing to recipes, and still reads
    /// correctly after the recipe itself is gone.
    public var recipeID: RecipeID?
    public var recipeTitle: String?
    /// Set when the item is on the list *for* something in the calendar — the
    /// ice for Saturday. Same denormalised title as the recipe link above, and
    /// for the same reason: a group heading must survive the event being
    /// deleted, and must not cost the list a second subscription.
    public var eventID: EventID?
    public var eventTitle: String?
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
        case recipeID = "recipe_id"
        case recipeTitle = "recipe_title"
        case eventID = "event_id"
        case eventTitle = "event_title"
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
        recipeID = try c.decodeIfPresent(RecipeID.self, forKey: .recipeID)
        recipeTitle = try c.decodeIfPresent(String.self, forKey: .recipeTitle)
        eventID = try c.decodeIfPresent(EventID.self, forKey: .eventID)
        eventTitle = try c.decodeIfPresent(String.self, forKey: .eventTitle)
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
        recipeID: RecipeID? = nil,
        recipeTitle: String? = nil,
        eventID: EventID? = nil,
        eventTitle: String? = nil,
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
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.eventID = eventID
        self.eventTitle = eventTitle
        self.created = created
        self.updated = updated
    }
}
