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
            if let current = store.current {
                if compact { strip(current) } else { card(current) }
            } else {
                invitation
            }
        }
        .sheet(item: Binding(
            get: { store.sheet?.isMoment == true ? nil : store.sheet },
            set: { if $0 == nil { store.send(.sheetDismissed) } }
        )) { sheet in
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
        #if DEBUG
        .task { await demo() }
        #endif
    }

    #if DEBUG
    /// Development builds can be driven from the command line, for
    /// screenshots of states that otherwise need a finger:
    /// `simctl launch … -companionDemo care` (or decorate, album, holidays,
    /// lab, choose, pick, celebrate, dress).
    private func demo() async {
        guard !compact, let demo = UserDefaults.standard.string(forKey: "companionDemo") else { return }
        try? await Task.sleep(for: .seconds(2.5))
        switch demo {
        case "care": store.send(.careTapped)
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
        case "dress": if let holiday = store.holidayToDress { store.send(.dressTapped(holiday.id)) }
        default: break
        }
    }
    #endif

    // MARK: - The card

    private func card(_ current: Companion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                scene(current)
                    .frame(height: 236)
                HStack(alignment: .top) {
                    holidayChip
                    Spacer(minLength: 8)
                    careButton(current)
                }
                .padding(10)
                #if DEBUG
                pointsStepper
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(10)
                #endif
            }
            .clipShape(.rect(topLeadingRadius: Metrics.cardRadius, topTrailingRadius: Metrics.cardRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.species.title)
                            .font(.headline)
                            .oneLine()
                        Text(subtitle(current))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .oneLine()
                    }
                    Spacer(minLength: 0)
                    jar
                }
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
                    progressBar
                }
                actions
            }
            .padding(14)
        }
        .glassCard()
        .animation(Motion.spring, value: store.isReady)
        .accessibilityIdentifier("Companion")
    }

    private func scene(_ current: Companion, compact: Bool = false) -> some View {
        CompanionScene(
            companion: current, progress: store.progress, mood: store.mood, stage: store.stage,
            layout: store.visibleLayout, southern: store.southern, now: store.clock,
            choreTick: store.choreTick, careTick: store.careTick, compact: compact, paused: isCovered
        )
        .accessibilityElement()
        .accessibilityLabel(Text(L10n.companionSceneLabel(
            String(localized: current.species.title),
            String(localized: stageTitle),
            Int((store.progress * 100).rounded()),
            String(localized: store.mood.title(isPet: store.isPet))
        )))
        .accessibilityHint(Text(L10n.companionSceneHint))
    }

    /// Whether a sheet hides the card. Half up — the lab's usual height — it
    /// does not, and the card has to keep playing what the sheet changes:
    /// held still under every sheet, points added in the lab grew the tree
    /// with nobody watching and it jumped when the sheet closed.
    private var isCovered: Bool {
        guard let sheet = store.sheet else { return false }
        return sheet == .decorate || sheet.isMoment || detent == .large
    }

    private var stageTitle: LocalizedStringResource {
        CompanionMath.stageTitle(store.stage, isPet: store.isPet, isReady: store.isReady)
    }

    /// "Sapling · thirsty · day 4".
    private func subtitle(_ current: Companion) -> String {
        [String(localized: stageTitle),
         String(localized: store.mood.title(isPet: store.isPet)),
         String(localized: L10n.companionDay(store.day))].joined(separator: " · ")
    }

    private var progressBar: some View {
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
            Text(L10n.companionNext(String(localized: CompanionMath.stageTitle(
                next, isPet: isPet, isReady: next >= CompanionMath.stageCount(isPet: isPet)
            ))))
            .font(.caption)
            .foregroundStyle(.secondary)
            .oneLine()
        }
        .accessibilityElement(children: .combine)
    }

    /// The house jar — Leaves and Sparkles side by side — with a "+10" that
    /// rises out of it when it is paid.
    private var jar: some View {
        Button { store.send(.decorateTapped) } label: {
            HStack(spacing: 8) {
                coin("🍃", store.house.leaves)
                coin("✨", store.house.sparkles)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassControl()
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if let pay = store.lastPay {
                (Text(L10n.companionPay(pay.coins.leaves)) + Text(verbatim: " 🍃  ")
                    + Text(L10n.companionPay(pay.coins.sparkles)) + Text(verbatim: " ✨"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.success)
                    .fixedSize()
                    .phaseAnimator([0, 1, 2], trigger: pay.id) { content, phase in
                        content
                            .offset(y: phase == 1 ? -22 : -6)
                            .opacity(phase == 1 ? 1 : 0)
                    } animation: { phase in
                        phase == 1 ? .easeOut(duration: 0.35) : .easeIn(duration: 0.8).delay(0.6)
                    }
                    .allowsHitTesting(false)
            }
        }
        .animation(Motion.spring, value: store.house.leaves)
        .animation(Motion.spring, value: store.house.sparkles)
        .accessibilityLabel(Text(L10n.companionJar))
        .accessibilityValue(Text(L10n.companionJarBoth(store.house.leaves, store.house.sparkles)))
    }

    private func coin(_ symbol: String, _ amount: Int) -> some View {
        HStack(spacing: 3) {
            Text(verbatim: symbol)
            Text(amount, format: .number)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
        }
        .fixedSize()
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

    /// Today's holiday: an offer to put its things out, or just its name once
    /// they are.
    @ViewBuilder
    private var holidayChip: some View {
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

    /// Water for a plant, a pet for a pet. Counts once a day per phone; every
    /// tap still gets a reaction.
    private func careButton(_ current: Companion, small: Bool = false) -> some View {
        Button { store.send(.careTapped) } label: {
            Label {
                Text(current.species.isPet ? L10n.companionPet : L10n.companionWater)
                    .fixedSize()
            } icon: {
                Image(systemName: store.caredToday ? "checkmark" : current.species.isPet ? "heart.fill" : "drop.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font((small ? Font.caption : .subheadline).weight(.semibold))
            .padding(.horizontal, small ? 10 : 12)
            .padding(.vertical, small ? 6 : 8)
            .glassControl(tinted: store.caredToday ? nil : theme.accent.opacity(0.35))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: store.careTick)
        .accessibilityHint(Text(L10n.companionCareHint))
        .accessibilityIdentifier("CompanionCare")
    }

    #if DEBUG
    /// Development builds: points off and on right under the tree, to watch it
    /// shrink and grow through its stages without a sheet in the way. A stage
    /// is about eleven points; this steps four at a time.
    private var pointsStepper: some View {
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
    #endif

    // MARK: - A busy day

    private func strip(_ current: Companion) -> some View {
        HStack(spacing: 12) {
            scene(current, compact: true)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(current.species.title)
                    .font(.subheadline.weight(.semibold))
                    .oneLine()
                Text(subtitle(current))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .oneLine()
            }
            Spacer(minLength: 0)
            if store.isReady {
                Button { store.send(.celebrateTapped) } label: {
                    Image(systemName: "party.popper.fill")
                        .padding(8)
                        .glassControl(tinted: theme.accent.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.companionCelebrate))
            } else {
                careButton(current, small: true)
            }
        }
        .padding(8)
        .glassCard()
    }

    // MARK: - Nothing growing yet

    private var invitation: some View {
        let first = store.house.album.isEmpty
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
}
