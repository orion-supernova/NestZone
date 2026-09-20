import ComposableArchitecture
import SwiftUI

public struct HubView: View {
    @Bindable var store: StoreOf<HubFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<HubFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                GlassGroup(spacing: 18) {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(
                                    minimum: HubLayout.minimumCardWidth,
                                    maximum: HubLayout.maximumCardWidth
                                ),
                                spacing: HubLayout.spacing
                            )
                        ],
                        spacing: HubLayout.spacing
                    ) {
                        ForEach(Array(HubModule.allCases.enumerated()), id: \.element.id) { index, module in
                            ModuleTile(
                                module: module,
                                count: count(for: module),
                                isPending: isPending(module),
                                isAlarming: isAlarming(module)
                            ) { store.send(.moduleTapped(module)) }
                            .appear(index)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    // The same figure above, below and between: one spacing on
                    // this screen, so nothing about the rhythm is arbitrary.
                    .padding(.vertical, HubLayout.spacing)
                }
            }
            .background(Backdrop(tint: theme.accent))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle(Text(L10n.managementScreenTitle))
            .task { await store.send(.task).finish() }
        } destination: { store in
            switch store.case {
            case let .shopping(store): ShoppingView(store: store)
            case let .recipes(store): RecipesView(store: store)
            case let .movies(store): MoviesView(store: store)
            case let .finance(store): FinanceView(store: store)
            case let .calendar(store): CalendarView(store: store)
            case let .issues(store): IssuesView(store: store)
            }
        }
    }

    private func count(for module: HubModule) -> Int? {
        switch module {
        case .shopping: store.shoppingCount
        case .recipes: store.recipeCount
        case .movies: store.movieCount
        // Zero bills needing attention is good news, and a card shouting "0"
        // reads as something missing rather than as nothing to do.
        case .finance: store.billsDueCount > 0 ? store.billsDueCount : nil
        // A quiet week is good news, and a card shouting "0" reads as something
        // missing rather than as nothing on.
        case .calendar: store.eventsThisWeekCount > 0 ? store.eventsThisWeekCount : nil
        // A house with nothing wrong with it is good news, and a card shouting
        // "0" reads as something missing rather than as nothing broken.
        case .maintenance: store.openIssueCount > 0 ? store.openIssueCount : nil
        }
    }

    /// Whether the card is carrying bad news as well as a number.
    ///
    /// Only House Problems can: three things on the shopping list is a shopping
    /// list, and three urgent repairs is a different kind of fact.
    ///
    /// It used to say so by painting the *count* red, which was wrong twice
    /// over — a red number beside a cyan icon reads as a colouring mistake
    /// before it reads as a warning, and Calendar was tinted red anyway, so the
    /// alarm was the ordinary state of another card. Every count now matches
    /// its own icon, and the warning is a dot on that icon: one small thing
    /// that is *only* ever there when something is wrong.
    private func isAlarming(_ module: HubModule) -> Bool {
        switch module {
        case .maintenance: store.urgentIssueCount > 0
        case .shopping, .recipes, .movies, .finance, .calendar: false
        }
    }

    /// Whether this card's number is still on its way.
    ///
    /// Distinct from "the number is zero", which is a real answer and looks
    /// identical. Without this the Hub opened reading 0 across the board and
    /// then quietly corrected itself, which states something false rather than
    /// admitting it does not know yet.
    private func isPending(_ module: HubModule) -> Bool {
        switch module {
        case .shopping: !store.loaded.contains(.shopping)
        case .recipes: !store.loaded.contains(.recipes)
        case .movies: !store.loaded.contains(.movies)
        case .finance: !store.loaded.contains(.billsDue)
        case .calendar: !store.loaded.contains(.events)
        case .maintenance: !store.loaded.contains(.issues)
        }
    }
}

// MARK: - Layout

/// The Hub's geometry.
///
/// Six cards, two columns, one spacing, every card the size of what is in it.
/// It is worth writing down what this is *not*, because four earlier versions
/// of this screen each tried one of them and each was worse:
///
/// - Cards stretched to reach the bottom of the screen. Filling the screen
///   this way opens a gap between a card's icon and its title wider than the
///   gap between two cards, and the card stops reading as one object.
/// - Six full-width rows, which do fill every phone exactly, but turn a hub
///   of places into a settings list.
/// - Every other column dropped below its neighbour. It fills more of the
///   screen and reads as deliberate, but a grid of six equals is easier to
///   take in when they line up.
/// - The card tinted in the module's colour. One tinted card among neutral
///   ones is an accent, which is why Calendar and Finance each have one; six
///   is a wash.
///
/// What is left is the ordinary answer, and the space under the last row is
/// allowed to be space.
enum HubLayout {
    /// The only spacing on this screen: between columns, between rows, and the
    /// margin above the first card and below the last.
    static let spacing: CGFloat = 16
    /// Two columns on every phone, more on an iPad.
    static let minimumCardWidth: CGFloat = 158
    /// So a wide window adds columns instead of stretching six cards across it.
    static let maximumCardWidth: CGFloat = 260

    static let cardPadding: CGFloat = 16
    /// Between the icon and the text it labels.
    static let cardInnerGap: CGFloat = 14
    /// What the card's own contents come to at the default text size: the
    /// padding twice, the icon, the gap, a one-line name and a two-line
    /// description. A floor rather than a height, so a larger text size can
    /// have more, and a constant rather than a measurement, so all six are
    /// identical on every device.
    static let cardHeight: CGFloat = 150

    static let iconSide: CGFloat = 46
    static let iconRadius: CGFloat = 14

    /// The card itself is **not** tinted, and that is the decision, not an
    /// omission.
    ///
    /// Calendar tints one event card with `kind.tint.opacity(0.18)` and
    /// Finance one category card with `0.12`, and both work because they are
    /// one coloured surface among neutral ones. Six of them side by side is a
    /// different picture: the tint stops being an accent and becomes most of
    /// what you can see, and the screen reads cheap. Tried at 0.13 and again
    /// at 0.08 here; both washed it out.
    ///
    /// The colour lives in the icon and the count instead, which is where it
    /// identifies the module without colouring the furniture.
    static let iconTintOpacity: Double = 0.16
}

// MARK: - Card

private struct ModuleTile: View {
    let module: HubModule
    let count: Int?
    /// The count has not arrived yet, as opposed to having arrived as zero.
    let isPending: Bool
    /// Something behind this card is wrong, not merely counted.
    var isAlarming: Bool = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            // Centred, not pinned top and bottom. The card is a little taller
            // than its contents on most screens, and that difference reads as
            // padding when it is split above and below and as a hole when it
            // is all in the middle. The columns are offset anyway, so there is
            // no cross-card alignment for centring to break.
            VStack(alignment: .leading, spacing: HubLayout.cardInnerGap) {
                HStack(alignment: .center, spacing: 8) {
                    icon
                    Spacer(minLength: 0)
                    if module.isAvailable { number }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(module.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        // "Calendar & Events" is one line in English and two in
                        // Turkish, and truncating a module's name is a worse
                        // trade than a second line.
                        .lineLimit(2)
                    Text(module.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !module.isAvailable {
                        Badge(String(localized: L10n.hubComingSoon), tint: .secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(HubLayout.cardPadding)
            .frame(maxWidth: .infinity, minHeight: HubLayout.cardHeight, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: module.isAvailable)
        .disabled(!module.isAvailable)
        .opacity(module.isAvailable ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(module.isAvailable ? .isButton : [])
    }

    private var tint: Color { module.isAvailable ? module.tint : Color.secondary }

    /// What the icon bounces on.
    ///
    /// The count, so the symbol marks its number arriving and every change to
    /// it afterwards — and since every read here is a live subscription, that
    /// includes somebody else adding to the shopping list from their own
    /// phone. Frozen under Reduce Motion: the value never changes, so the
    /// effect never fires.
    private var bounce: Int {
        reduceMotion ? 0 : (count ?? -1)
    }

    private var icon: some View {
        Image(systemName: module.symbol)
            .font(.title3)
            .symbolEffect(.bounce, options: .nonRepeating, value: bounce)
            .foregroundStyle(tint)
            .frame(width: HubLayout.iconSide, height: HubLayout.iconSide)
            .background(
                tint.opacity(HubLayout.iconTintOpacity),
                in: .rect(cornerRadius: HubLayout.iconRadius, style: .continuous)
            )
            .overlay(alignment: .topTrailing) { alarm }
    }

    /// The whole of the warning, and the only red on this screen.
    ///
    /// Small, because it is not competing with the count — it is saying the
    /// count is not the whole story. It breathes, and at most one card here
    /// ever does.
    @ViewBuilder
    private var alarm: some View {
        if isAlarming {
            Circle()
                .fill(Palette.danger)
                .frame(width: 11, height: 11)
                .offset(x: 3, y: -3)
                .pulse(true)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var number: some View {
        Group {
            if isPending {
                // Shaped like the number it is standing in for, so the card
                // does not resize when the real one lands.
                //
                // `verbatim` because this is a shape, not language: it is
                // always drawn redacted, so it is never read. A plain
                // `Text("––")` is a localizable literal — the rule the whole
                // catalog is built on — and the extractor duly added a "––"
                // entry to it.
                Text(verbatim: "––")
                    .redacted(reason: .placeholder)
            } else if let count {
                AnimatedNumber(count)
            }
        }
        .font(.system(.title3, design: .rounded, weight: .bold))
        // Always the module's own colour, never a state. A number that changes
        // hue is a number you have to decode; the dot on the icon is the thing
        // that says something is wrong.
        .foregroundStyle(module.tint)
    }
}
