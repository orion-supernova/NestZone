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
}

extension StatsClient: DependencyKey {
    public static let liveValue = StatsClient(
        forHome: { homeID in
            ConvexConnection.shared.subscribe(
                to: "stats:forHome", args: ["homeId": homeID], as: HomeStats.self
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
