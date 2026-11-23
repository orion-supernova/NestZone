import SwiftUI

/// How a row in a `Form` or `List` is drawn: the words in the label colour,
/// the icon carrying the accent, the way iOS Settings does it.
///
/// The app tints the whole tree with the theme's accent, and a plain `Button`
/// in a list takes that tint for its *label*, so "Check for updates" and every
/// other row that could be tapped came out in pink. A row's words are not the
/// action; its icon is the hint that it is one.
///
///     Form { ... }.settingsRows()
///     Button(role: .destructive) { ... } label: { Label(...) }
///         .labelStyle(.settingsRow(.destructive))
public struct SettingsRowLabelStyle: LabelStyle {
    public enum Tone: Sendable {
        /// Words in the label colour, icon in the accent.
        case regular
        /// For an action that is risky but can be undone ("Leave home"): the
        /// icon is red, the words stay quiet.
        case caution
        /// For an action that cannot be taken back ("Delete account"): icon
        /// and words in the measured red.
        case destructive
    }

    let tone: Tone

    public init(_ tone: Tone = .regular) { self.tone = tone }

    public func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
                .foregroundStyle(tone == .destructive ? AnyShapeStyle(Palette.dangerText) : AnyShapeStyle(.primary))
        } icon: {
            configuration.icon
                .foregroundStyle(tone == .regular ? AnyShapeStyle(.accentText) : AnyShapeStyle(Palette.dangerText))
        }
        // Back to the system's own layout, so icons keep the list's column.
        .labelStyle(.automatic)
    }
}

extension LabelStyle where Self == SettingsRowLabelStyle {
    public static var settingsRow: SettingsRowLabelStyle { SettingsRowLabelStyle() }
    public static func settingsRow(_ tone: SettingsRowLabelStyle.Tone) -> SettingsRowLabelStyle {
        SettingsRowLabelStyle(tone)
    }
}

extension View {
    /// Apply once to a `Form` or `List` whose rows are buttons and links: the
    /// row's words go to the label colour, its icon keeps the accent, and
    /// text-only button rows stop taking the root tint for their words.
    public func settingsRows() -> some View {
        labelStyle(.settingsRow)
            .buttonStyle(SettingsRowButtonStyle())
    }
}

/// A button in a list row that keeps the list's own press highlight but draws
/// its label in the label colour instead of the tint.
struct SettingsRowButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            configuration.trigger()
        } label: {
            configuration.label
        }
        .buttonStyle(.automatic)
        // The tint is what a list button draws its words in, so the tint is
        // what changes; the icon's accent is the label style's. A destructive
        // row keeps a red, the measured one.
        .tint(configuration.role == .destructive ? Palette.dangerText : .primary)
    }
}
