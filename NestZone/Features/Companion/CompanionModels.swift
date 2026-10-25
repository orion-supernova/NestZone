import Foundation

// The household companion ("Nestie" for now): a plant or a pet on Today that
// grows from what the house already does, graduates into an album, and is
// dressed up for the days the house celebrates.
//
// The house's companion lives on the server now (`companion:forHome`), shared
// by every phone in the house: these types are what it is drawn from. The
// MVP kept all of it in one file per phone (`companion-<home>.json`); that
// file's shape is still decoded, once, to be offered to the server
// (`LocalCompanion`), and the Lab keeps its own small file.

// MARK: - Species

/// What a household can grow. Six trees are drawn by `CanopyPainter` from a
/// seed and a handful of numbers, the duckling by `PetPainter`; the rest stand
/// in as their emoji until the art pass (`art`). How each is had is in the
/// catalog (`access`).
public enum Species: String, CaseIterable, Codable, Identifiable, Sendable {
    // Trees, drawn
    case magnolia, cherry, pomegranate, azalea, lemon, olive
    // Plants still to draw
    case basil, sunflower, cactus, daisy, mint, rosemary, snakePlant, fern, lavender, peony, monstera
    case rose, orchid, bonsai, tulip, maple, pumpkin, pine, snowdrop
    // Pets
    case duckling, kitten, hedgehog, hamster, turtle, goldfish, puppy, bunny
    case fox, owl, deer, penguin, snowFox, polarCub

    public var id: String { rawValue }

    public var isPet: Bool {
        switch self {
        case .duckling, .kitten, .hedgehog, .hamster, .turtle, .goldfish, .puppy, .bunny,
             .fox, .owl, .deer, .penguin, .snowFox, .polarCub: true
        default: false
        }
    }

    /// How it is drawn: a gouache tree, a plant on a growth rule (`PlantPlan`),
    /// the duckling, a pet on a body plan (`CritterPlan`) or — until its
    /// drawing is made — a sketch of its emoji, sprouting or hatching and
    /// growing.
    public enum Art: Sendable { case tree, plant, duckling, critter, sketch }

#if DEBUG
    private static let ducklingLegacy = UserDefaults.standard.bool(forKey: "ducklingLegacy")
#endif

    public var art: Art {
        switch self {
        case .magnolia, .cherry, .pomegranate, .azalea, .lemon, .olive: .tree
        case .duckling:
#if DEBUG
            // `-ducklingLegacy 1` draws the old, flat painter, to compare against.
            Self.ducklingLegacy ? .duckling : .critter
#else
            .critter
#endif
        default:
            if PlantPlan.of(self) != nil { .plant }
            else if CritterPlan.of(self) != nil { .critter }
            else { .sketch }
        }
    }

    public var symbol: String {
        switch self {
        case .magnolia: "🌸"
        case .cherry: "🌸"
        case .pomegranate: "🌺"
        case .azalea: "🌺"
        case .lemon: "🍋"
        case .olive: "🫒"
        case .basil: "🌿"
        case .sunflower: "🌻"
        case .cactus: "🌵"
        case .daisy: "🌼"
        case .mint: "🌱"
        case .rosemary: "🌾"
        case .snakePlant: "🎍"
        case .fern: "☘️"
        case .lavender: "🪻"
        case .peony: "🏵️"
        case .monstera: "🪴"
        case .rose: "🌹"
        case .orchid: "🪷"
        case .bonsai: "🌳"
        case .tulip: "🌷"
        case .maple: "🍁"
        case .pumpkin: "🎃"
        case .pine: "🌲"
        case .snowdrop: "🤍"
        case .duckling: "🐤"
        case .kitten: "🐱"
        case .hedgehog: "🦔"
        case .hamster: "🐹"
        case .turtle: "🐢"
        case .goldfish: "🐠"
        case .puppy: "🐶"
        case .bunny: "🐰"
        case .fox: "🦊"
        case .owl: "🦉"
        case .deer: "🦌"
        case .penguin: "🐧"
        case .snowFox: "🦊"
        case .polarCub: "🐻‍❄️"
        }
    }
}

// MARK: - Growth

/// How a companion's points become stages, and how the house's last few days
/// become a mood.
public enum CompanionMath {
    /// Points to graduate (the server's `graduateAt` says the same). With the
    /// simulated curve an active couple gets there in about two weeks, a quiet
    /// one in four or five, and nobody in under a week (Docs/Companion: the
    /// simulation behind these numbers).
    public static let graduateAt = 64.0
    /// The most finished chores one day can count, for the whole house: a
    /// Saturday clear-out grows it, it does not finish it. The MVP's rule,
    /// kept for the tests and the old file; the server counts growth now.
    public static let dayCap = 9
    /// What one person's care was worth in the MVP, once a day.
    public static let carePoints = 1.0

    /// Points from finished chores since the companion arrived, each day
    /// capped. The MVP's local sum; nothing draws from it now.
    public static func chorePoints(_ completions: [Completion], since start: Date, calendar: Calendar = .current) -> Double {
        let counted = completions.filter { $0.at >= start }
        let byDay = Dictionary(grouping: counted) { calendar.startOfDay(for: $0.at) }
        return Double(byDay.values.reduce(0) { $0 + min($1.count, dayCap) })
    }

    /// The plant's thresholds, as a share of the way to graduation.
    static let plantStages: [Double] = [0, 0.1, 0.28, 0.5, 0.72, 0.88]
    /// The pet's seven: egg, wobbly egg, hatchling, baby, little one, young, grown.
    static let petStages: [Double] = [0, 0.08, 0.2, 0.38, 0.56, 0.76, 0.94]

    public static func stage(progress: Double, isPet: Bool) -> Int {
        let stages = isPet ? petStages : plantStages
        return (stages.lastIndex { progress >= $0 } ?? 0)
    }

    public static func stageCount(isPet: Bool) -> Int { (isPet ? petStages : plantStages).count }

    /// The share of the way to the next stage, for the little bar under the
    /// scene.
    public static func nextStageShare(progress: Double, isPet: Bool) -> Double {
        let stages = (isPet ? petStages : plantStages) + [1]
        let index = stage(progress: progress, isPet: isPet)
        let low = stages[index], high = stages[index + 1]
        return min(max((progress - low) / max(high - low, 0.0001), 0), 1)
    }

    /// How the house has been, from what it did (the server's `recent`).
    ///
    /// Bright needs people together — two of them finishing something in the
    /// last two days — or a busy day; a house of one is bright after three
    /// things in a day. Three quiet days make it thirsty and a week makes it
    /// doze. It never gets worse than dozing, and it never dies.
    public static func mood(
        now: Date,
        completions: [Completion],
        lastCare: Date?,
        startedAt: Date,
        memberCount: Int,
        calendar: Calendar = .current
    ) -> Mood {
        let last = ([startedAt, lastCare].compactMap { $0 } + completions.map(\.at)).max() ?? startedAt
        let quietDays = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)
        ).day ?? 0
        if quietDays >= 7 { return .dozing }
        if quietDays >= 3 { return .thirsty }
        let twoDays = now.addingTimeInterval(-48 * 3600)
        let recent = completions.filter { $0.at >= twoDays }
        let people = Set(recent.compactMap(\.by))
        let today = completions.count { calendar.isDate($0.at, inSameDayAs: now) }
            + (lastCare.map { calendar.isDate($0, inSameDayAs: now) ? 1 : 0 } ?? 0)
        if memberCount > 1, people.count >= 2 { return .bright }
        if today >= (memberCount > 1 ? 4 : 3) { return .bright }
        return .content
    }
}

/// One thing the house did that grew it, as far as the mood cares: when, and
/// by whom. Chores to start with, and now dinners, trips, fixes and the rest.
public struct Completion: Equatable, Hashable, Sendable {
    public var at: Date
    public var by: UserID?

    public init(at: Date, by: UserID?) {
        self.at = at
        self.by = by
    }
}

public enum Mood: String, Codable, CaseIterable, Sendable {
    case bright, content, thirsty, dozing

    /// The number the renderers draw with: 1 is radiant, 0 is fast asleep.
    public var level: Double {
        switch self {
        case .bright: 1
        case .content: 0.62
        case .thirsty: 0.3
        case .dozing: 0.05
        }
    }

    public var isQuiet: Bool { self == .thirsty || self == .dozing }
}

// MARK: - The house's companion, its album and its jar

/// Everything one home keeps about its companion, as the server tells it.
///
/// Still `Codable` for one reason: the MVP's file on a test phone has this
/// shape, and `LocalCompanion` reads it to offer it to the house once. Nothing
/// is written in it any more.
public struct CompanionHouse: Codable, Equatable, Sendable {
    /// The one growing now. `nil` before the first is chosen and between a
    /// graduation and the next choice.
    public var current: Companion?
    /// Every one the house has grown, oldest first.
    public var album: [Graduate] = []
    /// The house jar, like the one on the kitchen shelf: one purse for the
    /// whole house, holding two currencies. Leaves are progress — earned by
    /// growing, never sold. Sparkles are what people buy, with a few earned
    /// along the way. Everybody spends from the jar.
    public var leaves = 0
    public var sparkles = 0
    /// Whether the house has had its welcome gift.
    public var welcomed = false
    /// Everyday decorations bought from the jar.
    public var owned: Set<String> = [DecorItem.wateringCan.rawValue]
    /// Species bought from the jar, alone or in a pack, to grow whenever the
    /// house likes.
    public var ownedSpecies: Set<String> = []
    /// What sits where.
    public var layout = SceneLayout()
    /// The days this house celebrates, or `nil` for the region's defaults.
    public var holidays: [String]?
    /// The highest stage already paid into the jar, so a stage pays once.
    public var paidStage = 0
    /// Overrides for trying things out on a development build: a local
    /// preview, laid over the house when it is drawn and never sent anywhere.
    public var lab = Lab()

    // What only the server version has. Not in the old file's keys.
    /// How many the house has graduated. The album's cards load with the
    /// album; the count is part of every read, because the seed of the next
    /// one and what a graduation earns depend on it.
    public var albumCount = 0
    /// Which species the house has grown all the way: what "grown them all"
    /// is counted from, so it needs no album.
    public var grown: Set<Species> = []
    /// Where the house is: the region its default holidays and its seasons
    /// come from, and its offset in minutes east of UTC, whose days growth is
    /// counted in. `nil` until somebody's phone says.
    public var region: String?
    public var tzOffset: Int?
    /// The house's vote for the one growing, open or decided. Not in the old
    /// file: only the server has votes.
    public var vote: CompanionVote?

    public init() {}

    public static let empty = CompanionHouse()

    /// The Lab: a LOCAL PREVIEW for development builds. It is laid over the
    /// house when it is drawn (`CompanionFeature.State.house`) and lives in its
    /// own file on this phone (`SharedKey.companionLab`). Nothing in it is ever
    /// sent to the server, and a purchase made while it holds coins stays in it
    /// too, so the house's jar cannot be spent on what only the Lab gave.
    public struct Lab: Codable, Equatable, Sendable {
        /// Pretend the house has been like this, whatever it has done.
        public var mood: Mood?
        /// Pretend it is this day — to see a holiday arrive.
        public var date: Date?
        /// Pretend somebody's birthday is today — to see the party hat.
        public var birthday = false
        /// The shop's stages at dusk rather than lit, to compare the two.
        public var dusk = false
        /// Points added (or taken away) by hand, over the server's.
        public var bonus = 0.0
        /// Coins added to (or taken from) the jar as it is drawn. The test
        /// store's Sparkles land here too: there is no top-up on the server yet.
        public var leaves = 0
        public var sparkles = 0
        /// What was bought with those coins.
        public var owned: Set<String> = []
        public var ownedSpecies: Set<String> = []
        public init() {}

        /// Whether the jar being drawn is not the house's real one.
        public var touchesJar: Bool { leaves != 0 || sparkles != 0 }

        enum CodingKeys: String, CodingKey { case mood, date, birthday, dusk, bonus, leaves, sparkles, owned, ownedSpecies }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mood = try? c.decodeIfPresent(Mood.self, forKey: .mood)
            date = try? c.decodeIfPresent(Date.self, forKey: .date)
            birthday = (try? c.decodeIfPresent(Bool.self, forKey: .birthday)) ?? false
            dusk = (try? c.decodeIfPresent(Bool.self, forKey: .dusk)) ?? false
            bonus = (try? c.decodeIfPresent(Double.self, forKey: .bonus)) ?? 0
            leaves = (try? c.decodeIfPresent(Int.self, forKey: .leaves)) ?? 0
            sparkles = (try? c.decodeIfPresent(Int.self, forKey: .sparkles)) ?? 0
            owned = (try? c.decodeIfPresent(Set<String>.self, forKey: .owned)) ?? []
            ownedSpecies = (try? c.decodeIfPresent(Set<String>.self, forKey: .ownedSpecies)) ?? []
        }
    }

    enum CodingKeys: String, CodingKey {
        // Leaves were the jar's only coin when the file first held it.
        case current, album, leaves = "jar", sparkles, welcomed, owned, ownedSpecies, layout, holidays, paidStage, lab
    }

    /// Lenient: a field a later build adds must not make an older file
    /// unreadable, because an unreadable file falls back to empty — and empty
    /// is somebody's album gone.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        current = try? c.decodeIfPresent(Companion.self, forKey: .current)
        album = (try? c.decodeIfPresent([Graduate].self, forKey: .album)) ?? []
        albumCount = album.count
        leaves = (try? c.decodeIfPresent(Int.self, forKey: .leaves)) ?? 0
        sparkles = (try? c.decodeIfPresent(Int.self, forKey: .sparkles)) ?? 0
        welcomed = (try? c.decodeIfPresent(Bool.self, forKey: .welcomed)) ?? false
        owned = (try? c.decodeIfPresent(Set<String>.self, forKey: .owned)) ?? [DecorItem.wateringCan.rawValue]
        ownedSpecies = (try? c.decodeIfPresent(Set<String>.self, forKey: .ownedSpecies)) ?? []
        layout = (try? c.decodeIfPresent(SceneLayout.self, forKey: .layout)) ?? SceneLayout()
        holidays = try? c.decodeIfPresent([String].self, forKey: .holidays)
        paidStage = (try? c.decodeIfPresent(Int.self, forKey: .paidStage)) ?? 0
        lab = (try? c.decodeIfPresent(Lab.self, forKey: .lab)) ?? Lab()
    }
}

public struct Companion: Codable, Equatable, Sendable {
    public var species: Species
    /// Seeds the drawing: the same seed grows the same tree on every phone.
    public var seed: String
    public var startedAt: Date
    /// The days this person cared for it, `yyyy-MM-dd` in the house's days.
    /// One counts per day.
    public var careDays: [String] = []
    /// When anyone in the house last came by.
    public var lastCareAt: Date?

    // What the server says. Absent in the old file, and on a companion that is
    // only just being started, before the server has answered.
    /// The server's id for it, which graduating names.
    public var id: String?
    /// Its growth, which the server counts: nothing here adds chores up.
    public var points: Double?
    public var serverStage: Int?
    /// Whether it can graduate, as the server says: the points and its floor of
    /// days both. Taken as it comes; nothing here works it out.
    public var isReady = false
    /// The points are there, whatever the days say.
    public var pointsReady = false
    /// When it can graduate, if the points are there by then.
    public var readyAt: Date?
    /// The house has not chosen what this is yet, so `species` is only the
    /// vote's first option standing in. A seed grows meanwhile (the server
    /// counts what the house does), but it is drawn as a seed and called one.
    public var isUndecided = false

    public init(species: Species, seed: String, startedAt: Date) {
        self.species = species
        self.seed = seed
        self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey { case species, seed, startedAt, careDays, lastCareAt }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        species = try c.decode(Species.self, forKey: .species)
        seed = try c.decode(String.self, forKey: .seed)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        careDays = (try? c.decodeIfPresent([String].self, forKey: .careDays)) ?? []
        lastCareAt = try? c.decodeIfPresent(Date.self, forKey: .lastCareAt)
    }
}

/// A companion that grew up, as its album card remembers it.
public struct Graduate: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var species: Species
    public var seed: String
    public var startedAt: Date
    public var graduatedAt: Date

    public var days: Int {
        max(Calendar.current.dateComponents([.day], from: startedAt, to: graduatedAt).day ?? 0, 1)
    }
}

extension CompanionHouse {
    public func canAfford(_ price: Price) -> Bool {
        switch price {
        case let .leaves(amount): leaves >= amount
        case let .sparkles(amount): sparkles >= amount
        }
    }

    public mutating func pay(_ price: Price) {
        switch price {
        case let .leaves(amount): leaves -= amount
        case let .sparkles(amount): sparkles -= amount
        }
    }

    public mutating func add(_ coins: Coins) {
        leaves += coins.leaves
        sparkles += coins.sparkles
    }
}

/// Some of each currency, as the jar is paid.
public struct Coins: Equatable, Sendable {
    public var leaves: Int
    public var sparkles: Int

    public static func * (coins: Coins, times: Int) -> Coins {
        Coins(leaves: coins.leaves * times, sparkles: coins.sparkles * times)
    }
}

/// What a thing costs: one price, in one currency. Never "100 Leaves or 5
/// Sparkles" for the same thing — a cheap second price for what progress
/// earns is paying to skip the progress. A house short of Leaves can make up
/// the difference with Sparkles it has, one for one (`Exchange`), which is
/// the same price paid, not a second one.
public enum Price: Hashable, Sendable {
    case leaves(Int)
    case sparkles(Int)
}

/// What the jar is paid, and when.
public enum Rewards {
    /// Every new stage: Leaves for progress, a pinch of Sparkles like a
    /// merge game's level-up.
    public static let stage = Coins(leaves: 10, sparkles: 5)
    /// Growing one all the way.
    public static let graduation = Coins(leaves: 100, sparkles: 25)
    /// The welcome gift: about one and a half of a starter item in each
    /// currency, so the first visit to the shop buys something real and
    /// still leaves a little over (bunting at 100 Leaves leaves 50; a paper
    /// lantern at 120 Sparkles leaves 60).
    public static let welcome = Coins(leaves: 150, sparkles: 180)
}

// MARK: - Decorations

/// Where a thing goes in the scene. Decorations never go anywhere they are
/// dropped: a phone-wide card covered in freely placed things is clutter
/// within a week, and a spot is the same place on every phone in the house.
public enum Spot: String, CaseIterable, Codable, Identifiable, Sendable {
    case above, sky, weather, tree, wearing, pot, left, right, ground
    public var id: String { rawValue }

    /// The kind of thing that fits; both floor spots take floor things.
    var kind: DecorItem.Kind {
        switch self {
        case .above: .above
        case .sky: .sky
        case .weather: .weather
        case .tree: .tree
        case .wearing: .wearing
        case .pot: .pot
        case .left, .right: .floor
        case .ground: .ground
        }
    }

    /// Spots a pet's scene has: no tree to hang things on and no pot.
    static let forPets: [Spot] = [.above, .sky, .weather, .wearing, .left, .right, .ground]
}

/// A decoration: a drawing, or a string of flags in a holiday's colours.
public enum Decor: Hashable, Sendable, Identifiable {
    case item(DecorItem)
    case flags(Holiday.ID)

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case let .item(item): item.rawValue
        case let .flags(holiday): "flags.\(holiday.rawValue)"
        }
    }

    public init?(rawValue: String) {
        if rawValue.hasPrefix("flags."), let holiday = Holiday.ID(rawValue: String(rawValue.dropFirst(6))) {
            self = .flags(holiday)
        } else if let item = DecorItem(rawValue: rawValue) {
            self = .item(item)
        } else {
            return nil
        }
    }

    var kind: DecorItem.Kind {
        switch self {
        case let .item(item): item.kind
        case .flags: .above
        }
    }
}

public enum DecorItem: String, CaseIterable, Codable, Sendable {
    // Everyday, bought from the jar
    case bunting, fairyLights, paperLantern, wateringCan, kilim, terracotta, glazedPot, goldPot, dusk
    // Everyday, still to draw: scenes, overhead, wearing, floor
    case windowsill, balcony, starryRooftop, winterSky, windChime, bow, scarf, partyHat, tinyCrown, birdFeeder, watermelon
    // Brought by a holiday, free while it lasts
    case ornaments, treeStar, giftBox, snowfall, heartGarland, bouquet, pumpkin, bats, fullMoon, spookyBunting
    case papelPicado, marigolds, kinara, confetti, shamrocks, fireworks, autumnLeaves, eggBasket, petals
    case ramadanLantern, crescentGarland, candyBowl, oilLamps, pomegranates, menorah, colourPowder, kites
    case redLanterns, harvestMoon, wishNotes, sabzeh

    enum Kind: Sendable { case above, sky, weather, tree, wearing, pot, floor, ground }

    var kind: Kind {
        switch self {
        case .bunting, .heartGarland, .spookyBunting, .papelPicado, .shamrocks, .crescentGarland, .kites, .redLanterns, .bats,
             .windChime:
            .above
        case .dusk, .fullMoon, .harvestMoon, .fireworks, .windowsill, .balcony, .starryRooftop, .winterSky:
            .sky
        case .snowfall, .petals, .confetti, .autumnLeaves, .colourPowder:
            .weather
        case .fairyLights, .ornaments, .treeStar, .wishNotes:
            .tree
        case .bow, .scarf, .partyHat, .tinyCrown:
            .wearing
        case .terracotta, .glazedPot, .goldPot:
            .pot
        case .kilim:
            .ground
        case .wateringCan, .paperLantern, .pumpkin, .giftBox, .candyBowl, .bouquet, .kinara, .eggBasket,
             .ramadanLantern, .oilLamps, .pomegranates, .menorah, .sabzeh, .marigolds, .birdFeeder, .watermelon:
            .floor
        }
    }

    /// Snow and the like, left out where December is summer.
    var isWintry: Bool { self == .snowfall || self == .winterSky }

    /// Drawn in the scene so far; the rest stand in as their emoji until the
    /// art pass.
    var isDrawn: Bool {
        switch self {
        case .windowsill, .balcony, .starryRooftop, .windChime, .bow, .scarf, .tinyCrown, .watermelon: false
        default: true
        }
    }
}

/// What sits in each spot. The tree takes up to four things; every other spot
/// takes one.
public struct SceneLayout: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case above, sky, weather, tree, wearing, pot, left, right, ground }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        above = try? c.decodeIfPresent(String.self, forKey: .above)
        sky = try? c.decodeIfPresent(String.self, forKey: .sky)
        weather = try? c.decodeIfPresent(String.self, forKey: .weather)
        tree = (try? c.decodeIfPresent([String].self, forKey: .tree)) ?? []
        wearing = try? c.decodeIfPresent(String.self, forKey: .wearing)
        pot = try? c.decodeIfPresent(String.self, forKey: .pot)
        left = try? c.decodeIfPresent(String.self, forKey: .left)
        right = try? c.decodeIfPresent(String.self, forKey: .right)
        ground = try? c.decodeIfPresent(String.self, forKey: .ground)
    }

    public var above: String?
    public var sky: String?
    public var weather: String?
    public var tree: [String] = []
    public var wearing: String?
    public var pot: String?
    public var left: String?
    public var right: String?
    public var ground: String?

    public static let treeLimit = 4

    public init() {}

    public subscript(spot: Spot) -> String? {
        get {
            switch spot {
            case .above: above
            case .sky: sky
            case .weather: weather
            case .tree: tree.first
            case .wearing: wearing
            case .pot: pot
            case .left: left
            case .right: right
            case .ground: ground
            }
        }
        set {
            switch spot {
            case .above: above = newValue
            case .sky: sky = newValue
            case .weather: weather = newValue
            case .tree: tree = newValue.map { [$0] } ?? []
            case .wearing: wearing = newValue
            case .pot: pot = newValue
            case .left: left = newValue
            case .right: right = newValue
            case .ground: ground = newValue
            }
        }
    }

    /// Whether `decor` is in `spot`.
    public func holds(_ decor: String, in spot: Spot) -> Bool {
        spot == .tree ? tree.contains(decor) : self[spot] == decor
    }

    /// Everything placed, in any spot.
    public var all: [String] {
        [above, sky, weather, wearing, pot, left, right, ground].compactMap { $0 } + tree
    }

    /// Puts `decor` in `spot`, or takes it out if it is already there. A floor
    /// thing moved to the other side leaves the first.
    public mutating func toggle(_ decor: String, in spot: Spot) {
        if spot == .tree {
            if let index = tree.firstIndex(of: decor) { tree.remove(at: index) }
            else if tree.count < Self.treeLimit { tree.append(decor) }
            return
        }
        if self[spot] == decor { self[spot] = nil; return }
        if spot == .left, right == decor { right = nil }
        if spot == .right, left == decor { left = nil }
        self[spot] = decor
    }

    /// Puts out everything a holiday brings that fits this scene.
    public mutating func dress(for holiday: Holiday, southern: Bool, isPet: Bool) {
        let keeping = Set(holiday.decor.map(\.rawValue))
        for decor in holiday.decor {
            if case let .item(item) = decor, item.isWintry, southern { continue }
            if isPet, decor.kind == .tree || decor.kind == .pot { continue }
            place(decor, keeping: keeping)
        }
    }

    /// Puts a holiday's thing out, for its "put it all out": into an empty
    /// spot that fits, or in place of something from before — never in place
    /// of something in `keeping`, which is the rest of the same holiday, so
    /// its bats are not swapped for its own bunting.
    public mutating func place(_ decor: Decor, keeping: Set<String> = []) {
        let raw = decor.rawValue
        guard !all.contains(raw) else { return }
        func free(_ value: String?) -> Bool { value.map { !keeping.contains($0) } ?? true }
        switch decor.kind {
        case .above: if free(above) { above = raw }
        case .sky: if free(sky) { sky = raw }
        case .weather: if free(weather) { weather = raw }
        case .tree:
            if tree.count < Self.treeLimit { tree.append(raw) }
            else if let index = tree.firstIndex(where: { !keeping.contains($0) }) { tree[index] = raw }
        case .wearing: if free(wearing) { wearing = raw }
        case .pot: if free(pot) { pot = raw }
        case .floor:
            if left == nil { left = raw }
            else if right == nil { right = raw }
            else if free(left) { left = raw }
            else if free(right) { right = raw }
        case .ground: if free(ground) { ground = raw }
        }
    }
}
