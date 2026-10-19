import Foundation

// The household companion ("Nestie" for now): a plant or a pet on Today that
// grows from what the house already does, graduates into an album, and is
// dressed up for the days the house celebrates.
//
// This is the MVP: everything here is kept on the device, per home, and the
// growth is read off the chores the household finishes, which every phone
// already receives. The server version (docs in Docs/Companion) replaces the
// storage, not these types.

// MARK: - Species

/// What a household can grow. The trees are drawn by `PlantRenderer` from a
/// seed and a handful of numbers; the duckling by `PetRenderer`.
public enum Species: String, CaseIterable, Codable, Identifiable, Sendable {
    case magnolia, cherry, pomegranate, azalea, lemon, olive, duckling

    public var id: String { rawValue }
    public var isPet: Bool { self == .duckling }
    public var symbol: String {
        switch self {
        case .magnolia: "🌸"
        case .cherry: "🌸"
        case .pomegranate: "🌺"
        case .azalea: "🌺"
        case .lemon: "🍋"
        case .olive: "🫒"
        case .duckling: "🐤"
        }
    }
}

// MARK: - Growth

/// How a companion's points become stages, and how the house's last few days
/// become a mood.
public enum CompanionMath {
    /// Points to graduate. With a chore worth one and a day capped at
    /// `dayCap`, an active couple gets there in about two weeks, a quiet one
    /// in four or five, and nobody in under a week (Docs/Companion: the
    /// simulation behind these numbers).
    public static let graduateAt = 64.0
    /// The most finished chores one day can count, for the whole house: a
    /// Saturday clear-out grows it, it does not finish it.
    public static let dayCap = 9
    /// What one person's care is worth, once a day.
    public static let carePoints = 1.0

    /// Points from finished chores since the companion arrived, each day
    /// capped.
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

    /// How the house has been.
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

/// One finished chore, as far as the companion cares: when, and by whom.
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

/// Everything one home keeps about its companion. One file per home on this
/// device in the MVP.
public struct CompanionHouse: Codable, Equatable, Sendable {
    /// The one growing now. `nil` before the first is chosen and between a
    /// graduation and the next choice.
    public var current: Companion?
    /// Every one the house has grown, oldest first.
    public var album: [Graduate] = []
    /// The house jar: one purse for the whole house, like the jar on the
    /// kitchen shelf. Graduations and new stages put Leaves in; everybody
    /// spends from it.
    public var jar = 0
    /// Everyday decorations bought from the jar.
    public var owned: Set<String> = [DecorItem.wateringCan.rawValue]
    /// What sits where.
    public var layout = SceneLayout()
    /// The days this house celebrates, or `nil` for the region's defaults.
    public var holidays: [String]?
    /// The highest stage already paid into the jar, so a stage pays once.
    public var paidStage = 0
    /// Overrides for trying things out on a development build.
    public var lab = Lab()

    public init() {}

    public static let empty = CompanionHouse()

    public struct Lab: Codable, Equatable, Sendable {
        /// Pretend the house has been like this, whatever the chores say.
        public var mood: Mood?
        /// Pretend it is this day — to see a holiday arrive.
        public var date: Date?
        public init() {}
    }

    enum CodingKeys: String, CodingKey {
        case current, album, jar, owned, layout, holidays, paidStage, lab
    }

    /// Lenient: a field a later build adds must not make an older file
    /// unreadable, because an unreadable file falls back to empty — and empty
    /// is somebody's album gone.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        current = try? c.decodeIfPresent(Companion.self, forKey: .current)
        album = (try? c.decodeIfPresent([Graduate].self, forKey: .album)) ?? []
        jar = (try? c.decodeIfPresent(Int.self, forKey: .jar)) ?? 0
        owned = (try? c.decodeIfPresent(Set<String>.self, forKey: .owned)) ?? [DecorItem.wateringCan.rawValue]
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
    /// The days this device cared for it, `yyyy-MM-dd`. One counts per day.
    public var careDays: [String] = []
    public var lastCareAt: Date?
    /// Points added by hand on a development build.
    public var bonus = 0.0

    public init(species: Species, seed: String, startedAt: Date) {
        self.species = species
        self.seed = seed
        self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey { case species, seed, startedAt, careDays, lastCareAt, bonus }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        species = try c.decode(Species.self, forKey: .species)
        seed = try c.decode(String.self, forKey: .seed)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        careDays = (try? c.decodeIfPresent([String].self, forKey: .careDays)) ?? []
        lastCareAt = try? c.decodeIfPresent(Date.self, forKey: .lastCareAt)
        bonus = (try? c.decodeIfPresent(Double.self, forKey: .bonus)) ?? 0
    }

    public var carePoints: Double { Double(careDays.count) * CompanionMath.carePoints }
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

/// What the jar pays.
public enum Jar {
    /// Every new stage.
    public static let stagePay = 10
    /// Growing one all the way.
    public static let graduationPay = 100
}

// MARK: - Decorations

/// Where a thing goes in the scene. Decorations never go anywhere they are
/// dropped: a phone-wide card covered in freely placed things is clutter
/// within a week, and a spot is the same place on every phone in the house.
public enum Spot: String, CaseIterable, Codable, Identifiable, Sendable {
    case above, sky, weather, tree, pot, left, right, ground
    public var id: String { rawValue }

    /// The kind of thing that fits; both floor spots take floor things.
    var kind: DecorItem.Kind {
        switch self {
        case .above: .above
        case .sky: .sky
        case .weather: .weather
        case .tree: .tree
        case .pot: .pot
        case .left, .right: .floor
        case .ground: .ground
        }
    }

    /// Spots a pet's scene has: no tree to hang things on and no pot.
    static let forPets: [Spot] = [.above, .sky, .weather, .left, .right, .ground]
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
    // Brought by a holiday, free while it lasts
    case ornaments, treeStar, giftBox, snowfall, heartGarland, bouquet, pumpkin, bats, fullMoon, spookyBunting
    case papelPicado, marigolds, kinara, confetti, shamrocks, fireworks, autumnLeaves, eggBasket, petals
    case ramadanLantern, crescentGarland, candyBowl, oilLamps, pomegranates, menorah, colourPowder, kites
    case redLanterns, harvestMoon, wishNotes, sabzeh

    enum Kind: Sendable { case above, sky, weather, tree, pot, floor, ground }

    var kind: Kind {
        switch self {
        case .bunting, .heartGarland, .spookyBunting, .papelPicado, .shamrocks, .crescentGarland, .kites, .redLanterns, .bats:
            .above
        case .dusk, .fullMoon, .harvestMoon, .fireworks:
            .sky
        case .snowfall, .petals, .confetti, .autumnLeaves, .colourPowder:
            .weather
        case .fairyLights, .ornaments, .treeStar, .wishNotes:
            .tree
        case .terracotta, .glazedPot, .goldPot:
            .pot
        case .kilim:
            .ground
        case .wateringCan, .paperLantern, .pumpkin, .giftBox, .candyBowl, .bouquet, .kinara, .eggBasket,
             .ramadanLantern, .oilLamps, .pomegranates, .menorah, .sabzeh, .marigolds:
            .floor
        }
    }

    /// Leaves from the jar, for the everyday things. Holiday things have no
    /// price: they come with the day.
    public var price: Int? {
        switch self {
        case .bunting: 100
        case .fairyLights: 150
        case .paperLantern: 200
        case .kilim: 250
        case .terracotta: 80
        case .glazedPot: 120
        case .goldPot: 300
        case .dusk: 200
        case .wateringCan: 0
        default: nil
        }
    }

    /// Snow and the like, left out where December is summer.
    var isWintry: Bool { self == .snowfall }
}

/// What sits in each spot. The tree takes up to four things; every other spot
/// takes one.
public struct SceneLayout: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case above, sky, weather, tree, pot, left, right, ground }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        above = try? c.decodeIfPresent(String.self, forKey: .above)
        sky = try? c.decodeIfPresent(String.self, forKey: .sky)
        weather = try? c.decodeIfPresent(String.self, forKey: .weather)
        tree = (try? c.decodeIfPresent([String].self, forKey: .tree)) ?? []
        pot = try? c.decodeIfPresent(String.self, forKey: .pot)
        left = try? c.decodeIfPresent(String.self, forKey: .left)
        right = try? c.decodeIfPresent(String.self, forKey: .right)
        ground = try? c.decodeIfPresent(String.self, forKey: .ground)
    }

    public var above: String?
    public var sky: String?
    public var weather: String?
    public var tree: [String] = []
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
        [above, sky, weather, pot, left, right, ground].compactMap { $0 } + tree
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
