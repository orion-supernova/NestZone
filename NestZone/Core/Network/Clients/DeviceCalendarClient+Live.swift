import ComposableArchitecture
import EventKit
import Foundation
import UIKit

extension DeviceCalendarClient: DependencyKey {
    public static let liveValue = DeviceCalendarClient(
        access: { DeviceCalendarStore.access() },
        requestAccess: { try await DeviceCalendarStore.shared.requestAccess() },
        calendars: { await DeviceCalendarStore.shared.calendars() },
        shareableCalendars: { await DeviceCalendarStore.shared.shareableCalendars() },
        events: { ids, from, to in await DeviceCalendarStore.shared.events(in: ids, from: from, to: to) },
        defaultCalendarID: { await DeviceCalendarStore.shared.defaultCalendarID() },
        marked: { ids, from, to in await DeviceCalendarStore.shared.marked(in: ids, from: from, to: to) },
        save: { draft, calendarID, existingID in
            try await DeviceCalendarStore.shared.save(draft, calendarID: calendarID, existingID: existingID)
        },
        remove: { id in try await DeviceCalendarStore.shared.remove(id) },
        commit: { try await DeviceCalendarStore.shared.commit() },
        existing: { ids in await DeviceCalendarStore.shared.existing(ids) },
        changes: {
            AsyncStream { continuation in
                let observer = ObserverBox(
                    NotificationCenter.default.addObserver(
                        forName: .EKEventStoreChanged, object: nil, queue: nil
                    ) { _ in continuation.yield() }
                )
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(observer.token)
                }
            }
        }
    )
}

/// `addObserver` hands back a token that is not `Sendable`; it is only ever
/// handed to `removeObserver`, which is safe from any thread.
private struct ObserverBox: @unchecked Sendable {
    let token: NSObjectProtocol
    init(_ token: NSObjectProtocol) { self.token = token }
}

/// The one `EKEventStore`, behind an actor.
///
/// EventKit reads and writes hit the calendar database, which for an Exchange
/// or Google account can mean waiting on a sync, so none of it runs on the main
/// actor, and the store and the objects it hands out never leave this actor.
actor DeviceCalendarStore {
    static let shared = DeviceCalendarStore()

    private let store = EKEventStore()

    nonisolated static func access() -> DeviceCalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: .notDetermined
        case .fullAccess: .granted
        case .writeOnly: .writeOnly
        case .denied: .denied
        case .restricted: .restricted
        // `.authorized` is the pre-iOS 17 spelling of full access.
        @unknown default: .denied
        }
    }

    func requestAccess() async throws -> DeviceCalendarAccess {
        guard Self.access() == .notDetermined else { return Self.access() }
        _ = try await store.requestFullAccessToEvents()
        // The store was made before the answer; calendars read through it
        // afterwards come back empty until it is told to look again.
        store.reset()
        return Self.access()
    }

    func calendars() -> [DeviceCalendar] {
        guard Self.access() == .granted else { return [] }
        return store.calendars(for: .event)
            .filter { $0.allowsContentModifications && $0.type != .subscription && $0.type != .birthday }
            .sorted { (lhs: EKCalendar, rhs: EKCalendar) -> Bool in
                if lhs.source.title != rhs.source.title { return lhs.source.title < rhs.source.title }
                return lhs.title < rhs.title
            }
            .map { calendar in
                DeviceCalendar(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    colorHex: Self.hex(calendar.cgColor),
                    accountTitle: calendar.source.title,
                    account: Self.account(calendar.source)
                )
            }
    }

    func shareableCalendars() -> [DeviceCalendar] {
        guard Self.access() == .granted else { return [] }
        return store.calendars(for: .event)
            .filter { $0.type != .birthday }
            .sorted { (lhs: EKCalendar, rhs: EKCalendar) -> Bool in
                if lhs.source.title != rhs.source.title { return lhs.source.title < rhs.source.title }
                return lhs.title < rhs.title
            }
            .map { calendar in
                DeviceCalendar(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    colorHex: Self.hex(calendar.cgColor),
                    accountTitle: calendar.source.title,
                    account: Self.account(calendar.source)
                )
            }
    }

    func events(in calendarIDs: [String], from: Date, to: Date) -> [DeviceEvent] {
        guard Self.access() == .granted, !calendarIDs.isEmpty, from < to else { return [] }
        let wanted = Set(calendarIDs)
        let calendars = store.calendars(for: .event).filter { wanted.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        return store.events(matching: predicate).compactMap { event in
            guard event.status != .canceled,
                  let identifier = event.eventIdentifier,
                  let calendarID = event.calendar?.calendarIdentifier else { return nil }
            return DeviceEvent(
                eventIdentifier: identifier,
                calendarID: calendarID,
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                title: event.title ?? "",
                location: event.location,
                isNestZoneCopy: MirrorMarker.isMarker(event.url)
            )
        }
    }

    func marked(in calendarIDs: [String], from: Date, to: Date) -> [DeviceMarkedEvent] {
        guard Self.access() == .granted, !calendarIDs.isEmpty, from < to else { return [] }
        let wanted = Set(calendarIDs)
        let calendars = store.calendars(for: .event).filter { wanted.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        var seen = Set<String>()
        var out: [DeviceMarkedEvent] = []
        for event in store.events(matching: predicate) {
            guard MirrorMarker.isMarker(event.url), let marker = event.url?.absoluteString,
                  let identifier = event.eventIdentifier,
                  let calendarID = event.calendar?.calendarIdentifier else { continue }
            // A series is one event with many occurrences.
            guard seen.insert(calendarID + "|" + marker).inserted else { continue }
            out.append(DeviceMarkedEvent(marker: marker, eventIdentifier: identifier, calendarID: calendarID))
        }
        return out
    }

    func defaultCalendarID() -> String? {
        guard Self.access() == .granted else { return nil }
        return store.defaultCalendarForNewEvents?.calendarIdentifier
    }

    func save(_ draft: DeviceEventDraft, calendarID: String, existingID: String?) throws -> String {
        guard Self.access() == .granted else { throw DeviceCalendarError.noAccess }
        guard let calendar = store.calendar(withIdentifier: calendarID) else {
            throw DeviceCalendarError.calendarMissing
        }
        let event: EKEvent
        let isNew: Bool
        if let existingID, let found = store.event(withIdentifier: existingID) {
            event = found
            isNew = false
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = calendar
            isNew = true
        }

        event.title = draft.title
        event.location = draft.location
        event.notes = Self.notes(draft.notes)
        event.isAllDay = draft.isAllDay
        event.startDate = draft.start
        event.endDate = draft.end
        event.url = draft.marker
        // A day with no time of day is the same day wherever the phone is.
        if draft.isAllDay {
            event.timeZone = nil
        } else if let minutes = draft.timeZoneOffset {
            // A repeating copy repeats at the series' own offset (see
            // `DeviceEventDraft.timeZoneOffset`), not at the phone's wall time.
            event.timeZone = TimeZone(secondsFromGMT: minutes * 60)
        }

        for rule in event.recurrenceRules ?? [] { event.removeRecurrenceRule(rule) }
        if let recurrence = draft.recurrence { event.addRecurrenceRule(Self.rule(for: recurrence)) }

        for alarm in event.alarms ?? [] { event.removeAlarm(alarm) }
        for minutes in draft.alarmMinutes {
            event.addAlarm(EKAlarm(relativeOffset: -TimeInterval(minutes) * 60))
        }

        // `.futureEvents` on a series' first event is the whole series. A new
        // event is committed now because its identifier is only final once it
        // is; a change waits for `commit`.
        try store.save(event, span: .futureEvents, commit: isNew)
        return event.eventIdentifier
    }

    func remove(_ eventID: String) throws {
        guard Self.access() == .granted, let event = store.event(withIdentifier: eventID) else { return }
        try store.remove(event, span: .futureEvents, commit: false)
    }

    func commit() throws {
        do {
            try store.commit()
        } catch {
            // What was queued did not land; leaving it queued would let the
            // next write commit half of an answer the caller was told failed.
            store.reset()
            throw error
        }
    }

    func existing(_ eventIDs: [String]) -> Set<String> {
        guard Self.access() == .granted else { return [] }
        return Set(eventIDs.filter { store.event(withIdentifier: $0) != nil })
    }

    // MARK: Mapping

    /// The copy's notes: the house event's own, then the line that says where
    /// the truth lives, so nobody edits the copy and wonders why it snaps back.
    private static func notes(_ notes: String?) -> String {
        let line = String(localized: L10n.calendarCopyNotesLine)
        guard let notes, !notes.isEmpty else { return line }
        return notes + "\n\n" + line
    }

    /// 0 = Sunday on the wire, `EKWeekday.sunday` = 1 in EventKit.
    private static func rule(for recurrence: Recurrence) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency = switch recurrence.frequency {
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
        let days: [EKRecurrenceDayOfWeek]? = recurrence.frequency == .weekly && !recurrence.weekdays.isEmpty
            ? recurrence.weekdays.compactMap { EKWeekday(rawValue: $0 + 1).map { EKRecurrenceDayOfWeek($0) } }
            : nil
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: recurrence.interval,
            daysOfTheWeek: days,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: recurrence.until.map { EKRecurrenceEnd(end: $0.date) }
        )
    }

    private static func account(_ source: EKSource) -> DeviceCalendar.Account {
        switch source.sourceType {
        case .local: .local
        case .mobileMe: .iCloud
        case .exchange: .exchange
        case .calDAV: source.title == "iCloud" ? .iCloud : .calDAV
        default: .other
        }
    }

    private static func hex(_ color: CGColor?) -> String {
        guard let color else { return "#8E8E93" }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(cgColor: color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded())
        )
    }
}
