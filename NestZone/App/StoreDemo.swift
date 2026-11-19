import Foundation
import os

/// Launch arguments for taking App Store screenshots without a live store
/// (`-storeDemo 1`, `-openPaywall calendar`, `-openSparkleStore 1`,
/// `-forceFreeHouse 1`, `-screenshotPersona <Name>`). Compiled only under `DEBUG || MEASURE`: a release
/// build has these as constants that say no, so nothing reads the defaults.
enum StoreDemo {
    #if DEBUG || MEASURE
    private static var defaults: UserDefaults { .standard }

    /// The Plus paywall and the Sparkles store draw prices they were not given
    /// by the store, and buying does nothing.
    static var isOn: Bool { defaults.bool(forKey: "storeDemo") }

    /// The feature the paywall opens for, shortly after launch.
    static var paywallFeature: ProFeature?? {
        guard let name = defaults.string(forKey: "openPaywall") else { return nil }
        return .some(ProFeature(serverName: name))
    }

    static var opensSparkleStore: Bool { defaults.bool(forKey: "openSparkleStore") }

    /// `-shoppingGroupedDemo 1`: the shopping list in aisles, whatever was
    /// stored (still Plus only). A launch argument reaches `@AppStorage` as a
    /// string, which a Bool key does not read, so `-appShoppingGrouped 1` is
    /// not a way to turn it on.
    static var groupsShopping: Bool { defaults.bool(forKey: "shoppingGroupedDemo") }

    /// The house is treated as without Plus, to photograph what a lock looks like.
    static var forcesFreeHouse: Bool { defaults.bool(forKey: "forceFreeHouse") }

    /// `-screenshotPersona <Name>`: the signed-in account is shown as this
    /// person, with the initials avatar, so a real name and face stay out of
    /// store screenshots. Applied where `User` documents arrive, so every
    /// screen follows.
    static var persona: String? {
        guard let name = defaults.string(forKey: "screenshotPersona"),
              !name.isEmpty else { return nil }
        return name
    }

    /// The signed-in user's id, learnt from `users:me`, which is the only read
    /// that says who "me" is. Guarded by a lock: streams deliver off the main actor.
    /// Also kept in the defaults, so a later launch knows who "me" is before
    /// `users:me` answers: the household list can arrive first and would
    /// otherwise be shown unmasked, with the real handle.
    private static let meKey = "screenshotPersonaMeID"
    private static let meID = OSAllocatedUnfairLock<String?>(
        initialState: UserDefaults.standard.string(forKey: "screenshotPersonaMeID"))

    /// The persona's name when `id` is the signed-in account, for the rows that
    /// carry a name and an email from the server (contributions, the ledger,
    /// the archive, the feed) and so never pass through a `User`.
    static func personaName(for id: UserID?) -> String? {
        guard let persona, let id, meID.withLock({ $0 }) == id.rawValue else { return nil }
        return persona
    }

    /// `user` as the persona when it is the signed-in account; others untouched.
    private static func masked(_ user: User, isMe: Bool) -> User {
        guard let persona, isMe || meID.withLock({ $0 }) == user.id.rawValue else { return user }
        var copy = user
        copy.name = persona
        copy.avatar = nil
        copy.avatarURL = nil
        return copy
    }

    /// For `users:me`: remembers the id, then masks.
    static func maskedMe(_ user: User?) -> User? {
        guard persona != nil, let user else { return user }
        meID.withLock { $0 = user.id.rawValue }
        defaults.set(user.id.rawValue, forKey: meKey)
        return masked(user, isMe: true)
    }

    static func masked(_ user: User) -> User { masked(user, isMe: false) }

    static func masked(_ users: [User]) -> [User] {
        persona == nil ? users : users.map { masked($0, isMe: false) }
    }

    /// Whether the notifications pre-prompt, and anything else that pops up
    /// by itself on a first launch, is held back for a clean screenshot.
    static var suppressesPrompts: Bool { persona != nil }

    /// Whether the demo prices in lira, the way a Turkish storefront would.
    private static var pricesInLira: Bool {
        Locale.current.region == .turkey || Locale.current.language.languageCode == .turkish
    }

    /// DEMO APPROXIMATIONS of Apple's Turkish price tiers, for screenshots
    /// only: NestZone.storekit carries USD prices alone and a real build asks
    /// the store. Yearly, monthly, then the six Sparkle packs in shelf order.
    private static let lira = (yearly: "749.99", monthly: "109.99",
                               packs: ["39.99", "119.99", "219.99", "399.99", "849.99", "1999.99"])

    /// Formats an amount like a store product's `displayPrice`: lira with
    /// Turkish separators in Turkey, dollars in this phone's locale elsewhere.
    private static func display(_ amount: Decimal) -> String {
        pricesInLira
            ? amount.formatted(.currency(code: "TRY").locale(Locale(identifier: "tr_TR")))
            : amount.formatted(.currency(code: "USD").locale(.current))
    }

    private static func amount(usd: String, lira: String) -> Decimal {
        Decimal(string: pricesInLira ? lira : usd)!
    }

    /// The yearly price over twelve months, rounded to a cent like the store's.
    private static func perMonth(_ yearly: Decimal) -> Decimal {
        var month = yearly / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &month, 2, .plain)
        return rounded
    }

    static var plusPackages: [PlusPackage] {
        let yearly = amount(usd: "19.99", lira: lira.yearly)
        return [
            PlusPackage(id: "demo.yearly", kind: .yearly, price: display(yearly),
                        pricePerMonth: display(perMonth(yearly)), trialDays: 7),
            PlusPackage(id: "demo.monthly", kind: .monthly,
                        price: display(amount(usd: "2.99", lira: lira.monthly))),
        ]
    }

    /// The catalog's shelf, priced the way the store would price it. `price`
    /// stays in dollars because packs are compared by it; only the text
    /// follows the storefront.
    static var sparklePacks: [SparklePack] {
        SparklePack.shelf.enumerated().map { index, pack in
            let shown = pack.price.map { usd in
                pricesInLira ? Decimal(string: lira.packs[min(index, lira.packs.count - 1)])! : usd
            }
            return SparklePack(id: pack.id, sparkles: pack.sparkles,
                               displayPrice: shown.map(display), price: pack.price)
        }
    }
    #else
    static var isOn: Bool { false }
    static var persona: String? { nil }
    static var suppressesPrompts: Bool { false }
    static func personaName(for id: UserID?) -> String? { nil }
    static func maskedMe(_ user: User?) -> User? { user }
    static func masked(_ user: User) -> User { user }
    static func masked(_ users: [User]) -> [User] { users }
    static var paywallFeature: ProFeature?? { nil }
    static var opensSparkleStore: Bool { false }
    static var forcesFreeHouse: Bool { false }
    static var groupsShopping: Bool { false }
    static var plusPackages: [PlusPackage] { [] }
    static var sparklePacks: [SparklePack] { [] }
    #endif
}
