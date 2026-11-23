import ComposableArchitecture
import ConvexMobile
import Foundation

/// Which pushes this person wants, and their quiet hours. See
/// `NotificationPrefs`.
@DependencyClient
public struct NotificationPrefsClient: Sendable {
    /// Live. A change on one phone reaches the others.
    public var mine: @Sendable () -> AsyncThrowingStream<NotificationPrefs, any Error> = { .never }

    /// Sends the whole state, never a delta: two phones writing at once end on
    /// one person's complete choice, not a blend.
    public var set: @Sendable (NotificationPrefs) async throws -> NotificationPrefs
}

extension NotificationPrefsClient: DependencyKey {
    public static let liveValue = NotificationPrefsClient(
        mine: {
            ConvexConnection.shared.subscribe(to: "notificationPrefs:mine", args: [:], as: NotificationPrefs.self)
        },
        set: { prefs in
            let off: [ConvexEncodable?] = prefs.off.sorted()
            // Sent even when nil: an absent `quiet` would read as "leave it
            // alone", and switching quiet hours off has to be sayable.
            let quiet: ConvexEncodable? = prefs.quiet.map { q in
                let fields: [String: ConvexEncodable?] = [
                    "start": q.start.convexNumber,
                    "end": q.end.convexNumber,
                    "timeZone": q.timeZone,
                ]
                return fields
            }
            return try await ConvexConnection.shared.mutate(
                "notificationPrefs:set",
                args: ["off": off, "quiet": quiet],
                as: NotificationPrefs.self,
                presentsPaywall: false
            )
        }
    )

    public static let testValue = NotificationPrefsClient()
}

extension DependencyValues {
    public var notificationPrefs: NotificationPrefsClient {
        get { self[NotificationPrefsClient.self] }
        set { self[NotificationPrefsClient.self] = newValue }
    }
}
