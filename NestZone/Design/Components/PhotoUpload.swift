import Foundation

/// Compressed bytes, and what they actually are.
///
/// The content type travels with the bytes because it is not a constant: the
/// compressor writes HEIC where it is allowed and the device can, and JPEG
/// everywhere else. Convex stores whatever content type it is told and serves
/// it back on every read, so a guess here is a mislabelled file served to the
/// whole household forever.
///
/// Deliberately free of `UIImage`, unlike `CompressedPhoto`. This is the value
/// that crosses into a reducer and onto the wire, and it has to stay
/// `Equatable` and `Sendable` to do that.
public struct PhotoUpload: Equatable, Sendable {
    public let data: Data
    public let contentType: String

    public init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }

    /// For logs, and for the size assertions in the tests.
    public var byteCount: Int { data.count }
}
