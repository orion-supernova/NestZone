#if DEBUG || MEASURE
import OSLog
import UIKit

/// Counts late frames: the stutter a person sees, which a profile of where
/// the time goes does not show directly. Launch with `-frameMeter 1` and read
/// the log, every two seconds:
///
///     xcrun simctl spawn booted log stream --predicate 'category == "Frames"'
///
/// A frame is late when it arrives more than half a frame after it was due.
/// `-frameMeter 2` also logs each late frame as it happens, to see how a
/// switch's work is split across frames and not only how bad the worst is.
/// Development builds, and the `MEASURE` configuration (Release optimisation
/// with the hooks compiled in; see CLAUDE.md, Commands).
@MainActor
final class FrameMeter: NSObject {
    static let shared = FrameMeter()

    private let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Frames")
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var frames = 0, late = 0, dropped = 0
    private var worst: CFTimeInterval = 0
    private var windowStart: CFTimeInterval = 0
    private let verbose = UserDefaults.standard.integer(forKey: "frameMeter") >= 2

    func startIfAsked() {
        guard link == nil, UserDefaults.standard.integer(forKey: "frameMeter") > 0 else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp, expected = link.targetTimestamp - link.timestamp
        defer { last = now }
        guard last > 0, expected > 0 else { windowStart = now; return }
        let interval = now - last
        frames += 1
        worst = max(worst, interval)
        if interval > expected * 1.5 {
            late += 1
            dropped += Int((interval / expected).rounded()) - 1
            if verbose { log.notice("late frame \(Int(interval * 1000)) ms") }
        }
        guard now - windowStart >= 2 else { return }
        log.notice("frames \(self.frames), late \(self.late), dropped \(self.dropped), worst \(Int(self.worst * 1000)) ms, frame \(Int(expected * 1000)) ms")
        frames = 0; late = 0; dropped = 0; worst = 0; windowStart = now
    }
}
#endif
