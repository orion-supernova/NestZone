#if DEBUG
import ComposableArchitecture
import SwiftUI
import os

// Nestie against a stand-in server, on a simulator nobody is signed in on.
//
//   xcrun simctl launch <udid> com.walhallaa.NestZone -nestieBench 1 \
//       [-nestieScenario fresh|growing|ready|young|vote|voteAlone|finale] \
//       [-nestieScript buy|care|ceremony|decorate|holidays|choose|chooseWarm|chooseReady|vote|voteSettle|votePick|finale|finaleStart|finaleChoose] \
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
//
// It is the Lab's pretend house with a scenario in place of the file: the same
// server (`FakeNestieServer`), the same host (`CompanionHost`), the same Lab
// sheet on the card. `-nestieLab keep` keeps the Lab's file from the last run.

struct NestieBench: View {
    @State private var store: StoreOf<CompanionFeature>
    @State private var position = ScrollPosition()
    @State private var isScrolling = false
    private let server: FakeNestieServer

    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Nestie")

    init() {
        let server = FakeNestieServer(Bench.arguments, home: "bench-home")
        self.server = server
        var state = CompanionFeature.State(homeID: "bench-home", region: "TR")
        // A bench is always a pretend house, and starts with a clean Lab so a
        // run is the scenario and nothing left over from the last one.
        state.withLab {
            if UserDefaults.standard.string(forKey: "nestieLab") != "keep" { $0 = CompanionLab() }
            $0.pretend = true
        }
        _store = State(initialValue: Store(initialState: state) {
            CompanionHost()
        } withDependencies: {
            $0.pretendHouse = server
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
    struct Arguments: Sendable {
        var scenario = "growing"
        var script = ""
        var buy = "honest"
        var fail: Set<String> = []
        var latency = Duration.milliseconds(250)
        /// The connection is down: every write fails (the Lab's switch).
        var offline = false
        var push = false
        /// `-nestieSpecies <raw value>` grows that one instead, to measure a
        /// drawing; `-nestieDecor full` owns and puts out a scene's worth.
        var species: Species?
        var decor: String?
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
        args.species = defaults.string(forKey: "nestieSpecies").flatMap(Species.init(rawValue:))
        args.decor = defaults.string(forKey: "nestieDecor")
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

    /// `-nestieLabDo "species=fox,colour=2,hour=22,fill"`: Lab controls driven
    /// from the command line, one every 1.5 s after the house has loaded, to
    /// photograph what each does. Tokens: species=<raw>, colour=<n>, stage=<n>,
    /// share=<0-1>, ready, stageup, hour=<h>, day=<holiday id>, mood=<raw>,
    /// fill, clear, backdrop=<raw>, wear=<raw>, leaves=<n>, sparkles=<n>,
    /// album=<n>, free, colours=<n>, members=<n>, vote, answer, preset=<raw>,
    /// moment=<raw>, buy=<outcome>, quiet=<days>, south, north, birthday, wait.
    @MainActor
    static func labDo(store: StoreOf<CompanionFeature>) async {
        guard let list = UserDefaults.standard.string(forKey: "nestieLabDo") else { return }
        while !store.isLoaded { try? await Task.sleep(for: .milliseconds(100)) }
        try? await Task.sleep(for: .seconds(2))
        for token in list.split(separator: ",").map(String.init) {
            let parts = token.split(separator: "=", maxSplits: 1).map(String.init)
            let value = parts.count > 1 ? parts[1] : ""
            func look(_ edit: (inout LabLook) -> Void) {
                var next = store.labLook
                edit(&next)
                store.send(.lab(.look(next)))
            }
            switch parts[0] {
            case "species": if let s = Species(rawValue: value) { store.pretend(.setSpecies(s)) }
            case "colour": store.pretend(.setColour(Int(value).flatMap { $0 == 0 ? nil : $0 }))
            case "stage": store.pretend(.setStage(Int(value) ?? 0))
            case "share": store.pretend(.setStageShare(Double(value) ?? 0))
            case "ready": store.pretend(.makeReady)
            case "stageup": store.pretend(.stageUp)
            case "hour":
                let h = Double(value) ?? 12
                look { $0.date = Calendar.current.date(bySettingHour: Int(h), minute: Int((h - Double(Int(h))) * 60), second: 0, of: store.clock) }
            case "day": if let id = Holiday.ID(rawValue: value) { store.send(.lab(.moment(.holidayChip(id)))) }
            case "mood": look { $0.mood = Mood(rawValue: value) }
            case "fill": store.pretend(.fillScene)
            case "clear": store.pretend(.clearScene)
            case "backdrop": store.pretend(.place(value, .sky))
            case "wear": store.pretend(.place(value, .wearing))
            case "leaves": store.pretend(.setLeaves(Int(value) ?? 0))
            case "sparkles": store.pretend(.setSparkles(Int(value) ?? 0))
            case "album": store.pretend(.fillAlbum(Int(value) ?? 0))
            case "free": store.pretend(.growAllFree)
            case "colours": store.pretend(.growColours(Int(value) ?? 1))
            case "members": store.lab(.members(Int(value) ?? 1))
            case "vote": store.pretend(.openVote)
            case "answer": store.pretend(.othersAnswerAll)
            case "preset": if let p = PretendPreset(rawValue: value) { store.lab(.preset(p)) }
            case "moment":
                let moments: [String: LabMoment] = [
                    "welcome": .welcome, "stageUp": .stageUp, "ceremony": .ceremony, "held": .heldGraduation, "finale": .finale,
                    "finaleStart": .finaleUnderStart, "newOne": .newOne, "vote": .voteOpens,
                ]
                if let m = moments[value] { store.lab(.moment(m)) }
            case "buy": store.lab(.nextBuy(value))
            case "quiet": store.pretend(.quiet(days: Int(value) ?? 4))
            case "south": store.pretend(.setRegion("AU"))
            case "north": store.pretend(.setRegion("TR"))
            case "birthday": look { $0.birthday = true }
            case "shop": store.send(.shopTapped)
            case "item": if let d = DecorItem(rawValue: value) { store.send(.itemTapped(.decor(d))) }
            case "care": store.send(.careTapped)
            case "lab": store.send(.labTapped)
            default: break
            }
            try? await Task.sleep(for: .milliseconds(parts[0] == "wait" ? 4000 : 1500))
        }
    }

    @MainActor
    static func run(store: StoreOf<CompanionFeature>, server: FakeNestieServer) async {
        let script = UserDefaults.standard.string(forKey: "nestieScript") ?? ""
        if UserDefaults.standard.bool(forKey: "nestiePush") { await server.pushForever() }
        await labDo(store: store)
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
        case "chooseWarm":
            // Choose as the app meets it: a sheet (and its navigation stack)
            // has opened and closed before, so the first open measured is
            // Choose and not the first sheet of the process. Then Choose
            // again, which is the warm one.
            store.send(.holidaysTapped)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.sheetDismissed)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.chooseTapped)
            try? await Task.sleep(for: .seconds(2.5))
            report("choose open", store)
            // And again: the second open is Choose with everything it needs
            // already looked up, which is how the app meets it after the first.
            store.send(.sheetDismissed)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.chooseTapped)
            try? await Task.sleep(for: .seconds(2))
            report("choose open again", store)
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
        // The screens left open, for the accessibility pass (screenshots at
        // the accessibility sizes, `Docs/Companion/a11y`).
        case "decorateOpen":
            store.send(.decorateTapped)
            try? await Task.sleep(for: .seconds(0.6))
            store.send(.spotPicked(.ground))
        case "ceremonyOpen":
            store.send(.celebrateTapped)
        case "albumOpen":
            store.send(.albumTapped)
        case "storeOpen":
            store.send(.shopTapped)
            try? await Task.sleep(for: .seconds(1))
            store.send(.storeTapped)
        default:
            break
        }
    }
}
#endif
