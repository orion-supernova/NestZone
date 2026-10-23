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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped for every new message — one appearing, or one replacing another.
    /// Drives the shake and the haptic, so a re-render that hands the same
    /// message back does neither.
    @State private var refusals = 0

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

    /// The message as it reads. `LocalizedStringResource` is only `Equatable`,
    /// and swapping one message for another needs something to key on.
    private var message: String? { error.map { String(localized: $0) } }

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

            if let error, let message {
                // Stacked, so one message replacing another blurs across in
                // place rather than the two standing one above the other.
                ZStack(alignment: .leading) {
                    Label { Text(error) } icon: {
                        Image(systemName: "exclamationmark.circle.fill")
                    }
                    .id(message)
                    .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
                }
                .font(.caption)
                .foregroundStyle(Palette.danger)
                .transition(reduceMotion ? AnyTransition.opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        // The field refuses, message and all — so a caller never shakes it
        // again on top: a failed submit that clears the message and sets it
        // back is already a new one.
        .shake(on: refusals)
        .animation(Motion.spring, value: message)
        .onChange(of: message) { old, new in
            if new != nil, new != old { refusals += 1 }
        }
        // Raised by whatever the person just typed or submitted.
        .sensoryFeedback(.error, trigger: refusals)
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
