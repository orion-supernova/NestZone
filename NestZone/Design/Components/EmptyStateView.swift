import SwiftUI

/// The empty state for any list.
///
/// Built on `ContentUnavailableView`, so it inherits the system's layout,
/// dynamic-type behaviour and VoiceOver grouping instead of re-deriving them —
/// the app previously had six hand-rolled variants that disagreed on all three.
public struct EmptyStateView: View {
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource?
    private let symbol: String
    private let action: Action?
    private let isCompact: Bool

    public struct Action {
        let title: LocalizedStringResource
        let handler: () -> Void

        public init(title: LocalizedStringResource, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    @Environment(\.theme) private var theme

    /// - Parameter isCompact: for an empty state sitting *inside* a scrolling
    ///   screen rather than owning it. `ContentUnavailableView` expands to fill
    ///   whatever it is given, so an inline one pushes the rest of the page —
    ///   and its own text — down behind the tab bar.
    public init(
        title: LocalizedStringResource,
        message: LocalizedStringResource? = nil,
        symbol: String,
        action: Action? = nil,
        isCompact: Bool = false
    ) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.action = action
        self.isCompact = isCompact
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(theme.accent)
                    .bounces()
            }
        } description: {
            if let message { Text(message) }
        } actions: {
            if let action {
                Button(action: action.handler) { Text(action.title) }
                    .buttonStyle(.glassProminent)
            }
        }
        .frame(maxHeight: isCompact ? 220 : .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}
