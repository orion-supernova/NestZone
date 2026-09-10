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

    /// What this household writes its money in, as `finance:summary` last
    /// reported it. `nil` until anything has been logged.
    ///
    /// Only ever a *default* for a composer that has no better answer — no
    /// stored amount is reinterpreted through it and nothing is converted. It
    /// exists because the calendar's budget field used to open on
    /// `Money.deviceDefault`, which is this phone's locale and not the
    /// household's ledger: two members in two countries budgeted the same party
    /// in two currencies, and a budget written in a currency the ledger has
    /// never seen lands in a set of figures nobody is looking at.
    ///
    /// Written by Finance, which is the only feature that knows the answer, and
    /// read through `CurrencyDefaults.preferred`. Passing it through app
    /// storage rather than a dependency keeps the calendar from reaching into
    /// Finance for it, and means the answer survives a launch — the composer is
    /// reachable long before the Finance tab has ever been opened.
    public static var householdCurrency: Self {
        Self[.appStorage("appHouseholdCurrency"), default: nil]
    }
}

extension SharedKey where Self == AppStorageKey<String>.Default {
    /// The currencies this person has actually picked, most recent first, as
    /// one comma-joined string.
    ///
    /// A string rather than an array because app storage holds property-list
    /// scalars only, and a file for four ISO codes is more machinery than the
    /// value deserves. Read it through `CurrencyDefaults`, never directly.
    public static var recentCurrenciesRaw: Self {
        Self[.appStorage("appRecentCurrencies"), default: ""]
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

/// What an amount field opens on, and what the currency picker puts at the top.
///
/// One place, because five composers ask the same question — an expense, a
/// bill, a budget, an event's budget and a repair's estimate — and they used to
/// answer it five times with `Money.deviceDefault`. That is this *phone's*
/// locale, which is not the household's ledger and not what the person picked
/// last time either.
public enum CurrencyDefaults {
    /// How many picks are worth remembering.
    ///
    /// Small on purpose: the list is a shortcut past the search field, not a
    /// history. A household that genuinely writes in six currencies is better
    /// served by typing three letters than by scrolling its own past.
    static let recentLimit = 4

    /// The codes this person has picked before, most recent first.
    public static var recent: [String] {
        @Shared(.recentCurrenciesRaw) var raw: String
        return raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    /// What an amount field should open on.
    ///
    /// In order: what this person picked last, then what the household writes
    /// its money in, then this device's locale. The last pick wins over the
    /// household because it is the more specific statement — somebody who
    /// switched to lira for the last three expenses is telling you something
    /// the ledger's majority has not caught up with yet. The household beats
    /// the device for the reason on `SharedKey.householdCurrency`.
    public static var preferred: String {
        @Shared(.householdCurrency) var household: String?
        return recent.first ?? household ?? Money.deviceDefault
    }

    /// Record a pick. Called by the picker itself, so every field that presents
    /// one gets the memory without asking for it.
    ///
    /// Moves an existing code to the front rather than duplicating it, so the
    /// list is a set in most-recent order and picking the same currency twice
    /// does not push the others out.
    public static func remember(_ code: String) {
        @Shared(.recentCurrenciesRaw) var raw: String
        var codes = recent.filter { $0 != code }
        codes.insert(code, at: 0)
        $raw.withLock { $0 = codes.prefix(recentLimit).joined(separator: ",") }
    }
}
