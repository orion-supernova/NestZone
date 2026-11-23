import SwiftUI

/// The app's text colours, as styles a view asks for by role.
///
/// `.secondary` and `.tertiary` are tuned by the system against opaque
/// backgrounds; over glass on a themed wash they measured 3.4:1 (secondary,
/// light) and 1.7 to 2.3:1 (tertiary). These roles resolve to solid colours
/// from `Palette` that hold 4.5:1 or better on every theme's worst surface,
/// in both appearances and under Increase Contrast, and the accent role
/// resolves through the *current theme*, so a call site never reads `theme`
/// just to colour a word.
///
///     Text("Due Friday").foregroundStyle(.secondaryText)
///     Text("See all").foregroundStyle(.accentText)
///     Text("Add").foregroundStyle(.onAccent)      // on a fill of the accent
///
/// Resolution happens when the style is drawn, from stored colours: nothing is
/// built in a `body`.
public struct TextRole: ShapeStyle {
    enum Role { case secondary, tertiary, accent, onAccent, accentFill }
    let role: Role

    public func resolve(in environment: EnvironmentValues) -> Color {
        switch role {
        case .secondary: Palette.textSecondary
        case .tertiary: Palette.textTertiary
        case .accent: environment.theme.ink
        case .onAccent: environment.theme.onAccent
        case .accentFill: environment.theme.accentFill
        }
    }
}

extension ShapeStyle where Self == TextRole {
    /// A second line or a caption. Replaces `.secondary` for words.
    public static var secondaryText: TextRole { TextRole(role: .secondary) }
    /// Skippable metadata (a timestamp, a hint). Replaces `.tertiary` for
    /// words; `.tertiary` and `.quaternary` are for hairlines and washes only.
    public static var tertiaryText: TextRole { TextRole(role: .tertiary) }
    /// The theme's accent as words or a glyph (a link, a count, a symbol).
    /// The brand accent itself is for fills and tints.
    public static var accentText: TextRole { TextRole(role: .accent) }
    /// What is written on a fill of the theme's accent.
    public static var onAccent: TextRole { TextRole(role: .onAccent) }
    /// The accent as a fill that carries words (a bubble, a button, a chip):
    /// the theme's accent deepened until white reads on it. Pairs with
    /// `.onAccent`. The pure accent is for glyphs and tints.
    public static var accentFill: TextRole { TextRole(role: .accentFill) }
}

extension View {
    /// The label over a group of rows: "Needs you", "Up next".
    ///
    /// Subheadline semibold in sentence case. It was footnote semibold in
    /// capitals, 13pt and the least legible line on the screen; capitals also
    /// cost reading speed and fall apart in Turkish dotted and dotless i.
    public func groupLabel() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}
