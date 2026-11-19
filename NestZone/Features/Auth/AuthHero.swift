import SwiftUI

/// The sign-in screen's picture: the house's own cherry tree in a window, with
/// four glass cards floating over its edges, each a glimpse of what the app
/// holds (a chore ticked, a shopping line, dinner, a movie night).
///
/// The tree is a still from the same renderer Today uses, drawn once; nothing
/// here animates on its own, so the screen at rest costs nothing. The cards
/// are decoration, hidden from VoiceOver, and stop growing with Dynamic Type
/// at a size where they would cover the tree.
struct AuthHero: View {
    @Environment(\.theme) private var theme

    /// Late afternoon, so the sky is warm whatever the hour it is opened at.
    private static let evening = Calendar.current.date(
        bySettingHour: 17, minute: 0, second: 0, of: Date()
    ) ?? Date()

    private static let companion = Companion(
        species: .cherry, seed: "welcome-home", startedAt: .distantPast
    )

    var body: some View {
        ZStack {
            window
            GlassGroup(spacing: 8) {
                ZStack {
                    card(L10n.authPreviewChore, symbol: "checkmark.circle.fill", tint: Palette.emerald)
                        .appear(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(x: -6, y: 22)
                    card(L10n.authPreviewMovie, symbol: "popcorn.fill", tint: Palette.amber)
                        .appear(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 6, y: 64)
                    card(L10n.authPreviewShopping, symbol: "cart.fill", tint: Palette.cyan)
                        .appear(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .offset(x: 6, y: -64)
                    card(L10n.authPreviewDinner, symbol: "fork.knife", tint: Palette.hotPink)
                        .appear(5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: -6, y: -22)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityHidden(true)
        }
        .appear(0)
    }

    private var window: some View {
        ScenePortrait(
            companion: Self.companion, progress: 0.97, mood: .bright, stage: 5, now: Self.evening
        )
        .clipShape(.rect(cornerRadius: 36, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.35), lineWidth: 3)
        }
        .shadow(color: theme.accent.opacity(0.22), radius: 24, y: 12)
        .padding(.horizontal, 14)
        .accessibilityHidden(true)
    }

    private func card(_ text: LocalizedStringResource, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(text)
                .foregroundStyle(.primary)
        }
        .font(.system(.footnote, design: .rounded, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
    }
}
