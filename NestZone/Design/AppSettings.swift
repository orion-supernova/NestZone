import ComposableArchitecture
import SwiftUI

/// Settings that outlive a launch and that more than one feature reads.
///
/// These were four separate mechanisms before: `@AppStorage("selectedTheme")`
/// re-declared in every view that needed it, a `LocalizationManager` singleton,
/// a `UserDefaults` key poked directly by `HomeSelectionManager`, and a
/// `NotificationCenter` broadcast to tell everyone the home had changed. A
/// `@Shared` value is one source of truth that every feature observes and that
/// tests can override.
///
/// Key names are camelCase with no dots: a `.` in an app-storage key defeats
/// key-value observation, and Sharing then falls back to NotificationCenter,
/// which is both slower and less accurate across processes.
extension SharedKey where Self == AppStorageKey<AppTheme>.Default {
    public static var theme: Self {
        Self[.appStorage("appTheme"), default: .basic]
    }
}

extension SharedKey where Self == AppStorageKey<AppLanguage>.Default {
    public static var language: Self {
        Self[.appStorage("appLanguage"), default: .system]
    }
}

extension SharedKey where Self == AppStorageKey<String?>.Default {
    /// Raw id of the home the user last had open. Stored as `String?` because
    /// `@AppStorage` cannot hold a custom type; read it through
    /// `Shared<String?>.homeID` below.
    public static var selectedHomeIDRaw: Self {
        Self[.appStorage("appSelectedHomeID"), default: nil]
    }
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    /// Whether the movie catalogue may return adult titles.
    public static var includeAdultTitles: Self {
        Self[.appStorage("appIncludeAdultTitles"), default: false]
    }

    /// Shopping list grouped by category (the default) versus one flat list.
    /// Remembered, because people reliably prefer one or the other.
    public static var shoppingGrouped: Self {
        Self[.appStorage("appShoppingGrouped"), default: true]
    }

    /// Set once the intro has been seen, so it never shows twice.
    public static var hasCompletedOnboarding: Self {
        Self[.appStorage("appHasCompletedOnboarding"), default: false]
    }
}

extension Shared<String?> {
    /// Typed view over the persisted home id.
    ///
    /// The setter goes through `withLock`: swift-sharing raises a runtime issue
    /// for a bare `wrappedValue =` assignment, since the write has to be
    /// serialised against other readers.
    public var homeID: HomeID? {
        get { wrappedValue.map { HomeID(rawValue: $0) } }
        nonmutating set {
            withLock { $0 = newValue?.rawValue }
        }
    }
}
