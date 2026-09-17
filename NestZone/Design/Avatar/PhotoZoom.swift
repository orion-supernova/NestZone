import CoreGraphics
import Foundation

/// Where a photo sits inside a screen you can pinch and drag it around.
///
/// The counterpart to `AvatarCrop`, and deliberately not the same type. A crop
/// *fills* its square — the circle must never show a gap, so the photo is
/// fitted to its shorter edge and always overhangs. A viewer *fits* its screen:
/// the whole picture has to be visible at rest, which means at scale 1 there is
/// no overhang at all and nothing to pan. Sharing one type would mean one of
/// the two lying about which edge it fits to.
public struct PhotoZoom: Equatable, Sendable {
    /// At rest. Anything less would leave the photo smaller than it was drawn.
    public static let minimumScale: CGFloat = 1
    /// Enough to read a face in a group shot without turning it to porridge.
    public static let maximumScale: CGFloat = 5
    /// Where a double tap lands, when it is not going back to `1`.
    public static let doubleTapScale: CGFloat = 2.5

    /// The photo's natural proportions, in any unit — only the ratio is used.
    public var imageSize: CGSize
    /// The space it is being shown in, in points.
    public var viewport: CGSize
    public var scale: CGFloat
    public var offset: CGSize

    public init(
        imageSize: CGSize,
        viewport: CGSize,
        scale: CGFloat = 1,
        offset: CGSize = .zero
    ) {
        self.imageSize = imageSize
        self.viewport = viewport
        self.scale = scale
        self.offset = offset
    }

    /// The scale at which the whole photo is visible — `scale == 1`.
    ///
    /// `min`, where a crop uses `max`. That one word is the difference between
    /// the two types.
    public var fitScale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0,
              viewport.width > 0, viewport.height > 0
        else { return 1 }
        return min(viewport.width / imageSize.width, viewport.height / imageSize.height)
    }

    /// How large the photo is drawn, in points.
    public var displayedSize: CGSize {
        let scale = fitScale * self.scale
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    /// How far it may be pushed before an edge would come inside the screen.
    ///
    /// Zero on an axis with nothing hanging off it, which pins that axis — so a
    /// photo at rest cannot be dragged sideways into empty space, and a portrait
    /// photo zoomed in can still only travel the way it actually overflows.
    public var maximumOffset: CGSize {
        let size = displayedSize
        return CGSize(
            width: max(0, (size.width - viewport.width) / 2),
            height: max(0, (size.height - viewport.height) / 2)
        )
    }

    /// True while the photo is at rest, which is when a downward drag means
    /// "close this" rather than "look further down".
    public var isAtRest: Bool { scale <= Self.minimumScale }

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

    /// Where a double tap takes it: all the way out if it is zoomed at all,
    /// otherwise in.
    ///
    /// Recentred on the way out, because a photo that is fully visible has only
    /// one correct position and leaving it offset would strand it off-centre
    /// with nothing to drag it back.
    public func toggledZoom() -> Self {
        var copy = self
        if scale > Self.minimumScale {
            copy.scale = Self.minimumScale
            copy.offset = .zero
        } else {
            copy.scale = Self.doubleTapScale
        }
        return copy.clamped()
    }
}
