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

    /// The real list prices, in USD, formatted for this phone's locale.
    static func price(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "USD").locale(.current))
    }

    static var plusPackages: [PlusPackage] {
        [
            PlusPackage(id: "demo.yearly", kind: .yearly, price: price(Decimal(string: "19.99")!),
                        pricePerMonth: price(Decimal(string: "1.67")!), trialDays: 7),
            PlusPackage(id: "demo.monthly", kind: .monthly, price: price(Decimal(string: "2.99")!)),
        ]
    }

    /// The catalog's shelf, priced the way the store would price it.
    static var sparklePacks: [SparklePack] {
        SparklePack.shelf.map {
            SparklePack(id: $0.id, sparkles: $0.sparkles, displayPrice: $0.price.map(price), price: $0.price)
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
