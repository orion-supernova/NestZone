#if DEBUG
import SwiftUI

/// The same question as `TreeAudit`, asked of the picture and not of the
/// geometry, so it holds for every painter however it lays itself out: draw a
/// tree or a plant on a clear ground, thicken what was drawn by a few points,
/// and everything that is not joined to the soil is something floating. A leaf,
/// a bud or a fruit that no stem reaches is a piece of its own; one that
/// touches a leaf that touches the wood is joined.
///
/// It is a test of what a person sees, so it counts a gap of more than
/// `tolerance` points and nothing smaller, and ignores what is meant to be in
/// the air (the petals a cherry lets fall: `TreeDebug.pixel`).
@MainActor
enum PixelAudit {
    /// A gap this wide or less between two drawn things is not a gap.
    static let tolerance = 3.0
    /// The picture is drawn at this many pixels to the point.
    static let scale = 2.0
    /// What is smaller than this, in points squared, is a speck and not a part.
    static let speck = 3.0

    struct Floater {
        /// In scene units, 360 points tall with the trunk's base at x = 180, y = 282.
        var rect: CGRect
        var area: Double
    }

    /// What the painter draws for this companion at this growth and mood, on a
    /// 360 by 360 clear ground, and what in it floats.
    static func floaters(_ companion: Companion, progress: Double, mood: Mood, hour: Date) -> [Floater] {
        let snapshot = SceneSnapshot(still: companion, progress: progress, mood: mood,
                                     stage: 5, now: hour, reduceMotion: true)
        let state = snapshot.treeState(at: snapshot.epoch)
        let plan = PlantPlan.of(companion.species, colourway: companion.colourway)
        let canopy = snapshot.canopy
        guard canopy != nil || plan != nil else { return [] }
        TreeDebug.pixel = true
        defer { TreeDebug.pixel = false }
        let content = Canvas { context, size in
            if let canopy {
                TreeLayer.paint(context, size: size, canopy: canopy, state: state)
            } else if let plan {
                PlantLayer.paint(context, size: size, plan: plan, state: state)
            }
        }
        .frame(width: 360, height: 360)
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.isOpaque = false
        guard let image = renderer.cgImage else { return [] }
        return find(image)
    }

    @_optimize(speed)
    private static func find(_ image: CGImage) -> [Floater] {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        cg.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var mask = [Bool](repeating: false, count: w * h)
        for i in 0..<(w * h) { mask[i] = data[i * 4 + 3] > 130 }

        // Thicken by the tolerance: a box, in two passes.
        let r = Int((tolerance * scale / 2).rounded(.up))
        func grow(_ src: [Bool], horizontal: Bool) -> [Bool] {
            var out = [Bool](repeating: false, count: w * h)
            for y in 0..<h {
                for x in 0..<w where src[y * w + x] {
                    if horizontal {
                        for k in max(0, x - r)...min(w - 1, x + r) { out[y * w + k] = true }
                    } else {
                        for k in max(0, y - r)...min(h - 1, y + r) { out[k * w + x] = true }
                    }
                }
            }
            return out
        }
        let thick = grow(grow(mask, horizontal: true), horizontal: false)

        // Label what is joined, and which labels touch the soil.
        var label = [Int32](repeating: -1, count: w * h)
        var count = 0
        let soilRow = Int((SceneSpace.soil - 4) * scale)
        var rects: [(minX: Int, minY: Int, maxX: Int, maxY: Int, area: Int, soil: Bool)] = []
        var stack: [Int] = []
        for start in 0..<(w * h) where thick[start] && label[start] < 0 {
            let id = Int32(count)
            count += 1
            label[start] = id
            stack.append(start)
            var box = (minX: w, minY: h, maxX: 0, maxY: 0, area: 0, soil: false)
            while let i = stack.popLast() {
                let x = i % w, y = i / w
                if mask[i] {
                    box.minX = min(box.minX, x); box.maxX = max(box.maxX, x)
                    box.minY = min(box.minY, y); box.maxY = max(box.maxY, y)
                    box.area += 1
                    if y >= soilRow { box.soil = true }
                }
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                    let j = ny * w + nx
                    if thick[j] && label[j] < 0 { label[j] = id; stack.append(j) }
                }
            }
            rects.append(box)
        }
        return rects.filter { !$0.soil && Double($0.area) / (scale * scale) >= speck }.map {
            Floater(rect: CGRect(x: Double($0.minX) / scale, y: Double($0.minY) / scale,
                                 width: Double($0.maxX - $0.minX + 1) / scale, height: Double($0.maxY - $0.minY + 1) / scale),
                    area: Double($0.area) / (scale * scale))
        }
    }
}
#endif
