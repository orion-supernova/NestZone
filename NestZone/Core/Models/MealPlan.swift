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
    /// The calendar event this meal belongs to — Saturday's dinner party
    /// rather than Saturday's dinner.
    ///
    /// Read through by the server, so the Home tab can name the occasion and
    /// open it — with its budget, its shopping and its menu — without
    /// subscribing to the calendar at all.
    public var event: LinkedEvent?
    public var plannedBy: UserID?
    public var created: Timestamp?
    public var updated: Timestamp?

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case cook, order, out
    }

    /// Just enough of the event to head a card and open it.
    public struct LinkedEvent: Codable, Hashable, Sendable, Identifiable {
        public let id: EventID
        public var title: String
        public var kind: EventKind

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case title, kind
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(EventID.self, forKey: .id)
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            kind = c.decodeLenient(EventKind.self, forKey: .kind, default: .general)
        }

        public init(id: EventID, title: String, kind: EventKind = .dinnerParty) {
            self.id = id
            self.title = title
            self.kind = kind
        }
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
        case kind, recipe, title, cuisine, place, date, event
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
        event = try c.decodeIfPresent(LinkedEvent.self, forKey: .event)
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
        event: LinkedEvent? = nil,
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
        self.event = event
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

    /// The date a `YYYY-MM-DD` key names, in the device's own calendar.
    ///
    /// The inverse of `key`, and the reason it is here rather than at a call
    /// site: a meal key is a *calendar day* with no time and no zone on it, and
    /// parsing one with a `DateFormatter` set to UTC — the obvious mistake — puts
    /// half the world's evenings on the day before.
    public static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(
            year: parts[0], month: parts[1], day: parts[2]
        ))
    }

    /// The time of day from `time`, on the day `key` names.
    ///
    /// A time picker edits a whole `Date`, and the date half of it drifts to
    /// whenever the picker was seeded. Only the clock face is meant, so only the
    /// clock face is taken.
    public static func at(_ time: Date, on key: String, calendar: Calendar = .current) -> Date {
        let day = date(key, calendar: calendar) ?? calendar.startOfDay(for: time)
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: clock.hour ?? 19,
            minute: clock.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }

    /// 7pm on the day a key names, which is when a household eats.
    ///
    /// A meal plan has no time on it — dinner is a day, not an instant — so
    /// turning one into a calendar event has to invent one. Seven is the least
    /// wrong guess, and the composer is one tap away for a household that eats
    /// at nine.
    public static func eveningOf(_ key: String, calendar: Calendar = .current) -> Date {
        let day = date(key, calendar: calendar) ?? calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .hour, value: 19, to: day) ?? day
    }
}
