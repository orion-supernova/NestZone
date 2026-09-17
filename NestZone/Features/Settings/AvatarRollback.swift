import Foundation

/// The photo a removal took off, kept for as long as the removal is in flight.
///
/// A write that failed changed nothing on the server, so there is no push
/// coming to correct the screen — the failure action has to put the old value
/// back itself, and so it has to carry it. Both halves travel because both were
/// cleared: the storage id is the identity, and the URL is what draws.
public struct AvatarRollback: Equatable, Sendable {
    public var storageID: String?
    public var url: URL?

    public init(storageID: String?, url: URL?) {
        self.storageID = storageID
        self.url = url
    }
}
