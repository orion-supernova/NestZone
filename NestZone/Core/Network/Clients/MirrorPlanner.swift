import Foundation

/// Decides what the person's calendars should hold, without touching them.
///
/// Pure, so it can be read (and tested) on its own: house events in, the list
/// of copies out.
enum MirrorPlanner {
    /// One thing to have in the person's calendars.
    struct Copy: Equatable {
        /// The map key: the event id for a series, `"<eventID>@<startMillis>"`
        /// for one occurrence.
        var key: String
        var eventID: String
        var draft: DeviceEventDraft
        var calendars: Set<String>
        var lastEnd: Date?
    }

    /// - Parameters:
    ///   - overrides: event id -> the calendars the composer pinned it to.
    ///   - calendarIDs: the calendars that exist and can be written to; anything
    ///     else in a target list is a calendar that has since gone.
    static func plan(
        _ request: MirrorRequest,
        overrides: [String: [String]],
        calendarIDs: Set<String>
    ) -> [Copy] {
        var order: [EventID] = []
        var groups: [EventID: [EventOccurrence]] = [:]
        for occurrence in request.occurrences {
            if let home = occurrence.homeID, home != request.homeID { continue }
            if groups[occurrence.eventID] == nil { order.append(occurrence.eventID) }
            groups[occurrence.eventID, default: []].append(occurrence)
        }

        var copies: [Copy] = []
        for eventID in order {
            guard let occurrences = groups[eventID]?.sorted(by: { $0.startsAt < $1.startsAt }),
                  let first = occurrences.first else { continue }

            let chosen: [String]? = overrides[eventID.rawValue]
            let calendars: Set<String>
            if let chosen {
                calendars = Set(chosen).intersection(calendarIDs)
            } else if request.mode.wants(first, user: request.userID) {
                calendars = Set(request.targets).intersection(calendarIDs)
            } else {
                calendars = []
            }
            guard !calendars.isEmpty else { continue }

            let alarms = request.copyReminders ? first.reminders : []

            if let rule = first.recurrence, canMirrorAsSeries(occurrences, rule: rule, request: request) {
                // The copy begins where the series began and lasts as long as
                // one occurrence does.
                let duration = first.duration
                let start = first.seriesStart.date
                let shape = shape(start: start, duration: duration, of: first)
                copies.append(Copy(
                    key: eventID.rawValue,
                    eventID: eventID.rawValue,
                    draft: draft(first, shape: shape, recurrence: rule, alarms: alarms),
                    calendars: calendars,
                    lastEnd: rule.until.map { $0.date.addingTimeInterval(duration) }
                ))
            } else {
                for occurrence in occurrences {
                    let shape = shape(start: occurrence.start, duration: occurrence.duration, of: occurrence)
                    copies.append(Copy(
                        key: "\(eventID.rawValue)@\(Int(occurrence.startsAt.milliseconds))",
                        eventID: eventID.rawValue,
                        draft: draft(occurrence, shape: shape, recurrence: nil, alarms: alarms),
                        calendars: calendars,
                        lastEnd: occurrence.end
                    ))
                }
            }
        }
        return copies
    }

    // MARK: Drafts

    private static func draft(
        _ occurrence: EventOccurrence,
        shape: (start: Date, end: Date),
        recurrence: Recurrence?,
        alarms: [Int]
    ) -> DeviceEventDraft {
        DeviceEventDraft(
            title: occurrence.title,
            location: occurrence.location?.isEmpty == false ? occurrence.location : nil,
            notes: occurrence.notes?.isEmpty == false ? occurrence.notes : nil,
            start: shape.start,
            end: shape.end,
            isAllDay: occurrence.isAllDay,
            recurrence: recurrence,
            alarmMinutes: alarms
        )
    }

    /// The start and end to write. An all-day event is stored as midnight to
    /// the midnight *after* its last day, in the zone it was written in; a
    /// calendar app wants the first and last day, in the zone it is looked at
    /// in, or a day lands on the wrong date for somebody a few hours away.
    private static func shape(
        start: Date,
        duration: TimeInterval,
        of occurrence: EventOccurrence
    ) -> (start: Date, end: Date) {
        guard occurrence.isAllDay else { return (start, start.addingTimeInterval(duration)) }

        var written = Calendar(identifier: .gregorian)
        written.timeZone = TimeZone(secondsFromGMT: occurrence.tzOffset * 60) ?? .current
        let local = Calendar.current

        func day(_ instant: Date) -> Date {
            let parts = written.dateComponents([.year, .month, .day], from: instant)
            return local.date(from: parts).map(local.startOfDay(for:)) ?? instant
        }
        let first = day(start)
        let last = day(start.addingTimeInterval(max(0, duration - 1)))
        return (first, max(first, last))
    }

    // MARK: Series or occurrences

    /// Whether the series can be one repeating event.
    ///
    /// EventKit has no way to say "not this Tuesday" on a rule it was given,
    /// so a series the house has skipped a date of, or lifted one date out of,
    /// would come back from the calendar with that date on it. Such a series is
    /// copied one occurrence at a time instead. The test is whether what the
    /// server expanded is exactly what the rule alone would give, worked out
    /// here the way the server works it out; any doubt falls to the safe side.
    static func canMirrorAsSeries(
        _ occurrences: [EventOccurrence],
        rule: Recurrence,
        request: MirrorRequest
    ) -> Bool {
        guard let first = occurrences.first else { return false }
        let tz = first.tzOffset
        let start = first.seriesStart.milliseconds

        // Where a rule that names weekdays starts on a day it does not name,
        // iCalendar and the server part ways about what the first date is.
        if rule.frequency == .weekly, !rule.weekdays.isEmpty,
           !rule.weekdays.contains(weekday(of: start, tz: tz)) { return false }
        // A 29th to 31st is skipped in the months without one, and calendar
        // apps differ about whether it is moved instead.
        if rule.frequency == .monthly || rule.frequency == .yearly,
           dayOfMonth(of: start, tz: tz) > 28 { return false }

        let expected = expand(
            first: start,
            duration: first.duration * 1000,
            rule: rule,
            tz: tz,
            from: request.windowStart.timeIntervalSince1970 * 1000,
            to: request.windowEnd.timeIntervalSince1970 * 1000
        )
        return expected == Set(occurrences.map(\.startsAt.milliseconds))
    }

    private static let day = 86_400_000.0
    private static let minute = 60_000.0
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static func weekday(of at: Double, tz: Int) -> Int {
        let days = Int(((at + Double(tz) * minute) / day).rounded(.down))
        // 1970-01-01 was a Thursday; 0 = Sunday.
        return ((days + 4) % 7 + 7) % 7
    }

    private static func dayOfMonth(of at: Double, tz: Int) -> Int {
        utc.component(.day, from: Date(timeIntervalSince1970: (at + Double(tz) * minute) / 1000))
    }

    /// The server's expansion (`expand` in `convex/events.ts`), for one rule
    /// and no skipped dates: every start that overlaps `[from, to]`.
    static func expand(
        first: Double,
        duration: Double,
        rule: Recurrence,
        tz: Int,
        from: Double,
        to: Double
    ) -> Set<Double> {
        let earliest = from - duration
        let interval = Double(max(1, rule.interval))
        let last = min(to, rule.until?.milliseconds ?? .infinity)
        guard last >= first else { return [] }

        var out = Set<Double>()
        func take(_ start: Double) {
            if start >= earliest, start <= last { out.insert(start) }
        }

        switch rule.frequency {
        case .daily, .weekly:
            let weekdays = rule.frequency == .weekly
                ? Array(Set(rule.weekdays.filter { (0...6).contains($0) })).sorted()
                : []
            if weekdays.isEmpty {
                let step = (rule.frequency == .daily ? 1.0 : 7.0) * interval * day
                var i = max(0, ((earliest - first) / step).rounded(.up))
                var guardCount = 0
                while guardCount < 3000 {
                    let start = first + i * step
                    if start > last { break }
                    take(start)
                    i += 1
                    guardCount += 1
                }
            } else {
                let stride = interval * 7 * day
                let anchor = first - Double(weekday(of: first, tz: tz)) * day
                var w = max(0, ((earliest - anchor - 6 * day) / stride).rounded(.down))
                var guardCount = 0
                while guardCount < 3000 {
                    let weekStart = anchor + w * stride
                    if weekStart > last { break }
                    for d in weekdays {
                        let start = weekStart + Double(d) * day
                        if start < first { continue }
                        take(start)
                    }
                    w += 1
                    guardCount += 1
                }
            }

        case .monthly, .yearly:
            let step = rule.frequency == .monthly ? Int(interval) : Int(interval) * 12
            let shifted = Date(timeIntervalSince1970: (first + Double(tz) * minute) / 1000)
            let base = utc.dateComponents([.year, .month, .day], from: shifted)
            let timeOfDay = (first + Double(tz) * minute).truncatingRemainder(dividingBy: day)
            let msOfDay = timeOfDay < 0 ? timeOfDay + day : timeOfDay
            let target = utc.dateComponents(
                [.year, .month],
                from: Date(timeIntervalSince1970: (max(earliest, first) + Double(tz) * minute) / 1000)
            )
            let monthsAhead = ((target.year ?? 0) - (base.year ?? 0)) * 12
                + ((target.month ?? 1) - (base.month ?? 1))
            var i = max(0, monthsAhead / max(step, 1))
            var guardCount = 0
            while guardCount < 600 {
                let month = (base.month ?? 1) - 1 + i * step
                let year = (base.year ?? 1970) + Int((Double(month) / 12).rounded(.down))
                let m = ((month % 12) + 12) % 12
                guard let monthStart = utc.date(from: DateComponents(year: year, month: m + 1, day: 1)) else { break }
                if monthStart.timeIntervalSince1970 * 1000 - Double(tz) * minute > last { break }
                if let date = utc.date(from: DateComponents(year: year, month: m + 1, day: base.day)),
                   utc.component(.day, from: date) == base.day {
                    take(date.timeIntervalSince1970 * 1000 + msOfDay - Double(tz) * minute)
                }
                i += 1
                guardCount += 1
            }
        }
        return out
    }
}
