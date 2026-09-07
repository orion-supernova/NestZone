import ComposableArchitecture
import Foundation
import ConvexMobile

/// The household calendar.
///
/// Every read is a *window*. The server expands each series into concrete
/// occurrences for the range asked for, so the screen subscribes to the month it
/// is showing and holds nothing else — a household with three years of events
/// costs the same to open in April as one created yesterday. Moving the window
/// replaces the subscription rather than filtering a larger one.
@DependencyClient
public struct EventsClient: Sendable {
    /// Live occurrences overlapping `[from, to]`, soonest first.
    public var inRange: @Sendable (HomeID, Date, Date) -> AsyncThrowingStream<[EventOccurrence], any Error> = { _, _, _ in .never }
    /// The next few things, whenever they are — for the Hub tile.
    public var upcoming: @Sendable (HomeID, Int) -> AsyncThrowingStream<[EventOccurrence], any Error> = { _, _ in .never }
    /// Writes a new event and hands back its id.
    ///
    /// The id matters because a plan is written in two steps: the event first,
    /// then anything the composer drafted against it — a shopping list typed
    /// before the event existed has nothing to attach to until it does.
    public var create: @Sendable (NewEvent) async throws -> EventID
    /// Applies `edit` to a whole series, or lifts one occurrence out of it.
    ///
    /// Returns the id the edit landed on, which is *not* always the one passed
    /// in: an occurrence-scope edit detaches that date as its own event, and
    /// anything attached afterwards belongs to the detached copy rather than to
    /// the series it left.
    public var update: @Sendable (EventID, EventScope, Date?, EventEdit) async throws -> EventID
    /// Deletes a series, or skips the occurrence starting at the given instant.
    public var remove: @Sendable (EventID, EventScope, Date?) async throws -> Void
    /// Says whether the signed-in user is coming. `nil` withdraws the answer.
    public var rsvp: @Sendable (EventID, RSVPStatus?) async throws -> Void

    // MARK: The plan
    //
    // One event links out to the three things a household has to organise
    // around a date — what it costs, what has to be bought, what is being
    // cooked. `plan` rolls all three up in a single subscription so the numbers
    // and the rows under them are computed from the same read and can never
    // disagree.

    /// Live rollup of one event's money, shopping and menu. `nil` once the
    /// event is gone.
    public var plan: @Sendable (EventID) -> AsyncThrowingStream<EventPlan?, any Error> = { _ in .never }
    /// Turns the menu into a shopping list, in one write. Returns how many
    /// lines were added and how many were already on the list.
    public var stockUp: @Sendable (EventID, ShoppingItem.Category?) async throws -> StockUpResult
    /// Adds things to buy that no recipe asked for — the candles, the ice.
    public var addItems: @Sendable (EventID, [String], ShoppingItem.Category?) async throws -> StockUpResult
}

/// What a bulk add actually did. `skipped` is the interesting half: it is how
/// the UI can say "already on the list" instead of silently doing nothing.
public struct StockUpResult: Codable, Equatable, Sendable {
    public var added: Int
    public var skipped: Int

    public init(added: Int = 0, skipped: Int = 0) {
        self.added = added
        self.skipped = skipped
    }
}

/// A partial update. Only the fields set here are sent.
///
/// `recurrence` is the one that needs three states rather than two: absent
/// leaves the repeat alone, `.some(nil)` clears it, `.some(rule)` replaces it.
/// A plain optional could not say "stop repeating" without also being the way
/// to say "don't touch it".
public struct EventEdit: Equatable, Sendable {
    public var title: String?
    public var notes: String?
    public var location: String?
    public var kind: EventKind?
    public var startsAt: Date?
    public var endsAt: Date?
    public var isAllDay: Bool?
    public var recurrence: Recurrence??
    public var attendees: [UserID]?
    public var reminders: [EventReminder]?
    public var url: String?
    /// The same three-state trick as `recurrence`: absent leaves the budget
    /// alone, `.some(nil)` removes it, `.some(n)` replaces it.
    public var budget: Int??
    public var currency: String?
    public var recipeIDs: [RecipeID]?

    public init(
        title: String? = nil,
        notes: String? = nil,
        location: String? = nil,
        kind: EventKind? = nil,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        isAllDay: Bool? = nil,
        recurrence: Recurrence?? = nil,
        attendees: [UserID]? = nil,
        reminders: [EventReminder]? = nil,
        url: String? = nil,
        budget: Int?? = nil,
        currency: String? = nil,
        recipeIDs: [RecipeID]? = nil
    ) {
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

    var arguments: [String: ConvexEncodable?] {
        var args: [String: ConvexEncodable?] = [:]
        if let title { args["title"] = title }
        if let notes { args["notes"] = notes }
        if let location { args["location"] = location }
        if let kind { args["kind"] = kind.rawValue }
        if let startsAt { args["startsAt"] = startsAt.convexMillis }
        if let endsAt { args["endsAt"] = endsAt.convexMillis }
        if let isAllDay { args["isAllDay"] = isAllDay }
        if let startsAt { args["tzOffset"] = EventsClient.tzOffset(at: startsAt) }
        if let attendees { args["attendees"] = attendees.map(\.rawValue) }
        if let reminders { args["reminders"] = reminders.map { $0.minutes.convexNumber } }
        // The doubled optional: the outer one is "was this field mentioned",
        // the inner one is the value. Convex takes an explicit null to clear.
        if let recurrence {
            args["recurrence"] = recurrence.map(EventsClient.encode(_:)) ?? nil
        }
        if let url { args["url"] = url }
        if let budget {
            // The same doubled optional, for the same reason: a household that
            // stops budgeting an event has to be able to say so.
            args["budget"] = budget.map(\.convexNumber) ?? nil
            if let budget, budget > 0 { args["currency"] = currency ?? Money.deviceDefault }
        } else if let currency {
            args["currency"] = currency
        }
        if let recipeIDs { args["recipeIds"] = recipeIDs.map(\.rawValue) }
        return args
    }
}

extension EventsClient {
    /// Minutes east of UTC, at the moment the event happens rather than now —
    /// so an event written in winter for a summer date carries the offset it
    /// will actually be read at.
    static func tzOffset(at date: Date) -> Double {
        Double(TimeZone.current.secondsFromGMT(for: date) / 60)
    }

    /// The wire form of a repeat rule.
    ///
    /// Hand-built rather than `JSONEncoder`'d: convex-swift wants a dictionary
    /// of `ConvexEncodable`, and an integer heading for a `v.number()` has to go
    /// through `convexNumber` or the validator rejects the whole request.
    static func encode(_ rule: Recurrence) -> [String: ConvexEncodable?] {
        var out: [String: ConvexEncodable?] = [
            "freq": rule.frequency.rawValue,
            "interval": rule.interval.convexNumber,
        ]
        if rule.frequency == .weekly, !rule.weekdays.isEmpty {
            out["weekdays"] = rule.weekdays.map(\.convexNumber)
        }
        if let until = rule.until { out["until"] = until.milliseconds }
        return out
    }
}

extension EventsClient: DependencyKey {
    public static let liveValue = EventsClient(
        inRange: { homeID, from, to in
            ConvexConnection.shared.subscribe(
                to: "events:inRange",
                args: ["homeId": homeID, "from": from.convexMillis, "to": to.convexMillis],
                as: [EventOccurrence].self
            )
        },
        upcoming: { homeID, limit in
            ConvexConnection.shared.subscribe(
                to: "events:upcoming",
                args: ["homeId": homeID, "limit": limit.convexNumber],
                as: [EventOccurrence].self
            )
        },
        create: { event in
            let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.eventTitleEmpty",
                    defaultValue: "Give the event a name."
                ))
            }
            guard event.endsAt >= event.startsAt else {
                throw AppError.validation(String(
                    localized: "validation.eventEndsBeforeStart",
                    defaultValue: "The event ends before it starts."
                ))
            }
            var args: [String: ConvexEncodable?] = [
                "homeId": event.homeID,
                "title": trimmed,
                "kind": event.kind.rawValue,
                "startsAt": event.startsAt.convexMillis,
                "endsAt": event.endsAt.convexMillis,
                "isAllDay": event.isAllDay,
                "tzOffset": tzOffset(at: event.startsAt),
            ]
            if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                args["notes"] = notes
            }
            if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines),
               !location.isEmpty {
                args["location"] = location
            }
            if !event.attendees.isEmpty {
                args["attendees"] = event.attendees.map(\.rawValue)
            }
            if !event.reminders.isEmpty {
                args["reminders"] = event.reminders.map { $0.minutes.convexNumber }
            }
            if let rule = event.recurrence { args["recurrence"] = encode(rule) }
            if let url = event.url?.trimmingCharacters(in: .whitespacesAndNewlines),
               !url.isEmpty {
                args["url"] = url
            }
            if let budget = event.budget, budget > 0 {
                args["budget"] = budget.convexNumber
                args["currency"] = event.currency ?? Money.deviceDefault
            }
            if !event.recipeIDs.isEmpty {
                args["recipeIds"] = event.recipeIDs.map(\.rawValue)
            }
            return try await ConvexConnection.shared.mutate(
                "events:create", args: args, as: EventID.self
            )
        },
        update: { id, scope, occurrenceStart, edit in
            var args = edit.arguments
            args["id"] = id
            args["scope"] = scope.rawValue
            if let occurrenceStart { args["occurrenceStart"] = occurrenceStart.convexMillis }
            return try await ConvexConnection.shared.mutate(
                "events:update", args: args, as: EventID.self
            )
        },
        remove: { id, scope, occurrenceStart in
            var args: [String: ConvexEncodable?] = ["id": id, "scope": scope.rawValue]
            if let occurrenceStart { args["occurrenceStart"] = occurrenceStart.convexMillis }
            try await ConvexConnection.shared.mutate("events:remove", args: args)
        },
        rsvp: { id, status in
            try await ConvexConnection.shared.mutate(
                "events:rsvp", args: ["id": id, "status": status?.rawValue]
            )
        },

        plan: { id in
            ConvexConnection.shared.subscribe(
                to: "events:detail", args: ["id": id], as: EventPlan?.self
            )
        },
        stockUp: { id, category in
            var args: [String: ConvexEncodable?] = ["id": id]
            if let category { args["category"] = category.rawValue }
            return try await ConvexConnection.shared.mutate(
                "events:stockUp", args: args, as: StockUpResult.self
            )
        },
        addItems: { id, names, category in
            let cleaned = names
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !cleaned.isEmpty else { return StockUpResult() }
            var args: [String: ConvexEncodable?] = [
                "id": id,
                "names": cleaned.map { $0 as ConvexEncodable? },
            ]
            if let category { args["category"] = category.rawValue }
            return try await ConvexConnection.shared.mutate(
                "events:addItems", args: args, as: StockUpResult.self
            )
        }
    )

    public static let testValue = EventsClient()
}

extension DependencyValues {
    public var events: EventsClient {
        get { self[EventsClient.self] }
        set { self[EventsClient.self] = newValue }
    }
}
