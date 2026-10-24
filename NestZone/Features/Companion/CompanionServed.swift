import Foundation

/// One delivery of `companion:forHome`, already in the shapes the feature
/// keeps, so the work of turning a payload into them is done off the main
/// thread (in the subscription's own task) and the reducer only compares and
/// assigns.
public struct CompanionServed: Equatable, Sendable {
    /// The house as the server says it: the jar, what is owned and out, the
    /// holidays, where it is, and the one growing. `album` is not here — the
    /// album's own subscription fills it — and nor is the Lab.
    public var house: CompanionHouse
    /// What the house did lately that grew it, for the mood. Care is not in it:
    /// the mood reads when somebody last came by from `Companion.lastCareAt`.
    public var activity: [Completion]
    /// Who added to the jar and who spent from it.
    public var jarFeed: [CompanionPayload.JarEntry]
    public var catalogVersion: String
    /// Whether the server has a row for this house at all: a house that never
    /// opened Nestie has none, and the card invites it in.
    public var hasHouse: Bool
    /// The house or its companion could not be read. The reducer keeps what it
    /// had and says so, rather than reading it as "no companion".
    public var isUnreadable: Bool

    init(
        house: CompanionHouse, activity: [Completion] = [], hasHouse: Bool = true, isUnreadable: Bool = false,
        catalogVersion: String = CatalogVersion.exported
    ) {
        self.house = house
        self.activity = activity
        jarFeed = []
        self.catalogVersion = catalogVersion
        self.hasHouse = hasHouse
        self.isUnreadable = isUnreadable
    }

    public init(_ payload: CompanionPayload) {
        var house = CompanionHouse()
        if let served = payload.house {
            house.leaves = served.leaves
            house.sparkles = served.sparkles
            house.welcomed = served.welcomed
            house.owned = Set(served.owned)
            house.ownedSpecies = Set(served.ownedSpecies)
            house.layout = served.layout
            house.holidays = served.holidays
            house.region = served.region
            house.tzOffset = served.tzOffset
            house.albumCount = served.albumCount
            house.grown = Set(served.grownSpecies.compactMap(Species.init(rawValue:)))
        }
        if let current = payload.current {
            var companion = Companion(species: current.species, seed: current.seed, startedAt: current.startedAt)
            companion.careDays = current.myCareDays
            companion.lastCareAt = current.lastCareAt
            companion.id = current.id
            companion.points = current.points
            companion.serverStage = current.stage
            companion.isReady = current.isReady
            companion.pointsReady = current.pointsReady
            companion.readyAt = current.readyAt
            companion.isUndecided = current.undecided
            house.current = companion
            house.paidStage = current.paidStage
        }
        house.vote = payload.vote
        self.house = house
        activity = payload.recent.filter { $0.kind != .care }.map { Completion(at: $0.at, by: $0.userID) }
        jarFeed = payload.jar
        catalogVersion = payload.catalogVersion
        hasHouse = payload.house != nil
        isUnreadable = payload.isUnreadable
    }

    /// Whether a phone should tell the server where the house is: when the
    /// row exists and lacks either. Never to move it — that is a person's
    /// choice, and the server has cooldowns for it.
    public var needsPlace: Bool {
        hasHouse && (house.tzOffset == nil || house.region == nil)
    }
}

extension Graduate {
    /// An album card from the server. The server keeps each companion's UUID as
    /// text; one that is not a UUID gets a stable stand-in, so the same card is
    /// the same row on every delivery.
    init(_ card: CompanionPayload.Card) {
        self.init(
            id: UUID(uuidString: card.uuid) ?? .stable(from: card.uuid),
            species: card.species, seed: card.seed, startedAt: card.startedAt, graduatedAt: card.graduatedAt
        )
    }
}

extension UUID {
    /// A UUID that is the same for the same text, for ids that were never UUIDs.
    static func stable(from text: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in text.utf8.enumerated() { bytes[index % 16] ^= byte &+ UInt8(truncatingIfNeeded: index / 16) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
