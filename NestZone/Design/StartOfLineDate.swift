import Foundation

/// A date written where a line begins, with its first letter capitalised.
///
/// Swedish and Turkish write months and weekdays in lowercase ("november
/// 2026", "tisdag"), which is right in a sentence and wrong at the head of a
/// line, where English capitalises them anyway. This wraps a date style and
/// raises the first letter of what it makes, in the app's language, so a header
/// reads the same way in all three. For a date inside a sentence, use the plain
/// style.
struct StartOfLineDate: FormatStyle {
    var base: Date.FormatStyle

    func format(_ value: Date) -> String {
        let text = base.format(value)
        guard let first = text.first else { return text }
        return String(first).uppercased(with: L10n.locale) + text.dropFirst()
    }

    func locale(_ locale: Locale) -> StartOfLineDate {
        StartOfLineDate(base: base.locale(locale))
    }
}

extension FormatStyle where Self == StartOfLineDate {
    /// `Text(date, format: .startOfLine(.dateTime.month(.wide).year()))`
    static func startOfLine(_ base: Date.FormatStyle) -> StartOfLineDate {
        StartOfLineDate(base: base)
    }
}
