import ComposableArchitecture
import Foundation
import ConvexMobile

/// Profile lookups for people other than the signed-in user.
@DependencyClient
public struct UsersClient: Sendable {
    /// Resolves several ids at once. Screens used to loop and fetch one user per
    /// row, which is where the message list's per-bubble request storm came from.
    public var byIDs: @Sendable ([UserID]) async throws -> [User] = { _ in [] }
}

extension UsersClient: DependencyKey {
    public static let liveValue = UsersClient(
        byIDs: { ids in
            guard !ids.isEmpty else { return [] }
            return try await ConvexConnection.shared.first(
                "users:byIds",
                args: ["ids": ids.map { $0 as ConvexEncodable? }],
                as: [User].self
            )
        }
    )

    public static let testValue = UsersClient()
}

extension DependencyValues {
    public var users: UsersClient {
        get { self[UsersClient.self] }
        set { self[UsersClient.self] = newValue }
    }
}
