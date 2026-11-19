import ComposableArchitecture
import SwiftUI

// Where the paywall is drawn from.
//
// A sheet can only be presented by the view on top, and a request for the
// paywall can come from under any sheet at all (an event's detail, a problem,
// a movie list picker, Customize, a server refusal from a write inside one).
// So every sheet the app opens through `hostedSheet` also hosts the paywall,
// one level deeper than the sheet that presented it, and only the deepest host
// that is on screen presents it. The tab bar is depth 0.

/// Which hosts are on screen, by depth. Only the deepest presents.
@MainActor @Observable
final class PaywallHosts {
    private var depths: [UUID: Int] = [:]

    /// The depth of the host that is on top.
    var topDepth: Int { depths.values.max() ?? 0 }

    func appear(_ id: UUID, depth: Int) { depths[id] = depth }
    func disappear(_ id: UUID) { depths[id] = nil }
}

extension EnvironmentValues {
    /// The tab bar's store, which owns the paywall's state.
    @Entry var paywallStore: StoreOf<MainFeature>?
    /// How many hosted sheets deep this view is.
    @Entry var paywallDepth = 0
}

extension View {
    /// Presents the paywall from here when this is the top layer. For the tab
    /// bar (`depth` 0); sheets get theirs from `hostedSheet`.
    func paywallHost(depth: Int = 0) -> some View {
        modifier(PaywallHost(depth: depth))
    }

    /// `sheet(item:)` that can also show the paywall over itself.
    func hostedSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { HostedSheetContent(content: content($0)) }
    }

    /// `sheet(isPresented:)` that can also show the paywall over itself.
    func hostedSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) { HostedSheetContent(content: content()) }
    }
}

private struct HostedSheetContent<Content: View>: View {
    let content: Content
    @Environment(\.paywallDepth) private var depth

    var body: some View {
        content.paywallHost(depth: depth + 1)
    }
}

private struct PaywallHost: ViewModifier {
    let depth: Int
    @Environment(PaywallHosts.self) private var hosts: PaywallHosts?
    @Environment(\.paywallStore) private var store
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .environment(\.paywallDepth, depth)
            .sheet(item: Binding(
                get: {
                    (hosts?.topDepth ?? 0) == depth
                        ? store?.scope(state: \.paywall, action: \.paywall.presented)
                        : nil
                },
                set: { if $0 == nil { store?.send(.paywall(.dismiss)) } }
            )) { paywall in
                PaywallView(store: paywall)
            }
            .onAppear { hosts?.appear(id, depth: depth) }
            .onDisappear { hosts?.disappear(id) }
    }
}
