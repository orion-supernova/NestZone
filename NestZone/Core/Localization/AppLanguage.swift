import Foundation

/// The languages the app ships strings for.
///
/// The picker exists because NestZone households are frequently mixed-language;
/// following the system language alone would force one member's choice on the
/// whole household's shared device.
public enum AppLanguage: String, CaseIterable, Sendable, Codable, Identifiable {
    /// Follow whatever the device is set to. The default, and what a fresh
    /// install gets.
    case system
    case english = "en"
    case turkish = "tr"

    public var id: String { rawValue }

    /// `nil` for `.system`, which means "let Foundation resolve it".
    public var explicitLocale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .turkish: Locale(identifier: "tr")
        }
    }

    public var locale: Locale { explicitLocale ?? .autoupdatingCurrent }

    /// Always written in the language itself — a Turkish speaker looking for
    /// Turkish should not have to read the word "Turkish" first.
    public var endonym: String {
        switch self {
        case .system: String(localized: "language.system", defaultValue: "System", bundle: .main)
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    /// The language every string in this app is *written* in, and the one a
    /// release note falls back to when it has no translation.
    public static let base: AppLanguage = .english

    /// The languages a release note can be translated into: every real language
    /// the app ships, minus the base it is already written in, and minus
    /// `.system`, which is a preference rather than a language.
    ///
    /// Derived rather than listed so that adding a language to this enum adds a
    /// section to the changelog composer without anybody remembering to.
    public static var translatable: [AppLanguage] {
        allCases.filter { $0 != .system && $0 != base }
    }

    public var flag: String {
        switch self {
        case .system: "globe"
        case .english: "🇬🇧"
        case .turkish: "🇹🇷"
        }
    }
}

extension L10n {
    /// Points every subsequent string lookup at `language`.
    ///
    /// Call this before rendering; `AppFeature` also re-identifies the root view
    /// so already-rendered text is rebuilt.
    public static func apply(_ language: AppLanguage) {
        locale = language.locale
    }
}
