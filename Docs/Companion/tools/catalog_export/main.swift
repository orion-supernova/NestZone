// Writes the server's copy of the companion catalog from the app's own Swift.
//
// The app's catalog (CompanionCatalog.swift, CompanionModels.swift,
// Holidays.swift) is the one source. This compiles those three files as they
// are, asks them every question the server has to answer — what each thing
// costs, how it is had, which holidays bring it and on which days — and writes
// the answers to backend/convex/lib/companionData.ts. The server never decides
// a price on its own; it reads this file. Run `export_catalog.sh` after any
// change to the catalog, in the same commit, and deploy the backend first.

import CryptoKit
import Foundation

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!

func dayString(_ date: Date) -> String {
    let p = utc.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
}

func price(_ price: Price) -> [String: Any] {
    switch price {
    case let .leaves(n): ["currency": "leaves", "amount": n]
    case let .sparkles(n): ["currency": "sparkles", "amount": n]
    }
}

func season(_ season: Season) -> [String: Any] {
    ["months": season.months, "followsNature": season.followsNature]
}

func reward(_ reward: Reward) -> [String: Any] {
    switch reward {
    case let .graduations(n): ["type": "graduations", "count": n]
    case .birthday: ["type": "birthday"]
    case .grownAll: ["type": "grownAll"]
    }
}

func access(_ access: Access) -> [String: Any] {
    switch access {
    case .free: ["type": "free"]
    case let .buy(p): ["type": "buy", "price": price(p)]
    case let .pack(pack): ["type": "pack", "pack": pack.rawValue]
    case let .season(s): ["type": "season", "season": season(s)]
    case .holiday: ["type": "holiday"]
    case let .holidaySale(p): ["type": "holidaySale", "price": price(p)]
    case let .seasonSale(p, s): ["type": "seasonSale", "price": price(p), "season": season(s)]
    case let .reward(r): ["type": "reward", "reward": reward(r)]
    }
}

func kind(_ kind: DecorItem.Kind) -> String {
    switch kind {
    case .above: "above"
    case .sky: "sky"
    case .weather: "weather"
    case .tree: "tree"
    case .wearing: "wearing"
    case .pot: "pot"
    case .floor: "floor"
    case .ground: "ground"
    }
}

/// The years the server can answer for. A holiday from a table that does not
/// list a year has no day that year, here as in the app.
let years = Array(2025...2036)

func starts(_ holiday: Holiday, region: String?) -> [String: String] {
    var out: [String: String] = [:]
    for year in years {
        if let first = holiday.start(in: year, region: region, calendar: utc) { out[String(year)] = dayString(first) }
    }
    return out
}

func regions(of rule: Holiday.Rule) -> [String] {
    if case let .regional(rules, _) = rule { return rules.keys.sorted() }
    return []
}

let holidays: [[String: Any]] = Holiday.all.map { holiday in
    var byRegion: [String: Any] = ["*": starts(holiday, region: nil)]
    for region in regions(of: holiday.rule) { byRegion[region] = starts(holiday, region: region) }
    return [
        "id": holiday.id.rawValue,
        "family": holiday.family.rawValue,
        "sells": holiday.sells,
        "days": holiday.days,
        "lead": holiday.lead,
        "decor": holiday.decor.map(\.rawValue),
        "starts": byRegion,
    ]
}

let isoRegions = Locale.Region.isoRegions.map(\.identifier).filter { $0.count == 2 }.sorted()
let base = Holiday.defaults(for: nil)
var defaults: [String: Any] = ["*": base.map(\.rawValue).sorted()]
for region in isoRegions {
    let ids = Holiday.defaults(for: region)
    if ids != base { defaults[region] = ids.map(\.rawValue).sorted() }
}

func coins(_ c: Coins) -> [String: Int] { ["leaves": c.leaves, "sparkles": c.sparkles] }

let catalog: [String: Any] = [
    "graduateAt": CompanionMath.graduateAt,
    "stages": ["plant": CompanionMath.plantStages, "pet": CompanionMath.petStages],
    "rewards": ["stage": coins(Rewards.stage), "graduation": coins(Rewards.graduation), "welcome": coins(Rewards.welcome)],
    "leavesPerSparkle": Exchange.leavesPerSparkle,
    "treeLimit": SceneLayout.treeLimit,
    "species": Species.allCases.map { ["id": $0.rawValue, "isPet": $0.isPet, "access": access($0.access)] as [String: Any] },
    "freeToHave": Species.freeToHave.map(\.rawValue).sorted(),
    "decor": DecorItem.allCases.map {
        ["id": $0.rawValue, "kind": kind($0.kind), "wintry": $0.isWintry, "access": access($0.access)] as [String: Any]
    },
    "packs": SpeciesPack.allCases.map {
        ["id": $0.rawValue, "price": price($0.price), "species": $0.species.map(\.rawValue)] as [String: Any]
    },
    "sparklePacks": SparklePack.shelf.map { ["id": $0.id, "sparkles": $0.sparkles] as [String: Any] },
    "holidays": holidays,
    "holidayDefaults": defaults,
    "southern": isoRegions.filter { Holiday.isSouthern($0) },
    "spotsForPets": Spot.forPets.map(\.rawValue),
]

let body = try JSONSerialization.data(withJSONObject: catalog, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
let version = SHA256.hash(data: body).prefix(6).map { String(format: "%02x", $0) }.joined()
let json = String(decoding: body, as: UTF8.self)

let out = """
// GENERATED by Docs/Companion/tools/catalog_export/export_catalog.sh from the
// app's CompanionCatalog.swift, CompanionModels.swift and Holidays.swift.
// Do not edit: change the Swift and run the script, in the same commit.
//
// The server checks every purchase against this, so the app and the server
// cannot price a thing differently. `CATALOG_VERSION` travels in
// `companion:forHome`, so a build can tell when its own catalog is not the
// server's.

import type { CatalogData } from "./companionTypes";

export const CATALOG_VERSION = "\(version)";

export const CATALOG: CatalogData = \(json);

"""

let target = CommandLine.arguments.dropFirst().first ?? "companionData.ts"
try out.write(toFile: target, atomically: true, encoding: .utf8)
print("wrote \(target) (catalog \(version))")
