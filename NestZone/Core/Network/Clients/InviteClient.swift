import ComposableArchitecture
import ConvexMobile
import Foundation

/// House invites by link and QR code (`convex/invites.ts`), beside the invite
/// code and never instead of it.
@DependencyClient
public struct InviteClient: Sendable {
    /// A new invite. `link` lasts a week, `qr` ten minutes (and revokes the
    /// caller's earlier `qr`). `maxUses` nil is unlimited.
    public var create: @Sendable (_ homeID: HomeID, _ kind: Kind, _ maxUses: Int?) async throws -> HomeInvite
    /// Live: how many have used it, and whether it was revoked.
    public var status: @Sendable (_ homeID: HomeID, _ token: String) -> AsyncThrowingStream<InviteStatus?, any Error> = { _, _ in .never }
    /// Live: what the token opens onto, for the card that asks to join.
    public var preview: @Sendable (_ token: String) -> AsyncThrowingStream<InvitePreview, any Error> = { _ in .never }
    /// Joins. A Plus refusal (a second house) comes back as `.proRequired`
    /// without opening the paywall: the card hands it on.
    public var redeem: @Sendable (_ token: String) async throws -> InviteRedeemed
    public var revoke: @Sendable (_ homeID: HomeID, _ token: String) async throws -> Void

    public enum Kind: String, Sendable { case link, qr }
}

extension InviteClient: DependencyKey {
    public static let liveValue = InviteClient(
        create: { homeID, kind, maxUses in
            var args: [String: ConvexEncodable?] = ["homeId": homeID, "kind": kind.rawValue]
            if let maxUses { args["maxUses"] = maxUses.convexNumber }
            return try await ConvexConnection.shared.mutate("invites:create", args: args, as: HomeInvite.self)
        },
        status: { homeID, token in
            ConvexConnection.shared.subscribe(
                to: "invites:status", args: ["homeId": homeID, "token": token], as: InviteStatus?.self
            )
        },
        preview: { token in
            ConvexConnection.shared.subscribe(to: "invites:preview", args: ["token": token], as: InvitePreview.self)
                // The inviter and the members are faces too.
                .recordingAvatars { AvatarDirectory.record($0.members + ($0.inviter.map { [$0] } ?? [])) }
        },
        redeem: { token in
            try await ConvexConnection.shared.mutate(
                "invites:redeem", args: ["token": token], as: InviteRedeemed.self, presentsPaywall: false
            )
        },
        revoke: { homeID, token in
            try await ConvexConnection.shared.mutate("invites:revoke", args: ["homeId": homeID, "token": token])
        }
    )

    public static let testValue = InviteClient()
}

extension DependencyValues {
    public var invite: InviteClient {
        get { self[InviteClient.self] }
        set { self[InviteClient.self] = newValue }
    }
}
