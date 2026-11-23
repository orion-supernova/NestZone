import ComposableArchitecture
import Foundation

/// House events, copied into the person's own calendars.
///
/// The house is the source of truth and the copies follow it: a changed time,
/// a new title, a skipped date or a deleted event reaches them on the next
/// sync, and a copy edited in another app is put back. What the phone
/// remembers of its copies (`MirrorMap`) is what keeps them from being added
/// twice and what lets anything that reads the person's calendars tell a
/// NestZone copy from an event of their own (`isCopy`).
///
/// Nothing here reaches the server. The live value is `MirrorEngine`.
@DependencyClient
public struct CalendarMirrorClient: Sendable {
    /// Brings the person's calendars in line with `request`: creates what is
    /// missing, updates what moved, removes what the house dropped or the
    /// settings no longer want. Serialised: a request that arrives while one is
    /// running is folded into a second pass, never run alongside it.
    public var sync: @Sendable (_ request: MirrorRequest, _ device: DeviceCalendarClient) async throws -> MirrorSummary
    /// Deletes every copy this phone has made, in every home, and forgets them.
    /// Returns how many events it removed.
    public var removeAll: @Sendable (_ device: DeviceCalendarClient) async -> Int = { _ in 0 }
    /// How many copies exist, for "Remove the copies?" to know whether to ask.
    public var copyCount: @Sendable () async -> Int = { 0 }
    /// Pins one event to the calendars chosen in the composer's "Also add to"
    /// (`nil` goes back to following the setting; an empty list means "not this
    /// one"). Persisted, and announced on `overridesChanged`.
    public var setOverride: @Sendable (_ homeID: HomeID, _ eventID: EventID, _ calendarIDs: [String]?) async -> Void
    public var override: @Sendable (_ homeID: HomeID, _ eventID: EventID) async -> [String]? = { _, _ in nil }
    /// Whether any event in this home is pinned, which is a reason to follow
    /// the house's calendar even with copying off.
    public var hasOverrides: @Sendable (_ homeID: HomeID) async -> Bool = { _ in false }
    /// Whether this `EKEvent.eventIdentifier` is a copy NestZone wrote. What
    /// sharing the person's calendars with the house must ask before it uploads
    /// an event, or the house would see every event twice.
    public var isCopy: @Sendable (_ eventIdentifier: String) async -> Bool = { _ in false }
    /// Every identifier NestZone wrote, in one read, for a pass over many
    /// events.
    public var copyIdentifiers: @Sendable () async -> Set<String> = { [] }
    /// Fires when an override changed, so the app-wide mirror syncs again.
    public var overridesChanged: @Sendable () -> AsyncStream<Void> = { .finished }
}

/// What one sync is asked to make true.
public struct MirrorRequest: Sendable {
    public var homeID: HomeID
    public var userID: UserID?
    public var mode: CalendarCopyMode
    /// The calendars the setting copies into.
    public var targets: [String]
    public var copyReminders: Bool
    /// The house's events in `windowStart...windowEnd`, as the server expanded
    /// them.
    public var occurrences: [EventOccurrence]
    public var windowStart: Date
    public var windowEnd: Date
    public var now: Date

    public init(
        homeID: HomeID,
        userID: UserID?,
        mode: CalendarCopyMode,
        targets: [String],
        copyReminders: Bool,
        occurrences: [EventOccurrence],
        windowStart: Date,
        windowEnd: Date,
        now: Date = .now
    ) {
        self.homeID = homeID
        self.userID = userID
        self.mode = mode
        self.targets = targets
        self.copyReminders = copyReminders
        self.occurrences = occurrences
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.now = now
    }
}

public struct MirrorSummary: Equatable, Sendable {
    public var created = 0
    public var updated = 0
    public var removed = 0
    /// Copies the person deleted by hand, which are not recreated.
    public var dismissed = 0
    public var failed = 0

    public init() {}

    public mutating func add(_ other: MirrorSummary) {
        created += other.created
        updated += other.updated
        removed += other.removed
        dismissed += other.dismissed
        failed += other.failed
    }
}

extension Notification.Name {
    static let nestZoneMirrorOverridesChanged = Notification.Name("nestZoneMirrorOverridesChanged")
}

extension DependencyValues {
    public var calendarMirror: CalendarMirrorClient {
        get { self[CalendarMirrorClient.self] }
        set { self[CalendarMirrorClient.self] = newValue }
    }
}

extension CalendarMirrorClient: TestDependencyKey {
    public static let testValue = CalendarMirrorClient()
    public static let previewValue = CalendarMirrorClient()
}
