import ComposableArchitecture
import Foundation

/// The person's own calendars, through EventKit.
///
/// No Google sign-in and no tokens: the phone already holds every calendar
/// account the person added in iOS Settings, and EventKit lists them as one set
/// of calendars. Everything here stays on the phone.
///
/// Nothing asks for access by itself. `requestAccess` is called by a screen
/// that has first said what NestZone will do with it (`CalendarAccessExplainer`),
/// and never at launch.
@DependencyClient
public struct DeviceCalendarClient: Sendable {
    /// Where access stands right now; cheap, and safe to ask on any thread.
    public var access: @Sendable () -> DeviceCalendarAccess = { .notDetermined }
    /// Shows the system prompt for full access, if it can still be shown, and
    /// answers with where access stands afterwards.
    public var requestAccess: @Sendable () async throws -> DeviceCalendarAccess
    /// The calendars a copy can be written into: writable ones only, across
    /// every account. Empty without full access.
    public var calendars: @Sendable () async -> [DeviceCalendar] = { [] }
    /// Every calendar worth offering to share, writable or not (a family
    /// calendar someone else owns is still the person's own to show), across
    /// every account. Birthdays are left out. Empty without full access.
    public var shareableCalendars: @Sendable () async -> [DeviceCalendar] = { [] }
    /// The events in `from...to` in these calendars, one per occurrence, off the
    /// main thread. Empty without full access.
    public var events: @Sendable (_ calendarIDs: [String], _ from: Date, _ to: Date) async -> [DeviceEvent] = { _, _, _ in [] }
    /// The calendar the phone itself would put a new event in, if there is one.
    public var defaultCalendarID: @Sendable () async -> String?
    /// The NestZone-marked events (`MirrorMarker`) in these calendars that have
    /// an occurrence in `from...to`, one per event. How a copy is found again
    /// when the identifier the phone remembers no longer names it.
    public var marked: @Sendable (_ calendarIDs: [String], _ from: Date, _ to: Date) async -> [DeviceMarkedEvent] = { _, _, _ in [] }
    /// Writes `draft` into `calendarID`: a new event when `existingID` is `nil`
    /// or no longer exists, otherwise that event, changed. Returns the event's
    /// identifier. A repeating draft is one repeating event, and an update
    /// reaches the whole series.
    ///
    /// Nothing is committed until `commit`. A new event answers with a
    /// provisional identifier, which `commit` resolves to the final one.
    public var save: @Sendable (_ draft: DeviceEventDraft, _ calendarID: String, _ existingID: String?) async throws -> String
    /// Deletes an event, and the rest of its series. Already gone is fine;
    /// without access it throws, because nothing was deleted.
    /// Not committed until `commit`, so a pass over many copies is one write
    /// to the calendar database and not one each.
    public var remove: @Sendable (_ eventID: String) async throws -> Void
    /// Makes the changes `save` and `remove` have queued permanent, and answers
    /// each provisional identifier with its final one. When it fails the queue
    /// is thrown away, so the caller knows none of it landed.
    public var commit: @Sendable () async throws -> [String: String]
    /// Which of these events still exist. How the mirror finds out the person
    /// deleted a copy by hand.
    public var existing: @Sendable (_ eventIDs: [String]) async -> Set<String> = { _ in [] }
    /// Makes a calendar of NestZone's own (a housemate's, "NestZone · Name"),
    /// in iCloud when the phone has it, else on the phone, and commits at once.
    /// Answers its identifier. Calendars made here are left out of
    /// `calendars` and `shareableCalendars`: nothing is copied into one by
    /// the house's mirror and none is shared back to the house.
    public var createCalendar: @Sendable (_ title: String, _ colorHex: String) async throws -> String
    /// Renames and recolours a calendar made by `createCalendar`.
    public var updateCalendar: @Sendable (_ id: String, _ title: String, _ colorHex: String) async throws -> Void
    /// Deletes a calendar made by `createCalendar` and everything in it.
    /// Already gone is fine.
    public var removeCalendar: @Sendable (_ id: String) async throws -> Void
    /// Which of these calendars still exist, whoever made them.
    public var calendarsExist: @Sendable (_ ids: [String]) async -> Set<String> = { _ in [] }
    /// A calendar of ours with exactly this title, if there is one: how a
    /// calendar is taken over again when the phone's memory of it was lost.
    public var findOwnCalendar: @Sendable (_ title: String) async -> String? = { _ in nil }
    /// Fires whenever the phone's calendar database changes, from any app
    /// (`EKEventStoreChanged`): including by the mirror's own writes, which
    /// find nothing to do the second time around.
    public var changes: @Sendable () -> AsyncStream<Void> = { .finished }
}

/// Why a write to the person's calendar did not happen.
public enum DeviceCalendarError: Error, Equatable, Sendable {
    /// The calendar it was meant for is gone (an account removed, say).
    case calendarMissing
    case noAccess
    /// No account the phone has would take a new calendar.
    case noSource
}

extension DependencyValues {
    public var deviceCalendar: DeviceCalendarClient {
        get { self[DeviceCalendarClient.self] }
        set { self[DeviceCalendarClient.self] = newValue }
    }
}

extension DeviceCalendarClient: TestDependencyKey {
    public static let testValue = DeviceCalendarClient()
    public static let previewValue = DeviceCalendarClient()
}
