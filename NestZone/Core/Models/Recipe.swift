import Foundation

public struct Recipe: Codable, Identifiable, Hashable, Sendable {
    public let id: RecipeID
    public var title: String
    public var summary: String?
    public var ingredients: [String]
    public var steps: [String]
    public var tags: [String]
    public var prepTime: Int?
    public var cookTime: Int?
    public var servings: Int?
    public var difficulty: Difficulty?
    public var image: String?
    public var homeID: HomeID?
    public var createdBy: UserID?
    public var created: Timestamp?
    public var updated: Timestamp?

    public enum Difficulty: String, Codable, CaseIterable, Sendable {
        case easy, medium, hard
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case summary = "description"
        case ingredients, steps, tags
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case servings, difficulty, image
        case homeID = "home_id"
        case createdBy = "created_by"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(RecipeID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        ingredients = try c.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        prepTime = try c.decodeIfPresent(Int.self, forKey: .prepTime)
        cookTime = try c.decodeIfPresent(Int.self, forKey: .cookTime)
        servings = try c.decodeIfPresent(Int.self, forKey: .servings)
        difficulty = (try? c.decodeIfPresent(String.self, forKey: .difficulty))
            .flatMap { Difficulty(rawValue: $0) }
        image = try c.decodeIfPresent(String.self, forKey: .image)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        createdBy = try c.decodeIfPresent(UserID.self, forKey: .createdBy)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: RecipeID,
        title: String,
        summary: String? = nil,
        ingredients: [String] = [],
        steps: [String] = [],
        tags: [String] = [],
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        servings: Int? = nil,
        difficulty: Difficulty? = nil,
        image: String? = nil,
        homeID: HomeID? = nil,
        createdBy: UserID? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
        self.tags = tags
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.difficulty = difficulty
        self.image = image
        self.homeID = homeID
        self.createdBy = createdBy
        self.created = created
        self.updated = updated
    }
}

extension Recipe {
    /// Prep + cook, when either is known.
    public var totalMinutes: Int? {
        switch (prepTime, cookTime) {
        case let (p?, c?): p + c
        case let (p?, nil): p
        case let (nil, c?): c
        case (nil, nil): nil
        }
    }
}
