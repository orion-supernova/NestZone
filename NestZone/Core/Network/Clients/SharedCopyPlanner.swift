import Foundation

/// What a housemate's shared items should look like in the phone's calendar,
/// decided without touching it.
///
/// A shared item has no id that outlives a sync (the server replaces the
/// rows), so it is known by its fingerprint: the calendar, the start and the
/// end. A moved item is a different key, which is a removed copy and a new one.
enum SharedCopyPlanner {
    struct Planned: Equatable {
        /// `"<home>/<owner>/<calendarKey>/<startMs>-<endMs>"`
        var key: String
        var ownerID: String
        var draft: DeviceEventDraft
        var end: Date
    }

    /// The key every item of one answer is known by. Two items with the same
    /// times in one calendar get a number after the first, in a stable order.
    static func keys(_ items: [SharedBusyItem], home: String) -> [(SharedBusyItem, String)] {
        let ordered = items.sorted {
            ($0.startsAt, $0.endsAt, $0.title ?? "", $0.id) < ($1.startsAt, $1.endsAt, $1.title ?? "", $1.id)
        }
        var seen: [String: Int] = [:]
        return ordered.map { item in
            let base = "\(home)/\(item.userID.rawValue)/\(item.calendarKey)/\(Int(item.start.timeIntervalSince1970 * 1000))-\(Int(item.end.timeIntervalSince1970 * 1000))"
            let n = seen[base, default: 0]
            seen[base] = n + 1
            return (item, n == 0 ? base : "\(base)~\(n + 1)")
        }
    }

    static func plan(_ request: SharedCopyRequest) -> [Planned] {
        let home = request.homeID.rawValue
        var out: [Planned] = []
        for (item, key) in keys(request.items, home: home) {
            let owner = item.userID.rawValue
            guard item.allowCopy, let who = request.owners[owner] else { continue }
            let shape = shape(of: item)
            let busy = String(localized: L10n.calendarSharedCopyBusy(who.name))
            let details = item.shownTitle
            out.append(Planned(
                key: key,
                ownerID: owner,
                draft: DeviceEventDraft(
                    title: details ?? busy,
                    location: item.level == .details && item.location?.isEmpty == false ? item.location : nil,
                    notes: String(localized: L10n.calendarSharedCopyNote(who.name)),
                    start: shape.start,
                    end: shape.end,
                    isAllDay: item.isAllDay,
                    marker: MirrorMarker.sharedURL(
                        home: home,
                        owner: owner,
                        calendarKey: item.calendarKey,
                        item: String(key.split(separator: "/").last ?? "")
                    )
                ),
                end: item.end
            ))
        }
        return out
    }

    /// An all-day item arrives as midnight to the midnight after its last day,
    /// at the sharer's midnight; a calendar app wants the first and last day.
    /// A day is the nearest midnight here, so a sharer a few hours away still
    /// lands on the right date.
    private static func shape(of item: SharedBusyItem) -> (start: Date, end: Date) {
        guard item.isAllDay else { return (item.start, max(item.end, item.start)) }
        let calendar = Calendar.current
        func day(_ date: Date) -> Date { calendar.startOfDay(for: date.addingTimeInterval(12 * 3600)) }
        let first = day(item.start)
        let after = day(item.end)
        let last = calendar.date(byAdding: .day, value: -1, to: after) ?? first
        return (first, max(first, last))
    }
}
