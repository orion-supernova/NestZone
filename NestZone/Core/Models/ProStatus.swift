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

    public static let unknown = ProStatus()

    /// Whoever's subscription covers the house.
    public struct Carrier: Equatable, Sendable {
        public var id: UserID
        public var name: String?
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
        mine: Bool = false
    ) {
        self.pro = pro
        self.enforced = enforced
        self.carriedBy = carriedBy
        self.expiresAt = expiresAt
        self.willRenew = willRenew
        self.mine = mine
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
