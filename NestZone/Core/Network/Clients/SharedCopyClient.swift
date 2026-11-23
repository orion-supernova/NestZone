import ComposableArchitecture
import Foundation

/// A housemate's shared calendar, copied into a calendar of its own on the
/// person's phone ("NestZone · Zeynep"), so it can be hidden with one tap in
/// any calendar app.
///
/// The housemate decides first (`allow_copy` on their share, read off every
/// answer), then this phone's person switches the copy on, per house and per
/// housemate. Nothing here reaches the server; the live value is
/// `SharedCopyEngine`. The house's own events are `CalendarMirrorClient`'s.
@DependencyClient
public struct SharedCopyClient: Sendable {
    /// Brings the housemates' calendars in line with `request`. Serialised, as
    /// the mirror's is.
    public var sync: @Sendable (_ request: SharedCopyRequest, _ device: DeviceCalendarClient) async throws -> SharedCopySummary
    /// Deletes one housemate's calendar from the phone, with its copies.
    /// Answers whether it is gone.
    public var removeOwner: @Sendable (_ device: DeviceCalendarClient, _ home: HomeID, _ owner: String) async -> Bool = { _, _, _ in true }
    /// Deletes every calendar made for housemates (all houses, or one).
    public var removeAll: @Sendable (_ device: DeviceCalendarClient, _ home: HomeID?) async -> Int = { _, _ in 0 }
    /// The houses this phone holds housemates' calendars for.
    public var knownHomes: @Sendable () async -> Set<HomeID> = { [] }
}

public struct SharedCopyOwner: Equatable, Sendable {
    public var name: String
    public var colorHex: String
    public init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }
}

public struct SharedCopyRequest: Sendable {
    public var homeID: HomeID
    /// Housemate id -> who, for everyone switched on.
    public var owners: [String: SharedCopyOwner]
    /// What `calendarShare:inRange` last said, in the window.
    public var items: [SharedBusyItem]
    public var windowStart: Date
    public var now: Date
    public var answeredAt: Date
    /// The keys of the answer before this one, when that was complete and not
    /// empty. A key in it that is not in this one was seen to go (the item
    /// moved or ended); without it an absent item is only a doubt.
    public var previousKeys: Set<String>?

    /// `IN_RANGE_CAP` in `backend/convex/calendarShare.ts`: an answer this
    /// long may be missing rows, and is never read as "they were deleted".
    public static let answerLimit = 1000
    public var isTruncated: Bool { items.count >= Self.answerLimit }

    public init(
        homeID: HomeID,
        owners: [String: SharedCopyOwner],
        items: [SharedBusyItem],
        windowStart: Date,
        now: Date = .now,
        answeredAt: Date = .now,
        previousKeys: Set<String>? = nil
    ) {
        self.homeID = homeID
        self.owners = owners
        self.items = items
        self.windowStart = windowStart
        self.now = now
        self.answeredAt = answeredAt
        self.previousKeys = previousKeys
    }
}

public struct SharedCopySummary: Equatable, Sendable {
    public var created = 0
    public var updated = 0
    public var removed = 0
    public var failed = 0
    public var didSync = true
    /// Housemates whose calendar the person deleted in the Calendar app: the
    /// switch goes off, and nothing is recreated.
    public var dismissedOwners: Set<String> = []

    public init() {}

    public mutating func add(_ other: SharedCopySummary) {
        didSync = didSync || other.didSync
        created += other.created
        updated += other.updated
        removed += other.removed
        failed += other.failed
        dismissedOwners.formUnion(other.dismissedOwners)
    }
}

extension DependencyValues {
    public var sharedCopy: SharedCopyClient {
        get { self[SharedCopyClient.self] }
        set { self[SharedCopyClient.self] = newValue }
    }
}

extension SharedCopyClient: TestDependencyKey {
    public static let testValue = SharedCopyClient()
    public static let previewValue = SharedCopyClient()
}
