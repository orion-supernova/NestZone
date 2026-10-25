import ComposableArchitecture
import SwiftUI

// The shop behind the jar, the card that asks before anything is bought, and
// the Sparkles store — as ordinary NestZone screens: glass on the Backdrop, the
// theme's accent, SF Symbols, the app's type. The playfulness is in the
// motion: coins fly from the jar to what they buy, numbers roll, symbols
// bounce, every state change has its haptic, and Sparkles bought take a
// deliberate second to land, so the house sees that it worked.

// MARK: - Coins in the air

/// Where the jar is on screen, and the coins in flight from it, in global
/// coordinates — the card's jar and its art, or a pack and the store's
/// counter, meet here.
@Observable
final class ShopGeometry {
    var flights: [CoinFlight] = []

    func launch(_ kinds: [Amount.Currency], from: CGRect, to: CGRect, stagger: Double = 0.05) {
        guard from != .zero, to != .zero else { return }
        let start = CGPoint(x: from.midX, y: from.midY), end = CGPoint(x: to.midX, y: to.midY)
        flights += kinds.enumerated().map { index, kind in
            CoinFlight(kind: kind, from: start, to: end, delay: Double(index) * stagger)
        }
    }
}

struct CoinFlight: Identifiable, Equatable {
    let id = UUID()
    let kind: Amount.Currency
    let from: CGPoint
    let to: CGPoint
    let delay: Double
}

extension EnvironmentValues {
    @Entry var shopGeometry = ShopGeometry()
}

/// The coins in the air, over a whole screen.
struct CoinFlightLayer: View {
    let geometry: ShopGeometry

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            ForEach(geometry.flights) { flight in
                FlyingCoin(flight: flight, origin: origin) {
                    geometry.flights.removeAll { $0.id == flight.id }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct FlyingCoin: View {
    let flight: CoinFlight
    let origin: CGPoint
    let done: () -> Void
    @State private var progress: CGFloat = 0

    var body: some View {
        Image(systemName: flight.kind.symbol)
            .font(.title3.weight(.semibold))
            .foregroundStyle(flight.kind == .leaves ? Palette.leaf : Palette.sparkle)
            .symbolColorRenderingMode(.gradient)
            .modifier(Arc(
                progress: progress,
                from: CGPoint(x: flight.from.x - origin.x, y: flight.from.y - origin.y),
                to: CGPoint(x: flight.to.x - origin.x, y: flight.to.y - origin.y)
            ))
            .task {
                withAnimation(Motion.travel.delay(flight.delay)) { progress = 1 }
                try? await Task.sleep(for: .seconds(0.8 + flight.delay))
                done()
            }
    }
}

/// A coin along an arc that rises 40 points above the straight line, getting
/// smaller as it goes into what it buys and fading only as it lands — worked
/// out from the same progress, so the fade is part of the flight.
private struct Arc: ViewModifier, Animatable {
    var progress: CGFloat
    let from: CGPoint
    let to: CGPoint

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let u = progress, v = 1 - progress
        let control = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - 40)
        let x = v * v * from.x + 2 * v * u * control.x + u * u * to.x
        let y = v * v * from.y + 2 * v * u * control.y + u * u * to.y
        content
            .scaleEffect(1 - 0.35 * u)
            .opacity(u < 0.85 ? 1 : max(0, (1 - u) / 0.15))
            .position(x: x, y: y)
    }
}

// MARK: - The shop

/// The whole catalog, behind the jar on the card: decorations by where they
/// go, then plants, then pets and their packs. Everything is tappable — to buy
/// it, or to hear how it comes.
///
/// Each shelf is its own page with its own scroll, under a switch pinned in a
/// bar: switching never shows a shelf half-laid-out or past its end, each
/// keeps its place, and a swipe moves between them too. One long list whose
/// content was swapped flashed empty and opened the shorter shelf past its
/// end.
struct ShopView: View {
    let store: StoreOf<CompanionFeature>
    #if DEBUG || MEASURE
    /// `-companionShelf pets` opens it on that shelf, for screenshots.
    @State private var shelf = UserDefaults.standard.string(forKey: "companionShelf").flatMap(Shelf.init(rawValue:)) ?? .decor
    #else
    @State private var shelf = Shelf.decor
    #endif
    @Environment(\.theme) private var theme
    @Environment(\.shopStage) private var stage
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Shelf: String, CaseIterable, Identifiable {
        case decor, plants, pets
        var id: String { rawValue }
    }

    private var shelfSelection: Binding<Shelf> {
        Binding(get: { shelf }, set: { next in
            withAnimation(reduceMotion ? Motion.fade : .snappy(duration: 0.32)) { shelf = next }
        })
    }

    var body: some View {
        let shop = store.shop
        TabView(selection: shelfSelection) {
            page { decor(shop) }.tag(Shelf.decor)
            page { species(Species.allCases.filter { !$0.isPet }, shop) }.tag(Shelf.plants)
            page { pets(shop) }.tag(Shelf.pets)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // What a shelf's tiles draw their pets from, built off the main
        // thread before they scroll in: a first build in a scroll was a
        // dropped frame.
        .task(id: shelf) {
            let stills = stills(on: shelf)
            let pets: [Species] = shelf == .pets ? Species.allCases.filter(\.isPet) : shelf == .decor ? DecorPortrait.pets : []
            await Task.detached(priority: .utility) { pets.compactMap(CritterPlan.of).forEach(CritterGeometry.prepare) }.value
            await StillCache.warm(stills)
        }
        #if DEBUG || MEASURE
        .task {
            // `-companionShelfCycle 1` switches shelves on its own, to watch
            // a switch frame by frame.
            guard UserDefaults.standard.bool(forKey: "companionShelfCycle") else { return }
            for next in [Shelf.pets, .plants, .decor, .pets] {
                try? await Task.sleep(for: .seconds(1.5))
                shelfSelection.wrappedValue = next
            }
        }
        #endif
        .safeAreaBar(edge: .top) {
            ShelfSwitch(selection: shelfSelection)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 8)
        }
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.shopTitle))
        .navigationSubtitle(Text(L10n.shopSubtitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) { store.send(.sheetDismissed) }
                    .tint(.primary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                // Plain amounts: the toolbar draws the one capsule around them.
                Button { store.send(.storeTapped) } label: {
                    JarAmounts(leaves: store.house.leaves, sparkles: store.house.sparkles)
                }
                // A toolbar button draws its label in the tint, whatever the
                // label asks for: violet numbers on dark glass are ~2:1.
                .tint(.primary)
                .accessibilityIdentifier("ShopJar")
            }
        }
    }

    /// The pictures a shelf's tiles show, to be kept before they scroll in.
    private func stills(on shelf: Shelf) -> [(StillSpec, AnyView)] {
        let big = typeSize.isAccessibilitySize
        let seed = "\(store.homeID.rawValue)-\(store.house.albumCount)"
        func species(_ list: [Species]) -> [(StillSpec, AnyView)] {
            list.map { kind in
                let portrait = SpeciesPortrait(species: kind, seed: seed, hour: stage.portraitHour)
                return (portrait.still(big: big), AnyView(portrait))
            }
        }
        switch shelf {
        case .decor:
            // In the order the shelf lays them out, so the ones on screen come first.
            let everyday = DecorItem.allCases.filter { $0.access != .holiday }
            let ordered = Self.kinds.flatMap { kind, _ in everyday.filter { $0.kind == kind } } + DecorItem.allCases.filter { $0.access == .holiday }
            return ordered.map { item in
                let portrait = DecorPortrait(decor: .item(item), hour: stage.portraitHour)
                return (portrait.still(big: big), AnyView(portrait))
            }
        case .plants: return species(shelved(Species.allCases.filter { !$0.isPet }, store.shop))
        case .pets: return species(shelved(Species.allCases.filter(\.isPet), store.shop))
        }
    }

    /// One shelf's own scroll.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ShelfPage(content: content())
    }

    // MARK: Decorations

    /// By where they go, the scenes first; then what only the holidays bring.
    private static let kinds: [(DecorItem.Kind, LocalizedStringResource)] = [
        (.sky, L10n.shopShelfScenes), (.above, L10n.spotAbove), (.tree, L10n.spotTree), (.wearing, L10n.spotWearing),
        (.pot, L10n.spotPot), (.floor, L10n.shopShelfFloor), (.ground, L10n.spotGround), (.weather, L10n.spotWeather),
    ]

    @ViewBuilder
    private func decor(_ shop: ShopContext) -> some View {
        let everyday = DecorItem.allCases.filter { $0.access != .holiday }
        ForEach(Self.kinds, id: \.0) { kind, title in
            let items = everyday.filter { $0.kind == kind }
            if !items.isEmpty { section(title, items, shop) }
        }
        section(L10n.shopShelfHolidays, DecorItem.allCases.filter { $0.access == .holiday }, shop)
    }

    private func section(_ title: LocalizedStringResource, _ items: [DecorItem], _ shop: ShopContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title) {
                Text(items.count, format: .number)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ShopGrid(columns: 3) {
                ForEach(items, id: \.self) { item in
                    ShopTile(
                        item: .decor(item), title: item.title, standing: shop.standing(of: item),
                        saleEnds: shop.saleEnds(item), southern: store.southern, now: store.clock, wellAspect: 1
                    ) {
                        DecorPortrait(decor: .item(item), hour: stage.portraitHour).tile(big: typeSize.isAccessibilitySize)
                    } tap: {
                        store.send(.itemTapped(.decor(item)), animation: ShopMotion.cardIn)
                    }
                    .accessibilityIdentifier("Shop.\(item.rawValue)")
                }
            }
        }
    }

    // MARK: Plants and pets

    private func species(_ list: [Species], _ shop: ShopContext) -> some View {
        ShopGrid(columns: 2) {
            ForEach(shelved(list, shop)) { kind in
                SpeciesTile(
                    species: kind, seed: "\(store.homeID.rawValue)-\(store.house.albumCount)",
                    standing: shop.standing(of: kind), southern: store.southern, now: store.clock
                ) {
                    store.send(.itemTapped(.species(kind)), animation: ShopMotion.cardIn)
                }
            }
        }
    }

    /// Pets on their own, then each pack under its name and its one price.
    @ViewBuilder
    private func pets(_ shop: ShopContext) -> some View {
        species(Species.allCases.filter { species in
            guard species.isPet else { return false }
            if case .pack = species.access { return false }
            return true
        }, shop)
        ForEach(SpeciesPack.allCases) { pack in
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(pack.title) { PriceTag(price: pack.price) }
                species(pack.species, shop)
            }
        }
    }
}

/// One shelf's scroll. `-companionScroll 1` scrolls it down and up on its
/// own, as it does Choose, so a shelf can be profiled on a simulator nobody
/// can touch.
private struct ShelfPage<Content: View>: View {
    let content: Content
    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing) { content }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
        }
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        #if DEBUG || MEASURE
        .task { await scrollForever() }
        #endif
    }

    #if DEBUG || MEASURE
    private func scrollForever() async {
        guard UserDefaults.standard.bool(forKey: "companionScroll") else { return }
        var down = true
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 1.8)) { position.scrollTo(edge: down ? .bottom : .top) }
            down.toggle()
        }
    }
    #endif
}

/// Usable first, then for sale, then what can't be had today; the catalog's
/// own order within each.
func shelved(_ species: [Species], _ shop: ShopContext) -> [Species] {
    func rank(_ standing: Standing) -> Int { standing.isUsable ? 0 : standing.price != nil ? 1 : 2 }
    return species.enumerated()
        .sorted { (rank(shop.standing(of: $0.element)), $0.offset) < (rank(shop.standing(of: $1.element)), $1.offset) }
        .map(\.element)
}

/// The shop's springs that aren't the whole app's.
enum ShopMotion {
    /// The card coming up from the bottom: quick, a touch of give.
    static let cardIn = SwiftUI.Animation.spring(duration: 0.32, bounce: 0.18)
}

/// Decor, Plants, Pets: a glass track with the accent thumb sliding between
/// them; the chosen one's icon bounces. Icons drop when a word won't fit
/// ("Minik dostlar").
private struct ShelfSwitch: View {
    @Binding var selection: ShopView.Shelf
    @Namespace private var thumb
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ShopView.Shelf.allCases) { shelf in
                let isOn = selection == shelf
                Button { selection = shelf } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 5) {
                            Image(systemName: symbol(shelf)).bounces(when: isOn)
                            Text(title(shelf))
                        }
                        Text(title(shelf))
                    }
                    .lineLimit(1)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background {
                        if isOn {
                            Capsule().fill(theme.accent).matchedGeometryEffect(id: "thumb", in: thumb)
                        }
                    }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .animation(Motion.spring, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func title(_ shelf: ShopView.Shelf) -> LocalizedStringResource {
        switch shelf {
        case .decor: L10n.shopDecor
        case .plants: L10n.choosePlants
        case .pets: L10n.choosePets
        }
    }

    private func symbol(_ shelf: ShopView.Shelf) -> String {
        switch shelf {
        case .decor: "paintbrush.pointed.fill"
        case .plants: "camera.macro"
        case .pets: "pawprint.fill"
        }
    }
}

// MARK: - Tiles

/// A grid of tiles: as many columns as asked, fewer as the text grows. One
/// glass pass for the lot.
struct ShopGrid<Content: View>: View {
    let columns: Int
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let count = typeSize.isAccessibilitySize ? 1 : typeSize >= .xxLarge ? min(columns, 2) : columns
        GlassGroup(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: count), spacing: 10) {
                content
            }
        }
    }
}

/// A thing in the shop: its window, its name, and its price or how it comes.
/// The art hops when it's tapped; a lock wiggles.
struct ShopTile<Art: View>: View {
    let item: ShopItem
    let title: LocalizedStringResource
    let standing: Standing
    var saleEnds: Date?
    let southern: Bool
    let now: Date
    var wellAspect: CGFloat = 1
    @ViewBuilder let art: Art
    let tap: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            tap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                StageWell(faded: standing.isLocked) {
                    art.modifier(Hop(trigger: taps))
                }
                .aspectRatio(wellAspect, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    Group {
                        if standing == .have { HaveBadge().transition(.scale.combined(with: .opacity)) }
                        else if standing.isLocked { LockBadge(wiggle: taps) }
                    }
                    .padding(5)
                }
                .overlay(alignment: .topLeading) { sale.padding(5) }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                    .padding(.horizontal, 4)
                StandingFoot(item: item, standing: standing, southern: southern, now: now)
                    .padding(.horizontal, 4)
            }
            .padding(6)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .glassCard(cornerRadius: Metrics.cardRadius)
        }
        .buttonStyle(.pressable)
        .animation(Motion.pop, value: standing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(verbatim: spokenStanding(standing, item: item, southern: southern, now: now)))
        .accessibilityAddTraits(.isButton)
    }

    /// On sale while its holiday lasts: the plain last day, never a countdown.
    @ViewBuilder
    private var sale: some View {
        if case .sale = standing, let saleEnds {
            // The clock says "until"; the date alone fits a small tile in
            // every language. VoiceOver hears the whole sentence.
            let day = saleEnds.formatted(Date.FormatStyle().day().month(.abbreviated).locale(L10n.locale))
            Label {
                Text(verbatim: day)
            } icon: {
                Image(systemName: "clock")
            }
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: .capsule)
            .accessibilityLabel(Text(L10n.saleUntil(day)))
        }
    }
}

/// A species: its portrait in its window, in the light of the hour.
struct SpeciesTile: View {
    let species: Species
    let seed: String
    let standing: Standing
    let southern: Bool
    let now: Date
    let tap: () -> Void
    @Environment(\.shopStage) private var stage
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ShopTile(item: .species(species), title: species.title, standing: standing, southern: southern, now: now, wellAspect: 4 / 3) {
            SpeciesPortrait(species: species, seed: seed, hour: stage.portraitHour).tile(big: typeSize.isAccessibilitySize)
        } tap: {
            tap()
        }
        .accessibilityIdentifier("Species.\(species.rawValue)")
    }
}

/// What it costs, or one short line saying how it is had. Only what costs
/// something gets a chip; everything else is a quiet line.
struct StandingFoot: View {
    let item: ShopItem
    let standing: Standing
    let southern: Bool
    let now: Date

    var body: some View {
        Group {
            if let price = standing.price {
                PriceTag(price: price)
            } else if case .freeToday = standing {
                Label {
                    status
                } icon: {
                    Image(systemName: "gift.fill").foregroundStyle(Palette.success)
                }
                .font(.footnote.weight(.semibold))
            } else {
                HStack(spacing: 4) {
                    if let symbol = standing.statusSymbol { Image(systemName: symbol) }
                    status
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .frame(minHeight: 28, alignment: .leading)
    }

    @ViewBuilder
    private var status: some View {
        if let line = standing.status(for: item, southern: southern, now: now) { Text(line) }
    }
}

/// What VoiceOver says after a thing's name: its price in words, or its story.
func spokenStanding(_ standing: Standing, item: ShopItem, southern: Bool, now: Date) -> String {
    if let price = standing.price { return price.spoken }
    return standing.status(for: item, southern: southern, now: now).map { String(localized: $0) } ?? ""
}

/// A companion drawn still, for a tile or a card: its own scene at an hour
/// that matches the window it stands in.
struct SpeciesPortrait: View, Equatable {
    let species: Species
    let seed: String
    var hour = 13
    var mood: Mood = .bright
    /// 0 is the original colours, 1-3 the colours of the finale.
    var colourway = 0
    /// A fixed moment, for a portrait that must not be redrawn by every
    /// re-evaluation of its parent (the default is the hour, today).
    var now: Date?

    var body: some View {
        ScenePortrait(
            companion: Companion(species: species, seed: seed, startedAt: .distantPast), mood: mood,
            now: now ?? Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date(),
            colourway: colourway
        )
        .allowsHitTesting(false)
    }
}

extension SpeciesPortrait {
    /// The kept bitmap this tile's picture is, and the size it is drawn at.
    func still(big: Bool) -> StillSpec {
        let size = big ? CGSize(width: 320, height: 240) : CGSize(width: 160, height: 120)
        return StillSpec(name: "s|\(species.rawValue)|\(seed)|\(hour)|c\(colourway)", size: size, big: big)
    }

    /// The picture as a tile shows it: the kept bitmap once there is one.
    func tile(big: Bool) -> some View { Still(spec: still(big: big)).equatable() }
}

// MARK: - The card

/// The card that asks before anything is bought: the thing in its window,
/// what it costs and what the jar will have left; the Leaves made up with
/// Sparkles; or how many Sparkles more it takes, with the way to get them.
/// Once paid, coins fly from the jar in its header into the thing and it says
/// it's in the house. For what isn't for sale, it says how it comes.
///
/// Glass, snapped to the bottom edge, running on past the home indicator — no
/// strip of the screen showing under it, which a floating half-sheet always
/// leaves.
struct PurchaseCardLayer: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        ZStack(alignment: .bottom) {
            if let card = store.card {
                Palette.dim
                    .ignoresSafeArea()
                    .onTapGesture { store.send(.cardDismissed, animation: Motion.exit) }
                    .transition(.opacity)
                    .accessibilityHidden(true)
                PurchaseCard(store: store, card: card)
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

private struct PurchaseCard: View {
    let store: StoreOf<CompanionFeature>
    let card: CompanionFeature.State.Card

    @Environment(\.shopGeometry) private var geometry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shopStage) private var stage
    @State private var jarFrame: CGRect = .zero
    @State private var artFrame: CGRect = .zero
    /// The coins have landed: the words of the moment may show.
    @State private var landed = false
    @State private var squash = 0
    @State private var fill: Double = 0

    private static let cardShape = UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)

    var body: some View {
        let step = store.state.step(of: card)
        VStack(spacing: 12) {
            header(step)
            art(step)
            words(step)
            content(step)
            buttons(step)
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            Self.cardShape.fill(Palette.cardWash)
                .glassEffect(.regular, in: Self.cardShape)
                .ignoresSafeArea(edges: .bottom)
        }
        // Secondary buttons and symbols in the text's colour: the app's violet
        // is too faint on dark glass.
        .tint(.primary)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onChange(of: card.isBought) { _, bought in
            if bought { pay() } else { landed = false }
        }
        .sensoryFeedback(.success, trigger: landed) { _, now in now }
    }

    // MARK: Header and art

    /// The jar the coins leave from, and the way out.
    private func header(_ step: CompanionFeature.State.CardStep) -> some View {
        HStack {
            if step != .about {
                JarAmounts(leaves: store.house.leaves, sparkles: store.house.sparkles, opensStore: false)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { jarFrame = $0 }
            }
            Spacer()
            IconButton(symbol: "xmark", label: L10n.commonClose) { store.send(.cardDismissed, animation: Motion.exit) }
                .foregroundStyle(.primary)
        }
    }

    private func art(_ step: CompanionFeature.State.CardStep) -> some View {
        let locked = step == .about && store.shop.standing(of: card.item).isLocked
        return StageWell(cornerRadius: Metrics.cardRadius, faded: locked) {
            switch card.item {
            case let .decor(decor):
                DecorPortrait(decor: .item(decor), hour: stage.portraitHour, fallbackSize: 58).equatable()
            case let .species(species):
                SpeciesPortrait(species: species, seed: "\(store.homeID.rawValue)-\(store.house.albumCount)", hour: stage.portraitHour)
            case let .pack(pack):
                if let first = pack.species.first {
                    SpeciesPortrait(species: first, seed: "\(store.homeID.rawValue)-\(store.house.albumCount)", hour: stage.portraitHour)
                }
            }
        }
        .frame(width: 112, height: 112)
        .keyframeAnimator(initialValue: CGSize(width: 1, height: 1), trigger: squash) { content, scale in
            content.scaleEffect(x: scale.width, y: scale.height, anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack(\.width) {
                CubicKeyframe(1.12, duration: 0.08)
                CubicKeyframe(0.94, duration: 0.12)
                SpringKeyframe(1, duration: 0.3, spring: .init(duration: 0.3, bounce: 0.3))
            }
            KeyframeTrack(\.height) {
                CubicKeyframe(0.88, duration: 0.08)
                CubicKeyframe(1.08, duration: 0.12)
                SpringKeyframe(1, duration: 0.3, spring: .init(duration: 0.3, bounce: 0.3))
            }
        }
        .overlay(alignment: .topTrailing) {
            if card.isBought, landed {
                HaveBadge()
                    .font(.title)
                    .offset(x: 8, y: -8)
                    .transition(.symbolEffect(.drawOn).combined(with: .scale))
            } else if locked {
                LockBadge().offset(x: 6, y: -6)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { artFrame = $0 }
        .accessibilityHidden(true)
    }

    private var name: String {
        String(localized: (card.purchase?.item ?? card.item).title)
    }

    // MARK: Words

    @ViewBuilder
    private func words(_ step: CompanionFeature.State.CardStep) -> some View {
        let (heading, line): (LocalizedStringResource, String) = switch step {
        case .pay:
            (L10n.buyConfirmTitle(name), card.purchase?.grow != nil
                ? String(localized: L10n.cardStartsGrowing) : (card.purchase?.item ?? card.item).purpose)
        case let .makeUp(_, short):
            (L10n.buyShortLeavesTitle(short), name)
        case let .short(sparkles):
            (L10n.buyShortTitle, shortSum(sparkles))
        case .bought:
            (L10n.cardHooray, String(localized: L10n.cardNowYours(name)))
        case .about:
            (card.item.title, String(localized: store.shop.standing(of: card.item)
                .explanation(for: card.item, southern: store.southern, now: store.clock)))
        case .notice(.unavailable):
            (L10n.cardUnavailableTitle, String(localized: L10n.cardUnavailableLine))
        case .notice(.offline):
            (L10n.cardOfflineTitle, String(localized: L10n.cardOfflineLine))
        }
        VStack(spacing: 4) {
            Text(heading)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: line)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(step == .bought && !landed ? 0 : 1)
    }

    /// "Kilim is 250 Leaves. The jar has 60 Leaves and 120 Sparkles: 70
    /// Sparkles short." The sum, so nobody has to do it.
    private func shortSum(_ sparkles: Int) -> String {
        guard let price = card.purchase?.price else { return "" }
        let house = store.house
        return switch price {
        case let .leaves(amount):
            String(localized: L10n.cardShortSumLeaves(name, amount, max(house.leaves, 0), max(house.sparkles, 0), sparkles))
        case let .sparkles(amount):
            String(localized: L10n.cardShortSumSparkles(name, amount, max(house.sparkles, 0), sparkles))
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ step: CompanionFeature.State.CardStep) -> some View {
        switch step {
        case let .pay(coins):
            VStack(spacing: 0) {
                row(L10n.cardPrice) { Paying(coins: coins) }
                Divider()
                row(L10n.cardJarAfter) {
                    HStack(spacing: 10) {
                        Amount(.leaves, store.house.leaves - coins.leaves)
                        Amount(.sparkles, store.house.sparkles - coins.sparkles)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .background(Palette.inset, in: .rect(cornerRadius: Metrics.tightRadius, style: .continuous))
        case let .makeUp(coins, _):
            VStack(alignment: .leading, spacing: 10) {
                MakeUpBar(leaves: coins.leaves, sparkles: coins.sparkles, fill: fill)
                    .onAppear { fillUp() }
                HStack(spacing: 6) {
                    Amount(.leaves, coins.leaves).font(.subheadline.weight(.semibold))
                    Text(L10n.cardFromJarAll).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Amount(.sparkles, coins.sparkles).font(.subheadline.weight(.semibold))
                    Text(L10n.cardMakesUp).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(L10n.cardRate).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.inset, in: .rect(cornerRadius: Metrics.tightRadius, style: .continuous))
        case .short:
            let (have, total, currency) = shortProgress
            VStack(spacing: 6) {
                ProgressView(value: Double(have) * fill, total: Double(max(total, 1)))
                    .tint(currency == .leaves ? Palette.leaf : Palette.sparkle)
                    .onAppear { fillUp() }
                Text(L10n.cardOf(have, total))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        case .bought, .about, .notice:
            EmptyView()
        }
    }

    private func row<Value: View>(_ label: LocalizedStringResource, @ViewBuilder value: () -> Value) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            value().fontWeight(.semibold)
        }
        .font(.system(.body, design: .rounded))
        .frame(minHeight: 44)
    }

    /// What the jar has toward the price, in the price's terms: Leaves and
    /// Sparkles both count toward Leaves, one for one.
    private var shortProgress: (Int, Int, Amount.Currency) {
        guard let price = card.purchase?.price else { return (0, 0, .leaves) }
        let house = store.house
        return switch price {
        case let .leaves(amount): (min(max(house.leaves, 0) + max(house.sparkles, 0), amount), amount, .leaves)
        case let .sparkles(amount): (min(max(house.sparkles, 0), amount), amount, .sparkles)
        }
    }

    private func fillUp() {
        fill = 0
        withAnimation(reduceMotion ? nil : Motion.settle.delay(0.12)) { fill = 1 }
    }

    // MARK: Buttons

    @ViewBuilder
    private func buttons(_ step: CompanionFeature.State.CardStep) -> some View {
        switch step {
        case let .pay(coins):
            Button { store.send(.cardBuyTapped, animation: Motion.spring) } label: {
                HStack(spacing: 8) {
                    Text(L10n.cardBuy)
                    Text(verbatim: "·")
                    Paying(coins: coins, plain: true)
                }
            }
            .buttonStyle(.depth)
            .accessibilityLabel(Text(verbatim: "\(String(localized: L10n.cardBuy)), \(spoken(coins))"))
            .accessibilityIdentifier("CardBuy")
            Text(L10n.cardFromJar)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case let .makeUp(coins, _):
            Button { store.send(.cardBuyTapped, animation: Motion.spring) } label: {
                HStack(spacing: 8) {
                    Text(L10n.cardPay)
                    Text(verbatim: "·")
                    Paying(coins: coins, plain: true)
                }
            }
            .buttonStyle(.depth)
            .accessibilityLabel(Text(verbatim: "\(String(localized: L10n.cardPay)), \(spoken(coins))"))
            .accessibilityIdentifier("CardBuy")
            SecondaryButton(L10n.cardSaveUp) { store.send(.cardDismissed, animation: Motion.exit) }
        case .short:
            PrimaryButton(L10n.cardSeePacks, symbol: "sparkle") { store.send(.cardStoreTapped) }
                .accessibilityIdentifier("CardSeePacks")
        case .bought:
            if card.purchase?.grow == nil {
                Group {
                    if case .decor = card.item {
                        PrimaryButton(L10n.cardPutOut, symbol: "paintbrush.pointed.fill") {
                            store.send(.cardPutOutTapped, animation: Motion.exit)
                        }
                        SecondaryButton(L10n.cardKeepShopping) { store.send(.cardDismissed, animation: Motion.exit) }
                    } else {
                        PrimaryButton(L10n.commonDone) { store.send(.cardDismissed, animation: Motion.exit) }
                    }
                }
                .opacity(landed ? 1 : 0)
            }
        case .notice(.unavailable):
            PrimaryButton(L10n.commonDone) { store.send(.cardDismissed, animation: Motion.exit) }
        case .notice(.offline):
            // The same purchase again: the tap keeps its request id, so if the
            // first one did get through the house is not charged twice.
            PrimaryButton(L10n.commonRetry) { store.send(.cardBuyTapped, animation: Motion.spring) }
                .accessibilityIdentifier("CardRetry")
            SecondaryButton(L10n.commonCancel) { store.send(.cardDismissed, animation: Motion.exit) }
        case .about:
            let standing = store.shop.standing(of: card.item)
            if case .decor = card.item, standing.isUsable, store.sheet != .decorate {
                PrimaryButton(L10n.cardPutOut, symbol: "paintbrush.pointed.fill") {
                    store.send(.cardPutOutTapped, animation: Motion.exit)
                }
            }
        }
    }

    private func spoken(_ coins: Coins) -> String {
        [coins.leaves > 0 ? Price.leaves(coins.leaves).spoken : nil, coins.sparkles > 0 ? Price.sparkles(coins.sparkles).spoken : nil]
            .compactMap { $0 }
            .formatted(.list(type: .and).locale(L10n.locale))
    }

    // MARK: Paying

    /// The coins leave the jar for the thing; it squashes as they land, and
    /// only then does the card say it's in the house.
    private func pay() {
        guard !reduceMotion else {
            withAnimation(Motion.fade) { landed = true }
            return
        }
        geometry.launch(coinsPaid, from: jarFrame, to: artFrame)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            // The server can take the purchase back while the coins fly.
            guard store.card?.isBought == true else { return }
            squash += 1
            try? await Task.sleep(for: .seconds(0.12))
            guard store.card?.isBought == true else { return }
            withAnimation(Motion.pop) { landed = true }
        }
    }

    /// Three coins, in the mix that was paid.
    private var coinsPaid: [Amount.Currency] {
        guard let paid = card.paid else { return [] }
        if paid.leaves > 0, paid.sparkles > 0 { return [.leaves, .leaves, .sparkles] }
        return Array(repeating: paid.leaves > 0 ? .leaves : .sparkles, count: 3)
    }
}

/// The amounts being paid, one currency or both.
private struct Paying: View {
    let coins: Coins
    var plain = false

    var body: some View {
        HStack(spacing: 6) {
            if coins.leaves > 0 { Amount(.leaves, coins.leaves, plain: plain) }
            if coins.leaves > 0, coins.sparkles > 0 { Text(verbatim: "+") }
            if coins.sparkles > 0 || coins.leaves == 0 { Amount(.sparkles, coins.sparkles, plain: plain) }
        }
    }
}

/// The price as a bar: the Leaves the jar has, then the Sparkles that make
/// up the rest.
private struct MakeUpBar: View {
    let leaves: Int
    let sparkles: Int
    var fill: Double = 1

    var body: some View {
        GeometryReader { proxy in
            let total = CGFloat(max(leaves + sparkles, 1))
            HStack(spacing: 2) {
                Capsule().fill(Palette.leaf)
                    .frame(width: max(proxy.size.width * CGFloat(leaves) / total * fill - 1, 0))
                Capsule().fill(Palette.sparkle)
                    .frame(width: max(proxy.size.width * CGFloat(sparkles) / total * fill - 1, 0))
                Spacer(minLength: 0)
            }
        }
        .frame(height: 6)
        .background(Palette.inset, in: .capsule)
        .accessibilityHidden(true)
    }
}

// MARK: - The Sparkles store

/// The Sparkles store as its own full screen: its counter pinned at the top,
/// so the Sparkles landing in it are seen however far down the packs the
/// house scrolled, and its own layer for them to fly in.
struct SparkleStoreScreen: View {
    let store: StoreOf<CompanionFeature>
    let stage: ShopStage
    @State private var geometry = ShopGeometry()

    var body: some View {
        NavigationStack {
            SparkleStoreView(store: store)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) { store.send(.storeDismissed) }
                            .tint(.primary)
                    }
                }
        }
        .overlay { CoinFlightLayer(geometry: geometry) }
        .environment(\.shopGeometry, geometry)
        .environment(\.shopStage, stage)
    }
}

/// The packs of Sparkles. Sent from something being bought, it says how many
/// more that needs and marks the smallest pack that covers it — a fact, not a
/// nudge; the one pack that is cheapest per Sparkle says so too. A bought
/// pack's Sparkles fly into the counter and it rolls up, every time; with
/// enough, it goes back to the card, which already says so.
struct SparkleStoreView: View {
    let store: StoreOf<CompanionFeature>

    @Environment(\.shopGeometry) private var geometry
    @Environment(\.shopStage) private var stage
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var counterFrame: CGRect = .zero
    @State private var packFrames: [SparklePack.ID: CGRect] = [:]
    @State private var lastTapped: SparklePack.ID?
    @State private var arrivals = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.sectionSpacing) {
                goal
                packs
                VStack(spacing: 10) {
                    Text(L10n.storeNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if SparkleStoreClient.isTestStore {
                        Text(L10n.storeTest)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Palette.inset, in: .capsule)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .top) { counter }
        .background(Backdrop(tint: theme.accent))
        .navigationTitle(Text(L10n.shopAddSparkles))
        .navigationBarTitleDisplayMode(.inline)
        .task { store.send(.storeAppeared) }
        // Every arrival, the same pack twice included: the count of them
        // changes even when the amount doesn't.
        .onChange(of: store.landedTick) { _, _ in
            guard !reduceMotion, let id = lastTapped, let from = packFrames[id] else {
                arrivals += 1
                return
            }
            geometry.launch(Array(repeating: .sparkles, count: 6), from: from, to: counterFrame, stagger: 0.06)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                arrivals += 1
            }
        }
        .sensoryFeedback(.success, trigger: arrivals)
    }

    /// The jar's Sparkles, always in view.
    private var counter: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: Amount.Currency.sparkles.symbol)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Palette.sparkle)
                    .symbolColorRenderingMode(.gradient)
                    .symbolEffect(.bounce.up.byLayer, value: arrivals)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { counterFrame = $0 }
                Text(store.house.sparkles, format: .number)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(store.house.sparkles)))
                    .animation(reduceMotion ? Motion.fade : Motion.settle.delay(0.35), value: store.house.sparkles)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            Text(L10n.storeHero)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // A line kept for "+300 in the jar", so nothing moves when it comes.
            ZStack {
                if let landed = store.landed {
                    Text(L10n.storeLanded(landed))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.sparkle)
                        .id(store.landedTick)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .frame(height: 20)
            .animation(reduceMotion ? Motion.fade : Motion.arrive.delay(0.45), value: store.landedTick)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityShowsLargeContentViewer()
    }

    private func isShort(_ price: Price) -> Bool {
        if case .short = store.house.checkout(price) { return true }
        return false
    }

    /// What the house came here for: how many more it needs, filling with
    /// every pack bought toward it — then that it's enough.
    @ViewBuilder
    private var goal: some View {
        if let pending = store.pending, let price = pending.price {
            let short: Int = if case let .short(more) = store.house.checkout(price) { more } else { 0 }
            HStack(spacing: 12) {
                StageWell(cornerRadius: 12, shadow: false) {
                    pendingArt(pending.item)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 8) {
                    Text(short > 0
                         ? L10n.storeGoal(String(localized: pending.item.title), short)
                         : L10n.storeEnoughNow(String(localized: pending.item.title)))
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText(value: Double(short)))
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: Double(price.amount - short), total: Double(max(price.amount, 1)))
                        .tint(Palette.sparkle)
                }
            }
            .padding(14)
            .glassCard()
            .animation(reduceMotion ? Motion.fade : Motion.settle.delay(0.35), value: short)
        }
    }

    /// What the house came for, in its small window: the drawing, or its emoji.
    @ViewBuilder
    private func pendingArt(_ item: ShopItem) -> some View {
        switch item {
        case let .decor(decor): DecorPortrait(decor: .item(decor), hour: stage.portraitHour, fallbackSize: 26).equatable()
        case let .species(species): SpeciesPortrait(species: species, seed: "store", hour: stage.portraitHour).equatable()
        case let .pack(pack):
            if let first = pack.species.first { SpeciesPortrait(species: first, seed: "store", hour: stage.portraitHour).equatable() }
        }
    }

    /// The smallest pack that covers what the house is short, if it came here
    /// for something.
    private var enoughPack: SparklePack.ID? {
        guard let pending = store.pending, let price = pending.price, case let .short(more) = store.house.checkout(price) else { return nil }
        return store.packs.first { $0.sparkles >= more }?.id
    }

    private var packs: some View {
        let best = SparklePack.bestValue(store.packs)
        return VStack(spacing: 0) {
            if store.packs.isEmpty {
                unpriced
            } else {
                ForEach(Array(store.packs.enumerated()), id: \.element.id) { index, pack in
                    if index > 0 { Divider().padding(.leading, 70) }
                    row(pack, size: index, isBest: best == pack.id)
                }
            }
        }
        .glassCard()
    }

    /// The store has not priced the packs yet, or cannot be reached.
    @ViewBuilder
    private var unpriced: some View {
        if store.packsUnavailable {
            VStack(spacing: 12) {
                Text(L10n.storeUnavailable)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SecondaryButton(L10n.storeRetry, symbol: "arrow.clockwise") { store.send(.storeAppeared) }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private func row(_ pack: SparklePack, size: Int, isBest: Bool) -> some View {
        let isBuying = store.buyingPack == pack.id
        let note = store.packNote?.id == pack.id ? store.packNote : nil
        let glyphs: [Font] = [.body, .title3, .title2, .title]
        return HStack(spacing: 12) {
            // Bigger packs, a bigger sparkle: size shown, never shouted.
            Image(systemName: Amount.Currency.sparkles.symbol)
                .font(glyphs[min(size, 3)].weight(.semibold))
                .foregroundStyle(Palette.sparkle)
                .symbolColorRenderingMode(.gradient)
                .frame(width: 44, height: 44)
                .background(Palette.sparkleWash, in: .circle)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { packFrames[pack.id] = $0 }
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.sparkles, format: .number)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Text(L10n.storePackUnit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if isBest || enoughPack == pack.id {
                    FlowLayout(spacing: 6) {
                        if isBest {
                            Text(L10n.storeBestValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(theme.accent, in: .capsule)
                        }
                        if enoughPack == pack.id, let pending = store.pending {
                            Label {
                                Text(L10n.storeEnoughFor(String(localized: pending.item.title)))
                            } icon: {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Palette.inset, in: .capsule)
                        }
                    }
                    .padding(.top, 2)
                }
                if let note {
                    Label {
                        switch note.kind {
                        case .waiting: Text(L10n.storeWaiting)
                        case .failed: Text(L10n.storeDidnt)
                        case .unverified: Text(L10n.storeUnverified)
                        case .retrying: Text(L10n.storeRetrying)
                        }
                    } icon: {
                        Image(systemName: note.kind == .failed || note.kind == .unverified ? "exclamationmark.circle" : "clock")
                    }
                    .font(.footnote)
                    .foregroundStyle(note.kind == .failed || note.kind == .unverified ? Palette.danger : Color.secondary)
                }
            }
            Spacer(minLength: 8)
            Button {
                lastTapped = pack.id
                store.send(.packTapped(pack))
            } label: {
                ZStack {
                    // Holds the button's width while it waits.
                    priceLabel(pack).opacity(isBuying ? 0 : 1)
                    if isBuying { ProgressView().tint(.white) }
                }
            }
            .buttonStyle(.depthCompact)
            // The pack being bought keeps its colour under its spinner; the
            // others wait their turn.
            .disabled(store.buyingPack != nil && !isBuying)
            .allowsHitTesting(!isBuying)
            .shake(on: note.map { $0.kind == .failed || $0.kind == .unverified ? 1 : 0 } ?? 0)
            .accessibilityLabel(Text(verbatim: "\(Price.sparkles(pack.sparkles).spoken), \(pack.displayPrice ?? String(localized: L10n.storeTestPrice))\(isBest ? ", \(String(localized: L10n.storeBestValue))" : "")"))
            .accessibilityIdentifier("Pack.\(pack.sparkles)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .opacity(store.buyingPack != nil && !isBuying ? 0.5 : 1)
        .animation(Motion.fade, value: store.buyingPack)
    }

    @ViewBuilder
    private func priceLabel(_ pack: SparklePack) -> some View {
        if let price = pack.displayPrice {
            Text(verbatim: price).monospacedDigit()
        } else {
            Text(L10n.storeTestPrice)
        }
    }
}
