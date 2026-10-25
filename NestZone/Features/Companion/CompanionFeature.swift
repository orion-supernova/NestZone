import ComposableArchitecture
import Foundation
import os

/// The companion on Today ("Nestie" for now): a plant or a pet the house grows
/// together, by doing what it already does.
///
/// The house's companion is the server's, one for every phone in it:
/// `companion:forHome` is a live subscription that carries the jar, the scene,
/// the holidays, the one growing and its growth, and `recent` for the mood.
/// Growth is counted there; this feature counts nothing.
///
/// What the person does is written optimistically, and every write owns its
/// own rollback. A write's effect on the screen is an entry in `writes`, laid
/// over `served` when the house is drawn (`State.house`). Two things keep that
/// honest whichever of the answer and the live push arrives first:
///
/// - An entry shows only while `served` does not already show what it
///   promised: a buy's debit stops once `served` owns the thing, a start's
///   companion once `served` is growing it. So the push first never counts a
///   debit twice, and the entry that outlives its answer never contradicts
///   the push.
/// - When the answer comes, it is folded into `served` before the entry goes
///   (the layout sent, the holidays, the care day, the jar after a buy), so
///   nothing flickers back. A start's and a graduation's entry wait for the
///   push that shows them, because only the push has the new companion.
///
/// A failed write changed nothing on the server, so taking its entry off *is*
/// the rollback; the failure only has to say so. Every write is raced against
/// a timeout, and a timeout is a failure: the request ids make a late arrival
/// harmless.
///
/// The Lab (development builds) is laid over the same way, from its own file,
/// and is a local preview: it never writes, and nothing it influences is sent.
@Reducer
public struct CompanionFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, for the one thing kept per person: the import's mark.
        public var userID: UserID?
        /// How many people live here: "together" needs two of them.
        public var memberCount = 1
        /// The container's clock.
        public var now: Date
        /// Every finished chore the Done list holds, handed down by the tab
        /// container from Today's own subscription. Only to react to a chore
        /// finished a moment ago; growth is not counted from it.
        public var completions: [Completion] = []
        /// Bumped when a chore lands, so the scene can send a drop flying.
        public var choreTick = 0
        /// Bumped when this phone cares for it.
        public var careTick = 0
        /// The finished chores seen so far, so a new one can be told from the
        /// first delivery of the list.
        var seen: Set<Completion> = []
        var hasLoaded = false
        /// This phone's region: the house's own wins once it has one
        /// (`placeRegion`), and it is what a phone offers when the house has none.
        public var region: String?

        // MARK: What the server said

        /// The house as the server last said it, album apart.
        var served = CompanionHouse.empty
        /// What the house did lately, for the mood.
        var activity: [Completion] = []
        /// Who added to the jar and who spent from it. Not drawn yet.
        var jarFeed: [CompanionPayload.JarEntry] = []
        /// Whether the first delivery has come. Until it has, the card is not
        /// drawn: a house that has a companion must not be offered a new one.
        public var isLoaded = false
        /// The last delivery could not be read. The card says so, and keeps
        /// what it had; it never reads an unreadable companion as none.
        public var isUnreadable = false
        /// Writes that are on their way, and what they show meanwhile.
        var writes = Writes()
        /// The Lab: a local preview laid over the house, never sent anywhere.
        @Shared public var lab: CompanionHouse.Lab
        var placeTold = false
        var importTried = false
        var streamRetries = 0

        @Presents public var alert: AlertState<Action.Alert>?

        public var sheet: Sheet?
        /// The scene's layout while Decorate is open, with previews in it.
        public var draft = SceneLayout()
        public var decorateSpot: Spot?
        /// Just paid into the jar, for the little "+10" over it.
        public var lastPay: Payment?
        /// Days with a birthday in the house's calendar: the party hat's.
        public var birthdays: Set<CalendarDay> = []
        /// A graduation that happened under a start, to be shown once.
        public var moment: Moment?
        /// Bumped when this phone answers an option of the vote: the tap's own
        /// haptic is keyed on it, never on the tally a push can also move.
        public var ballotTick = 0
        /// Settling the vote is on its way to the server.
        public var isDeciding = false
        /// Why settling did nothing, until anything about the vote moves.
        public var voteNote: VoteNote?
        /// When the ceremony's cover was closed, so a sheet that follows it
        /// waits out what is left of the pause a closing presentation needs.
        var ceremonyClosedAt: Date?
        /// A graduation into a vote is on its way and the vote is not known
        /// yet: the card says so and offers no pick.
        public var isOpeningVote = false

        /// The card that asks before anything is bought — what it costs and
        /// what is left, the Leaves made up with Sparkles, or how many more it
        /// takes — and that says how a thing is had when it isn't for sale.
        public var card: Card?
        /// The last purchase that did not get an answer, so tapping Buy again
        /// is the same purchase (the same request id) and not a second one.
        var retry: BuyAttempt?
        /// The same for choosing a companion.
        var startAttempt: StartAttempt?
        /// The Sparkles store, pushed over whichever sheet sent the house
        /// there. The card stays underneath it.
        public var storeOpen = false
        /// What the house was buying when it went for Sparkles: once there
        /// are enough, the store closes onto the same card.
        public var pending: Purchase?
        /// The packs on the store's shelf, and the one being bought.
        /// Empty until the store has priced them: the live store has no
        /// packs to show before it answers, and an unpriced shelf would be
        /// buttons for products it may not have. Loaded once, then kept.
        public var packs = SparkleStoreClient.isTestStore ? SparklePack.shelf : []
        public var arePacksLoaded = false
        /// The store could not be asked, or had none to sell.
        public var packsUnavailable = false
        public var buyingPack: SparklePack.ID?
        /// The way back to the card is already on its way (see `landed`).
        var isReturning = false
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
        /// A sheet that is about to open after a pause (Decorate, after the
        /// card or the welcome closes), so nothing else is put in its place.
        var pendingSheet: Sheet?
        /// The ceremony for a queued moment is waiting out its pause.
        var momentScheduled = false
        /// A readable delivery has come: the first one is not "news".
        var hasRead = false
        /// What today's holidays are, kept while its inputs hold: the
        /// calendar arithmetic is not worth doing on every action.
        var holidayCache: HolidayCache?

        // MARK: What is drawn, worked out once per action
        //
        // Stored, and assigned only when they change (`refresh`), so a view
        // that reads one is redrawn by that one and not by every delivery:
        // the jar does not redraw when the points move, and the scene does
        // not when the jar does.

        public var jar = Coins(leaves: 0, sparkles: 0)
        public var current: Companion?
        /// Whether there is one, and which: what the card's frame and its
        /// title need, so they are not redrawn by the points.
        public var hasCompanion = false
        public var species: Species?
        /// The companion as the scene draws it — species, seed and when it
        /// arrived — without its points or its care, which change more often
        /// than anything the scene shows.
        public var look: Companion?
        public var points = 0.0
        public var progress = 0.0
        public var stage = 0
        public var isReady = false
        public var mood = Mood.content
        public var caredToday = false
        public var day = 0
        public var southern = false
        public var activeHolidays: [Holiday] = []
        public var holidayToDress: Holiday?
        public var visibleLayout = SceneLayout()
        /// The house has not chosen what the one growing is: it is drawn and
        /// called a seed, and `species` is nil (the server's is only the
        /// vote's first option, standing in).
        public var isUndecided = false
        /// The house's vote for the one growing, with this phone's own ballots
        /// laid over it.
        public var vote: CompanionVote?

        /// What stands in for a seed's species where one is needed to draw:
        /// a sketched plant, whose first stage is a sprout whatever it grows
        /// into, so the stand-in is never drawn as if it had been chosen.
        static let seedStandIn = Species.basil

        public enum VoteNote: Equatable, Sendable {
            /// Nobody else has answered: settling would be a pick.
            case alone
            /// Nobody has said yes to anything yet.
            case noVotes
        }

        public enum Sheet: String, Equatable, Identifiable, Sendable {
            case choose, decorate, album, holidays, lab, ceremony, welcome, shop, vote
            public var id: String { rawValue }
            /// Shown over everything rather than as a sheet: the moments.
            var isMoment: Bool { self == .ceremony || self == .welcome }
        }

        public struct Payment: Equatable, Sendable {
            public var coins: Coins
            public var id: Int
        }

        /// A companion that graduated, for the ceremony to show once.
        public struct Moment: Equatable, Sendable {
            public var species: Species
            public var seed: String
            public var startedAt: Date
            public var graduatedAt: Date
            public var paid: Coins?
        }

        struct HolidayCache: Equatable, Sendable {
            var day: String
            var region: String?
            var celebrated: Set<Holiday.ID>
            var holidays: [Holiday]
        }

        /// Something about to be bought.
        public struct Purchase: Equatable, Sendable {
            public var item: ShopItem
            /// Grown as soon as it is bought: bought from Choose.
            public var grow: Species?
            /// The price the server asked when it differed from the catalog
            /// here. The server's prices win.
            public var priceOverride: Price?

            public var price: Price? { priceOverride ?? item.price }

            public init(item: ShopItem, grow: Species? = nil, priceOverride: Price? = nil) {
                self.item = item
                self.grow = grow
                self.priceOverride = priceOverride
            }
        }

        public struct Card: Equatable, Sendable {
            /// What the card shows: a fox, even when what is bought is its pack.
            public var item: ShopItem
            /// What buying it would be; `nil` when it isn't for sale today.
            public var purchase: Purchase?
            /// What was paid, once it is: the card has become the moment it
            /// lands in the house, and the coins that fly are these.
            public var paid: Coins?
            /// What the server said that the card has to tell, in place of its
            /// question.
            public var notice: Notice?
            /// The server said the jar is short, whatever this phone thought
            /// it had; true until the jar changes.
            public var shortNote: ShortNote?
            public var isBought: Bool { paid != nil }

            public enum Notice: Equatable, Sendable {
                /// Not for sale today, as far as the server is concerned.
                case unavailable
                /// The server could not be reached or did not answer.
                case offline
            }

            public struct ShortNote: Equatable, Sendable {
                public var sparkles: Int
                /// The jar the server judged it against.
                public var jar: Coins
            }

            public init(item: ShopItem, purchase: Purchase?) {
                self.item = item
                self.purchase = purchase
            }
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
            case notice(Card.Notice)
        }

        public struct PackNote: Equatable, Sendable {
            public enum Kind: Equatable, Sendable {
                /// Ask to Buy: a parent has to say yes.
                case waiting
                /// The store said no, or never answered.
                case failed
                /// The purchase did not verify: nothing was added.
                case unverified
                /// Paid, and the server could not be asked yet. The purchase
                /// is kept and credited the next time the app can reach it.
                case retrying
            }

            public var id: SparklePack.ID
            public var kind: Kind

            public var isWaiting: Bool { kind == .waiting }
        }

        /// One purchase tap, for a retry to reuse.
        struct BuyAttempt: Equatable, Sendable {
            var item: ShopItem
            var price: Price
            var requestID: String
        }

        /// One choice of a companion, for a retry to reuse.
        struct StartAttempt: Equatable, Sendable {
            var species: Species
            var requestID: String
        }

        /// The writes that are on their way. Each is what the screen shows
        /// until the server answers and the push shows it too, and each
        /// carries what putting the screen back needs.
        struct Writes: Equatable, Sendable {
            /// Today's care, given.
            var care: Care?
            /// Purchases by request id: the coins taken and the thing given.
            var buys: [String: Buy] = [:]
            /// A companion being started.
            var start: Start?
            /// The ceremony's end.
            var graduating: Graduating?
            /// The latest layout and holidays sent. Their tokens tell a late
            /// answer to an earlier write from the one that is current.
            var layout: Layout?
            var holidays: Holidays?
            /// This person's answers to the vote, by species, on their way.
            var ballots: [String: Ballot] = [:]

            var isEmpty: Bool {
                care == nil && buys.isEmpty && start == nil && graduating == nil && layout == nil && holidays == nil
                    && ballots.isEmpty
            }

            /// `nil` is an answer taken back.
            struct Ballot: Equatable, Sendable { var answer: Bool? }

            struct Care: Equatable, Sendable { var day: String; var at: Date }
            struct Buy: Equatable, Sendable { var item: ShopItem; var coins: Coins }
            struct Start: Equatable, Sendable {
                var species: Species
                var seed: String
                var startedAt: Date
                /// The companion that was growing when it was tapped: a push
                /// that shows another is the push that shows this. Kept whole
                /// for the moment of its graduation, if the start brings one.
                var previous: Companion?
                var previousID: String? { previous?.id }
                /// Whether the welcome gift is being shown with it.
                var welcome: Bool
                /// The "+" over the jar this write put up, and the one before.
                var floater: Int?
                var previousPay: Payment?
                /// The server's answer, once it has come, and the id it gave.
                var companionID: String?
                var since = Date.distantFuture
                /// Set when this chose what an undecided seed would be: the
                /// seed is the same companion, with its growth, so it is
                /// drawn chosen only once the push says its species.
                var seedID: String?

                /// Whether `served` shows this write's companion, by its
                /// answer's id when it has come.
                func isShown(in served: CompanionHouse) -> Bool {
                    guard let current = served.current else { return false }
                    if seedID != nil { return isShownByPush(in: served) }
                    if let companionID { return current.id == companionID }
                    return isShownByPush(in: served)
                }

                /// Whether `served` is growing what this started, whatever
                /// the answer said: the push that shows it, for an answer
                /// that was lost.
                func isShownByPush(in served: CompanionHouse) -> Bool {
                    guard let current = served.current else { return false }
                    if let seedID {
                        return current.id == seedID && !current.isUndecided && current.species == species
                    }
                    return current.id != previousID && current.species == species
                }
            }
            struct Graduating: Equatable, Sendable {
                var companionID: String
                var floater: Int
                var previousPay: Payment?
                var isAnswered = false
                var since = Date.distantFuture
                /// A house of two or more: the server opens the vote in the
                /// same write, so the next one is drawn as a seed at once and
                /// Choose is not opened ahead of the answer.
                var predictsSeed = false
                /// The answer said there is no vote: the house picks.
                var noVote = false
            }
            struct Layout: Equatable, Sendable { var token: Int; var value: SceneLayout }
            struct Holidays: Equatable, Sendable { var token: Int; var value: [String]? }

            /// How long an answered entry waits for the push that shows it
            /// before it is let go regardless: a backstop, not a rule.
            static let patience: TimeInterval = 120

            /// Takes off what `served` now shows. A start and a graduation stay
            /// until the push that has the new companion, not until their
            /// answer. An answered start also goes once the served companion is
            /// no longer the one it replaced (somebody else moved on), and any
            /// answered entry goes after `patience`.
            mutating func settle(against served: CompanionHouse, now: Date = .distantPast) {
                if let start, start.companionID != nil {
                    let moved = served.current?.id != start.previousID
                    if start.isShown(in: served) || moved || now.timeIntervalSince(start.since) > Self.patience {
                        self.start = nil
                    }
                }
                if let graduating, graduating.isAnswered,
                   served.current?.id != graduating.companionID || now.timeIntervalSince(graduating.since) > Self.patience {
                    self.graduating = nil
                }
            }
        }

        var writeToken = 0

        public func step(of card: Card) -> CardStep {
            if card.isBought { return .bought }
            if let notice = card.notice { return .notice(notice) }
            guard let price = card.purchase?.price else { return .about }
            if let note = card.shortNote { return .short(sparkles: note.sparkles) }
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
            // Release builds draw none of this, so they do not even open the
            // Lab's file.
            _lab = CompanionFlag.isEnabled
                ? Shared(wrappedValue: CompanionHouse.Lab(), .companionLab(homeID))
                : Shared(value: CompanionHouse.Lab())
        }

        // MARK: The house, as drawn

        /// The house as it is drawn: what the server said, with the writes
        /// that are on their way laid over it, and the Lab over those.
        ///
        /// Computed, so there is one copy of the truth and no overlay to
        /// forget to take off. Most of the time nothing is laid over it and
        /// this is `served`.
        public var house: CompanionHouse {
            var house = served
            if !writes.isEmpty { overlay(writes, on: &house) }
            if lab != CompanionHouse.Lab() { overlay(lab, on: &house) }
            return house
        }

        /// Each entry applies only while `served` does not already show it;
        /// a graduation goes before a start, so a companion chosen straight
        /// after one has graduated is the one that is drawn.
        private func overlay(_ writes: Writes, on house: inout CompanionHouse) {
            for buy in writes.buys.values where !served.has(buy.item) {
                house.pay(buy.coins)
                house.receive(buy.item)
            }
            if let graduating = writes.graduating, served.current?.id == graduating.companionID {
                house.current = nil
                house.vote = nil
                // The vote opens in the same write for a house of two or more,
                // and the next one is already growing, as a seed.
                if graduating.predictsSeed {
                    var seed = Companion(
                        species: Self.seedStandIn, seed: "\(homeID.rawValue)-\(served.albumCount + 1)", startedAt: graduating.since
                    )
                    seed.isUndecided = true
                    house.current = seed
                }
                house.albumCount += 1
                house.add(Rewards.graduation)
                house.paidStage = 0
            }
            if let start = writes.start, !start.isShown(in: served) {
                if start.seedID != nil, var seed = house.current {
                    // The seed is chosen: the same companion with the same
                    // growth, and the vote is over with the pick.
                    seed.species = start.species
                    seed.isUndecided = false
                    house.current = seed
                    house.vote?.close(winner: start.species.rawValue, how: .picked)
                } else {
                    var started = Companion(species: start.species, seed: start.seed, startedAt: start.startedAt)
                    started.points = 0
                    house.current = started
                    house.paidStage = 0
                    if start.welcome, !served.welcomed {
                        house.add(Rewards.welcome)
                        house.welcomed = true
                    }
                }
            }
            // An answer shows only while `served` does not already: the tally
            // is moved by what this person's ballot changes, and by nothing the
            // push has counted.
            for (species, ballot) in writes.ballots where served.vote?.mine[species] != ballot.answer {
                house.vote?.answer(species, as: ballot.answer)
            }
            if let care = writes.care, var current = house.current,
               served.current?.careDays.contains(care.day) != true {
                if !current.careDays.contains(care.day) { current.careDays.append(care.day) }
                current.lastCareAt = care.at
                house.current = current
            }
            if let layout = writes.layout { house.layout = layout.value }
            if let holidays = writes.holidays { house.holidays = holidays.value }
        }

        private func overlay(_ lab: CompanionHouse.Lab, on house: inout CompanionHouse) {
            house.lab = lab
            house.leaves += lab.leaves
            house.sparkles += lab.sparkles
            house.owned.formUnion(lab.owned)
            house.ownedSpecies.formUnion(lab.ownedSpecies)
        }

        // MARK: Clock and calendar

        /// The day the scene thinks it is: the lab's pretend day on a
        /// development build, today otherwise. For drawing only; nothing sent
        /// to the server is judged by it (`serverShop` uses `now`).
        public var clock: Date { lab.date ?? now }

        /// Where the house is. Its own region once it has one — the server
        /// prices its seasons by it — and this phone's until then.
        public var placeRegion: String? { served.region ?? region }

        public var celebrated: Set<Holiday.ID> {
            house.holidays.map { Set($0.compactMap(Holiday.ID.init(rawValue:))) } ?? Holiday.defaults(for: placeRegion)
        }

        /// Everything that decides what the house can have today, as it is
        /// drawn — the Lab's day and purchases included — worked out once for
        /// a whole shelf.
        public var shop: ShopContext { shop(for: house, at: clock, birthday: lab.birthday) }

        private func shop(
            for house: CompanionHouse, at date: Date, birthday: Bool, holidays known: [Holiday]? = nil
        ) -> ShopContext {
            let celebrated = house.holidays.map { Set($0.compactMap(Holiday.ID.init(rawValue:))) }
                ?? Holiday.defaults(for: placeRegion)
            return ShopContext(
                clock: date, southern: Holiday.isSouthern(placeRegion), owned: house.owned,
                ownedSpecies: house.ownedSpecies, albumCount: house.albumCount, grown: house.grown,
                holidays: known ?? Holiday.active(on: date, among: celebrated, region: placeRegion),
                isBirthday: birthday || birthdays.contains(CalendarDay(date)), region: placeRegion
            )
        }

        /// What the server could do, for everything that is sent to it: from
        /// what it said (`served`) and the container's clock (`now`) alone —
        /// never the Lab's pretend day, coins or purchases, which it knows
        /// nothing of and must never be asked about.
        var serverShop: ShopContext { shop(for: served, at: now, birthday: false) }

        /// What can be in the scene on the server's terms.
        var serverAvailable: Set<String> { available(in: serverShop, house: served) }

        private func available(in shop: ShopContext, house: CompanionHouse) -> Set<String> {
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

        /// What can be in the scene today, as it is drawn: everything the jar
        /// has bought or the house has earned, what every house has, and
        /// whatever today's holidays bring, free while they last.
        public var available: Set<String> { available(in: shop, house: house) }

        /// A layout made safe to send: every spot holds something the server
        /// would let stand today.
        func serverSafe(_ layout: SceneLayout) -> SceneLayout {
            var layout = layout
            let available = serverAvailable
            for spot in Spot.allCases where spot != .tree {
                if let raw = layout[spot], !available.contains(raw) { layout[spot] = nil }
            }
            layout.tree = layout.tree.filter(available.contains)
            return layout
        }

        public var isPet: Bool { species?.isPet ?? false }
        /// A plant in a pot, which names its stages as a plant does.
        public var isPotted: Bool { species?.growsInPot ?? false }

        /// Whether ending the ceremony is a real graduation: the server says
        /// it can. Otherwise it is the Lab's preview.
        var canGraduate: Bool { served.current?.isReady == true && served.current?.id != nil }

        /// `yyyy-MM-dd`, in the house's offset when it has one: the server
        /// counts care by the house's days, and so must the button.
        static func dayKey(_ date: Date, offset: Int? = nil) -> String {
            var calendar = Calendar(identifier: .gregorian)
            if let offset, let zone = TimeZone(secondsFromGMT: offset * 60) { calendar.timeZone = zone }
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }

        /// Opens the card for a thing: to buy it if it is on sale today, or to
        /// say how it is had if it isn't.
        mutating func show(_ item: ShopItem, grow: Species? = nil) {
            let forSale = shop.standing(of: item).price != nil
            card = Card(item: item, purchase: forSale ? Purchase(item: item.bought, grow: grow) : nil)
        }

        /// Whether the album's cards are needed: only its own sheet draws them.
        var wantsAlbum: Bool { sheet == .album }

        /// Works out what the views draw from what the reducer holds, and
        /// assigns each only if it changed. Run after every action, and by the
        /// container when its clock or the household moves.
        public mutating func refresh() {
            let shown = served
            writes.settle(against: shown, now: now)
            let house = self.house
            let clock = self.clock
            // Today's holidays are calendar arithmetic: kept while the day,
            // the region and the days the house celebrates hold.
            let celebrated = house.holidays.map { Set($0.compactMap(Holiday.ID.init(rawValue:))) }
                ?? Holiday.defaults(for: placeRegion)
            let today = Self.dayKey(clock)
            let holidays: [Holiday]
            if let cache = holidayCache, cache.day == today, cache.region == placeRegion, cache.celebrated == celebrated {
                holidays = cache.holidays
            } else {
                holidays = Holiday.active(on: clock, among: celebrated, region: placeRegion)
                holidayCache = HolidayCache(day: today, region: placeRegion, celebrated: celebrated, holidays: holidays)
            }
            let context = shop(for: house, at: clock, birthday: lab.birthday, holidays: holidays)
            let current = house.current
            // A seed nobody has named yet is a plant's sprout, never the pet
            // or the plant the vote happens to list first.
            let undecided = current?.isUndecided == true
            let isPet = !undecided && (current?.species.isPet ?? false)

            set(\.jar, Coins(leaves: house.leaves, sparkles: house.sparkles))
            set(\.current, current)
            set(\.hasCompanion, current != nil)
            set(\.isUndecided, undecided)
            set(\.isOpeningVote, writes.graduating.map { $0.predictsSeed && !$0.noVote } ?? false)
            set(\.vote, house.vote)
            set(\.species, undecided ? nil : current?.species)
            set(\.look, current.map {
                Companion(species: $0.isUndecided ? Self.seedStandIn : $0.species, seed: $0.seed, startedAt: $0.startedAt)
            })
            let points = current.map { max(($0.points ?? 0) + lab.bonus, 0) } ?? 0
            set(\.points, points)
            // A seed holds still as a seed while the house decides: it grows
            // (the server counts it) but is not drawn as anything yet.
            let progress = undecided ? 0 : min(points / CompanionMath.graduateAt, 1)
            set(\.progress, progress)
            // The server's word on its stage and on being ready, unless the
            // Lab has moved the points: it can pretend, for the ceremony.
            let stage = undecided ? 0 : (lab.bonus == 0 ? current?.serverStage : nil)
                ?? CompanionMath.stage(progress: progress, isPet: isPet)
            set(\.stage, stage)
            set(\.isReady, !undecided && (current.map { $0.isReady || (lab.bonus > 0 && progress >= 1 && !$0.pointsReady) } ?? false))
            let mood: Mood = if let current {
                lab.mood ?? CompanionMath.mood(
                    now: clock, completions: activity, lastCare: current.lastCareAt,
                    startedAt: current.startedAt, memberCount: memberCount
                )
            } else {
                .content
            }
            set(\.mood, mood)
            set(\.caredToday, current?.careDays.contains(Self.dayKey(now, offset: served.tzOffset)) ?? false)
            let day = current.map {
                (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0.startedAt),
                                                 to: Calendar.current.startOfDay(for: clock)).day ?? 0) + 1
            } ?? 0
            set(\.day, day)
            set(\.southern, Holiday.isSouthern(placeRegion))
            set(\.activeHolidays, context.holidays)

            var layout = house.layout
            let allowed = available(in: context, house: house)
            for spot in Spot.allCases where spot != .tree {
                if let raw = layout[spot], !allowed.contains(raw) { layout[spot] = nil }
            }
            layout.tree = layout.tree.filter(allowed.contains)
            if isPet { layout.tree = []; layout.pot = nil }
            set(\.visibleLayout, layout)

            // The first holiday today that putting out would change the scene
            // for — what the card offers with one tap. A holiday whose things
            // share a spot (bats and bunting both go overhead) counts as out
            // once there is nothing left that would move.
            let southern = Holiday.isSouthern(placeRegion)
            let toDress = context.holidays.first { holiday in
                var dressed = layout
                dressed.dress(for: holiday, southern: southern, isPet: isPet)
                return dressed != layout
            }
            set(\.holidayToDress, toDress)
        }

        private mutating func set<Value: Equatable>(_ keyPath: WritableKeyPath<State, Value>, _ value: Value) {
            if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
        }
    }

    public enum Action: Equatable {
        /// Open the house's companion and keep it open. Sent for the life of
        /// the tab bar.
        case task
        /// The house's companion, as the server now says it.
        case served(CompanionServed)
        case albumUpdated([Graduate])
        /// A subscription ended with an error. A retryable one is opened again
        /// after a wait that grows, as the app's other reads are.
        case streamEnded(retry: Bool)

        /// The finished chores changed.
        case completionsUpdated([Completion])
        case careTapped
        case chooseTapped
        /// The pause before a sheet that follows a closing presentation is over.
        case presentPending
        case chose(Species)
        /// The card's way into the vote for the next one.
        case voteTapped
        /// One option of the vote, answered: yes, or no; the same answer again
        /// takes it back.
        case ballotTapped(String, yes: Bool)
        /// "Settle it": the ballots so far decide.
        case settleTapped
        /// Pick instead of voting, while nobody else has answered.
        case pickInsteadTapped
        /// The welcome gift's "Decorate now".
        case welcomeDecorateTapped
        case celebrateTapped
        case ceremonyFinished
        /// The ceremony for a graduation that happened under a start.
        case momentDismissed
        /// The pause before a queued ceremony is over.
        case momentReady
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
        case packsUnavailable
        case packTapped(SparklePack)
        case packBought(SparklePack.ID, PurchaseOutcome)
        case packFailed(SparklePack.ID, SparkleStoreError?)
        /// Listens for purchases that finish without a tap on a pack, for as
        /// long as the effect lives (the screen's task; signing out ends it).
        case watchPurchases
        /// Sparkles the server credited from one of those.
        case sparklesArrived(Int)
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

        // The server's answers to what was sent.
        case buyAnswered(String, Result<BuyOutcome, AppError>)
        case careAnswered(Result<Bool, AppError>)
        case startAnswered(Result<StartOutcome, AppError>)
        case graduateAnswered(Result<GraduateOutcome, AppError>)
        /// `nil`: the server took it.
        case ballotAnswered(String, AppError?)
        case decideAnswered(Result<DecideOutcome, AppError>)
        case layoutAnswered(token: Int, Result<SceneLayout, AppError>)
        case holidaysAnswered(token: Int, Result<[String]?, AppError>)
        case importAnswered(Result<ImportOutcome, AppError>)

        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    enum CancelID { case served, album, grow, retry, moment, purchases }

    /// How long a write waits for the server before it is taken as failed.
    static let writeTimeout: Duration = .seconds(15)

    @Dependency(\.companion) var companionClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.sparkleStore) var sparkleStore
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var currentDate

    static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Companion")

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .run { send in
                    // Decoded and shaped off the main thread; the reducer only
                    // compares and assigns.
                    for try await payload in companionClient.forHome(homeID) {
                        await send(.served(CompanionServed(payload)))
                    }
                } catch: { error, send in
                    let error = AppError(error)
                    Self.log.error("companion:forHome ended: \(error.diagnostic, privacy: .public)")
                    await send(.streamEnded(retry: error.isRetryable))
                }
                .cancellable(id: CancelID.served, cancelInFlight: true)

            case let .served(served):
                return receive(served, state: &state)

            case let .streamEnded(retry):
                guard retry else { return .none }
                state.streamRetries += 1
                let wait = Duration.seconds(min(1 << min(state.streamRetries, 6), 60))
                return .run { send in
                    try await clock.sleep(for: wait)
                    await send(.task)
                }
                .cancellable(id: CancelID.retry, cancelInFlight: true)

            case let .albumUpdated(album):
                if state.served.album != album { state.served.album = album }
                return .none

            case let .completionsUpdated(completions):
                let incoming = Set(completions)
                // A chore finished a moment ago, by anyone, anywhere in the
                // app — not the first delivery of a month of Done list.
                let fresh = incoming.subtracting(state.seen).contains { state.now.timeIntervalSince($0.at) < 180 }
                if state.hasLoaded, fresh { state.choreTick += 1 }
                state.seen = incoming
                state.hasLoaded = true
                if completions != state.completions { state.completions = completions }
                return .none

            case .careTapped:
                guard let current = state.current else { return .none }
                // The house's real day and the container's clock, not the
                // Lab's: this is what the server is told.
                let key = State.dayKey(state.now, offset: state.served.tzOffset)
                let at = state.now
                state.careTick += 1
                // Every tap gets a reaction; the server hears about the first
                // care of the day, and about a later one a minute on, not
                // about every tap of a happy burst.
                let wakes = state.lab.mood?.isQuiet == true
                let isNew = !current.careDays.contains(key)
                let isStale = current.lastCareAt.map { at.timeIntervalSince($0) > 60 } ?? true
                // Caring is coming back: it wakes up whatever the lab said.
                if wakes { state.$lab.withLock { $0.mood = nil } }
                guard isNew || isStale, state.writes.care == nil, state.served.current != nil else { return .none }
                state.writes.care = State.Writes.Care(day: key, at: at)
                let homeID = state.homeID
                return .run { send in
                    await send(.careAnswered(await attempt { try await companionClient.care(homeID) }))
                }

            case let .careAnswered(result):
                // A care that did not reach the house is not worth an alert
                // over a water drop: the entry comes off and the button asks
                // again. One that did is folded in, so the check stays.
                if let care = state.writes.care {
                    if case .success = result, var current = state.served.current {
                        if !current.careDays.contains(care.day) { current.careDays.insert(care.day, at: 0) }
                        current.lastCareAt = care.at
                        state.served.current = current
                    }
                    state.writes.care = nil
                }
                if case let .failure(error) = result {
                    Self.log.error("companion:care failed: \(error.diagnostic, privacy: .public)")
                }
                return .none

            case .chooseTapped:
                // Not while the vote that is about to be known is the way.
                guard !state.isOpeningVote else { return .none }
                state.pendingSheet = nil
                state.sheet = .choose
                return .none

            case .presentPending:
                // What waited for a closing presentation to finish; dropped if
                // anything else has been opened since.
                guard let sheet = state.pendingSheet else { return .none }
                state.pendingSheet = nil
                guard state.sheet == nil else { return .none }
                state.sheet = sheet
                return .none

            case .voteTapped:
                state.pendingSheet = nil
                state.voteNote = nil
                state.sheet = .vote
                return .none

            case let .ballotTapped(species, yes):
                // Only while it is open, on its own options, and one answer to
                // an option at a time: two in flight could land out of order.
                guard let vote = state.house.vote, vote.isOpen, vote.options.contains(where: { $0.id == species }),
                      state.writes.ballots[species] == nil
                else { return .none }
                let answer: Bool? = vote.mine[species] == yes ? nil : yes
                state.ballotTick += 1
                state.voteNote = nil
                state.writes.ballots[species] = State.Writes.Ballot(answer: answer)
                let pollID = vote.pollID
                return .run { send in
                    let result = await attempt { try await companionClient.ballot(pollID, species, answer) }
                    await send(.ballotAnswered(species, result.failureValue))
                }

            case let .ballotAnswered(species, error):
                guard let ballot = state.writes.ballots.removeValue(forKey: species) else { return .none }
                if let error { return failed(error, "polls:vote", state: &state) }
                // Folded in before the entry goes, so the answer does not
                // blink between here and the push. A push that already
                // counted it makes this a no-op.
                state.served.vote?.answer(species, as: ballot.answer)
                return .none

            case .settleTapped:
                guard let vote = state.house.vote, vote.isOpen, !state.isDeciding else { return .none }
                state.voteNote = nil
                // What the live read already says: nobody else has answered
                // (that is a pick, and `start` does it), or nothing is a yes.
                // The server says the same when it is asked.
                guard vote.othersVoted else {
                    state.voteNote = .alone
                    return .none
                }
                guard vote.hasYes else {
                    state.voteNote = .noVotes
                    return .none
                }
                state.isDeciding = true
                let homeID = state.homeID
                return .run { send in
                    await send(.decideAnswered(await attempt { try await companionClient.decide(homeID) }))
                }

            case let .decideAnswered(result):
                state.isDeciding = false
                switch result {
                case let .success(outcome):
                    switch outcome {
                    case let .chosen(winner):
                        Self.fold(winner: winner, how: .decided, into: &state)
                    case let .closed(winner):
                        if let winner { Self.fold(winner: winner, how: .other, into: &state) }
                    case .noVotes: state.voteNote = .noVotes
                    case .alone: state.voteNote = .alone
                    case .none: break
                    }
                    return .none
                case let .failure(error):
                    return failed(error, "companion:decide", state: &state)
                }

            case .pickInsteadTapped:
                // The vote's sheet closes first and Choose opens once it has
                // gone, so the two never fight over the screen.
                state.pendingSheet = .choose
                state.sheet = nil
                return .run { send in
                    try await clock.sleep(for: .milliseconds(450))
                    await send(.chooseTapped)
                }

            case let .chose(species):
                return grow(species, state: &state)

            case let .growTapped(species):
                let standing = state.shop.standing(of: species)
                if standing.isUsable {
                    return grow(species, state: &state)
                } else {
                    state.show(.species(species), grow: standing.price != nil ? species : nil)
                    return .none
                }

            case .shopTapped:
                state.sheet = .shop
                return .none

            case let .itemTapped(item):
                state.show(item)
                return .none

            case .cardBuyTapped:
                return buy(state: &state)

            case let .buyAnswered(requestID, result):
                return buyAnswered(requestID, result, state: &state)

            case let .cardGrow(species):
                state.card = nil
                return grow(species, state: &state)

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
                state.pendingSheet = .decorate
                state.sheet = nil
                return .run { send in
                    try await clock.sleep(for: .milliseconds(450))
                    await send(.decorateTapped)
                }

            case .cardDismissed:
                state.card = nil
                return .none

            case .storeTapped:
                state.isReturning = false
                state.pending = nil
                state.landed = nil
                state.packNote = nil
                state.storeOpen = true
                return .none

            case .storeDismissed:
                state.isReturning = false
                state.storeOpen = false
                state.pending = nil
                state.landed = nil
                state.packNote = nil
                return .none

            case .storeAppeared:
                guard !state.arePacksLoaded else { return .none }
                state.packsUnavailable = false
                return .run { send in
                    guard let packs = try? await sparkleStore.packs(), !packs.isEmpty else {
                        await send(.packsUnavailable)
                        return
                    }
                    await send(.packsLoaded(packs))
                }

            case let .packsLoaded(packs):
                state.packs = packs
                state.arePacksLoaded = true
                state.packsUnavailable = false
                return .none

            case .packsUnavailable:
                state.packsUnavailable = true
                return .none

            case let .packTapped(pack):
                guard state.buyingPack == nil else { return .none }
                state.buyingPack = pack.id
                state.packNote = nil
                let homeID = state.homeID
                let userID = state.userID?.rawValue
                return .run { send in
                    do {
                        await send(.packBought(pack.id, try await sparkleStore.purchase(pack.id, homeID, userID)))
                    } catch {
                        await send(.packFailed(pack.id, error as? SparkleStoreError))
                    }
                }

            case .watchPurchases:
                let homeID = state.homeID
                let userID = state.userID?.rawValue
                return .run { send in
                    for await sparkles in sparkleStore.credits(homeID, userID) {
                        await send(.sparklesArrived(sparkles))
                    }
                }
                .cancellable(id: CancelID.purchases, cancelInFlight: true)

            case let .sparklesArrived(sparkles):
                // Ask to Buy, or a purchase finished elsewhere, landing while
                // the store is open: say so. With the store closed the jar
                // simply changes.
                guard state.storeOpen else { return .none }
                state.packNote = nil
                return landed(sparkles, isInJar: false, state: &state)

            case let .packBought(id, outcome):
                state.buyingPack = nil
                switch outcome {
                case .cancelled: return .none
                case .pending:
                    state.packNote = State.PackNote(id: id, kind: .waiting)
                    return .none
                case let .added(sparkles):
                    // The server has them; the jar itself comes on the live
                    // read, so nothing is added here.
                    return landed(sparkles, isInJar: false, state: &state)
                case let .preview(sparkles):
                    // The test store's Sparkles are not money, and the server
                    // never hears of them: they land in the Lab's local
                    // preview, and what they buy stays there too.
                    state.$lab.withLock { $0.sparkles += sparkles }
                    return landed(sparkles, isInJar: true, state: &state)
                }

            case let .packFailed(id, error):
                state.buyingPack = nil
                let kind: State.PackNote.Kind = switch error {
                case .notConfirmed: .retrying
                case .unverified, .refused: .unverified
                case .unavailable, nil: .failed
                }
                state.packNote = State.PackNote(id: id, kind: kind)
                return .none

            case .storeReturned:
                state.isReturning = false
                guard state.storeOpen else { return .none }
                // The Sparkles of a real purchase come on the live read, which
                // may be a moment behind the answer: if the jar still falls
                // short, the store stays until it doesn't.
                if let price = state.pending?.price, case .short = state.house.checkout(price) { return .none }
                state.storeOpen = false
                state.pending = nil
                state.landed = nil
                return .none

            case let .birthdaysUpdated(days):
                if state.birthdays != days { state.birthdays = days }
                return .none

            case .welcomeDecorateTapped:
                // The gift closes first; Decorate opens once it has gone, so
                // the two presentations never fight over the screen.
                state.pendingSheet = .decorate
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
                guard state.current != nil, state.isReady else {
                    state.sheet = nil
                    return .none
                }
                // The Lab can pretend it is ready, for the ceremony's sake:
                // that ends with the pretence, and the server is not asked.
                guard state.canGraduate, let id = state.served.current?.id else {
                    state.$lab.withLock { $0.bonus = 0 }
                    state.sheet = nil
                    return .none
                }
                let floater = (state.lastPay?.id ?? 0) + 1
                // A house of two or more votes on the next one, and the server
                // opens it in this very write; a house of one picks.
                let votes = state.memberCount > 1
                state.writes.graduating = State.Writes.Graduating(
                    companionID: id, floater: floater, previousPay: state.lastPay, since: state.now, predictsSeed: votes
                )
                state.lastPay = State.Payment(coins: Rewards.graduation, id: floater)
                // Straight on to the next one: nothing done while the house
                // decides is lost, because growth counts from when it arrives.
                // For a house that votes, the answer says which sheet.
                state.sheet = votes ? nil : .choose
                state.ceremonyClosedAt = currentDate
                let homeID = state.homeID
                return .run { send in
                    await send(.graduateAnswered(await attempt { try await companionClient.graduate(homeID, id) }))
                }

            case let .graduateAnswered(result):
                guard var graduating = state.writes.graduating else { return .none }
                switch result {
                case let .success(outcome):
                    // What was really paid, once: more or less than the
                    // coins that were shown arriving, or none (it had been).
                    if state.lastPay?.id == graduating.floater {
                        if let paid = outcome.paid { state.lastPay?.coins = paid } else { state.lastPay = graduating.previousPay }
                    }
                    graduating.isAnswered = true
                    // A repeat call says nothing of a vote (the key is absent):
                    // the push decides. An explicit null is "this house picks".
                    let picks = outcome.vote == nil && !outcome.isRepeat
                    if picks { graduating.noVote = true }
                    state.writes.graduating = graduating
                    let served = state.served
                    state.writes.settle(against: served)
                    // The vote it opened is what comes next, not Choose; a
                    // house with nothing to vote on picks as before. Presented
                    // after the pause a closing cover needs, or it is dropped.
                    if outcome.vote != nil, state.sheet == nil || state.sheet == .choose {
                        state.voteNote = nil
                        return present(.vote, afterSheet: state.sheet != nil, state: &state)
                    } else if picks, graduating.predictsSeed, state.sheet == nil {
                        return present(.choose, afterSheet: false, state: &state)
                    }
                    return .none
                case .failure(let error) where error.isTransport && state.served.current?.id != graduating.companionID:
                    // The answer was lost but the graduation was not.
                    graduating.isAnswered = true
                    state.writes.graduating = graduating
                    let served = state.served
                    state.writes.settle(against: served)
                    if graduating.predictsSeed, state.sheet == nil {
                        if served.current?.isUndecided == true { return present(.vote, afterSheet: false, state: &state) }
                        if served.current == nil { return present(.choose, afterSheet: false, state: &state) }
                    }
                    return .none
                case let .failure(error):
                    // Nothing graduated. It is back on Today, ready, and the
                    // coins that were shown arriving are not coming.
                    state.writes.graduating = nil
                    if state.lastPay?.id == graduating.floater { state.lastPay = graduating.previousPay }
                    if state.sheet == .choose { state.sheet = nil }
                    return failed(error, "companion:graduate", state: &state)
                }

            case .momentReady:
                state.momentScheduled = false
                guard state.moment != nil, state.sheet == nil, state.placeOnOpen == nil, state.pendingSheet == nil else {
                    return .none
                }
                state.sheet = .ceremony
                return .none

            case .momentDismissed:
                state.moment = nil
                if state.sheet == .ceremony { state.sheet = nil }
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
                return setHolidays(Holiday.all.map(\.id).filter(ids.contains).map(\.rawValue), state: &state)

            case .holidaysReset:
                return setHolidays(nil, state: &state)

            case let .holidaysAnswered(token, result):
                guard state.writes.holidays?.token == token else { return .none }
                state.writes.holidays = nil
                switch result {
                case let .success(holidays): state.served.holidays = holidays
                case let .failure(error): return failed(error, "companion:setHolidays", state: &state)
                }
                return .none

            case let .dressTapped(id):
                guard let holiday = Holiday.with(id) else { return .none }
                var layout = state.house.layout
                layout.dress(for: holiday, southern: state.southern, isPet: state.isPet)
                return setLayout(layout, state: &state)

            case .decorateTapped:
                state.pendingSheet = nil
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
                // is bought by closing a sheet. What is kept is what the server
                // would let stand, so a preview the Lab made possible (its day,
                // its coins) is not sent.
                let layout = state.serverSafe(state.draft)
                state.sheet = nil
                state.decorateSpot = nil
                return setLayout(layout, state: &state)

            case .decorateCancelled:
                state.sheet = nil
                state.decorateSpot = nil
                return .none

            case let .layoutAnswered(token, result):
                guard state.writes.layout?.token == token else { return .none }
                state.writes.layout = nil
                switch result {
                case let .success(kept): state.served.layout = kept
                case let .failure(error): return failed(error, "companion:setLayout", state: &state)
                }
                return .none

            case let .startAnswered(result):
                return startAnswered(result, state: &state)

            case .labTapped:
                state.sheet = .lab
                return .none

            case let .labPoints(points):
                // Taking points away stops at a seed, never below nothing grown.
                let earned = state.served.current?.points ?? 0
                state.$lab.withLock { $0.bonus = max($0.bonus + points, -earned) }
                return .none

            case let .labMood(mood):
                state.$lab.withLock { $0.mood = mood }
                return .none

            case let .labDate(date):
                state.$lab.withLock { $0.date = date }
                return .none

            case let .labCoins(coins):
                state.$lab.withLock {
                    $0.leaves += coins.leaves
                    $0.sparkles += coins.sparkles
                }
                return .none

            case let .labBirthday(on):
                state.$lab.withLock { $0.birthday = on }
                return .none

            case let .labDusk(on):
                state.$lab.withLock { $0.dusk = on }
                return .none

            case .labReset:
                state.$lab.withLock { $0 = CompanionHouse.Lab() }
                state.sheet = nil
                return .none

            case .sheetDismissed:
                // Closing the ceremony ends its moment; closing anything else
                // is what lets a queued one play.
                if state.sheet == .ceremony { state.moment = nil }
                state.sheet = nil
                state.decorateSpot = nil
                state.card = nil
                state.storeOpen = false
                state.pending = nil
                state.landed = nil
                state.packNote = nil
                return .none

            case let .importAnswered(result):
                switch result {
                case let .success(outcome):
                    Self.log.info("companion:importLocal answered \(String(describing: outcome), privacy: .public)")
                case let .failure(error):
                    Self.log.error("companion:importLocal failed: \(error.diagnostic, privacy: .public)")
                }
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        // The album's cards are read while its sheet is open, and the read is
        // let go with it. Nothing else opens or closes it.
        .onChange(of: \.wantsAlbum) { _, state in
            let homeID = state.homeID
            guard state.wantsAlbum else { return .cancel(id: CancelID.album) }
            return .run { send in
                for try await cards in companionClient.album(homeID) {
                    await send(.albumUpdated(cards.cards.map(Graduate.init)))
                }
            } catch: { error, _ in
                Self.log.error("companion:album ended: \(AppError(error).diagnostic, privacy: .public)")
            }
            .cancellable(id: CancelID.album, cancelInFlight: true)
        }

        // What the views draw, kept in step with what the reducer holds, and
        // the ceremony of a queued graduation: it plays once, after a pause
        // that lets whatever sheet was closing finish closing (a sheet
        // presented in the action that dismisses another is dropped), and
        // never over one that is about to open.
        Reduce { state, _ in
            state.refresh()
            guard state.moment != nil, state.sheet == nil, state.placeOnOpen == nil, state.pendingSheet == nil else {
                // Something is open or about to be: a pause that is running
                // is dropped, so every close starts a fresh one and a stale
                // timer cannot fire into a sheet that is still closing.
                guard state.momentScheduled else { return .none }
                state.momentScheduled = false
                return .cancel(id: CancelID.moment)
            }
            guard !state.momentScheduled else { return .none }
            state.momentScheduled = true
            return .run { send in
                try await clock.sleep(for: .milliseconds(450))
                await send(.momentReady)
            }
            .cancellable(id: CancelID.moment, cancelInFlight: true)
        }
    }

    // MARK: - The server's delivery

    /// A new delivery of the house. Assigns only what changed, so a delivery
    /// that moved the jar does not redraw the scene, and one that moved the
    /// mood does not redraw the jar.
    /// Sparkles that just landed: said in the store, and, when they are enough
    /// for what sent the house there, a moment later back to the card.
    /// `isInJar` is whether the jar already shows them (the Lab's preview
    /// does); a real purchase's come on the live read, so `storeReturned`
    /// looks again before it leaves.
    private func landed(_ sparkles: Int, isInJar: Bool, state: inout State) -> Effect<Action> {
        state.landed = sparkles
        state.landedTick += 1
        // Enough now for what sent them here: a moment to see the Sparkles
        // land — that second is how anyone knows it worked — then back to the
        // card, which already says so. Not enough yet, and the store stays.
        guard let price = state.pending?.price, !state.isReturning else { return .none }
        if isInJar, case .short = state.house.checkout(price) { return .none }
        state.isReturning = true
        return .run { send in
            try await clock.sleep(for: .milliseconds(1300))
            await send(.storeReturned)
        }
    }

    private func receive(_ served: CompanionServed, state: inout State) -> Effect<Action> {
        state.streamRetries = 0
        state.isLoaded = true
        // Unreadable is an error to say, never "no companion": what the card
        // had stays, and nothing below reads the broken delivery.
        guard !served.isUnreadable else {
            Self.log.error("companion:forHome delivered a house or companion this build cannot read")
            state.isUnreadable = true
            return .none
        }
        state.isUnreadable = false
        let first = !state.hasRead
        state.hasRead = true

        var house = served.house
        house.album = state.served.album
        let before = state.served

        // A jar that grew on its own — a stage, a house-mate's doing — is
        // announced like the phone's own earnings. Not for the coins of this
        // phone's own start or graduation: those were announced when it
        // began, and again from what the server said it paid.
        if !first, state.writes.start == nil, state.writes.graduating == nil {
            let gained = Coins(leaves: max(house.leaves - before.leaves, 0), sparkles: max(house.sparkles - before.sparkles, 0))
            if gained.leaves > 0 || gained.sparkles > 0 {
                state.lastPay = State.Payment(coins: gained, id: (state.lastPay?.id ?? 0) + 1)
            }
        }
        if before != house { state.served = house }
        if state.activity != served.activity { state.activity = served.activity }
        if state.jarFeed != served.jarFeed { state.jarFeed = served.jarFeed }
        let shown = state.served
        state.writes.settle(against: shown, now: state.now)
        // A choice that was never answered keeps its id for a retry; once the
        // house is growing something else, or this species, a later Choose is
        // a new one and must not be taken for a replay.
        if let attempt = state.startAttempt, state.writes.start == nil,
           before.current?.id != house.current?.id || house.current?.species == attempt.species {
            state.startAttempt = nil
        }
        // "Not enough" was the server's judgement of a jar that has moved.
        if let note = state.card?.shortNote, note.jar != Coins(leaves: house.leaves, sparkles: house.sparkles) {
            state.card?.shortNote = nil
        }
        // A purchase whose answer was lost can still have gone through: the
        // house has the thing now, so the card says so rather than asking again.
        Self.settleCard(&state)
        if served.catalogVersion != CatalogVersion.exported, !state.placeTold {
            Self.log.warning(
                "catalog differs: server \(served.catalogVersion, privacy: .public), this build \(CatalogVersion.exported, privacy: .public); the server's prices win"
            )
        }

        let homeID = state.homeID
        let place = Place.current(region: state.region)
        var effects: [Effect<Action>] = []
        // Where the house is, once, when it has no idea; never to move it.
        if !state.placeTold {
            state.placeTold = true
            if served.needsPlace {
                effects.append(.run { _ in
                    do { _ = try await timed { try await companionClient.setPlace(homeID, place) } }
                    catch { Self.log.error("companion:setPlace failed: \(AppError(error).diagnostic, privacy: .public)") }
                })
            }
        }
        // A test phone's MVP file, offered once by each person who has it; the
        // file stays either way. Waits for the person to be known.
        if !state.importTried, let userID = state.userID {
            state.importTried = true
            effects.append(.run { send in
                guard let local = LocalCompanion.pending(for: homeID, userID: userID) else { return }
                do {
                    let outcome = try await timed { try await companionClient.importLocal(homeID, local, place) }
                    LocalCompanion.markOffered(homeID, userID: userID)
                    await send(.importAnswered(.success(outcome)))
                } catch {
                    // Marked for any answer, an error included, that asking
                    // again would only repeat; not for a connection that
                    // never got through, which is tried again next launch.
                    let error = AppError(error)
                    if !error.isTransport { LocalCompanion.markOffered(homeID, userID: userID) }
                    await send(.importAnswered(.failure(error)))
                }
            })
        }
        // A real purchase's Sparkles can reach the jar after the 1.3 s beat
        // has already looked: when the read that brings them shows enough,
        // the store goes back to the card after a short beat of its own.
        if state.storeOpen, state.landed != nil, !state.isReturning,
           let price = state.pending?.price, !state.house.checkout(price).isShort {
            state.isReturning = true
            effects.append(.run { send in
                try await clock.sleep(for: .milliseconds(600))
                await send(.storeReturned)
            })
        }
        return .merge(effects)
    }

    /// Presents a sheet once whatever was closing has finished closing: a sheet
    /// presented in the action that dismisses another is dropped, and the state
    /// would then say `.vote` with nothing on screen. `afterSheet` is a sheet
    /// of this feature being replaced, which needs the whole pause; otherwise
    /// it is what is left of it since the ceremony's cover closed.
    private func present(_ sheet: State.Sheet, afterSheet: Bool, state: inout State) -> Effect<Action> {
        let pause = 450
        let elapsed = state.ceremonyClosedAt.map { Int(currentDate.timeIntervalSince($0) * 1000) } ?? pause
        let wait = afterSheet ? pause : max(0, pause - max(elapsed, 0))
        state.pendingSheet = sheet
        state.sheet = nil
        return .run { send in
            try await clock.sleep(for: .milliseconds(wait))
            await send(.presentPending)
        }
    }

    /// What a settled vote chose, folded into what the server last said, the way
    /// a purchase's answer is: the card does not wait on the push to stop being
    /// a seed. A vote that is over already keeps its own ending.
    private static func fold(winner: String, how: CompanionVote.How, into state: inout State) {
        if state.served.vote?.isOpen == true { state.served.vote?.close(winner: winner, how: how) }
        if state.served.current?.isUndecided == true, let species = Species(rawValue: winner) {
            state.served.current?.species = species
            state.served.current?.isUndecided = false
        }
    }

    // MARK: - Writes

    /// Runs a call against the write timeout and says how it ended. A timeout
    /// is `AppError.offline`: the request id the call carries makes the one
    /// that arrives late harmless.
    private func attempt<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async -> Result<T, AppError> {
        do { return .success(try await timed(operation)) } catch { return .failure(AppError(error)) }
    }

    /// The call against the write timeout, written so the loser is never
    /// awaited. The real client's call is a Rust future that ignores
    /// cancellation, so a structured race (a task group waits for every child)
    /// would hold a hung write until the socket came back. Instead one
    /// continuation is resumed exactly once, by whichever of the call, the
    /// sleeper or an outer cancel comes first; a late answer from the call is
    /// ignored (the live push corrects the screen).
    private func timed<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let clock = self.clock
        let race = WriteRace<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.start(continuation)
                race.hold(
                    Task {
                        do { race.finish(.success(try await operation())) } catch { race.finish(.failure(error)) }
                    },
                    Task {
                        guard (try? await clock.sleep(for: Self.writeTimeout)) != nil else { return }
                        race.finish(.failure(AppError.offline))
                    }
                )
            }
        } onCancel: {
            race.finish(.failure(CancellationError()))
        }
    }

    /// Starts growing one. The house sees it at once, with the welcome gift if
    /// it is the first; if the server says no, all of that is taken back. Each
    /// choice has its own request id, kept when an answer is lost.
    private func grow(_ species: Species, state: inout State) -> Effect<Action> {
        guard state.writes.start == nil, state.serverShop.standing(of: species).isUsable else { return .none }
        let house = state.house
        let firstTime = !house.welcomed
        // Choosing for a seed the house has not named is the same companion
        // with its growth, not a new one: it keeps its seed and its start.
        let undecided = state.served.current.flatMap { $0.isUndecided ? $0 : nil }
        let seed = undecided?.seed ?? "\(state.homeID.rawValue)-\(house.albumCount)"
        let floater = (state.lastPay?.id ?? 0) + 1
        state.writes.start = State.Writes.Start(
            species: species, seed: seed, startedAt: undecided?.startedAt ?? state.now, previous: state.served.current,
            welcome: firstTime, floater: firstTime ? floater : nil, previousPay: state.lastPay, since: state.now,
            seedID: undecided?.id
        )
        state.sheet = firstTime ? .welcome : nil
        if firstTime { state.lastPay = State.Payment(coins: Rewards.welcome, id: floater) }
        let attempt = state.startAttempt.flatMap { $0.species == species ? $0 : nil }
            ?? State.StartAttempt(species: species, requestID: uuid().uuidString)
        state.startAttempt = attempt
        let homeID = state.homeID
        let place = Place.current(region: state.region)
        return .run { send in
            await send(.startAnswered(await self.attempt {
                try await companionClient.start(homeID, species, place, attempt.requestID)
            }))
        }
    }

    private func startAnswered(_ result: Result<StartOutcome, AppError>, state: inout State) -> Effect<Action> {
        guard var start = state.writes.start else { return .none }
        switch result {
        case let .success(outcome):
            state.startAttempt = nil
            start.companionID = outcome.companionID
            state.writes.start = start
            // What the welcome really was: the coins shown arriving become
            // the server's, or go if it did not come (another phone's was first).
            if let floater = start.floater, state.lastPay?.id == floater {
                if let welcome = outcome.welcome {
                    state.lastPay?.coins = welcome
                } else {
                    state.lastPay = start.previousPay
                    if state.sheet == .welcome { state.sheet = nil }
                }
            }
            // A ready one was graduated first, in the same write: its coins
            // arrive once, and so does its moment.
            if let graduated = outcome.graduated {
                if let paid = graduated.paid {
                    state.lastPay = State.Payment(coins: paid, id: (state.lastPay?.id ?? 0) + 1)
                }
                if let previous = start.previous, previous.id == graduated.companionID {
                    state.moment = State.Moment(
                        species: graduated.species, seed: previous.seed, startedAt: previous.startedAt,
                        graduatedAt: state.now, paid: graduated.paid
                    )
                }
            }
            let shown = state.served
            state.writes.settle(against: shown)
            return .none
        case let .failure(error) where error.isTransport && start.isShownByPush(in: state.served):
            // The answer was lost but the write was not: the push already
            // shows it growing. Nothing to take back and nothing to alert.
            state.startAttempt = nil
            let served = state.served
            state.writes.start?.companionID = served.current?.id
            state.writes.settle(against: served)
            return .none
        case let .failure(error):
            // Nothing started: the invitation is back, and so is the jar. The
            // welcome that was being shown never came. A request that never
            // got an answer keeps its id for the next tap.
            state.writes.start = nil
            if !error.isTransport { state.startAttempt = nil }
            if let floater = start.floater, state.lastPay?.id == floater { state.lastPay = start.previousPay }
            if state.sheet == .welcome { state.sheet = nil }
            return failed(error, "companion:start", state: &state)
        }
    }

    /// The card's Buy. The jar is debited here and now; the server is asked
    /// with this tap's own request id and the price the card showed, and gets
    /// the last word (`buyAnswered`).
    private func buy(state: inout State) -> Effect<Action> {
        guard var card = state.card, !card.isBought, let purchase = card.purchase,
              let price = purchase.price
        else { return .none }
        let lab = state.lab.touchesJar
        // What the server would say about the sale, not the Lab's day.
        guard (lab ? state.shop : state.serverShop).standing(of: purchase.item).price != nil else { return .none }
        let coins: Coins
        switch state.house.checkout(price) {
        case let .pay(paying), let .makeUp(paying, _): coins = paying
        // The card offers the store instead of a Buy button; nothing to do.
        case .short: return .none
        }
        card.notice = nil
        card.shortNote = nil

        // Coins from the Lab are not the house's: what they buy stays in the
        // Lab, and the server is not asked.
        if lab {
            state.$lab.withLock {
                $0.leaves -= coins.leaves
                $0.sparkles -= coins.sparkles
                $0.receive(purchase.item)
            }
            card.paid = coins
            state.card = card
            return growAfterBuying(purchase.grow, delay: .milliseconds(1400))
        }

        let tap = state.retry.flatMap { $0.item == purchase.item && $0.price == price ? $0 : nil }
            ?? State.BuyAttempt(item: purchase.item, price: price, requestID: uuid().uuidString)
        state.retry = tap
        state.writes.buys[tap.requestID] = State.Writes.Buy(item: purchase.item, coins: coins)
        card.paid = coins
        state.card = card
        let homeID = state.homeID
        return .run { send in
            await send(.buyAnswered(tap.requestID, await attempt {
                try await companionClient.buy(homeID, tap.item, tap.requestID, tap.price)
            }))
        }
    }

    /// Every way a purchase can end. The entry that debited the jar comes off
    /// in all of them, after what the server said has been folded in; what is
    /// left to do is say what happened.
    private func buyAnswered(_ requestID: String, _ result: Result<BuyOutcome, AppError>, state: inout State) -> Effect<Action> {
        let buy = state.writes.buys.removeValue(forKey: requestID)
        let tap = state.retry?.requestID == requestID ? state.retry : nil
        // The card this answer is for, if it is still the one on screen.
        let isCurrent = state.card?.purchase?.item == buy?.item

        switch result {
        case let .success(.bought(paid, madeUp, jar, replay)):
            state.retry = nil
            Self.log.info("shop:buy bought (madeUp \(madeUp ?? 0), replay \(replay))")
            // What the server says is in the house and the jar, so the
            // purchase does not blink between its answer and the next push.
            if let item = buy?.item, !state.served.has(item) {
                state.served.receive(item)
                // Only when the push has not shown it: then the served jar is
                // already the one after the purchase, and this could be older.
                if let jar {
                    state.served.leaves = jar.leaves
                    state.served.sparkles = jar.sparkles
                }
            }
            guard isCurrent else { return .none }
            if state.card?.paid != paid { state.card?.paid = paid }
            return growAfterBuying(state.card?.purchase?.grow, delay: .milliseconds(1100))

        case .success(.owned):
            // The house had it already — from another phone. Nothing was spent.
            state.retry = nil
            if let item = buy?.item { state.served.receive(item) }
            guard isCurrent else { return .none }
            state.card?.paid = nil
            state.card?.purchase = nil
            return .cancel(id: CancelID.grow)

        case let .success(.short(sparkles, price)):
            state.retry = nil
            guard isCurrent else { return .none }
            state.card?.paid = nil
            if state.card?.purchase?.item.price != price { state.card?.purchase?.priceOverride = price }
            let jar = Coins(leaves: state.served.leaves, sparkles: state.served.sparkles)
            state.card?.shortNote = State.Card.ShortNote(sparkles: sparkles, jar: jar)

        case .success(.unavailable):
            state.retry = nil
            guard isCurrent else { return .none }
            state.card?.paid = nil
            state.card?.notice = .unavailable

        case let .success(.priceChanged(price)):
            // The card again, at the price the server asked.
            state.retry = nil
            guard isCurrent else { return .none }
            state.card?.paid = nil
            state.card?.purchase?.priceOverride = price

        case let .failure(error):
            // Not heard from: it may have gone through, so the retry keeps
            // this tap's request id and the server answers it as the same
            // purchase, never a second one.
            state.retry = tap
            Self.log.error("shop:buy failed: \(error.diagnostic, privacy: .public)")
            guard isCurrent else { return .none }
            state.card?.paid = nil
            state.card?.notice = .offline
            Self.settleCard(&state)
            return .cancel(id: CancelID.grow)
        }
        return .cancel(id: CancelID.grow)
    }

    /// A purchase whose answer was lost can still have gone through: if the
    /// house has the thing, the card says so instead of asking again.
    static func settleCard(_ state: inout State) {
        guard let card = state.card, !card.isBought, let purchase = card.purchase,
              state.shop.standing(of: purchase.item).price == nil else { return }
        state.card?.purchase = nil
        state.card?.notice = nil
        state.card?.shortNote = nil
    }

    /// A companion bought on Choose starts growing once the moment has
    /// played: the coins land, it says it's in the house.
    private func growAfterBuying(_ species: Species?, delay: Duration) -> Effect<Action> {
        guard let species else { return .none }
        return .run { send in
            try await clock.sleep(for: delay)
            await send(.cardGrow(species))
        }
        .cancellable(id: CancelID.grow, cancelInFlight: true)
    }

    private func setLayout(_ layout: SceneLayout, state: inout State) -> Effect<Action> {
        state.writeToken += 1
        let token = state.writeToken
        state.writes.layout = State.Writes.Layout(token: token, value: layout)
        let homeID = state.homeID
        return .run { send in
            await send(.layoutAnswered(token: token, await attempt { try await companionClient.setLayout(homeID, layout) }))
        }
    }

    private func setHolidays(_ holidays: [String]?, state: inout State) -> Effect<Action> {
        state.writeToken += 1
        let token = state.writeToken
        state.writes.holidays = State.Writes.Holidays(token: token, value: holidays)
        let homeID = state.homeID
        return .run { send in
            await send(.holidaysAnswered(token: token, await attempt { try await companionClient.setHolidays(homeID, holidays) }))
        }
    }

    /// A write the server did not take. Its entry is already off, so the
    /// screen is back as it was; this says so.
    private func failed(_ error: AppError, _ name: String, state: inout State) -> Effect<Action> {
        Self.log.error("\(name, privacy: .public) failed: \(error.diagnostic, privacy: .public)")
        guard error != .cancelled else { return .none }
        state.alert = .failure(error)
        return .none
    }
}

extension Result {
    /// What went wrong, or `nil` when nothing did.
    var failureValue: Failure? {
        if case let .failure(error) = self { error } else { nil }
    }
}

extension AppError {
    /// Whether a subscription that ended with this is worth opening again,
    /// as `ConvexConnection.subscribe` judges its own retries.
    var isRetryable: Bool {
        switch self {
        case .offline, .server, .unknown: true
        case .notAuthenticated, .decoding, .validation, .noHomeSelected, .cancelled: false
        }
    }
}

extension CompanionHouse {
    /// Whether the house has it already.
    func has(_ item: ShopItem) -> Bool {
        switch item {
        case let .decor(decor): owned.contains(decor.rawValue)
        case let .species(species): ownedSpecies.contains(species.rawValue)
        case let .pack(pack): pack.species.allSatisfy { ownedSpecies.contains($0.rawValue) }
        }
    }
}

extension CompanionHouse.Lab {
    /// A thing bought with the Lab's coins, kept in the Lab.
    mutating func receive(_ item: ShopItem) {
        switch item {
        case let .decor(decor): owned.insert(decor.rawValue)
        case let .species(species): ownedSpecies.insert(species.rawValue)
        case let .pack(pack): ownedSpecies.formUnion(pack.species.map(\.rawValue))
        }
    }
}

/// Whether the companion shows. On for development builds only while it is an
/// MVP: a release build compiles it and never draws it.
public enum CompanionFlag {
    #if DEBUG || MEASURE
    public static let isEnabled = true
    #else
    public static let isEnabled = false
    #endif
}

/// One answer for a write, from whichever side gets there first. Resumes its
/// continuation exactly once, whether the winner comes before or after the
/// continuation is installed, and cancels the others (the call itself may
/// not notice).
private final class WriteRace<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var outcome: Result<T, any Error>?
    private var isDone = false
    private var tasks: [Task<Void, Never>] = []

    func start(_ continuation: CheckedContinuation<T, any Error>) {
        let early = lock.withLock { () -> Result<T, any Error>? in
            if let outcome { return outcome }
            self.continuation = continuation
            return nil
        }
        if let early { continuation.resume(with: early) }
    }

    func hold(_ call: Task<Void, Never>, _ sleeper: Task<Void, Never>) {
        let finished = lock.withLock { () -> Bool in
            tasks = [call, sleeper]
            return isDone
        }
        if finished { call.cancel(); sleeper.cancel() }
    }

    func finish(_ result: Result<T, any Error>) {
        let (resume, held) = lock.withLock { () -> (CheckedContinuation<T, any Error>?, [Task<Void, Never>]?) in
            guard !isDone else { return (nil, nil) }
            isDone = true
            outcome = result
            defer { continuation = nil }
            return (continuation, tasks)
        }
        // A winner that came before `start` leaves the outcome for it.
        resume?.resume(with: result)
        held?.forEach { $0.cancel() }
    }
}
