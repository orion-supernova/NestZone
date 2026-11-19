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
/// switch's work is split across frames and not only how bad the worst is,
/// and with the main thread's CPU time over the same frame: close to the
/// frame's length when the main thread was working, far below it when it was
/// waiting. Neither is steady on a Mac that is busy with something else (a
/// build in the next window made the same open 110 ms, then 317 ms of CPU),
/// so compare two builds in interleaved runs, never one after the other.
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
    private var lastCPU: UInt64 = 0
    private let verbose = UserDefaults.standard.integer(forKey: "frameMeter") >= 2

    /// Launch, as the frame meter sees it: milliseconds since the process was
    /// created, logged when the launch screen first appears and on the first
    /// frame after the tab container does. The process's own start time, so it
    /// includes the time before `main` (dyld, which a simulator makes slow).
    private var todayPending = false
    private var todayLogged = false

    private func sinceLaunch() -> Int {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return -1 }
        let start = info.kp_proc.p_un.__p_starttime
        let began = Date(timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1e6)
        return Int(Date().timeIntervalSince(began) * 1000)
    }

    /// The tab container is in the hierarchy; the next frame is the one that
    /// draws it.
    func todayAppeared() {
        guard link != nil, !todayLogged else { return }
        todayPending = true
    }

    func startIfAsked() {
        guard link == nil, UserDefaults.standard.integer(forKey: "frameMeter") > 0 else { return }
        log.notice("launch: first view \(self.sinceLaunch()) ms after process start")
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp, expected = link.targetTimestamp - link.timestamp
        let cpu = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        defer { last = now; lastCPU = cpu }
        if todayPending {
            todayPending = false
            todayLogged = true
            log.notice("launch: Today first frame \(self.sinceLaunch()) ms after process start")
        }
        guard last > 0, expected > 0 else { windowStart = now; return }
        let interval = now - last
        frames += 1
        worst = max(worst, interval)
        if interval > expected * 1.5 {
            late += 1
            dropped += Int((interval / expected).rounded()) - 1
            if verbose { log.notice("late frame \(Int(interval * 1000)) ms, main cpu \((cpu - self.lastCPU) / 1_000_000) ms") }
        }
        guard now - windowStart >= 2 else { return }
        log.notice("frames \(self.frames), late \(self.late), dropped \(self.dropped), worst \(Int(self.worst * 1000)) ms, frame \(Int(expected * 1000)) ms")
        frames = 0; late = 0; dropped = 0; worst = 0; windowStart = now
    }
}
#endif
