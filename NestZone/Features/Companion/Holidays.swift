import Foundation
import Synchronization

/// The days a household can celebrate, from every calendar that has them.
///
/// Most are worked out rather than listed: a fixed day, "the second Sunday of
/// May", an offset from Easter, or a day in the Islamic, Hebrew, Chinese or
/// Persian calendar, which Foundation already knows how to convert. Only the
/// Hindu, Sikh and Buddhist days that follow a lunisolar almanac Foundation
/// does not carry come from a table, and the table says which years it covers
/// — an unknown year simply has no occurrence, rather than a guessed one.
///
/// Solemn days (Yom Kippur, Ashura, Good Friday on its own) are deliberately
/// not here. The scene only ever dresses up, and dressing up for a fast is
/// worse than saying nothing.
public struct Holiday: Identifiable, Equatable, Sendable {
    public let id: ID
    public let family: Family
    let rule: Rule
    /// How many days it lasts, counting the first.
    let days: Int
    /// How many days before it the scene starts dressing for it — December's
    /// tree goes up long before the first of January.
    let lead: Int
    /// A single emoji for chips and lists.
    public let symbol: String
    /// What it puts in the scene while it lasts, free.
    public let decor: [Decor]
    /// The colours its string of flags is made of, for the days that have
    /// colours of their own (a flag, a festival).
    public let colors: [UInt32]

    public enum Family: String, CaseIterable, Identifiable, Sendable {
        case worldwide, christian, muslim, jewish, hindu, sikh, buddhist, eastAsian, persian, turkish, national
        public var id: String { rawValue }
    }

    public enum ID: String, CaseIterable, Codable, Sendable {
        // Worldwide and cultural
        case newYear, valentines, womensDay, stPatricks, carnival, earthDay, mothersDay, fathersDay
        case midsummer, halloween, dayOfTheDead, bonfireNight, thanksgivingUS, thanksgivingCA, kwanzaa
        // Christian
        case epiphany, orthodoxChristmas, easter, orthodoxEaster, christmas
        // Muslim
        case ramadan, eidAlFitr, eidAlAdha, islamicNewYear, mawlid
        // Jewish
        case roshHashanah, sukkot, hanukkah, purim, passover
        // Hindu, Sikh, Buddhist
        case makarSankranti, holi, diwali, vaisakhi, guruNanakJayanti, vesak
        // East Asian
        case lunarNewYear, dragonBoat, tanabata, midAutumn
        // Persian
        case nowruz, yalda
        // Turkish
        case hidirellez, childrensDayTR, republicDayTR
        // National days with a party
        case canadaDay, independenceUS, bastilleDay, independenceMX
    }

    indirect enum Rule: Equatable, Sendable {
        case fixed(month: Int, day: Int)
        /// The `ordinal`th `weekday` (1 = Sunday) of `month`; -1 is the last.
        case weekday(month: Int, weekday: Int, ordinal: Int)
        /// The first `weekday` on or after a day.
        case weekdayOnOrAfter(month: Int, day: Int, weekday: Int)
        /// Days from Western Easter Sunday.
        case easter(offset: Int)
        /// Days from Orthodox Easter Sunday.
        case orthodoxEaster(offset: Int)
        /// A day in another calendar. For the Hebrew calendar Foundation
        /// numbers Tishrei 1 and Nisan 8, and Adar is always 7 — Adar II in a
        /// leap year, which is the one Purim is kept in.
        case lunar(Calendar.Identifier, month: Int, day: Int)
        /// A verified table, year → (month, day). Years it does not list have
        /// no occurrence.
        case table([Int: MonthDay])
        /// A different rule in some regions.
        case regional([String: Rule], otherwise: Rule)
    }

    struct MonthDay: Equatable, Sendable {
        let month: Int
        let day: Int
        init(_ month: Int, _ day: Int) { self.month = month; self.day = day }
    }
}

// MARK: - Occurrences

extension Holiday {
    /// The first day of this holiday in a Gregorian year, at the start of the
    /// local day.
    func start(in year: Int, region: String?, calendar: Calendar = .current) -> Date? {
        Self.resolve(rule, year: year, region: region, calendar: calendar)
    }

    /// When the scene dresses for it around `date`: from `lead` days before the
    /// first day to the end of the last.
    public func window(around date: Date, region: String?, calendar: Calendar = .current) -> DateInterval? {
        let year = calendar.component(.year, from: date)
        for candidate in [year - 1, year, year + 1] {
            guard let first = start(in: candidate, region: region, calendar: calendar),
                  let opens = calendar.date(byAdding: .day, value: -lead, to: first),
                  let closes = calendar.date(byAdding: .day, value: days, to: first)
            else { continue }
            if date >= opens, date < closes { return DateInterval(start: opens, end: closes) }
        }
        return nil
    }

    /// The first day of the next occurrence on or after `date`'s day.
    public func next(after date: Date, region: String?, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: date)
        return [year, year + 1, year + 2]
            .compactMap { start(in: $0, region: region, calendar: calendar) }
            .first { $0 >= today }
    }

    /// Whether `date` falls on the holiday itself rather than in the days
    /// leading up to it.
    public func isUnderway(on date: Date, region: String?, calendar: Calendar = .current) -> Bool {
        let year = calendar.component(.year, from: date)
        for candidate in [year - 1, year] {
            guard let first = start(in: candidate, region: region, calendar: calendar),
                  let last = calendar.date(byAdding: .day, value: days, to: first)
            else { continue }
            if date >= first, date < last { return true }
        }
        return false
    }

    private static func resolve(_ rule: Rule, year: Int, region: String?, calendar: Calendar) -> Date? {
        func day(_ month: Int, _ day: Int) -> Date? {
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
        switch rule {
        case let .fixed(month, d):
            return day(month, d)
        case let .weekday(month, weekday, ordinal):
            var components = DateComponents(year: year, month: month, weekday: weekday)
            components.weekdayOrdinal = ordinal
            if ordinal > 0 { return calendar.date(from: components) }
            // The last one: step back from the first of next month.
            guard let first = day(month, 1),
                  let next = calendar.date(byAdding: .month, value: 1, to: first)
            else { return nil }
            var date = calendar.date(byAdding: .day, value: -1, to: next)
            while let current = date, calendar.component(.weekday, from: current) != weekday {
                date = calendar.date(byAdding: .day, value: -1, to: current)
            }
            return date
        case let .weekdayOnOrAfter(month, d, weekday):
            guard var date = day(month, d) else { return nil }
            while calendar.component(.weekday, from: date) != weekday {
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
                date = next
            }
            return date
        case let .easter(offset):
            let (month, d) = westernEaster(year)
            return day(month, d).flatMap { calendar.date(byAdding: .day, value: offset, to: $0) }
        case let .orthodoxEaster(offset):
            let (month, d) = orthodoxEaster(year)
            return day(month, d).flatMap { calendar.date(byAdding: .day, value: offset, to: $0) }
        case let .lunar(identifier, month, d):
            return LunarIndex.date(identifier, month: month, day: d, inGregorianYear: year, calendar: calendar)
        case let .table(dates):
            guard let date = dates[year] else { return nil }
            return day(date.month, date.day)
        case let .regional(rules, otherwise):
            let chosen = region.flatMap { rules[$0] } ?? otherwise
            return resolve(chosen, year: year, region: region, calendar: calendar)
        }
    }

    /// Western Easter Sunday: the anonymous Gregorian computus.
    static func westernEaster(_ year: Int) -> (month: Int, day: Int) {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return (month, day)
    }

    /// Orthodox Easter Sunday: the Julian computus, moved onto the Gregorian
    /// calendar (13 days apart from 1900 to 2099).
    static func orthodoxEaster(_ year: Int) -> (month: Int, day: Int) {
        let a = year % 4, b = year % 7, c = year % 19
        let d = (19 * c + 15) % 30
        let e = (2 * a + 4 * b - d + 34) % 7
        let month = (d + e + 114) / 31
        let day = (d + e + 114) % 31 + 1
        var components = DateComponents(year: year, month: month, day: day)
        components.calendar = Calendar(identifier: .gregorian)
        let julian = Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
        let moved = julian.addingTimeInterval(13 * 24 * 3600)
        let parts = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: moved)
        return (parts.month ?? month, parts.day ?? day)
    }
}

/// Finds a day of another calendar inside a Gregorian year.
///
/// By walking the year a day at a time and asking each day what it is in the
/// other calendar, rather than building the date from that calendar's own
/// year number: the Chinese calendar counts years in sixty-year cycles under an
/// era, and an Islamic year starts eleven days earlier every Gregorian year, so
/// "which of its years overlap this one" is a question with edge cases. A walk
/// has none, costs 365 conversions, and is done once per calendar per year.
enum LunarIndex {
    private static let cache = Mutex<[String: [String: Date]]>([:])

    static func date(
        _ identifier: Calendar.Identifier,
        month: Int,
        day: Int,
        inGregorianYear year: Int,
        calendar: Calendar
    ) -> Date? {
        let key = "\(identifier)-\(year)-\(calendar.timeZone.identifier)"
        if let days = cache.withLock({ $0[key] }) { return days["\(month)-\(day)"] }
        var other = Calendar(identifier: identifier)
        other.timeZone = calendar.timeZone
        var days: [String: Date] = [:]
        guard var date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        while calendar.component(.year, from: date) == year {
            let parts = other.dateComponents([.month, .day, .isLeapMonth], from: date)
            // A leap month repeats a month number (Chinese); the holiday is in
            // the ordinary one.
            if parts.isLeapMonth != true, let m = parts.month, let d = parts.day {
                let slot = "\(m)-\(d)"
                if days[slot] == nil { days[slot] = date }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        cache.withLock { $0[key] = days }
        return days["\(month)-\(day)"]
    }
}

// MARK: - The catalogue

extension Holiday {
    /// Every holiday, family by family. Split into typed lists only so the
    /// compiler can check them in reasonable time.
    public static let all: [Holiday] = worldwide + christian + muslim + jewish + dharmic + eastAsian + persian + turkish + national

    static let worldwide: [Holiday] = [
        Holiday(id: .newYear, family: .worldwide, rule: .fixed(month: 1, day: 1), days: 1, lead: 24, symbol: "🎆",
                decor: [.item(.fireworks), .item(.fairyLights), .item(.ornaments), .item(.treeStar), .item(.giftBox), .item(.snowfall),
                        .item(.winterSky)], colors: []),
        Holiday(id: .valentines, family: .worldwide, rule: .fixed(month: 2, day: 14), days: 1, lead: 6, symbol: "💕",
                decor: [.item(.heartGarland), .item(.bouquet)], colors: []),
        Holiday(id: .womensDay, family: .worldwide, rule: .fixed(month: 3, day: 8), days: 1, lead: 0, symbol: "💐",
                decor: [.item(.bouquet)], colors: []),
        Holiday(id: .stPatricks, family: .worldwide, rule: .fixed(month: 3, day: 17), days: 1, lead: 3, symbol: "☘️",
                decor: [.item(.shamrocks)], colors: []),
        Holiday(id: .carnival, family: .worldwide, rule: .easter(offset: -52), days: 6, lead: 0, symbol: "🎭",
                decor: [.item(.confetti), .flags(.carnival)], colors: [0x9B5DE5, 0xF15BB5, 0xFEE440, 0x00BBF9, 0x00F5D4]),
        Holiday(id: .earthDay, family: .worldwide, rule: .fixed(month: 4, day: 22), days: 1, lead: 0, symbol: "🌍",
                decor: [.item(.petals)], colors: []),
        Holiday(id: .mothersDay, family: .worldwide, rule: .regional(mothersDayRules, otherwise: .weekday(month: 5, weekday: 1, ordinal: 2)),
                days: 1, lead: 1, symbol: "💐", decor: [.item(.bouquet)], colors: []),
        Holiday(id: .fathersDay, family: .worldwide, rule: .regional(fathersDayRules, otherwise: .weekday(month: 6, weekday: 1, ordinal: 3)),
                days: 1, lead: 1, symbol: "👔", decor: [.flags(.fathersDay)], colors: [0x1D4ED8, 0x93C5FD, 0xFFFFFF]),
        // Midsummer Eve, the Friday between 19 and 25 June.
        Holiday(id: .midsummer, family: .worldwide, rule: .weekdayOnOrAfter(month: 6, day: 19, weekday: 6), days: 2, lead: 1, symbol: "🌼",
                decor: [.item(.petals), .flags(.midsummer)], colors: [0x2563EB, 0xFACC15]),
        Holiday(id: .halloween, family: .worldwide, rule: .fixed(month: 10, day: 31), days: 1, lead: 10, symbol: "🎃",
                decor: [.item(.pumpkin), .item(.bats), .item(.fullMoon), .item(.spookyBunting)], colors: []),
        Holiday(id: .dayOfTheDead, family: .worldwide, rule: .fixed(month: 11, day: 1), days: 2, lead: 3, symbol: "💀",
                decor: [.item(.papelPicado), .item(.marigolds)], colors: []),
        Holiday(id: .bonfireNight, family: .worldwide, rule: .fixed(month: 11, day: 5), days: 1, lead: 1, symbol: "🎇",
                decor: [.item(.fireworks)], colors: []),
        Holiday(id: .thanksgivingUS, family: .worldwide, rule: .weekday(month: 11, weekday: 5, ordinal: 4), days: 1, lead: 4, symbol: "🦃",
                decor: [.item(.pumpkin), .item(.autumnLeaves)], colors: []),
        Holiday(id: .thanksgivingCA, family: .worldwide, rule: .weekday(month: 10, weekday: 2, ordinal: 2), days: 1, lead: 3, symbol: "🍁",
                decor: [.item(.pumpkin), .item(.autumnLeaves)], colors: []),
        Holiday(id: .kwanzaa, family: .worldwide, rule: .fixed(month: 12, day: 26), days: 7, lead: 0, symbol: "🕯️",
                decor: [.item(.kinara), .flags(.kwanzaa)], colors: [0xC0262D, 0x111111, 0x15803D]),
    ]

    static let christian: [Holiday] = [
        Holiday(id: .epiphany, family: .christian, rule: .fixed(month: 1, day: 6), days: 1, lead: 0, symbol: "👑",
                decor: [.item(.treeStar)], colors: []),
        Holiday(id: .orthodoxChristmas, family: .christian, rule: .fixed(month: 1, day: 7), days: 1, lead: 10, symbol: "🎄",
                decor: [.item(.ornaments), .item(.treeStar), .item(.giftBox), .item(.snowfall)], colors: []),
        // Good Friday to Easter Monday.
        Holiday(id: .easter, family: .christian, rule: .easter(offset: -2), days: 4, lead: 5, symbol: "🐣",
                decor: [.item(.eggBasket), .item(.petals), .flags(.easter)], colors: [0xFBCFE8, 0xBFDBFE, 0xFEF08A, 0xBBF7D0]),
        Holiday(id: .orthodoxEaster, family: .christian, rule: .orthodoxEaster(offset: -2), days: 4, lead: 5, symbol: "🥚",
                decor: [.item(.eggBasket), .item(.petals)], colors: []),
        Holiday(id: .christmas, family: .christian, rule: .fixed(month: 12, day: 25), days: 2, lead: 24, symbol: "🎄",
                decor: [.item(.ornaments), .item(.treeStar), .item(.giftBox), .item(.fairyLights), .item(.snowfall)], colors: []),
    ]

    /// Umm al-Qura; a country's own announcement can be a day apart.
    static let muslim: [Holiday] = [
        Holiday(id: .ramadan, family: .muslim, rule: .lunar(.islamicUmmAlQura, month: 9, day: 1), days: 29, lead: 1, symbol: "🌙",
                decor: [.item(.ramadanLantern), .item(.crescentGarland)], colors: []),
        Holiday(id: .eidAlFitr, family: .muslim, rule: .lunar(.islamicUmmAlQura, month: 10, day: 1), days: 3, lead: 0, symbol: "🍬",
                decor: [.item(.candyBowl), .item(.crescentGarland), .item(.fairyLights)], colors: []),
        Holiday(id: .eidAlAdha, family: .muslim, rule: .lunar(.islamicUmmAlQura, month: 12, day: 10), days: 4, lead: 1, symbol: "🌙",
                decor: [.item(.crescentGarland), .item(.ramadanLantern)], colors: []),
        Holiday(id: .islamicNewYear, family: .muslim, rule: .lunar(.islamicUmmAlQura, month: 1, day: 1), days: 1, lead: 0, symbol: "🌙",
                decor: [.item(.crescentGarland)], colors: []),
        Holiday(id: .mawlid, family: .muslim, rule: .lunar(.islamicUmmAlQura, month: 3, day: 12), days: 1, lead: 1, symbol: "🪔",
                decor: [.item(.oilLamps)], colors: []),
    ]

    /// Each begins the evening before; the scene dresses that day.
    static let jewish: [Holiday] = [
        Holiday(id: .roshHashanah, family: .jewish, rule: .lunar(.hebrew, month: 1, day: 1), days: 2, lead: 1, symbol: "🍎",
                decor: [.item(.pomegranates)], colors: []),
        Holiday(id: .sukkot, family: .jewish, rule: .lunar(.hebrew, month: 1, day: 15), days: 7, lead: 1, symbol: "🌿",
                decor: [.item(.autumnLeaves)], colors: []),
        Holiday(id: .hanukkah, family: .jewish, rule: .lunar(.hebrew, month: 3, day: 25), days: 8, lead: 1, symbol: "🕎",
                decor: [.item(.menorah), .flags(.hanukkah)], colors: [0x1E40AF, 0xFFFFFF, 0x93C5FD]),
        Holiday(id: .purim, family: .jewish, rule: .lunar(.hebrew, month: 7, day: 14), days: 1, lead: 1, symbol: "🎭",
                decor: [.item(.confetti)], colors: []),
        Holiday(id: .passover, family: .jewish, rule: .lunar(.hebrew, month: 8, day: 15), days: 8, lead: 1, symbol: "🍷",
                decor: [.item(.petals)], colors: []),
    ]

    /// Hindu, Sikh and Buddhist: almanac dates, from verified tables.
    static let dharmic: [Holiday] = [
        Holiday(id: .makarSankranti, family: .hindu, rule: .table(HolidayTables.makarSankranti), days: 1, lead: 1, symbol: "🪁",
                decor: [.item(.kites)], colors: []),
        Holiday(id: .holi, family: .hindu, rule: .table(HolidayTables.holi), days: 1, lead: 1, symbol: "🎨",
                decor: [.item(.colourPowder)], colors: []),
        Holiday(id: .diwali, family: .hindu, rule: .table(HolidayTables.diwali), days: 3, lead: 4, symbol: "🪔",
                decor: [.item(.oilLamps), .item(.fairyLights), .item(.fireworks)], colors: []),
        Holiday(id: .vaisakhi, family: .sikh, rule: .table(HolidayTables.vaisakhi), days: 1, lead: 1, symbol: "🌾",
                decor: [.flags(.vaisakhi)], colors: [0xF97316, 0xFACC15, 0x1D4ED8]),
        Holiday(id: .guruNanakJayanti, family: .sikh, rule: .table(HolidayTables.guruNanakJayanti), days: 1, lead: 1, symbol: "🪔",
                decor: [.item(.oilLamps), .item(.fairyLights)], colors: []),
        // Singapore keeps Vesak on the 15th of the Chinese fourth month — it
        // matched the Ministry of Manpower every year checked, 2024–2027 —
        // while India keeps Buddha Purnima by its own almanac.
        Holiday(id: .vesak, family: .buddhist, rule: .regional(
            ["SG": .lunar(.chinese, month: 4, day: 15), "MY": .lunar(.chinese, month: 4, day: 15)],
            otherwise: .table(HolidayTables.buddhaPurnima)
        ), days: 1, lead: 2, symbol: "🪷", decor: [.item(.paperLantern), .flags(.vesak)],
                colors: [0x2563EB, 0xFACC15, 0xDC2626, 0xFFFFFF, 0xF97316]),
    ]

    static let eastAsian: [Holiday] = [
        Holiday(id: .lunarNewYear, family: .eastAsian, rule: .lunar(.chinese, month: 1, day: 1), days: 15, lead: 5, symbol: "🧧",
                decor: [.item(.redLanterns), .item(.fireworks), .item(.paperLantern)], colors: []),
        Holiday(id: .dragonBoat, family: .eastAsian, rule: .lunar(.chinese, month: 5, day: 5), days: 1, lead: 1, symbol: "🐉",
                decor: [.flags(.dragonBoat)], colors: [0x16A34A, 0xFACC15, 0xDC2626]),
        Holiday(id: .tanabata, family: .eastAsian, rule: .fixed(month: 7, day: 7), days: 1, lead: 2, symbol: "🎋",
                decor: [.item(.wishNotes)], colors: []),
        Holiday(id: .midAutumn, family: .eastAsian, rule: .lunar(.chinese, month: 8, day: 15), days: 1, lead: 3, symbol: "🥮",
                decor: [.item(.harvestMoon), .item(.paperLantern)], colors: []),
    ]

    static let persian: [Holiday] = [
        Holiday(id: .nowruz, family: .persian, rule: .lunar(.persian, month: 1, day: 1), days: 13, lead: 5, symbol: "🌱",
                decor: [.item(.sabzeh), .item(.petals)], colors: []),
        Holiday(id: .yalda, family: .persian, rule: .fixed(month: 12, day: 21), days: 1, lead: 1, symbol: "🍉",
                decor: [.item(.pomegranates)], colors: []),
    ]

    static let turkish: [Holiday] = [
        Holiday(id: .hidirellez, family: .turkish, rule: .fixed(month: 5, day: 6), days: 1, lead: 1, symbol: "🌹",
                decor: [.item(.wishNotes), .item(.petals)], colors: []),
        Holiday(id: .childrensDayTR, family: .turkish, rule: .fixed(month: 4, day: 23), days: 1, lead: 1, symbol: "🎈",
                decor: [.flags(.childrensDayTR)], colors: [0xE30A17, 0xFFFFFF]),
        Holiday(id: .republicDayTR, family: .turkish, rule: .fixed(month: 10, day: 29), days: 1, lead: 1, symbol: "🇹🇷",
                decor: [.flags(.republicDayTR), .item(.fireworks)], colors: [0xE30A17, 0xFFFFFF]),
    ]

    /// National days that are a party.
    static let national: [Holiday] = [
        Holiday(id: .canadaDay, family: .national, rule: .fixed(month: 7, day: 1), days: 1, lead: 1, symbol: "🇨🇦",
                decor: [.flags(.canadaDay), .item(.fireworks)], colors: [0xD52B1E, 0xFFFFFF]),
        Holiday(id: .independenceUS, family: .national, rule: .fixed(month: 7, day: 4), days: 1, lead: 2, symbol: "🇺🇸",
                decor: [.flags(.independenceUS), .item(.fireworks)], colors: [0xB22234, 0xFFFFFF, 0x3C3B6E]),
        Holiday(id: .bastilleDay, family: .national, rule: .fixed(month: 7, day: 14), days: 1, lead: 1, symbol: "🇫🇷",
                decor: [.flags(.bastilleDay), .item(.fireworks)], colors: [0x0055A4, 0xFFFFFF, 0xEF4135]),
        Holiday(id: .independenceMX, family: .national, rule: .fixed(month: 9, day: 16), days: 1, lead: 2, symbol: "🇲🇽",
                decor: [.item(.papelPicado), .flags(.independenceMX)], colors: [0x006847, 0xFFFFFF, 0xCE1126]),
    ]

    public static func with(_ id: ID) -> Holiday? { all.first { $0.id == id } }

    static let mothersDayRules: [String: Rule] = {
        var rules: [String: Rule] = [:]
        // Mothering Sunday, three weeks before Easter.
        for region in ["GB", "IE"] { rules[region] = .easter(offset: -21) }
        for region in ["MX", "GT", "SV"] { rules[region] = .fixed(month: 5, day: 10) }
        for region in ["ES", "PT"] { rules[region] = .weekday(month: 5, weekday: 1, ordinal: 1) }
        for region in ["EG", "JO", "LB", "SA", "AE", "SY", "IQ", "KW", "QA"] { rules[region] = .fixed(month: 3, day: 21) }
        rules["FR"] = .weekday(month: 5, weekday: 1, ordinal: -1)
        rules["RU"] = .weekday(month: 11, weekday: 1, ordinal: -1)
        return rules
    }()

    static let fathersDayRules: [String: Rule] = {
        var rules: [String: Rule] = [:]
        for region in ["AU", "NZ"] { rules[region] = .weekday(month: 9, weekday: 1, ordinal: 1) }
        for region in ["IT", "ES", "PT"] { rules[region] = .fixed(month: 3, day: 19) }
        // Ascension Day.
        rules["DE"] = .easter(offset: 39)
        return rules
    }()
}

// MARK: - Which ones a house keeps

extension Holiday {
    /// What a house in `region` celebrates before anybody chooses: the days
    /// most of a country marks, and New Year everywhere. A suggestion, not a
    /// statement about who lives there — "Our holidays" lists all of them.
    public static func defaults(for region: String?) -> Set<ID> {
        var ids: Set<ID> = [.newYear, .valentines, .mothersDay, .fathersDay]
        let region = region ?? ""
        let islamic: Set<String> = ["SA", "AE", "EG", "JO", "LB", "SY", "IQ", "KW", "QA", "BH", "OM", "YE", "MA", "DZ", "TN",
                                    "LY", "SD", "PK", "BD", "ID", "MY", "AF", "AZ", "UZ", "KZ", "KG", "TJ", "TM", "SN", "ML", "NE"]
        let orthodox: Set<String> = ["RU", "UA", "BY", "GR", "CY", "RS", "BG", "RO", "MK", "ME", "GE", "MD"]
        let western: Set<String> = ["US", "GB", "IE", "CA", "AU", "NZ", "DE", "AT", "CH", "FR", "BE", "NL", "LU", "IT", "ES", "PT",
                                    "PL", "CZ", "SK", "HU", "SI", "HR", "DK", "NO", "SE", "FI", "IS", "MX", "BR", "AR", "CL",
                                    "CO", "PE", "VE", "EC", "UY", "PY", "BO", "CR", "PA", "GT", "SV", "HN", "NI", "DO", "PR",
                                    "PH", "ZA", "MT", "EE", "LV", "LT"]
        if islamic.contains(region) { ids.formUnion([.ramadan, .eidAlFitr, .eidAlAdha, .islamicNewYear]) }
        if orthodox.contains(region) { ids.formUnion([.orthodoxChristmas, .orthodoxEaster, .womensDay]) }
        if western.contains(region) { ids.formUnion([.christmas, .easter]) }
        switch region {
        case "TR": ids.formUnion([.ramadan, .eidAlFitr, .eidAlAdha, .womensDay, .hidirellez, .childrensDayTR, .republicDayTR, .halloween])
        case "US": ids.formUnion([.stPatricks, .independenceUS, .halloween, .thanksgivingUS])
        case "CA": ids.formUnion([.canadaDay, .thanksgivingCA, .halloween])
        case "GB": ids.formUnion([.bonfireNight, .halloween])
        case "IE": ids.formUnion([.stPatricks, .halloween])
        case "FR": ids.insert(.bastilleDay)
        case "DE", "AT", "CH", "BR", "IT", "ES", "BE", "NL": ids.insert(.carnival)
        case "MX": ids.formUnion([.epiphany, .dayOfTheDead, .independenceMX])
        case "SE", "FI": ids.insert(.midsummer)
        case "IL": ids.formUnion([.roshHashanah, .sukkot, .hanukkah, .purim, .passover])
        case "IN": ids.formUnion([.makarSankranti, .holi, .diwali, .vaisakhi, .guruNanakJayanti, .vesak])
        case "NP", "LK", "TH", "MM", "KH", "LA", "BT": ids.insert(.vesak)
        case "CN", "TW", "HK", "MO", "SG", "VN": ids.formUnion([.lunarNewYear, .dragonBoat, .midAutumn])
        case "KR": ids.formUnion([.lunarNewYear, .midAutumn, .christmas])
        case "JP": ids.formUnion([.tanabata, .christmas])
        case "IR": ids.formUnion([.nowruz, .yalda, .ramadan, .eidAlFitr, .eidAlAdha])
        case "AF", "AZ", "KZ", "KG", "TJ", "UZ", "TM": ids.insert(.nowruz)
        default: break
        }
        if region == "SG" || region == "MY" { ids.formUnion([.vesak, .diwali, .eidAlFitr, .christmas]) }
        return ids
    }

    /// Whether winter falls in December where this house is. Snow on a
    /// Christmas tree in Sydney is a picture of somebody else's December.
    public static func isSouthern(_ region: String?) -> Bool {
        guard let region else { return false }
        return ["AR", "AU", "BO", "BR", "CL", "NZ", "PY", "PE", "UY", "ZA", "NA", "BW", "ZW", "ZM", "MZ", "MG", "LS", "SZ", "FJ"]
            .contains(region)
    }

    /// The holidays dressing the scene at `date`, the soonest-starting first.
    public static func active(
        on date: Date,
        among ids: Set<ID>,
        region: String?,
        calendar: Calendar = .current
    ) -> [Holiday] {
        all.filter { ids.contains($0.id) }
            .compactMap { holiday in holiday.window(around: date, region: region, calendar: calendar).map { (holiday, $0) } }
            .sorted { $0.1.start > $1.1.start }
            .map(\.0)
    }
}

/// Days from almanacs Foundation does not carry, as kept in New Delhi.
///
/// 2026 and 2027 are India's gazetted holidays (DoPT); 2028–2030 are from
/// Drik Panchang (New Delhi), each recomputed from the tithi or sankranti
/// rule. A year missing here has no occurrence rather than an invented one,
/// and extending the table is a data change. The sources and the two days
/// where almanacs disagree are in Docs/Companion/HOLIDAYS.md.
enum HolidayTables {
    typealias Table = [Int: Holiday.MonthDay]

    /// Lakshmi Puja.
    static let diwali: Table = [2026: .init(11, 8), 2027: .init(10, 29), 2028: .init(10, 17), 2029: .init(11, 5), 2030: .init(10, 26)]
    /// The day of colours, not Holika Dahan the night before. 2027 follows
    /// the gazette (23 March); Drik Panchang says the 22nd.
    static let holi: Table = [2026: .init(3, 4), 2027: .init(3, 23), 2028: .init(3, 11), 2029: .init(3, 1), 2030: .init(3, 20)]
    static let makarSankranti: Table = [2026: .init(1, 14), 2027: .init(1, 14), 2028: .init(1, 15), 2029: .init(1, 14), 2030: .init(1, 14)]
    /// 2029 is Drik Panchang's; the government list may say the 13th.
    static let vaisakhi: Table = [2026: .init(4, 14), 2027: .init(4, 14), 2028: .init(4, 13), 2029: .init(4, 14), 2030: .init(4, 14)]
    static let guruNanakJayanti: Table = [2026: .init(11, 24), 2027: .init(11, 14), 2028: .init(11, 2), 2029: .init(11, 21), 2030: .init(11, 10)]
    static let buddhaPurnima: Table = [2026: .init(5, 1), 2027: .init(5, 20), 2028: .init(5, 8), 2029: .init(5, 27), 2030: .init(5, 17)]
}
