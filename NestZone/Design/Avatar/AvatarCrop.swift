import CoreGraphics
import Foundation

/// Where in a photo the circle is pointing.
///
/// Pure geometry, with no view and no image in it, because this is the part
/// that is actually easy to get wrong: a crop that drifts by a few points is
/// invisible in a preview and obvious once it is somebody's face. Kept
/// separately so it can be checked directly rather than by looking at it.
///
/// Three frames of reference meet here, so each one is named. `imageSize` is in
/// source pixels. `viewport` and `offset` are in points, the units the editor's
/// gestures arrive in. `sourceRect` is the answer, back in source pixels.
public struct AvatarCrop: Equatable, Sendable {
    /// Below this the photo would no longer cover the circle.
    public static let minimumScale: CGFloat = 1
    /// Past this a phone photo is being enlarged into its own pixels.
    public static let maximumScale: CGFloat = 6

    /// The upright source image, in pixels.
    public var imageSize: CGSize
    /// The edge of the square the photo is fitted into, in points.
    public var viewport: CGFloat
    /// The user's zoom, on top of the scale that already covers the viewport.
    public var scale: CGFloat
    /// The user's pan, in points.
    public var offset: CGSize

    public init(
        imageSize: CGSize,
        viewport: CGFloat,
        scale: CGFloat = 1,
        offset: CGSize = .zero
    ) {
        self.imageSize = imageSize
        self.viewport = viewport
        self.scale = scale
        self.offset = offset
    }

    /// The scale at which the photo exactly covers the viewport — `scale == 1`.
    ///
    /// `max`, not `min`: the circle must be full at every zoom, so the photo is
    /// fitted to its *shorter* edge and the longer one overhangs.
    public var fillScale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        return max(viewport / imageSize.width, viewport / imageSize.height)
    }

    /// Source pixels to screen points, all in.
    public var displayScale: CGFloat { fillScale * scale }

    /// How large the photo is drawn, in points.
    public var displayedSize: CGSize {
        CGSize(
            width: imageSize.width * displayScale,
            height: imageSize.height * displayScale
        )
    }

    /// How far the photo may be pushed before an edge would come inside the
    /// circle. Zero on an axis with no overhang, which pins that axis.
    public var maximumOffset: CGSize {
        CGSize(
            width: max(0, (displayedSize.width - viewport) / 2),
            height: max(0, (displayedSize.height - viewport) / 2)
        )
    }

    /// The same crop with the zoom in range and the photo still covering the
    /// circle.
    ///
    /// Applied on the way out of every gesture rather than during one: clamping
    /// live makes a pinch past the limit feel like the photo is fighting the
    /// finger, and clamping on release lets it settle back instead.
    public func clamped() -> Self {
        var copy = self
        copy.scale = min(max(scale, Self.minimumScale), Self.maximumScale)
        // Read off the clamped copy: the limit depends on the zoom, and using
        // the unclamped one would allow an offset the final scale cannot hold.
        let limit = copy.maximumOffset
        copy.offset = CGSize(
            width: min(max(offset.width, -limit.width), limit.width),
            height: min(max(offset.height, -limit.height), limit.height)
        )
        return copy
    }

    /// The square of the source the circle is showing, in source pixels.
    ///
    /// Square rather than round: the mask is how an avatar is *presented*, and
    /// every surface that draws one already applies it. Storing the circle
    /// itself would bake a decision the UI is free to change into the file, and
    /// hand back a photo with corners nobody can get rid of.
    public var sourceRect: CGRect {
        let crop = clamped()
        let scale = crop.displayScale
        guard scale > 0, imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: imageSize)
        }

        // The viewport, measured back in source pixels.
        let edge = min(crop.viewport / scale, min(imageSize.width, imageSize.height))
        // Pushing the photo right shows what was to its left, so the window
        // moves against the offset.
        let center = CGPoint(
            x: imageSize.width / 2 - crop.offset.width / scale,
            y: imageSize.height / 2 - crop.offset.height / scale
        )

        // Nudged inside the image rather than trimmed by it. Rounding can put
        // an edge a fraction of a pixel out of bounds, and `CGImage.cropping`
        // answers that by intersecting — which would quietly return a rectangle
        // that is no longer square.
        let origin = CGPoint(
            x: min(max(0, center.x - edge / 2), imageSize.width - edge),
            y: min(max(0, center.y - edge / 2), imageSize.height - edge)
        )
        return CGRect(origin: origin, size: CGSize(width: edge, height: edge))
    }
}
