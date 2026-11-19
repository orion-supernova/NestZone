import Foundation

/// Launch arguments for taking App Store screenshots without a live store
/// (`-storeDemo 1`, `-openPaywall calendar`, `-openSparkleStore 1`,
/// `-forceFreeHouse 1`). Compiled only under `DEBUG || MEASURE`: a release
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

    /// The house is treated as without Plus, to photograph what a lock looks like.
    static var forcesFreeHouse: Bool { defaults.bool(forKey: "forceFreeHouse") }

    /// Whether the demo prices in lira, the way a Turkish storefront would.
    private static var pricesInLira: Bool {
        Locale.current.region == .turkey || Locale.current.language.languageCode == .turkish
    }

    /// DEMO APPROXIMATIONS of Apple's Turkish price tiers, for screenshots
    /// only: NestZone.storekit carries USD prices alone and a real build asks
    /// the store. Yearly, monthly, then the four Sparkle packs in shelf order.
    private static let lira = (yearly: "749.99", monthly: "109.99",
                               packs: ["109.99", "329.99", "649.99", "1299.99"])

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
    static var paywallFeature: ProFeature?? { nil }
    static var opensSparkleStore: Bool { false }
    static var forcesFreeHouse: Bool { false }
    static var plusPackages: [PlusPackage] { [] }
    static var sparklePacks: [SparklePack] { [] }
    #endif
}
