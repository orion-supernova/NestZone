import ComposableArchitecture
import SwiftUI

public struct HouseStatsView: View {
    let store: StoreOf<HouseStatsFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<HouseStatsFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            HouseStatsGrid(
                stats: store.stats,
                eventsThisWeek: store.eventsThisWeek,
                statsLoaded: store.statsLoaded,
                eventsLoaded: store.eventsLoaded
            ) { tile in
                store.send(.tileTapped(tile))
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, Metrics.stackSpacing)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.hubStatsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
    }
}
