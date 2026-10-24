import ComposableArchitecture
import SwiftUI

/// The companion on Today.
///
/// On a normal day it is a card: the scene, its name and how it is doing, a
/// little bar to the next stage, and the ways into decorating, the album and
/// the house's holidays. When something in the house is wrong, Today puts that
/// first and the companion shrinks to one line — it is the thing that fills a
/// quiet day, not the thing that competes with a leak.
struct CompanionCard: View {
    @Bindable var store: StoreOf<CompanionFeature>
    var compact = false

    @Environment(\.theme) private var theme
    @State private var detent = PresentationDetent.medium
    /// Icons differ in height, and the labels under them have to share a
    /// line: "Holidays" sat higher than the rest under its shorter calendar.
    @ScaledMetric(relativeTo: .body) private var actionIcon = 24.0

    var body: some View {
        Group {
            // Not before the house has answered: a house that has a companion
            // must never be offered a new one while its own is on its way.
            if store.isLoaded {
                if store.isUnreadable {
                    unreadable
                } else if store.hasCompanion {
                    if compact { strip() } else { card() }
                } else {
                    invitation
                }
            }
        }
        .transition(.opacity)
        .animation(Motion.fade, value: store.isLoaded)
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: Binding(
            get: { store.sheet?.isMoment == true ? nil : store.sheet },
            set: { if $0 == nil { store.send(.sheetDismissed) } }
        )) { sheet in
            // A plain sheet: a zoom out of the jar could be pulled closed from
            // anywhere, and a shop full of scrolling closed under the finger.
            CompanionSheet(store: store, sheet: sheet, detent: $detent)
        }
        .onChange(of: store.sheet == nil) { _, closed in if closed { detent = .medium } }
        .fullScreenCover(isPresented: Binding(
            get: { store.sheet?.isMoment == true },
            set: { if !$0 { store.send(.sheetDismissed) } }
        )) {
            if store.sheet == .welcome {
                WelcomeGiftView(store: store)
            } else {
                CeremonyView(store: store)
            }
        }
        #if DEBUG || MEASURE
        .task { await demo() }
        #endif
    }

    #if DEBUG || MEASURE
    /// Development builds can be driven from the command line, for
    /// screenshots of states that otherwise need a finger:
    /// `simctl launch … -companionDemo care` (or decorate, album, holidays,
    /// lab, choose, pick, celebrate, dress, shop, store, buy, makeup, short,
    /// topup, pay, info).
    private func demo() async {
        guard !compact, let demo = UserDefaults.standard.string(forKey: "companionDemo") else { return }
        try? await Task.sleep(for: .seconds(2.5))
        switch demo {
        case "care": store.send(.careTapped)
        case "waterspam":
            // Water tapped over and over, the way a person does when it's fun.
            for _ in 0..<12 {
                store.send(.careTapped)
                try? await Task.sleep(for: .milliseconds(120))
            }
        case "decorate":
            store.send(.decorateTapped)
            if let spot = UserDefaults.standard.string(forKey: "companionSpot").flatMap(Spot.init(rawValue:)) {
                store.send(.spotPicked(spot))
            }
        case "album": store.send(.albumTapped)
        case "holidays": store.send(.holidaysTapped)
        case "lab": store.send(.labTapped)
        case "grow": store.send(.labPoints(12))
        case "labgrow":
            // With the lab open at half height, the card must still play it.
            store.send(.labTapped)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.labPoints(12))
        case "choose": store.send(.chooseTapped)
        case "pick":
            // Choose again and grow it in the Lab: with the old seed kept, this
            // once left the previous species' tree on screen.
            store.send(.chose(.magnolia))
            store.send(.labPoints(60))
        case "celebrate": store.send(.celebrateTapped)
        case "shop": store.send(.shopTapped)
        case "store":
            store.send(.shopTapped)
            try? await Task.sleep(for: .seconds(1))
            store.send(.storeTapped)
        case "buy", "makeup", "short", "topup":
            // The card before buying the kilim (250 Leaves): with the jar as
            // it is, with 60 Leaves and Sparkles to make up the rest, or with
            // 60 Leaves and none — and then off to the store and back.
            store.send(.decorateTapped)
            store.send(.spotPicked(.ground))
            if demo != "buy" {
                let sparkles = demo == "makeup" ? 300 : 0
                store.send(.labCoins(Coins(leaves: 60 - store.house.leaves, sparkles: sparkles - store.house.sparkles)))
            }
            try? await Task.sleep(for: .seconds(1))
            store.send(.itemTapped(.decor(.kilim)), animation: ShopMotion.cardIn)
            guard demo == "topup" else { return }
            try? await Task.sleep(for: .seconds(2.5))
            store.send(.cardStoreTapped)
            try? await Task.sleep(for: .seconds(2.5))
            if let pack = store.packs.first { store.send(.packTapped(pack)) }
        case "pay":
            // Bought: the coins fly from the jar, the card says it's in.
            store.send(.shopTapped)
            try? await Task.sleep(for: .seconds(1.2))
            store.send(.itemTapped(.decor(.bow)), animation: ShopMotion.cardIn)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.cardBuyTapped, animation: Motion.spring)
        case "info":
            store.send(.shopTapped)
            try? await Task.sleep(for: .seconds(1.2))
            store.send(.itemTapped(.species(.hedgehog)), animation: ShopMotion.cardIn)
        default: break
        }
    }
    #endif

    // MARK: - The card
    //
    // The card is drawn from small views that each read only what they draw
    // (`jar`, `look`, `progress`…), so a delivery that moves the points does
    // not redraw the jar and one that moves the jar does not redraw the scene.
    // This body reads only whether there is a companion, and the sheet.

    private func card() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                CardScene(store: store, compact: false, covered: isCovered)
                    .frame(height: 236)
                HStack(alignment: .top) {
                    HolidayChip(store: store)
                    Spacer(minLength: 8)
                    CareButton(store: store, small: false)
                }
                .padding(10)
                #if DEBUG
                PointsStepper(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(10)
                #endif
            }
            .clipShape(.rect(topLeadingRadius: Metrics.cardRadius, topTrailingRadius: Metrics.cardRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    CardTitle(store: store, font: .headline, detail: .footnote)
                    Spacer(minLength: 0)
                    CardJar(store: store, covered: isCovered)
                }
                CardProgress(store: store)
                actions
            }
            .padding(14)
        }
        .glassCard()
        .accessibilityIdentifier("Companion")
    }

    /// Whether a sheet hides the card. Half up — the lab's usual height — it
    /// does not, and the card has to keep playing what the sheet changes:
    /// held still under every sheet, points added in the lab grew the tree
    /// with nobody watching and it jumped when the sheet closed.
    private var isCovered: Bool {
        guard let sheet = store.sheet else { return false }
        return sheet == .decorate || sheet == .shop || sheet.isMoment || detent == .large
    }

    /// Equal tiles, the icon over a one-line label, so a long word in one
    /// language ("Özel günler") never wraps or pushes the others aside.
    private var actions: some View {
        HStack(spacing: 4) {
            action(L10n.companionDecorate, "paintbrush.pointed.fill") { store.send(.decorateTapped) }
            action(L10n.companionAlbum, "book.closed.fill") { store.send(.albumTapped) }
            action(L10n.companionHolidays, "calendar") { store.send(.holidaysTapped) }
            if CompanionFlag.isEnabled {
                action(L10n.companionLab, "flask.fill") { store.send(.labTapped) }
            }
        }
    }

    private func action(_ title: LocalizedStringResource, _ symbol: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(height: actionIcon)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .oneLine()
            }
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }

    // MARK: - A busy day

    private func strip() -> some View {
        HStack(spacing: 12) {
            CardScene(store: store, compact: true, covered: isCovered)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            CardTitle(store: store, font: .subheadline.weight(.semibold), detail: .caption)
            Spacer(minLength: 0)
            StripAction(store: store)
        }
        .padding(8)
        .glassCard()
    }

    // MARK: - Nothing growing yet

    private var invitation: some View {
        let first = store.house.albumCount == 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(verbatim: first ? "🌱" : "🌼")
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(first ? L10n.companionMeetTitle(String(localized: L10n.companionBrand)) : L10n.companionNextTitle)
                        .font(.headline)
                        .oneLine()
                    Text(first ? L10n.companionMeetBody : L10n.companionNextBody)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .oneLine()
                }
            }
            Button { store.send(.chooseTapped) } label: {
                Text(L10n.companionChoose)
                    .font(.subheadline.weight(.semibold))
                    .oneLine()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(theme.accent)
            .accessibilityIdentifier("CompanionChoose")
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// The last delivery could not be read, so there is no honest card to
    /// draw: a house that has a companion must not be offered a new one.
    private var unreadable: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            Text(L10n.companionUnreadable)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .oneLine()
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityIdentifier("CompanionUnreadable")
    }
}

// MARK: - The card's parts

/// The scene: the plant or pet, its sky and what is put out. Reads what it
/// draws and nothing else.
private struct CardScene: View {
    let store: StoreOf<CompanionFeature>
    let compact: Bool
    let covered: Bool

    var body: some View {
        if let look = store.look {
            CompanionScene(
                companion: look, progress: store.progress, mood: store.mood, stage: store.stage,
                layout: store.visibleLayout, southern: store.southern, now: store.clock,
                choreTick: store.choreTick, careTick: store.careTick, compact: compact, paused: covered
            )
            .accessibilityElement()
            .accessibilityLabel(Text(L10n.companionSceneLabel(
                String(localized: look.species.title),
                String(localized: stageTitle),
                Int((store.progress * 100).rounded()),
                String(localized: store.mood.title(isPet: store.isPet))
            )))
            .accessibilityHint(Text(L10n.companionSceneHint))
        }
    }

    private var stageTitle: LocalizedStringResource {
        CompanionMath.stageTitle(store.stage, isPet: store.isPet, isReady: store.isReady)
    }
}

/// "Magnolia", and under it "Sapling · thirsty · day 4".
private struct CardTitle: View {
    let store: StoreOf<CompanionFeature>
    let font: Font
    let detail: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let species = store.species {
                Text(species.title)
                    .font(font)
                    .oneLine()
            }
            Text(subtitle)
                .font(detail)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .oneLine()
        }
    }

    private var subtitle: String {
        [String(localized: CompanionMath.stageTitle(store.stage, isPet: store.isPet, isReady: store.isReady)),
         String(localized: store.mood.title(isPet: store.isPet)),
         String(localized: L10n.companionDay(store.day))].joined(separator: " · ")
    }
}

/// The little bar to the next stage, or the way to the ceremony.
private struct CardProgress: View {
    let store: StoreOf<CompanionFeature>
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if store.isReady {
                Button { store.send(.celebrateTapped) } label: {
                    Label { Text(L10n.companionCelebrate).oneLine() } icon: { Image(systemName: "party.popper.fill") }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(theme.accent)
                .accessibilityIdentifier("CompanionCelebrate")
            } else {
                bar
            }
        }
        .animation(Motion.spring, value: store.isReady)
    }

    private var bar: some View {
        let isPet = store.isPet
        let share = CompanionMath.nextStageShare(progress: store.progress, isPet: isPet)
        let next = min(store.stage + 1, CompanionMath.stageCount(isPet: isPet))
        return VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.inset)
                    Capsule().fill(theme.accent)
                        .frame(width: max(8, geometry.size.width * share))
                }
            }
            .frame(height: 6)
            .animation(Motion.arrive, value: share)
            Text(caption(next: next, isPet: isPet))
                .font(.caption)
                .foregroundStyle(.secondary)
                .oneLine()
        }
        .accessibilityElement(children: .combine)
    }

    /// What comes next — or, when the points are all there and only the days
    /// are not, when it will be ready (the server's `readyAt`).
    private func caption(next: Int, isPet: Bool) -> LocalizedStringResource {
        if let current = store.current, current.pointsReady, !current.isReady, let readyAt = current.readyAt {
            return L10n.companionReadyOn(readyAt.formatted(Date.FormatStyle().day().month(.abbreviated).locale(L10n.locale)))
        }
        return L10n.companionNext(String(localized: CompanionMath.stageTitle(
            next, isPet: isPet, isReady: next >= CompanionMath.stageCount(isPet: isPet)
        )))
    }
}

/// The house jar — Leaves and Sparkles side by side — with a "+10" that
/// drops into it when it is paid. It opens the shop.
private struct CardJar: View {
    let store: StoreOf<CompanionFeature>
    let covered: Bool

    var body: some View {
        let jar = store.jar
        Button { store.send(.shopTapped) } label: {
            JarAmounts(leaves: jar.leaves, sparkles: jar.sparkles, opensStore: false)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .glassControl()
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            // Under a sheet nobody would see it land; it waits for nothing.
            if let pay = store.lastPay, !covered {
                payment(pay.coins)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Palette.success)
                    .fixedSize()
                    .phaseAnimator([0, 1, 2], trigger: pay.id) { content, phase in
                        // Earnings drop into the jar: they show above it, then
                        // fall in. Rising away from it read as money leaving.
                        content
                            .offset(y: phase == 2 ? 0 : -24)
                            .opacity(phase == 1 ? 1 : 0)
                    } animation: { phase in
                        switch phase {
                        case 1: .easeOut(duration: 0.2)
                        case 2: .spring(duration: 0.35, bounce: 0).delay(0.4)
                        default: nil
                        }
                    }
                    .allowsHitTesting(false)
            }
        }
        .animation(Motion.spring, value: jar.leaves)
        .animation(Motion.spring, value: jar.sparkles)
        .accessibilityLabel(Text(L10n.companionJar))
        .accessibilityValue(Text(L10n.companionJarBoth(jar.leaves, jar.sparkles)))
        .accessibilityIdentifier("CardJar")
    }

    /// "+10 [leaf]  +5 [sparkle]", leaving out a currency that wasn't paid: a
    /// top-up of Sparkles is not "+0" Leaves.
    private func payment(_ coins: Coins) -> some View {
        HStack(spacing: 8) {
            if coins.leaves != 0 {
                HStack(spacing: 2) { Text(L10n.companionPay(coins.leaves)); Image(systemName: Amount.Currency.leaves.symbol).foregroundStyle(Palette.leaf) }
            }
            if coins.sparkles != 0 {
                HStack(spacing: 2) { Text(L10n.companionPay(coins.sparkles)); Image(systemName: Amount.Currency.sparkles.symbol).foregroundStyle(Palette.sparkle) }
            }
        }
    }
}

/// Today's holiday: an offer to put its things out, or just its name once
/// they are.
private struct HolidayChip: View {
    let store: StoreOf<CompanionFeature>
    @Environment(\.theme) private var theme

    var body: some View {
        if let holiday = store.holidayToDress {
            Button { store.send(.dressTapped(holiday.id), animation: Motion.celebrate) } label: {
                HStack(spacing: 6) {
                    Text(verbatim: "\(holiday.symbol) \(String(localized: holiday.id.title))")
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(L10n.companionDecorate)
                        .foregroundStyle(theme.accent)
                        .fixedSize()
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassControl()
            }
            .buttonStyle(.plain)
        } else if let holiday = store.activeHolidays.first {
            Text(verbatim: "\(holiday.symbol) \(String(localized: holiday.id.title))")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassControl()
        }
    }
}

/// Water for a plant, a pet for a pet. Counts once a day per person; every
/// tap still gets a reaction.
/// Every tap answers: the drop (or heart) bounces, a little one rises out
/// of the button, and the tap is felt a touch harder the more of them come
/// in a row. Today's care, once given, is a small check drawn on the
/// glyph — the glyph itself stays, so the button keeps answering.
private struct CareButton: View {
    let store: StoreOf<CompanionFeature>
    let small: Bool

    @Environment(\.theme) private var theme
    /// Taps on Water in a row, for a reaction that grows with them.
    @State private var careCombo = 0
    @State private var lastCare = Date.distantPast

    var body: some View {
        let isPet = store.isPet
        let symbol = isPet ? "heart.fill" : "drop.fill"
        let cared = store.caredToday
        Button {
            let now = Date()
            careCombo = now.timeIntervalSince(lastCare) < 1.2 ? careCombo + 1 : 1
            lastCare = now
            store.send(.careTapped)
        } label: {
            Label {
                Text(isPet ? L10n.companionPet : L10n.companionWater)
                    .fixedSize()
            } icon: {
                Image(systemName: symbol)
                    .symbolEffect(.bounce.down.byLayer, value: store.careTick)
                    .overlay(alignment: .bottomTrailing) {
                        if cared {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: small ? 8 : 10, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Palette.success)
                                .offset(x: 4, y: 3)
                                .transition(.symbolEffect(.drawOn))
                        }
                    }
            }
            .font((small ? Font.caption : .subheadline).weight(.semibold))
            .padding(.horizontal, small ? 10 : 12)
            .padding(.vertical, small ? 6 : 8)
            .glassControl(tinted: cared ? nil : theme.accent.opacity(0.35))
            .overlay(alignment: .top) { CareRise(symbol: symbol, tick: store.careTick) }
            .animation(Motion.pop, value: cared)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.92))
        .sensoryFeedback(.impact(weight: .light, intensity: min(0.5 + 0.12 * Double(careCombo), 1)), trigger: store.careTick)
        .accessibilityHint(Text(L10n.companionCareHint))
        .accessibilityIdentifier("CompanionCare")
    }
}

/// The strip's one button: Water, or the ceremony once it is ready.
private struct StripAction: View {
    let store: StoreOf<CompanionFeature>
    @Environment(\.theme) private var theme

    var body: some View {
        if store.isReady {
            Button { store.send(.celebrateTapped) } label: {
                Image(systemName: "party.popper.fill")
                    .padding(8)
                    .glassControl(tinted: theme.accent.opacity(0.35))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L10n.companionCelebrate))
        } else {
            CareButton(store: store, small: true)
        }
    }
}

#if DEBUG
/// Development builds: points off and on right under the tree, to watch it
/// shrink and grow through its stages without a sheet in the way. A stage
/// is about eleven points; this steps four at a time. A local preview, like
/// the whole Lab: the points are laid over the server's count on this phone
/// and are never sent.
private struct PointsStepper: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        HStack(spacing: 2) {
            Button { store.send(.labPoints(-4)) } label: {
                Image(systemName: "minus").frame(width: 30, height: 26)
            }
            .accessibilityLabel(Text(L10n.labPointsLess(4)))
            Text(verbatim: "\(Int(store.points.rounded())) / \(Int(CompanionMath.graduateAt))")
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Motion.spring, value: Int(store.points.rounded()))
            Button { store.send(.labPoints(4)) } label: {
                Image(systemName: "plus").frame(width: 30, height: 26)
            }
            .accessibilityLabel(Text(L10n.labPoints(4)))
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .glassControl()
        .accessibilityIdentifier("CompanionPoints")
    }
}
#endif

/// A little drop (or heart) rising out of the Water button with each tap and
/// fading as it goes. One per tap; never under Reduce Motion.
private struct CareRise: View {
    let symbol: String
    let tick: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion, tick > 0 {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(symbol == "drop.fill" ? SceneInk.water : SceneInk.heart)
                .phaseAnimator([0.0, 1.0], trigger: tick) { content, phase in
                    content
                        .offset(y: -18 * phase)
                        .opacity(phase == 0 ? 0 : 1 - phase * 0.9)
                        .scaleEffect(1 - 0.3 * phase)
                } animation: { phase in
                    phase == 1 ? .easeOut(duration: 0.6) : nil
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
