import ComposableArchitecture
import Foundation

/// Whether the open house has NestZone Plus, and the nudge that makes the
/// server look again.
///
/// The phone never says "I'm Plus": after a purchase, a restore, and once per
/// launch it asks the server to check with RevenueCat (`pro:refresh`), and
/// everything on screen follows the live `pro:status`.
@DependencyClient
public struct ProClient: Sendable {
    /// Live. A purchase on one phone reaches every phone in the house.
    public var status: @Sendable (HomeID) -> AsyncThrowingStream<ProStatusPayload, any Error> = { _ in .never }
    public var refresh: @Sendable () async throws -> ProRefreshResult
}

extension ProClient: DependencyKey {
    public static let liveValue = ProClient(
        status: { homeID in
            ConvexConnection.shared.subscribe(
                to: "pro:status", args: ["homeId": homeID], as: ProStatusPayload.self
            )
        },
        refresh: {
            try await ConvexConnection.shared.act("pro:refresh", args: [:], as: ProRefreshResult.self)
        }
    )

    public static let testValue = ProClient()
}

extension DependencyValues {
    public var pro: ProClient {
        get { self[ProClient.self] }
        set { self[ProClient.self] = newValue }
    }
}
