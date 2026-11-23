import ComposableArchitecture
import Foundation

extension CalendarMirrorClient: DependencyKey {
    public static let liveValue = CalendarMirrorClient(
        sync: { request, device in try await MirrorEngine.shared.sync(request, device: device) },
        removeAll: { device in await MirrorEngine.shared.removeAll(device: device) },
        copyCount: { await MirrorEngine.shared.copyCount() },
        setOverride: { home, event, calendars in
            await MirrorEngine.shared.setOverride(home, event, calendars)
        },
        override: { home, event in await MirrorEngine.shared.override(home, event) },
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
/// keeps must not be written by two of them at once. Every change to
/// `map` goes through `self` and is persisted right after the EventKit write it
/// describes, so a crash between "created" and "remembered" can cost at most
/// one copy being added a second time, never a copy being forgotten.
actor MirrorEngine {
    static let shared = MirrorEngine()

    private var map: MirrorMap?
    private var running = false
    private var queued: (MirrorRequest, DeviceCalendarClient)?

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

    private func save(_ next: MirrorMap) {
        map = next
        if let data = try? JSONEncoder().encode(next) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func copyCount() -> Int {
        current().entries.values.reduce(0) { $0 + $1.copies.count }
    }

    func isCopy(_ identifier: String) -> Bool { current().isCopy(identifier) }
    func copyIdentifiers() -> Set<String> { current().copyIdentifiers }

    func override(_ home: HomeID, _ event: EventID) -> [String]? {
        current().overrides[MirrorMap.overrideKey(home.rawValue, event.rawValue)]
    }

    func hasOverrides(_ home: HomeID) -> Bool {
        let prefix = home.rawValue + "/"
        return current().overrides.keys.contains { $0.hasPrefix(prefix) }
    }

    func setOverride(_ home: HomeID, _ event: EventID, _ calendars: [String]?) {
        var next = current()
        let key = MirrorMap.overrideKey(home.rawValue, event.rawValue)
        guard next.overrides[key] != calendars else { return }
        next.overrides[key] = calendars
        save(next)
        NotificationCenter.default.post(name: .nestZoneMirrorOverridesChanged, object: nil)
    }

    // MARK: Sync

    func sync(_ request: MirrorRequest, device: DeviceCalendarClient) async throws -> MirrorSummary {
        if running {
            queued = (request, device)
            return MirrorSummary()
        }
        running = true
        defer { running = false }

        var total = MirrorSummary()
        var next: (MirrorRequest, DeviceCalendarClient)? = (request, device)
        while let (request, device) = next {
            queued = nil
            total.add(await pass(request, device: device))
            next = queued
        }
        return total
    }

    func removeAll(device: DeviceCalendarClient) async -> Int {
        while running { try? await Task.sleep(for: .milliseconds(100)) }
        running = true
        defer { running = false }

        var next = current()
        var removed = 0
        for entry in next.entries.values {
            for copy in entry.copies.values {
                if (try? await device.remove(copy.id)) != nil { removed += 1 }
            }
        }
        next.entries = [:]
        save(next)
        return removed
    }

    private func pass(_ request: MirrorRequest, device: DeviceCalendarClient) async -> MirrorSummary {
        var summary = MirrorSummary()
        guard device.access() == .granted else { return summary }

        let home = request.homeID.rawValue
        let calendarIDs = Set(await device.calendars().map(\.id))
        let prefix = home + "/"
        let overrides = current().overrides
            .filter { $0.key.hasPrefix(prefix) }
            .reduce(into: [String: [String]]()) { $0[String($1.key.dropFirst(prefix.count))] = $1.value }

        let plan = MirrorPlanner.plan(request, overrides: overrides, calendarIDs: calendarIDs)
        let wanted = Set(plan.map(\.key))

        // With copying off, only what was pinned from the composer is the
        // mirror's business; the rest is what the person chose to keep.
        let managed = current().entries.filter { key, entry in
            entry.homeID == home && (request.mode != .off || overrides[entry.eventID] != nil)
        }
        let present = await device.existing(managed.values.flatMap { $0.copies.values.map(\.id) })

        for copy in plan {
            let key = MirrorMap.entryKey(home, copy.key)
            var entry = current().entries[key] ?? MirrorMap.Entry(homeID: home, eventID: copy.eventID)
            entry.lastEnd = copy.lastEnd
            let fingerprint = copy.draft.fingerprint

            // Calendars the copy no longer belongs in (unticked in Settings, a
            // different choice in the composer, a calendar that is gone).
            for (calendar, ref) in entry.copies where !copy.calendars.contains(calendar) {
                if calendarIDs.contains(calendar) {
                    do { try await device.remove(ref.id); summary.removed += 1 } catch { summary.failed += 1; continue }
                }
                entry.copies[calendar] = nil
            }
            entry.dismissed.formIntersection(copy.calendars)

            for calendar in copy.calendars.sorted() where !entry.dismissed.contains(calendar) {
                do {
                    if let ref = entry.copies[calendar] {
                        guard present.contains(ref.id) else {
                            // Deleted by hand. Their call; not recreated.
                            entry.copies[calendar] = nil
                            entry.dismissed.insert(calendar)
                            summary.dismissed += 1
                            continue
                        }
                        guard ref.fingerprint != fingerprint else { continue }
                        let id = try await device.save(copy.draft, calendar, ref.id)
                        entry.copies[calendar] = .init(id: id, fingerprint: fingerprint)
                        summary.updated += 1
                    } else {
                        let id = try await device.save(copy.draft, calendar, nil)
                        entry.copies[calendar] = .init(id: id, fingerprint: fingerprint)
                        summary.created += 1
                    }
                } catch {
                    summary.failed += 1
                }
                commit(entry, at: key)
            }
            commit(entry, at: key)
        }

        // What the house no longer says. Missing from a window that started
        // before the copy ended means deleted (or no longer wanted); missing
        // from one that started after means only that it is over.
        for (key, entry) in managed where !wanted.contains(String(key.dropFirst(prefix.count))) {
            if let end = entry.lastEnd, end < request.windowStart {
                if end < request.now.addingTimeInterval(-14 * 86_400) { store(nil, at: key) }
                continue
            }
            var failed = false
            for ref in entry.copies.values {
                do { try await device.remove(ref.id); summary.removed += 1 } catch { failed = true; summary.failed += 1 }
            }
            if !failed { store(nil, at: key) }
        }
        return summary
    }

    /// An entry with no copy and nothing dismissed remembers nothing.
    private func commit(_ entry: MirrorMap.Entry, at key: String) {
        store(entry.copies.isEmpty && entry.dismissed.isEmpty ? nil : entry, at: key)
    }

    private func store(_ entry: MirrorMap.Entry?, at key: String) {
        var next = current()
        next.entries[key] = entry
        save(next)
    }
}
