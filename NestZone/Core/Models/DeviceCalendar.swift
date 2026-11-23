import Foundation
import SwiftUI

/// Where the phone stands with calendar access, as EventKit says it.
///
/// Only `granted` (full access) can list the person's calendars and choose
/// among them; iOS's write-only access can use the default calendar and see no
/// other, which is not enough for "Into iCloud · Home and Gmail · Personal".
public enum DeviceCalendarAccess: Equatable, Sendable {
    case notDetermined
    case granted
    /// The person chose "Add Events Only" in the system prompt (or later in
    /// Settings): nothing here can read the calendar list.
    case writeOnly
    case denied
    /// Parental controls or a profile.
    case restricted

    /// The system prompt can still be shown.
    public var canAsk: Bool { self == .notDetermined }
}

/// One of the person's own calendars, as the phone lists them: across every
/// account added in iOS Settings (iCloud, Google, Exchange, ...), which is the
/// reason NestZone has no Google sign-in.
public struct DeviceCalendar: Equatable, Hashable, Identifiable, Sendable {
    /// `EKCalendar.calendarIdentifier`.
    public var id: String
    public var title: String
    /// `#RRGGBB`.
    public var colorHex: String
    /// `colorHex` as a colour, built once when the calendar is listed so a row
    /// never builds one while it draws.
    public let color: Color
    /// The account it lives in: "iCloud", "Gmail", "Work".
    public var accountTitle: String
    public var account: Account

    public enum Account: String, Equatable, Hashable, Sendable {
        case local, iCloud, exchange, calDAV, other
    }

    public init(
        id: String,
        title: String,
        colorHex: String,
        accountTitle: String,
        account: Account
    ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.color = Color(hex: colorHex)
        self.accountTitle = accountTitle
        self.account = account
    }
}

extension Sequence<DeviceCalendar> {
    /// Calendars under the account that owns them, in the order the phone
    /// gives accounts, which is the order the person knows from Calendar.
    public func groupedByAccount() -> [(account: String, calendars: [DeviceCalendar])] {
        var order: [String] = []
        var groups: [String: [DeviceCalendar]] = [:]
        for calendar in self {
            if groups[calendar.accountTitle] == nil { order.append(calendar.accountTitle) }
            groups[calendar.accountTitle, default: []].append(calendar)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }
}

/// What one mirrored event should look like in the person's calendar.
///
/// Built from a house event by the mirror and written by `DeviceCalendarClient`,
/// which knows nothing about NestZone's model beyond this and `Recurrence`.
public struct DeviceEventDraft: Equatable, Sendable {
    public var title: String
    public var location: String?
    /// The house event's notes. The client appends the line that says where to
    /// edit the copy; it is not part of the draft, so it can follow the
    /// language the phone is in when it is written.
    public var notes: String?
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    /// A series, as one repeating event. EventKit cannot hold an exception on
    /// a rule it was given (it has no way to say "not this Tuesday"), so a
    /// series with skipped or lifted-out dates is never sent as a rule; see
    /// `MirrorPlanner`.
    public var recurrence: Recurrence?
    /// Minutes before the start, one alert each. Empty unless the person asked
    /// for reminders to be copied.
    public var alarmMinutes: [Int]

    public init(
        title: String,
        location: String? = nil,
        notes: String? = nil,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        recurrence: Recurrence? = nil,
        alarmMinutes: [Int] = []
    ) {
        self.title = title
        self.location = location
        self.notes = notes
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.recurrence = recurrence
        self.alarmMinutes = alarmMinutes
    }

    /// Whether two drafts would write the same event, as one string that is
    /// stable across launches (a `hashValue` is not), so the id map can say
    /// "this copy is already right" without asking EventKit.
    public var fingerprint: String {
        var parts: [String] = [
            title, location ?? "", notes ?? "",
            String(Int(start.timeIntervalSince1970)), String(Int(end.timeIntervalSince1970)),
            isAllDay ? "1" : "0",
            alarmMinutes.sorted().map(String.init).joined(separator: ","),
        ]
        if let rule = recurrence {
            parts.append([
                rule.frequency.rawValue, String(rule.interval),
                rule.weekdays.sorted().map(String.init).joined(separator: ","),
                rule.until.map { String(Int($0.milliseconds)) } ?? "",
            ].joined(separator: "/"))
        }
        return parts.joined(separator: "\u{1F}")
    }
}
