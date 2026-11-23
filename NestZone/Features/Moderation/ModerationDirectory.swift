import Observation
import SwiftUI

/// What this person has reported and so no longer sees, and who they are while
/// they report.
///
/// A mirror of what the server said, on the same terms as `AvatarDirectory`:
/// filled by one subscription (`ModerationSessionFeature`), read by the views
/// that draw a face or a problem photo, holding nothing optimistic but the one
/// thing a report does on the spot, which is to hide. The server keeps the
/// hide (`moderation:hiddenByMe`), so a local one is never a promise the
/// next push can break.
@MainActor
@Observable
public final class ModerationDirectory {
    public static let shared = ModerationDirectory()

    /// Problem photos by storage id.
    private var photos: Set<String> = []
    /// Faces by user id, which is what `Avatar` is keyed on.
    private var faces: Set<String> = []

    /// Whose phone this is and which house is open, so a face can be reported
    /// from the full-screen viewer, which knows neither.
    public private(set) var userID: UserID?
    public private(set) var homeID: HomeID?

    init() {}

    public func isPhotoHidden(_ id: String) -> Bool { photos.contains(id) }
    public func isFaceHidden(_ userID: String) -> Bool { faces.contains(userID) }

    /// Hidden at once, before the server's push says so.
    public func hidePhoto(_ id: String) { photos.insert(id) }
    public func hideFace(_ userID: String) { faces.insert(userID) }

    /// What the server says is hidden. Added to, never replaced: a local hide
    /// that the push has not caught up with must not flicker back.
    public func record(_ items: [HiddenItem]) {
        var newPhotos = photos
        var newFaces = faces
        for item in items {
            switch item.kind {
            case .issuePhoto: newPhotos.insert(item.targetID)
            case .avatar: newFaces.insert(item.targetID)
            case .message, .calendarItem: break
            }
        }
        // Convex re-publishes every query on any query-set change; writing an
        // identical set into an observed property would invalidate every
        // avatar on screen for nothing.
        if newPhotos != photos { photos = newPhotos }
        if newFaces != faces { faces = newFaces }
    }

    public func setSession(userID: UserID?, homeID: HomeID?) {
        if self.userID != userID { self.userID = userID }
        if self.homeID != homeID { self.homeID = homeID }
    }

    /// Forgets everything. Called when a session ends.
    public func clear() {
        photos = []
        faces = []
        userID = nil
        homeID = nil
    }
}
