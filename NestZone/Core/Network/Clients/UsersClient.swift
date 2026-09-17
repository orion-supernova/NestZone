import ComposableArchitecture
import Foundation
import ConvexMobile

/// Profile lookups, and the signed-in user's own photo.
@DependencyClient
public struct UsersClient: Sendable {
    /// Resolves several ids at once. Screens used to loop and fetch one user per
    /// row, which is where the message list's per-bubble request storm came from.
    public var byIDs: @Sendable ([UserID]) async throws -> [User] = { _ in [] }

    // MARK: The profile photo

    /// Uploads one image and hands back its storage id.
    ///
    /// Split from `setAvatar` for the reason house-problem photos are: the
    /// bytes go straight to storage over a signed URL, and only the id reaches
    /// a mutation.
    public var uploadAvatar: @Sendable (PhotoUpload) async throws -> String

    /// Points the signed-in user at an uploaded photo. `nil` takes it off.
    ///
    /// Answers with the patched user rather than nothing, so the screen that
    /// asked knows the new URL the moment the write lands. Waiting for the
    /// `users:me` push instead would leave a gap between "the upload finished"
    /// and "there is something to show for it" — which is exactly the gap a
    /// spinner would be turned off in.
    public var setAvatar: @Sendable (_ storageID: String?) async throws -> User
}

extension UsersClient: DependencyKey {
    public static let liveValue = UsersClient(
        byIDs: { ids in
            guard !ids.isEmpty else { return [] }
            let users = try await ConvexConnection.shared.first(
                "users:byIds",
                args: ["ids": ids.map { $0 as ConvexEncodable? }],
                as: [User].self
            )
            // Message authors and comment authors arrive here and nowhere else.
            // Recording them is what lets an avatar in a chat bubble find a
            // photo without the bubble knowing anything about photos.
            AvatarDirectory.record(users)
            return users
        },

        uploadAvatar: { upload in
            // The type travels with the bytes. Convex stores whatever content
            // type it is told and serves it back on every read, so sending a
            // constant here would mislabel every HEIC avatar in the deployment.
            try await ConvexConnection.shared.upload(
                upload.data,
                contentType: upload.contentType,
                signedBy: "users:avatarUploadUrl"
            )
        },

        setAvatar: { storageID in
            let user = try await ConvexConnection.shared.mutate(
                "users:setAvatar",
                // An explicit null, not an omitted argument: `setAvatar` has to
                // be able to say "take it off", and a missing field can only
                // say "not mentioned".
                args: ["storageId": storageID as ConvexEncodable?],
                as: User.self
            )
            AvatarDirectory.record(user)
            return user
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
