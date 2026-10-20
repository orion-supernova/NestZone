import ComposableArchitecture
import Foundation
import Testing
@testable import NestZone

/// The companion's logic: holiday dates, growth, moods, and where decorations
/// go. The dates are the ones checked against official sources in
/// Docs/Companion/HOLIDAYS.md.
@Suite("Companion")
struct CompanionTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    private func day(_ holiday: Holiday.ID, _ year: Int, region: String? = "TR") -> String? {
        guard let date = Holiday.with(holiday)?.start(in: year, region: region, calendar: Self.calendar) else { return nil }
        let parts = Self.calendar.dateComponents([.month, .day], from: date)
        return String(format: "%02d-%02d", parts.month ?? 0, parts.day ?? 0)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: Holidays

    @Test("Easter, Western and Orthodox, from the computus")
    func easter() {
        // Stored as Good Friday, two days before Easter Sunday.
        #expect(day(.easter, 2026) == "04-03")
        #expect(day(.easter, 2027) == "03-26")
        #expect(day(.orthodoxEaster, 2026) == "04-10")
        #expect(day(.orthodoxEaster, 2027) == "04-30")
    }

    @Test("Islamic days match the Umm al-Qura calendar and Diyanet")
    func islamic() {
        #expect(day(.ramadan, 2026) == "02-18")
        #expect(day(.eidAlFitr, 2026) == "03-20")
        #expect(day(.eidAlFitr, 2027) == "03-09")
        #expect(day(.eidAlAdha, 2026) == "05-27")
        #expect(day(.eidAlAdha, 2027) == "05-16")
    }

    @Test("Jewish days, with Purim in Adar II in a leap year")
    func jewish() {
        #expect(day(.roshHashanah, 2026) == "09-12")
        #expect(day(.hanukkah, 2026) == "12-05")
        #expect(day(.passover, 2026) == "04-02")
        #expect(day(.purim, 2026) == "03-03")
        #expect(day(.purim, 2027) == "03-23")
    }

    @Test("Chinese and Persian calendar days")
    func lunarAndSolar() {
        #expect(day(.lunarNewYear, 2026) == "02-17")
        #expect(day(.lunarNewYear, 2027) == "02-06")
        #expect(day(.midAutumn, 2026) == "09-25")
        #expect(day(.nowruz, 2026) == "03-21")
    }

    @Test("Almanac days come from the table, and a year it lacks has none")
    func tables() {
        #expect(day(.diwali, 2026) == "11-08")
        #expect(day(.holi, 2027) == "03-23")
        #expect(day(.diwali, 2031) == nil)
        // Singapore keeps Vesak on the Chinese 4/15; India by its almanac.
        #expect(day(.vesak, 2026, region: "SG") == "05-31")
        #expect(day(.vesak, 2026, region: "IN") == "05-01")
    }

    @Test("Mother's Day follows the country")
    func regional() {
        #expect(day(.mothersDay, 2026, region: "TR") == "05-10")
        #expect(day(.mothersDay, 2026, region: "GB") == "03-15")
        #expect(day(.mothersDay, 2026, region: "FR") == "05-31")
        #expect(day(.fathersDay, 2026, region: "AU") == "09-06")
    }

    @Test("A holiday dresses the scene from its lead days until it ends")
    func window() {
        let ids: Set<Holiday.ID> = [.newYear, .halloween]
        let december = Holiday.active(on: date(2026, 12, 20), among: ids, region: "TR", calendar: Self.calendar)
        #expect(december.map(\.id) == [.newYear])
        let afterwards = Holiday.active(on: date(2027, 1, 3), among: ids, region: "TR", calendar: Self.calendar)
        #expect(afterwards.isEmpty)
        #expect(Holiday.defaults(for: "TR").contains(.eidAlFitr))
        #expect(Holiday.isSouthern("AU"))
    }

    // MARK: Growth and mood

    @Test("Chores count from when it arrived, capped per day")
    func growth() {
        let start = date(2026, 10, 1, 0)
        let busy = (0..<15).map { Completion(at: date(2026, 10, 2, 8 + $0 % 10), by: "u1") }
        let before = Completion(at: date(2026, 9, 30), by: "u1")
        let points = CompanionMath.chorePoints(busy + [before], since: start, calendar: Self.calendar)
        #expect(points == Double(CompanionMath.dayCap))
    }

    @Test("Quiet days make it thirsty, a week makes it doze, two people make it bright")
    func mood() {
        let start = date(2026, 10, 1)
        let now = date(2026, 10, 20)
        func mood(_ completions: [Completion], members: Int = 2) -> Mood {
            CompanionMath.mood(now: now, completions: completions, lastCare: nil, startedAt: start,
                               memberCount: members, calendar: Self.calendar)
        }
        #expect(mood([Completion(at: date(2026, 10, 16), by: "u1")]) == .thirsty)
        #expect(mood([Completion(at: date(2026, 10, 10), by: "u1")]) == .dozing)
        #expect(mood([Completion(at: date(2026, 10, 19), by: "u1"), Completion(at: date(2026, 10, 20, 9), by: "u2")]) == .bright)
        #expect(mood([Completion(at: date(2026, 10, 19), by: "u1")]) == .content)
    }

    @Test("Stages follow progress")
    func stages() {
        #expect(CompanionMath.stage(progress: 0, isPet: false) == 0)
        #expect(CompanionMath.stage(progress: 0.5, isPet: false) == 3)
        #expect(CompanionMath.stage(progress: 0.99, isPet: true) == 6)
    }

    // MARK: Decorating

    @Test("One thing per spot, up to four on the tree, and a floor thing moves sides")
    func layout() {
        var layout = SceneLayout()
        layout.toggle("pumpkin", in: .left)
        layout.toggle("pumpkin", in: .right)
        #expect(layout.left == nil && layout.right == "pumpkin")
        for item in ["fairyLights", "ornaments", "treeStar", "wishNotes", "bunting"] { layout.toggle(item, in: .tree) }
        #expect(layout.tree.count == SceneLayout.treeLimit)
        layout.toggle("ornaments", in: .tree)
        #expect(!layout.tree.contains("ornaments"))
    }

    @Test("Putting a holiday out does not swap its own things for each other")
    func dress() throws {
        var layout = SceneLayout()
        layout.above = "bunting"
        let halloween = try #require(Holiday.with(.halloween))
        layout.dress(for: halloween, southern: false, isPet: false)
        #expect(layout.above == "bats")
        #expect(layout.left == "pumpkin")
        #expect(layout.sky == "fullMoon")
        var again = layout
        again.dress(for: halloween, southern: false, isPet: false)
        #expect(again == layout)
    }

    @Test("A house keeps its pot: the same seed, the same colour and band as before the tree was redrawn")
    func pot() {
        let first = PotStyle(seed: "x-0"), second = PotStyle(seed: "k17cheh68tdhjdh90n37jnakn18dp9gt-0")
        #expect([first.h, first.s, first.l] == [152, 22, 48] && first.band == 1)
        #expect([second.h, second.s, second.l] == [262, 28, 58] && second.band == 2)
    }

    @Test("Choosing another species with the same seed grows that species' tree")
    func sameSeedNewSpecies() {
        // A new companion keeps the old seed until something graduates; the
        // pomegranate chosen after a lemon once kept drawing the lemon.
        #expect(Canopy(seed: "h-0", species: .lemon) != Canopy(seed: "h-0", species: .pomegranate))
        let crowns = CrownCache()
        let lemon = crowns.anchors(Canopy(seed: "h-0", species: .lemon), progress: 0.97, mood: 0.9)
        let pomegranate = crowns.anchors(Canopy(seed: "h-0", species: .pomegranate), progress: 0.97, mood: 0.9)
        #expect(lemon != pomegranate)
    }

    @Test("The welcome gift buys a first thing in each currency, with some left over")
    func welcomeGift() {
        let prices = DecorItem.allCases.compactMap(\.price)
        let cheapestLeaves = prices.compactMap { if case let .leaves(amount) = $0 { amount } else { nil } }.min() ?? 0
        let cheapestSparkles = prices.compactMap { if case let .sparkles(amount) = $0 { amount } else { nil } }.min() ?? 0
        #expect(cheapestLeaves > 0 && cheapestSparkles > 0)
        #expect(Rewards.welcome.leaves > cheapestLeaves)
        #expect(Rewards.welcome.sparkles > cheapestSparkles)
        var house = CompanionHouse()
        house.add(Rewards.welcome)
        house.pay(.sparkles(cheapestSparkles))
        #expect(house.sparkles > 0)
        #expect(!house.canAfford(.sparkles(Rewards.welcome.sparkles)))
    }

    @Test("A saved house with fields missing still opens")
    func lenientDecoding() throws {
        let json = #"{"jar": 40, "album": [], "current": {"species": "magnolia", "seed": "h-0", "startedAt": 0}}"#
        let house = try JSONDecoder().decode(CompanionHouse.self, from: Data(json.utf8))
        // The file's "jar" was the Leaves balance before Sparkles joined it.
        #expect(house.leaves == 40)
        #expect(house.sparkles == 0)
        #expect(!house.welcomed)
        #expect(house.current?.species == .magnolia)
        #expect(house.owned.contains("wateringCan"))
        #expect(house.layout.tree.isEmpty)
    }
}
