import ComposableArchitecture
import SwiftUI

/// One event, pushed on the stack that asked for it: the detail sheet's content
/// as a screen (`EventPageFeature`).
struct EventPageView: View {
    @Bindable var store: StoreOf<EventPageFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let detail = store.scope(state: \.detail, action: \.detail) {
                EventDetailSheet(store: detail, isPushed: true)
            } else if store.isGone {
                EmptyStateView(
                    title: L10n.calendarEventGoneTitle,
                    message: L10n.calendarEventGoneMessage,
                    symbol: "calendar.badge.exclamationmark"
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
        .hostedSheet(item: $store.scope(state: \.compose, action: \.compose)) { store in
            EventComposerSheet(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
