import ComposableArchitecture
import SwiftUI

/// The bar above the tab bar: the one live thing, and a way to add anything.
///
/// Drawn by the system's tab-bar accessory, which supplies the glass and moves
/// it in beside the tab bar when the bar shrinks on scroll — so this view draws
/// only its contents, and draws less of them when it is inline.
public struct NowDock: View {
    let store: StoreOf<NowFeature>

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Taps on the `+`. Each turns it a quarter, which leaves a plus looking
    /// like a plus — so it never has to turn back.
    @State private var adds = 0
    /// Choices made in the long-press menu: the person's own, so they tick.
    @State private var picks = 0
    /// Long presses that were held long enough to open the menu; drives its one thud.
    @State private var menuOpens = 0
    /// Taps on Join: the person's own, so they tick.
    @State private var joins = 0

    public init(store: StoreOf<NowFeature>) {
        self.store = store
    }

    private var isInline: Bool { placement == .inline }

    public var body: some View {
        HStack(spacing: 10) {
            // A tap does the dock's own thing; a long press opens the menu in
            // place (no lifted preview, which let the tab item behind react
            // to the same touch). The `+` is outside it and keeps its tap.
            Menu {
                dockMenu
            } label: {
                HStack(spacing: 10) {
                    if store.dockItem != .add {
                        // Stacked, so the emblem leaving and the one arriving
                        // blur across in one place rather than side by side.
                        ZStack {
                            emblem
                                .id(emblemKey)
                                .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
                        }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        title
                            .font(.subheadline.weight(store.dockItem == .add ? .regular : .semibold))
                            .foregroundStyle(store.dockItem == .add ? AnyShapeStyle(.secondaryText) : AnyShapeStyle(.primary))
                            .lineLimit(1)
                            // The live thing changing — tonight's dinner giving
                            // way to the movie round, one event to the next —
                            // morphs rather than cuts.
                            .contentTransition(.interpolate)
                        if !isInline, let subtitle {
                            subtitle
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            } primaryAction: {
                store.send(.dockTapped)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            // The menu gives no feedback of its own when a hold opens it. The
            // gesture runs beside the menu's, ends when the hold is long
            // enough (a tap never gets there), and counts the person's own
            // hold, so nothing else can fire it.
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in menuOpens += 1 })
            .sensoryFeedback(.impact(weight: .medium), trigger: menuOpens)
            .accessibilityIdentifier("Dock")
            .accessibilityHint(Text(L10n.dockMenuTitle))

            if store.dockItem.joinableMeeting(at: store.now) != nil {
                Button {
                    joins += 1
                    store.send(.joinTapped)
                } label: {
                    Label { Text(L10n.meetingJoin) } icon: { Image(systemName: "video.fill") }
                        .labelStyle(JoinLabelStyle(isCompact: isInline))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.onAccent)
                        .padding(.horizontal, isInline ? 8 : 12)
                        .frame(height: 30)
                        .background(theme.accentFill, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.pressable)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
                .accessibilityIdentifier("DockJoin")
            }

            Button {
                adds += 1
                store.send(.addTapped)
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.onAccent)
                    // A quarter turn as Add anything opens. The light tap is
                    // already the press style's, on the way down.
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(adds) * 90))
                    .animation(Motion.release, value: adds)
                    .frame(width: 30, height: 30)
                    .background(theme.accentFill, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(L10n.dockAddPlaceholder))
            .accessibilityIdentifier("DockAdd")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        // The dock is a fixed-height accessory, so it cannot grow with the
        // type the way a row can; capped, its line fits in every language.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        // The whole capsule is ours to touch: a press in the padding or the
        // gap never falls through to the tab bar or the screen behind.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.capsule)
        // A tap on the gap or the padding is the dock's too, and does nothing:
        // a shape with no gesture is skipped by hit testing, and the touch
        // would reach what scrolls underneath the glass.
        .onTapGesture {}
        .animation(Motion.spring, value: store.dockItem)
        .sensoryFeedback(.selection, trigger: picks)
        .sensoryFeedback(.impact(weight: .light), trigger: joins)
    }

    // MARK: - Long-press menu

    /// What the dock shows, as in Customize and writing the same setting, then
    /// the way into the rest of Today. The checkmark follows what is drawn, so
    /// a free house that had the next event kept sees Automatic ticked.
    @ViewBuilder
    private var dockMenu: some View {
        let setting = store.dockSetting
        Section {
            modeButton(.automatic, selected: setting.mode == .automatic)
            Menu {
                ForEach(DockThing.allCases) { thing in
                    let locked = thing.needsPlus && !store.pro.isPro
                    Button {
                        picks += 1
                        store.send(.dockThingPicked(thing), animation: Motion.spring)
                    } label: {
                        Label {
                            Text(thing.title)
                        } icon: {
                            Image(systemName: setting.mode == .always && setting.thing == thing
                                ? "checkmark" : (locked ? PlusStyle.lockedSymbol : thing.symbol))
                        }
                    }
                }
            } label: {
                Label {
                    Text(L10n.dockModeAlways)
                } icon: {
                    Image(systemName: setting.mode == .always ? "checkmark" : DockMode.always.symbol)
                }
            }
            modeButton(.addOnly, selected: setting.mode == .addOnly)
            modeButton(.off, selected: setting.mode == .off)
        } header: {
            Text(L10n.dockMenuTitle)
        }
        Divider()
        Button {
            store.send(.editTodayTapped)
        } label: {
            Label { Text(L10n.dockMenuEditToday) } icon: { Image(systemName: "slider.horizontal.3") }
        }
    }

    private func modeButton(_ mode: DockMode, selected: Bool) -> some View {
        Button {
            picks += 1
            store.send(.dockModePicked(mode), animation: Motion.spring)
        } label: {
            Label { Text(mode.title) } icon: { Image(systemName: selected ? "checkmark" : mode.symbol) }
        }
    }

    // MARK: - Contents

    /// The emblem's identity: the thing in the dock, not the state it is in.
    /// An event that gets under way keeps its emblem (and bounces); something
    /// else taking the dock blurs across to its own.
    private var emblemKey: String {
        switch store.dockItem {
        case let .happening(occurrence), let .startingSoon(occurrence), let .dinnerSuggestion(occurrence),
             let .nextEvent(occurrence):
            occurrence.id
        case .dinner, .dinnerUndecided: "dinner"
        case .movieRound, .noMovieRound: "movieRound"
        case .noEvent: "noEvent"
        case .add: "add"
        }
    }

    @ViewBuilder
    private var emblem: some View {
        switch store.dockItem {
        case let .happening(occurrence), let .startingSoon(occurrence), let .dinnerSuggestion(occurrence):
            symbol(occurrence.kind.symbol, tint: occurrence.kind.tint)
                .bounces(when: store.dockItem == .happening(occurrence))
        case .dinner, .dinnerUndecided:
            symbol("fork.knife", tint: Palette.eventFood)
        case .movieRound, .noMovieRound:
            symbol("popcorn.fill", tint: Palette.violet)
        case let .nextEvent(occurrence):
            symbol(occurrence.kind.symbol, tint: occurrence.kind.tint)
        case .noEvent:
            symbol("calendar", tint: Palette.eventGeneral)
        case .add:
            EmptyView()
        }
    }

    private func symbol(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 26, height: 26)
            .background(tint.opacity(0.18), in: .circle)
    }

    private var title: Text {
        switch store.dockItem {
        case let .happening(occurrence), let .startingSoon(occurrence):
            Text(occurrence.title)
        case let .dinner(plan):
            Text(L10n.dockTonight(plan.dockHeadline))
        case let .dinnerSuggestion(occurrence):
            Text(L10n.dockTonight(occurrence.title))
        case .dinnerUndecided:
            Text(L10n.dinnerEmptyTitle)
        case .movieRound:
            Text(L10n.dockMovieRoundTitle)
        case let .nextEvent(occurrence):
            Text(occurrence.title)
        case .noEvent:
            Text(L10n.dockNoEventTitle)
        case .noMovieRound:
            Text(L10n.dockNoMovieTitle)
        case .add:
            Text(L10n.dockAddPlaceholder)
        }
    }

    private var subtitle: Text? {
        switch store.dockItem {
        case let .happening(occurrence):
            Text(L10n.dockHappeningUntil(occurrence.end.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale)
            )))
        case let .startingSoon(occurrence):
            Text(CountdownText.phrase(for: occurrence.start, now: store.now))
        case .dinner:
            Text(L10n.dockTonightSubtitle)
        case .dinnerSuggestion:
            Text(L10n.dockSuggestionSubtitle)
        case .dinnerUndecided:
            Text(L10n.dinnerEmptySubtitle)
        case .movieRound:
            Text(L10n.dockMovieRoundSubtitle)
        case let .nextEvent(occurrence):
            Text(occurrence.start.formatted(
                .startOfLine(Date.FormatStyle().weekday(.abbreviated).hour().minute().locale(L10n.locale))
            ))
        case .noEvent:
            Text(L10n.dockNoEventSubtitle)
        case .noMovieRound:
            Text(L10n.dockNoMovieSubtitle)
        case .add:
            nil
        }
    }
}

extension MealPlan {
    /// What tonight is called in a single line: the dish, the place, or how
    /// the household is eating when nobody named either.
    var dockHeadline: String {
        if let headline { return headline }
        return switch kind {
        case .cook: String(localized: L10n.dinnerKindCook)
        case .order, .out: String(localized: cuisine?.title ?? L10n.cuisineOther)
        }
    }
}

/// Join's label: icon and word, or the icon alone when the dock is inline.
private struct JoinLabelStyle: LabelStyle {
    let isCompact: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            if !isCompact { configuration.title }
        }
    }
}
