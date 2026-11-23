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
    /// The calendar the phone itself would put a new event in, if there is one.
    public var defaultCalendarID: @Sendable () async -> String?
    /// Writes `draft` into `calendarID`: a new event when `existingID` is `nil`
    /// or no longer exists, otherwise that event, changed. Returns the event's
    /// identifier. A repeating draft is one repeating event, and an update
    /// reaches the whole series.
    public var save: @Sendable (_ draft: DeviceEventDraft, _ calendarID: String, _ existingID: String?) async throws -> String
    /// Deletes an event, and the rest of its series. Already gone is fine.
    public var remove: @Sendable (_ eventID: String) async throws -> Void
    /// Which of these events still exist. How the mirror finds out the person
    /// deleted a copy by hand.
    public var existing: @Sendable (_ eventIDs: [String]) async -> Set<String> = { _ in [] }
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
