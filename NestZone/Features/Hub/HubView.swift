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
                                count: count(for: module)
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
            }
        }
    }

    private func count(for module: HubModule) -> Int? {
        switch module {
        case .shopping: store.shoppingCount
        case .recipes: store.recipeCount
        case .movies: store.movieCount
        case .maintenance, .finance, .calendar: nil
        }
    }
}

private struct ModuleTile: View {
    let module: HubModule
    let count: Int?
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
                    if let count, module.isAvailable {
                        AnimatedNumber(count)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(module.tint)
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
