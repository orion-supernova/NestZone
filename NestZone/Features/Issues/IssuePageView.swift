import ComposableArchitecture
import SwiftUI

/// One problem, pushed on the stack that asked for it (`IssuePageFeature`).
struct IssuePageView: View {
    @Bindable var store: StoreOf<IssuePageFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let detail = store.scope(state: \.detail, action: \.detail) {
                IssueDetailView(store: detail)
            } else if store.isGone {
                EmptyStateView(
                    title: L10n.issuesGoneTitle,
                    message: L10n.issuesGoneMessage,
                    symbol: "wrench.and.screwdriver"
                )
                .frame(maxHeight: .infinity)
                .background(Backdrop(tint: theme.accent))
            } else {
                LoadingView()
                    .background(Backdrop(tint: theme.accent))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
