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

    public init(store: StoreOf<NowFeature>) {
        self.store = store
    }

    private var isInline: Bool { placement == .inline }

    public var body: some View {
        HStack(spacing: 10) {
            Button { store.send(.dockTapped) } label: {
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
                            .foregroundStyle(store.dockItem == .add ? .secondary : .primary)
                            .lineLimit(1)
                            // The live thing changing — tonight's dinner giving
                            // way to the movie round, one event to the next —
                            // morphs rather than cuts.
                            .contentTransition(.interpolate)
                        if !isInline, let subtitle {
                            subtitle
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Dock")

            Button {
                adds += 1
                store.send(.addTapped)
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    // A quarter turn as Add anything opens. The light tap is
                    // already the press style's, on the way down.
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(adds) * 90))
                    .animation(Motion.release, value: adds)
                    .frame(width: 30, height: 30)
                    .background(theme.accent, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(L10n.dockAddPlaceholder))
            .accessibilityIdentifier("DockAdd")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .animation(Motion.spring, value: store.dockItem)
    }

    // MARK: - Contents

    /// The emblem's identity: the thing in the dock, not the state it is in.
    /// An event that gets under way keeps its emblem (and bounces); something
    /// else taking the dock blurs across to its own.
    private var emblemKey: String {
        switch store.dockItem {
        case let .happening(occurrence), let .startingSoon(occurrence), let .dinnerSuggestion(occurrence):
            occurrence.id
        case .dinner, .dinnerUndecided: "dinner"
        case .movieRound: "movieRound"
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
        case .movieRound:
            symbol("popcorn.fill", tint: Palette.violet)
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
