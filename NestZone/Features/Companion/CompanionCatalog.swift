import Foundation

// The catalog: everything a house can grow, put out and collect, and how each
// thing is had — free, bought from the jar, in a pack, in its season, with a
// holiday, or earned. One list, read by Choose, Decorate and the shop, and the
// one the server version will serve.
//
// Most of it is not drawn yet. A species or a decoration without its drawing
// stands in as its emoji (`Species.art`, `GraphicsContext.sketch`) until the
// art pass, so the whole catalog can be tried now.

// MARK: - How a thing is had

/// How a thing is had. Everything is had exactly one way, and anything with a
/// price has one price, in one currency.
public enum Access: Equatable, Sendable {
    /// Every house has it from the start.
    case free
    /// Bought from the jar and kept for good.
    case buy(Price)
    /// Bought with the rest of its pack.
    case pack(SpeciesPack)
    /// A species anyone can start while its season lasts. Never sold.
    case season(Season)
    /// Free while a holiday that brings it lasts, and never sold: the days of
    /// a faith get free things only.
    case holiday
    /// Free while a holiday that brings it lasts, and on sale then to keep for
    /// good — a Halloween pumpkin, New Year's baubles. Only a holiday that
    /// isn't a faith's puts it on sale.
    case holidaySale(Price)
    /// On sale only in its season, then kept: watermelon in summer.
    case seasonSale(Price, Season)
    /// Earned, never sold.
    case reward(Reward)
}

/// What earns a thing.
public enum Reward: Equatable, Sendable {
    /// This many companions grown all the way.
    case graduations(Int)
    /// A birthday in the house's calendar: free on the day.
    case birthday
    /// Every species a house can have without paying, grown: the finale.
    case grownAll
}

/// When a seasonal thing is around: a run of months, turned round where
/// December is summer when it follows nature rather than a date on the
/// calendar.
public struct Season: Equatable, Sendable {
    /// Months, 1…12, in the order they come; a season across the new year
    /// wraps (12, 1).
    public let months: [Int]
    /// Spring flowers come in September south of the equator; a pumpkin for
    /// Halloween does not move.
    public let followsNature: Bool

    public static let spring = Season(months: [3, 4, 5], followsNature: true)
    public static let summer = Season(months: [6, 7, 8], followsNature: true)

    public func months(southern: Bool) -> [Int] {
        guard southern, followsNature else { return months }
        return months.map { ($0 + 5) % 12 + 1 }
    }

    public func contains(_ date: Date, southern: Bool, calendar: Calendar = .current) -> Bool {
        months(southern: southern).contains(calendar.component(.month, from: date))
    }

    /// The month it comes back in, as a date on its first day, for "back in
    /// March".
    public func returns(after date: Date, southern: Bool, calendar: Calendar = .current) -> Date? {
        guard let first = months(southern: southern).first else { return nil }
        let year = calendar.component(.year, from: date)
        return [year, year + 1]
            .compactMap { calendar.date(from: DateComponents(year: $0, month: first, day: 1)) }
            .first { $0 > date }
    }
}

/// Pets sold together, for one price.
public enum SpeciesPack: String, CaseIterable, Codable, Identifiable, Sendable {
    case forestFriends, snowFriends

    public var id: String { rawValue }
    public var price: Price { .sparkles(900) }
    public var species: [Species] { Species.allCases.filter { $0.access == .pack(self) } }
}

/// Something the jar can buy.
public enum ShopItem: Hashable, Sendable {
    case decor(DecorItem)
    case species(Species)
    case pack(SpeciesPack)
}

// MARK: - Species

extension Species {
    public var access: Access {
        switch self {
        case .magnolia, .basil, .sunflower, .cactus, .duckling, .kitten: .free
        case .daisy: .buy(.leaves(120))
        case .mint, .rosemary, .snakePlant: .buy(.leaves(150))
        case .fern: .buy(.leaves(180))
        case .lavender: .buy(.leaves(200))
        case .azalea, .peony: .buy(.leaves(250))
        case .pomegranate, .goldfish: .buy(.leaves(300))
        case .hamster: .buy(.leaves(350))
        case .turtle: .buy(.leaves(400))
        case .rose: .buy(.sparkles(350))
        case .lemon: .buy(.sparkles(400))
        case .orchid: .buy(.sparkles(450))
        case .bonsai, .puppy: .buy(.sparkles(600))
        case .fox, .owl, .deer: .pack(.forestFriends)
        case .penguin, .snowFox, .polarCub: .pack(.snowFriends)
        case .cherry: .season(.spring)
        case .tulip: .season(Season(months: [3, 4], followsNature: true))
        case .maple: .season(Season(months: [9, 10, 11], followsNature: true))
        case .snowdrop: .season(Season(months: [1, 2], followsNature: true))
        // Kept to their days on the calendar: Halloween's, the new year's, Easter's.
        case .pumpkin: .season(Season(months: [10, 11], followsNature: false))
        case .pine: .season(Season(months: [12, 1], followsNature: false))
        case .bunny: .season(Season(months: [3, 4], followsNature: false))
        case .monstera: .reward(.graduations(1))
        case .hedgehog: .reward(.graduations(2))
        case .olive: .reward(.graduations(3))
        }
    }

    /// What the finale counts: everything a house can grow without paying.
    /// Bought with Sparkles or in a pack never counts, so buying can't push
    /// the crown further away.
    public static let freeToHave: Set<Species> = Set(allCases.filter { species in
        switch species.access {
        case .free, .season, .reward, .buy(.leaves): true
        default: false
        }
    })
}

// MARK: - Decorations

extension DecorItem {
    public var access: Access {
        switch self {
        case .windowsill, .wateringCan: .free
        case .bow: .buy(.leaves(60))
        case .terracotta: .buy(.leaves(80))
        case .bunting, .scarf: .buy(.leaves(100))
        case .glazedPot, .windChime: .buy(.leaves(120))
        case .fairyLights: .buy(.leaves(150))
        case .birdFeeder: .buy(.leaves(200))
        case .kilim: .buy(.leaves(250))
        case .balcony: .buy(.leaves(300))
        case .paperLantern: .buy(.sparkles(120))
        case .dusk: .buy(.sparkles(160))
        case .goldPot: .buy(.sparkles(240))
        case .starryRooftop: .buy(.sparkles(500))
        case .giftBox: .holidaySale(.sparkles(100))
        case .pumpkin, .bats, .treeStar: .holidaySale(.sparkles(120))
        case .ornaments: .holidaySale(.sparkles(150))
        case .fullMoon, .winterSky: .holidaySale(.sparkles(200))
        case .watermelon: .seasonSale(.sparkles(120), .summer)
        case .partyHat: .reward(.birthday)
        case .tinyCrown: .reward(.grownAll)
        default: .holiday
        }
    }

    /// What it costs from the jar, in exactly one currency, whenever it is on
    /// sale. Holiday things that are only ever free have none; nor does what
    /// every house has, or what is earned.
    public var price: Price? {
        switch access {
        case let .buy(price), let .holidaySale(price), let .seasonSale(price, _): price
        default: nil
        }
    }
}

extension Holiday {
    /// Whether this holiday puts its things on sale: a faith's days bring free
    /// things only.
    var sells: Bool { family == .worldwide || family == .national }
}

// MARK: - Where a thing stands for one house today

/// Everything that decides what a house can have today, worked out once and
/// read for every item on a shelf: today's holidays are a few calendar
/// conversions each, too many to repeat per tile.
public struct ShopContext: Sendable {
    public var clock: Date
    public var southern: Bool
    public var owned: Set<String>
    public var ownedSpecies: Set<String>
    /// How many the house has graduated, and which species those were: the
    /// count comes with every read, the species with the album's cards.
    public var albumCount: Int
    public var grown: Set<Species>
    public var holidays: [Holiday]
    public var isBirthday: Bool
    /// For working out a holiday's dates: some move by country.
    public var region: String? = nil

    /// What a thing comes to for this house today.
    public func standing(of item: ShopItem) -> Standing {
        switch item {
        case let .decor(decor): standing(of: decor)
        case let .species(species): standing(of: species)
        case let .pack(pack):
            pack.species.allSatisfy { ownedSpecies.contains($0.rawValue) } ? .have : .buy(pack.price)
        }
    }

    public func standing(of species: Species) -> Standing {
        switch species.access {
        case .free: return .free
        case let .buy(price):
            return ownedSpecies.contains(species.rawValue) ? .have : .buy(price)
        case let .pack(pack):
            return ownedSpecies.contains(species.rawValue) ? .have : .buy(pack.price)
        case let .season(season):
            return season.contains(clock, southern: southern) ? .freeToday : .locked(.season(season))
        case let .reward(reward):
            return earned(reward) ? .have : .locked(.reward(reward))
        case .holiday, .holidaySale, .seasonSale:
            return .locked(.holiday(nil))
        }
    }

    public func standing(of decor: DecorItem) -> Standing {
        let freeToday = brings(decor)
        switch decor.access {
        case .free: return .free
        case let .buy(price):
            if owned.contains(decor.rawValue) { return .have }
            // Fairy lights for Diwali, a lantern for Lunar New Year: an
            // everyday thing a holiday brings is free while it lasts.
            return freeToday ? .sale(price, freeToday: true) : .buy(price)
        case .holiday:
            return freeToday ? .freeToday : .locked(.holiday(firstHoliday(bringing: decor)))
        case let .holidaySale(price):
            if owned.contains(decor.rawValue) { return .have }
            if holidays.contains(where: { $0.sells && $0.decor.contains(.item(decor)) }) { return .sale(price, freeToday: freeToday) }
            return freeToday ? .freeToday : .locked(.holiday(firstHoliday(bringing: decor)))
        case let .seasonSale(price, season):
            if owned.contains(decor.rawValue) { return .have }
            return season.contains(clock, southern: southern) ? .sale(price, freeToday: false) : .locked(.season(season))
        case let .reward(reward):
            guard earned(reward) else { return .locked(.reward(reward)) }
            return reward == .birthday ? .freeToday : .have
        case .season, .pack:
            return .locked(.holiday(nil))
        }
    }

    /// The last day a holiday thing is on sale: its holiday's last day. Said
    /// plainly on the card ("Till 31 Oct"); never a countdown.
    public func saleEnds(_ decor: DecorItem, calendar: Calendar = .current) -> Date? {
        holidays.filter { $0.sells && $0.decor.contains(.item(decor)) }
            .compactMap { $0.window(around: clock, region: region, calendar: calendar)?.end }
            .max()
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
    }

    /// Whether today's holidays bring it. Snow stays out where December is
    /// summer.
    func brings(_ decor: DecorItem) -> Bool {
        if decor.isWintry, southern { return false }
        return holidays.contains { $0.decor.contains(.item(decor)) }
    }

    func earned(_ reward: Reward) -> Bool {
        switch reward {
        case let .graduations(count): albumCount >= count
        case .birthday: isBirthday
        case .grownAll: Species.freeToHave.isSubset(of: grown)
        }
    }

    /// The holiday to name on something that comes with one: the first in
    /// the list that brings it.
    private func firstHoliday(bringing decor: DecorItem) -> Holiday.ID? {
        Holiday.all.first { $0.decor.contains(.item(decor)) }?.id
    }
}

/// Where a thing stands for a house today.
public enum Standing: Equatable, Sendable {
    /// Every house has it.
    case free
    /// This house has it: bought, or earned for good.
    case have
    /// Free for today only — a holiday's, a season's, a birthday's.
    case freeToday
    /// For sale.
    case buy(Price)
    /// On sale while its holiday or season lasts, to keep for good; perhaps
    /// free to put out today as well.
    case sale(Price, freeToday: Bool)
    /// Not to be had today.
    case locked(Lock)

    public enum Lock: Equatable, Sendable {
        case season(Season)
        case holiday(Holiday.ID?)
        case reward(Reward)
    }

    /// Whether it can go in the scene, or be grown, today without buying.
    public var isUsable: Bool {
        switch self {
        case .free, .have, .freeToday, .sale(_, freeToday: true): true
        default: false
        }
    }

    public var isLocked: Bool {
        if case .locked = self { true } else { false }
    }

    /// What buying it would cost, if it can be bought today.
    public var price: Price? {
        switch self {
        case let .buy(price), let .sale(price, _): price
        default: nil
        }
    }
}

// MARK: - Paying

/// Making up a Leaves price with Sparkles when the jar's Leaves run short.
///
/// Leaves are never sold. But a house 40 Leaves short of something can make up
/// the 40 with Sparkles it has — at one for one, which is easy to say and to
/// check, and which never makes saving the worse deal: earned, a Sparkle comes
/// three times slower than a Leaf. Sparkles are never made up with Leaves —
/// progress doesn't buy what money does.
public enum Exchange {
    public static let leavesPerSparkle = 1

    /// The Sparkles that make up for this many Leaves, rounded up.
    public static func sparkles(forLeaves leaves: Int) -> Int {
        (max(leaves, 0) + leavesPerSparkle - 1) / leavesPerSparkle
    }
}

/// What paying for something from the jar comes to.
public enum Checkout: Equatable, Sendable {
    /// The jar has it, in the thing's own currency.
    case pay(Coins)
    /// The Leaves are short by `short`, and the jar's Sparkles make up the
    /// rest: `coins` is all of it.
    case makeUp(Coins, short: Int)
    /// Not enough even so; this many Sparkles more would do it.
    case short(sparkles: Int)
}

extension CompanionHouse {
    public func checkout(_ price: Price) -> Checkout {
        // A refunded top-up can take the jar below zero; nothing below zero
        // pays for anything.
        let leaves = max(self.leaves, 0), sparkles = max(self.sparkles, 0)
        switch price {
        case let .leaves(amount):
            if leaves >= amount { return .pay(Coins(leaves: amount, sparkles: 0)) }
            let short = amount - leaves
            let makeUp = Exchange.sparkles(forLeaves: short)
            if sparkles >= makeUp { return .makeUp(Coins(leaves: leaves, sparkles: makeUp), short: short) }
            return .short(sparkles: makeUp - sparkles)
        case let .sparkles(amount):
            if sparkles >= amount { return .pay(Coins(leaves: 0, sparkles: amount)) }
            return .short(sparkles: amount - sparkles)
        }
    }

    public mutating func pay(_ coins: Coins) {
        leaves -= coins.leaves
        sparkles -= coins.sparkles
    }

    /// Puts what was bought in the house.
    public mutating func receive(_ item: ShopItem) {
        switch item {
        case let .decor(decor): owned.insert(decor.rawValue)
        case let .species(species): ownedSpecies.insert(species.rawValue)
        case let .pack(pack): ownedSpecies.formUnion(pack.species.map(\.rawValue))
        }
    }
}

extension ShopItem {
    /// What the shop asks for it: a species in a pack is bought with its pack.
    public var price: Price? {
        switch self {
        case let .decor(decor): decor.price
        case let .species(species):
            switch species.access {
            case let .buy(price): price
            case let .pack(pack): pack.price
            default: nil
            }
        case let .pack(pack): pack.price
        }
    }

    /// What is actually bought: a pet from a pack comes with the pack.
    public var bought: ShopItem {
        if case let .species(species) = self, case let .pack(pack) = species.access { return .pack(pack) }
        return self
    }
}

// MARK: - Sparkles for the jar

/// A pack of Sparkles on the shelf.
public struct SparklePack: Equatable, Identifiable, Sendable {
    /// The App Store product.
    public var id: String
    public var sparkles: Int
    /// The price in the person's own storefront and currency, as the store
    /// gives it; `nil` on the test store, which charges nothing.
    public var displayPrice: String?
    /// The same price as a number, to compare packs by.
    public var price: Decimal?

    public init(id: String, sparkles: Int, displayPrice: String?, price: Decimal? = nil) {
        self.id = id
        self.sparkles = sparkles
        self.displayPrice = displayPrice
        self.price = price
    }

    /// The four packs, before any store prices them: 300, 1,000, 2,200 and
    /// 5,000 (still open in Docs/Companion/HANDOFF.md). The test store
    /// compares them at example prices, which it never shows or charges.
    public static let shelf: [SparklePack] = zip([300, 1_000, 2_200, 5_000], [Decimal(string: "2.99"), Decimal(string: "8.99"), Decimal(string: "17.99"), Decimal(string: "34.99")]).map {
        SparklePack(id: "com.walhallaa.NestZone.sparkles.\($0)", sparkles: $0, displayPrice: nil, price: $1)
    }

    /// The one pack that is cheapest per Sparkle, if the store priced them
    /// all. Worked out, never declared: a tag nobody can check is a nudge.
    public static func bestValue(_ packs: [SparklePack]) -> SparklePack.ID? {
        let priced = packs.compactMap { pack in pack.price.map { (pack.id, $0 / Decimal(pack.sparkles)) } }
        guard priced.count == packs.count, packs.count > 1 else { return nil }
        return priced.min { $0.1 < $1.1 }?.0
    }
}

// MARK: - Which catalog this is

/// The catalog the server was last told about by this file.
///
/// `companion:forHome` sends the version of the catalog it prices from
/// (`catalogVersion`: the generated file's hash, `-r`, the rules' version). A
/// build that differs logs it, and the server's prices win either way. The next
/// line is rewritten by `Docs/Companion/tools/catalog_export/export_catalog.sh`
/// when it regenerates `companionData.ts`; do not edit it by hand.
public enum CatalogVersion {
    public static let exported = "79790c743d93-r1"
}
