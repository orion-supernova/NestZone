import Foundation

/// A house invite the phone just asked for (`invites:create`). The token is
/// returned once and never again: only its hash is kept on the server, so this
/// value is the only place it exists.
public struct HomeInvite: Equatable, Sendable, Decodable {
    public let token: String
    public let url: URL
    public let expiresAt: Date
    /// `nil` is unlimited.
    public let maxUses: Int?

    enum CodingKeys: String, CodingKey { case token, url, expiresAt, maxUses }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decode(String.self, forKey: .token)
        let raw = try c.decode(String.self, forKey: .url)
        guard let parsed = URL(string: raw) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: c, debugDescription: "Not a URL")
        }
        url = parsed
        expiresAt = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .expiresAt) / 1000)
        maxUses = try c.decodeIfPresent(Int.self, forKey: .maxUses)
    }

    public init(token: String, url: URL, expiresAt: Date, maxUses: Int?) {
        self.token = token
        self.url = url
        self.expiresAt = expiresAt
        self.maxUses = maxUses
    }
}

/// How an invite stands, live (`invites:status`). Time passing is not an
/// event: compare `expiresAt` with the phone's clock.
public struct InviteStatus: Equatable, Sendable, Decodable {
    public let uses: Int
    public let maxUses: Int?
    public let expiresAt: Date
    public let revoked: Bool

    enum CodingKeys: String, CodingKey { case uses, maxUses, expiresAt, revoked }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uses = try c.decode(Int.self, forKey: .uses)
        maxUses = try c.decodeIfPresent(Int.self, forKey: .maxUses)
        expiresAt = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .expiresAt) / 1000)
        revoked = try c.decode(Bool.self, forKey: .revoked)
    }

    public init(uses: Int, maxUses: Int?, expiresAt: Date, revoked: Bool) {
        self.uses = uses
        self.maxUses = maxUses
        self.expiresAt = expiresAt
        self.revoked = revoked
    }

    public var isUsedUp: Bool { maxUses.map { uses >= $0 } ?? false }
}

/// What a token opens onto, for the card that asks "Join this house?"
/// (`invites:preview`). `state` degrades to `.invalid` for a value a newer
/// server added, so the card says something rather than failing to decode.
public struct InvitePreview: Equatable, Sendable, Decodable {
    public enum State: String, Equatable, Sendable {
        case ok, expired, full, revoked, invalid, alreadyMember
    }

    public let state: State
    public let homeID: HomeID?
    public let homeName: String?
    public let inviter: User?
    public let memberCount: Int?
    public let members: [User]

    enum CodingKeys: String, CodingKey { case state, homeId, homeName, inviter, memberCount, members }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = (try? c.decode(String.self, forKey: .state)).flatMap(State.init(rawValue:)) ?? .invalid
        homeID = try? c.decodeIfPresent(HomeID.self, forKey: .homeId)
        homeName = try? c.decodeIfPresent(String.self, forKey: .homeName)
        inviter = try? c.decodeIfPresent(User.self, forKey: .inviter)
        memberCount = try? c.decodeIfPresent(Int.self, forKey: .memberCount)
        members = (try? c.decodeIfPresent([User].self, forKey: .members)) ?? []
    }

    public init(
        state: State, homeID: HomeID? = nil, homeName: String? = nil, inviter: User? = nil,
        memberCount: Int? = nil, members: [User] = []
    ) {
        self.state = state
        self.homeID = homeID
        self.homeName = homeName
        self.inviter = inviter
        self.memberCount = memberCount
        self.members = members
    }
}

/// `invites:redeem`'s answer.
public struct InviteRedeemed: Equatable, Sendable, Decodable {
    public let homeID: HomeID
    /// The person was a member already; nothing changed.
    public let already: Bool

    enum CodingKeys: String, CodingKey { case homeID = "homeId", already }

    public init(homeID: HomeID, already: Bool) {
        self.homeID = homeID
        self.already = already
    }
}

/// How many people a QR code lets in. A closed set: the sheet offers these
/// and the server allows 1...20.
public enum InviteLimit: Int, CaseIterable, Hashable, Sendable {
    case one = 1, three = 3, five = 5
    /// No limit (sent as no `maxUses`).
    case anyone = 0

    public var maxUses: Int? { self == .anyone ? nil : rawValue }
}

/// Reading an invite out of whatever a person hands over: a universal link,
/// the `nestzone://join/<token>` fallback, or a bare token.
public enum InviteLink {
    /// The universal link's host and path (`backend/convex/lib/invites.ts`).
    public static let host = "nestzone-convex-api.walhallaa.com"

    /// 22 characters of base64url, the server's `TOKEN_RE`.
    static func isToken(_ text: String) -> Bool {
        text.count == 22 && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    /// The token in a link of ours, or `nil` for any other URL.
    public static func token(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.scheme?.lowercased() {
        case "https":
            guard url.host?.lowercased() == host,
                  let at = parts.firstIndex(of: "join"), at + 1 < parts.count,
                  isToken(parts[at + 1]) else { return nil }
            return parts[at + 1]
        case "nestzone":
            // `nestzone://join/<token>`: "join" is the host.
            guard url.host?.lowercased() == "join", let first = parts.first, isToken(first) else { return nil }
            return first
        default:
            return nil
        }
    }

    /// The token in typed or pasted text: a link of ours or a bare token.
    /// `nil` for anything else, which is how an old invite code is told apart.
    public static func token(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isToken(trimmed) { return trimmed }
        guard let url = URL(string: trimmed) else { return nil }
        return token(from: url)
    }
}

/// A link opened while signed out, kept across the sign-in round trip in app
/// storage as `<token>@<opened at, ms>`, and dropped after a day.
public struct PendingInvite: Equatable, Sendable {
    public static let lifetime: TimeInterval = 24 * 60 * 60

    public let token: String
    public let opened: Date

    public init(token: String, opened: Date) {
        self.token = token
        self.opened = opened
    }

    public init?(raw: String) {
        let parts = raw.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2, InviteLink.isToken(parts[0]), let ms = Double(parts[1]) else { return nil }
        self.init(token: parts[0], opened: Date(timeIntervalSince1970: ms / 1000))
    }

    public var raw: String { "\(token)@\(Int(opened.timeIntervalSince1970 * 1000))" }

    public func isFresh(at now: Date) -> Bool { now.timeIntervalSince(opened) < Self.lifetime }
}
