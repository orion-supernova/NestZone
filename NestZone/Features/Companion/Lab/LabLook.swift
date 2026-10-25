import Foundation

/// What the card is told to pretend it looks like, and nothing else: a mood,
/// a day and hour, a birthday, a hemisphere, a colourway. It changes how the
/// house is drawn and is never sent anywhere, so it is safe on the real house.
///
/// The Lab (Debug builds only) is the one thing that sets it. Release builds
/// compile this type because the reducer reads it, and it is empty there for
/// good: there is no storage behind it.
public struct LabLook: Codable, Equatable, Sendable {
    /// Pretend the house has been like this, whatever it has done.
    public var mood: Mood?
    /// Pretend it is this day and hour: to see a holiday arrive, or dusk.
    public var date: Date?
    /// Pretend somebody's birthday is today, for the party hat.
    public var birthday = false
    /// Pretend the house is in this region, for the hemisphere (the seasons,
    /// the holidays' dates, the snow that is left out south of the equator).
    public var region: String?
    /// Draw the one growing in this colourway, 1-3, whatever it holds.
    public var colour: Int?

    public init() {}

    /// Whether anything is pretended.
    public var isActive: Bool { self != LabLook() }

    /// Whether what is pretended changes what the house can have or celebrate
    /// (the day, the region). A write worked out from the drawn house would
    /// then be worked out from a house that is not the real one, so the
    /// reducer does not make those writes while it holds.
    public var changesTheWorld: Bool { date != nil || region != nil }

    enum CodingKeys: String, CodingKey { case mood, date, birthday, region, colour }

    /// Lenient, like every file this app keeps: a key a later build adds, or an
    /// older Lab file's coins and points, must not make it unreadable.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mood = try? c.decodeIfPresent(Mood.self, forKey: .mood)
        date = try? c.decodeIfPresent(Date.self, forKey: .date)
        birthday = (try? c.decodeIfPresent(Bool.self, forKey: .birthday)) ?? false
        region = (try? c.decodeIfPresent(String.self, forKey: .region)) ?? nil
        colour = Colourway.read((try? c.decodeIfPresent(Int.self, forKey: .colour)) ?? nil)
    }
}
