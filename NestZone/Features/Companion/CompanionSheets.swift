import ComposableArchitecture
import SwiftUI

/// The sheets behind the companion card: choosing one, decorating, the shop,
/// the album, the house's holidays, and the lab on development builds. Any of
/// them can push the Sparkles store. The purchase card floats over the sheet's
/// first screen, so a pushed store covers it and going back finds it there.
struct CompanionSheet: View {
    @Bindable var store: StoreOf<CompanionFeature>
    let sheet: CompanionFeature.State.Sheet
    /// How far it is pulled up, so the card knows whether it is covered.
    @Binding var detent: PresentationDetent
    @State private var geometry = ShopGeometry()

    var body: some View {
        NavigationStack {
            Group {
                switch sheet {
                case .choose: ChooseView(store: store)
                case .vote: VoteView(store: store)
                case .decorate: DecorateView(store: store)
                case .shop: ShopView(store: store)
                case .album: AlbumView(store: store)
                case .holidays: HolidaysView(store: store)
                #if DEBUG
                case .lab: LabView(store: store)
                #endif
                case .ceremony, .welcome: EmptyView()
                }
            }
            .overlay { PurchaseCardLayer(store: store) }
            .overlay { ColourPickerLayer(store: store) }
        }
        .overlay { CoinFlightLayer(geometry: geometry) }
        // The store covers the whole screen, so the Sparkles landing in the
        // jar are in view however far down the packs it was scrolled.
        .fullScreenCover(isPresented: Binding(
            get: { store.storeOpen },
            set: { if !$0 { store.send(.storeDismissed) } }
        )) {
            SparkleStoreScreen(store: store, stage: stage)
        }
        // Full of lanes and grids that scroll: a swipe meant for them closed
        // the shop. It closes with its button.
        .interactiveDismissDisabled(sheet == .shop)
        .environment(\.shopGeometry, geometry)
        .environment(\.shopStage, stage)
        #if DEBUG
        .environment(\.labSheetIsFull, detent == .large)
        #endif
        .presentationDetents(isTall ? [.large] : isLab ? [Self.peek, .medium, .large] : [.medium, .large],
                             selection: isTall ? .constant(.large) : $detent)
        // The Lab is for watching the card while it changes: the screen behind
        // it stays live (Today scrolls) up to half height.
        .presentationBackgroundInteraction(isLab ? .enabled(upThrough: .medium) : .automatic)
    }

    /// The Lab's lowest stop: the card above it is nearly all of the screen.
    static let peek = PresentationDetent.fraction(0.34)

    private var isLab: Bool {
        #if DEBUG
        sheet == .lab
        #else
        false
        #endif
    }

    /// Decorating and shopping need the whole screen.
    private var isTall: Bool { sheet == .decorate || sheet == .shop }

    /// The shop in the light of the house's hour (the Lab's pretend one too).
    private var stage: ShopStage {
        ShopStage(hour: Calendar.current.component(.hour, from: store.clock))
    }
}

/// The sheets' fixed colours.
enum SheetInk {
    static let spot = Color.white.opacity(0.75)
    static let spotFill = Color.white.opacity(0.04)
    static let spotOn = Palette.lemon.opacity(0.14)
    static let label = Color.black.opacity(0.55)
    static let backdrop = Color.black.opacity(0.92)
    static let polaroid = Color(white: 0.96)
    static let caption = Color.white.opacity(0.75)
}

// MARK: - Choose

private struct ChooseView: View {
    let store: StoreOf<CompanionFeature>

    @State private var position = ScrollPosition(edge: .top)
    @Environment(\.shopStage) private var stage
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shop = store.shop
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.chooseHint)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                group(L10n.choosePlants, Species.allCases.filter { !$0.isPet }, shop, jar: true)
                group(L10n.choosePets, Species.allCases.filter(\.isPet), shop)
            }
            .padding(.vertical, 12)
        }
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        // The pets' shapes, built off the main thread before their tiles
        // scroll in.
        .task {
            let plans = Species.allCases.filter(\.isPet).compactMap(CritterPlan.of)
            await Task.detached(priority: .utility) { plans.forEach(CritterGeometry.prepare) }.value
            let seed = "\(store.homeID.rawValue)-\(store.house.albumCount)"
            let big = typeSize.isAccessibilitySize
            let shop = store.shop
            let order = shelved(Species.allCases.filter { !$0.isPet }, shop) + shelved(Species.allCases.filter(\.isPet), shop)
            await StillCache.warm(order.map { kind in
                let portrait = SpeciesPortrait(species: kind, seed: seed, hour: stage.portraitHour)
                return (portrait.still(big: big), AnyView(portrait))
            })
        }
        #if DEBUG || MEASURE
        .task { await scrollForever() }
        #endif
        .navigationTitle(Text(store.house.albumCount == 0 ? L10n.companionMeetTitle(String(localized: L10n.companionBrand)) : L10n.companionNextTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { store.send(.sheetDismissed) } label: { Text(L10n.commonCancel) }
            }
        }
    }

    #if DEBUG || MEASURE
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

    /// The house's own and today's free ones first, then the ones to buy —
    /// tapping one asks before it spends — then the ones that can't be had
    /// today, which say when they can. The jar sits beside the first heading:
    /// over the title it squeezed "Meet Nestie" to "Meet Ne…".
    private func group(_ title: LocalizedStringResource, _ species: [Species], _ shop: ShopContext, jar: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // The jar goes under the heading at the accessibility sizes: beside
            // it, "Plants" broke in the middle of the word.
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                if jar {
                    Button { store.send(.storeTapped) } label: {
                        JarAmounts(leaves: store.house.leaves, sparkles: store.house.sparkles)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .glassControl()
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 20)
            ShopGrid(columns: 2) {
                ForEach(shelved(species, shop)) { kind in
                    SpeciesTile(
                        species: kind, seed: "\(store.homeID.rawValue)-\(store.house.albumCount)",
                        standing: shop.standing(of: kind), southern: store.southern, now: store.clock
                    ) {
                        store.send(.growTapped(kind), animation: ShopMotion.cardIn)
                    }
                    .accessibilityIdentifier("Choose.\(kind.rawValue)")
                }
            }
            .padding(.horizontal, 20)
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
    @Environment(\.shopStage) private var stage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var dash: CGFloat = 0
    /// A tray tile and its picture grow with the text, so a name that needs
    /// the room has it.
    @ScaledMetric(relativeTo: .footnote) private var trayWidth = 92.0
    @ScaledMetric(relativeTo: .footnote) private var trayArt = 60.0

    private var spots: [Spot] { store.isPet ? Spot.forPets : Spot.allCases }

    var body: some View {
        // At the accessibility sizes the tray is taller than what is left
        // under the scene: the whole screen scrolls.
        Group {
            if typeSize.isAccessibilitySize {
                ScrollView { content }
            } else {
                content
            }
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

    private var content: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack {
                    if let current = store.current {
                        CompanionScene(
                            companion: current, progress: store.progress, mood: store.mood, stage: store.stage,
                            layout: store.draft, southern: store.southern, now: store.clock,
                            choreTick: store.choreTick, careTick: store.careTick,
                            colourway: current.colour ?? 0
                        )
                        .allowsHitTesting(false)
                        // The spots below say what is where.
                        .accessibilityHidden(true)
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
        // Beside the crown, clear of the tree's own spot; on a pet's head.
        case .wearing:
            return store.isPet
                ? CGRect(x: center - 32, y: SceneSpace.floor - 222, width: 64, height: 40)
                : CGRect(x: center + 100, y: SceneSpace.soil - 150, width: 58, height: 40)
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
        // Only the spot being dressed moves; the rest hold still.
        let stroke = StrokeStyle(lineWidth: isOn ? 2.4 : 1.6, dash: [5, 4], dashPhase: isOn ? dash : 0)
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
                    .font(.footnote.weight(.bold))
                    .fixedSize()
                    .foregroundStyle(isOn ? Palette.lemon : .white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(SheetInk.label))
                    .offset(y: spot == .left || spot == .right ? -18 : 4)
                    // Labels on a drawing of a fixed size: they stop growing
                    // here, and VoiceOver says the full name.
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            // The outline keeps its size; the hit area is at least a finger.
            .frame(width: rect.width * scale, height: rect.height * scale)
            .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .position(x: rect.midX * scale, y: rect.midY * scale)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityLabel(Text(spot.title))
        .accessibilityValue(Text(store.draft[spot].flatMap(Decor.init(rawValue:)).map(\.title) ?? L10n.decorateEmpty))
        .accessibilityIdentifier("Spot.\(spot.rawValue)")
    }

    // MARK: The tray

    private var tray: some View {
        let shop = store.shop
        let big = typeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: 12) {
            (big ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 8))) {
                if let spot = store.decorateSpot {
                    Text(spot.title)
                        .font(.headline)
                        .oneLineUnlessAccessibility(shrinking: 1)
                    Text(spot == .tree ? L10n.decorateTreeLimit : L10n.decorateOneThing)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .oneLineUnlessAccessibility(shrinking: 0.9)
                } else {
                    Text(L10n.decoratePickSpot)
                        .font(.headline)
                        .oneLineUnlessAccessibility(shrinking: 0.9)
                }
                if !big { Spacer(minLength: 8) }
                Button { store.send(.storeTapped) } label: {
                    JarAmounts(leaves: store.house.leaves, sparkles: store.house.sparkles)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .glassControl()
                }
                .buttonStyle(.pressable)
            }
            if let spot = store.decorateSpot {
                ScrollView(.horizontal) {
                    GlassGroup(spacing: 0) {
                        HStack(spacing: 10) {
                            ForEach(choices(for: spot, shop), id: \.rawValue) { decor in
                                item(decor, in: spot, shop)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                preview(shop)
            }
            if !store.activeHolidays.isEmpty {
                Text(L10n.decorateSets)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.activeHolidays) { holiday in
                            Button { store.send(.setPicked(holiday.id), animation: Motion.spring) } label: {
                                Text(verbatim: "\(holiday.symbol) \(String(localized: holiday.id.title))")
                                    .font(.subheadline.weight(.semibold))
                                    .fixedSize()
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .glassControl()
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What fits a spot: the house's own and today's free things first, then
    /// whatever is on sale today.
    private func choices(for spot: Spot, _ shop: ShopContext) -> [Decor] {
        var seen = Set<String>()
        var list: [Decor] = []
        for raw in store.available.sorted() {
            if let decor = Decor(rawValue: raw), decor.kind == spot.kind, seen.insert(raw).inserted { list.append(decor) }
        }
        for item in DecorItem.allCases
        where item.kind == spot.kind && !seen.contains(item.rawValue) && shop.standing(of: item).price != nil {
            list.append(.item(item))
        }
        return list
    }

    /// A thing in the tray: tapping puts it in the scene to try, or takes it
    /// out. One haptic, from the press.
    private func item(_ decor: Decor, in spot: Spot, _ shop: ShopContext) -> some View {
        let isOn = store.draft.holds(decor.rawValue, in: spot)
        let standing: Standing = if case let .item(item) = decor { shop.standing(of: item) } else { .freeToday }
        return Button { store.send(.decorToggled(decor.rawValue), animation: Motion.spring) } label: {
            VStack(alignment: .leading, spacing: 6) {
                StageWell(cornerRadius: 12, shadow: false) {
                    DecorPortrait(decor: decor, hour: stage.portraitHour, fallbackSize: 32).equatable()
                }
                .frame(width: trayWidth, height: trayArt)
                .overlay(alignment: .topTrailing) {
                    if isOn { HaveBadge().padding(4).transition(.scale.combined(with: .opacity)) }
                }
                Text(decor.title)
                    .font(.footnote.weight(.semibold))
                    .oneLineUnlessAccessibility(shrinking: 0.85)
                    .frame(maxWidth: trayWidth, alignment: .leading)
                if let price = standing.price, !standing.isUsable, !isOn {
                    PriceTag(price: price)
                } else {
                    Text(isOn ? L10n.decoratePlaced : standing == .have || standing == .free ? L10n.decorateYours : L10n.decorateFree)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .oneLineUnlessAccessibility(shrinking: 0.85)
                        .frame(minHeight: 28)
                }
            }
            .padding(6)
            .glassCard(cornerRadius: 16, tinted: isOn ? theme.accent.opacity(0.3) : nil)
            .animation(Motion.pop, value: isOn)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(decor.title))
        .accessibilityValue(isOn ? Text(L10n.decoratePlaced) : standing.price.map { Text(verbatim: $0.spoken) } ?? Text(L10n.decorateYours))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    /// A preview the house would have to buy. Buying asks first, on the card.
    @ViewBuilder
    private func preview(_ shop: ShopContext) -> some View {
        let available = store.available
        let unowned = store.draft.all.compactMap(DecorItem.init(rawValue:))
            .filter { !available.contains($0.rawValue) && shop.standing(of: $0).price != nil }
        if let item = unowned.first, let price = shop.standing(of: item).price {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.decoratePreview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Button { store.send(.itemTapped(.decor(item)), animation: ShopMotion.cardIn) } label: {
                    HStack(spacing: 6) {
                        Text(L10n.cardBuy)
                        Amount(price.currency, price.amount, plain: true)
                    }
                }
                .buttonStyle(.depthCompact)
                .accessibilityLabel(Text(verbatim: "\(String(localized: L10n.cardBuy)), \(price.spoken)"))
                .accessibilityIdentifier("DecorateBuy")
            }
            .padding(12)
            .glassCard(cornerRadius: Metrics.cardRadius)
        }
    }
}

// MARK: - Album

private struct AlbumView: View {
    let store: StoreOf<CompanionFeature>
    /// A card is wider as the text is, so its words keep their room.
    @ScaledMetric(relativeTo: .body) private var cardWidth = 150.0

    private var columns: [GridItem] { [GridItem(.adaptive(minimum: cardWidth), spacing: 14)] }

    var body: some View {
        ScrollView {
            if store.house.albumCount == 0 {
                Text(L10n.albumEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .oneLineUnlessAccessibility()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if store.house.album.isEmpty {
                // The house has graduated some; their cards are on their way.
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.house.album.reversed()) { graduate in
                        VStack(alignment: .leading, spacing: 4) {
                            SpeciesPortrait(species: graduate.species, seed: graduate.seed, mood: .content, colourway: graduate.colour ?? 0)
                                .frame(height: 150)
                                .clipShape(.rect(cornerRadius: 6))
                                .accessibilityHidden(true)
                            (graduate.colour.map { Text(L10n.companionColoured(String(localized: graduate.species.title), String(localized: graduate.species.colourName($0)))) } ?? Text(graduate.species.title))
                                .font(.subheadline.weight(.semibold))
                                .oneLineUnlessAccessibility()
                            Text(verbatim: "\(String(localized: L10n.albumDays(graduate.days))) · \(graduate.graduatedAt.formatted(Date.FormatStyle().month(.abbreviated).year().locale(L10n.locale)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .oneLineUnlessAccessibility()
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.inset))
                        // "Magnolia, 14 days · Oct 2026": one card, one stop.
                        .accessibilityElement(children: .combine)
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
                    .oneLineUnlessAccessibility()
                Button { store.send(.holidaysReset) } label: { Text(L10n.holidaysSuggested).oneLineUnlessAccessibility() }
            }
            ForEach(Holiday.Family.allCases) { family in
                Section {
                    ForEach(Holiday.all.filter { $0.family == family }) { holiday in
                        row(holiday)
                    }
                } header: {
                    Text(family.title).oneLineUnlessAccessibility()
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
                // The emoji would be read as its own description.
                Text(verbatim: holiday.symbol).font(.title3).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(holiday.id.title)
                        .oneLineUnlessAccessibility()
                    Text(when(holiday))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .oneLineUnlessAccessibility()
                }
            }
        }
    }

    private func when(_ holiday: Holiday) -> String {
        if holiday.isUnderway(on: store.clock, region: store.placeRegion) { return String(localized: L10n.holidayNow) }
        guard let next = holiday.next(after: store.clock, region: store.placeRegion) else { return "" }
        return String(localized: L10n.holidayNext(next.formatted(Date.FormatStyle().day().month(.wide).year().locale(L10n.locale))))
    }
}

// MARK: - The ceremony

/// Graduation: the grown companion in a glow, petals falling, a polaroid for
/// the album and Leaves for the jar. Short, and only ever started by a tap.
struct CeremonyView: View {
    let store: StoreOf<CompanionFeature>

    /// Who is graduating: the one on Today, or — when choosing the next one
    /// graduated a ready one in the same write — the one that was.
    private struct Subject {
        var companion: Companion
        var stage: Int
        var days: Int
        var paid: Coins?
    }

    private var subject: Subject? {
        if let moment = store.moment {
            let isPet = moment.species.isPet
            return Subject(
                companion: Companion(species: moment.species, seed: moment.seed, startedAt: moment.startedAt),
                stage: CompanionMath.stageCount(isPet: isPet) - 1,
                days: Graduate(id: UUID(), species: moment.species, seed: moment.seed,
                               startedAt: moment.startedAt, graduatedAt: moment.graduatedAt).days,
                paid: moment.paid
            )
        }
        guard let current = store.look else { return nil }
        return Subject(companion: current, stage: store.stage, days: store.day, paid: Rewards.graduation)
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = 0
    /// The finale has taken the cover over from the graduation (or is all of
    /// it, when the graduation was played already).
    @State private var showsFinale = false

    /// A graduation that went on to the finale has its own way out, at the end.
    private var leadsToFinale: Bool { store.moment?.isFinale == true }

    var body: some View {
        ZStack {
            SheetInk.backdrop.ignoresSafeArea()
            // The finale has its own confetti; petals over it would be a second
            // continuous canvas for nothing.
            if !reduceMotion, store.moment?.isFinaleOnly != true { Petals().ignoresSafeArea().allowsHitTesting(false) }
            if let moment = store.moment, moment.isFinale, showsFinale || moment.isFinaleOnly {
                FinaleView(store: store, moment: moment)
                    .transition(.opacity)
            } else {
            ScrollsAtAccessibilitySizes {
            VStack(spacing: 18) {
                Spacer()
                if let subject {
                    CompanionScene(
                        companion: subject.companion, progress: 1, mood: .bright, stage: subject.stage,
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
                    // The words under it name the one that grew up.
                    .accessibilityHidden(true)
                    Text(L10n.companionReady)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .oneLineUnlessAccessibility()
                        .opacity(beat >= 2 ? 1 : 0)
                        .accessibilityHidden(beat < 2)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.ceremonyGrownIn(String(localized: subject.companion.species.title), subject.days))
                        .font(.body)
                        .foregroundStyle(SheetInk.caption)
                        .multilineTextAlignment(.center)
                        .oneLineUnlessAccessibility()
                        .opacity(beat >= 2 ? 1 : 0)
                        .accessibilityHidden(beat < 2)
                    if let paid = subject.paid {
                        Text(L10n.ceremonyCoins(paid.leaves, paid.sparkles))
                            .font(.headline)
                            .foregroundStyle(Palette.lemon)
                            .multilineTextAlignment(.center)
                            .oneLineUnlessAccessibility()
                            .opacity(beat >= 3 ? 1 : 0)
                            .scaleEffect(beat >= 3 ? 1 : 0.6)
                            .accessibilityHidden(beat < 3)
                    }
                }
                Spacer()
                PrimaryButton(L10n.ceremonyAlbum, symbol: "book.closed.fill") {
                    // A graduation that already happened (a start brought it)
                    // only closes; the one on Today graduates the companion.
                    store.send(store.moment == nil ? .ceremonyFinished : .momentDismissed, animation: Motion.arrive)
                }
                .opacity(beat >= 3 && !leadsToFinale ? 1 : 0)
                .allowsHitTesting(!leadsToFinale)
                .accessibilityHidden(beat < 3 || leadsToFinale)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 24)
                .accessibilityIdentifier("CeremonyAlbum")
            }
            .padding(.horizontal, Metrics.screenPadding)
            }
            }
        }
        .sensoryFeedback(.success, trigger: beat) { _, now in now == 3 && store.moment?.isFinaleOnly != true }
        .task {
            // The graduation was played already: only the finale is shown.
            guard store.moment?.isFinaleOnly != true else { return }
            for step in 1...3 {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 700))
                withAnimation(reduceMotion ? Motion.fade : Motion.celebrate) { beat = step }
                // Said once, when the words arrive: the picture and the
                // confetti cannot tell anyone what happened.
                if step == 2, let subject {
                    let line = "\(String(localized: L10n.companionReady)) \(String(localized: L10n.ceremonyGrownIn(String(localized: subject.companion.species.title), subject.days)))"
                    AccessibilityNotification.Announcement(line).post()
                }
            }
            // One sequence: after a beat with the coins, the same cover goes
            // on to "You've grown them all".
            guard leadsToFinale else { return }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 600 : 1600))
            withAnimation(Motion.fade) { showsFinale = true }
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            SheetInk.backdrop.ignoresSafeArea()
            if !reduceMotion { Petals().ignoresSafeArea().allowsHitTesting(false) }
            ScrollsAtAccessibilitySizes {
            VStack(spacing: 22) {
                Spacer()
                Text(verbatim: "🎁")
                    .font(.system(size: 72))
                    .scaleEffect(0.6 + 0.4 * shown)
                    .accessibilityHidden(true)
                Text(L10n.welcomeTitle)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .oneLineUnlessAccessibility()
                    .accessibilityAddTraits(.isHeader)
                (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 28))) {
                    amount("🍃", Rewards.welcome.leaves)
                    amount("✨", Rewards.welcome.sparkles)
                }
                // The emoji and a number that counts up, said as the sum.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(L10n.ceremonyCoins(Rewards.welcome.leaves, Rewards.welcome.sparkles)))
                Text(L10n.welcomeBody)
                    .font(.body)
                    .foregroundStyle(SheetInk.caption)
                    .multilineTextAlignment(.center)
                    .oneLineUnlessAccessibility()
                Spacer()
                PrimaryButton(L10n.welcomeDecorate, symbol: "paintbrush.pointed.fill") {
                    store.send(.welcomeDecorateTapped, animation: Motion.arrive)
                }
                .accessibilityIdentifier("WelcomeDecorate")
                Button { store.send(.sheetDismissed) } label: {
                    Text(L10n.welcomeLater).font(.body.weight(.semibold)).oneLineUnlessAccessibility()
                        .frame(minHeight: Metrics.minTapTarget)
                        .contentShape(.rect)
                }
                .foregroundStyle(SheetInk.caption)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, Metrics.screenPadding)
            }
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

/// A full-screen column that is centred as it is at the usual sizes, and
/// scrolls once the text is so large that it would not fit.
private struct ScrollsAtAccessibilitySizes<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
        } else {
            content
        }
    }
}

/// Petals drifting down over the ceremony.
private struct Petals: View {
    @State private var start = Date()

    var body: some View {
        petals.accessibilityHidden(true)
    }

    private var petals: some View {
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
