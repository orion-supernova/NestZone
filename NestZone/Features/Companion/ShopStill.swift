import SwiftUI

// A shop tile's picture is the same still all the time, so it is drawn once
// into a bitmap and kept. A tree or a plant painted into a `Canvas` costs
// tens of milliseconds on the main thread each time a tile scrolls in (Choose
// held its scroll at about 8 fps on the simulator), and a bitmap costs a
// texture. The shelf fills the cache a picture at a time while nobody is
// scrolling (`StillCache.warm`); a tile that scrolls in before its picture is
// ready draws the canvas, as it always did.

/// What a still is: which picture, and how big a tile shows it.
struct StillSpec: Hashable, Sendable {
    let key: String
    let size: CGSize
}

@MainActor
enum StillCache {
    /// Two pixels to the point: a tile is 100 to 160 points wide, and a
    /// bitmap at three would be most of a megabyte each.
    static let scale: CGFloat = 2
    private static let images: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    static func image(_ spec: StillSpec) -> CGImage? { images.object(forKey: spec.key as NSString) }

    /// Draws each picture that is not kept yet, one at a time with a breath
    /// between, so a shelf opening is never one long frame. Cancelled with the
    /// shelf's task.
    static func warm(_ jobs: [(StillSpec, AnyView)]) async {
        for (spec, view) in jobs where image(spec) == nil {
            if Task.isCancelled { return }
            let renderer = ImageRenderer(content: view.frame(width: spec.size.width, height: spec.size.height))
            renderer.scale = scale
            if let made = renderer.cgImage {
                images.setObject(made, forKey: spec.key as NSString, cost: made.bytesPerRow * made.height)
            }
            try? await Task.sleep(for: .milliseconds(60))
        }
    }
}

/// A picture that is the kept bitmap once there is one, and the live canvas
/// until then.
struct Still<Live: View & Equatable>: View, Equatable {
    let spec: StillSpec
    let live: Live

    var body: some View {
        if let image = StillCache.image(spec) {
            Image(decorative: image, scale: StillCache.scale)
                .resizable()
                .allowsHitTesting(false)
        } else {
            live
        }
    }
}
