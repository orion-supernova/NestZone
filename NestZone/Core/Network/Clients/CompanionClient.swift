import ComposableArchitecture
import ConvexMobile
import Foundation

/// The house's companion (Nestie) on the server: `companion:*` and `shop:buy`.
///
/// One live read carries the whole card (`forHome`), the album has its own
/// (`album`, opened with its sheet), and every write is a call that answers
/// with what it did. The calls do not retry: a write that failed changed
/// nothing, and the reducer that sent it owns putting its screen back.
@DependencyClient
public struct CompanionClient: Sendable {
    public var forHome: @Sendable (HomeID) -> AsyncThrowingStream<CompanionPayload, any Error> = { _ in .never }
    /// The album's cards, oldest first. Read only while the album is shown.
    public var album: @Sendable (HomeID) -> AsyncThrowingStream<CompanionPayload.Cards, any Error> = { _ in .never }

    /// Tells the server where the house is. Only fills what it lacks or moves
    /// it on purpose: the server has cooldowns, and a phone travelling is not
    /// the house moving. `true` when something changed.
    public var setPlace: @Sendable (HomeID, Place) async throws -> Bool
    /// Starts growing one. One that is ready graduates first, in the same
    /// write (`graduated` says so); one that is not is let go. `requestID` is
    /// the tap's own, so a retry after a lost answer is the same start.
    public var start: @Sendable (HomeID, Species, Place, _ requestID: String) async throws -> StartOutcome
    /// Water or pet it. `true` when it counted as today's care.
    public var care: @Sendable (HomeID) async throws -> Bool
    /// The ceremony's end. The coins the graduation paid, or `nil` when it had
    /// already been paid.
    public var graduate: @Sendable (HomeID, _ companionID: String) async throws -> Coins?
    /// Decorate's Done. Answers with what the server kept.
    public var setLayout: @Sendable (HomeID, SceneLayout) async throws -> SceneLayout
    /// Our holidays; `nil` goes back to the region's defaults.
    public var setHolidays: @Sendable (HomeID, [String]?) async throws -> [String]?
    /// One test phone's MVP file, offered once. Only admin and test accounts
    /// are let in; anybody else gets `.closed`.
    public var importLocal: @Sendable (HomeID, LocalCompanion, Place) async throws -> ImportOutcome
    /// Buys one thing for the house. `requestID` is the tap's own, so a retry
    /// with it is the same purchase; `expected` is the price the card showed.
    public var buy: @Sendable (HomeID, ShopItem, _ requestID: String, _ expected: Price) async throws -> BuyOutcome
}

/// Where a phone says the house is: minutes east of UTC and a two-letter region.
public struct Place: Equatable, Sendable {
    public var tzOffset: Int
    public var region: String?

    public init(tzOffset: Int, region: String?) {
        self.tzOffset = tzOffset
        self.region = region
    }

    /// This phone's, now.
    public static func current(region: String? = Locale.current.region?.identifier) -> Place {
        Place(tzOffset: TimeZone.current.secondsFromGMT() / 60, region: region)
    }
}

public struct StartOutcome: Equatable, Sendable {
    public var companionID: String
    /// The welcome gift that came with the house's first, once.
    public var welcome: Coins?
    /// The ready companion this start graduated first, if there was one.
    public var graduated: GraduatedCompanion?

    public init(companionID: String, welcome: Coins? = nil, graduated: GraduatedCompanion? = nil) {
        self.companionID = companionID
        self.welcome = welcome
        self.graduated = graduated
    }
}

/// A companion that a start graduated, and what that paid (`nil` when it had
/// been paid already, as on a retry).
public struct GraduatedCompanion: Equatable, Sendable {
    public var companionID: String
    public var species: Species
    public var paid: Coins?

    public init(companionID: String, species: Species, paid: Coins?) {
        self.companionID = companionID
        self.species = species
        self.paid = paid
    }
}

/// How a purchase ended. The server answers every outcome the card has a
/// screen for as a status, not an error; a status this build does not know is
/// `.unavailable`, because nothing was shown to have been bought.
public enum BuyOutcome: Equatable, Sendable {
    /// In the house. `paid` and `madeUp` are the server's own sum, `jar` what
    /// is left (`nil` if the answer did not say), and `replay` says this
    /// answered a retry of one already made.
    case bought(paid: Coins, madeUp: Int?, jar: Coins?, replay: Bool)
    /// The house already had it, from this phone or another.
    case owned
    /// Not enough, even with the Sparkles that make up Leaves.
    case short(sparkles: Int, price: Price)
    /// Not to be had today.
    case unavailable
    /// The catalog says another price than the card showed. Nothing was spent.
    case priceChanged(Price)
}

public enum ImportOutcome: Equatable, Sendable {
    case imported
    case already
    case closed
}

extension CompanionClient: DependencyKey {
    public static let liveValue = CompanionClient(
        forHome: { homeID in
            ConvexConnection.shared.subscribe(
                to: "companion:forHome", args: ["homeId": homeID], as: CompanionPayload.self
            )
        },
        album: { homeID in
            ConvexConnection.shared.subscribe(
                to: "companion:album", args: ["homeId": homeID], as: CompanionPayload.Cards.self
            )
        },
        setPlace: { homeID, place in
            try await ConvexConnection.shared.mutate(
                "companion:setPlace", args: .setPlace(homeID, place), as: Changed.self
            ).changed
        },
        start: { homeID, species, place, requestID in
            let started = try await ConvexConnection.shared.mutate(
                "companion:start", args: .start(homeID, species, place, requestID), as: Started.self
            )
            return StartOutcome(
                companionID: started.companionId, welcome: started.welcome?.coins,
                graduated: started.graduated.map {
                    GraduatedCompanion(
                        companionID: $0.companionId, species: Species(rawValue: $0.species) ?? .magnolia,
                        paid: $0.paid?.coins
                    )
                }
            )
        },
        care: { homeID in
            try await ConvexConnection.shared.mutate("companion:care", args: ["homeId": homeID], as: Counted.self).counted
        },
        graduate: { homeID, companionID in
            try await ConvexConnection.shared.mutate(
                "companion:graduate", args: ["homeId": homeID, "companionId": companionID], as: Graduated.self
            ).paid?.coins
        },
        setLayout: { homeID, layout in
            try await ConvexConnection.shared.mutate(
                "companion:setLayout", args: .setLayout(homeID, layout), as: SceneLayout.self
            )
        },
        setHolidays: { homeID, holidays in
            // `null` is a value here — back to the region's days — so the key
            // is always sent.
            try await ConvexConnection.shared.mutate(
                "companion:setHolidays",
                args: ["homeId": homeID, "holidays": holidays.map { $0.map { $0 as ConvexEncodable? } }],
                as: [String]?.self
            )
        },
        importLocal: { homeID, local, place in
            let answer = try await ConvexConnection.shared.mutate(
                "companion:importLocal", args: .importLocal(homeID, local, place), as: Imported.self
            )
            return switch answer.status {
            case "imported": .imported
            case "already": .already
            default: .closed
            }
        },
        buy: { homeID, item, requestID, expected in
            let args: [String: ConvexEncodable?] = [
                "homeId": homeID,
                "item": item.arguments,
                "requestId": requestID,
                "expectedPrice": expected.arguments,
            ]
            return try await ConvexConnection.shared.mutate("shop:buy", args: args, as: Bought.self).outcome
        }
    )

    public static let testValue = CompanionClient()
}

extension DependencyValues {
    public var companion: CompanionClient {
        get { self[CompanionClient.self] }
        set { self[CompanionClient.self] = newValue }
    }
}

// MARK: - Arguments

/// What each write sends, built apart from the calls so that its shape can be
/// read (and tested) without a server: the server validates strictly, and an
/// argument it did not expect rejects the whole request.
extension Dictionary where Key == String, Value == ConvexEncodable? {
    static func setPlace(_ homeID: HomeID, _ place: Place) -> Self {
        var args = place.arguments
        args["homeId"] = homeID
        return args
    }

    static func start(_ homeID: HomeID, _ species: Species, _ place: Place, _ requestID: String) -> Self {
        var args = place.arguments
        args["homeId"] = homeID
        args["species"] = species.rawValue
        args["requestId"] = requestID
        return args
    }

    static func setLayout(_ homeID: HomeID, _ layout: SceneLayout) -> Self {
        ["homeId": homeID, "layout": layout.arguments]
    }

    static func importLocal(_ homeID: HomeID, _ local: LocalCompanion, _ place: Place) -> Self {
        var args = local.arguments
        args.merge(place.arguments) { _, new in new }
        args["homeId"] = homeID
        return args
    }
}


extension Place {
    /// Both keys are optional on the server: a region of `nil` is left out.
    var arguments: [String: ConvexEncodable?] {
        var args: [String: ConvexEncodable?] = ["tzOffset": tzOffset.convexNumber]
        if let region { args["region"] = region }
        return args
    }
}

extension ShopItem {
    fileprivate var arguments: [String: ConvexEncodable?] {
        switch self {
        case let .decor(decor): ["kind": "decor", "id": decor.rawValue]
        case let .species(species): ["kind": "species", "id": species.rawValue]
        case let .pack(pack): ["kind": "pack", "id": pack.rawValue]
        }
    }
}

extension Price {
    fileprivate var arguments: [String: ConvexEncodable?] {
        switch self {
        case let .leaves(amount): ["currency": "leaves", "amount": amount.convexNumber]
        case let .sparkles(amount): ["currency": "sparkles", "amount": amount.convexNumber]
        }
    }

    fileprivate init?(currency: String, amount: Int) {
        switch currency {
        case "leaves": self = .leaves(amount)
        case "sparkles": self = .sparkles(amount)
        default: return nil
        }
    }
}

extension SceneLayout {
    /// Every spot is sent, empty ones as `null`: that is how the server hears
    /// "nothing here" (a missing key would be "not mentioned").
    var arguments: [String: ConvexEncodable?] {
        var args: [String: ConvexEncodable?] = ["tree": tree.map { $0 as ConvexEncodable? }]
        for spot in Spot.allCases where spot != .tree {
            // `updateValue`, not a subscript: assigning a nil through the
            // subscript would delete the key instead of storing the null.
            let thing: ConvexEncodable? = self[spot]
            args.updateValue(thing, forKey: spot.rawValue)
        }
        return args
    }
}

extension LocalCompanion {
    /// What the MVP's file offers. No Sparkles, by decision: the MVP's were
    /// free tests and the server would not take them anyway. Fields the file
    /// does not have are left out, because a `null` is not "absent" for the
    /// server's optional numbers and arrays.
    var arguments: [String: ConvexEncodable?] {
        var args: [String: ConvexEncodable?] = [
            "leaves": leaves.convexNumber,
            "welcomed": welcomed,
            "owned": owned.sorted().map { $0 as ConvexEncodable? },
            "ownedSpecies": ownedSpecies.sorted().map { $0 as ConvexEncodable? },
            "layout": layout.arguments,
            "paidStage": paidStage.convexNumber,
            "album": album.map { card -> ConvexEncodable? in
                [
                    "id": card.id.uuidString,
                    "species": card.species.rawValue,
                    "seed": card.seed,
                    "startedAt": card.startedAt.convexMillis,
                    "graduatedAt": card.graduatedAt.convexMillis,
                ] as [String: ConvexEncodable?]
            },
        ]
        if let current {
            args["current"] = [
                "species": current.species.rawValue,
                "seed": current.seed,
                "startedAt": current.startedAt.convexMillis,
                "careDays": current.careDays.map { $0 as ConvexEncodable? },
            ] as [String: ConvexEncodable?]
        }
        if let holidays { args["holidays"] = holidays.map { $0 as ConvexEncodable? } }
        return args
    }
}

// MARK: - Answers

private struct Changed: Decodable, Sendable { var changed: Bool }
private struct Counted: Decodable, Sendable { var counted: Bool }

/// `{ leaves, sparkles }`, which is what the server calls some coins.
private struct WireCoins: Decodable, Sendable {
    var leaves: Int
    var sparkles: Int

    var coins: Coins { Coins(leaves: leaves, sparkles: sparkles) }

    enum CodingKeys: String, CodingKey { case leaves, sparkles }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        leaves = c.decodeNumber(forKey: .leaves)
        sparkles = c.decodeNumber(forKey: .sparkles)
    }
}

private struct Started: Decodable, Sendable {
    var companionId: String
    var welcome: WireCoins?
    var graduated: WireGraduated?
}

private struct WireGraduated: Decodable, Sendable {
    var companionId: String
    var species: String
    var paid: WireCoins?
}

private struct Graduated: Decodable, Sendable {
    var paid: WireCoins?
}

private struct Imported: Decodable, Sendable {
    var status: String
}

/// The answer to `shop:buy`, whichever of the five it is.
private struct Bought: Decodable, Sendable {
    var outcome: BuyOutcome

    enum CodingKeys: String, CodingKey { case status, paid, madeUp, jar, replay, sparkles, price }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let status = (try? c.decode(String.self, forKey: .status)) ?? ""
        let price = (try? c.decodeIfPresent(WirePrice.self, forKey: .price))?.price
        outcome = switch status {
        case "bought":
            .bought(
                paid: (try? c.decode(WireCoins.self, forKey: .paid))?.coins ?? Coins(leaves: 0, sparkles: 0),
                madeUp: c.decodeNumberIfPresent(forKey: .madeUp),
                jar: (try? c.decodeIfPresent(WireCoins.self, forKey: .jar))?.coins,
                replay: (try? c.decodeIfPresent(Bool.self, forKey: .replay)) ?? false
            )
        case "owned":
            .owned
        case "short":
            if let price { .short(sparkles: c.decodeNumber(forKey: .sparkles), price: price) } else { .unavailable }
        case "priceChanged":
            if let price { .priceChanged(price) } else { .unavailable }
        default:
            .unavailable
        }
    }
}

private struct WirePrice: Decodable, Sendable {
    var price: Price?

    enum CodingKeys: String, CodingKey { case currency, amount }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        price = Price(currency: (try? c.decode(String.self, forKey: .currency)) ?? "", amount: c.decodeNumber(forKey: .amount))
    }
}
