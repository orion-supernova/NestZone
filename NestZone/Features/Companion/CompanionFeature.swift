import ComposableArchitecture
import Foundation

/// The companion on Today ("Nestie" for now): a plant or a pet the house grows
/// together, by doing what it already does.
///
/// An MVP for development builds. It reads the household's finished chores —
/// which every phone already receives, with who finished them and when — and
/// keeps everything else on this device, one file per home: the companion,
/// the album, the house jar and what is out in the scene. Care counts once a
/// day per phone. Nothing here writes to the server, so it can be tried on a
/// real household without a backend change; the server version replaces
/// `house` with a subscription and keeps the rest.
@Reducer
public struct CompanionFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// How many people live here: "together" needs two of them.
        public var memberCount = 1
        /// The container's clock.
        public var now: Date
        /// Every finished chore the Done list holds, handed down by the tab
        /// container from Today's own subscription.
        public var completions: [Completion] = []
        /// Bumped when a chore lands, so the scene can send a drop flying.
        public var choreTick = 0
        /// Bumped when this phone cares for it.
        public var careTick = 0
        /// The finished chores seen so far, so a new one can be told from the
        /// first delivery of the list.
        var seen: Set<Completion> = []
        var hasLoaded = false
        /// The region the default holidays and the hemisphere come from.
        public var region: String?

        @Shared public var house: CompanionHouse

        public var sheet: Sheet?
        /// The scene's layout while Decorate is open, with previews in it.
        public var draft = SceneLayout()
        public var decorateSpot: Spot?
        /// Just paid into the jar, for the little "+10" over it.
        public var lastPay: Payment?
        /// Days with a birthday in the house's calendar: the party hat's.
        public var birthdays: Set<CalendarDay> = []

        /// The card that asks before anything is bought — what it costs and
        /// what is left, the Leaves made up with Sparkles, or how many more it
        /// takes — and that says how a thing is had when it isn't for sale.
        public var card: Card?
        /// The Sparkles store, pushed over whichever sheet sent the house
        /// there. The card stays underneath it.
        public var storeOpen = false
        /// What the house was buying when it went for Sparkles: once there
        /// are enough, the store closes onto the same card.
        public var pending: Purchase?
        /// The packs on the store's shelf, and the one being bought.
        public var packs = SparklePack.shelf
        public var buyingPack: SparklePack.ID?
        /// A pack that didn't simply go through: waiting for a parent's OK, or
        /// failed.
        public var packNote: PackNote?
        /// Sparkles that just landed in the jar, for the store to say so, and
        /// a count of arrivals: the same pack bought twice lands twice.
        public var landed: Int?
        public var landedTick = 0
        /// A decoration to put out as soon as Decorate opens: just bought in
        /// the shop, with "Put it out".
        var placeOnOpen: String?

        public enum Sheet: String, Equatable, Identifiable, Sendable {
            case choose, decorate, album, holidays, lab, ceremony, welcome, shop
            public var id: String { rawValue }
            /// Shown over everything rather than as a sheet: the moments.
            var isMoment: Bool { self == .ceremony || self == .welcome }
        }

        public struct Payment: Equatable, Sendable {
            public var coins: Coins
            public var id: Int
        }

        /// Something about to be bought.
        public struct Purchase: Equatable, Sendable {
            public var item: ShopItem
            /// Grown as soon as it is bought: bought from Choose.
            public var grow: Species?
        }

        public struct Card: Equatable, Sendable {
            /// What the card shows: a fox, even when what is bought is its pack.
            public var item: ShopItem
            /// What buying it would be; `nil` when it isn't for sale today.
            public var purchase: Purchase?
            /// What was paid, once it is: the card has become the moment it
            /// lands in the house, and the coins that fly are these.
            public var paid: Coins?
            public var isBought: Bool { paid != nil }
        }

        /// Where a card stands, worked out from the jar as it is now — so when
        /// the house comes back from the store with enough, the same card
        /// already says so.
        public enum CardStep: Equatable, Sendable {
            case pay(Coins)
            case makeUp(Coins, short: Int)
            case short(sparkles: Int)
            case bought
            case about
        }

        public struct PackNote: Equatable, Sendable {
            public var id: SparklePack.ID
            public var isWaiting: Bool
        }

        public func step(of card: Card) -> CardStep {
            if card.isBought { return .bought }
            guard let price = card.purchase?.item.price else { return .about }
            return switch house.checkout(price) {
            case let .pay(coins): .pay(coins)
            case let .makeUp(coins, short): .makeUp(coins, short: short)
            case let .short(sparkles): .short(sparkles: sparkles)
            }
        }

        public init(homeID: HomeID, now: Date = Date(), region: String? = Locale.current.region?.identifier) {
            self.homeID = homeID
            self.now = now
            self.region = region
            _house = Shared(wrappedValue: .empty, .companion(homeID))
        }

        // MARK: Clock and calendar

        /// The day the scene thinks it is: the lab's pretend day on a
        /// development build, today otherwise.
        public var clock: Date { house.lab.date ?? now }

        public var celebrated: Set<Holiday.ID> {
            house.holidays.map { Set($0.compactMap(Holiday.ID.init(rawValue:))) } ?? Holiday.defaults(for: region)
        }

        public var southern: Bool { Holiday.isSouthern(region) }

        /// The holidays dressing the scene today.
        public var activeHolidays: [Holiday] {
            Holiday.active(on: clock, among: celebrated, region: region)
        }

        /// Everything that decides what the house can have today, worked out
        /// once for a whole shelf.
        public var shop: ShopContext {
            ShopContext(
                clock: clock, southern: southern, owned: house.owned, ownedSpecies: house.ownedSpecies,
                album: house.album, holidays: activeHolidays,
                isBirthday: house.lab.birthday || birthdays.contains(CalendarDay(clock)), region: region
            )
        }

        /// What can be in the scene today: everything the jar has bought or
        /// the house has earned, what every house has, and whatever today's
        /// holidays bring, free while they last.
        public var available: Set<String> {
            let shop = self.shop
            var ids = house.owned
            for item in DecorItem.allCases where shop.standing(of: item).isUsable {
                ids.insert(item.rawValue)
            }
            for holiday in shop.holidays {
                for decor in holiday.decor {
                    if case .flags = decor { ids.insert(decor.rawValue) }
                }
            }
            return ids
        }

        /// The scene as drawn: a holiday's things go back in the box by
        /// themselves when it is over, and come out again next year.
        public var visibleLayout: SceneLayout {
            var layout = house.layout
            let available = self.available
            for spot in Spot.allCases where spot != .tree {
                if let raw = layout[spot], !available.contains(raw) { layout[spot] = nil }
            }
            layout.tree = layout.tree.filter(available.contains)
            if current?.species.isPet == true { layout.tree = []; layout.pot = nil }
            return layout
        }

        /// The first holiday today that putting out would change the scene
        /// for — what the card offers with one tap. A holiday whose things
        /// share a spot (bats and bunting both go overhead) counts as out
        /// once there is nothing left that would move.
        public var holidayToDress: Holiday? {
            let layout = visibleLayout
            return activeHolidays.first { holiday in
                var dressed = layout
                dressed.dress(for: holiday, southern: southern, isPet: current?.species.isPet == true)
                return dressed != layout
            }
        }

        // MARK: Growth

        public var current: Companion? { house.current }

        public var points: Double {
            guard let current else { return 0 }
            return CompanionMath.chorePoints(completions, since: current.startedAt) + current.carePoints + current.bonus
        }

        public var progress: Double { min(points / CompanionMath.graduateAt, 1) }

        public var isPet: Bool { current?.species.isPet ?? false }

        public var stage: Int { CompanionMath.stage(progress: progress, isPet: isPet) }

        public var isReady: Bool { current != nil && progress >= 1 }

        public var mood: Mood {
            guard let current else { return .content }
            if let mood = house.lab.mood { return mood }
            return CompanionMath.mood(
                now: clock, completions: completions, lastCare: current.lastCareAt,
                startedAt: current.startedAt, memberCount: memberCount
            )
        }

        /// Day 1 is the day it arrived.
        public var day: Int {
            guard let current else { return 0 }
            return (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: current.startedAt),
                                                    to: Calendar.current.startOfDay(for: clock)).day ?? 0) + 1
        }

        /// Whether this phone has given today's care.
        public var caredToday: Bool {
            current?.careDays.contains(Self.dayKey(clock)) ?? false
        }

        static func dayKey(_ date: Date) -> String {
            let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }

        /// Starts growing a new companion: the house's first comes with the
        /// welcome gift.
        mutating func grow(_ species: Species) {
            let seed = "\(homeID.rawValue)-\(house.album.count)"
            let now = clock
            let firstTime = !house.welcomed
            $house.withLock {
                $0.current = Companion(species: species, seed: seed, startedAt: now)
                $0.paidStage = 0
                if firstTime {
                    $0.add(Rewards.welcome)
                    $0.welcomed = true
                }
            }
            sheet = firstTime ? .welcome : nil
            if firstTime { lastPay = Payment(coins: Rewards.welcome, id: (lastPay?.id ?? 0) + 1) }
        }

        /// Opens the card for a thing: to buy it if it is on sale today, or to
        /// say how it is had if it isn't.
        mutating func show(_ item: ShopItem, grow: Species? = nil) {
            let forSale = shop.standing(of: item).price != nil
            card = Card(item: item, purchase: forSale ? Purchase(item: item.bought, grow: grow) : nil)
        }

        /// Pays the jar for any stage reached since the last payment.
        mutating func payStages() {
            guard current != nil else { return }
            let reached = stage
            guard reached > house.paidStage else { return }
            let coins = Rewards.stage * (reached - house.paidStage)
            $house.withLock {
                $0.add(coins)
                $0.paidStage = reached
            }
            lastPay = Payment(coins: coins, id: (lastPay?.id ?? 0) + 1)
        }
    }

    public enum Action: Equatable {
        /// The finished chores changed.
        case completionsUpdated([Completion])
        case careTapped
        case chooseTapped
        case chose(Species)
        /// The welcome gift's "Decorate now".
        case welcomeDecorateTapped
        case celebrateTapped
        case ceremonyFinished
        case albumTapped
        case holidaysTapped
        case holidayToggled(Holiday.ID)
        case holidaysReset
        /// The card's "put out the Diwali things", straight into the scene.
        case dressTapped(Holiday.ID)

        case decorateTapped
        case spotPicked(Spot?)
        case decorToggled(String)
        case setPicked(Holiday.ID)
        case decorateDone
        case decorateCancelled

        /// The jar on the card: the whole catalog.
        case shopTapped
        /// A thing in the shop or Decorate: its card — to buy it, or to say
        /// how it comes.
        case itemTapped(ShopItem)
        /// A species on Choose: grown straight away if the house has it, its
        /// card otherwise.
        case growTapped(Species)
        case cardBuyTapped
        case cardStoreTapped
        case cardPutOutTapped
        case cardDismissed
        /// A companion bought on Choose, once the moment has played.
        case cardGrow(Species)
        case storeTapped
        case storeDismissed
        case storeAppeared
        case packsLoaded([SparklePack])
        case packTapped(SparklePack)
        case packBought(SparklePack.ID, PurchaseOutcome)
        case packFailed(SparklePack.ID)
        /// Back from the store with enough, after the Sparkles were seen to land.
        case storeReturned
        case birthdaysUpdated(Set<CalendarDay>)

        case labTapped
        case labPoints(Double)
        case labMood(Mood?)
        case labDate(Date?)
        case labCoins(Coins)
        case labBirthday(Bool)
        case labDusk(Bool)
        case labReset

        case sheetDismissed
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.sparkleStore) var sparkleStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .completionsUpdated(completions):
                let incoming = Set(completions)
                // A chore finished a moment ago, by anyone, anywhere in the
                // app — not the first delivery of a month of Done list.
                let fresh = incoming.subtracting(state.seen).contains { state.now.timeIntervalSince($0.at) < 180 }
                if state.hasLoaded, fresh { state.choreTick += 1 }
                state.seen = incoming
                state.hasLoaded = true
                guard completions != state.completions else { return .none }
                state.completions = completions
                state.payStages()
                return .none

            case .careTapped:
                guard state.current != nil else { return .none }
                let key = State.dayKey(state.clock)
                let at = state.clock
                state.careTick += 1
                // Once a day counts; every tap still gets a reaction. The file
                // is written when something changes — the first care of the
                // day, a minute on, or a lab mood to wake — not on every tap
                // of a happy burst.
                let wakes = state.house.lab.mood?.isQuiet == true
                let isNew = state.current.map { !$0.careDays.contains(key) } ?? false
                let isStale = state.current?.lastCareAt.map { at.timeIntervalSince($0) > 60 } ?? true
                guard isNew || isStale || wakes else { return .none }
                state.$house.withLock {
                    guard var current = $0.current else { return }
                    if !current.careDays.contains(key) { current.careDays.append(key) }
                    current.lastCareAt = at
                    $0.current = current
                    // Caring is coming back: it wakes up whatever the lab said.
                    if $0.lab.mood?.isQuiet == true { $0.lab.mood = nil }
                }
                state.payStages()
                return .none

            case .chooseTapped:
                state.sheet = .choose
                return .none

            case let .chose(species):
                guard state.shop.standing(of: species).isUsable else { return .none }
                state.grow(species)
                return .none

            case let .growTapped(species):
                let standing = state.shop.standing(of: species)
                if standing.isUsable {
                    state.grow(species)
                } else {
                    state.show(.species(species), grow: standing.price != nil ? species : nil)
                }
                return .none

            case .shopTapped:
                state.sheet = .shop
                return .none

            case let .itemTapped(item):
                state.show(item)
                return .none

            case .cardBuyTapped:
                guard var card = state.card, !card.isBought, let purchase = card.purchase,
                      let price = purchase.item.price, state.shop.standing(of: purchase.item).price != nil
                else { return .none }
                let coins: Coins
                switch state.house.checkout(price) {
                case let .pay(paying), let .makeUp(paying, _): coins = paying
                // The card offers the store instead of a Buy button; nothing to do.
                case .short: return .none
                }
                state.$house.withLock {
                    $0.pay(coins)
                    $0.receive(purchase.item)
                }
                card.paid = coins
                state.card = card
                // A companion bought on Choose starts growing once the moment
                // has played: the coins land, it says it's in the house.
                guard let species = purchase.grow else { return .none }
                return .run { send in
                    try await clock.sleep(for: .milliseconds(1400))
                    await send(.cardGrow(species))
                }

            case let .cardGrow(species):
                state.card = nil
                state.grow(species)
                return .none

            case .cardStoreTapped:
                state.pending = state.card?.purchase
                state.landed = nil
                state.packNote = nil
                state.storeOpen = true
                return .none

            case .cardPutOutTapped:
                guard let card = state.card else { return .none }
                state.card = nil
                // In Decorate it is out already: it was bought as the preview.
                guard state.sheet != .decorate, case let .decor(item) = card.item else { return .none }
                state.placeOnOpen = item.rawValue
                state.sheet = nil
                return .run { send in
                    try await clock.sleep(for: .milliseconds(450))
                    await send(.decorateTapped)
                }

            case .cardDismissed:
                state.card = nil
                return .none

            case .storeTapped:
                state.pending = nil
                state.landed = nil
                state.packNote = nil
                state.storeOpen = true
                return .none

            case .storeDismissed:
                state.storeOpen = false
                state.pending = nil
                state.landed = nil
                state.packNote = nil
                return .none

            case .storeAppeared:
                return .run { send in
                    if let packs = try? await sparkleStore.packs(), !packs.isEmpty {
                        await send(.packsLoaded(packs))
                    }
                }

            case let .packsLoaded(packs):
                state.packs = packs
                return .none

            case let .packTapped(pack):
                guard state.buyingPack == nil else { return .none }
                state.buyingPack = pack.id
                state.packNote = nil
                return .run { send in
                    do {
                        await send(.packBought(pack.id, try await sparkleStore.purchase(pack.id)))
                    } catch {
                        await send(.packFailed(pack.id))
                    }
                }

            case let .packBought(id, outcome):
                state.buyingPack = nil
                let sparkles: Int
                switch outcome {
                case .cancelled: return .none
                case .pending:
                    state.packNote = State.PackNote(id: id, isWaiting: true)
                    return .none
                case let .added(added): sparkles = added
                }
                state.$house.withLock { $0.sparkles += sparkles }
                state.landed = sparkles
                state.landedTick += 1
                // Enough now for what sent them here: a moment to see the
                // Sparkles land — that second is how anyone knows it worked —
                // then back to the card, which already says so. Not enough
                // yet, and the store stays.
                guard let price = state.pending?.item.price else { return .none }
                if case .short = state.house.checkout(price) { return .none }
                return .run { send in
                    try await clock.sleep(for: .milliseconds(1300))
                    await send(.storeReturned)
                }

            case let .packFailed(id):
                state.buyingPack = nil
                state.packNote = State.PackNote(id: id, isWaiting: false)
                return .none

            case .storeReturned:
                guard state.storeOpen else { return .none }
                state.storeOpen = false
                state.pending = nil
                state.landed = nil
                return .none

            case let .birthdaysUpdated(days):
                state.birthdays = days
                return .none

            case .welcomeDecorateTapped:
                // The gift closes first; Decorate opens once it has gone, so
                // the two presentations never fight over the screen.
                state.sheet = nil
                return .run { send in
                    try await clock.sleep(for: .milliseconds(450))
                    await send(.decorateTapped)
                }

            case .celebrateTapped:
                guard state.isReady else { return .none }
                state.sheet = .ceremony
                return .none

            case .ceremonyFinished:
                guard let current = state.current, state.isReady else {
                    state.sheet = nil
                    return .none
                }
                let graduate = Graduate(id: UUID(), species: current.species, seed: current.seed,
                                        startedAt: current.startedAt, graduatedAt: state.clock)
                state.$house.withLock {
                    $0.album.append(graduate)
                    $0.add(Rewards.graduation)
                    $0.current = nil
                    $0.paidStage = 0
                }
                state.lastPay = State.Payment(coins: Rewards.graduation, id: (state.lastPay?.id ?? 0) + 1)
                // Straight on to the next one: nothing done while the house
                // decides is lost, because growth counts from when it arrives.
                state.sheet = .choose
                return .none

            case .albumTapped:
                state.sheet = .album
                return .none

            case .holidaysTapped:
                state.sheet = .holidays
                return .none

            case let .holidayToggled(id):
                var ids = state.celebrated
                if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
                let raw = Holiday.all.map(\.id).filter(ids.contains).map(\.rawValue)
                state.$house.withLock { $0.holidays = raw }
                return .none

            case .holidaysReset:
                state.$house.withLock { $0.holidays = nil }
                return .none

            case let .dressTapped(id):
                guard let holiday = Holiday.with(id) else { return .none }
                let southern = state.southern, isPet = state.isPet
                state.$house.withLock { $0.layout.dress(for: holiday, southern: southern, isPet: isPet) }
                return .none

            case .decorateTapped:
                state.draft = state.visibleLayout
                state.decorateSpot = nil
                // Bought in the shop with "Put it out": out it goes, its spot
                // picked, so the tray shows it placed.
                if let raw = state.placeOnOpen, let decor = Decor(rawValue: raw) {
                    state.draft.place(decor)
                    state.decorateSpot = (state.isPet ? Spot.forPets : Spot.allCases).first { $0.kind == decor.kind }
                    state.placeOnOpen = nil
                }
                state.sheet = .decorate
                return .none

            case let .spotPicked(spot):
                state.decorateSpot = spot
                return .none

            case let .decorToggled(raw):
                guard let spot = state.decorateSpot else { return .none }
                state.draft.toggle(raw, in: spot)
                return .none

            case let .setPicked(id):
                guard let holiday = Holiday.with(id) else { return .none }
                state.draft.dress(for: holiday, southern: state.southern, isPet: state.isPet)
                return .none

            case .decorateDone:
                // Previews that were never bought go back on the shelf: nothing
                // is bought by closing a sheet.
                var layout = state.draft
                let available = state.available
                for spot in Spot.allCases where spot != .tree {
                    if let raw = layout[spot], !available.contains(raw) { layout[spot] = nil }
                }
                layout.tree = layout.tree.filter(available.contains)
                state.$house.withLock { $0.layout = layout }
                state.sheet = nil
                state.decorateSpot = nil
                return .none

            case .decorateCancelled:
                state.sheet = nil
                state.decorateSpot = nil
                return .none

            case .labTapped:
                state.sheet = .lab
                return .none

            case let .labPoints(points):
                // Taking points away stops at a seed, never below nothing grown.
                let earned = state.points - (state.current?.bonus ?? 0)
                state.$house.withLock {
                    guard let bonus = $0.current?.bonus else { return }
                    $0.current?.bonus = max(bonus + points, -earned)
                }
                state.payStages()
                return .none

            case let .labMood(mood):
                state.$house.withLock { $0.lab.mood = mood }
                return .none

            case let .labDate(date):
                state.$house.withLock { $0.lab.date = date }
                return .none

            case let .labCoins(coins):
                state.$house.withLock { $0.add(coins) }
                return .none

            case let .labBirthday(on):
                state.$house.withLock { $0.lab.birthday = on }
                return .none

            case let .labDusk(on):
                state.$house.withLock { $0.lab.dusk = on }
                return .none

            case .labReset:
                state.$house.withLock { $0 = .empty }
                state.sheet = nil
                return .none

            case .sheetDismissed:
                state.sheet = nil
                state.decorateSpot = nil
                state.card = nil
                state.storeOpen = false
                state.pending = nil
                state.landed = nil
                state.packNote = nil
                return .none
            }
        }
    }
}

/// Whether the companion shows. On for development builds only while it is an
/// MVP: a release build compiles it and never draws it.
public enum CompanionFlag {
    #if DEBUG
    public static let isEnabled = true
    #else
    public static let isEnabled = false
    #endif
}
