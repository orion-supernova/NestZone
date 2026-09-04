import ComposableArchitecture
import Foundation

/// Homes and their membership.
///
/// `homes:listMine` used to be fetched independently by `HomeSelectionManager`,
/// `TabBarScreenViewModel` and `MessagesView` — three copies of the same data,
/// refreshed at different times and free to disagree. There is one subscription
/// now, owned by the app-level reducer.
@DependencyClient
public struct HomesClient: Sendable {
    /// Live list of the homes the signed-in user belongs to.
    public var mine: @Sendable () -> AsyncThrowingStream<[Home], any Error> = { .never }
    /// Live membership of one home.
    public var members: @Sendable (HomeID) -> AsyncThrowingStream<[User], any Error> = { _ in .never }
    public var create: @Sendable (String) async throws -> Void
    public var join: @Sendable (String) async throws -> Void
    /// Leaves `home`.
    ///
    /// If the caller is its last member the server cascades the entire home away
    /// — every task, shopping item, note, recipe, movie list, poll, conversation
    /// and message under it, plus the `home_id` mirror on every user (see
    /// `convex/lib/relations.ts` `cascadeDeleteHome`). That is deliberate: a home
    /// with no members can never satisfy `requireHomeMember` again, so leaving it
    /// behind would strand its contents forever. With other members remaining,
    /// only this user is removed.
    public var leave: @Sendable (HomeID) async throws -> Void
}

extension HomesClient: DependencyKey {
    public static let liveValue = HomesClient(
        mine: { ConvexConnection.shared.subscribe(to: "homes:listMine", as: [Home].self) },
        members: { homeID in
            ConvexConnection.shared.subscribe(
                to: "homes:members", args: ["homeId": homeID], as: [User].self
            )
        },
        create: { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.homeNameEmpty",
                    defaultValue: "Give your home a name."
                ))
            }
            try await ConvexConnection.shared.mutate("homes:create", args: ["name": trimmed])
        },
        join: { code in
            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.inviteCodeEmpty",
                    defaultValue: "Enter an invite code."
                ))
            }
            try await ConvexConnection.shared.mutate("homes:join", args: ["inviteCode": trimmed])
        },
        leave: { homeID in
            try await ConvexConnection.shared.mutate("homes:leave", args: ["homeId": homeID])
        }
    )

    public static let testValue = HomesClient()
}

extension DependencyValues {
    public var homes: HomesClient {
        get { self[HomesClient.self] }
        set { self[HomesClient.self] = newValue }
    }
}
