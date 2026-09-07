import Foundation
import SwiftUI

// The household calendar's domain types.
//
// The client never holds an *event*. It holds occurrences: the server expands
// every series for the window on screen and sends concrete, dated things, so a
// weekly standup that has run for two years is one row on the server and
// exactly four items in a phone's memory while April is open.
//
// That is why `EventOccurrence` carries its whole series with it — kind,
// attendees, recurrence, reminders. Opening a detail sheet is then free, and a
// list of occurrences is self-contained enough that no screen ever needs a
// second subscription to describe what it is already showing.

// MARK: - Kind

/// What sort of thing this is.
///
/// Mostly a label — the symbol and the colour — but it also decides what the
/// composer opens with. A dinner party wants a menu; a concert wants a ticket
/// link and a budget; a dentist appointment wants neither. Guessing that from
/// the kind is the difference between a form with nine collapsed sections and
/// one that already looks like the thing being planned.
///
/// Nineteen is a lot for a picker, which is why they are grouped rather than
/// listed. Three kinds and a free-text label would be tidier and would throw
/// away the only signal the app has about what an event needs prepared for it.
public enum EventKind: String, Codable, CaseIterable, Sendable, Identifiable {
    // At home
    case general, houseParty, dinnerParty, movieNight, gameNight, visit, chore
    // Going out
    case dining, concert, cinema, theatre, sports, picnic, trip
    // Occasions
    case birthday, anniversary, holiday
    // Admin
    case appointment, deadline

    public var id: String { rawValue }

    /// The four shelves of the picker.
    public enum Group: String, CaseIterable, Sendable, Identifiable {
        case atHome, goingOut, occasions, admin

        public var id: String { rawValue }

        public var title: LocalizedStringResource {
            switch self {
            case .atHome: L10n.calendarGroupAtHome
            case .goingOut: L10n.calendarGroupGoingOut
            case .occasions: L10n.calendarGroupOccasions
            case .admin: L10n.calendarGroupAdmin
            }
        }

        public var symbol: String {
            switch self {
            case .atHome: "house.fill"
            case .goingOut: "figure.walk"
            case .occasions: "gift.fill"
            case .admin: "checklist"
            }
        }

        public var kinds: [EventKind] {
            EventKind.allCases.filter { $0.group == self }
        }
    }

    public var group: Group {
        switch self {
        case .general, .houseParty, .dinnerParty, .movieNight, .gameNight, .visit, .chore:
            .atHome
        case .dining, .concert, .cinema, .theatre, .sports, .picnic, .trip:
            .goingOut
        case .birthday, .anniversary, .holiday:
            .occasions
        case .appointment, .deadline:
            .admin
        }
    }

    public var title: LocalizedStringResource {
        switch self {
        case .general: L10n.calendarKindGeneral
        case .houseParty: L10n.calendarKindHouseParty
        case .dinnerParty: L10n.calendarKindDinnerParty
        case .movieNight: L10n.calendarKindMovieNight
        case .gameNight: L10n.calendarKindGameNight
        case .visit: L10n.calendarKindVisit
        case .chore: L10n.calendarKindChore
        case .dining: L10n.calendarKindDining
        case .concert: L10n.calendarKindConcert
        case .cinema: L10n.calendarKindCinema
        case .theatre: L10n.calendarKindTheatre
        case .sports: L10n.calendarKindSports
        case .picnic: L10n.calendarKindPicnic
        case .trip: L10n.calendarKindTrip
        case .birthday: L10n.calendarKindBirthday
        case .anniversary: L10n.calendarKindAnniversary
        case .holiday: L10n.calendarKindHoliday
        case .appointment: L10n.calendarKindAppointment
        case .deadline: L10n.calendarKindDeadline
        }
    }

    public var symbol: String {
        switch self {
        case .general: "calendar"
        case .houseParty: "party.popper.fill"
        case .dinnerParty: "fork.knife"
        case .movieNight: "popcorn.fill"
        case .gameNight: "dice.fill"
        case .visit: "person.badge.plus"
        case .chore: "wrench.and.screwdriver.fill"
        case .dining: "wineglass.fill"
        case .concert: "music.mic"
        case .cinema: "ticket.fill"
        case .theatre: "theatermasks.fill"
        case .sports: "sportscourt.fill"
        case .picnic: "basket.fill"
        case .trip: "airplane"
        case .birthday: "birthday.cake.fill"
        case .anniversary: "heart.fill"
        case .holiday: "sparkles"
        case .appointment: "stethoscope"
        case .deadline: "flag.checkered"
        }
    }

    public var tint: Color {
        switch self {
        case .general: Palette.eventGeneral
        case .houseParty: Palette.eventParty
        case .dinnerParty: Palette.eventFood
        case .movieNight: Palette.eventScreen
        case .gameNight: Palette.eventPlay
        case .visit: Palette.eventPeople
        case .chore: Palette.eventChore
        case .dining: Palette.eventFood
        case .concert: Palette.eventStage
        case .cinema: Palette.eventScreen
        case .theatre: Palette.eventStage
        case .sports: Palette.eventOutdoor
        case .picnic: Palette.eventOutdoor
        case .trip: Palette.eventTravel
        case .birthday: Palette.eventCelebrate
        case .anniversary: Palette.eventCelebrate
        case .holiday: Palette.eventHoliday
        case .appointment: Palette.eventAdmin
        case .deadline: Palette.eventDeadline
        }
    }

    /// Which parts of the plan this kind opens with.
    ///
    /// Only a *suggestion*: every section is always reachable from the plan
    /// menu, because a household will always want something the taxonomy did
    /// not predict. What this stops is a dentist appointment presenting a menu
    /// picker and a budget field nobody will ever fill in.
    public var suggestedPlan: Set<PlanSection> {
        switch self {
        case .houseParty, .dinnerParty, .picnic: [.menu, .shopping, .budget]
        case .movieNight, .gameNight: [.shopping, .budget]
        case .birthday, .anniversary, .holiday: [.shopping, .budget]
        case .visit: [.menu, .shopping]
        case .concert, .cinema, .theatre, .sports: [.tickets, .budget]
        case .dining, .trip: [.budget, .tickets]
        case .general, .chore, .appointment, .deadline: []
        }
    }

    /// An all-day event by default? A birthday is a day, a concert is a time.
    public var isTypicallyAllDay: Bool {
        switch self {
        case .birthday, .anniversary, .holiday, .trip, .deadline: true
        default: false
        }
    }

    /// How long one of these usually runs, when nobody has said.
    public var defaultDuration: TimeInterval {
        switch self {
        case .houseParty, .dinnerParty: 4 * 3600
        case .movieNight, .cinema, .theatre, .concert, .sports: 3 * 3600
        case .gameNight, .dining, .picnic, .visit: 2 * 3600
        case .appointment: 3600
        case .chore, .deadline: 1800
        default: 3600
        }
    }

    /// A repeat rule that suits the kind, offered as the composer's first
    /// non-`nil` choice. A birthday that does not repeat yearly is nearly
    /// always a mistake nobody notices until next year.
    public var suggestedRecurrence: Recurrence? {
        switch self {
        case .birthday, .anniversary: Recurrence(frequency: .yearly)
        default: nil
        }
    }
}

/// The optional halves of an event: what it costs, what has to be bought, what
/// is being cooked, and where the tickets are.
public enum PlanSection: String, CaseIterable, Sendable, Identifiable {
    case budget, shopping, menu, tickets

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .budget: L10n.calendarPlanBudget
        case .shopping: L10n.calendarPlanShopping
        case .menu: L10n.calendarPlanMenu
        case .tickets: L10n.calendarPlanTickets
        }
    }

    public var symbol: String {
        switch self {
        case .budget: "creditcard.fill"
        case .shopping: "cart.fill"
        case .menu: "fork.knife"
        case .tickets: "ticket.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .budget: Palette.indigo
        case .shopping: Palette.success
        case .menu: Palette.warning
        case .tickets: Palette.violet
        }
    }
}

// MARK: - RSVP

/// Whether somebody is coming.
///
/// Answered per *series*: saying yes to "every Tuesday" once is what people
/// mean, and an answer that had to be repeated weekly would simply be ignored.
public enum RSVPStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case going, maybe, declined

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .going: L10n.calendarRsvpGoing
        case .maybe: L10n.calendarRsvpMaybe
        case .declined: L10n.calendarRsvpDeclined
        }
    }

    public var symbol: String {
        switch self {
        case .going: "checkmark.circle.fill"
        case .maybe: "questionmark.circle.fill"
        case .declined: "xmark.circle.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .going: Palette.success
        case .maybe: Palette.warning
        case .declined: Palette.danger
        }
    }
}

public struct EventRSVP: Codable, Hashable, Sendable, Identifiable {
    public var userID: UserID
    public var status: RSVPStatus

    public var id: UserID { userID }

    public init(userID: UserID, status: RSVPStatus) {
        self.userID = userID
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case status
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(UserID.self, forKey: .userID)
        status = c.decodeLenient(RSVPStatus.self, forKey: .status, default: .going)
    }
}

// MARK: - Recurrence

/// How an event repeats.
///
/// Smaller than RRULE, and without a repeat *count* — see the note on
/// `recurrence` in `convex/schema.ts`. "Until a date" and "forever" are what a
/// household means, and they are the two the server can expand by arithmetic
/// rather than by walking every occurrence since the series began.
public struct Recurrence: Codable, Hashable, Sendable {
    public enum Frequency: String, Codable, CaseIterable, Sendable, Identifiable {
        case daily, weekly, monthly, yearly

        public var id: String { rawValue }

        public var symbol: String {
            switch self {
            case .daily: "sun.max"
            case .weekly: "calendar.day.timeline.left"
            case .monthly: "calendar"
            case .yearly: "gift"
            }
        }
    }

    public var frequency: Frequency
    /// Every `interval` days/weeks/months/years. At least 1.
    public var interval: Int
    /// 0=Sunday … 6=Saturday. Weekly only; empty means "the day it started on".
    public var weekdays: [Int]
    /// Last day the series may produce an occurrence. `nil` is forever.
    public var until: Timestamp?

    public init(
        frequency: Frequency,
        interval: Int = 1,
        weekdays: [Int] = [],
        until: Timestamp? = nil
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.until = until
    }

    enum CodingKeys: String, CodingKey {
        case freq, interval, weekdays, until
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frequency = c.decodeLenient(Frequency.self, forKey: .freq, default: .weekly)
        interval = max(1, c.decodeNumber(forKey: .interval, default: 1))
        weekdays = (try? c.decodeIfPresent([Int].self, forKey: .weekdays)) ?? []
        until = try c.decodeIfPresent(Timestamp.self, forKey: .until)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(frequency, forKey: .freq)
        try c.encode(interval, forKey: .interval)
        if !weekdays.isEmpty { try c.encode(weekdays, forKey: .weekdays) }
        try c.encodeIfPresent(until, forKey: .until)
    }

    /// A sentence a person can check at a glance — "Every 2 weeks on Tue, Thu".
    ///
    /// Weekday names come from `Calendar`, not from the catalogue: the system
    /// already has them in every language, correctly abbreviated and correctly
    /// ordered for the reader's locale.
    public var summary: String {
        let base: String = switch frequency {
        case .daily:
            interval == 1
                ? String(localized: L10n.calendarRepeatDaily)
                : String(localized: L10n.calendarRepeatEveryNDays(interval))
        case .weekly:
            interval == 1
                ? String(localized: L10n.calendarRepeatWeekly)
                : String(localized: L10n.calendarRepeatEveryNWeeks(interval))
        case .monthly:
            interval == 1
                ? String(localized: L10n.calendarRepeatMonthly)
                : String(localized: L10n.calendarRepeatEveryNMonths(interval))
        case .yearly:
            interval == 1
                ? String(localized: L10n.calendarRepeatYearly)
                : String(localized: L10n.calendarRepeatEveryNYears(interval))
        }

        guard frequency == .weekly, !weekdays.isEmpty else { return base }
        let symbols = Recurrence.shortWeekdaySymbols
        let names = weekdays.sorted()
            .compactMap { $0 >= 0 && $0 < symbols.count ? symbols[$0] : nil }
            .joined(separator: ", ")
        return names.isEmpty ? base : "\(base) · \(names)"
    }

    /// Sunday-first short names, as the wire format indexes them.
    ///
    /// `Calendar.shortWeekdaySymbols` is always Sunday-first regardless of the
    /// locale's first weekday, which is exactly the indexing the server uses —
    /// so this is a straight lookup rather than a rotation.
    public static var shortWeekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = L10n.locale
        return calendar.shortWeekdaySymbols
    }

    /// Weekday indexes in the reader's own week order, for a day picker.
    public static var weekdayOrder: [Int] {
        var calendar = Calendar.current
        calendar.locale = L10n.locale
        // `firstWeekday` is 1-based with 1 = Sunday; the wire format is 0-based.
        let first = calendar.firstWeekday - 1
        return (0..<7).map { ($0 + first) % 7 }
    }
}

// MARK: - Reminders

/// How long before an occurrence to nudge the household.
///
/// Stops at ten minutes because the sweep that sends these runs on a quarter
/// hour (see `convex/crons.ts`). Offering "5 minutes before" would promise a
/// precision the schedule cannot keep.
public enum EventReminder: Int, Codable, CaseIterable, Sendable, Identifiable {
    case atTime = 0
    case tenMinutes = 10
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case oneDay = 1440
    case twoDays = 2880
    case oneWeek = 10080

    public var id: Int { rawValue }

    public var minutes: Int { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .atTime: L10n.calendarReminderAtTime
        case .tenMinutes: L10n.calendarReminderTenMinutes
        case .thirtyMinutes: L10n.calendarReminderThirtyMinutes
        case .oneHour: L10n.calendarReminderOneHour
        case .twoHours: L10n.calendarReminderTwoHours
        case .oneDay: L10n.calendarReminderOneDay
        case .twoDays: L10n.calendarReminderTwoDays
        case .oneWeek: L10n.calendarReminderOneWeek
        }
    }

    /// The nearest offer to a number of minutes the server sent back. A value
    /// this build does not know degrades to the closest one it does rather than
    /// vanishing from the sheet that is about to re-save it.
    public static func nearest(to minutes: Int) -> EventReminder {
        allCases.min { abs($0.minutes - minutes) < abs($1.minutes - minutes) } ?? .atTime
    }

    /// At most three, largest first — the same ceiling a bill's reminders have.
    /// A calendar that pings four times is a calendar people mute.
    public static let maximum = 3
}

// MARK: - A day

/// One day in the reader's calendar, as a value cheap enough to use as a
/// dictionary key.
///
/// Not a `Date`: bucketing a month of events by `calendar.startOfDay(for:)`
/// means a `Calendar` round trip per event per rebuild, and hashing a `Date` is
/// hashing a `Double`. Three small integers hash in a word and compare without
/// touching the calendar at all.
public struct CalendarDay: Hashable, Sendable, Comparable, Identifiable, Codable {
    public var year: Int
    public var month: Int
    public var day: Int

    public var id: Int { year * 10_000 + month * 100 + day }

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year ?? 1970
        self.month = parts.month ?? 1
        self.day = parts.day ?? 1
    }

    public static var today: Self { Self(Date()) }

    /// Local midnight.
    public func date(_ calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    public func advanced(by days: Int, calendar: Calendar = .current) -> Self {
        guard let moved = calendar.date(byAdding: .day, value: days, to: date(calendar)) else {
            return self
        }
        return Self(moved, calendar: calendar)
    }

    public var month_: CalendarMonth { CalendarMonth(year: year, month: month) }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.id < rhs.id }
}

// MARK: - Occurrence

/// One dated instance of an event, with its whole series along for the ride.
public struct EventOccurrence: Codable, Identifiable, Hashable, Sendable {
    /// `"<eventId>:<startMillis>"`. Assigned by the server and stable across
    /// pushes, so a list can key on it without inventing an identity — and two
    /// occurrences of the same series never collide.
    public let id: String
    public let eventID: EventID
    public var homeID: HomeID?
    public var title: String
    public var notes: String?
    public var location: String?
    public var kind: EventKind
    public var startsAt: Timestamp
    public var endsAt: Timestamp
    public var isAllDay: Bool
    /// Minutes east of UTC where the series was written.
    public var tzOffset: Int
    /// The ticket, the booking, the listing somebody sent in the chat.
    public var url: String?
    /// What the household means to spend on it, in minor units. What it has
    /// actually spent lives in `EventPlan`, because only the server can total
    /// a ledger.
    public var budget: Int?
    /// ISO 4217 for `budget`.
    public var currency: String?
    /// The menu. Titles and times are read through by `events:detail`; this is
    /// only the identity, for the composer to reopen with.
    public var recipeIDs: [RecipeID]
    public var recurrence: Recurrence?
    /// Where the series itself began — "since March", on the detail sheet.
    public var seriesStart: Timestamp
    public var isRecurring: Bool
    public var attendees: [UserID]
    public var rsvps: [EventRSVP]
    public var reminders: [Int]
    public var createdBy: UserID?
    public var created: Timestamp?
    public var updated: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case homeID = "home_id"
        case title, notes, location, kind
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isAllDay = "is_all_day"
        case tzOffset = "tz_offset"
        case url, budget, currency
        case recipeIDs = "recipe_ids"
        case recurrence
        case seriesStart = "series_start"
        case isRecurring = "is_recurring"
        case attendees, rsvps, reminders
        case createdBy = "created_by"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventID = try c.decode(EventID.self, forKey: .eventID)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        kind = c.decodeLenient(EventKind.self, forKey: .kind, default: .general)
        startsAt = try c.decode(Timestamp.self, forKey: .startsAt)
        endsAt = try c.decodeIfPresent(Timestamp.self, forKey: .endsAt) ?? startsAt
        isAllDay = try c.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        tzOffset = c.decodeNumber(forKey: .tzOffset)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        // Money is decoded through `decodeNumber` for the reason every other
        // amount in this app is: `v.number()` is float64, and one `1250.0`
        // would throw and blank a whole month rather than one card.
        budget = c.decodeNumberIfPresent(forKey: .budget)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        recipeIDs = (try? c.decodeIfPresent([RecipeID].self, forKey: .recipeIDs)) ?? []
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence)
        seriesStart = try c.decodeIfPresent(Timestamp.self, forKey: .seriesStart) ?? startsAt
        isRecurring = try c.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? (recurrence != nil)
        attendees = (try? c.decodeIfPresent([UserID].self, forKey: .attendees)) ?? []
        rsvps = (try? c.decodeIfPresent([EventRSVP].self, forKey: .rsvps)) ?? []
        reminders = (try? c.decodeIfPresent([Int].self, forKey: .reminders)) ?? []
        createdBy = try c.decodeIfPresent(UserID.self, forKey: .createdBy)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: String? = nil,
        eventID: EventID,
        homeID: HomeID? = nil,
        title: String,
        notes: String? = nil,
        location: String? = nil,
        kind: EventKind = .general,
        startsAt: Timestamp,
        endsAt: Timestamp,
        isAllDay: Bool = false,
        tzOffset: Int = 0,
        url: String? = nil,
        budget: Int? = nil,
        currency: String? = nil,
        recipeIDs: [RecipeID] = [],
        recurrence: Recurrence? = nil,
        seriesStart: Timestamp? = nil,
        attendees: [UserID] = [],
        rsvps: [EventRSVP] = [],
        reminders: [Int] = [],
        createdBy: UserID? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id ?? "\(eventID.rawValue):\(Int(startsAt.milliseconds))"
        self.eventID = eventID
        self.homeID = homeID
        self.title = title
        self.notes = notes
        self.location = location
        self.kind = kind
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isAllDay = isAllDay
        self.tzOffset = tzOffset
        self.url = url
        self.budget = budget
        self.currency = currency
        self.recipeIDs = recipeIDs
        self.recurrence = recurrence
        self.seriesStart = seriesStart ?? startsAt
        self.isRecurring = recurrence != nil
        self.attendees = attendees
        self.rsvps = rsvps
        self.reminders = reminders
        self.createdBy = createdBy
        self.created = created
        self.updated = updated
    }
}

// MARK: - Derived

extension EventOccurrence {
    public var start: Date { startsAt.date }
    public var end: Date { endsAt.date }

    public var duration: TimeInterval {
        max(0, endsAt.milliseconds - startsAt.milliseconds) / 1000
    }

    public var isPast: Bool { end < Date() }

    /// Under way right now. What the "happening now" band on the agenda is for.
    public var isInProgress: Bool {
        let now = Date()
        return start <= now && now < end
    }

    /// The days this occurrence appears on.
    ///
    /// An all-day event's `endsAt` is midnight on the day *after* the last one —
    /// the half-open convention the server writes — so the final midnight must
    /// not add a day of its own, or every one-day event would claim two.
    public func days(_ calendar: Calendar = .current) -> [CalendarDay] {
        let first = CalendarDay(start, calendar: calendar)
        var lastInstant = end
        if lastInstant > start, lastInstant == calendar.startOfDay(for: lastInstant) {
            lastInstant = lastInstant.addingTimeInterval(-1)
        }
        let last = CalendarDay(lastInstant, calendar: calendar)
        guard last > first else { return [first] }

        var days: [CalendarDay] = [first]
        var cursor = first
        // Bounded: a series is capped server-side and nothing sane spans a
        // year, but a corrupt `ends_at` must not spin here.
        while cursor < last, days.count < 400 {
            cursor = cursor.advanced(by: 1, calendar: calendar)
            days.append(cursor)
        }
        return days
    }

    public var isMultiDay: Bool { days().count > 1 }

    public func rsvp(of user: UserID?) -> RSVPStatus? {
        guard let user else { return nil }
        return rsvps.first { $0.userID == user }?.status
    }

    public var going: [UserID] { rsvps.filter { $0.status == .going }.map(\.userID) }

    /// Whether this concerns `user` at all — they are expected, they answered,
    /// or they wrote it. Drives the "just mine" filter.
    /// Whether this event is one of *mine*, for the calendar's "just mine"
    /// filter.
    ///
    /// Deliberately not "did I type it". `createdBy` used to count, which made
    /// the filter useless in exactly the household it was built for: whoever
    /// enters the events owns every one of them, so the toggle excluded nobody
    /// and read as a dead control.
    ///
    /// An event with no invite list is the household's, and therefore mine too
    /// — hiding the shared calendar behind a personal filter is not what
    /// anybody means by the word. What it does hide is the event that names
    /// other people and not me: somebody else's dentist appointment.
    public func isMine(_ user: UserID?) -> Bool {
        guard let user else { return false }
        if attendees.isEmpty { return true }
        return attendees.contains(user) || rsvps.contains { $0.userID == user }
    }

    /// The reminders this build can offer back, de-duplicated.
    public var reminderChoices: [EventReminder] {
        var seen: [EventReminder] = []
        for minutes in reminders.sorted(by: >) {
            let choice = EventReminder.nearest(to: minutes)
            if !seen.contains(choice) { seen.append(choice) }
        }
        return Array(seen.prefix(EventReminder.maximum))
    }

    /// "14:00 – 15:30", or "All day". Built with the app's own locale rather
    /// than the device's, so it follows the in-app language picker.
    public var timeText: String {
        if isAllDay { return String(localized: L10n.calendarAllDay) }
        let style = Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale)
        let from = start.formatted(style)
        guard duration > 0 else { return from }
        return "\(from) – \(end.formatted(style))"
    }
}

// MARK: - The plan

/// Everything hanging off one event, as `events:detail` computes it.
///
/// One subscription, not four. The alternative — the event, its expenses, its
/// shopping and its recipes as separate live queries — is four websocket queries
/// per open sheet, four pushes whenever any of them changes, and four chances
/// for a spend total to disagree with the list printed under it. Rolled up
/// server-side, the number and the rows it summarises are computed from the same
/// read and cannot contradict each other.
public struct EventPlan: Codable, Equatable, Sendable {
    public var eventID: EventID
    /// The currency the budget and `spent` are in. `nil` when nothing has been
    /// budgeted and nothing has been spent.
    public var currency: String?
    /// Minor units. `nil` when the household has not set one.
    public var budget: Int?
    /// Minor units, scoped to `currency` — the same rule the Finance screen
    /// follows, because adding 500 lira to 20 euros is not a number.
    public var spent: Int
    /// Every currency the linked expenses are written in, so a mixed plan can
    /// say so rather than quietly under-reporting.
    public var currencies: [String]
    public var expenses: [LinkedExpense]
    public var shopping: [LinkedItem]
    public var shoppingTotal: Int
    public var shoppingPurchased: Int
    public var recipes: [MenuRecipe]
    /// Ingredients on the menu that are not yet on the household's list — what
    /// "stock up" would actually add if it were pressed now.
    ///
    /// Computed server-side because the client cannot: a `MenuRecipe` carries
    /// an ingredient *count*, not the names, so the button had no way to know
    /// it would do nothing. It came from the same read as `stockUp`'s own
    /// arithmetic, so the two cannot disagree.
    public var stockUpPending: Int
    /// The days this event is already the household's dinner, as `yyyy-MM-dd`.
    ///
    /// Days, plural, because the plan belongs to the *series* and a series is
    /// many days. "Make it dinner" writes one meal plan for the occurrence being
    /// looked at — a meal plan is one row per home per day, so a weekly event
    /// cannot claim them all — and without this the sheet had no way to know it
    /// had ever been pressed. Every occurrence looked equally undecided.
    public var dinnerDays: [String]

    public static let empty = EventPlan(eventID: EventID(""))

    public init(
        eventID: EventID,
        currency: String? = nil,
        budget: Int? = nil,
        spent: Int = 0,
        currencies: [String] = [],
        expenses: [LinkedExpense] = [],
        shopping: [LinkedItem] = [],
        shoppingTotal: Int = 0,
        shoppingPurchased: Int = 0,
        recipes: [MenuRecipe] = [],
        stockUpPending: Int = 0,
        dinnerDays: [String] = []
    ) {
        self.eventID = eventID
        self.currency = currency
        self.budget = budget
        self.spent = spent
        self.currencies = currencies
        self.expenses = expenses
        self.shopping = shopping
        self.shoppingTotal = shoppingTotal
        self.shoppingPurchased = shoppingPurchased
        self.recipes = recipes
        self.stockUpPending = stockUpPending
        self.dinnerDays = dinnerDays
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case currency, budget, spent, currencies, expenses, shopping, recipes
        case shoppingTotal = "shopping_total"
        case shoppingPurchased = "shopping_purchased"
        case stockUpPending = "stock_up_pending"
        case dinnerDays = "dinner_days"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try c.decode(EventID.self, forKey: .eventID)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        budget = c.decodeNumberIfPresent(forKey: .budget)
        spent = c.decodeNumber(forKey: .spent)
        currencies = (try? c.decodeIfPresent([String].self, forKey: .currencies)) ?? []
        expenses = (try? c.decodeIfPresent([LinkedExpense].self, forKey: .expenses)) ?? []
        shopping = (try? c.decodeIfPresent([LinkedItem].self, forKey: .shopping)) ?? []
        shoppingTotal = c.decodeNumber(forKey: .shoppingTotal)
        shoppingPurchased = c.decodeNumber(forKey: .shoppingPurchased)
        recipes = (try? c.decodeIfPresent([MenuRecipe].self, forKey: .recipes)) ?? []
        stockUpPending = c.decodeNumber(forKey: .stockUpPending)
        dinnerDays = (try? c.decodeIfPresent([String].self, forKey: .dinnerDays)) ?? []
    }

    /// One expense, only as much of it as a plan needs to list.
    public struct LinkedExpense: Codable, Identifiable, Hashable, Sendable {
        public let id: ExpenseID
        public var title: String
        public var amount: Int
        public var currency: String
        public var category: SpendCategory
        public var paidBy: UserID?
        public var spentAt: Timestamp

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case title, amount, currency, category
            case paidBy = "paid_by"
            case spentAt = "spent_at"
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(ExpenseID.self, forKey: .id)
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            amount = c.decodeNumber(forKey: .amount)
            currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "EUR"
            category = c.decodeLenient(SpendCategory.self, forKey: .category, default: .other)
            paidBy = try c.decodeIfPresent(UserID.self, forKey: .paidBy)
            spentAt = try c.decodeIfPresent(Timestamp.self, forKey: .spentAt)
                ?? Timestamp(milliseconds: 0)
        }

        public init(
            id: ExpenseID,
            title: String,
            amount: Int,
            currency: String,
            category: SpendCategory = .other,
            paidBy: UserID? = nil,
            spentAt: Timestamp
        ) {
            self.id = id
            self.title = title
            self.amount = amount
            self.currency = currency
            self.category = category
            self.paidBy = paidBy
            self.spentAt = spentAt
        }
    }

    /// One line of the shopping this event needs.
    public struct LinkedItem: Codable, Identifiable, Hashable, Sendable {
        public let id: ShoppingItemID
        public var name: String
        public var isPurchased: Bool
        public var category: ShoppingItem.Category
        /// Which recipe wanted it, when it came from the menu — so a long list
        /// can still say why the saffron is on it.
        public var recipeTitle: String?

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name, category
            case isPurchased = "is_purchased"
            case recipeTitle = "recipe_title"
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(ShoppingItemID.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            isPurchased = try c.decodeIfPresent(Bool.self, forKey: .isPurchased) ?? false
            category = c.decodeLenient(ShoppingItem.Category.self, forKey: .category, default: .other)
            recipeTitle = try c.decodeIfPresent(String.self, forKey: .recipeTitle)
        }

        public init(
            id: ShoppingItemID,
            name: String,
            isPurchased: Bool = false,
            category: ShoppingItem.Category = .other,
            recipeTitle: String? = nil
        ) {
            self.id = id
            self.name = name
            self.isPurchased = isPurchased
            self.category = category
            self.recipeTitle = recipeTitle
        }
    }

    /// A recipe on the menu, read through so nothing subscribes to recipes to
    /// draw it.
    public struct MenuRecipe: Codable, Identifiable, Hashable, Sendable {
        public let id: RecipeID
        public var title: String
        public var image: String?
        public var prepTime: Int?
        public var cookTime: Int?
        public var servings: Int?
        public var ingredientCount: Int

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case title, image, servings
            case prepTime = "prep_time"
            case cookTime = "cook_time"
            case ingredientCount = "ingredient_count"
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(RecipeID.self, forKey: .id)
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            image = try c.decodeIfPresent(String.self, forKey: .image)
            prepTime = try c.decodeIfPresent(Int.self, forKey: .prepTime)
            cookTime = try c.decodeIfPresent(Int.self, forKey: .cookTime)
            servings = try c.decodeIfPresent(Int.self, forKey: .servings)
            ingredientCount = c.decodeNumber(forKey: .ingredientCount)
        }

        public init(
            id: RecipeID,
            title: String,
            image: String? = nil,
            prepTime: Int? = nil,
            cookTime: Int? = nil,
            servings: Int? = nil,
            ingredientCount: Int = 0
        ) {
            self.id = id
            self.title = title
            self.image = image
            self.prepTime = prepTime
            self.cookTime = cookTime
            self.servings = servings
            self.ingredientCount = ingredientCount
        }

        /// Prep plus cook, when either is known.
        public var totalMinutes: Int? {
            let total = (prepTime ?? 0) + (cookTime ?? 0)
            return total > 0 ? total : nil
        }
    }
}

extension EventPlan {
    public var hasAnything: Bool {
        budget != nil || !expenses.isEmpty || shoppingTotal > 0 || !recipes.isEmpty
    }

    /// Under, over, or exactly on. `nil` with no budget to be measured against.
    public var remaining: Int? {
        guard let budget else { return nil }
        return budget - spent
    }

    public var isOverBudget: Bool { (remaining ?? 0) < 0 }

    /// `0...1` for the ring; a blown budget clamps rather than overflowing the
    /// arc, and the number beside it is what says by how much.
    public var budgetProgress: Double {
        guard let budget, budget > 0 else { return 0 }
        return min(1, Double(spent) / Double(budget))
    }

    /// `0...1`. A list with nothing on it is not "0% done", it is not a list —
    /// callers check `shoppingTotal` first.
    public var shoppingProgress: Double {
        guard shoppingTotal > 0 else { return 0 }
        return Double(shoppingPurchased) / Double(shoppingTotal)
    }

    public var shoppingIsDone: Bool {
        shoppingTotal > 0 && shoppingPurchased == shoppingTotal
    }

    public var outstandingItems: [LinkedItem] { shopping.filter { !$0.isPurchased } }

    /// The linked expenses have more than one currency on them, so the total
    /// above them is only part of the story.
    public var isMixedCurrency: Bool { currencies.count > 1 }

    /// Every ingredient the menu wants, as a count — for the "stock up" button,
    /// which otherwise reads as a button that might do nothing.
    public var menuIngredientCount: Int {
        recipes.reduce(0) { $0 + $1.ingredientCount }
    }
}

// MARK: - Writes

/// Everything needed to write an event.
///
/// Times are absolute instants; `tzOffset` rides along so a monthly series
/// keeps meaning the same wall-clock day and hour wherever it is later read
/// from.
public struct NewEvent: Equatable, Sendable {
    public var homeID: HomeID
    public var title: String
    public var notes: String?
    public var location: String?
    public var kind: EventKind
    public var startsAt: Date
    public var endsAt: Date
    public var isAllDay: Bool
    public var recurrence: Recurrence?
    public var attendees: [UserID]
    public var reminders: [EventReminder]
    /// The ticket or booking link.
    public var url: String?
    /// Minor units. `nil` for an event nobody is budgeting.
    public var budget: Int?
    public var currency: String?
    /// The menu, if the event has one.
    public var recipeIDs: [RecipeID]

    public init(
        homeID: HomeID,
        title: String,
        notes: String? = nil,
        location: String? = nil,
        kind: EventKind = .general,
        startsAt: Date,
        endsAt: Date,
        isAllDay: Bool = false,
        recurrence: Recurrence? = nil,
        attendees: [UserID] = [],
        reminders: [EventReminder] = [],
        url: String? = nil,
        budget: Int? = nil,
        currency: String? = nil,
        recipeIDs: [RecipeID] = []
    ) {
        self.homeID = homeID
        self.title = title
        self.notes = notes
        self.location = location
        self.kind = kind
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isAllDay = isAllDay
        self.recurrence = recurrence
        self.attendees = attendees
        self.reminders = reminders
        self.url = url
        self.budget = budget
        self.currency = currency
        self.recipeIDs = recipeIDs
    }
}

/// Which of a repeating event an edit or a delete is about.
public enum EventScope: String, Sendable, Equatable {
    /// Every occurrence, past and future.
    case series
    /// This one date only — skipped on the series, and re-written as its own
    /// event if it is an edit rather than a delete.
    case occurrence
}
