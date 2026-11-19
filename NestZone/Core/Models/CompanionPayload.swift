import Foundation

/// What `companion:forHome` answers: the house's jar and scene, the one
/// growing, the newest things the house did (for its mood) and the jar's feed.
///
/// Decoded by hand where a value can arrive that this build has not heard of.
/// `recent[].kind`, `jar[].kind` and the species all grow with the server, and
/// the read is one payload: a kind added tomorrow must degrade its own row, not
/// blank the card.
public struct CompanionPayload: Decodable, Equatable, Sendable {
    /// The catalog the server prices from: its generated file's hash and the
    /// rules' version. Compared with `CatalogVersion.exported`.
    public var catalogVersion: String
    public var graduateAt: Double
    /// `nil` until the house's first write: a house that never opened Nestie.
    public var house: House?
    public var current: Current?
    /// The house or its companion arrived in a shape this build cannot read.
    /// Never to be taken for "none": a house that has a companion must not be
    /// offered a new one because one field went missing.
    public var isUnreadable: Bool
    public var recent: [Recent]
    public var jar: [JarEntry]
    /// The vote that chose (or is choosing) the one growing, if there was one.
    /// A vote this build cannot read is `nil`, not an unreadable house: the
    /// card still draws, it just has no ballot to offer.
    public var vote: CompanionVote?

    public struct House: Decodable, Equatable, Sendable {
        public var leaves: Int
        public var sparkles: Int
        public var welcomed: Bool
        public var owned: [String]
        public var ownedSpecies: [String]
        /// Species the house has grown all the way.
        public var grownSpecies: [String]
        /// `"<species>:<colour>"` for each colourway grown. Empty from a
        /// server that predates colours.
        public var grownColours: [String]
        /// When the house finished every free species; `nil` until it has.
        public var finaleAt: Date?
        public var layout: SceneLayout
        /// `nil` means the region's defaults.
        public var holidays: [String]?
        public var region: String?
        public var tzOffset: Int?
        public var albumCount: Int

        enum CodingKeys: String, CodingKey {
            case leaves, sparkles, welcomed, owned, ownedSpecies, grownSpecies, grownColours, finaleAt, layout, holidays, region
            case tzOffset, albumCount
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            leaves = c.decodeNumber(forKey: .leaves)
            sparkles = c.decodeNumber(forKey: .sparkles)
            welcomed = (try? c.decodeIfPresent(Bool.self, forKey: .welcomed)) ?? false
            owned = (try? c.decodeIfPresent([String].self, forKey: .owned)) ?? []
            ownedSpecies = (try? c.decodeIfPresent([String].self, forKey: .ownedSpecies)) ?? []
            grownSpecies = (try? c.decodeIfPresent([String].self, forKey: .grownSpecies)) ?? []
            grownColours = (try? c.decodeIfPresent([String].self, forKey: .grownColours)) ?? []
            finaleAt = ((try? c.decodeIfPresent(Double.self, forKey: .finaleAt)) ?? nil)
                .map { Date(timeIntervalSince1970: $0 / 1000) }
            layout = (try? c.decodeIfPresent(SceneLayout.self, forKey: .layout)) ?? SceneLayout()
            holidays = (try? c.decodeIfPresent([String].self, forKey: .holidays)) ?? nil
            region = (try? c.decodeIfPresent(String.self, forKey: .region)) ?? nil
            tzOffset = c.decodeNumberIfPresent(forKey: .tzOffset)
            albumCount = c.decodeNumber(forKey: .albumCount)
        }
    }

    public struct Current: Decodable, Equatable, Sendable {
        public var id: String
        public var uuid: String
        /// A species this build cannot draw is shown as the first free one
        /// rather than hiding the house's companion.
        public var species: Species
        public var seed: String
        public var startedAt: Date
        public var points: Double
        public var stage: Int
        /// The server's whole rule: the points and the days.
        public var isReady: Bool
        public var pointsReady: Bool
        /// When the days allow it.
        public var readyAt: Date?
        public var paidStage: Int
        public var lastCareAt: Date?
        /// The caller's own care days on this one, newest first, `YYYY-MM-DD`
        /// in the house's days.
        public var myCareDays: [String]
        /// The house has not chosen what this is yet: `species` is only the
        /// vote's first option, standing in. Draw a seed, never it.
        public var undecided: Bool
        /// Its colourway, 1-3; `nil` is the original.
        public var colour: Int?

        enum CodingKeys: String, CodingKey {
            case id, uuid, species, seed, startedAt, points, stage, isReady, pointsReady, readyAt, paidStage, lastCareAt, myCareDays
            case undecided, colour
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            uuid = (try? c.decodeIfPresent(String.self, forKey: .uuid)) ?? id
            species = c.decodeLenient(Species.self, forKey: .species, default: .magnolia)
            seed = try c.decode(String.self, forKey: .seed)
            startedAt = Date(timeIntervalSince1970: ((try? c.decode(Double.self, forKey: .startedAt)) ?? 0) / 1000)
            points = (try? c.decodeIfPresent(Double.self, forKey: .points)) ?? 0
            stage = c.decodeNumber(forKey: .stage)
            isReady = (try? c.decodeIfPresent(Bool.self, forKey: .isReady)) ?? false
            pointsReady = (try? c.decodeIfPresent(Bool.self, forKey: .pointsReady)) ?? isReady
            readyAt = ((try? c.decodeIfPresent(Double.self, forKey: .readyAt)) ?? nil)
                .map { Date(timeIntervalSince1970: $0 / 1000) }
            paidStage = c.decodeNumber(forKey: .paidStage)
            lastCareAt = ((try? c.decodeIfPresent(Double.self, forKey: .lastCareAt)) ?? nil)
                .map { Date(timeIntervalSince1970: $0 / 1000) }
            myCareDays = (try? c.decodeIfPresent([String].self, forKey: .myCareDays)) ?? []
            undecided = (try? c.decodeIfPresent(Bool.self, forKey: .undecided)) ?? false
            colour = Colourway.read(c.decodeNumberIfPresent(forKey: .colour))
        }
    }

    /// One thing the house did that grew the one growing.
    public struct Recent: Decodable, Equatable, Sendable {
        public var kind: Kind
        public var at: Date
        public var userID: UserID?

        public enum Kind: String, Decodable, Sendable {
            case chore, purchase, dinner, event, fix, movie, care
            /// A kind added after this build. Still something the house did.
            case other
        }

        enum CodingKeys: String, CodingKey { case kind, at, userId }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = c.decodeLenient(Kind.self, forKey: .kind, default: .other)
            at = Date(timeIntervalSince1970: ((try? c.decode(Double.self, forKey: .at)) ?? 0) / 1000)
            userID = (try? c.decodeIfPresent(UserID.self, forKey: .userId)) ?? nil
        }
    }

    /// One move in the house jar: who added, who spent.
    public struct JarEntry: Decodable, Equatable, Sendable, Identifiable {
        public var id: String
        public var kind: Kind
        public var leaves: Int
        public var sparkles: Int
        public var item: String?
        public var userID: UserID?
        public var at: Date

        public enum Kind: String, Decodable, Sendable {
            case welcome, stage, graduation, buy, `import`, topUp, refund
            case other
        }

        enum CodingKeys: String, CodingKey { case id, kind, leaves, sparkles, item, userId, at }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            kind = c.decodeLenient(Kind.self, forKey: .kind, default: .other)
            leaves = c.decodeNumber(forKey: .leaves)
            sparkles = c.decodeNumber(forKey: .sparkles)
            item = (try? c.decodeIfPresent(String.self, forKey: .item)) ?? nil
            userID = (try? c.decodeIfPresent(UserID.self, forKey: .userId)) ?? nil
            at = Date(timeIntervalSince1970: ((try? c.decode(Double.self, forKey: .at)) ?? 0) / 1000)
        }
    }

    /// One card in the album (`companion:album`).
    public struct Card: Decodable, Equatable, Sendable {
        public var uuid: String
        public var species: Species
        public var seed: String
        public var startedAt: Date
        public var graduatedAt: Date
        /// The colourway it grew in; `nil` is the original.
        public var colour: Int?

        enum CodingKeys: String, CodingKey { case uuid, species, seed, startedAt, graduatedAt, colour }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            uuid = try c.decode(String.self, forKey: .uuid)
            species = c.decodeLenient(Species.self, forKey: .species, default: .magnolia)
            seed = try c.decode(String.self, forKey: .seed)
            let started = (try? c.decode(Double.self, forKey: .startedAt)) ?? 0
            startedAt = Date(timeIntervalSince1970: started / 1000)
            graduatedAt = Date(timeIntervalSince1970: ((try? c.decode(Double.self, forKey: .graduatedAt)) ?? started) / 1000)
            colour = Colourway.read(c.decodeNumberIfPresent(forKey: .colour))
        }
    }

    enum CodingKeys: String, CodingKey { case catalogVersion, graduateAt, house, current, recent, jar, vote }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        catalogVersion = (try? c.decodeIfPresent(String.self, forKey: .catalogVersion)) ?? ""
        graduateAt = (try? c.decodeIfPresent(Double.self, forKey: .graduateAt)) ?? CompanionMath.graduateAt
        var unreadable = false
        (house, unreadable) = Self.optional(House.self, in: c, key: .house, unreadable: unreadable)
        (current, unreadable) = Self.optional(Current.self, in: c, key: .current, unreadable: unreadable)
        isUnreadable = unreadable
        recent = (try? c.decodeIfPresent(LossyList<Recent>.self, forKey: .recent))?.elements ?? []
        jar = (try? c.decodeIfPresent(LossyList<JarEntry>.self, forKey: .jar))?.elements ?? []
        vote = (try? c.decodeIfPresent(CompanionVote.self, forKey: .vote)) ?? nil
    }

    /// A field that may be null. Present and unreadable is not null.
    private static func optional<T: Decodable>(
        _ type: T.Type, in c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys, unreadable: Bool
    ) -> (T?, Bool) {
        guard c.contains(key), !((try? c.decodeNil(forKey: key)) ?? true) else { return (nil, unreadable) }
        guard let value = try? c.decode(T.self, forKey: key) else { return (nil, true) }
        return (value, unreadable)
    }

    /// The album's cards, a row at a time: one that cannot be read leaves the
    /// others.
    public struct Cards: Decodable, Equatable, Sendable {
        public var cards: [Card]

        public init(from decoder: any Decoder) throws {
            cards = try LossyList<Card>(from: decoder).elements
        }
    }
}

/// A list that keeps the rows it can read.
struct LossyList<Element: Decodable>: Decodable {
    var elements: [Element] = []

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                // A failed decode does not move on; reading it as nothing does.
                _ = try? container.decode(ConvexConnection.Discarded.self)
            }
        }
    }
}
