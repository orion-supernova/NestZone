import BackgroundTasks
import ComposableArchitecture
import Foundation

/// The calendar passes, run by the system now and then while NestZone is not.
///
/// A phone only syncs while the app runs, and a person who shares a calendar
/// does not open the app for every meeting they add. So when the app goes to
/// the background it asks iOS for a refresh (no sooner than an hour; iOS
/// decides when, and how often), and when it is given one this restores the
/// session through the normal path, runs the sharing upload, the mirror and the
/// housemates' copies once each with a time budget, and asks for the next.
///
/// It builds the same reducers the tab bar runs, headless: no screen exists in
/// a background launch, so nothing can be asked of the root store. A session
/// that cannot be restored ends it quietly, and so does a phone with nothing
/// switched on.
@MainActor
struct CalendarBackgroundSync {
    static let identifier = "com.walhallaa.NestZone.calendarSync"
    /// iOS gives a refresh about thirty seconds; leave room to say we are done.
    static let budget: Duration = .seconds(22)

    @Dependency(\.deviceCalendar) private var deviceCalendar
    @Dependency(\.auth) private var auth
    @Dependency(\.pro) private var pro

    @Shared(.selectedHomeIDRaw) private var rawHome
    @Shared(.calendarShareChoicesRaw) private var shareChoicesRaw
    @Shared(.calendarCopyMode) private var copyMode
    @Shared(.calendarCopyChoicesRaw) private var copyChoicesRaw
    @Shared(.pro) private var proStatus
    @Shared(.calendarSyncActive) private var active

    /// Called once, before the app finishes launching: iOS refuses a handler
    /// registered later.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            let box = TaskBox(task: task)
            Task { @MainActor in await CalendarBackgroundSync().handle(box.task) }
        }
    }

    /// Asks for the next refresh, when there is anything to refresh.
    static func schedule() {
        guard CalendarBackgroundSync().isWanted else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Sharing or copying is on, and the phone has said yes to its calendars.
    private var isWanted: Bool {
        guard deviceCalendar.access() == .granted, let home = rawHome.map({ HomeID(rawValue: $0) }) else { return false }
        let sharing = CalendarShareChoices.decode(shareChoicesRaw).house(home).isOn
        let copying = copyMode != .off
            || !CalendarCopyChoices.decode(copyChoicesRaw).house(home).owners.isEmpty
        return sharing || copying
    }

    private func handle(_ task: BGTask) async {
        // The next one is asked for first, so a pass that is cut short still
        // has a successor.
        Self.schedule()
        let work = Task { await run() }
        task.expirationHandler = { work.cancel() }
        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
    }

    private func run() async {
        guard isWanted, let rawHome else { return }
        let homeID = HomeID(rawValue: rawHome)
        guard await auth.restoreSession() == .restored else { return }

        // The gates read Plus from here; a first answer is all they need.
        do {
            for try await payload in pro.status(homeID) {
                $proStatus.withLock { $0 = ProStatus(payload, now: Date()) }
                break
            }
        } catch {}
        var user: User?
        do {
            for try await current in auth.currentUser() {
                user = current
                break
            }
        } catch {}

        let share = Store(initialState: CalendarShareFeature.State(homeID: homeID, userID: user?.id)) {
            CalendarShareFeature()
        }
        let mirror = Store(initialState: CalendarMirrorFeature.State(homeID: homeID, userID: user?.id)) {
            CalendarMirrorFeature()
        }
        let copies = Store(initialState: SharedCopyFeature.State(homeID: homeID)) {
            SharedCopyFeature()
        }
        // `.task` opens each pass's reads; `syncNow` asks for one pass and
        // puts the feature in `active` until it is done with it.
        let tasks = [
            mirror.send(.task), copies.send(.task),
        ]
        share.send(.syncNow)
        mirror.send(.syncNow)
        copies.send(.syncNow)

        let deadline = ContinuousClock.now + Self.budget
        try? await Task.sleep(for: .seconds(1))
        while !active.isEmpty, ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(300))
        }
        for task in tasks { task.cancel() }
    }
}

/// `BGTask` is not `Sendable`; it is only handed to the main actor and used
/// there.
private struct TaskBox: @unchecked Sendable {
    let task: BGTask
}
