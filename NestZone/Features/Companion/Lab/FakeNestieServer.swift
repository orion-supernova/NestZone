#if DEBUG
import ComposableArchitecture
import Foundation
import os

/// A stand-in for the server's Nestie, on the phone, with no network at all.
///
/// It is what the bench runs against on a simulator nobody is signed in on,
/// and what the Lab's pretend house runs against on the owner's own phone. The
/// real feature, reducer and views sit on top of it with only the
/// `CompanionClient` replaced, so every flow is the real one: a write answers
/// after a little latency, the live read pushes after every change, and the
/// rules the client depends on are kept — one answer per request id, a price
/// the catalog decides, a welcome gift once, a graduation only when grown.
///
/// The house is a `PretendState` value. With a `file` it is written there
/// after each change and read back on the next launch, so the pretend house
/// survives a relaunch; the bench has none and starts from its scenario.
///
/// Nothing in here reaches `ConvexConnection`, by construction: this file
/// does not name it.
actor FakeNestieServer {
    private(set) var state: PretendState
    private var config: Bench.Arguments
    private let file: URL?
    private let clock: @Sendable () -> Date
    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Nestie")

    // What it has been asked.
    private var seenBuys: [String: BuyOutcome] = [:]
    private var starts: [String: StartOutcome] = [:]
    private var buyCalls = 0
    private var startCalls = 0
    private var subscribers: [UUID: AsyncThrowingStream<CompanionPayload, any Error>.Continuation] = [:]
    private var albumSubscribers: [UUID: AsyncThrowingStream<CompanionPayload.Cards, any Error>.Continuation] = [:]
    private var houseSubscribers: [UUID: AsyncStream<PretendState>.Continuation] = [:]
    private var pushing: Task<Void, Never>?
    private var saving: Task<Void, Never>?
    /// The next purchase's answer, whatever it would honestly have been.
    private var forcedBuy: String?

    /// `file`: where the house is kept between launches. A file that is not
    /// there, or cannot be read, starts the scenario's house instead.
    init(
        _ config: Bench.Arguments = Bench.Arguments(), file: URL? = nil, home: String = "pretend",
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.file = file
        self.clock = clock
        if let file, let data = try? Data(contentsOf: file), let kept = try? JSONDecoder().decode(PretendState.self, from: data) {
            state = kept
        } else {
            state = PretendState.scenario(config.scenario, now: clock(), species: config.species, decor: config.decor, home: home)
        }
        forcedBuy = config.buy == "honest" ? nil : config.buy
    }

    /// The pretend house of this phone: one file, whichever home is open.
    static let device: FakeNestieServer = {
        var arguments = Bench.Arguments()
        arguments.latency = .milliseconds(150)
        return FakeNestieServer(arguments, file: URL.documentsDirectory.appending(component: "pretendHouse.json"))
    }()

    // MARK: The clients

    nonisolated var client: CompanionClient {
        CompanionClient(
            forHome: { _ in self.stream() },
            album: { _ in self.albumStream() },
            setPlace: { _, place in try await self.setPlace(place) },
            start: { _, species, place, requestID, colour in try await self.start(species, place, requestID, colour) },
            care: { _ in try await self.care() },
            graduate: { _, id in try await self.graduate(id) },
            ballot: { _, species, answer in try await self.ballot(species, answer) },
            decide: { _ in try await self.decide() },
            setLayout: { _, layout in try await self.setLayout(layout) },
            setHolidays: { _, holidays in try await self.setHolidays(holidays) },
            // The MVP's file belongs to the real house: it is never offered here.
            importLocal: { _, _, _ in .closed },
            buy: { _, item, requestID, expected in try await self.buy(item, requestID, expected) },
            // A signed transaction is Apple's: nothing here credits one.
            topUp: { _, _ in TopUpOutcome(status: .invalid) }
        )
    }

    /// The Sparkles store of the pretend house: charges nothing, and what a
    /// pack buys is credited to the pretend jar as the server would credit it
    /// (`added`), so the store's whole path is the real one.
    nonisolated var store: SparkleStoreClient {
        SparkleStoreClient(
            packs: { SparklePack.shelf },
            purchase: { id, _, _ in
                try await Task.sleep(for: .milliseconds(600))
                // `-sparkleOutcome ask` or `fail`, to see the store's other answers.
                switch UserDefaults.standard.string(forKey: "sparkleOutcome") {
                case "ask": return .pending
                case "fail": throw CancellationError()
                default: break
                }
                guard let sparkles = SparklePack.shelf.first(where: { $0.id == id })?.sparkles else { return .cancelled }
                await self.apply(.topUp(sparkles))
                return .added(sparkles)
            },
            credits: { _, _ in AsyncStream { $0.finish() } }
        )
    }

    // MARK: Reads

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
        subscribers[id] = continuation
        continuation.yield(state.payload(now: clock()))
    }

    private func detach(_ id: UUID) { subscribers[id] = nil }

    private func attachAlbum(_ id: UUID, _ continuation: AsyncThrowingStream<CompanionPayload.Cards, any Error>.Continuation) {
        albumSubscribers[id] = continuation
        continuation.yield(state.cards())
    }

    private func detachAlbum(_ id: UUID) { albumSubscribers[id] = nil }

    private func push() {
        let next = state.payload(now: clock())
        for continuation in subscribers.values { continuation.yield(next) }
        let cards = state.cards()
        for continuation in albumSubscribers.values { continuation.yield(cards) }
        for continuation in houseSubscribers.values { continuation.yield(state) }
        save()
    }

    /// The house itself, as the Lab reads it: what the pretend server holds,
    /// which the card's own read does not carry (a housemate's ballots, what
    /// is owned and not out). Yields now, and after every change.
    nonisolated func houses() -> AsyncStream<PretendState> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.attachHouse(id, continuation) }
            continuation.onTermination = { _ in Task { await self.detachHouse(id) } }
        }
    }

    private func attachHouse(_ id: UUID, _ continuation: AsyncStream<PretendState>.Continuation) {
        houseSubscribers[id] = continuation
        continuation.yield(state)
    }

    private func detachHouse(_ id: UUID) { houseSubscribers[id] = nil }

    /// A live house: someone finishes something every so often.
    func pushForever() {
        guard pushing == nil else { return }
        pushing = Task {
            var n = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                n += 1
                state.recent.insert(.init(kind: "chore", at: clock(), user: n.isMultiple(of: 2) ? "u1" : "u2"), at: 0)
                if state.recent.count > 120 { state.recent.removeLast() }
                // `-nestiePush 2`: the house is busy but the points do not move.
                if n.isMultiple(of: 5), UserDefaults.standard.integer(forKey: "nestiePush") != 2 { state.current?.points += 0.4 }
                push()
            }
        }
    }

    // MARK: Keeping the house

    /// Written a moment after the last change, so a slider that moves it
    /// sixty times a second writes once.
    private func save() {
        guard let file else { return }
        saving?.cancel()
        saving = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let data = try? JSONEncoder().encode(state) else { return }
            try? data.write(to: file, options: .atomic)
        }
    }

    /// What a test reads.
    func snapshot() -> PretendState { state }

    // MARK: The Lab

    /// A change from the Lab. It is the house changing, so it is pushed as
    /// any change would be.
    func apply(_ command: PretendCommand) {
        switch command {
        case let .setLatency(ms): config.latency = .milliseconds(ms)
        case let .setOffline(on): config.offline = on
        case let .nextBuy(mode): forcedBuy = mode
        case .reset, .preset, .freshHouse:
            seenBuys = [:]
            starts = [:]
            state.apply(command, now: clock())
        default:
            state.apply(command, now: clock())
        }
        push()
    }

    // MARK: Writes

    private func wait(_ name: String) async throws {
        try await Task.sleep(for: config.latency)
        Self.log.notice("server: \(name, privacy: .public)")
        // Never answers: the client's own timeout has to end it.
        if config.fail.contains("hang") { try await Task.sleep(for: .seconds(3600)) }
        if config.offline || config.fail.contains(name) { throw URLError(.notConnectedToInternet) }
    }

    private func setPlace(_ place: Place) async throws -> Bool {
        try await wait("setPlace")
        state.tzOffset = place.tzOffset
        state.region = place.region
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

    private func start(_ species: Species, _ place: Place, _ requestID: String, _ colour: Int?) async throws -> StartOutcome {
        startCalls += 1
        try await wait(startCalls == 1 ? "start" : "start-\(startCalls)")
        let now = clock()
        if let first = starts[requestID] {
            Self.log.notice("server: start replayed for the same request id")
            return StartOutcome(companionID: first.companionID, welcome: nil, graduated: first.graduated.map {
                GraduatedCompanion(companionID: $0.companionID, species: $0.species, paid: nil, finale: $0.finale)
            })
        }
        if !state.hasHouse {
            state.hasHouse = true
            state.tzOffset = place.tzOffset
            state.region = place.region
        }
        // A seed the house has not named: this is the pick, and it keeps its growth.
        if var seed = state.current, seed.undecided {
            if let vote = state.vote, vote.isOpen, vote.othersVoted {
                throw AppError.server("The house is voting on the next one")
            }
            seed.species = species
            seed.undecided = false
            state.current = seed
            if state.vote?.isOpen == true { state.vote?.status = "closed"; state.vote?.how = "picked"; state.vote?.winner = species.rawValue }
            let outcome = StartOutcome(companionID: seed.id)
            starts[requestID] = outcome
            publish()
            return outcome
        }
        // A colour is the server's to judge: after the finale, for a species
        // grown, in a colour not grown yet. Thrown, with the server's words.
        if let colour {
            guard Colourway.range.contains(colour) else { throw AppError.server("There's no such colour") }
            let finished = state.finaleAt != nil || Species.freeToHave.isSubset(of: state.grown)
            guard finished, state.grown.contains(species), !state.grownColours.contains(Colourway.key(species, colour))
            else { throw AppError.server("That colour can't be grown yet") }
        }
        // What costs something has to be bought first; the rest (free, in
        // season, earned) is the client's to have judged.
        switch species.access {
        case .buy, .pack:
            guard state.ownedSpecies.contains(species.rawValue) else { throw AppError.server("That one can't be grown yet") }
        default: break
        }
        // A ready one graduates first, in the same write.
        var graduated: GraduatedCompanion?
        if let c = state.current, state.isReady(c, now: now) {
            let done = state.graduate(c, now: now)
            graduated = GraduatedCompanion(companionID: c.id, species: c.species, paid: done.paid, finale: done.finale)
        }
        let id = "companion-\(state.albumCount)-\(startCalls)"
        state.current = PretendState.Current(
            id: id, species: species, seed: "pretend-\(state.albumCount)", startedAt: now, points: 0, colour: colour
        )
        state.vote = nil
        var welcome: Coins?
        if !state.welcomed {
            state.welcomed = true
            state.leaves += Rewards.welcome.leaves
            state.sparkles += Rewards.welcome.sparkles
            state.addJar("welcome", leaves: Rewards.welcome.leaves, sparkles: Rewards.welcome.sparkles, at: now)
            welcome = Rewards.welcome
        }
        let outcome = StartOutcome(companionID: id, welcome: welcome, graduated: graduated)
        starts[requestID] = outcome
        publish()
        // The write went through and the answer was lost on the way back.
        if config.fail.contains("startAfter"), startCalls == 1 { throw URLError(.networkConnectionLost) }
        return outcome
    }

    /// An answer to one option, or (`nil`) taking it back. When everyone has
    /// answered everything, the vote ends and the seed is named.
    private func ballot(_ species: String, _ answer: Bool?) async throws {
        try await wait("ballot")
        guard state.vote?.isOpen == true else { throw AppError.server("That vote is over") }
        state.apply(.ballot(member: 0, species: species, answer: answer), now: clock())
        publish()
    }

    private func decide() async throws -> DecideOutcome {
        try await wait("decide")
        guard let v = state.vote else { return .none }
        if !v.isOpen { return .closed(winner: v.winner) }
        guard v.othersVoted else { return .alone }
        guard let winner = v.leader else { return .noVotes }
        state.closeVote(how: "decided", winner: winner)
        publish()
        return .chosen(winner: winner)
    }

    private func care() async throws -> Bool {
        try await wait("care")
        guard var c = state.current else { return false }
        let now = clock()
        let day = state.dayKey(now)
        let counted = !c.careDays.contains(day)
        if counted { c.careDays.insert(day, at: 0); c.points += PretendRules.carePoints }
        c.lastCare = now
        state.current = c
        if counted { state.settleStages(now: now) }
        publish()
        return counted
    }

    private func graduate(_ id: String) async throws -> GraduateOutcome {
        try await wait("graduate")
        let now = clock()
        guard let c = state.current, state.isReady(c, now: now) else { throw AppError.server("Not grown up yet") }
        state.current = nil
        state.vote = nil
        let done = state.graduate(c, now: now)
        // A house of two or more votes on the next one, in the same write.
        var vote: PollID?
        if state.members > 1 {
            state.openVote(now: now)
            vote = PollID(state.vote?.pollID ?? "pretend-poll")
        }
        publish()
        return GraduateOutcome(paid: done.paid, vote: vote, finale: done.finale)
    }

    private func setLayout(_ layout: SceneLayout) async throws -> SceneLayout {
        try await wait("layout")
        state.layout = layout
        publish()
        return layout
    }

    private func setHolidays(_ holidays: [String]?) async throws -> [String]? {
        try await wait("holidays")
        state.holidays = holidays
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
        let now = clock()
        func take() -> BuyOutcome {
            var house = CompanionHouse()
            house.leaves = state.leaves
            house.sparkles = state.sparkles
            switch house.checkout(price) {
            case let .short(more):
                return .short(sparkles: more, price: price)
            case let .pay(coins), let .makeUp(coins, _):
                state.leaves -= coins.leaves
                state.sparkles -= coins.sparkles
                give(item)
                state.addJar("buy", leaves: -coins.leaves, sparkles: -coins.sparkles, item: "x", at: now)
                return .bought(paid: coins, madeUp: nil, jar: Coins(leaves: state.leaves, sparkles: state.sparkles), replay: false)
            }
        }
        var outcome: BuyOutcome
        let forced = forcedBuy
        forcedBuy = nil
        switch forced {
        case "owned":
            // Another phone got there first: the house has it, nothing is charged.
            give(item)
            outcome = .owned
        case "short": outcome = .short(sparkles: 40, price: price)
        case "unavailable": outcome = .unavailable
        case "priceChanged": outcome = .priceChanged(price.moved(by: 20))
        default:
            if has(item) {
                outcome = .owned
            } else {
                outcome = expected == price ? take() : .priceChanged(price)
            }
        }
        if case .bought = outcome { seenBuys[requestID] = outcome }
        publish()
        // The write went through and the answer was lost on the way back.
        if config.fail.contains("buyAfter"), call == 1 { throw URLError(.networkConnectionLost) }
        return outcome
    }

    private func give(_ item: ShopItem) {
        switch item {
        case let .decor(decor): state.owned.insert(decor.rawValue)
        case let .species(species): state.ownedSpecies.insert(species.rawValue)
        case let .pack(pack): state.ownedSpecies.formUnion(pack.species.map(\.rawValue))
        }
    }

    private func has(_ item: ShopItem) -> Bool {
        switch item {
        case let .decor(decor): state.owned.contains(decor.rawValue)
        case let .species(species): state.ownedSpecies.contains(species.rawValue)
        case let .pack(pack): pack.species.allSatisfy { state.ownedSpecies.contains($0.rawValue) }
        }
    }
}

extension Price {
    /// The same price in the same coin, moved: what a catalog that changed
    /// under the card would ask.
    fileprivate func moved(by amount: Int) -> Price {
        switch self {
        case let .leaves(value): .leaves(value + amount)
        case let .sparkles(value): .sparkles(value + amount)
        }
    }
}
#endif
