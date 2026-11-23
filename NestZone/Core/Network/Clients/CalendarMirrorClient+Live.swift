import ComposableArchitecture
import Foundation

extension CalendarMirrorClient: DependencyKey {
    public static let liveValue = CalendarMirrorClient(
        sync: { request, device in try await MirrorEngine.shared.sync(request, device: device) },
        removeAll: { device, home, forget in
            await MirrorEngine.shared.removeAll(device: device, home: home, forgetChoices: forget)
        },
        knownHomes: { await MirrorEngine.shared.knownHomes() },
        copyCount: { await MirrorEngine.shared.copyCount() },
        setOverride: { home, event, calendars in
            await MirrorEngine.shared.setOverride(home, event, calendars)
        },
        override: { home, event in await MirrorEngine.shared.override(home, event) },
        copyCalendars: { home, event in await MirrorEngine.shared.copyCalendars(home, event) },
        hasOverrides: { home in await MirrorEngine.shared.hasOverrides(home) },
        isCopy: { id in await MirrorEngine.shared.isCopy(id) },
        copyIdentifiers: { await MirrorEngine.shared.copyIdentifiers() },
        overridesChanged: {
            AsyncStream { continuation in
                let observer = MirrorObserver(
                    NotificationCenter.default.addObserver(
                        forName: .nestZoneMirrorOverridesChanged, object: nil, queue: nil
                    ) { _ in continuation.yield() }
                )
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(observer.token)
                }
            }
        }
    )
}

private struct MirrorObserver: @unchecked Sendable {
    let token: NSObjectProtocol
    init(_ token: NSObjectProtocol) { self.token = token }
}

/// The mirror, off the main actor.
///
/// An actor because a sync is a long conversation with EventKit and the map it
/// keeps must not be written by two of them at once. A pass changes the map in
/// memory as it goes and writes it to disk once per batch of EventKit writes
/// (fifty, or the end of the pass), after the batch has been committed. A crash
/// between a write to the calendar and the map being saved can cost at most
/// that batch being found again, and a copy found again is adopted by its
/// marker (`MirrorMarker`), never added a second time.
actor MirrorEngine {
    static let shared = MirrorEngine()

    private var map: MirrorMap?
    private var isDirty = false
    private var running = false
    private var queued: (MirrorRequest, DeviceCalendarClient)?
    /// When each scope (a home id, or `*` for all) was last removed. A request
    /// built before that moment was built from a session, a home or a setting
    /// that has since ended, and must not put the copies back.
    private var removedAt: [String: Date] = [:]

    /// Writes between two commits to the calendar database.
    private static let batch = 50
    /// A copy is deleted when this many complete answers in a row lacked it.
    private static let strikesToDelete = 2
    /// Seconds a strike counts for. Two answers of one session; never one from
    /// before a relaunch and one after.
    private static let strikeLife: TimeInterval = 600

    private let fileURL: URL = {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appending(component: "calendar-mirror.json")
    }()

    // MARK: The map

    private func current() -> MirrorMap {
        if let map { return map }
        let loaded = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode(MirrorMap.self, from: $0) } ?? MirrorMap()
        map = loaded
        return loaded
    }

    /// Changes the map in memory. It reaches the disk with the next `flush`.
    private func mutate(_ change: (inout MirrorMap) -> Void) {
        var next = current()
        change(&next)
        map = next
        isDirty = true
    }

    private func flush() {
        guard isDirty, let map else { return }
        isDirty = false
        if let data = try? JSONEncoder().encode(map) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func copyCount() -> Int {
        current().entries.values.reduce(0) { $0 + $1.copies.count }
    }

    func knownHomes() -> Set<HomeID> {
        let map = current()
        var homes = Set(map.entries.values.map(\.homeID))
        for key in map.overrides.keys {
            if let home = key.split(separator: "/").first { homes.insert(String(home)) }
        }
        return Set(homes.map { HomeID($0) })
    }

    func isCopy(_ identifier: String) -> Bool { current().isCopy(identifier) }
    func copyIdentifiers() -> Set<String> { current().copyIdentifiers }

    func override(_ home: HomeID, _ event: EventID) -> [String]? {
        current().overrides[MirrorMap.overrideKey(home.rawValue, event.rawValue)]
    }

    func copyCalendars(_ home: HomeID, _ event: EventID) -> [String] {
        var calendars: Set<String> = []
        for entry in current().entries.values where entry.homeID == home.rawValue && entry.eventID == event.rawValue {
            calendars.formUnion(entry.copies.keys)
        }
        return calendars.sorted()
    }

    /// Whether any event in this home is pinned to a calendar. An empty pin
    /// ("not this one") copies nothing and is no reason to keep reading.
    func hasOverrides(_ home: HomeID) -> Bool {
        let prefix = home.rawValue + "/"
        return current().overrides.contains { $0.key.hasPrefix(prefix) && !$0.value.isEmpty }
    }

    func setOverride(_ home: HomeID, _ event: EventID, _ calendars: [String]?) {
        let key = MirrorMap.overrideKey(home.rawValue, event.rawValue)
        guard current().overrides[key] != calendars else { return }
        mutate { map in
            map.overrides[key] = calendars
            var dates = map.overrideDates ?? [:]
            dates[key] = calendars == nil ? nil : Date.now.timeIntervalSince1970
            map.overrideDates = dates
        }
        flush()
        NotificationCenter.default.post(name: .nestZoneMirrorOverridesChanged, object: nil)
    }

    // MARK: Sync

    private func isStale(_ request: MirrorRequest) -> Bool {
        let floor = max(removedAt["*"] ?? .distantPast, removedAt[request.homeID.rawValue] ?? .distantPast)
        return request.now <= floor
    }

    func sync(_ request: MirrorRequest, device: DeviceCalendarClient) async throws -> MirrorSummary {
        if isStale(request) {
            var stale = MirrorSummary()
            stale.didSync = false
            return stale
        }
        if running {
            queued = (request, device)
            var merged = MirrorSummary()
            merged.didSync = false
            return merged
        }
        running = true
        defer { running = false }
        return await drain((request, device))
    }

    /// Runs `first`, then whatever arrived while it ran, until nothing is left.
    private func drain(_ first: (MirrorRequest, DeviceCalendarClient)) async -> MirrorSummary {
        var total = MirrorSummary()
        total.didSync = false
        var next: (MirrorRequest, DeviceCalendarClient)? = first
        while let (request, device) = next {
            queued = nil
            total.add(await pass(request, device: device))
            next = queued
        }
        return total
    }

    /// Marker prefix for a scope: every copy of one house, or of any.
    private static func markerPrefix(_ home: String?) -> String {
        home.map { "\(MirrorMarker.scheme)://event/\($0)/" } ?? "\(MirrorMarker.scheme)://event/"
    }

    func removeAll(device: DeviceCalendarClient, home: HomeID?, forgetChoices: Bool) async -> Int {
        while running { try? await Task.sleep(for: .milliseconds(100)) }
        running = true
        defer { running = false }

        let scope = home?.rawValue
        var removed = 0
        var queuedWrites = 0
        var snapshots: [String: MirrorMap.Entry] = [:]
        var removedIDs: Set<String> = []

        // What the map knows. A copy that could not be removed (no access, a
        // failed write) stays remembered, so the next attempt finds it.
        for (key, entry) in current().entries where scope == nil || entry.homeID == scope {
            var kept = entry
            for (calendar, copy) in entry.copies {
                do {
                    queuedWrites += 1
                    try await device.remove(copy.id)
                    removedIDs.insert(copy.id)
                    kept.copies[calendar] = nil
                } catch {}
            }
            snapshots[key] = entry
            mutate { $0.entries[key] = kept.copies.isEmpty ? nil : kept }
        }

        // And what the map does not: a copy a restore, a second phone or a lost
        // map left behind says what it is in its URL. A year back and ahead is
        // as far as a copy is ever planned or kept.
        if device.access() == .granted {
            let ids = await device.calendars().map(\.id)
            let prefix = Self.markerPrefix(scope)
            let from = Date.now.addingTimeInterval(-365 * 86_400)
            let to = Date.now.addingTimeInterval(365 * 86_400)
            for event in await device.marked(ids, from, to) where event.marker.hasPrefix(prefix) {
                guard !removedIDs.contains(event.eventIdentifier) else { continue }
                do {
                    queuedWrites += 1
                    try await device.remove(event.eventIdentifier)
                    removedIDs.insert(event.eventIdentifier)
                } catch {}
            }
        }

        if queuedWrites > 0 {
            do {
                _ = try await device.commit()
                removed = removedIDs.count
            } catch {
                // None of it landed: everything is as it was.
                mutate { map in for (key, entry) in snapshots { map.entries[key] = entry } }
            }
        }
        if forgetChoices {
            let prefix = scope.map { $0 + "/" }
            mutate { map in
                map.overrides = map.overrides.filter { prefix != nil && !$0.key.hasPrefix(prefix!) }
                map.overrideDates = map.overrideDates?.filter { prefix != nil && !$0.key.hasPrefix(prefix!) }
            }
        }
        flush()

        // Our own commit tells the calendar database it changed, which queues a
        // sync built before this removal. It is covered by it and dropped; one
        // for another house is not, and runs.
        removedAt[scope ?? "*"] = .now
        if let waiting = queued {
            queued = nil
            if scope != nil, waiting.0.homeID.rawValue != scope { _ = await drain(waiting) }
        }
        return removed
    }

    // MARK: A pass

    private func pass(_ request: MirrorRequest, device: DeviceCalendarClient) async -> MirrorSummary {
        var summary = MirrorSummary()
        summary.didSync = false
        guard device.access() == .granted, !isStale(request) else { return summary }

        // Two answers that look like "there is nothing to copy into" or "nobody
        // is signed in" are far likelier a calendar database or a session that
        // has not come back yet than a person who deleted every calendar; and
        // acting on them removes copies. Stand down, and sync again when they
        // are back.
        let calendars = await device.calendars()
        guard !calendars.isEmpty else { return summary }
        if request.userID == nil, request.mode == .onlyMine || request.mode == .involvingMe { return summary }
        summary.didSync = true

        let home = request.homeID.rawValue
        let calendarIDs = Set(calendars.map(\.id))
        let prefix = home + "/"
        let overrides = current().overrides
            .filter { $0.key.hasPrefix(prefix) }
            .reduce(into: [String: [String]]()) { $0[String($1.key.dropFirst(prefix.count))] = $1.value }

        let plan = MirrorPlanner.plan(request, overrides: overrides, calendarIDs: calendarIDs)
        let wanted = Set(plan.map(\.key))
        let inAnswer = Set(request.occurrences.compactMap { occurrence -> String? in
            if let owner = occurrence.homeID, owner != request.homeID { return nil }
            return occurrence.eventID.rawValue
        })
        let isComplete = !request.isTruncated

        // With copying off, only what was pinned from the composer is the
        // mirror's business; the rest is what the person chose to keep.
        let managed = current().entries.filter { _, entry in
            entry.homeID == home && (request.mode != .off || overrides[entry.eventID] != nil)
        }
        let present = await device.existing(managed.values.flatMap { $0.copies.values.map(\.id) })

        // Copies found by the marker they carry are read once, and only if
        // needed; EventKit writes are queued and committed in batches.
        markedIndex = nil
        queuedWrites = 0
        snapshots = [:]

        // An event whose entry exists under another key (a series that is now
        // being answered date by date, or the other way round) must not get a
        // second kind of copy from an answer that may be cut short.
        let knownEvents = Set(managed.values.map(\.eventID))

        for copy in plan {
            let key = MirrorMap.entryKey(home, copy.key)
            let existing = current().entries[key]
            if !isComplete, existing == nil, knownEvents.contains(copy.eventID) { continue }

            var entry = existing ?? MirrorMap.Entry(homeID: home, eventID: copy.eventID)
            entry.lastEnd = copy.lastEnd
            entry.strikes = nil
            entry.strikeAt = nil
            let fingerprint = copy.draft.fingerprint

            // Calendars the copy no longer belongs in (unticked in Settings, a
            // different choice in the composer, a calendar that is gone).
            // A calendar missing from the list is unknown, not unwanted: it may
            // be an account that has not finished loading. Its copy and its
            // "deleted by hand" stay as they were.
            for (calendar, ref) in entry.copies where !copy.calendars.contains(calendar) && calendarIDs.contains(calendar) {
                do {
                    noteWrite(key)
                    try await device.remove(ref.id)
                    summary.removed += 1
                } catch { summary.failed += 1; continue }
                entry.copies[calendar] = nil
            }
            entry.dismissed = entry.dismissed.filter { copy.calendars.contains($0) || !calendarIDs.contains($0) }

            for calendar in copy.calendars.sorted() where !entry.dismissed.contains(calendar) {
                do {
                    var ref = entry.copies[calendar]
                    if let remembered = ref, !present.contains(remembered.id) {
                        // Not at the identifier the phone remembers. Before
                        // calling that "deleted by hand", look for a copy that
                        // says it is this one (a restore, another phone).
                        if let id = await found(calendar, copy.draft.marker, request, device, calendarIDs) {
                            ref = .init(id: id, fingerprint: "")
                        } else {
                            // Deleted by hand. Their call; not recreated.
                            entry.copies[calendar] = nil
                            entry.dismissed.insert(calendar)
                            summary.dismissed += 1
                            continue
                        }
                    } else if ref == nil, let id = await found(calendar, copy.draft.marker, request, device, calendarIDs) {
                        // Made before, by this phone's earlier map or another
                        // phone: taken over, not added again.
                        ref = .init(id: id, fingerprint: "")
                    }

                    if let ref {
                        guard ref.fingerprint != fingerprint else { entry.copies[calendar] = ref; continue }
                        noteWrite(key)
                        let id = try await device.save(copy.draft, calendar, ref.id)
                        entry.copies[calendar] = .init(id: id, fingerprint: fingerprint)
                        summary.updated += 1
                    } else {
                        noteWrite(key)
                        let id = try await device.save(copy.draft, calendar, nil)
                        entry.copies[calendar] = .init(id: id, fingerprint: fingerprint)
                        summary.created += 1
                    }
                } catch {
                    summary.failed += 1
                }
            }
            commit(entry, at: key)
            if queuedWrites >= Self.batch { summary.failed += await finishBatch(device) }
        }

        // What the house no longer says. Only from an answer that is whole: an
        // answer cut off at the server's ceiling (`MirrorRequest.answerLimit`)
        // is missing events that still exist, and reading that as a deletion
        // would delete the copies of every series past the cut.
        var dropped: Set<String> = []
        if isComplete {
            let seen = request.previousEventIDs
            for (key, entry) in managed where !wanted.contains(String(key.dropFirst(prefix.count))) {
                // Missing from a window that started before the copy ended
                // means deleted (or no longer wanted); missing from one that
                // started after means only that it is over.
                if let end = entry.lastEnd, end < request.windowStart {
                    if end < request.now.addingTimeInterval(-14 * 86_400) {
                        store(nil, at: key)
                        dropped.insert(entry.eventID)
                    }
                    continue
                }

                var entry = entry
                if inAnswer.contains(entry.eventID) {
                    // The house still has it: whatever doubt there was is over.
                    entry.strikes = nil
                    entry.strikeAt = nil
                } else if seen?.contains(entry.eventID) != true {
                    // Absent, and not seen going: a doubt, not a deletion,
                    // until a second answer says it too. A doubt older than
                    // `strikeLife` is from another launch or another day and
                    // starts again at one.
                    let at = request.answeredAt.timeIntervalSince1970
                    if let last = entry.strikeAt, at - last > Self.strikeLife { entry.strikes = nil }
                    if (entry.strikeAt ?? 0) < at {
                        entry.strikes = (entry.strikes ?? 0) + 1
                        entry.strikeAt = at
                    }
                    if (entry.strikes ?? 0) < Self.strikesToDelete {
                        store(entry, at: key)
                        continue
                    }
                }

                // Only from calendars the phone lists now; one that is missing
                // is unknown, and its copy stays remembered.
                for (calendar, ref) in entry.copies where calendarIDs.contains(calendar) {
                    do {
                        noteWrite(key)
                        try await device.remove(ref.id)
                        summary.removed += 1
                        entry.copies[calendar] = nil
                    } catch {
                        // Stays remembered, and is tried again next pass.
                        summary.failed += 1
                    }
                }
                if entry.copies.isEmpty {
                    store(nil, at: key)
                    dropped.insert(entry.eventID)
                } else {
                    store(entry, at: key)
                }
                if queuedWrites >= Self.batch { summary.failed += await finishBatch(device) }
            }
            pruneOverrides(home: home, inAnswer: inAnswer, dropped: dropped, now: request.now)
        }
        summary.failed += await finishBatch(device)
        return summary
    }

    // MARK: Batches

    /// What the pass has queued in EventKit and not yet committed, and each
    /// entry as it was before the first queued write to it, so a commit that
    /// fails puts the map back to what is true.
    private var queuedWrites = 0
    private var snapshots: [String: MirrorMap.Entry?] = [:]
    /// `calendar \u{1F} marker` -> the event carrying it, for this pass.
    private var markedIndex: [String: String]?

    private func noteWrite(_ key: String) {
        queuedWrites += 1
        if snapshots[key] == nil { snapshots[key] = .some(current().entries[key]) }
    }

    /// Commits what is queued and writes the map. Answers how many writes
    /// did not land.
    private func finishBatch(_ device: DeviceCalendarClient) async -> Int {
        var failed = 0
        if queuedWrites > 0 {
            do {
                // New events were saved without committing, so their final
                // identifiers are known only now.
                let resolved = try await device.commit()
                mutate { map in
                    for (key, var entry) in map.entries {
                        var changed = false
                        for (calendar, ref) in entry.copies where ref.id.hasPrefix(DeviceCalendarStore.pendingPrefix) {
                            changed = true
                            if let final = resolved[ref.id] {
                                entry.copies[calendar] = .init(id: final, fingerprint: ref.fingerprint)
                            } else {
                                // Written, but no identifier to remember it by:
                                // forgotten, and found again by its marker.
                                entry.copies[calendar] = nil
                                failed += 1
                            }
                        }
                        if changed { map.entries[key] = entry.copies.isEmpty && entry.dismissed.isEmpty ? nil : entry }
                    }
                }
            } catch {
                failed = queuedWrites
                let before = snapshots
                mutate { map in for (key, entry) in before { map.entries[key] = entry } }
            }
        }
        queuedWrites = 0
        snapshots = [:]
        flush()
        return failed
    }

    private func found(
        _ calendar: String,
        _ marker: URL?,
        _ request: MirrorRequest,
        _ device: DeviceCalendarClient,
        _ calendarIDs: Set<String>
    ) async -> String? {
        guard let marker else { return nil }
        if markedIndex == nil {
            let events = await device.marked(Array(calendarIDs), request.windowStart, request.windowEnd)
            markedIndex = Dictionary(
                events.map { ($0.calendarID + "\u{1F}" + $0.marker, $0.eventIdentifier) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        return markedIndex?[calendar + "\u{1F}" + marker.absoluteString]
    }

    /// A pin for an event the house no longer has stops mattering, and while it
    /// is kept it keeps the whole window subscribed with copying off.
    private func pruneOverrides(home: String, inAnswer: Set<String>, dropped: Set<String>, now: Date) {
        let prefix = home + "/"
        let map = current()
        var gone: [String] = []
        for key in map.overrides.keys where key.hasPrefix(prefix) {
            let event = String(key.dropFirst(prefix.count))
            guard !inAnswer.contains(event) else { continue }
            let hasEntry = map.entries.values.contains { $0.homeID == home && $0.eventID == event }
            // Only a pin whose event is known gone: its copies were just let
            // go from a complete answer. Age proves nothing (an event further
            // ahead than the window has not turned up yet).
            guard !hasEntry, dropped.contains(event) else { continue }
            gone.append(key)
        }
        guard !gone.isEmpty else { return }
        mutate { map in
            for key in gone {
                map.overrides[key] = nil
                map.overrideDates?[key] = nil
            }
        }
    }

    /// An entry with no copy and nothing dismissed remembers nothing.
    private func commit(_ entry: MirrorMap.Entry, at key: String) {
        store(entry.copies.isEmpty && entry.dismissed.isEmpty ? nil : entry, at: key)
    }

    private func store(_ entry: MirrorMap.Entry?, at key: String) {
        mutate { $0.entries[key] = entry }
    }
}
