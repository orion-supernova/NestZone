import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Squeezes a picture down until it fits a stated budget.
///
/// One implementation for both of the app's uploads. A profile photo and a
/// photograph of a leak want different sizes and different formats, but they
/// want the *same* thing done to them — quality first, pixels second, stop when
/// it fits — and two copies of that ladder would drift the moment one of them
/// was tuned.
///
/// Quality before size because at these dimensions a photograph survives a
/// surprising amount of quantisation and does not survive being made small: the
/// point of a picture of a stain is that somebody can see the stain.
public enum PhotoCompressor {
    /// The smallest encoding of `image` that fits the plan.
    ///
    /// Returns the smallest it managed even when nothing met the budget.
    /// Refusing to upload would turn "your photo is a little large" into "you
    /// cannot have a photo", and the ladder bottoms out well inside anything a
    /// camera produces.
    static func compress(_ image: UIImage, plan: PhotoCompressionPlan) -> CompressedPhoto? {
        var smallest: CompressedPhoto?

        for edge in plan.edgeLadder {
            let candidate = resized(image, longEdge: edge)
            for quality in plan.qualitySteps {
                guard let attempt = written(candidate, quality: quality, plan: plan) else {
                    continue
                }
                if attempt.upload.byteCount < (smallest?.upload.byteCount ?? .max) {
                    smallest = attempt
                }
                if attempt.upload.byteCount <= plan.byteBudget { return attempt }
            }
        }
        return smallest
    }

    /// A picture reduced to `longEdge` pixels on its longest side, or left
    /// alone if it is already smaller. Proportions are kept.
    ///
    /// The orientation is baked in rather than left in the EXIF:
    /// `UIGraphicsImageRenderer` draws in the orientation the image reports, so
    /// the result is upright with no tag left for a consumer to remember to
    /// honour.
    static func resized(_ image: UIImage, longEdge: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > longEdge, longest > 0 else { return image }

        let scale = longEdge / longest
        let target = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        // No transparency to preserve: the source is a photograph, and an opaque
        // context is both faster and a third smaller as JPEG.
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// The smallest this device can make this picture, at this size and quality.
    ///
    /// Where HEIC is allowed, both containers are tried and the smaller kept,
    /// rather than HEIC being assumed to win. It nearly always does — a
    /// photograph is around half the bytes of the same JPEG — but "nearly
    /// always" is not a rule an encoder obeys. On detail with no structure to
    /// model, HEIC hits a floor JPEG walks straight past: pure noise at 1024 is
    /// 391 KB of HEIC against 427 KB of JPEG at the same quality. Preferring it
    /// unconditionally would mean the ladder never finding the JPEG that fit,
    /// and settling for something several times the budget.
    private static func written(
        _ image: UIImage,
        quality: CGFloat,
        plan: PhotoCompressionPlan
    ) -> CompressedPhoto? {
        var candidates: [(data: Data, contentType: String)] = []
        if plan.allowsHEIC, canWriteHEIC, let heic = write(image, as: .heic, quality: quality) {
            candidates.append((heic, "image/heic"))
        }
        if let jpeg = write(image, as: .jpeg, quality: quality) {
            candidates.append((jpeg, "image/jpeg"))
        }
        guard let best = candidates.min(by: { $0.data.count < $1.data.count }) else {
            return nil
        }
        return CompressedPhoto(
            upload: PhotoUpload(data: best.data, contentType: best.contentType),
            image: image
        )
    }

    /// Encodes, and refuses to believe it worked until the result decodes.
    ///
    /// The round trip is the whole safety net. `CGImageDestination` hands back a
    /// destination for formats it cannot really write and then finalises to
    /// nothing, which would otherwise be discovered as a picture that uploaded
    /// fine and is a blank square on every other phone in the house.
    private static func write(_ image: UIImage, as type: UTType, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            buffer, type.identifier as CFString, 1, nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: quality,
        ] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        let data = buffer as Data
        guard !data.isEmpty, UIImage(data: data) != nil else { return nil }
        return data
    }

    /// Whether this device writes HEIC, settled once.
    ///
    /// Probed rather than assumed from an OS version: the encoder is hardware,
    /// and the simulator in particular will hand out a HEIC destination that
    /// finalises to an empty file. Eight pixels is enough to find that out.
    private static let canWriteHEIC: Bool = {
        guard let probe = probeImage() else { return false }
        return write(probe, as: .heic, quality: 0.5) != nil
    }()

    private static func probeImage() -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: 8, height: 8)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
