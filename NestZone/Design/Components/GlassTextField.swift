import SwiftUI

/// A text field on a glass surface, with a floating label and inline validation.
///
/// Replaces `PremiumTextField`, which drew a gradient border, an outer glow and
/// an animated focus ring — three composited layers that repainted on every
/// keystroke.
public struct GlassTextField: View {
    private let title: LocalizedStringResource
    private let symbol: String?
    @Binding private var text: String
    private let isSecure: Bool
    private let error: LocalizedStringResource?

    @FocusState private var isFocused: Bool
    @Environment(\.theme) private var theme

    public init(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        symbol: String? = nil,
        isSecure: Bool = false,
        error: LocalizedStringResource? = nil
    ) {
        self.title = title
        self._text = text
        self.symbol = symbol
        self.isSecure = isSecure
        self.error = error
    }

    private var isFloating: Bool { isFocused || !text.isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.body)
                        .foregroundStyle(isFocused ? theme.accent : .secondary)
                        .frame(width: 20)
                }
                ZStack(alignment: .leading) {
                    Text(title)
                        .font(isFloating ? .caption2 : .body)
                        .foregroundStyle(.secondary)
                        .offset(y: isFloating ? -15 : 0)
                    field
                        .offset(y: isFloating ? 6 : 0)
                }
                .animation(Motion.spring, value: isFloating)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .glassEffect(
                .regular.tint(isFocused ? theme.accent.opacity(0.18) : nil),
                in: .rect(cornerRadius: Metrics.tightRadius, style: .continuous)
            )
            .overlay {
                if error != nil {
                    RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                        .strokeBorder(Palette.danger, lineWidth: 1)
                }
            }
            .animation(Motion.fade, value: isFocused)

            if let error {
                Label { Text(error) } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(Palette.danger)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: error == nil)
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField("", text: $text).focused($isFocused)
        } else {
            TextField("", text: $text).focused($isFocused)
        }
    }
}
