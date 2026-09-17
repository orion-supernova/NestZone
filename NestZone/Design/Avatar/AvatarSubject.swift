import Foundation

/// One person, as the full-screen viewer needs them.
///
/// `Identifiable` because it is what a `fullScreenCover(item:)` is handed, and
/// identified by the photo rather than the person: opening the same face twice
/// is the same presentation, and a photo that changes underneath is a new one.
public struct AvatarSubject: Identifiable, Equatable, Sendable {
    public let name: String
    public let initials: String
    public let seed: String
    public let photo: URL

    public var id: URL { photo }

    public init(name: String, initials: String, seed: String, photo: URL) {
        self.name = name
        self.initials = initials
        self.seed = seed
        self.photo = photo
    }
}
