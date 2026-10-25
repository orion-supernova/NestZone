#if DEBUG
import ComposableArchitecture
import SwiftUI
import os

// Nestie against a stand-in server, on a simulator nobody is signed in on.
//
//   xcrun simctl launch <udid> com.walhallaa.NestZone -nestieBench 1 \
//       [-nestieScenario fresh|growing|ready|young|vote|voteAlone|finale] \
//       [-nestieScript buy|care|ceremony|decorate|holidays|choose|chooseReady|vote|voteSettle|votePick|finale|finaleStart|finaleChoose] \
//       [-nestieOrder pushFirst|answerFirst] \
//       [-nestieBuy honest|owned|short|unavailable|priceChanged] \
//       [-nestieFail care,start,startAfter,buy,buyAfter,graduate,layout,holidays,ballot,decide,hang] \
//       [-nestieSpecies <raw value>] [-nestieLatency 250] [-nestiePush 1] [-todayScroll 1] [-frameMeter 1]
//
// The real thing runs behind a session (Convex Auth rotates the refresh token
// on every exchange, so a copy of a signed-in simulator's keychain would sign
// the original out), and a Debug run against the owner's household writes to
// production. This is the real feature, reducer and views, with only the
// `CompanionClient` replaced by `FakeNestieServer`, which keeps the server's
// rules for what the client depends on: one answer per request id, a price the
// catalog decides, a welcome gift once, a graduation only when grown, and a
// live read that pushes after every write. Payloads are built as JSON and
// decoded by the real `CompanionPayload`, unknown kinds included.

struct NestieBench: View {
    @State private var store: StoreOf<CompanionFeature>
    @State private var position = ScrollPosition()
    @State private var isScrolling = false
    private let server: FakeNestieServer

    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Nestie")

    init() {
        let server = FakeNestieServer(Bench.arguments)
        self.server = server
        _store = State(initialValue: Store(
            initialState: CompanionFeature.State(homeID: "bench-home", region: "TR")
        ) {
            CompanionFeature()
        } withDependencies: {
            $0.companion = server.client
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(verbatim: "Tuesday evening")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                filler
                CompanionCard(store: store)
                    .environment(\.isScrolling, isScrolling)
                filler
                filler
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .onScrollPhaseChange { _, phase in isScrolling = phase.isScrolling }
        .scrollPosition($position)
        .background(Backdrop(tint: .indigo))
        .task { await store.send(.task).finish() }
        .task { await flick() }
        .task { await Bench.run(store: store, server: server) }
        .onAppear { FrameMeter.shared.startIfAsked() }
    }

    private var filler: some View {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
            .fill(Palette.inset)
            .frame(height: 120)
    }

    /// Today's own flick (`HomeView.flickForever`).
    private func flick() async {
        // `-nestieScrollY 900` puts the bench that far down once, to see the
        // lower half of a card at a size where it is taller than the screen.
        let offset = UserDefaults.standard.double(forKey: "nestieScrollY")
        if offset > 0 {
            try? await Task.sleep(for: .seconds(2))
            position.scrollTo(y: offset)
            return
        }
        guard UserDefaults.standard.bool(forKey: "todayScroll") else { return }
        var down = true
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 0.45)) { position.scrollTo(edge: down ? .bottom : .top) }
            down.toggle()
        }
    }
}

// MARK: - Launch arguments and scripts

enum Bench {
    struct Arguments {
        var scenario = "growing"
        var script = ""
        var buy = "honest"
        var fail: Set<String> = []
        var latency = Duration.milliseconds(250)
        var push = false
        /// Which comes first at the phone: the write's answer or the live
        /// push that shows it. Both happen on a real server.
        var order = "pushFirst"
    }

    static var arguments: Arguments {
        let defaults = UserDefaults.standard
        var args = Arguments()
        args.scenario = defaults.string(forKey: "nestieScenario") ?? "growing"
        args.script = defaults.string(forKey: "nestieScript") ?? ""
        args.buy = defaults.string(forKey: "nestieBuy") ?? "honest"
        args.fail = Set((defaults.string(forKey: "nestieFail") ?? "").split(separator: ",").map(String.init))
        if defaults.object(forKey: "nestieLatency") != nil {
            args.latency = .milliseconds(defaults.integer(forKey: "nestieLatency"))
        }
        args.push = defaults.bool(forKey: "nestiePush")
        args.order = defaults.string(forKey: "nestieOrder") ?? "pushFirst"
        return args
    }

    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Nestie")

    /// What the screen says, in one line, so a script's steps can be read
    /// from the log next to the screenshots.
    @MainActor
    static func report(_ label: String, _ store: StoreOf<CompanionFeature>) {
        let step = store.card.map { String(describing: store.state.step(of: $0)) } ?? "no card"
        let current = store.current.map { "\($0.species.rawValue) \(Int($0.points ?? -1))pts stage \(store.stage)" } ?? "none"
        log.notice("[\(label, privacy: .public)] jar \(store.house.leaves)/\(store.house.sparkles) card \(step, privacy: .public) current \(current, privacy: .public) sheet \(store.sheet?.rawValue ?? "-", privacy: .public) cared \(store.caredToday) pay \(store.lastPay.map { "\($0.coins.leaves)/\($0.coins.sparkles)" } ?? "-", privacy: .public) alert \(store.alert != nil)")
    }

    /// Logs the screen's state each time it changes, so the order things
    /// happened in — and any value that was there only for a moment — can be
    /// read from the log.
    @MainActor
    static func sample(_ store: StoreOf<CompanionFeature>) async {
        var last = ""
        let started = Date()
        while !Task.isCancelled {
            let step = store.card.map { String(describing: store.state.step(of: $0)) } ?? "-"
            let signature = "jar \(store.jar.leaves)/\(store.jar.sparkles) own \(store.current?.species.rawValue ?? "none")#\(store.current?.id ?? "-") ready \(store.isReady) pay \(store.lastPay.map { "\($0.id):\($0.coins.leaves)/\($0.coins.sparkles)" } ?? "-") sheet \(store.sheet?.rawValue ?? "-") card \(step) cared \(store.caredToday) layout \(store.house.layout.all.count) hol \(store.house.holidays?.count ?? -1) album \(store.house.albumCount) moment \(store.moment != nil) alert \(store.alert != nil) loaded \(store.isLoaded)"
            if signature != last {
                last = signature
                log.notice("+\(Int(Date().timeIntervalSince(started) * 1000))ms \(signature, privacy: .public)")
            }
            try? await Task.sleep(for: .milliseconds(30))
        }
    }

    @MainActor
    static func run(store: StoreOf<CompanionFeature>, server: FakeNestieServer) async {
        let script = UserDefaults.standard.string(forKey: "nestieScript") ?? ""
        if UserDefaults.standard.bool(forKey: "nestiePush") { await server.pushForever() }
        guard !script.isEmpty else { return }
        Task { await sample(store) }
        while !store.isLoaded { try? await Task.sleep(for: .milliseconds(100)) }
        try? await Task.sleep(for: .seconds(2))
        report("loaded", store)
        switch script {
        case "care":
            store.send(.careTapped)
            report("care tapped", store)
            try? await Task.sleep(for: .seconds(1.5))
            report("care settled", store)
        case "buy":
            store.send(.shopTapped)
            try? await Task.sleep(for: .seconds(1.2))
            store.send(.itemTapped(.decor(.bow)), animation: ShopMotion.cardIn)
            try? await Task.sleep(for: .seconds(1))
            report("card open", store)
            store.send(.cardBuyTapped, animation: Motion.spring)
            report("buy tapped", store)
            try? await Task.sleep(for: .seconds(2.5))
            report("buy settled", store)
            // A failed buy shows its notice and tapping again is the same purchase.
            if store.card.map({ store.state.step(of: $0) }) == .notice(.offline) {
                store.send(.cardBuyTapped, animation: Motion.spring)
                report("retry tapped", store)
                try? await Task.sleep(for: .seconds(2.5))
                report("retry settled", store)
            }
        case "shop":
            // The shop left open on `-companionShelf`, to scroll (`-companionScroll 1`) and measure.
            store.send(.shopTapped)
            try? await Task.sleep(for: .seconds(1.2))
            report("shop open", store)
        case "chooseOpen":
            // Choose left open, to scroll (`-companionScroll 1`) and measure.
            store.send(.chooseTapped)
            try? await Task.sleep(for: .seconds(1.2))
            report("choose open", store)
        case "choose":
            store.send(.chooseTapped)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.chose(.sunflower))
            report("chose", store)
            try? await Task.sleep(for: .seconds(2))
            report("chose settled", store)
        case "holidays":
            store.send(.holidaysTapped)
            try? await Task.sleep(for: .seconds(1))
            store.send(.holidayToggled(.halloween))
            report("holiday toggled", store)
            try? await Task.sleep(for: .seconds(2.5))
            report("holidays settled", store)
        case "chooseReady":
            // A ready one, and a new one chosen straight away: the server
            // graduates the first in the same write.
            store.send(.chooseTapped)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.chose(.sunflower))
            report("chose over a ready one", store)
            try? await Task.sleep(for: .seconds(3))
            report("settled", store)
        case "ceremony":
            store.send(.celebrateTapped)
            try? await Task.sleep(for: .seconds(3.5))
            store.send(.ceremonyFinished, animation: Motion.arrive)
            report("ceremony finished", store)
            try? await Task.sleep(for: .seconds(2))
            report("ceremony settled", store)
        case "finale":
            // `-nestieScenario finale`: the last free species is ready. The
            // ceremony on Today, its button, and the answer says "finale":
            // the finale plays in a cover of its own, and Choose opens on
            // the colours when it closes. The last step grows one coloured.
            store.send(.celebrateTapped)
            try? await Task.sleep(for: .seconds(3.5))
            store.send(.ceremonyFinished, animation: Motion.arrive)
            report("ceremony finished", store)
            try? await Task.sleep(for: .seconds(9))
            report("finale playing", store)
            store.send(.momentDismissed, animation: Motion.arrive)
            try? await Task.sleep(for: .seconds(2))
            report("choose with colours", store)
            store.send(.growTapped(.kitten), animation: ShopMotion.cardIn)
            try? await Task.sleep(for: .seconds(2))
            report("colour picker", store)
            store.send(.colourPicked(.kitten, 2), animation: Motion.exit)
            report("coloured start tapped", store)
            try? await Task.sleep(for: .seconds(2))
            report("coloured start settled", store)
        case "finaleStart":
            // The same finale, brought by a start over the ready one: one
            // cover, "All grown up!" and then "You've grown them all".
            store.send(.chooseTapped)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.chose(.kitten))
            report("chose over a ready one", store)
            try? await Task.sleep(for: .seconds(14))
            report("finale playing", store)
            store.send(.momentDismissed, animation: Motion.arrive)
            try? await Task.sleep(for: .seconds(2))
            report("finale closed", store)
        case "finaleChoose":
            // After the finale (a house that finished): Choose, the picker
            // for a grown one, and a colour the house has grown already.
            store.send(.chooseTapped)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.growTapped(.kitten), animation: ShopMotion.cardIn)
            try? await Task.sleep(for: .seconds(2))
            report("colour picker", store)
        case "vote":
            // Open the vote, answer two of three, and see the card.
            store.send(.voteTapped)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.ballotTapped("cherry", yes: true))
            try? await Task.sleep(for: .seconds(0.6))
            store.send(.ballotTapped("duckling", yes: false))
            report("two answered", store)
            try? await Task.sleep(for: .seconds(1.5))
            report("settled", store)
        case "voteSettle":
            store.send(.voteTapped)
            try? await Task.sleep(for: .seconds(1.2))
            store.send(.settleTapped)
            report("settle tapped", store)
            try? await Task.sleep(for: .seconds(2))
            report("settle answered", store)
        case "votePick":
            store.send(.voteTapped)
            try? await Task.sleep(for: .seconds(1.2))
            store.send(.pickInsteadTapped)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.chose(.sunflower))
            report("picked", store)
            try? await Task.sleep(for: .seconds(2))
            report("pick settled", store)
        case "store":
            // The Sparkles store's shelf: what the store priced, or that it
            // could not be asked. Buys nothing.
            store.send(.storeTapped)
            store.send(.storeAppeared)
            try? await Task.sleep(for: .seconds(3))
            let shelf = store.packs.map { "\($0.sparkles)=\($0.displayPrice ?? "-")" }.joined(separator: " ")
            log.notice("[store] test \(SparkleStoreClient.isTestStore) packs \(shelf, privacy: .public) loaded \(store.arePacksLoaded) unavailable \(store.packsUnavailable)")
        case "decorate":
            store.send(.decorateTapped)
            store.send(.spotPicked(.ground))
            try? await Task.sleep(for: .seconds(1))
            store.send(.decorToggled(DecorItem.wateringCan.rawValue))
            store.send(.decorateDone)
            report("decorated", store)
            try? await Task.sleep(for: .seconds(2))
            report("decorate settled", store)
        default:
            break
        }
    }
}

// MARK: - The stand-in server

actor FakeNestieServer {
    private let config: Bench.Arguments
    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Nestie")

    // The house.
    private var leaves = 0, sparkles = 0, welcomed = false
    private var owned: Set<String> = [], ownedSpecies: Set<String> = []
    private var layout = SceneLayout()
    private var holidays: [String]?
    private var region: String? = "TR"
    private var tzOffset: Int? = 180
    private var albumCount = 0
    private var hasHouse = true
    private var current: Current?
    private var recent: [(kind: String, at: Date, user: String?)] = []
    private var album: [(uuid: String, species: Species, seed: String, started: Date, graduated: Date)] = []
    /// Colours of album cards, by uuid, and the house's finale.
    private var albumColours: [String: Int] = [:]
    private var grownColours: Set<String> = []
    private var finaleAt: Date?
    private var jarFeed: [[String: Any]] = []

    private struct Current {
        var id = "companion-1", uuid = UUID().uuidString
        var species: Species, seed: String, startedAt: Date
        var points: Double, paidStage = 0
        var lastCare: Date?
        var careDays: [String] = []
        /// A seed the house has not named: `species` is the vote's first option.
        var undecided = false
        var colour: Int?
    }

    /// The vote for the next one, as the server keeps it, with one housemate
    /// (`u1`) whose answers are `others`.
    private struct VoteState {
        var options = ["cherry", "duckling", "fern"]
        var mine: [String: Bool] = [:]
        var others: [String: Bool] = ["cherry": true, "duckling": false, "fern": true]
        var othersVoted = true
        var status = "open"
        var how: String?
        var winner: String?
        var closesAt = Date().addingTimeInterval(23 * 3_600)

        func yes(_ id: String) -> Int { (mine[id] == true ? 1 : 0) + (othersVoted && others[id] == true ? 1 : 0) }
        func no(_ id: String) -> Int { (mine[id] == false ? 1 : 0) + (othersVoted && others[id] == false ? 1 : 0) }
        var answered: Int {
            (mine.count == options.count ? 1 : 0) + (othersVoted && others.count == options.count ? 1 : 0)
        }
        /// Most yeses, the earlier option on a tie; none without a yes.
        var leader: String? {
            options.filter { yes($0) > 0 }.max { yes($0) < yes($1) }
        }
    }
    private var voteState: VoteState?

    // What it has been asked.
    private var seenBuys: [String: BuyOutcome] = [:]
    private var buyCalls = 0
    private var subscribers: [UUID: AsyncThrowingStream<CompanionPayload, any Error>.Continuation] = [:]
    private var albumSubscribers: [UUID: AsyncThrowingStream<CompanionPayload.Cards, any Error>.Continuation] = [:]
    private var pushing: Task<Void, Never>?

    init(_ config: Bench.Arguments) {
        self.config = config
    }

    private var seeded = false

    /// The scenario's house, made the first time anything asks (an actor's
    /// synchronous init cannot call its own methods).
    private func seedIfNeeded() {
        guard !seeded else { return }
        seeded = true
        let day: TimeInterval = 86_400
        let now = Date()
        switch config.scenario {
        case "fresh":
            hasHouse = false
            tzOffset = nil
            region = nil
        case "ready":
            seedHouse(points: 64, startedAgo: 8 * day, now: now)
        case "finale", "finaleDone":
            // Every species that costs no Sparkles grown but one, which is
            // ready (`finaleDone`: that one is grown too, a house that
            // finished before the finale shipped).
            seedHouse(points: 64, startedAgo: 8 * day, now: now)
            let last = Species.sunflower
            current?.species = last
            for (index, species) in Species.allCases.filter({ Species.freeToHave.contains($0) && $0 != last }).enumerated() {
                album.append((UUID().uuidString, species, "bench-home-\(index)", now.addingTimeInterval(-60 * day), now.addingTimeInterval(-30 * day)))
            }
            albumCount = album.count
            if config.scenario == "finaleDone" {
                album.append((UUID().uuidString, last, "bench-home-last", now.addingTimeInterval(-9 * day), now.addingTimeInterval(-8 * day)))
                albumCount = album.count
                current?.points = 20
                finaleAt = now.addingTimeInterval(-8 * day)
                grownColours = ["kitten:1"]
            }
        case "young":
            seedHouse(points: 64, startedAgo: 2 * day, now: now)
        case "vote", "voteAlone":
            seedHouse(points: 12, startedAgo: day, now: now)
            current?.species = .cherry
            current?.undecided = true
            current?.paidStage = 0
            voteState = VoteState()
            if config.scenario == "voteAlone" { voteState?.othersVoted = false }
        default:
            seedHouse(points: 20.6, startedAgo: 3 * day, now: now)
        }
    }

    private func seedHouse(points: Double, startedAgo: TimeInterval, now: Date) {
        leaves = 150; sparkles = 180; welcomed = true
        owned = []
        // `-nestieSpecies sunflower` grows that one instead, to measure a drawing.
        let species = UserDefaults.standard.string(forKey: "nestieSpecies").flatMap(Species.init(rawValue:)) ?? .magnolia
        current = Current(species: species, seed: "bench-home-0", startedAt: now.addingTimeInterval(-startedAgo), points: points, paidStage: 2)
        // Two people finishing things lately, and a kind this build has never heard of.
        recent = [
            ("chore", now.addingTimeInterval(-3_600), "u1"), ("chore", now.addingTimeInterval(-7_200), "u2"),
            ("dinner", now.addingTimeInterval(-86_400), "u1"), ("hug", now.addingTimeInterval(-90_000), nil),
        ]
        jarFeed = [["id": "j1", "kind": "welcome", "leaves": 150, "sparkles": 180, "item": NSNull(), "userId": "u1", "at": now.addingTimeInterval(-startedAgo).timeIntervalSince1970 * 1000],
                   ["id": "j2", "kind": "gift", "leaves": 1, "sparkles": 0, "item": NSNull(), "userId": NSNull(), "at": now.timeIntervalSince1970 * 1000]]
        if config.scenario != "finale", config.scenario != "finaleDone" { album = [] }
        // `-nestieDecor full` (or a list of raw values, `windChime,bow`) owns
        // those decorations and puts them out, to measure what a scene full of
        // them costs against an empty one.
        if let list = UserDefaults.standard.string(forKey: "nestieDecor") {
            let raws = list == "full" ? Self.fullSet : list.split(separator: ",").map(String.init)
            layout = SceneLayout()
            for raw in raws {
                guard let item = DecorItem(rawValue: raw) else { continue }
                owned.insert(raw)
                layout.place(.item(item))
            }
        }
    }

    /// One of everything that is drawn each frame or lit at night, a spot each.
    private static let fullSet = ["windChime", "starryRooftop", "fairyLights", "ornaments", "treeStar", "tinyCrown", "glazedPot",
                                  "watermelon", "paperLantern", "kilim", "petals"]

    // MARK: Reads

    nonisolated var client: CompanionClient {
        CompanionClient(
            forHome: { _ in self.stream() },
            album: { _ in self.albumStream() },
            setPlace: { _, place in try await self.setPlace(place) },
            start: { _, species, place, requestID, colour in try await self.start(species, place, requestID, colour) },
            care: { _ in try await self.care() },
            graduate: { _, id in
                let (paid, finale) = try await self.graduate(id)
                return GraduateOutcome(paid: paid, finale: finale)
            },
            // A vote exists only in the `vote` scenarios, with one housemate who has answered.
            ballot: { _, species, answer in try await self.ballot(species, answer) },
            decide: { _ in try await self.decide() },
            setLayout: { _, layout in try await self.setLayout(layout) },
            setHolidays: { _, holidays in try await self.setHolidays(holidays) },
            importLocal: { _, _, _ in .closed },
            buy: { _, item, requestID, expected in try await self.buy(item, requestID, expected) },
            // The bench has no jar to top up: a real StoreKit purchase made on
            // it is refused, and stays unfinished.
            topUp: { _, _ in TopUpOutcome(status: .invalid) }
        )
    }

    private nonisolated func stream() -> AsyncThrowingStream<CompanionPayload, any Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            Task { await self.attach(id, continuation) }
            continuation.onTermination = { _ in Task { await self.detach(id) } }
        }
    }

    private nonisolated func albumStream() -> AsyncThrowingStream<CompanionPayload.Cards, any Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            Task { await self.attachAlbum(id, continuation) }
            continuation.onTermination = { _ in Task { await self.detachAlbum(id) } }
        }
    }

    private func attach(_ id: UUID, _ continuation: AsyncThrowingStream<CompanionPayload, any Error>.Continuation) {
        seedIfNeeded()
        subscribers[id] = continuation
        continuation.yield(payload())
    }

    private func detach(_ id: UUID) { subscribers[id] = nil }

    private func attachAlbum(_ id: UUID, _ continuation: AsyncThrowingStream<CompanionPayload.Cards, any Error>.Continuation) {
        seedIfNeeded()
        albumSubscribers[id] = continuation
        continuation.yield(cards())
    }

    private func detachAlbum(_ id: UUID) { albumSubscribers[id] = nil }

    private func push() {
        let next = payload()
        for continuation in subscribers.values { continuation.yield(next) }
        let cards = cards()
        for continuation in albumSubscribers.values { continuation.yield(cards) }
    }

    /// A live house: someone finishes something every so often.
    func pushForever() {
        guard pushing == nil else { return }
        pushing = Task {
            var n = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                n += 1
                recent.insert(("chore", Date(), n.isMultiple(of: 2) ? "u1" : "u2"), at: 0)
                if recent.count > 120 { recent.removeLast() }
                // `-nestiePush 2`: the house is busy but the points do not move.
                if n.isMultiple(of: 5), UserDefaults.standard.integer(forKey: "nestiePush") != 2 { current?.points += 0.4 }
                push()
            }
        }
    }

    // MARK: The payload, as JSON

    private func payload() -> CompanionPayload {
        func ms(_ date: Date) -> Double { (date.timeIntervalSince1970 * 1000).rounded() }
        let stageThresholds = current.map { $0.species.isPet ? CompanionMath.petStages : CompanionMath.plantStages }
        var json: [String: Any] = [
            "catalogVersion": CatalogVersion.exported,
            "graduateAt": 64,
            "recent": recent.prefix(120).map { ["kind": $0.kind, "at": ms($0.at), "userId": $0.user ?? NSNull()] as [String: Any] },
            "jar": jarFeed,
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
            let progress = c.points / 64
            let stage = stageThresholds.map { $0.lastIndex { progress >= $0 } ?? 0 } ?? 0
            let readyAt = c.startedAt.addingTimeInterval(6 * 86_400)
            let pointsReady = c.points >= 64 - 1e-9
            return [
                "id": c.id, "uuid": c.uuid, "species": c.species.rawValue, "seed": c.seed,
                "startedAt": ms(c.startedAt), "points": c.points, "stage": stage,
                "isReady": pointsReady && Date() >= readyAt, "pointsReady": pointsReady, "readyAt": ms(readyAt),
                "paidStage": c.paidStage,
                "lastCareAt": c.lastCare.map(ms) as Any? ?? NSNull(), "myCareDays": c.careDays,
                "undecided": c.undecided, "colour": c.colour as Any? ?? NSNull(),
            ] as [String: Any]
        } ?? NSNull()
        json["vote"] = voteState.map { v in
            [
                "pollId": "bench-poll", "status": v.status, "openedAt": ms(Date().addingTimeInterval(-3_600)),
                "closesAt": ms(v.closesAt), "closedAt": NSNull(), "how": v.how as Any? ?? NSNull(),
                "winner": v.winner as Any? ?? NSNull(),
                "options": v.options.map { id in
                    ["species": id, "isPet": Species(rawValue: id)?.isPet ?? false, "grown": false, "yes": v.yes(id), "no": v.no(id)] as [String: Any]
                },
                "mine": v.mine.map { ["species": $0.key, "yes": $0.value] as [String: Any] },
                "members": 2, "answered": v.answered, "othersVoted": v.othersVoted,
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

    private func cards() -> CompanionPayload.Cards {
        let json: [[String: Any]] = album.map { card in
            ["uuid": card.uuid, "species": card.species.rawValue, "seed": card.seed,
             "startedAt": card.started.timeIntervalSince1970 * 1000, "graduatedAt": card.graduated.timeIntervalSince1970 * 1000,
             "colour": albumColours[card.uuid] as Any? ?? NSNull()]
        }
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(CompanionPayload.Cards.self, from: try! JSONSerialization.data(withJSONObject: json))
    }

    // MARK: Writes

    private func wait(_ name: String) async throws {
        try await Task.sleep(for: config.latency)
        Self.log.notice("server: \(name, privacy: .public)")
        // Never answers: the client's own timeout has to end it.
        if config.fail.contains("hang") { try await Task.sleep(for: .seconds(3600)) }
        if config.fail.contains(name) { throw URLError(.notConnectedToInternet) }
    }

    private func setPlace(_ place: Place) async throws -> Bool {
        try await wait("setPlace")
        tzOffset = place.tzOffset
        region = place.region
        publish()
        return true
    }

    /// The write's effect reaches the phone as the live push. On a real server
    /// it can land before the write's answer or after it; the bench does either.
    private func publish() {
        if config.order == "answerFirst" {
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                self.push()
            }
        } else {
            push()
        }
    }

    private var starts: [String: StartOutcome] = [:]
    private var startCalls = 0

    /// What graduating a ready companion does to the house: the card, the jar,
    /// the colour grown, and whether it finished every free species, once.
    private func graduateCurrent(_ c: Current) -> (finale: Bool, paid: Coins) {
        album.append((c.uuid, c.species, c.seed, c.startedAt, Date()))
        if let colour = c.colour {
            albumColours[c.uuid] = colour
            grownColours.insert(Colourway.key(c.species, colour))
        }
        albumCount += 1
        leaves += 100; sparkles += 25
        let grown = Set(album.map(\.species))
        let finale = finaleAt == nil && Species.freeToHave.isSubset(of: grown)
        if finale { finaleAt = Date() }
        return (finale, Coins(leaves: 100, sparkles: 25))
    }

    private func start(_ species: Species, _ place: Place, _ requestID: String, _ colour: Int?) async throws -> StartOutcome {
        startCalls += 1
        try await wait(startCalls == 1 ? "start" : "start-\(startCalls)")
        if let first = starts[requestID] {
            Self.log.notice("server: start replayed for the same request id")
            return StartOutcome(companionID: first.companionID, welcome: nil, graduated: first.graduated.map {
                GraduatedCompanion(companionID: $0.companionID, species: $0.species, paid: nil, finale: $0.finale)
            })
        }
        if !hasHouse { hasHouse = true; tzOffset = place.tzOffset; region = place.region }
        // A seed the house has not named: this is the pick, and it keeps its growth.
        if var seed = current, seed.undecided {
            if voteState?.status == "open", voteState?.othersVoted == true {
                throw AppError.server("The house is voting on the next one")
            }
            seed.species = species
            seed.undecided = false
            current = seed
            if voteState?.status == "open" { voteState?.status = "closed"; voteState?.how = "picked"; voteState?.winner = species.rawValue }
            let outcome = StartOutcome(companionID: seed.id)
            starts[requestID] = outcome
            publish()
            return outcome
        }
        // A colour is the server's to judge: after the finale, for a species
        // grown, in a colour not grown yet. Thrown, with the server's words.
        if let colour {
            guard Colourway.range.contains(colour) else { throw AppError.server("There's no such colour") }
            let finished = finaleAt != nil || Species.freeToHave.isSubset(of: Set(album.map(\.species)))
            guard finished, album.contains(where: { $0.species == species }),
                  !grownColours.contains(Colourway.key(species, colour))
            else { throw AppError.server("That colour can't be grown yet") }
        }
        // A ready one graduates first, in the same write.
        var graduated: GraduatedCompanion?
        if let c = current, c.points >= 64 - 1e-9, Date().timeIntervalSince(c.startedAt) >= 6 * 86_400 {
            let done = graduateCurrent(c)
            graduated = GraduatedCompanion(companionID: c.id, species: c.species, paid: done.paid, finale: done.finale)
        }
        let free: Set<Species> = [.magnolia, .basil, .sunflower, .cactus, .duckling, .kitten]
        guard free.contains(species) || ownedSpecies.contains(species.rawValue) else {
            throw AppError.server("That one can't be grown yet")
        }
        let id = "companion-\(albumCount)-\(startCalls)"
        current = Current(id: id, species: species, seed: "bench-home-\(albumCount)", startedAt: Date(), points: 0, colour: colour)
        var welcome: Coins?
        if !welcomed {
            welcomed = true
            leaves += 150; sparkles += 180
            welcome = Coins(leaves: 150, sparkles: 180)
        }
        let outcome = StartOutcome(companionID: id, welcome: welcome, graduated: graduated)
        starts[requestID] = outcome
        publish()
        // The write went through and the answer was lost on the way back.
        if config.fail.contains("startAfter"), startCalls == 1 { throw URLError(.networkConnectionLost) }
        return outcome
    }

    /// An answer to one option, or (`nil`) taking it back. When both people
    /// have answered everything, the vote ends and the seed is named.
    private func ballot(_ species: String, _ answer: Bool?) async throws {
        try await wait("ballot")
        guard var v = voteState, v.status == "open" else { throw AppError.server("That vote is over") }
        v.mine[species] = answer
        if v.answered >= 2, let winner = v.leader {
            v.status = "closed"; v.how = "everyone"; v.winner = winner
            current?.species = Species(rawValue: winner) ?? .cherry
            current?.undecided = false
        }
        voteState = v
        publish()
    }

    private func decide() async throws -> DecideOutcome {
        try await wait("decide")
        guard var v = voteState else { return .none }
        if v.status != "open" { return .closed(winner: v.winner) }
        guard v.othersVoted else { return .alone }
        guard let winner = v.leader else { return .noVotes }
        v.status = "closed"; v.how = "decided"; v.winner = winner
        voteState = v
        current?.species = Species(rawValue: winner) ?? .cherry
        current?.undecided = false
        publish()
        return .chosen(winner: winner)
    }

    private func care() async throws -> Bool {
        try await wait("care")
        guard var c = current else { return false }
        let day = CompanionFeature.State.dayKey(Date(), offset: tzOffset)
        let counted = !c.careDays.contains(day)
        if counted { c.careDays.insert(day, at: 0); c.points += 0.8 }
        c.lastCare = Date()
        current = c
        publish()
        return counted
    }

    private func graduate(_ id: String) async throws -> (Coins?, Bool) {
        try await wait("graduate")
        guard let c = current, c.points >= 64 - 1e-9, Date().timeIntervalSince(c.startedAt) >= 6 * 86_400 else {
            throw AppError.server("Not grown up yet")
        }
        current = nil
        let done = graduateCurrent(c)
        publish()
        return (done.paid, done.finale)
    }

    private func setLayout(_ layout: SceneLayout) async throws -> SceneLayout {
        try await wait("layout")
        self.layout = layout
        publish()
        return layout
    }

    private func setHolidays(_ holidays: [String]?) async throws -> [String]? {
        try await wait("holidays")
        self.holidays = holidays
        publish()
        return holidays
    }

    private func buy(_ item: ShopItem, _ requestID: String, _ expected: Price) async throws -> BuyOutcome {
        buyCalls += 1
        let call = buyCalls
        try await wait(config.fail.contains("buy") && call == 1 ? "buy" : "buy-\(call)")
        if let first = seenBuys[requestID] {
            Self.log.notice("server: buy replayed for the same request id")
            return first
        }
        guard let price = item.price else { return .unavailable }
        func take() -> BuyOutcome? {
            var house = CompanionHouse()
            house.leaves = leaves; house.sparkles = sparkles
            switch house.checkout(price) {
            case let .short(more): return .short(sparkles: more, price: price)
            case let .pay(coins), let .makeUp(coins, _):
                leaves -= coins.leaves; sparkles -= coins.sparkles
                switch item {
                case let .decor(d): owned.insert(d.rawValue)
                case let .species(s): ownedSpecies.insert(s.rawValue)
                case let .pack(p): ownedSpecies.formUnion(p.species.map(\.rawValue))
                }
                jarFeed.insert(["id": "j\(call)", "kind": "buy", "leaves": -coins.leaves, "sparkles": -coins.sparkles, "item": "x", "userId": "u1", "at": Date().timeIntervalSince1970 * 1000], at: 0)
                return .bought(paid: coins, madeUp: nil, jar: Coins(leaves: leaves, sparkles: sparkles), replay: false)
            }
        }
        var outcome: BuyOutcome
        switch (config.buy, call) {
        case ("owned", 1):
            // Another phone got there first: the house has it, nothing is charged.
            if case let .decor(d) = item { owned.insert(d.rawValue) }
            outcome = .owned
        case ("short", 1): outcome = .short(sparkles: 40, price: price)
        case ("unavailable", 1): outcome = .unavailable
        case ("priceChanged", 1):
            outcome = .priceChanged(.leaves(expected == .leaves(60) ? 80 : 99))
        default:
            outcome = expected == price ? (take() ?? .unavailable) : .priceChanged(price)
        }
        if case .bought = outcome { seenBuys[requestID] = outcome }
        publish()
        // The write went through and the answer was lost on the way back.
        if config.fail.contains("buyAfter"), call == 1 { throw URLError(.networkConnectionLost) }
        return outcome
    }
}
#endif
