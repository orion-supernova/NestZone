import SwiftUI

/// A compressed picture on its way to the server, plus the bitmap it came from.
///
/// Two forms because they go to two places and neither is derivable for free.
/// `upload` is what is sent. `image` is the same picture already decoded, at
/// the size that was actually encoded — which is what primes the cache under
/// the URL storage answers with, so a photo somebody just chose never makes a
/// round trip to come back.
///
/// The split in types matters: `upload` is `Sendable` and `Equatable` and
/// crosses into a reducer, while `image` stays in the view layer where a
/// `UIImage` belongs.
struct CompressedPhoto {
    let upload: PhotoUpload
    let image: UIImage
}
