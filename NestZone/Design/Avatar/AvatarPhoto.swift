import SwiftUI

/// Getting a profile photo from the picker to the server, and deciding how big
/// one needs to be anywhere it is drawn.
///
/// The sizes are the whole design. A photo out of the library is a twelve-
/// megapixel HEIC of several megabytes; what this feature needs is a face,
/// drawn at 52 points at its largest. Every number below exists to stop one of
/// those being confused for the other.
public enum AvatarPhoto {
    /// The longest edge the editor works on.
    ///
    /// Not the original. The crop is driven by a live gesture, and dragging a
    /// twelve-megapixel bitmap around costs a texture upload per frame — while
    /// nothing above this can survive being cropped down to `storedEdge`
    /// anyway. It is the smallest size that still leaves room to zoom in.
    public static let editingEdge: CGFloat = 1600

    /// The square that reaches the server.
    ///
    /// Sized for the *largest* thing that is ever done with it, which since
    /// avatars became tappable is a full-screen photo and not a 52-point
    /// circle. 1024 is about native on a 3× phone and lands around 200 KB of
    /// JPEG — where 512 was ample for a list and visibly soft the moment
    /// somebody opened it. Storing the original instead would mean every member
    /// of every household downloading four megabytes to fill a 26-point circle,
    /// once per household, on somebody's data plan.
    public static let storedEdge: CGFloat = 1024

    /// What the full-screen viewer asks for, in points.
    ///
    /// Its own entry in the cache, and rightly: it is a genuinely different
    /// size from the two a list draws, and sharing a bucket would mean either a
    /// blurry viewer or a list holding megapixels per face.
    public static let viewerEdge: CGFloat = 512

    /// How hard an avatar is squeezed.
    ///
    /// HEIC is allowed here and not for house-problem photos: a face is drawn
    /// by this app and nothing else ever sees it, while a picture of a leak is
    /// exactly the kind of thing somebody forwards to a plumber.
    ///
    /// Real numbers on ordinary photographs: 137–212 KB before this existed,
    /// 23–73 KB after, at the same 1024 pixels.
    public static let plan = PhotoCompressionPlan(
        byteBudget: 120 * 1024,
        qualitySteps: [0.7, 0.55, 0.45, 0.35],
        edgeLadder: [storedEdge, 768, 512],
        allowsHEIC: true
    )

    /// Kept for the tests and for anything that wants to state the ceiling.
    public static var byteBudget: Int { plan.byteBudget }
    public static var edgeLadder: [CGFloat] { plan.edgeLadder }

    /// The size an avatar is actually decoded at, given the size it is drawn at.
    ///
    /// The app draws avatars at eight different sizes — 18 points in an issue
    /// comment, 52 in the Settings header — and the decoded-image cache keys on
    /// the size it was asked for. Passing each site's own size through would
    /// decode the same person up to eight times and keep eight bitmaps of them
    /// resident. Two buckets mean one decode per member for every list, badge
    /// and comment in the app, and a second only for a header large enough to
    /// show the difference.
    public static func renderSize(for drawnSize: CGFloat) -> CGFloat {
        renderBuckets.first { drawnSize <= $0 } ?? renderBuckets[renderBuckets.count - 1]
    }

    /// Every size an avatar is ever decoded at, smallest first.
    ///
    /// Named as a list because priming the cache has to cover all of them: a
    /// photo filed under the list size alone would still be fetched back from
    /// storage the first time the Settings header drew it.
    public static let renderBuckets: [CGFloat] = [56, 128]

    /// A square image reduced to `edge` pixels, or left alone if it is already
    /// smaller.
    ///
    /// Only the cache-priming path uses this now — `compress` resizes through
    /// `PhotoCompressor`. Priming with the full upload would file a bitmap
    /// eight times the size of the slot it was filed under, and — because the
    /// same copy is written to disk — keep doing so on every launch after this
    /// one.
    public static func fitted(_ image: UIImage, toPixels edge: CGFloat) -> UIImage {
        PhotoCompressor.resized(image, longEdge: edge)
    }

    /// Decodes the picker's bytes into an upright working copy.
    ///
    /// Upright as pixels, not as an EXIF tag: the crop rectangle is computed
    /// against what the user is looking at, so a photo that is still claiming
    /// to be rotated would be cropped along the wrong axis. Thumbnailing with
    /// `kCGImageSourceCreateThumbnailWithTransform` bakes the orientation in and
    /// downsamples in one pass, without ever decoding the original at full size.
    public static func upright(_ data: Data, maxEdge: CGFloat = editingEdge) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        // Scale 1 and `.up`: the pixels are the truth now, and anything reading
        // this image should not have to consult a transform to believe them.
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// Cuts `crop` out of an upright image and squares it off for upload.
    ///
    /// Returns `nil` rather than something wrong if the image has no bitmap
    /// behind it — a `UIImage` built from a `CIImage` has no `cgImage` — which
    /// the caller surfaces as a failed change rather than uploading a blank.
    public static func square(_ image: UIImage, crop: AvatarCrop) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let rect = crop.sourceRect
        guard rect.width >= 1, rect.height >= 1,
              let cut = cgImage.cropping(to: rect.integral)
        else { return nil }

        let edge = min(storedEdge, CGFloat(cut.width))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        // No transparency to preserve: the source is a photograph, and an opaque
        // context is both faster and a third smaller as JPEG.
        format.opaque = true
        let size = CGSize(width: edge, height: edge)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: cut, scale: 1, orientation: .up)
                .draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// The bytes to upload, and the bitmap they came from.
    ///
    /// Both, because the caller needs each for a different thing: the data goes
    /// to storage, and the image primes the cache under the URL the server
    /// answers with — so the moment the subscription delivers the new avatar it
    /// is already decoded, and the photo the user just chose never makes a
    /// round trip to come back.
    ///
    /// The image handed back is the one that was *encoded*, not the one that
    /// was cropped: if the budget forced a smaller square, the cache must be
    /// primed with what the server actually has, or the local copy and the
    /// remote one are two different pictures at the same URL.
    static func encode(_ image: UIImage, crop: AvatarCrop) -> CompressedPhoto? {
        guard let squared = square(image, crop: crop) else { return nil }
        return compress(squared)
    }

    static func compress(_ square: UIImage) -> CompressedPhoto? {
        PhotoCompressor.compress(square, plan: plan)
    }
}
