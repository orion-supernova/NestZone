import Foundation

/// The MVP's file on this phone, offered to the house once.
///
/// Before the server version Nestie lived in `companion-<home>.json` in
/// Documents, one file per phone. A few test phones have one. The server takes
/// it only as far as the house could really have got (`companion:importLocal`),
/// and only from admin and test accounts; everybody else, and every phone
/// without a file, never calls it.
///
/// The file is never changed or deleted here: if the import is refused, or goes
/// wrong, it is still the only copy of what that phone grew. What stops a
/// second call is a mark kept apart from it, written once the server has
/// answered for good.
public struct LocalCompanion: Equatable, Sendable {
    public var current: Companion?
    public var album: [Graduate]
    public var leaves: Int
    public var welcomed: Bool
    public var owned: Set<String>
    public var ownedSpecies: Set<String>
    public var layout: SceneLayout
    public var holidays: [String]?
    public var paidStage: Int

    public init(_ house: CompanionHouse) {
        current = house.current
        album = house.album
        leaves = house.leaves
        welcomed = house.welcomed
        owned = house.owned
        ownedSpecies = house.ownedSpecies
        layout = house.layout
        holidays = house.holidays
        paidStage = house.paidStage
    }

    /// Whether the file holds anything the house could use. A file that was
    /// only ever opened and left is not worth a call.
    public var isWorthOffering: Bool {
        current != nil || !album.isEmpty || leaves > 0 || welcomed || holidays != nil
            || owned != [DecorItem.wateringCan.rawValue] || !ownedSpecies.isEmpty
    }

    // MARK: The file and its mark

    static func file(_ homeID: HomeID) -> URL {
        .documentsDirectory.appending(component: "companion-\(homeID.rawValue).json")
    }

    /// Per person and per home: the server takes one import for each pair, and
    /// two people sharing a phone each have their own to make.
    private static func markKey(_ homeID: HomeID, _ userID: UserID) -> String {
        "companionImported.\(userID.rawValue).\(homeID.rawValue)"
    }

    /// What this phone has to offer for this home, if it has not been offered
    /// already by this person: `nil` for no file, an unreadable one, an empty
    /// one, or one the server has answered for.
    public static func pending(for homeID: HomeID, userID: UserID, defaults: UserDefaults = .standard) -> LocalCompanion? {
        guard !defaults.bool(forKey: markKey(homeID, userID)),
              let data = try? Data(contentsOf: file(homeID)),
              let house = try? JSONDecoder().decode(CompanionHouse.self, from: data)
        else { return nil }
        let local = LocalCompanion(house)
        return local.isWorthOffering ? local : nil
    }

    /// Written when the server has answered for good: with an outcome, or
    /// with an error that asking again would only repeat. Not after a failure
    /// to get through at all (`AppError.isTransport`): a dropped connection
    /// should be tried again next launch.
    public static func markOffered(_ homeID: HomeID, userID: UserID, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: markKey(homeID, userID))
    }
}
