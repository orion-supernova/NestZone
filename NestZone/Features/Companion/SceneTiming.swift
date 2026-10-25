#if DEBUG
import OSLog
import QuartzCore

/// How long the scene's own canvases take to record a frame (the sky and
/// what hangs, the floor and what is worn), logged in Debug when the frame
/// meter is on, beside `PetTiming` and `TreeTiming`:
///
///   xcrun simctl spawn <udid> log stream --level info --predicate 'category == "Frames"'
///
/// Each name keeps its own mean and worst and reports once a second, so the
/// cost of a scene full of decorations can be read against an empty one.
enum SceneTiming {
    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Frames")
    private static let on = UserDefaults.standard.integer(forKey: "frameMeter") > 0 || UserDefaults.standard.bool(forKey: "treeTiming")

    private struct Tally {
        var total = 0.0, worst = 0.0, count = 0
        var since = CACurrentMediaTime()
    }

    nonisolated(unsafe) private static var tallies: [String: Tally] = [:]

    static func measure(_ name: String, _ draw: () -> Void) {
        guard on else { draw(); return }
        let start = CACurrentMediaTime()
        draw()
        let now = CACurrentMediaTime()
        let ms = (now - start) * 1000
        // A layer drawn now and then is logged at each draw: that it was drawn is the news.
        if name == "scenery" { log.info("scene draw \(name, privacy: .public) once \(ms, format: .fixed(precision: 2)) ms") }
        var tally = tallies[name] ?? Tally()
        tally.total += ms; tally.worst = max(tally.worst, ms); tally.count += 1
        if now - tally.since >= 1 {
            log.info("scene draw \(name, privacy: .public) mean \(tally.total / Double(tally.count), format: .fixed(precision: 2)) ms worst \(tally.worst, format: .fixed(precision: 2)) ms over \(tally.count) frames")
            tally = Tally()
        }
        tallies[name] = tally
    }
}
#else
enum SceneTiming {
    @inline(__always) static func measure(_ name: String, _ draw: () -> Void) { draw() }
}
#endif
