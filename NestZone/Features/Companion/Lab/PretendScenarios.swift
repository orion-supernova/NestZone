#if DEBUG
import Foundation

// The houses the stand-in server can start from: the bench's scenarios
// (`-nestieScenario`) and the Lab's presets, which are the same houses with a
// few more. One list, so the bench and the pretend house cannot disagree
// about what "a house with a ready tree" is.

extension PretendState {
    /// A house for a scenario name. An unknown name is the usual growing one.
    ///
    /// `species` and `decor` are the bench's `-nestieSpecies` and
    /// `-nestieDecor`: grow that one instead, and own and put out these.
    static func scenario(
        _ name: String, now: Date = Date(), species: Species? = nil, decor: String? = nil, home: String = "pretend"
    ) -> PretendState {
        var house = PretendState()
        let day = PretendRules.day
        switch name {
        case "fresh", "newHouse":
            house.hasHouse = false
            house.tzOffset = nil
            house.region = nil
        case "ready":
            house.seed(points: 64, startedAgo: 8 * day, now: now, species: species, home: home)
        case "finale", "finaleDone", "finaleReady":
            // Every species that costs no Sparkles grown but one, which is
            // ready (`finaleDone`: that one is grown too, a house that
            // finished before the finale shipped).
            house.seed(points: 64, startedAgo: 8 * day, now: now, species: species, home: home)
            let last = Species.sunflower
            house.current?.species = last
            for (index, grown) in Species.allCases.filter({ Species.freeToHave.contains($0) && $0 != last }).enumerated() {
                house.album.append(Card(
                    uuid: UUID().uuidString, species: grown, seed: "\(home)-\(index)",
                    started: now.addingTimeInterval(-60 * day), graduated: now.addingTimeInterval(-30 * day)
                ))
            }
            house.albumCount = house.album.count
            if name == "finaleDone" {
                house.album.append(Card(
                    uuid: UUID().uuidString, species: last, seed: "\(home)-last",
                    started: now.addingTimeInterval(-9 * day), graduated: now.addingTimeInterval(-8 * day)
                ))
                house.albumCount = house.album.count
                house.current?.points = 20
                house.finaleAt = now.addingTimeInterval(-8 * day)
                house.grownColours = ["kitten:1"]
            }
        case "young":
            house.seed(points: 64, startedAgo: 2 * day, now: now, species: species, home: home)
        case "vote", "voteAlone", "twoMidVote":
            house.seed(points: 12, startedAgo: day, now: now, species: species, home: home)
            house.current?.species = .cherry
            house.current?.undecided = true
            house.current?.paidStage = 0
            house.members = 2
            var vote = Vote(
                options: ["cherry", "duckling", "fern"], others: [[:]],
                openedAt: now.addingTimeInterval(-3_600), closesAt: now.addingTimeInterval(23 * 3_600)
            )
            if name != "voteAlone" { vote.others = [["cherry": true, "duckling": false, "fern": true]] }
            house.vote = vote
        case "thirstyPetAtNight":
            house.seed(points: 30, startedAgo: 6 * day, now: now, species: species ?? .kitten, home: home)
            house.quiet(days: 4, now: now)
        case "readyTreeOnChristmasEve":
            house.seed(points: 64, startedAgo: 9 * day, now: now, species: species ?? .cherry, home: home)
            house.region = "US"
            house.holidays = nil
        case "brokeJar":
            house.seed(points: 20.6, startedAgo: 3 * day, now: now, species: species, home: home)
            house.leaves = 0
            house.sparkles = 0
            house.owned = []
            house.ownedSpecies = []
        case "decoratedRooftopAtNight":
            house.seed(points: 50, startedAgo: 5 * day, now: now, species: species ?? .kitten, home: home)
            house.own(decor: Self.rooftopSet)
            house.layout = SceneLayout()
            for raw in Self.rooftopSet { if let item = Decor(rawValue: raw) { house.layout.place(item) } }
        default:
            house.seed(points: 20.6, startedAgo: 3 * day, now: now, species: species, home: home)
        }
        if let decor { house.layoutFromLaunch(decor) }
        return house
    }

    /// A house with a companion growing and a jar to spend: the usual start.
    mutating func seed(points: Double, startedAgo: TimeInterval, now: Date, species: Species?, home: String) {
        leaves = 150
        sparkles = 180
        welcomed = true
        owned = []
        current = Current(
            species: species ?? .magnolia, seed: "\(home)-0", startedAt: now.addingTimeInterval(-startedAgo),
            points: points, paidStage: 2
        )
        markStagePaid()
        // Two people finishing things lately, and a kind this build has never heard of.
        recent = [
            Recent(kind: "chore", at: now.addingTimeInterval(-3_600), user: "u1"),
            Recent(kind: "chore", at: now.addingTimeInterval(-7_200), user: "u2"),
            Recent(kind: "dinner", at: now.addingTimeInterval(-86_400), user: "u1"),
            Recent(kind: "hug", at: now.addingTimeInterval(-90_000), user: nil),
        ]
        jarFeed = []
        addJar("welcome", leaves: 150, sparkles: 180, at: now.addingTimeInterval(-startedAgo))
        album = []
        albumCount = 0
        vote = nil
        members = 1
    }

    /// Nothing done and nobody by for this many days: thirsty at three, dozing at seven.
    mutating func quiet(days: Int, now: Date) {
        let ago = now.addingTimeInterval(-Double(days) * PretendRules.day)
        recent = recent.filter { $0.at < ago }
        if var c = current {
            c.lastCare = c.lastCare.map { min($0, ago) } ?? ago
            c.startedAt = min(c.startedAt, ago)
            c.careDays = c.careDays.filter { $0 < dayKey(ago) }
            current = c
        }
    }

    mutating func own(decor raws: [String]) {
        for raw in raws {
            if case let .item(item)? = Decor(rawValue: raw) { owned.insert(item.rawValue) }
        }
    }

    /// `-nestieDecor full` (or a list of raw values, `windChime,bow`) owns
    /// those decorations and puts them out, to measure what a scene full of
    /// them costs against an empty one.
    mutating func layoutFromLaunch(_ list: String) {
        let raws = list == "full" ? Self.fullSet : list.split(separator: ",").map(String.init)
        layout = SceneLayout()
        for raw in raws {
            guard let item = DecorItem(rawValue: raw) else { continue }
            owned.insert(raw)
            layout.place(.item(item))
        }
    }

    /// One of everything that is drawn each frame or lit at night, a spot each.
    static let fullSet = [
        "windChime", "starryRooftop", "fairyLights", "ornaments", "treeStar", "tinyCrown", "glazedPot",
        "watermelon", "paperLantern", "kilim", "petals",
    ]

    static let rooftopSet = ["starryRooftop", "fairyLights", "windChime", "paperLantern", "kilim", "tinyCrown", "bow", "petals", "bunting"]
}

// MARK: - Presets

/// A one-tap house for the Lab: what the house is, how many live in it, and
/// what the card is told to pretend about the day.
public enum PretendPreset: String, CaseIterable, Identifiable, Sendable {
    case newHouse, growing, thirstyPetAtNight, readyTreeOnChristmasEve, finaleReady, brokeJar
    case decoratedRooftopAtNight, twoMidVote

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .newHouse: "A new house"
        case .growing: "Growing, mid-week"
        case .thirstyPetAtNight: "A thirsty pet at night"
        case .readyTreeOnChristmasEve: "A ready tree on Christmas eve"
        case .finaleReady: "A finale-ready house"
        case .brokeJar: "A broke jar"
        case .decoratedRooftopAtNight: "A decorated rooftop at night"
        case .twoMidVote: "A house of two, mid-vote"
        }
    }

    var summary: String {
        switch self {
        case .newHouse: "Nobody has opened Nestie yet: the invitation, then the welcome gift."
        case .growing: "A magnolia a few days old, a jar to spend."
        case .thirstyPetAtNight: "A kitten nobody has come by for in four days, at 10 pm."
        case .readyTreeOnChristmasEve: "A cherry ready to graduate, on December 24 in the US."
        case .finaleReady: "Every free species grown but one, which is ready: graduate it for the finale."
        case .brokeJar: "Nothing in the jar and nothing owned: every purchase card says how short it is."
        case .decoratedRooftopAtNight: "A kitten on the starry rooftop with the lot, at midnight."
        case .twoMidVote: "Two people, a vote open and one of them has answered."
        }
    }

    var symbol: String {
        switch self {
        case .newHouse: "house"
        case .growing: "leaf"
        case .thirstyPetAtNight: "moon.zzz"
        case .readyTreeOnChristmasEve: "gift"
        case .finaleReady: "crown"
        case .brokeJar: "bag"
        case .decoratedRooftopAtNight: "sparkles"
        case .twoMidVote: "person.2"
        }
    }

    var members: Int { self == .twoMidVote ? 2 : 1 }

    func state(now: Date) -> PretendState { PretendState.scenario(scenarioName, now: now) }

    private var scenarioName: String { self == .growing ? "growing" : rawValue }

    /// The pretend day the preset wants, if any. It is look-only: the Lab
    /// lays it over the card, and in a pretend house the server's own clock
    /// follows it too.
    func date(now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .thirstyPetAtNight: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)
        case .decoratedRooftopAtNight: calendar.date(bySettingHour: 23, minute: 30, second: 0, of: now)
        case .readyTreeOnChristmasEve:
            {
                let year = calendar.component(.year, from: now)
                let thisYear = calendar.date(from: DateComponents(year: year, month: 12, day: 24, hour: 19))
                guard let thisYear else { return nil }
                return thisYear >= now ? thisYear : calendar.date(from: DateComponents(year: year + 1, month: 12, day: 24, hour: 19))
            }()
        default: nil
        }
    }
}
#endif
