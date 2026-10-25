#if DEBUG
import Foundation

/// Everything the stand-in server keeps about one house: the jar, what is
/// owned and out, the one growing, the album, the vote. A plain value, so the
/// pretend house can be written to a file and read back (it survives a
/// relaunch), copied for a test, and changed by a preset in one go.
///
/// The rules for what the client depends on live beside it (`PretendRules`):
/// a graduation only when grown, a welcome gift once, a price the catalog
/// decides. `FakeNestieServer` adds what a network adds: latency, refusals,
/// one answer per request id.
struct PretendState: Codable, Equatable, Sendable {
    // The house.
    var leaves = 0
    var sparkles = 0
    var welcomed = false
    var owned: Set<String> = []
    var ownedSpecies: Set<String> = []
    var layout = SceneLayout()
    var holidays: [String]?
    var region: String? = "TR"
    var tzOffset: Int? = 180
    var albumCount = 0
    var hasHouse = true
    var current: Current?
    var recent: [Recent] = []
    var album: [Card] = []
    var grownColours: Set<String> = []
    var finaleAt: Date?
    var jarFeed: [JarRow] = []
    var vote: Vote?
    /// People in the house. The reducer keeps the same number (`lab.members`)
    /// and tells the server whenever it changes; the vote needs them.
    var members = 1

    struct Current: Codable, Equatable, Sendable {
        var id = "companion-1"
        var uuid = UUID().uuidString
        var species: Species
        var seed: String
        var startedAt: Date
        var points: Double
        var paidStage = 0
        var lastCare: Date?
        var careDays: [String] = []
        /// A seed the house has not named: `species` is the vote's first option.
        var undecided = false
        var colour: Int?
    }

    struct Recent: Codable, Equatable, Sendable {
        var kind: String
        var at: Date
        var user: String?
    }

    struct Card: Codable, Equatable, Sendable {
        var uuid: String
        var species: Species
        var seed: String
        var started: Date
        var graduated: Date
        var colour: Int?
    }

    struct JarRow: Codable, Equatable, Sendable {
        var id: String
        var kind: String
        var leaves: Int
        var sparkles: Int
        var item: String?
        var user: String?
        var at: Date
    }

    /// The vote for the next one, as the server keeps it. `others` holds one
    /// set of answers for each of the other people in the house.
    struct Vote: Codable, Equatable, Sendable {
        var options: [String]
        var mine: [String: Bool] = [:]
        var others: [[String: Bool]]
        var status = "open"
        var how: String?
        var winner: String?
        var openedAt: Date
        var closesAt: Date
        var pollID = "pretend-poll"

        var members: Int { 1 + others.count }
        var isOpen: Bool { status == "open" }

        func yes(_ id: String) -> Int {
            (mine[id] == true ? 1 : 0) + others.count { $0[id] == true }
        }

        func no(_ id: String) -> Int {
            (mine[id] == false ? 1 : 0) + others.count { $0[id] == false }
        }

        /// How many people have answered every option.
        var answered: Int {
            (mine.count == options.count ? 1 : 0) + others.count { $0.count == options.count }
        }

        /// Somebody other than this person has answered something.
        var othersVoted: Bool { others.contains { !$0.isEmpty } }

        /// Most yeses, the earlier option on a tie; none without a yes.
        var leader: String? {
            options.filter { yes($0) > 0 }.max { yes($0) < yes($1) }
        }
    }
}

// MARK: - The rules

/// The numbers the server owns, as the client sees them.
enum PretendRules {
    static let graduateAt = 64.0
    /// A companion cannot graduate before it has grown this long, however
    /// many points it has.
    static let floorDays = 6.0
    static let day: TimeInterval = 86_400
    /// What a housemate's finished chore, and a day's first care, are worth.
    static let chorePoints = 1.2
    static let carePoints = 0.8
}

extension PretendState {
    func thresholds(isPet: Bool) -> [Double] { isPet ? CompanionMath.petStages : CompanionMath.plantStages }

    func stage(of current: Current) -> Int {
        guard !current.undecided else { return 0 }
        let progress = current.points / PretendRules.graduateAt
        return thresholds(isPet: current.species.isPet).lastIndex { progress >= $0 } ?? 0
    }

    func pointsReady(_ current: Current) -> Bool { current.points >= PretendRules.graduateAt - 1e-9 }

    func readyAt(_ current: Current) -> Date {
        current.startedAt.addingTimeInterval(PretendRules.floorDays * PretendRules.day)
    }

    func isReady(_ current: Current, now: Date) -> Bool {
        !current.undecided && pointsReady(current) && now >= readyAt(current)
    }

    /// Species this house can start today without the shop: the free ones and
    /// whatever it bought or was given.
    func startable() -> [Species] {
        Species.allCases.filter {
            switch $0.access {
            case .free: true
            default: ownedSpecies.contains($0.rawValue)
            }
        }
    }

    var grown: Set<Species> { Set(album.map(\.species)) }

    /// A day key in the house's days, as the server counts care.
    func dayKey(_ date: Date) -> String {
        CompanionFeature.State.dayKey(date, offset: tzOffset)
    }

    // MARK: The payload, as JSON

    /// `companion:forHome`, built as the JSON the server sends and decoded by
    /// the real `CompanionPayload`, unknown kinds and all.
    func payload(now: Date) -> CompanionPayload {
        func ms(_ date: Date) -> Double { (date.timeIntervalSince1970 * 1000).rounded() }
        var json: [String: Any] = [
            "catalogVersion": CatalogVersion.exported,
            "graduateAt": PretendRules.graduateAt,
            "recent": recent.prefix(120).map { ["kind": $0.kind, "at": ms($0.at), "userId": $0.user ?? NSNull()] as [String: Any] },
            "jar": jarFeed.map { row in
                ["id": row.id, "kind": row.kind, "leaves": row.leaves, "sparkles": row.sparkles, "item": row.item ?? NSNull(),
                 "userId": row.user ?? NSNull(), "at": ms(row.at)] as [String: Any]
            },
        ]
        json["house"] = hasHouse ? [
            "leaves": leaves, "sparkles": sparkles, "welcomed": welcomed,
            "owned": owned.sorted(), "ownedSpecies": ownedSpecies.sorted(),
            "grownSpecies": album.map(\.species.rawValue),
            "grownColours": grownColours.sorted(), "finaleAt": finaleAt.map(ms) as Any? ?? NSNull(),
            "layout": layoutJSON(), "holidays": holidays as Any? ?? NSNull(),
            "region": region as Any? ?? NSNull(), "tzOffset": tzOffset as Any? ?? NSNull(),
            "albumCount": albumCount,
        ] as [String: Any] : NSNull()
        json["current"] = current.map { c in
            [
                "id": c.id, "uuid": c.uuid, "species": c.species.rawValue, "seed": c.seed,
                "startedAt": ms(c.startedAt), "points": c.points, "stage": stage(of: c),
                "isReady": isReady(c, now: now), "pointsReady": pointsReady(c), "readyAt": ms(readyAt(c)),
                "paidStage": c.paidStage,
                "lastCareAt": c.lastCare.map(ms) as Any? ?? NSNull(), "myCareDays": c.careDays,
                "undecided": c.undecided, "colour": c.colour as Any? ?? NSNull(),
            ] as [String: Any]
        } ?? NSNull()
        json["vote"] = vote.map { v in
            [
                "pollId": v.pollID, "status": v.status, "openedAt": ms(v.openedAt),
                "closesAt": ms(v.closesAt), "closedAt": NSNull(), "how": v.how as Any? ?? NSNull(),
                "winner": v.winner as Any? ?? NSNull(),
                "options": v.options.map { id in
                    ["species": id, "isPet": Species(rawValue: id)?.isPet ?? false,
                     "grown": Species(rawValue: id).map(grown.contains) ?? false,
                     "yes": v.yes(id), "no": v.no(id)] as [String: Any]
                },
                "mine": v.mine.map { ["species": $0.key, "yes": $0.value] as [String: Any] },
                "members": v.members, "answered": v.answered, "othersVoted": v.othersVoted,
            ] as [String: Any]
        } ?? NSNull()
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: json)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(CompanionPayload.self, from: data)
    }

    private func layoutJSON() -> [String: Any] {
        var json: [String: Any] = ["tree": layout.tree]
        for spot in Spot.allCases where spot != .tree { if let raw = layout[spot] { json[spot.rawValue] = raw } }
        return json
    }

    /// `companion:album`.
    func cards() -> CompanionPayload.Cards {
        let json: [[String: Any]] = album.map { card in
            ["uuid": card.uuid, "species": card.species.rawValue, "seed": card.seed,
             "startedAt": card.started.timeIntervalSince1970 * 1000, "graduatedAt": card.graduated.timeIntervalSince1970 * 1000,
             "colour": card.colour as Any? ?? NSNull()]
        }
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(CompanionPayload.Cards.self, from: try! JSONSerialization.data(withJSONObject: json))
    }

    // MARK: What a write does to the house

    mutating func addJar(_ kind: String, leaves: Int, sparkles: Int, item: String? = nil, at now: Date) {
        jarFeed.insert(
            JarRow(id: "j\(UUID().uuidString.prefix(8))", kind: kind, leaves: leaves, sparkles: sparkles, item: item, user: "u1", at: now),
            at: 0
        )
        if jarFeed.count > 40 { jarFeed.removeLast() }
    }

    /// Pays every stage reached and not yet paid, once each, as the server
    /// does when the points move.
    mutating func settleStages(now: Date) {
        guard var c = current, !c.undecided else { return }
        let reached = stage(of: c)
        while c.paidStage < reached {
            c.paidStage += 1
            leaves += Rewards.stage.leaves
            sparkles += Rewards.stage.sparkles
            addJar("stage", leaves: Rewards.stage.leaves, sparkles: Rewards.stage.sparkles, at: now)
        }
        current = c
    }

    /// Marks the stage reached as paid without paying it: jumping to a stage
    /// from the Lab is setting up a house, not growing it.
    mutating func markStagePaid() {
        guard var c = current else { return }
        c.paidStage = max(c.paidStage, stage(of: c))
        current = c
    }

    /// What graduating the one growing does to the house: the card, the jar,
    /// the colour grown, and whether it finished every free species, once.
    mutating func graduate(_ c: Current, now: Date) -> (finale: Bool, paid: Coins) {
        album.append(Card(uuid: c.uuid, species: c.species, seed: c.seed, started: c.startedAt, graduated: now, colour: c.colour))
        if let colour = c.colour { grownColours.insert(Colourway.key(c.species, colour)) }
        albumCount += 1
        leaves += Rewards.graduation.leaves
        sparkles += Rewards.graduation.sparkles
        addJar("graduation", leaves: Rewards.graduation.leaves, sparkles: Rewards.graduation.sparkles, at: now)
        let finale = finaleAt == nil && Species.freeToHave.isSubset(of: grown)
        if finale { finaleAt = now }
        return (finale, Rewards.graduation)
    }

    /// Opens the vote for the next one, as the server does in the write that
    /// graduates a companion in a house of two or more: the next one is
    /// already growing, as a seed.
    mutating func openVote(now: Date) {
        let options = voteOptions()
        var others: [[String: Bool]] = []
        for _ in 1..<max(members, 1) { others.append([:]) }
        vote = Vote(options: options, others: others, openedAt: now, closesAt: now.addingTimeInterval(24 * 3_600))
        let seed = "pretend-\(albumCount)-\(Int(now.timeIntervalSince1970) % 1000)"
        current = Current(
            id: "companion-\(albumCount + 1)-seed", species: Species(rawValue: options[0]) ?? .cherry, seed: seed,
            startedAt: now, points: 0, undecided: true
        )
    }

    /// Three the house could grow, ones it has not grown first.
    func voteOptions() -> [String] {
        let pool = startableForVote()
        let fresh = pool.filter { !grown.contains($0) }
        let order = (fresh + pool.filter { grown.contains($0) }).map(\.rawValue)
        // Stable but not the same three every time.
        let shift = order.isEmpty ? 0 : albumCount % order.count
        let rotated = Array(order[shift...] + order[..<shift])
        return Array(rotated.prefix(3))
    }

    private func startableForVote() -> [Species] {
        let seasonless = Species.allCases.filter {
            switch $0.access {
            case .free, .season, .reward: true
            default: ownedSpecies.contains($0.rawValue)
            }
        }
        return seasonless.filter { $0 != current?.species || current?.undecided == true }
    }

    /// Ends the vote with a winner and names the seed.
    mutating func closeVote(how: String, winner: String?) {
        guard var v = vote, v.isOpen else { return }
        v.status = "closed"
        v.how = how
        v.winner = winner
        vote = v
        if let winner, var c = current, c.undecided, let species = Species(rawValue: winner) {
            c.species = species
            c.undecided = false
            current = c
        }
    }
}
#endif
