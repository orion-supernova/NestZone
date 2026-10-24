#if DEBUG
import OSLog
import QuartzCore

/// How long a pet takes to record one frame, logged in Debug when the frame
/// meter is on, so a change to a pet's painter can be measured:
///
///   xcrun simctl spawn booted log stream --predicate 'category == "Frames"'
///
/// A pet is drawn whole every frame (the tree is not), so what is logged is
/// the main thread's cost of one `draw`: the canvas closure building the
/// shapes and recording the fills. It is summed and reported once a second as
/// the mean and the worst, so a log of thirty frames a second stays readable.
enum PetTiming {
    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Frames")
    private static let on = UserDefaults.standard.integer(forKey: "frameMeter") > 0 || UserDefaults.standard.bool(forKey: "treeTiming")
    nonisolated(unsafe) private static var total = 0.0
    nonisolated(unsafe) private static var worst = 0.0
    nonisolated(unsafe) private static var count = 0
    nonisolated(unsafe) private static var since = CACurrentMediaTime()

    static func measure(_ name: String, _ draw: () -> Void) {
        guard on else { draw(); return }
        let start = CACurrentMediaTime()
        draw()
        let now = CACurrentMediaTime()
        let ms = (now - start) * 1000
        total += ms; worst = max(worst, ms); count += 1
        if now - since >= 1 {
            log.info("pet draw \(name, privacy: .public) mean \(total / Double(count), format: .fixed(precision: 2)) ms worst \(worst, format: .fixed(precision: 2)) ms over \(count) frames")
            total = 0; worst = 0; count = 0; since = now
        }
    }
}
#else
enum PetTiming {
    @inline(__always) static func measure(_ name: String, _ draw: () -> Void) { draw() }
}
#endif
