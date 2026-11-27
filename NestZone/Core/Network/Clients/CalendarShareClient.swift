import ComposableArchitecture
import ConvexMobile
import Foundation

/// The person's own calendars, shared with a house (`backend/convex/calendarShare.ts`).
///
/// Five calls, all through `ConvexConnection`. Reading what housemates share is
/// open to every house; uploading is Plus, and the server says so
/// (`PRO_REQUIRED`) however the phone is feeling about it. What is read off the
/// phone and what is chosen lives in `CalendarShareFeature`; this only talks.
@DependencyClient
public struct CalendarShareClient: Sendable {
    /// What this person shares in this house, live; `nil` before they ever have.
    public var mine: @Sendable (HomeID) -> AsyncThrowingStream<CalendarShareRow?, any Error> = { _ in .never }
    /// Housemates' shared items overlapping `[from, to]`, live, soonest first.
    /// Other members only, unless `includeOwn`: then the caller's own shared
    /// items come too (same shape, their own `userID`), so a person sees on
    /// the calendar what the house sees of them. The copy engine never asks
    /// for them: a person's own meetings are already in their own calendar.
    public var inRange: @Sendable (HomeID, Date, Date, _ includeOwn: Bool) -> AsyncThrowingStream<[SharedBusyItem], any Error> = { _, _, _, _ in .never }
    /// Replaces the whole list of calendars shared in this house. An empty list
    /// stops sharing, and is never refused.
    /// `allowCopy` is whether housemates may copy them into their own
    /// calendars; `nil` keeps what the server holds (a phone that never chose
    /// must not undo another phone's answer).
    public var setCalendars: @Sendable (_ homeID: HomeID, _ calendars: [SharedCalendarEntry], _ windowDays: Int, _ allowCopy: Bool?) async throws -> CalendarShareRow
    /// Who shares calendars with this house and whether they let them be
    /// copied, live. Housemates only.
    public var housemates: @Sendable (HomeID) -> AsyncThrowingStream<[HousemateShare], any Error> = { _ in .never }
    /// Replaces one calendar's items in `from...to` with `items`. Idempotent: a
    /// retry after a dropped connection is harmless. Answers how many it wrote.
    public var replace: @Sendable (_ homeID: HomeID, _ calendarKey: String, _ from: Date, _ to: Date, _ items: [SharedItemUpload]) async throws -> Int
    /// Stops sharing one calendar, or every calendar when `calendarKey` is
    /// `nil`, and deletes what was shared. Never refused.
    public var stop: @Sendable (_ homeID: HomeID, _ calendarKey: String?) async throws -> Void
}

extension CalendarShareClient: DependencyKey {
    public static let liveValue = CalendarShareClient(
        mine: { homeID in
            ConvexConnection.shared.subscribe(
                to: "calendarShare:mine",
                args: ["homeId": homeID],
                as: CalendarShareRow?.self
            )
        },
        inRange: { homeID, from, to, includeOwn in
            var args: [String: ConvexEncodable?] = ["homeId": homeID, "from": from.convexMillis, "to": to.convexMillis]
            // Sent only when asked for: a backend that predates the argument
            // would reject it, and the copy engine never wants it.
            if includeOwn { args["includeOwn"] = true }
            return ConvexConnection.shared.subscribe(
                to: "calendarShare:inRange",
                args: args,
                as: [SharedBusyItem].self
            )
        },
        setCalendars: { homeID, calendars, windowDays, allowCopy in
            let list: [ConvexEncodable?] = calendars.map { entry in
                var out: [String: ConvexEncodable?] = [
                    "key": entry.key,
                    "name": entry.name,
                    "level": entry.level.rawValue,
                ]
                if let color = entry.colorHex { out["color"] = color }
                return out
            }
            var args: [String: ConvexEncodable?] = [
                "homeId": homeID,
                "calendars": list,
                "windowDays": windowDays.convexNumber,
            ]
            if let allowCopy { args["allowCopy"] = allowCopy }
            return try await ConvexConnection.shared.mutate(
                "calendarShare:setCalendars",
                args: args,
                as: CalendarShareRow.self,
                // Done in the background; a Plus refusal is handled quietly by
                // the share engine, never as a paywall over something else.
                presentsPaywall: false
            )
        },
        housemates: { homeID in
            ConvexConnection.shared.subscribe(
                to: "calendarShare:housemates",
                args: ["homeId": homeID],
                as: [HousemateShare].self
            )
        },
        replace: { homeID, key, from, to, items in
            let list: [ConvexEncodable?] = items.map { item in
                var out: [String: ConvexEncodable?] = [
                    "startsAt": item.startsAt.convexMillis,
                    "endsAt": item.endsAt.convexMillis,
                ]
                if item.isAllDay { out["isAllDay"] = true }
                if let title = item.title, !title.isEmpty { out["title"] = title }
                if let location = item.location, !location.isEmpty { out["location"] = location }
                return out
            }
            let answer = try await ConvexConnection.shared.mutate(
                "calendarShare:replace",
                args: [
                    "homeId": homeID,
                    "calendarKey": key,
                    "from": from.convexMillis,
                    "to": to.convexMillis,
                    "items": list,
                ],
                as: ReplaceAnswer.self,
                presentsPaywall: false
            )
            return answer.written
        },
        stop: { homeID, key in
            var args: [String: ConvexEncodable?] = ["homeId": homeID]
            if let key { args["calendarKey"] = key }
            try await ConvexConnection.shared.mutate("calendarShare:stop", args: args, presentsPaywall: false)
        }
    )

    /// `{ written }`.
    private struct ReplaceAnswer: Decodable {
        let written: Int

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            written = c.decodeNumber(forKey: .written)
        }

        enum CodingKeys: String, CodingKey { case written }
    }

    public static let testValue = CalendarShareClient()
    public static let previewValue = CalendarShareClient()
}

extension DependencyValues {
    public var calendarShare: CalendarShareClient {
        get { self[CalendarShareClient.self] }
        set { self[CalendarShareClient.self] = newValue }
    }
}
