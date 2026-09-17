import Foundation

/// What the app knows about how to draw one person.
///
/// The name travels with the photo because the two are wanted together and
/// neither is reachable from a member row: a full-screen photo needs a title,
/// and a tappable avatar needs something for VoiceOver to call it. Looking both
/// up from the id is what keeps `Avatar`'s signature free of either.
public struct AvatarEntry: Equatable, Sendable {
    public var name: String
    /// `nil` once a photo has been taken off, which is different from the
    /// person being unknown — the entry stays so the name survives.
    public var photo: URL?

    public init(name: String, photo: URL?) {
        self.name = name
        self.photo = photo
    }
}
