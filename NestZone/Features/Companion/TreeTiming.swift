#if DEBUG
import OSLog
import QuartzCore

/// How long the tree layer takes to record a picture, logged in Debug when the
/// frame meter is on, so a change to a painter can be measured:
///
///   xcrun simctl spawn booted log stream --predicate 'category == "Frames"'
///
/// This is the main thread's cost of drawing the tree again (the canvas
/// closure building its shapes), which is what Today pays when a mood or a
/// stage eases in; the rasterising after it is the GPU's.
enum TreeTiming {
    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Frames")
    /// `-pomegranateLegacy 1` draws the pomegranate with the shared canopy
    /// painter again, to compare the two on the bench.
    static let legacyPomegranate = UserDefaults.standard.bool(forKey: "pomegranateLegacy")
    /// `-treeLegacy lemon,olive` (or `all`) draws those trees with the shared
    /// canopy painter, for the same comparison.
    private static let legacy = Set((UserDefaults.standard.string(forKey: "treeLegacy") ?? "").split(separator: ",").map(String.init))
    static func legacy(_ species: Species) -> Bool {
        legacy.contains(species.rawValue) || legacy.contains("all") || legacy.contains("1")
    }
    private static let on = UserDefaults.standard.integer(forKey: "frameMeter") > 0 || UserDefaults.standard.bool(forKey: "treeTiming")

    /// One clump's leaves built for the cache (`LeafArt`): the cost a redraw
    /// pays once per light and mood, and never while a tree only grows.
    static func built(_ clump: Int, leaves: Int, since start: CFTimeInterval) {
        guard on else { return }
        log.info("leaf art clump \(clump) leaves \(leaves) \((CACurrentMediaTime() - start) * 1000, format: .fixed(precision: 2)) ms")
    }

    static func note(_ species: Species, light: Double = 0, since start: CFTimeInterval) {
        guard on else { return }
        log.info("tree draw \(species.rawValue, privacy: .public) light \(light, format: .fixed(precision: 1)) \((CACurrentMediaTime() - start) * 1000, format: .fixed(precision: 2)) ms")
    }
}
#else
enum TreeTiming {
    static let legacyPomegranate = false
    static func legacy(_ species: Species) -> Bool { false }
    static func built(_ clump: Int, leaves: Int, since start: Double) {}
}
#endif
