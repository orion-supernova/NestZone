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

    var body: some View {
        Group {
            if let current = store.current {
                if compact { strip(current) } else { card(current) }
            } else {
                invitation
            }
        }
        .sheet(item: Binding(
            get: { store.sheet == .ceremony ? nil : store.sheet },
            set: { if $0 == nil { store.send(.sheetDismissed) } }
        )) { sheet in
            CompanionSheet(store: store, sheet: sheet)
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.sheet == .ceremony },
            set: { if !$0 { store.send(.sheetDismissed) } }
        )) {
            CeremonyView(store: store)
        }
        #if DEBUG
        .task { await demo() }
        #endif
    }

    #if DEBUG
    /// Development builds can be driven from the command line, for
    /// screenshots of states that otherwise need a finger:
    /// `simctl launch … -companionDemo care` (or decorate, album, holidays,
    /// lab, choose, celebrate).
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
        case "choose": store.send(.chooseTapped)
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
            }
            .clipShape(.rect(topLeadingRadius: Metrics.cardRadius, topTrailingRadius: Metrics.cardRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.species.title)
                            .font(.headline)
                        Text(subtitle(current))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 0)
                    jar
                }
                if store.isReady {
                    Button { store.send(.celebrateTapped) } label: {
                        Label { Text(L10n.companionCelebrate) } icon: { Image(systemName: "party.popper.fill") }
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
            choreTick: store.choreTick, careTick: store.careTick, compact: compact
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
        }
        .accessibilityElement(children: .combine)
    }

    /// The house jar, with a "+10" that rises out of it when it is paid.
    private var jar: some View {
        Button { store.send(.decorateTapped) } label: {
            HStack(spacing: 4) {
                Text(verbatim: "🍃")
                Text(store.house.jar, format: .number)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassControl()
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if let pay = store.lastPay {
                Text(L10n.companionPay(pay.amount))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.success)
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
        .animation(Motion.spring, value: store.house.jar)
        .accessibilityLabel(Text(L10n.companionJar))
        .accessibilityValue(Text(L10n.companionJarValue(store.house.jar)))
    }

    private var actions: some View {
        HStack(spacing: 18) {
            action(L10n.companionDecorate, "paintbrush.pointed.fill") { store.send(.decorateTapped) }
            action(L10n.companionAlbum, "book.closed.fill") { store.send(.albumTapped) }
            action(L10n.companionHolidays, "calendar") { store.send(.holidaysTapped) }
            if CompanionFlag.isEnabled {
                Spacer(minLength: 0)
                action(L10n.companionLab, "flask.fill") { store.send(.labTapped) }
            }
        }
        .font(.footnote.weight(.semibold))
    }

    private func action(_ title: LocalizedStringResource, _ symbol: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label { Text(title) } icon: { Image(systemName: symbol) }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(theme.accent)
                .frame(minHeight: 28)
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
                Text(L10n.companionDress(holiday.symbol, String(localized: holiday.id.title)))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .glassControl()
            }
            .buttonStyle(.plain)
        } else if let holiday = store.activeHolidays.first {
            Text(verbatim: "\(holiday.symbol) \(String(localized: holiday.id.title))")
                .font(.caption.weight(.semibold))
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

    // MARK: - A busy day

    private func strip(_ current: Companion) -> some View {
        HStack(spacing: 12) {
            scene(current, compact: true)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(current.species.title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle(current))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
                    Text(first ? L10n.companionMeetBody : L10n.companionNextBody)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button { store.send(.chooseTapped) } label: {
                Text(L10n.companionChoose)
                    .font(.subheadline.weight(.semibold))
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
