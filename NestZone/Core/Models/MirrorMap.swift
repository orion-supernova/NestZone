import Foundation

/// What the phone remembers about the copies it has put in the person's
/// calendars: which house event each one is, so it is updated and never added
/// twice, and so anything that reads the person's calendars (sharing them with
/// the house, later) can tell a NestZone copy from an event of their own and
/// leave it out.
///
/// Held on the phone only. Persisted by `CalendarMirrorClient`'s live value as
/// JSON in Application Support, and never sent anywhere.
public struct MirrorMap: Codable, Equatable, Sendable {
    /// One thing that was copied: a series (one repeating event) or one
    /// occurrence of a series that EventKit could not hold as a rule.
    public struct Entry: Codable, Equatable, Sendable {
        public var homeID: String
        public var eventID: String
        /// Calendar id -> the copy in it.
        public var copies: [String: Copy]
        /// Calendars the person deleted this copy from by hand. Not recreated:
        /// it was their call, and recreating it would be the app arguing.
        public var dismissed: Set<String>
        /// When the copy stops mattering: a one-off's end, a series' last day,
        /// `nil` for a series that never ends. An entry whose event is missing
        /// from a window that starts after this is just old, not deleted.
        public var lastEnd: Date?
        /// How many complete answers in a row have lacked this event, and when
        /// the last of them arrived. A copy is deleted only on the second, so
        /// one odd answer is a delay and never a deletion. Optional so a map
        /// written before it existed still decodes.
        public var strikes: Int?
        public var strikeAt: Double?

        public init(
            homeID: String,
            eventID: String,
            copies: [String: Copy] = [:],
            dismissed: Set<String> = [],
            lastEnd: Date? = nil
        ) {
            self.homeID = homeID
            self.eventID = eventID
            self.copies = copies
            self.dismissed = dismissed
            self.lastEnd = lastEnd
        }
    }

    public struct Copy: Codable, Equatable, Sendable {
        /// `EKEvent.eventIdentifier`.
        public var id: String
        /// What was last written to it (`DeviceEventDraft.fingerprint`).
        public var fingerprint: String

        public init(id: String, fingerprint: String) {
            self.id = id
            self.fingerprint = fingerprint
        }
    }

    /// `"<homeID>/<copyKey>"` -> entry. A copy key is the event id for a
    /// series copy and `"<eventID>@<startMillis>"` for one occurrence.
    public var entries: [String: Entry] = [:]
    /// `"<homeID>/<eventID>"` -> the calendars the composer's "Also add to"
    /// chose for that event, which win over the setting. An empty list is a
    /// choice too: "not this one".
    public var overrides: [String: [String]] = [:]
    /// When each override was set (seconds since 1970), so one for an event
    /// that never turned up can age out. Optional for the same reason.
    public var overrideDates: [String: Double]?

    public init() {}

    public static func entryKey(_ homeID: String, _ copyKey: String) -> String {
        "\(homeID)/\(copyKey)"
    }

    public static func overrideKey(_ homeID: String, _ eventID: String) -> String {
        "\(homeID)/\(eventID)"
    }

    /// Every `EKEvent.eventIdentifier` NestZone wrote.
    public var copyIdentifiers: Set<String> {
        var ids: Set<String> = []
        for entry in entries.values {
            for copy in entry.copies.values { ids.insert(copy.id) }
        }
        return ids
    }

    /// Whether `identifier` (an `EKEvent.eventIdentifier`) is a NestZone copy.
    public func isCopy(_ identifier: String) -> Bool {
        entries.values.contains { $0.copies.values.contains { $0.id == identifier } }
    }
}

/// The mark every copy carries in its URL field:
/// `nestzone://event/<homeID>/<copyKey>`.
///
/// A copy used to be known only by the identifier EventKit gave it, which is
/// the phone's own: a restore, a second phone writing into the same iCloud
/// calendar, or a map lost between the write and the save made a copy nobody
/// could tell from a stranger, and a second one was added. The mark is the copy
/// saying what it is. Nothing handles the scheme; it only has to be unique.
public enum MirrorMarker {
    public static let scheme = "nestzone"

    public static func url(home: String, copyKey: String) -> URL? {
        URL(string: "\(scheme)://event/\(home)/\(copyKey)")
    }

    public static func isMarker(_ url: URL?) -> Bool {
        url?.scheme?.lowercased() == scheme
    }
}
