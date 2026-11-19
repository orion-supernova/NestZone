import ComposableArchitecture
import Foundation

/// Whether the open house has NestZone Plus, as the server last said.
///
/// Held in memory and shared, because every gate in the app reads it and none
/// of them may reach into another feature for it. Written by one reducer
/// (`ProStatusFeature`) and read by the rest; the server stays the only judge,
/// this is what the screens draw from.
public struct ProStatus: Equatable, Sendable {
    /// The server has answered at least once for this house.
    public var isLoaded = false
    /// Whether Plus is on *now*: the server's answer, and not past its end.
    /// True until the server has answered, so a gate never flashes shut on a
    /// house that has Plus while the first answer is on its way.
    public var isPro = true
    /// Whether the server refuses Plus writes yet (`PRO_ENFORCE`).
    public var enforced = false
    public var carrier: Carrier?
    public var expiresAt: Date?
    public var willRenew: Bool?
    /// The person looking is the one paying.
    public var mine = false
    /// Which homes this person's own Plus covers and how many it may. Only
    /// the person who pays hears it, and an older server says nothing.
    public var coverage: Coverage?

    public static let unknown = ProStatus()

    /// Whether this person may make a second home without asking for Plus:
    /// only the person who pays for Plus themselves (a house that is covered
    /// by somebody else's does not carry over to a home of their own). True
    /// until the server has answered, so nothing locks mid-load.
    public var allowsAnotherHome: Bool { !isLoaded || (isPro && mine) }

    /// Whoever's subscription covers the house.
    public struct Carrier: Equatable, Sendable {
        public var id: UserID
        public var name: String?
    }

    public struct Coverage: Equatable, Sendable {
        public var limit: Int
        public var homeIDs: [HomeID]
    }

    public init() {}

    /// Reads the server's answer. `now` is compared against the end date as
    /// well, because the live query can lag the clock by hours.
    public init(_ payload: ProStatusPayload, now: Date) {
        isLoaded = true
        enforced = payload.enforced
        carrier = payload.carriedBy.map { Carrier(id: $0.id, name: $0.name) }
        expiresAt = payload.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) }
        willRenew = payload.willRenew
        mine = payload.mine
        coverage = payload.coverage.map { Coverage(limit: $0.limit, homeIDs: $0.homeIds) }
        isPro = payload.pro && (expiresAt.map { $0 > now } ?? true)
    }
}

/// `pro:status`, as it arrives. Nulls rather than missing keys.
public struct ProStatusPayload: Codable, Equatable, Sendable {
    public var pro: Bool
    public var enforced: Bool
    public var carriedBy: Carrier?
    public var expiresAt: Double?
    public var willRenew: Bool?
    public var mine: Bool
    /// Absent from older servers and from callers who do not carry Plus
    /// themselves; read leniently, so a shape this build does not know is
    /// "no coverage" and never a failed status.
    public var coverage: Coverage?

    public struct Coverage: Codable, Equatable, Sendable {
        public var limit: Int
        public var homeIds: [HomeID]

        public init(limit: Int, homeIds: [HomeID]) {
            self.limit = limit
            self.homeIds = homeIds
        }
    }

    public struct Carrier: Codable, Equatable, Sendable {
        public var id: UserID
        public var name: String?

        public init(id: UserID, name: String? = nil) {
            self.id = id
            self.name = name
        }
    }

    public init(
        pro: Bool,
        enforced: Bool = false,
        carriedBy: Carrier? = nil,
        expiresAt: Double? = nil,
        willRenew: Bool? = nil,
        mine: Bool = false,
        coverage: Coverage? = nil
    ) {
        self.pro = pro
        self.enforced = enforced
        self.carriedBy = carriedBy
        self.expiresAt = expiresAt
        self.willRenew = willRenew
        self.mine = mine
        self.coverage = coverage
    }

    private enum CodingKeys: String, CodingKey {
        case pro, enforced, carriedBy, expiresAt, willRenew, mine, coverage
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pro = try c.decode(Bool.self, forKey: .pro)
        enforced = try c.decode(Bool.self, forKey: .enforced)
        carriedBy = try c.decodeIfPresent(Carrier.self, forKey: .carriedBy)
        expiresAt = try c.decodeIfPresent(Double.self, forKey: .expiresAt)
        willRenew = try c.decodeIfPresent(Bool.self, forKey: .willRenew)
        mine = try c.decode(Bool.self, forKey: .mine)
        coverage = (try? c.decodeIfPresent(Coverage.self, forKey: .coverage)) ?? nil
    }
}

extension ProStatus {
    /// "Your Plus covers 2 of 2 homes: Bizim Ev, Yazlık", only for the person
    /// who pays and only when the server said. Homes the app cannot name are
    /// left out of the names but still counted.
    func coverageLine(homeNames: [HomeID: String]) -> LocalizedStringResource? {
        guard isPro, mine, let coverage else { return nil }
        let names = coverage.homeIDs.compactMap { homeNames[$0] }.filter { !$0.isEmpty }
        let count = coverage.homeIDs.count
        guard !names.isEmpty else { return L10n.plusCoverageCount(count, coverage.limit) }
        return L10n.plusCoverage(count, coverage.limit, names.joined(separator: ", "))
    }
}

/// `pro:refresh`'s answer.
public struct ProRefreshResult: Codable, Equatable, Sendable {
    public var active: Bool
    public var expiresAt: Double?

    public init(active: Bool, expiresAt: Double? = nil) {
        self.active = active
        self.expiresAt = expiresAt
    }
}

extension SharedKey where Self == InMemoryKey<ProStatus>.Default {
    /// The open house's Plus standing. Reset on sign-out.
    public static var pro: Self {
        Self[.inMemory("proStatus"), default: .unknown]
    }
}

/// The refusal the server throws for a Plus write: `ConvexError` data
/// `{ code: "PRO_REQUIRED", feature }`, which convex-swift hands over as a JSON
/// string.
public enum ProRefusal {
    /// `nil` when this is not a Plus refusal; `.some(nil)` when it is one for a
    /// feature this build has no name for.
    public static func feature(inConvexErrorData data: String) -> ProFeature?? {
        guard var object = parse(data) else { return nil }
        // A string that is itself JSON, once more.
        if let inner = object as? String, let again = parse(inner) { object = again }
        guard let dictionary = object as? [String: Any],
              dictionary["code"] as? String == "PRO_REQUIRED" else { return nil }
        return .some(ProFeature(serverName: dictionary["feature"] as? String))
    }

    private static func parse(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
