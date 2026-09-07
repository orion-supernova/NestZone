import ComposableArchitecture
import Foundation

/// The Home tab's counters, computed server-side.
///
/// The client used to derive these by downloading three whole collections and
/// filtering by date in Swift, on every appearance of the tab. See
/// `convex/stats.ts`.
@DependencyClient
public struct StatsClient: Sendable {
    public var forHome: @Sendable (HomeID) -> AsyncThrowingStream<HomeStats, any Error> = { _ in .never }
    /// Who did what, over `window`. A separate subscription from `forHome` on
    /// purpose: this one reads only tasks and membership, so a new message does
    /// not invalidate it and redraw the ring.
    public var contributions: @Sendable (HomeID, ContributionWindow)
        -> AsyncThrowingStream<HomeContributions, any Error> = { _, _ in .never }
}

extension StatsClient: DependencyKey {
    public static let liveValue = StatsClient(
        forHome: { homeID in
            ConvexConnection.shared.subscribe(
                to: "stats:forHome", args: ["homeId": homeID], as: HomeStats.self
            )
        },
        contributions: { homeID, window in
            ConvexConnection.shared.subscribe(
                to: "stats:contributions",
                args: [
                    "homeId": homeID,
                    // `.convexNumber`, not a bare `Int`: convex-swift encodes an
                    // `Int` as int64 and `v.number()` is float64, which the
                    // validator rejects outright.
                    "windowDays": window.days.convexNumber,
                    // The server has no timezone. Without this the day buckets
                    // and the streak's idea of "today" are the device's only by
                    // coincidence.
                    "tzOffsetMinutes": (TimeZone.current.secondsFromGMT() / 60).convexNumber,
                ],
                as: HomeContributions.self
            )
        }
    )

    public static let testValue = StatsClient()
}

extension DependencyValues {
    public var stats: StatsClient {
        get { self[StatsClient.self] }
        set { self[StatsClient.self] = newValue }
    }
}
