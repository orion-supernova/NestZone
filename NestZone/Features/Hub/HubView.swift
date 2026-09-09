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
                        columns: [GridItem(.adaptive(minimum: 158), spacing: Metrics.stackSpacing)],
                        spacing: Metrics.stackSpacing
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
                    .padding(.bottom, Metrics.scrollBottomInset)
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
        // Zero bills needing attention is good news, and a tile shouting "0"
        // reads as something missing rather than as nothing to do.
        case .finance: store.billsDueCount > 0 ? store.billsDueCount : nil
        // A quiet week is good news, and a tile shouting "0" reads as something
        // missing rather than as nothing on.
        case .calendar: store.eventsThisWeekCount > 0 ? store.eventsThisWeekCount : nil
        // A house with nothing wrong with it is good news, and a tile shouting
        // "0" reads as something missing rather than as nothing broken.
        case .maintenance: store.openIssueCount > 0 ? store.openIssueCount : nil
        }
    }

    /// Whether the tile's number is bad news rather than merely a number.
    ///
    /// Only House Problems has one: three things on the shopping list is a
    /// shopping list, and three urgent repairs is a different kind of fact. The
    /// tile keeps its own colour — a tile whose hue moves is a tile you have to
    /// hunt for on exactly the day you most need it — and the *number* goes red
    /// instead, which is the part that is actually saying something.
    private func isAlarming(_ module: HubModule) -> Bool {
        switch module {
        case .maintenance: store.urgentIssueCount > 0
        case .shopping, .recipes, .movies, .finance, .calendar: false
        }
    }

    /// Whether this tile's number is still on its way.
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

private struct ModuleTile: View {
    let module: HubModule
    let count: Int?
    /// The count has not arrived yet, as opposed to having arrived as zero.
    let isPending: Bool
    /// The number is bad news, not merely a number.
    var isAlarming: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: module.symbol)
                        .font(.title3)
                        .foregroundStyle(module.isAvailable ? module.tint : Color.secondary)
                        .frame(width: 42, height: 42)
                        .background(
                            (module.isAvailable ? module.tint : Color.secondary).opacity(0.14),
                            in: .rect(cornerRadius: 12, style: .continuous)
                        )
                    Spacer(minLength: 0)
                    if module.isAvailable {
                        if isPending {
                            // Shaped like the number it is standing in for, so
                            // the tile does not resize when the real one lands.
                            //
                            // `verbatim` because this is a shape, not language:
                            // it is always drawn redacted, so it is never read.
                            // A plain `Text("––")` is a localizable literal — the
                            // rule the whole catalog is built on — and the
                            // extractor duly added a "––" entry to it.
                            Text(verbatim: "––")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(module.tint)
                                .redacted(reason: .placeholder)
                        } else if let count {
                            AnimatedNumber(count)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(isAlarming ? Palette.danger : module.tint)
                                // At most one tile on this grid ever breathes,
                                // and only when something is genuinely wrong.
                                .pulse(isAlarming)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(module.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(module.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if !module.isAvailable {
                    Badge(String(localized: L10n.hubComingSoon), tint: .secondary)
                }
            }
            .animation(Motion.spring, value: isAlarming)
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: module.isAvailable)
        .disabled(!module.isAvailable)
        .opacity(module.isAvailable ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(module.isAvailable ? .isButton : [])
    }
}
