import Foundation

/// One picked photo, in the two sizes a problem actually needs.
///
/// They travel together because they are written together: `issues.photos` and
/// `issues.photo_thumbs` are parallel arrays, and an entry that reaches one
/// without reaching the other would leave a row drawing somebody else's
/// thumbnail. Pairing them here means no caller can attach half of one.
public struct IssuePhotoUpload: Equatable, Sendable {
    /// What the detail screen's strip draws, and what somebody forwards to a
    /// plumber.
    public let full: PhotoUpload
    /// What the board row draws — about a tenth the bytes.
    public let thumbnail: PhotoUpload

    public init(full: PhotoUpload, thumbnail: PhotoUpload) {
        self.full = full
        self.thumbnail = thumbnail
    }
}

/// The pair of storage ids the two uploads answer with.
public struct IssuePhotoIDs: Equatable, Sendable {
    public let full: String
    public let thumbnail: String

    public init(full: String, thumbnail: String) {
        self.full = full
        self.thumbnail = thumbnail
    }
}
