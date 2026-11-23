import ComposableArchitecture
import Foundation

extension SharedCopyClient: DependencyKey {
    public static let liveValue = SharedCopyClient(
        sync: { request, device in try await SharedCopyEngine.shared.sync(request, device: device) },
        removeOwner: { device, home, owner in
            await SharedCopyEngine.shared.removeOwner(device: device, home: home, owner: owner)
        },
        removeAll: { device, home in await SharedCopyEngine.shared.removeAll(device: device, home: home) },
        knownHomes: { await SharedCopyEngine.shared.knownHomes() }
    )
}

/// The housemates' calendars, off the main actor. The mirror's machinery
/// (marker, id map, batched commits, "two complete answers before a delete")
/// for a different thing: not house events, which have an id, but a shared
/// calendar's items, which have only their times.
///
/// One dedicated calendar per housemate and house. Taking it off the phone is
/// deleting that calendar, which is also how everything in it goes at once.
actor SharedCopyEngine {
    static let shared = SharedCopyEngine()

    private var map: SharedCopyMap?
    private var isDirty = false
    private var running = false
    private var queued: (SharedCopyRequest, DeviceCalendarClient)?
    private var removedAt: [String: Date] = [:]

    private static let batch = 50
    private static let strikesToDelete = 2
    private static let strikeLife: TimeInterval = 600

    private let fileURL: URL = {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appending(component: "shared-calendar-copies.json")
    }()

    // MARK: The map

    private func current() -> SharedCopyMap {
        if let map { return map }
        let loaded = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode(SharedCopyMap.self, from: $0) } ?? SharedCopyMap()
        map = loaded
        return loaded
    }

    private func mutate(_ change: (inout SharedCopyMap) -> Void) {
        var next = current()
        change(&next)
        map = next
        isDirty = true
    }

    private func flush() {
        guard isDirty, let map else { return }
        isDirty = false
        if let data = try? JSONEncoder().encode(map) { try? data.write(to: fileURL, options: .atomic) }
    }

    func knownHomes() -> Set<HomeID> {
        Set(current().calendars.values.map { HomeID($0.homeID) })
    }

    // MARK: Sync

    private func isStale(_ request: SharedCopyRequest) -> Bool {
        let floor = max(removedAt["*"] ?? .distantPast, removedAt[request.homeID.rawValue] ?? .distantPast)
        return request.now <= floor
    }

    func sync(_ request: SharedCopyRequest, device: DeviceCalendarClient) async throws -> SharedCopySummary {
        var none = SharedCopySummary()
        none.didSync = false
        if isStale(request) { return none }
        if running {
            queued = (request, device)
            return none
        }
        running = true
        defer { running = false }
        var total = none
        var next: (SharedCopyRequest, DeviceCalendarClient)? = (request, device)
        while let (request, device) = next {
            queued = nil
            total.add(await pass(request, device: device))
            next = queued
        }
        return total
    }

    func removeOwner(device: DeviceCalendarClient, home: HomeID, owner: String) async -> Bool {
        while running { try? await Task.sleep(for: .milliseconds(100)) }
        running = true
        defer { running = false }
        let ok = await drop(scope: home.rawValue, owner: owner, device: device)
        removedAt[home.rawValue] = .now
        queued = nil
        return ok
    }

    func removeAll(device: DeviceCalendarClient, home: HomeID?) async -> Int {
        while running { try? await Task.sleep(for: .milliseconds(100)) }
        running = true
        defer { running = false }
        var removed = 0
        for (_, record) in current().calendars where home == nil || record.homeID == home?.rawValue {
            if await drop(scope: record.homeID, owner: record.ownerID, device: device) { removed += 1 }
        }
        removedAt[home?.rawValue ?? "*"] = .now
        queued = nil
        return removed
    }

    /// Deletes one housemate's calendar and forgets its copies. A calendar that
    /// could not be deleted stays remembered, so the next attempt finds it.
    private func drop(scope home: String, owner: String, device: DeviceCalendarClient) async -> Bool {
        let key = SharedCopyMap.calendarKey(home, owner)
        guard let record = current().calendars[key] else { return true }
        do {
            try await device.removeCalendar(record.calendarID)
        } catch {
            return false
        }
        let prefix = key + "/"
        mutate { map in
            map.calendars[key] = nil
            map.copies = map.copies.filter { !$0.key.hasPrefix(prefix) }
        }
        flush()
        return true
    }

    // MARK: A pass

    private var queuedWrites = 0
    private var snapshots: [String: SharedCopyMap.Copy?] = [:]

    private func pass(_ request: SharedCopyRequest, device: DeviceCalendarClient) async -> SharedCopySummary {
        var summary = SharedCopySummary()
        summary.didSync = false
        guard device.access() == .granted, !isStale(request) else { return summary }

        let home = request.homeID.rawValue
        let records = current().calendars.filter { $0.value.homeID == home }
        let exist = await device.calendarsExist(records.values.map(\.calendarID))
        // Nothing listed and none of our calendars found is a calendar
        // database that has not come back, far likelier than a person who
        // deleted everything; acting on it would call every calendar deleted.
        let listed = await device.calendars()
        if listed.isEmpty, exist.isEmpty, !records.isEmpty { return summary }
        summary.didSync = true

        // Calendars of housemates whose switch is off: the person asked.
        for (_, record) in records where request.owners[record.ownerID] == nil {
            if !(await drop(scope: home, owner: record.ownerID, device: device)) { summary.failed += 1 }
        }

        let plan = SharedCopyPlanner.plan(request)
        let keyed = SharedCopyPlanner.keys(request.items, home: home)
        let isComplete = !request.isTruncated
        // Per housemate: did their share say yes, no, or nothing at all.
        var consent: [String: Bool] = [:]
        for item in request.items { consent[item.userID.rawValue] = (consent[item.userID.rawValue] ?? false) || item.allowCopy }

        queuedWrites = 0
        snapshots = [:]
        var calendarIDs: [String: String] = [:]   // owner -> calendar id, for owners in play

        for (owner, who) in request.owners.sorted(by: { $0.key < $1.key }) {
            let key = SharedCopyMap.calendarKey(home, owner)
            let title = String(localized: L10n.calendarSharedCopyCalendarName(who.name))
            let stamp = title + "|" + who.colorHex

            if let record = current().calendars[key] {
                if !exist.contains(record.calendarID) {
                    // Deleted in the Calendar app: that is the person
                    // switching it off. Not recreated.
                    mutate { map in
                        map.calendars[key] = nil
                        map.copies = map.copies.filter { !$0.key.hasPrefix(key + "/") }
                    }
                    summary.dismissedOwners.insert(owner)
                    continue
                }
                calendarIDs[owner] = record.calendarID
                if record.stamp != stamp {
                    do {
                        try await device.updateCalendar(record.calendarID, title, who.colorHex)
                        mutate { $0.calendars[key]?.stamp = stamp }
                    } catch { summary.failed += 1 }
                }
            } else {
                // Nothing to copy until the housemate has said yes: no calendar
                // is made for a "no" or for nothing.
                guard consent[owner] == true else { continue }
                do {
                    let id: String
                    if let found = await device.findOwnCalendar(title) {
                        id = found
                    } else {
                        id = try await device.createCalendar(title, who.colorHex)
                    }
                    mutate { $0.calendars[key] = .init(homeID: home, ownerID: owner, calendarID: id, stamp: stamp) }
                    calendarIDs[owner] = id
                    flush()
                } catch {
                    summary.failed += 1
                }
            }
        }

        markedIndex = nil

        let managed = current().copies.filter { calendarIDs[$0.value.ownerID] != nil && $0.value.homeID == home }
        let present = await device.existing(managed.values.map(\.id).filter { !$0.isEmpty })
        let planned = Set(plan.map(\.key))

        // What a "no" takes back at once: a housemate who withdrew the copy
        // consent is the server's say-so, not a doubt.
        for (key, copy) in managed where consent[copy.ownerID] == false {
            await remove(copy, at: key, summary: &summary, device: device)
            if queuedWrites >= Self.batch { summary.failed += await finishBatch(device) }
        }

        for item in plan {
            guard let calendarID = calendarIDs[item.ownerID] else { continue }
            let existing = current().copies[item.key]
            if existing?.dismissed == true { continue }
            let fingerprint = item.draft.fingerprint
            do {
                var id = existing?.id
                if let remembered = id, !remembered.isEmpty, !present.contains(remembered) {
                    if let adopted = await found(calendarID, item.draft.marker, Set(calendarIDs.values), request.windowStart, device) {
                        id = adopted
                    } else {
                        // Deleted by hand. Their call; the item is not
                        // brought back until it has left the answer.
                        mutate { $0.copies[item.key]?.dismissed = true }
                        continue
                    }
                } else if id == nil, let adopted = await found(calendarID, item.draft.marker, Set(calendarIDs.values), request.windowStart, device) {
                    id = adopted
                }
                if let id, existing?.fingerprint == fingerprint, !id.isEmpty {
                    mutate { $0.copies[item.key]?.strikes = nil; $0.copies[item.key]?.strikeAt = nil }
                    continue
                }
                noteWrite(item.key)
                let saved = try await device.save(item.draft, calendarID, id)
                mutate { map in
                    map.copies[item.key] = .init(
                        homeID: home, ownerID: item.ownerID, id: saved, fingerprint: fingerprint, end: item.end
                    )
                }
                if id == nil { summary.created += 1 } else { summary.updated += 1 }
            } catch {
                summary.failed += 1
            }
            if queuedWrites >= Self.batch { summary.failed += await finishBatch(device) }
        }

        // Items the answer no longer holds, from a whole answer only.
        if isComplete {
            let inAnswer = Set(keyed.map(\.1))
            let seen = request.previousKeys
            for (key, copy) in current().copies where calendarIDs[copy.ownerID] != nil && copy.homeID == home && !planned.contains(key) {
                if consent[copy.ownerID] == false { continue }   // handled above
                if copy.end < request.windowStart {
                    // Over, not deleted: left in the calendar and forgotten once old.
                    if copy.end < request.now.addingTimeInterval(-14 * 86_400) { mutate { $0.copies[key] = nil } }
                    continue
                }
                // Still in the answer, only not for copying (no consent, or a
                // switch that just went off): handled above or by `drop`.
                if inAnswer.contains(key) { continue }
                if seen?.contains(key) != true {
                    // Absent and not seen going: a doubt until a second answer says it too.
                    var next = copy
                    let at = request.answeredAt.timeIntervalSince1970
                    if let last = next.strikeAt, at - last > Self.strikeLife { next.strikes = nil }
                    if (next.strikeAt ?? 0) < at {
                        next.strikes = (next.strikes ?? 0) + 1
                        next.strikeAt = at
                    }
                    if (next.strikes ?? 0) < Self.strikesToDelete {
                        mutate { $0.copies[key] = next }
                        continue
                    }
                }
                await remove(copy, at: key, summary: &summary, device: device)
                if queuedWrites >= Self.batch { summary.failed += await finishBatch(device) }
            }
            // A dismissed item that has left the answer may come back later.
            for (key, copy) in current().copies where copy.dismissed == true && copy.homeID == home && !Set(keyed.map(\.1)).contains(key) {
                mutate { $0.copies[key] = nil }
            }
        }
        summary.failed += await finishBatch(device)
        return summary
    }

    private func remove(
        _ copy: SharedCopyMap.Copy,
        at key: String,
        summary: inout SharedCopySummary,
        device: DeviceCalendarClient
    ) async {
        // A dismissed copy is already gone from the calendar.
        guard !copy.id.isEmpty else {
            mutate { $0.copies[key] = nil }
            return
        }
        do {
            noteWrite(key)
            try await device.remove(copy.id)
            mutate { $0.copies[key] = nil }
            summary.removed += 1
        } catch {
            summary.failed += 1
        }
    }

    /// `calendar \u{1F} marker` -> the event carrying it, for this pass.
    private var markedIndex: [String: String]?

    /// Where a marker says an event is, for copies the map has lost.
    private func found(
        _ calendarID: String,
        _ marker: URL?,
        _ calendars: Set<String>,
        _ start: Date,
        _ device: DeviceCalendarClient
    ) async -> String? {
        guard let marker else { return nil }
        if markedIndex == nil {
            let events = await device.marked(
                Array(calendars), start.addingTimeInterval(-86_400), start.addingTimeInterval(400 * 86_400)
            )
            markedIndex = Dictionary(
                events.map { ($0.calendarID + "\u{1F}" + $0.marker, $0.eventIdentifier) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        return markedIndex?[calendarID + "\u{1F}" + marker.absoluteString]
    }

    // MARK: Batches

    private func noteWrite(_ key: String) {
        queuedWrites += 1
        if snapshots[key] == nil { snapshots[key] = .some(current().copies[key]) }
    }

    private func finishBatch(_ device: DeviceCalendarClient) async -> Int {
        var failed = 0
        if queuedWrites > 0 {
            do {
                let resolved = try await device.commit()
                mutate { map in
                    for (key, var copy) in map.copies where copy.id.hasPrefix(DeviceCalendarStore.pendingPrefix) {
                        if let final = resolved[copy.id] {
                            copy.id = final
                            map.copies[key] = copy
                        } else {
                            // Written, but no identifier to remember it by:
                            // forgotten, and found again by its marker.
                            map.copies[key] = nil
                            failed += 1
                        }
                    }
                }
            } catch {
                failed = queuedWrites
                let before = snapshots
                mutate { map in for (key, copy) in before { map.copies[key] = copy } }
            }
        }
        queuedWrites = 0
        snapshots = [:]
        flush()
        return failed
    }
}
