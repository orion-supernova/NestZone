import CryptoKit
import Foundation

/// How much of one of the person's own calendars the house sees.
///
/// `off` exists only on the phone ("not shared"); the server holds `busy` and
/// `details` and nothing else.
public enum CalendarShareLevel: String, CaseIterable, Codable, Identifiable, Sendable {
    case off
    /// Start, end and all-day. The title never leaves the phone.
    case busy
    /// The title and the location too. Never notes, attendees or links.
    case details

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .off: L10n.calendarShareLevelOff
        case .busy: L10n.calendarShareLevelBusy
        case .details: L10n.calendarShareLevelDetails
        }
    }

    public var isShared: Bool { self != .off }
}

/// The name a calendar is known to the server by: a hash of EventKit's own
/// identifier, so what the server holds says nothing about the phone's calendar
/// database and is the same on every launch.
public enum CalendarShareKey {
    /// Sixteen hex characters of SHA-256 over the calendar's identifier.
    public static func key(for calendarIdentifier: String) -> String {
        SHA256.hash(data: Data(calendarIdentifier.utf8))
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - What the server holds

/// One calendar of the caller's, as the server lists it.
public struct SharedCalendarEntry: Codable, Equatable, Hashable, Sendable {
    public var key: String
    public var name: String
    /// `#RRGGBB`.
    public var colorHex: String?
    public var level: CalendarShareLevel

    enum CodingKeys: String, CodingKey {
        case key, name, color, level
    }

    public init(key: String, name: String, colorHex: String? = nil, level: CalendarShareLevel) {
        self.key = key
        self.name = name
        self.colorHex = colorHex
        self.level = level
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        colorHex = try? c.decodeIfPresent(String.self, forKey: .color)
        // Unknown from a newer server reads as the lesser of the two.
        level = c.decodeLenient(CalendarShareLevel.self, forKey: .level, default: .busy)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(key, forKey: .key)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(colorHex, forKey: .color)
        try c.encode(level, forKey: .level)
    }
}

/// `calendarShare:mine`: what this person shares in this house.
public struct CalendarShareRow: Decodable, Equatable, Sendable {
    public var calendars: [SharedCalendarEntry]
    public var windowDays: Int
    /// Housemates may copy these calendars into their own. Off unless the
    /// person said so (`allow_copy`; absent on the server is off).
    public var allowCopy: Bool
    /// When the phone last uploaded, if it ever has.
    public var syncedAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case calendars
        case windowDays = "window_days"
        case allowCopy = "allow_copy"
        case syncedAt = "synced_at"
    }

    public init(
        calendars: [SharedCalendarEntry] = [],
        windowDays: Int = 56,
        allowCopy: Bool = false,
        syncedAt: Timestamp? = nil
    ) {
        self.calendars = calendars
        self.windowDays = windowDays
        self.allowCopy = allowCopy
        self.syncedAt = syncedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calendars = (try? c.decodeIfPresent([SharedCalendarEntry].self, forKey: .calendars)) ?? []
        windowDays = c.decodeNumber(forKey: .windowDays, default: 56)
        allowCopy = (try? c.decodeIfPresent(Bool.self, forKey: .allowCopy)) ?? false
        syncedAt = try? c.decodeIfPresent(Timestamp.self, forKey: .syncedAt)
    }
}

/// A housemate's shared calendar item, as `calendarShare:inRange` returns it.
///
/// Not an `EventOccurrence` and never mistaken for one: it cannot be edited,
/// answered, planned or counted, and nothing outside the Calendar screen reads
/// it.
public struct SharedBusyItem: Decodable, Identifiable, Equatable, Hashable, Sendable {
    public var id: String
    public var userID: UserID
    public var calendarKey: String
    public var calendarName: String
    public var colorHex: String?
    public var level: CalendarShareLevel
    public var startsAt: Timestamp
    public var endsAt: Timestamp
    public var isAllDay: Bool
    /// The owner lets housemates copy this into their own calendar. Read off
    /// the owner's share on every answer, so a withdrawn consent reaches the
    /// copiers at their next sync.
    public var allowCopy: Bool
    /// Only at `details`.
    public var title: String?
    public var location: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userID = "user_id"
        case calendarKey = "calendar_key"
        case calendarName = "calendar_name"
        case colorHex = "color"
        case level
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isAllDay = "is_all_day"
        case allowCopy = "allow_copy"
        case title, location
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userID = try c.decode(UserID.self, forKey: .userID)
        calendarKey = try c.decode(String.self, forKey: .calendarKey)
        calendarName = (try? c.decodeIfPresent(String.self, forKey: .calendarName)) ?? ""
        colorHex = try? c.decodeIfPresent(String.self, forKey: .colorHex)
        level = c.decodeLenient(CalendarShareLevel.self, forKey: .level, default: .busy)
        startsAt = try c.decode(Timestamp.self, forKey: .startsAt)
        endsAt = try c.decode(Timestamp.self, forKey: .endsAt)
        isAllDay = (try? c.decodeIfPresent(Bool.self, forKey: .isAllDay)) ?? false
        allowCopy = (try? c.decodeIfPresent(Bool.self, forKey: .allowCopy)) ?? false
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        location = try? c.decodeIfPresent(String.self, forKey: .location)
    }

    public init(
        id: String,
        userID: UserID,
        calendarKey: String = "",
        calendarName: String = "",
        level: CalendarShareLevel = .busy,
        startsAt: Timestamp,
        endsAt: Timestamp,
        isAllDay: Bool = false,
        allowCopy: Bool = false,
        title: String? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.allowCopy = allowCopy
        self.userID = userID
        self.calendarKey = calendarKey
        self.calendarName = calendarName
        self.colorHex = nil
        self.level = level
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isAllDay = isAllDay
        self.title = title
        self.location = location
    }

    public var start: Date { startsAt.date }
    public var end: Date { endsAt.date }

    /// What the item says about itself, if the person shared that much.
    public var shownTitle: String? {
        guard level == .details, let title, !title.isEmpty else { return nil }
        return title
    }

    /// "14:00 – 15:30", or "All day", in the app's own language.
    public var timeText: String {
        if isAllDay { return String(localized: L10n.calendarAllDay) }
        let style = Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale)
        let from = start.formatted(style)
        guard end > start else { return from }
        return "\(from) – \(end.formatted(style))"
    }

    public var isPast: Bool { end < Date() }

    /// The days it appears on. Same rule as `EventOccurrence.days`: an item that
    /// ends exactly at midnight does not claim the next day.
    public func days(_ calendar: Calendar = .current) -> [CalendarDay] {
        let first = CalendarDay(start, calendar: calendar)
        var lastInstant = end
        if lastInstant > start, lastInstant == calendar.startOfDay(for: lastInstant) {
            lastInstant = lastInstant.addingTimeInterval(-1)
        }
        let last = CalendarDay(lastInstant, calendar: calendar)
        guard last > first else { return [first] }
        var days: [CalendarDay] = [first]
        var cursor = first
        while cursor < last, days.count < 70 {
            cursor = cursor.advanced(by: 1, calendar: calendar)
            days.append(cursor)
        }
        return days
    }
}

/// `calendarShare:housemates`: one housemate who shares calendars with this
/// house, and whether they let it be copied.
public struct HousemateShare: Decodable, Equatable, Identifiable, Sendable {
    public var userID: UserID
    public var allowCopy: Bool
    public var id: String { userID.rawValue }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case allowCopy = "allow_copy"
    }

    public init(userID: UserID, allowCopy: Bool) {
        self.userID = userID
        self.allowCopy = allowCopy
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(UserID.self, forKey: .userID)
        allowCopy = (try? c.decodeIfPresent(Bool.self, forKey: .allowCopy)) ?? false
    }
}

/// One item the phone uploads for one calendar.
public struct SharedItemUpload: Equatable, Sendable {
    public var startsAt: Date
    public var endsAt: Date
    public var isAllDay: Bool
    public var title: String?
    public var location: String?

    public init(
        startsAt: Date,
        endsAt: Date,
        isAllDay: Bool,
        title: String? = nil,
        location: String? = nil
    ) {
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isAllDay = isAllDay
        self.title = title
        self.location = location
    }
}

// MARK: - What the phone remembers

/// Which of this phone's calendars are shared with which house, and at what
/// level. Per device and per house: the calendars are on this phone, and what
/// is shared with a partner and with flatmates are different things.
///
/// Kept as JSON in one app-storage string (`calendarShareChoicesRaw`) because
/// app storage holds scalars. A calendar absent from `levels` is not shared.
public struct CalendarShareChoices: Codable, Equatable, Sendable {
    public struct House: Codable, Equatable, Sendable {
        /// The master switch.
        public var isOn = false
        /// Calendar key -> level, for the ones that are shared.
        public var levels: [String: CalendarShareLevel] = [:]
        /// Every calendar key the person has already been shown under this
        /// switch, so only a calendar that turns up later gets the default for
        /// new ones.
        public var known: Set<String> = []
        /// The server still has to be told to forget everything: the switch went
        /// off, and the call may not have got through yet (a phone in a lift).
        /// Kept until `calendarShare:stop` answers, so "off" is never only a
        /// picture on this screen.
        public var stopAll = false
        /// The same for single calendars set back to Off.
        public var stopKeys: Set<String> = []
        /// "Housemates can add my calendar to theirs", as this phone last set
        /// it. `nil` until it is touched here, so a second phone that never
        /// asked does not overwrite the first one's answer. Optional so
        /// choices written before it existed still decode.
        public var allowCopy: Bool?

        public init() {}

        public func level(of key: String) -> CalendarShareLevel { levels[key] ?? .off }
    }

    public var houses: [String: House] = [:]

    public init() {}

    public static func decode(_ raw: String) -> CalendarShareChoices {
        guard let data = raw.data(using: .utf8), !raw.isEmpty,
              let choices = try? JSONDecoder().decode(CalendarShareChoices.self, from: data)
        else { return CalendarShareChoices() }
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
        houses[homeID.rawValue] = house
    }

    /// Gives the calendars this house has not met yet the default for new ones.
    /// A house whose switch is off learns nothing: turning it on is what marks
    /// every calendar then on the phone as known and not shared.
    public mutating func adoptNew(_ homeID: HomeID, keys: [String], defaultLevel: CalendarShareLevel) {
        guard house(homeID).isOn else { return }
        let fresh = keys.filter { !house(homeID).known.contains($0) }
        guard !fresh.isEmpty else { return }
        update(homeID) { house in
            for key in fresh {
                house.known.insert(key)
                if defaultLevel.isShared { house.levels[key] = defaultLevel }
            }
        }
    }
}
