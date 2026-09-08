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

extension SharedKey where Self == FileStorageKey<[Home]>.Default {
    /// The household list as it stood at the end of the last session.
    ///
    /// The launch screen used to stay up until `homes:listMine` answered, and on
    /// a cold start that answer is a websocket connect, a refresh-token exchange
    /// and a query round trip away — every launch paid the network to be told
    /// what the device already knew, and a launch with no network never got past
    /// the splash at all. Seeded from here the gate opens immediately and the
    /// live subscription corrects it a moment later, which is the same bargain
    /// the rest of the app makes with optimistic writes.
    ///
    /// A file rather than app storage: `@AppStorage` holds property-list types
    /// only, and this is a list of structs. Documents, because it must survive a
    /// low-storage purge — a cleared cache would put the splash back — and the
    /// container is private (the app ships no `UIFileSharingEnabled`).
    ///
    /// Cleared on sign-out. It is one household's data, and the next person to
    /// sign in on this device must not inherit it.
    public static var cachedHomes: Self {
        Self[
            .fileStorage(.documentsDirectory.appending(component: "cached-homes.json")),
            default: []
        ]
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

    /// Set once the household has been asked about notifications.
    ///
    /// The system prompt is one-shot — a "Don't Allow" can only be undone in
    /// Settings.app — so the app asks softly first, and asks exactly once. A
    /// pre-prompt that reappears every launch is worse than never asking.
    public static var hasAskedForNotifications: Self {
        Self[.appStorage("appHasAskedForNotifications"), default: false]
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
