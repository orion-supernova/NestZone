import Foundation

/// What the household is doing about dinner on a given day.
///
/// Dinner is a decision before it is a dish, so a plan is one of three shapes:
/// cook something, order it in, or go out. Only `cook` carries a recipe, and it
/// travels with the plan rather than being looked up client-side — the Home tab
/// shows tonight without subscribing to the whole recipe collection, and can
/// open it straight from the card. The server drops a cook plan whose recipe has
/// been deleted, so `recipe` is never a dangling pointer.
public struct MealPlan: Codable, Identifiable, Hashable, Sendable {
    public let id: MealPlanID
    public var homeID: HomeID?
    public var kind: Kind
    public var recipe: Recipe?
    /// A meal nobody wrote down — leftovers, a family dish. Set instead of
    /// `recipe` on a cook plan.
    public var title: String?
    public var cuisine: Cuisine?
    /// Where from, when anyone has decided. Free text: a takeaway's name is not
    /// something the app should pretend to have a list of.
    public var place: String?
    /// `YYYY-MM-DD` in the household's own reckoning — dinner is a calendar
    /// day, not an instant. Compared against `MealDate.today`.
    public var date: String
    public var plannedBy: UserID?
    public var created: Timestamp?
    public var updated: Timestamp?

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case cook, order, out
    }

    /// What to put on a card for this plan.
    public var headline: String? {
        switch kind {
        case .cook: recipe?.title ?? title
        case .order, .out:
            place?.isEmpty == false ? place : nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case homeID = "home_id"
        case kind, recipe, title, cuisine, place, date
        case plannedBy = "planned_by"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(MealPlanID.self, forKey: .id)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        kind = c.decodeLenient(Kind.self, forKey: .kind, default: .cook)
        recipe = try c.decodeIfPresent(Recipe.self, forKey: .recipe)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        cuisine = c.decodeLenientIfPresent(Cuisine.self, forKey: .cuisine)
        place = try c.decodeIfPresent(String.self, forKey: .place)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        plannedBy = try c.decodeIfPresent(UserID.self, forKey: .plannedBy)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: MealPlanID,
        homeID: HomeID? = nil,
        kind: Kind,
        recipe: Recipe? = nil,
        title: String? = nil,
        cuisine: Cuisine? = nil,
        place: String? = nil,
        date: String,
        plannedBy: UserID? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.homeID = homeID
        self.kind = kind
        self.recipe = recipe
        self.title = title
        self.cuisine = cuisine
        self.place = place
        self.date = date
        self.plannedBy = plannedBy
        self.created = created
        self.updated = updated
    }
}

/// The kitchens worth choosing between when nobody is cooking.
///
/// A closed list rather than free text: it is what the "what are we eating"
/// round votes on, and two people typing "thai" and "Thai" must not become two
/// candidates. `place` stays free text for the actual restaurant.
public enum Cuisine: String, Codable, CaseIterable, Identifiable, Sendable {
    case turkish, italian, chinese, japanese, indian, mexican
    case thai, mediterranean, american, korean, seafood, other

    public var id: String { rawValue }

    /// Emoji rather than SF Symbols: there is no `fork.knife.indian`, and a row
    /// of identical cutlery glyphs would tell a person nothing.
    public var emoji: String {
        switch self {
        case .turkish: "🥙"
        case .italian: "🍝"
        case .chinese: "🥡"
        case .japanese: "🍣"
        case .indian: "🍛"
        case .mexican: "🌮"
        case .thai: "🍜"
        case .mediterranean: "🥗"
        case .american: "🍔"
        case .korean: "🍲"
        case .seafood: "🦐"
        case .other: "🍽️"
        }
    }
}

/// The calendar-day keys a meal plan is stored under.
public enum MealDate {
    /// `YYYY-MM-DD` for a date in the device's own calendar. Deliberately not
    /// UTC: at 9pm in Istanbul, UTC is still yesterday, and "tonight's dinner"
    /// would point at the wrong day for half the evening.
    public static func key(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        )
    }

    public static var today: String { key() }
}
