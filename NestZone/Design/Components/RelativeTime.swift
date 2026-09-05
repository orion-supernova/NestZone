import Observation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The one ticking clock behind every "3 min ago" label in the app.
///
/// `Text(date, format: .relative(...))` renders once and is never asked again,
/// which is why a note posted a second ago read "1 second ago" for the rest of
/// the session while the note beside it sat at "0 seconds ago". A shared clock
/// re-renders those labels instead — one timer for the whole app rather than a
/// `TimelineView` per row, and no network traffic at all: the timestamps are
/// already in hand, only the phrasing goes stale.
@MainActor
@Observable
public final class RelativeTimeClock {
    public static let shared = RelativeTimeClock()

    /// Advances on every tick. Reading it inside a `body` is what subscribes
    /// that view to the tick; the value itself is deliberately not used for
    /// formatting, so a label that has just appeared is never stale.
    public private(set) var tick: Int = 0

    /// Half a minute. Fine enough that "Just now" becomes "1 min ago" within a
    /// few seconds of it being true, coarse enough to cost nothing.
    private static let interval: Duration = .seconds(30)

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var foregroundObserver: (any NSObjectProtocol)?

    private init() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.interval)
                self?.tick &+= 1
            }
        }

        #if canImport(UIKit)
        // Coming back from the background can land mid-interval, with every
        // label showing what was true when the app was suspended. Tick once on
        // the way in so the first frame is right.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick &+= 1 }
        }
        #endif
    }
}

/// How long ago something happened, in the coarsest unit that still says
/// something useful.
///
/// Seconds are deliberately absent: "1 second ago" is noise, and two notes
/// written in the same breath reading "1 second ago" and "0 seconds ago" is
/// worse than noise. Anything under a minute is simply "Just now".
public enum RelativeTime {
    public static func text(for date: Date, now: Date = .now) -> Text {
        let seconds = now.timeIntervalSince(date)

        // A row written on the server a moment ago can land a second or two in
        // the device's future when the two clocks disagree. That is "just now",
        // not "in 2 seconds".
        guard seconds >= 60 else { return Text(L10n.timeJustNow) }

        let minutes = Int(seconds) / 60
        if minutes < 60 { return Text(L10n.timeMinutesAgo(minutes)) }

        let hours = minutes / 60
        if hours < 24 { return Text(L10n.timeHoursAgo(hours)) }

        let days = hours / 24
        if days < 7 { return Text(L10n.timeDaysAgo(days)) }

        // Past a week the exact age stops mattering and the date itself is the
        // more useful answer.
        return Text(
            date.formatted(
                Date.FormatStyle(date: .abbreviated, time: .omitted)
                    .locale(L10n.locale)
            )
        )
    }
}

/// A relative timestamp that keeps up with the clock.
///
/// Drop-in replacement for `Text(date, format: .relative(...))` on anything that
/// has already happened.
public struct RelativeTimeText: View {
    private let date: Date

    public init(_ timestamp: Timestamp) { self.date = timestamp.date }
    public init(_ date: Date) { self.date = date }

    public var body: some View {
        // Subscribes to the shared tick. The phrase is computed against the
        // real current time rather than the clock's, so a label that appears
        // between two ticks is still correct to the second it is drawn.
        let _ = RelativeTimeClock.shared.tick
        RelativeTime.text(for: date)
    }
}
