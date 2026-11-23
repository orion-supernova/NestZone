import Foundation

/// Whose shared calendar this phone copies into its own calendar app, per
/// house. A person is on or off; the name travels with the choice so the
/// engine can title the calendar ("NestZone · Zeynep") without a members read.
///
/// Per device and off by default: it is this phone's calendar app that gets
/// the copy, and the sharer has to have said yes on their side first.
public struct CalendarCopyChoices: Codable, Equatable, Sendable {
    public struct Owner: Codable, Equatable, Sendable {
        public var name: String
        public init(name: String) { self.name = name }
    }

    public struct House: Codable, Equatable, Sendable {
        /// Housemate id -> the person, for everyone switched on.
        public var owners: [String: Owner] = [:]
        public init() {}
    }

    public var houses: [String: House] = [:]

    public init() {}

    public static func decode(_ raw: String) -> CalendarCopyChoices {
        guard let data = raw.data(using: .utf8), !raw.isEmpty,
              let choices = try? JSONDecoder().decode(CalendarCopyChoices.self, from: data)
        else { return CalendarCopyChoices() }
        return choices
    }

    public var raw: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    public func house(_ homeID: HomeID) -> House { houses[homeID.rawValue] ?? House() }

    public mutating func update(_ homeID: HomeID, _ change: (inout House) -> Void) {
        var house = house(homeID)
        change(&house)
        houses[homeID.rawValue] = house.owners.isEmpty ? nil : house
    }
}

/// What the phone remembers about the calendars and events it wrote for
/// housemates' shared calendars. Separate from `MirrorMap`: a shared item has
/// no id that survives a sync (the server replaces the rows), so it is known
/// by its fingerprint, `<calendarKey>/<startMs>-<endMs>`, and a moved item is
/// a removed copy and a new one.
public struct SharedCopyMap: Codable, Equatable, Sendable {
    /// One housemate's dedicated calendar in this phone's calendar app.
    public struct Calendar: Codable, Equatable, Sendable {
        public var homeID: String
        public var ownerID: String
        /// `EKCalendar.calendarIdentifier`.
        public var calendarID: String
        /// Title and colour as last written, so a rename or a new colour is
        /// written once and not on every pass.
        public var stamp: String
    }

    public struct Copy: Codable, Equatable, Sendable {
        public var homeID: String
        public var ownerID: String
        /// `EKEvent.eventIdentifier`; empty for one the person deleted by
        /// hand (`dismissed`).
        public var id: String
        public var fingerprint: String
        public var end: Date
        public var dismissed: Bool?
        /// Complete answers in a row that lacked this item, as the mirror counts.
        public var strikes: Int?
        public var strikeAt: Double?
    }

    /// `"<home>/<owner>"` -> calendar.
    public var calendars: [String: Calendar] = [:]
    /// `"<home>/<owner>/<calendarKey>/<startMs>-<endMs>"` -> copy.
    public var copies: [String: Copy] = [:]

    public init() {}

    public static func calendarKey(_ home: String, _ owner: String) -> String { "\(home)/\(owner)" }

    public var copyIdentifiers: Set<String> {
        Set(copies.values.compactMap { $0.id.isEmpty ? nil : $0.id })
    }
}
