import ComposableArchitecture
import Foundation

/// Keeps what the person shares of their own calendars current in the house,
/// for as long as the tab bar is up.
///
/// App-wide, like `CalendarMirrorFeature`, and for the same reason: Calendar
/// being closed must not stop a housemate seeing that you are busy. The phone
/// is the only place the calendars are, so it uploads: each shared calendar's
/// next few weeks, replaced whole, when the app opens or comes back, when a
/// setting moves, and when the phone's calendar database changes (a second
/// after the last change, and never more than once in five minutes for a
/// calendar whose settings have not moved). A phone only syncs while NestZone
/// runs, and Settings says so.
///
/// Three rules decide what leaves the phone:
/// - only the calendars the person picked, at the level they picked: at Busy
///   only the title and the location are never even handed on;
/// - never an event NestZone itself wrote into a calendar (`copyIdentifiers`),
///   or the house would see each of its own events twice;
/// - nothing at all unless the house has Plus. Stopping is never gated, and
///   neither is it ever skipped: Settings records "forget this" in the choices
///   and this feature carries it out, retrying on every sync, so an Off is
///   true on the server and not only on the screen.
@Reducer
public struct CalendarShareFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var userID: UserID?

        @Shared(.calendarShareChoicesRaw) var choicesRaw: String
        @Shared(.calendarShareWeeks) var weeks: Int
        @Shared(.calendarShareDefaultLevelRaw) var defaultLevelRaw: String
        @Shared(.pro) var pro: ProStatus

        /// A pass is running; a trigger that arrives meanwhile is folded into
        /// one more pass afterwards.
        var isSyncing = false
        var again = false
        /// The list last given to the server in this run, so an unchanged list
        /// is not sent on every pass.
        var declared: [SharedCalendarEntry]?
        /// When each calendar was last uploaded, and under which settings.
        var uploads: [String: Upload] = [:]
        /// The server refused uploads for Plus: nothing more is tried until
        /// the house's status or a setting moves.
        var isBlocked = false

        struct Upload: Equatable, Sendable {
            var at: Date
            var stamp: String
        }

        public init(homeID: HomeID, userID: UserID?) {
            self.homeID = homeID
            self.userID = userID
        }

        var choices: CalendarShareChoices { .decode(choicesRaw) }
        var defaultLevel: CalendarShareLevel { CalendarShareLevel(rawValue: defaultLevelRaw) ?? .busy }
    }

    public enum Action {
        case task
        /// A setting, Plus or the choice of calendars moved.
        case settingsChanged
        case becameActive
        case storeChanged
        case sync(Trigger)
        case calendarsLoaded([DeviceCalendar], Trigger)
        case finished(Outcome)
        case stopped(HomeID, Set<String>, all: Bool)

        public enum Trigger: Equatable, Sendable {
            case launch, foreground, settings, storeChanged, retry
        }

        public struct Outcome: Equatable, Sendable {
            var declared: [SharedCalendarEntry]?
            var uploads: [String: State.Upload] = [:]
            var blocked = false
            /// When something was held back by the five-minute rule, the time
            /// it may go.
            var retryAt: Date?
        }
    }

    private enum CancelID { case store, debounce, retry }

    /// Between two uploads of one calendar whose settings did not change.
    static let interval: TimeInterval = 5 * 60
    /// The server keeps at most this many items per calendar.
    static let itemCap = 500

    @Dependency(\.calendarShare) var calendarShare
    @Dependency(\.deviceCalendar) var deviceCalendar
    @Dependency(\.calendarMirror) var calendarMirror
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .send(.sync(.launch)),
                    .run { send in
                        for await _ in deviceCalendar.changes() { await send(.storeChanged) }
                    }
                    .cancellable(id: CancelID.store, cancelInFlight: true)
                )

            case .settingsChanged:
                state.isBlocked = false
                return .send(.sync(.settings))

            case .becameActive:
                return .send(.sync(.foreground))

            case .storeChanged:
                // A burst of changes, ours included, is one pass, a moment later.
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.sync(.storeChanged))
                }
                .cancellable(id: CancelID.debounce, cancelInFlight: true)

            case let .sync(trigger):
                guard !state.isSyncing else {
                    state.again = true
                    return .none
                }
                let house = state.choices.house(state.homeID)
                let homeID = state.homeID
                let needsStop = house.stopAll || !house.stopKeys.isEmpty
                // Nothing to forget and nothing shared: nothing to do, and no
                // call is made for a person who never shared.
                guard house.isOn || needsStop else { return .none }
                state.isSyncing = true
                return .run { send in
                    // Forgetting comes first and is never gated.
                    if needsStop {
                        await stop(homeID, all: house.stopAll, keys: house.stopKeys, send)
                    }
                    guard house.isOn else {
                        await send(.finished(.init()))
                        return
                    }
                    guard deviceCalendar.access() == .granted else {
                        await send(.finished(.init()))
                        return
                    }
                    await send(.calendarsLoaded(await deviceCalendar.shareableCalendars(), trigger))
                }

            case let .stopped(homeID, keys, all):
                guard homeID == state.homeID else { return .none }
                state.$choicesRaw.withLock { raw in
                    var choices = CalendarShareChoices.decode(raw)
                    choices.update(homeID) { house in
                        // Only what was carried out: a switch turned back on
                        // meanwhile has nothing left to forget.
                        if all { house.stopAll = false }
                        house.stopKeys.subtract(keys)
                    }
                    raw = choices.raw
                }
                if all { state.declared = nil; state.uploads = [:] }
                return .none

            case let .calendarsLoaded(calendars, trigger):
                guard state.pro.isLoaded, state.pro.isPro, !state.isBlocked else {
                    state.isSyncing = false
                    return finishedAgain(&state)
                }
                let homeID = state.homeID
                let defaultLevel = state.defaultLevel
                let keys = calendars.map(\.key)
                state.$choicesRaw.withLock { raw in
                    var choices = CalendarShareChoices.decode(raw)
                    let before = choices
                    choices.adoptNew(homeID, keys: keys, defaultLevel: defaultLevel)
                    if choices != before { raw = choices.raw }
                }

                let house = state.choices.house(homeID)
                // Only what is still on the phone and still shared.
                let wanted: [(DeviceCalendar, CalendarShareLevel)] = calendars.compactMap {
                    let level = house.level(of: $0.key)
                    return level.isShared ? ($0, level) : nil
                }
                let weeks = min(12, max(4, state.weeks))
                let from = Calendar.current.startOfDay(for: now)
                let to = from.addingTimeInterval(TimeInterval(weeks * 7) * 86_400)
                let entries = wanted.map {
                    SharedCalendarEntry(key: $0.key, name: $0.title, colorHex: $0.colorHex, level: $1)
                }
                let previous = state.declared
                let uploads = state.uploads
                let current = now

                return .run { send in
                    var result = Action.Outcome(declared: previous, uploads: uploads)
                    do {
                        // The list first: the server refuses an upload for a
                        // calendar it has not been told about.
                        if entries != previous {
                            if entries.isEmpty {
                                try await calendarShare.stop(homeID, nil)
                            } else {
                                _ = try await calendarShare.setCalendars(homeID, entries, weeks * 7)
                            }
                            result.declared = entries
                            // A different list is a different share: everything
                            // is sent again.
                            result.uploads = [:]
                        }

                        let skip = await calendarMirror.copyIdentifiers()
                        let due = wanted.filter { calendar, level in
                            let stamp = Self.stamp(calendar, level, weeks: weeks, from: from)
                            guard let last = result.uploads[calendar.key], last.stamp == stamp else { return true }
                            let next = last.at.addingTimeInterval(Self.interval)
                            if next > current {
                                // Held back by the five-minute rule; the retry
                                // catches it once the time is up.
                                if trigger == .storeChanged || trigger == .retry {
                                    result.retryAt = min(result.retryAt ?? next, next)
                                }
                                return false
                            }
                            return true
                        }
                        guard !due.isEmpty else {
                            await send(.finished(result))
                            return
                        }

                        let events = await deviceCalendar.events(due.map { $0.0.id }, from, to)
                        let byCalendar = Dictionary(grouping: events.filter { !skip.contains($0.eventIdentifier) }, by: \.calendarID)

                        for (calendar, level) in due {
                            let items = Self.items(byCalendar[calendar.id] ?? [], level: level)
                            let stamp = Self.stamp(calendar, level, weeks: weeks, from: from)
                            do {
                                _ = try await replace(homeID, calendar.key, from, to, items, entries, weeks)
                                result.uploads[calendar.key] = .init(at: current, stamp: stamp)
                            } catch let error as AppError {
                                if case .proRequired = error {
                                    // Not Plus after all: stop quietly.
                                    result.blocked = true
                                    break
                                }
                                // Offline or refused: the next trigger tries
                                // again; nothing here is shown.
                            }
                        }
                    } catch let error as AppError {
                        if case .proRequired = error { result.blocked = true }
                    } catch {}
                    await send(.finished(result))
                }

            case let .finished(result):
                state.isSyncing = false
                state.declared = result.declared
                state.uploads = result.uploads
                if result.blocked { state.isBlocked = true }
                let again = finishedAgain(&state)
                guard let retryAt = result.retryAt, !result.blocked else { return again }
                let wait = max(1, retryAt.timeIntervalSince(now) + 1)
                return .merge(
                    again,
                    .run { send in
                        try await clock.sleep(for: .seconds(wait))
                        await send(.sync(.retry))
                    }
                    .cancellable(id: CancelID.retry, cancelInFlight: true)
                )
            }
        }
    }

    private func finishedAgain(_ state: inout State) -> Effect<Action> {
        guard state.again else { return .none }
        state.again = false
        return .send(.sync(.settings))
    }

    // MARK: Server calls

    private func stop(_ homeID: HomeID, all: Bool, keys: Set<String>, _ send: Send<Action>) async {
        do {
            if all {
                try await calendarShare.stop(homeID, nil)
            } else {
                for key in keys.sorted() { try await calendarShare.stop(homeID, key) }
            }
            await send(.stopped(homeID, keys, all: all))
        } catch {
            // Kept in the choices; the next sync tries again.
        }
    }

    /// One calendar's upload. A calendar the server has forgotten (its
    /// 30-day sweep emptied the list) is `NOT_FOUND`: the list is sent again
    /// from the phone's own choice and the upload tried once more.
    private func replace(
        _ homeID: HomeID,
        _ key: String,
        _ from: Date,
        _ to: Date,
        _ items: [SharedItemUpload],
        _ entries: [SharedCalendarEntry],
        _ weeks: Int
    ) async throws -> Int {
        do {
            return try await calendarShare.replace(homeID, key, from, to, items)
        } catch AppError.refused(.notFound) {
            _ = try await calendarShare.setCalendars(homeID, entries, weeks * 7)
            return try await calendarShare.replace(homeID, key, from, to, items)
        }
    }

    // MARK: What is sent

    /// What a calendar's settings add up to: when it changes, an upload is
    /// owed whatever the clock says. The start of the window is in it so a new
    /// day slides the window.
    static func stamp(_ calendar: DeviceCalendar, _ level: CalendarShareLevel, weeks: Int, from: Date) -> String {
        "\(calendar.key)|\(level.rawValue)|\(weeks)|\(Int(from.timeIntervalSince1970))|\(calendar.title)"
    }

    /// The upload for one calendar at one level. Busy only drops the title and
    /// the location here, before anything is built to send.
    static func items(_ events: [DeviceEvent], level: CalendarShareLevel) -> [SharedItemUpload] {
        let calendar = Calendar.current
        let sorted = events.sorted { $0.start < $1.start }
        var out: [SharedItemUpload] = []
        out.reserveCapacity(min(sorted.count, itemCap))
        for event in sorted.prefix(itemCap) {
            var start = event.start
            var end = event.end
            if event.isAllDay {
                // The house writes an all-day item as midnight to the midnight
                // after its last day; EventKit ends it at 23:59:59.
                start = calendar.startOfDay(for: start)
                end = calendar.startOfDay(for: end.addingTimeInterval(1))
                if end <= start { end = calendar.date(byAdding: .day, value: 1, to: start) ?? start }
            } else if end < start {
                end = start
            }
            let details = level == .details
            let title = details ? event.title.trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let location = details ? event.location?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            out.append(SharedItemUpload(
                startsAt: start,
                endsAt: end,
                isAllDay: event.isAllDay,
                title: title.isEmpty ? nil : title,
                location: (location?.isEmpty ?? true) ? nil : location
            ))
        }
        return out
    }
}
