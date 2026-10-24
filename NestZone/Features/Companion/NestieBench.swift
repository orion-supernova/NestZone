#if DEBUG
import ComposableArchitecture
import SwiftUI
import os

// Nestie against a stand-in server, on a simulator nobody is signed in on.
//
//   xcrun simctl launch <udid> com.walhallaa.NestZone -nestieBench 1 \
//       [-nestieScenario fresh|growing|ready|young] \
//       [-nestieScript buy|care|ceremony|decorate|holidays|choose|chooseReady] \
//       [-nestieOrder pushFirst|answerFirst] \
//       [-nestieBuy honest|owned|short|unavailable|priceChanged] \
//       [-nestieFail care,start,startAfter,buy,buyAfter,graduate,layout,holidays,hang] \
//       [-nestieLatency 250] [-nestiePush 1] [-todayScroll 1] [-frameMeter 1]
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
    private var jarFeed: [[String: Any]] = []

    private struct Current {
        var id = "companion-1", uuid = UUID().uuidString
        var species: Species, seed: String, startedAt: Date
        var points: Double, paidStage = 0
        var lastCare: Date?
        var careDays: [String] = []
    }

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
        case "young":
            seedHouse(points: 64, startedAgo: 2 * day, now: now)
        default:
            seedHouse(points: 20.6, startedAgo: 3 * day, now: now)
        }
    }

    private func seedHouse(points: Double, startedAgo: TimeInterval, now: Date) {
        leaves = 150; sparkles = 180; welcomed = true
        owned = []
        current = Current(species: .magnolia, seed: "bench-home-0", startedAt: now.addingTimeInterval(-startedAgo), points: points, paidStage: 2)
        // Two people finishing things lately, and a kind this build has never heard of.
        recent = [
            ("chore", now.addingTimeInterval(-3_600), "u1"), ("chore", now.addingTimeInterval(-7_200), "u2"),
            ("dinner", now.addingTimeInterval(-86_400), "u1"), ("hug", now.addingTimeInterval(-90_000), nil),
        ]
        jarFeed = [["id": "j1", "kind": "welcome", "leaves": 150, "sparkles": 180, "item": NSNull(), "userId": "u1", "at": now.addingTimeInterval(-startedAgo).timeIntervalSince1970 * 1000],
                   ["id": "j2", "kind": "gift", "leaves": 1, "sparkles": 0, "item": NSNull(), "userId": NSNull(), "at": now.timeIntervalSince1970 * 1000]]
        album = []
    }

    // MARK: Reads

    nonisolated var client: CompanionClient {
        CompanionClient(
            forHome: { _ in self.stream() },
            album: { _ in self.albumStream() },
            setPlace: { _, place in try await self.setPlace(place) },
            start: { _, species, place, requestID in try await self.start(species, place, requestID) },
            care: { _ in try await self.care() },
            graduate: { _, id in try await self.graduate(id) },
            setLayout: { _, layout in try await self.setLayout(layout) },
            setHolidays: { _, holidays in try await self.setHolidays(holidays) },
            importLocal: { _, _, _ in .closed },
            buy: { _, item, requestID, expected in try await self.buy(item, requestID, expected) }
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
             "startedAt": card.started.timeIntervalSince1970 * 1000, "graduatedAt": card.graduated.timeIntervalSince1970 * 1000]
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

    private func start(_ species: Species, _ place: Place, _ requestID: String) async throws -> StartOutcome {
        startCalls += 1
        try await wait(startCalls == 1 ? "start" : "start-\(startCalls)")
        if let first = starts[requestID] {
            Self.log.notice("server: start replayed for the same request id")
            return StartOutcome(companionID: first.companionID, welcome: nil, graduated: first.graduated.map {
                GraduatedCompanion(companionID: $0.companionID, species: $0.species, paid: nil)
            })
        }
        if !hasHouse { hasHouse = true; tzOffset = place.tzOffset; region = place.region }
        // A ready one graduates first, in the same write.
        var graduated: GraduatedCompanion?
        if let c = current, c.points >= 64 - 1e-9, Date().timeIntervalSince(c.startedAt) >= 6 * 86_400 {
            album.append((c.uuid, c.species, c.seed, c.startedAt, Date()))
            albumCount += 1
            leaves += 100; sparkles += 25
            graduated = GraduatedCompanion(companionID: c.id, species: c.species, paid: Coins(leaves: 100, sparkles: 25))
        }
        let free: Set<Species> = [.magnolia, .basil, .sunflower, .cactus, .duckling, .kitten]
        guard free.contains(species) || ownedSpecies.contains(species.rawValue) else {
            throw AppError.server("That one can't be grown yet")
        }
        let id = "companion-\(albumCount)-\(startCalls)"
        current = Current(id: id, species: species, seed: "bench-home-\(albumCount)", startedAt: Date(), points: 0)
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

    private func graduate(_ id: String) async throws -> Coins? {
        try await wait("graduate")
        guard let c = current, c.points >= 64 - 1e-9, Date().timeIntervalSince(c.startedAt) >= 6 * 86_400 else {
            throw AppError.server("Not grown up yet")
        }
        album.append((c.uuid, c.species, c.seed, c.startedAt, Date()))
        albumCount += 1
        current = nil
        leaves += 100; sparkles += 25
        publish()
        return Coins(leaves: 100, sparkles: 25)
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
