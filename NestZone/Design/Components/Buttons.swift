import SwiftUI

/// The app's primary call to action.
///
/// Wraps `.glassProminent` so every screen gets the same height, corner radius,
/// haptic and disabled treatment. Screens used to build this by hand and had
/// drifted to four different heights.
public struct PrimaryButton: View {
    private let title: LocalizedStringResource
    private let symbol: String?
    private let isLoading: Bool
    private let role: ButtonRole?
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.theme) private var theme

    public init(
        _ title: LocalizedStringResource,
        symbol: String? = nil,
        isLoading: Bool = false,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.isLoading = isLoading
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(.white)
                } else if let symbol {
                    Image(systemName: symbol).font(.body.weight(.semibold))
                }
                Text(title).font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .contentTransition(.opacity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(role == .destructive ? Palette.danger : theme.accent)
        // The button stays mounted while work is in flight so the layout never
        // jumps; it just stops accepting taps.
        .disabled(isLoading || !isEnabled)
        .animation(Motion.fade, value: isLoading)
        .sensoryFeedback(.impact(weight: .medium), trigger: isLoading) { was, now in
            !was && now
        }
    }
}

/// The quieter sibling — "Cancel", "Not now", "Skip".
public struct SecondaryButton: View {
    private let title: LocalizedStringResource
    private let symbol: String?
    private let action: () -> Void

    public init(_ title: LocalizedStringResource, symbol: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 26)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }
}

/// A circular glass icon button for toolbars and overlays.
public struct IconButton: View {
    private let symbol: String
    private let label: LocalizedStringResource
    private let tint: Color?
    private let action: () -> Void

    public init(
        symbol: String,
        label: LocalizedStringResource,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.label = label
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .glassEffect(.regular.tint(tint).interactive(), in: .circle)
        .accessibilityLabel(Text(label))
    }
}
