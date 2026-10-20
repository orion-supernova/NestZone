import ComposableArchitecture
import SwiftUI

/// The sheets behind the companion card: choosing one, decorating, the album,
/// the house's holidays, and the lab on development builds.
struct CompanionSheet: View {
    @Bindable var store: StoreOf<CompanionFeature>
    let sheet: CompanionFeature.State.Sheet
    /// How far it is pulled up, so the card knows whether it is covered.
    @Binding var detent: PresentationDetent

    var body: some View {
        NavigationStack {
            switch sheet {
            case .choose: ChooseView(store: store)
            case .decorate: DecorateView(store: store)
            case .album: AlbumView(store: store)
            case .holidays: HolidaysView(store: store)
            case .lab: LabView(store: store)
            case .ceremony, .welcome: EmptyView()
            }
        }
        .presentationDetents(sheet == .decorate ? [.large] : [.medium, .large],
                             selection: sheet == .decorate ? .constant(.large) : $detent)
    }
}

/// The sheets' fixed colours.
private enum SheetInk {
    static let spot = Color.white.opacity(0.75)
    static let spotFill = Color.white.opacity(0.04)
    static let spotOn = Palette.lemon.opacity(0.14)
    static let label = Color.black.opacity(0.55)
    static let backdrop = Color.black.opacity(0.92)
    static let polaroid = Color(white: 0.96)
    static let caption = Color.white.opacity(0.75)
}

/// A companion drawn still, for a card that is not the live one.
private struct Portrait: View {
    let species: Species
    let seed: String
    var mood: Mood = .content

    var body: some View {
        ScenePortrait(
            companion: Companion(species: species, seed: seed, startedAt: .distantPast), mood: mood,
            now: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Choose

private struct ChooseView: View {
    let store: StoreOf<CompanionFeature>

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]
    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.chooseHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .oneLine()
                group(L10n.choosePlants, Species.allCases.filter { !$0.isPet })
                group(L10n.choosePets, Species.allCases.filter(\.isPet))
            }
            .padding(Metrics.screenPadding)
        }
        .scrollPosition($position)
        #if DEBUG
        .task { await scrollForever() }
        #endif
        .navigationTitle(Text(store.house.album.isEmpty ? L10n.companionMeetTitle(String(localized: L10n.companionBrand)) : L10n.companionNextTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { store.send(.sheetDismissed) } label: { Text(L10n.commonCancel) }
            }
        }
    }

    #if DEBUG
    /// `-companionScroll 1` scrolls the sheet down and up on its own, so the
    /// scroll can be profiled on a simulator nobody can touch.
    private func scrollForever() async {
        guard UserDefaults.standard.bool(forKey: "companionScroll") else { return }
        var down = true
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 1.2)) { position.scrollTo(edge: down ? .bottom : .top) }
            down.toggle()
        }
    }
    #endif

    private func group(_ title: LocalizedStringResource, _ species: [Species]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .oneLine()
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(species) { kind in
                    Button { store.send(.chose(kind), animation: Motion.arrive) } label: {
                        VStack(spacing: 0) {
                            Portrait(species: kind, seed: "\(store.homeID.rawValue)-\(store.house.album.count)", mood: .bright)
                                .frame(height: 150)
                            Text(kind.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .oneLine()
                                .padding(10)
                        }
                        .clipShape(.rect(cornerRadius: Metrics.tightRadius, style: .continuous))
                        .glassCard(cornerRadius: Metrics.tightRadius)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("Choose.\(kind.rawValue)")
                }
            }
        }
    }
}

// MARK: - Decorate

/// Decorating: the scene, its glowing spots, and a tray of what fits the one
/// tapped. Things the house does not own yet go in as a preview with their
/// price; anything not bought by Done goes back on the shelf.
private struct DecorateView: View {
    @Bindable var store: StoreOf<CompanionFeature>
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dash: CGFloat = 0

    private var spots: [Spot] { store.isPet ? Spot.forPets : Spot.allCases }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack {
                    if let current = store.current {
                        CompanionScene(
                            companion: current, progress: store.progress, mood: store.mood, stage: store.stage,
                            layout: store.draft, southern: store.southern, now: store.clock,
                            choreTick: store.choreTick, careTick: store.careTick
                        )
                        .allowsHitTesting(false)
                    }
                    ForEach(spots) { spot in
                        outline(spot, in: geometry.size)
                    }
                }
            }
            .frame(height: 360)
            .clipShape(.rect(cornerRadius: Metrics.cardRadius, style: .continuous))
            .padding(.horizontal, 12)
            tray
        }
        .navigationTitle(Text(L10n.decorateTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { store.send(.decorateCancelled) } label: { Text(L10n.commonCancel) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button { store.send(.decorateDone) } label: { Text(L10n.commonDone) }
                    .accessibilityIdentifier("DecorateDone")
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { dash = -18 }
        }
    }

    // MARK: Spots

    /// Where a spot is, in the scene's 360-tall space.
    private func frame(of spot: Spot, width: Double) -> CGRect {
        let center = width / 2
        switch spot {
        case .above: return CGRect(x: 10, y: 4, width: width - 20, height: 40)
        case .sky: return CGRect(x: 12, y: 50, width: 64, height: 26)
        case .weather: return CGRect(x: width - 90, y: 50, width: 78, height: 26)
        case .tree: return CGRect(x: center - 96, y: SceneSpace.soil - 226, width: 192, height: 198)
        case .pot: return CGRect(x: center - 58, y: SceneSpace.soil - 12, width: 116, height: 80)
        case .left: return CGRect(x: center - SceneSpace.floorOffset - 28, y: SceneSpace.floor - 48, width: 56, height: 56)
        case .right: return CGRect(x: center + SceneSpace.floorOffset - 28, y: SceneSpace.floor - 48, width: 56, height: 56)
        case .ground: return CGRect(x: center - 104, y: SceneSpace.soil + 58, width: 208, height: 24)
        }
    }

    private func outline(_ spot: Spot, in size: CGSize) -> some View {
        let scale = size.height / SceneSpace.height
        let width = size.width / scale
        let rect = frame(of: spot, width: width)
        let isOn = store.decorateSpot == spot
        let stroke = StrokeStyle(lineWidth: isOn ? 2.4 : 1.6, dash: [5, 4], dashPhase: dash)
        let color = isOn ? Palette.lemon : SheetInk.spot
        return Button { store.send(.spotPicked(spot), animation: Motion.spring) } label: {
            ZStack(alignment: .top) {
                Group {
                    switch spot {
                    case .left, .right:
                        Circle().strokeBorder(color, style: stroke)
                            .background(Circle().fill(isOn ? SheetInk.spotOn : SheetInk.spotFill))
                    case .tree, .ground:
                        Ellipse().strokeBorder(color, style: stroke)
                            .background(Ellipse().fill(isOn ? SheetInk.spotOn : SheetInk.spotFill))
                    default:
                        RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(color, style: stroke)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isOn ? SheetInk.spotOn : SheetInk.spotFill))
                    }
                }
                Text(spot.title)
                    .font(.caption2.weight(.semibold))
                    .fixedSize()
                    .foregroundStyle(isOn ? Palette.lemon : .white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(SheetInk.label))
                    .offset(y: spot == .left || spot == .right ? -18 : 4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(width: rect.width * scale, height: rect.height * scale)
        .position(x: rect.midX * scale, y: rect.midY * scale)
        .accessibilityLabel(Text(spot.title))
        .accessibilityValue(Text(store.draft[spot].flatMap(Decor.init(rawValue:)).map(\.title) ?? L10n.decorateEmpty))
        .accessibilityIdentifier("Spot.\(spot.rawValue)")
    }

    // MARK: The tray

    private var tray: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let spot = store.decorateSpot {
                HStack(alignment: .firstTextBaseline) {
                    Text(spot.title).font(.headline).oneLine()
                    Spacer()
                    Text(spot == .tree ? L10n.decorateTreeLimit : L10n.decorateOneThing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .oneLine()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(choices(for: spot), id: \.rawValue) { decor in
                            item(decor, in: spot)
                        }
                    }
                }
                preview
            } else {
                Text(L10n.decoratePickSpot).font(.headline).oneLine()
            }
            if !store.activeHolidays.isEmpty {
                Text(L10n.decorateSets)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .oneLine()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.activeHolidays) { holiday in
                            Button { store.send(.setPicked(holiday.id), animation: Motion.celebrate) } label: {
                                Text(verbatim: "\(holiday.symbol) \(String(localized: holiday.id.title))")
                                    .font(.subheadline.weight(.semibold))
                                    .fixedSize()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassControl()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What fits a spot: the house's own and today's free things first, then
    /// the shop.
    private func choices(for spot: Spot) -> [Decor] {
        var seen = Set<String>()
        var list: [Decor] = []
        for raw in store.available.sorted() {
            if let decor = Decor(rawValue: raw), decor.kind == spot.kind, seen.insert(raw).inserted { list.append(decor) }
        }
        for item in DecorItem.allCases where item.price != nil && item.kind == spot.kind && !seen.contains(item.rawValue) {
            list.append(.item(item))
        }
        return list
    }

    private func item(_ decor: Decor, in spot: Spot) -> some View {
        let isOn = store.draft.holds(decor.rawValue, in: spot)
        let owned = store.available.contains(decor.rawValue)
        let label: LocalizedStringResource = isOn ? L10n.decoratePlaced
            : store.house.owned.contains(decor.rawValue) ? L10n.decorateYours
            : owned ? L10n.decorateFree
            : priceLabel(decor)
        return Button { store.send(.decorToggled(decor.rawValue), animation: Motion.celebrate) } label: {
            // As wide as its one-line name needs, never narrower than a tile:
            // "Cadılar Bayramı flaması" gets the room, "Kar" doesn't look lost.
            VStack(spacing: 4) {
                Text(verbatim: decor.symbol).font(.title2)
                Text(decor.title)
                    .font(.caption.weight(.semibold))
                    .fixedSize()
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isOn ? Palette.amber : .secondary)
                    .fixedSize()
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 88, minHeight: 96)
            .background(RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                .strokeBorder(isOn ? Palette.amber : Color.clear, lineWidth: 1.5))
            .glassCard(cornerRadius: Metrics.tightRadius)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isOn)
    }

    /// One price, in the one currency the thing is sold for.
    private func priceLabel(_ decor: Decor) -> LocalizedStringResource {
        guard case let .item(item) = decor, let price = item.price else { return L10n.decorateFree }
        return switch price {
        case let .leaves(amount): L10n.decoratePrice(amount)
        case let .sparkles(amount): L10n.decoratePriceSparkles(amount)
        }
    }

    /// A preview the house would have to buy, with the jar's answer.
    @ViewBuilder
    private var preview: some View {
        let unowned = store.draft.all.compactMap(DecorItem.init(rawValue:))
            .filter { $0.price != nil && !store.available.contains($0.rawValue) }
        if let item = unowned.first, let price = item.price {
            let (short, buy, needs): (Int, LocalizedStringResource, LocalizedStringResource) = switch price {
            case let .leaves(amount):
                (amount - store.house.leaves, L10n.decorateBuy(amount), L10n.decorateNeedMore(amount - store.house.leaves))
            case let .sparkles(amount):
                (amount - store.house.sparkles, L10n.decorateBuySparkles(amount), L10n.decorateNeedMoreSparkles(amount - store.house.sparkles))
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.decoratePreview).font(.caption.weight(.semibold)).oneLine()
                    Text(item.title).font(.caption).foregroundStyle(.secondary).oneLine()
                }
                Spacer(minLength: 6)
                Button { store.send(.buyTapped(item.rawValue), animation: Motion.celebrate) } label: {
                    Text(short > 0 ? needs : buy)
                        .font(.footnote.weight(.semibold))
                        .fixedSize()
                }
                .buttonStyle(.glassProminent)
                .tint(theme.accent)
                .disabled(short > 0)
            }
            .padding(10)
            .glassCard(cornerRadius: Metrics.tightRadius)
        }
    }
}

// MARK: - Album

private struct AlbumView: View {
    let store: StoreOf<CompanionFeature>
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ScrollView {
            if store.house.album.isEmpty {
                Text(L10n.albumEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .oneLine()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.house.album.reversed()) { graduate in
                        VStack(alignment: .leading, spacing: 4) {
                            Portrait(species: graduate.species, seed: graduate.seed)
                                .frame(height: 150)
                                .clipShape(.rect(cornerRadius: 6))
                            Text(graduate.species.title)
                                .font(.subheadline.weight(.semibold))
                                .oneLine()
                            Text(verbatim: "\(String(localized: L10n.albumDays(graduate.days))) · \(graduate.graduatedAt.formatted(Date.FormatStyle().month(.abbreviated).year().locale(L10n.locale)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .oneLine()
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.inset))
                    }
                }
                .padding(Metrics.screenPadding)
            }
        }
        .navigationTitle(Text(L10n.albumTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { store.send(.sheetDismissed) } label: { Text(L10n.commonDone) }
            }
        }
    }
}

// MARK: - Holidays

/// The days this house celebrates, from every calendar. A suggestion from the
/// region to start, and every one of them a switch.
private struct HolidaysView: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        List {
            Section {
                Text(L10n.holidaysHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .oneLine()
                Button { store.send(.holidaysReset) } label: { Text(L10n.holidaysSuggested).oneLine() }
            }
            ForEach(Holiday.Family.allCases) { family in
                Section {
                    ForEach(Holiday.all.filter { $0.family == family }) { holiday in
                        row(holiday)
                    }
                } header: {
                    Text(family.title).oneLine()
                }
            }
        }
        .navigationTitle(Text(L10n.holidaysTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { store.send(.sheetDismissed) } label: { Text(L10n.commonDone) }
            }
        }
    }

    private func row(_ holiday: Holiday) -> some View {
        Toggle(isOn: Binding(
            get: { store.celebrated.contains(holiday.id) },
            set: { _ in store.send(.holidayToggled(holiday.id)) }
        )) {
            HStack(spacing: 10) {
                Text(verbatim: holiday.symbol).font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(holiday.id.title)
                        .oneLine()
                    Text(when(holiday))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .oneLine()
                }
            }
        }
    }

    private func when(_ holiday: Holiday) -> String {
        if holiday.isUnderway(on: store.clock, region: store.region) { return String(localized: L10n.holidayNow) }
        guard let next = holiday.next(after: store.clock, region: store.region) else { return "" }
        return String(localized: L10n.holidayNext(next.formatted(Date.FormatStyle().day().month(.wide).year().locale(L10n.locale))))
    }
}

// MARK: - Lab

/// Development builds only: grow it, make it thirsty, pretend it is
/// Halloween. Nothing here reaches the server.
private struct LabView: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        Form {
            Section {
                Text(L10n.labNote).font(.footnote).foregroundStyle(.secondary).oneLine()
            }
            Section(header: Text(L10n.labGrow)) {
                Button { store.send(.labPoints(5)) } label: { Text(L10n.labPoints(5)).oneLine() }
                Button { store.send(.labPoints(20)) } label: { Text(L10n.labPoints(20)).oneLine() }
                Button { store.send(.labPoints(CompanionMath.graduateAt)) } label: { Text(L10n.labReady).oneLine() }
            }
            Section(header: Text(L10n.labMood)) {
                Button { store.send(.labMood(nil)) } label: { Text(L10n.labReal).oneLine() }
                Button { store.send(.labMood(.bright)) } label: { Text(L10n.labBright).oneLine() }
                Button { store.send(.labMood(.thirsty)) } label: { Text(L10n.labThirsty).oneLine() }
                Button { store.send(.labMood(.dozing)) } label: { Text(L10n.labDozing).oneLine() }
            }
            Section(header: Text(L10n.labDay)) {
                Button { store.send(.labDate(nil)) } label: { Text(L10n.labToday).oneLine() }
                ForEach(Holiday.all) { holiday in
                    if let start = holiday.next(after: Date(), region: store.region) {
                        Button { store.send(.labDate(Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: start))) } label: {
                            Text(verbatim: "\(holiday.symbol) \(String(localized: holiday.id.title))").oneLine()
                        }
                    }
                }
            }
            Section {
                Button { store.send(.labCoins(Coins(leaves: 200, sparkles: 0))) } label: { Text(L10n.labLeaves(200)).oneLine() }
                Button { store.send(.labCoins(Coins(leaves: 0, sparkles: 200))) } label: { Text(L10n.labSparkles(200)).oneLine() }
                Button(role: .destructive) { store.send(.labReset) } label: { Text(L10n.labReset).oneLine() }
            }
        }
        .navigationTitle(Text(L10n.labTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { store.send(.sheetDismissed) } label: { Text(L10n.commonDone) }
            }
        }
    }
}

// MARK: - The ceremony

/// Graduation: the grown companion in a glow, petals falling, a polaroid for
/// the album and Leaves for the jar. Short, and only ever started by a tap.
struct CeremonyView: View {
    let store: StoreOf<CompanionFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = 0

    var body: some View {
        ZStack {
            SheetInk.backdrop.ignoresSafeArea()
            if !reduceMotion { Petals().ignoresSafeArea().allowsHitTesting(false) }
            VStack(spacing: 18) {
                Spacer()
                if let current = store.current {
                    CompanionScene(
                        companion: current, progress: 1, mood: .bright, stage: store.stage,
                        layout: store.visibleLayout, southern: store.southern, now: store.clock,
                        choreTick: 0, careTick: beat
                    )
                    .frame(width: 300, height: 300)
                    .clipShape(.rect(cornerRadius: 8))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(SheetInk.polaroid))
                    .rotationEffect(.degrees(beat >= 1 ? -3 : 0))
                    .scaleEffect(beat >= 1 ? 1 : 0.85)
                    .opacity(beat >= 1 ? 1 : 0)
                    Text(L10n.companionReady)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .oneLine()
                        .opacity(beat >= 2 ? 1 : 0)
                    Text(L10n.ceremonyGrownIn(String(localized: current.species.title), store.day))
                        .font(.body)
                        .foregroundStyle(SheetInk.caption)
                        .oneLine()
                        .opacity(beat >= 2 ? 1 : 0)
                    Text(L10n.ceremonyCoins(Rewards.graduation.leaves, Rewards.graduation.sparkles))
                        .font(.headline)
                        .foregroundStyle(Palette.lemon)
                        .oneLine()
                        .opacity(beat >= 3 ? 1 : 0)
                        .scaleEffect(beat >= 3 ? 1 : 0.6)
                }
                Spacer()
                PrimaryButton(L10n.ceremonyAlbum, symbol: "book.closed.fill") {
                    store.send(.ceremonyFinished, animation: Motion.arrive)
                }
                .opacity(beat >= 3 ? 1 : 0)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 24)
                .accessibilityIdentifier("CeremonyAlbum")
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
        .sensoryFeedback(.success, trigger: beat) { _, now in now == 3 }
        .task {
            for step in 1...3 {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 700))
                withAnimation(reduceMotion ? Motion.fade : Motion.celebrate) { beat = step }
            }
        }
    }
}

/// The house's welcome gift: Leaves and Sparkles counting up into the jar,
/// enough for a first decoration with a little over, and a way straight into
/// Decorate to spend it.
struct WelcomeGiftView: View {
    let store: StoreOf<CompanionFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.theme) private var theme
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            SheetInk.backdrop.ignoresSafeArea()
            if !reduceMotion { Petals().ignoresSafeArea().allowsHitTesting(false) }
            VStack(spacing: 22) {
                Spacer()
                Text(verbatim: "🎁")
                    .font(.system(size: 72))
                    .scaleEffect(0.6 + 0.4 * shown)
                Text(L10n.welcomeTitle)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .oneLine()
                HStack(spacing: 28) {
                    amount("🍃", Rewards.welcome.leaves)
                    amount("✨", Rewards.welcome.sparkles)
                }
                Text(L10n.welcomeBody)
                    .font(.body)
                    .foregroundStyle(SheetInk.caption)
                    .oneLine()
                Spacer()
                PrimaryButton(L10n.welcomeDecorate, symbol: "paintbrush.pointed.fill") {
                    store.send(.welcomeDecorateTapped, animation: Motion.arrive)
                }
                .accessibilityIdentifier("WelcomeDecorate")
                Button { store.send(.sheetDismissed) } label: {
                    Text(L10n.welcomeLater).font(.body.weight(.semibold)).oneLine()
                }
                .foregroundStyle(SheetInk.caption)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
        .sensoryFeedback(.success, trigger: shown) { _, now in now == 1 }
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 350))
            withAnimation(reduceMotion ? Motion.fade : .easeOut(duration: 1.1)) { shown = 1 }
        }
    }

    /// A number that counts up from nothing as the gift lands.
    private func amount(_ symbol: String, _ value: Int) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: symbol).font(.title)
            Text(Int((Double(value) * shown).rounded()), format: .number)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit())
                .foregroundStyle(Palette.lemon)
                .contentTransition(.numericText(value: Double(value) * shown))
        }
        .fixedSize()
    }
}

/// Petals drifting down over the ceremony.
private struct Petals: View {
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                var r = Ink.Random(seed: 11)
                let colors: [UInt32] = [0xFF8FB8, 0xFFD27A, 0xC4A7FF]
                for i in 0..<44 {
                    let x0 = r.next() * size.width, speed = r.between(40, 90), delay = r.next() * 4, sway = r.between(10, 30)
                    let y = (t - delay) * speed - 20
                    guard y > -20, y < size.height + 20 else { continue }
                    var c = context
                    c.translateBy(x: x0 + sin(t + Double(i)) * sway, y: y)
                    c.rotate(by: .radians(t * 2 + Double(i)))
                    c.ellipse(0, 0, 5, 3, .color(Ink.color(colors[i % 3], 0.9)))
                }
            }
        }
    }
}
