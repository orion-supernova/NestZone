import Observation
import SwiftUI
import UIKit

// A shop tile's picture is the same still all the time, so it is drawn once
// into a bitmap and kept. A tree or a plant painted into a `Canvas` costs
// tens of milliseconds on the main thread each time a tile scrolls in (Choose
// held its scroll at about 8 fps on the simulator), and a bitmap costs a
// texture. The shelf fills the cache a picture at a time while nobody is
// scrolling (`StillCache.warm`). A tile whose picture is not ready shows its
// sky well alone, which every tile has already, and swaps the picture in when
// it lands; it never draws the canvas itself, because forty canvases recorded
// in one frame are what a jump to the end of a shelf would cost.

/// What a still is: which picture, and how big a tile shows it.
struct StillSpec: Hashable, Sendable {
    let key: String
    let size: CGSize
    let scale: CGFloat

    /// `name` says what is shown; the size and the scale are part of the key,
    /// so a bigger text size never shows a blurred smaller picture.
    @MainActor
    init(name: String, size: CGSize, big: Bool) {
        let scale = StillCache.scale(big: big)
        self.size = size
        self.scale = scale
        key = "\(name)|\(Int(size.width))|\(Int(scale))"
    }
}

/// One picture's place in the cache. Each tile reads only its own, so a
/// picture landing redraws that tile and no other.
@MainActor @Observable
final class StillSlot {
    fileprivate(set) var image: UIImage?
    fileprivate var bytes = 0
}

@MainActor
enum StillCache {
    /// What the cache may hold. The whole catalog at three pixels to the
    /// point is about 51 MB (80 decorations of 300 x 300 pixels, 32 species of
    /// 480 x 360); at the accessibility sizes pictures are drawn at two, which
    /// is about 90 MB, and the oldest are let go to stay under this. The shelf
    /// being looked at was warmed last, so it is the last to go.
    static let budget = 64 * 1024 * 1024

    /// Three pixels to the point on a phone that has them, two at the
    /// accessibility sizes where a picture is twice as many points wide.
    static func scale(big: Bool) -> CGFloat {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.scale }.first ?? 3
        return big ? min(screen, 2) : screen
    }

    private static var slots: [String: StillSlot] = [:]
    /// Keys that hold a picture, oldest first.
    private static var held: [String] = []
    private static var bytes = 0

    private static let memoryWarning = NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
    ) { _ in MainActor.assumeIsolated { dropAll() } }

    static func slot(_ key: String) -> StillSlot {
        _ = memoryWarning
        if let slot = slots[key] { return slot }
        let slot = StillSlot()
        slots[key] = slot
        return slot
    }

    private static func dropAll() {
        for key in held { slots[key]?.image = nil; slots[key]?.bytes = 0 }
        held.removeAll()
        bytes = 0
    }

    private static func keep(_ image: UIImage, cost: Int, in slot: StillSlot, as key: String) {
        bytes += cost - slot.bytes
        slot.image = image
        slot.bytes = cost
        held.removeAll { $0 == key }
        held.append(key)
        while bytes > budget, let oldest = held.first, oldest != key {
            held.removeFirst()
            if let evicted = slots[oldest] {
                bytes -= evicted.bytes
                evicted.image = nil
                evicted.bytes = 0
            }
        }
    }

    /// Draws each picture that is not kept yet, one at a time with a breath
    /// between, so a shelf opening is never one long frame. The bitmap is
    /// decoded for display off the main thread before it is kept, so the first
    /// frame that shows it uploads it and decodes nothing. Cancelled with the
    /// shelf's task.
    static func warm(_ jobs: [(StillSpec, AnyView)]) async {
        for (spec, view) in jobs {
            let slot = slot(spec.key)
            guard slot.image == nil else { continue }
            if Task.isCancelled { return }
            let renderer = ImageRenderer(content: view.frame(width: spec.size.width, height: spec.size.height))
            renderer.scale = spec.scale
            if let made = renderer.cgImage,
               let ready = await UIImage(cgImage: made, scale: spec.scale, orientation: .up).byPreparingForDisplay() {
                keep(ready, cost: made.bytesPerRow * made.height, in: slot, as: spec.key)
            }
            try? await Task.sleep(for: .milliseconds(40))
        }
    }
}

/// A picture that is the kept bitmap once there is one, and nothing but the
/// tile's own window until then.
struct Still: View, Equatable {
    let spec: StillSpec
    private let slot: StillSlot

    init(spec: StillSpec) {
        self.spec = spec
        slot = StillCache.slot(spec.key)
    }

    nonisolated static func == (lhs: Still, rhs: Still) -> Bool { lhs.spec == rhs.spec }

    var body: some View {
        if let image = slot.image {
            Image(uiImage: image)
                .resizable()
                .allowsHitTesting(false)
        } else {
            Color.clear
        }
    }
}
