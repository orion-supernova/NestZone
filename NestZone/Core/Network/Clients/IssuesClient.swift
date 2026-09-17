import ComposableArchitecture
import Foundation
import ConvexMobile

/// House problems: what is broken, and what the household is doing about it.
///
/// Two live reads serve the whole module. `board` is one subscription and not
/// three on purpose — the counters, the room grid and the rows under them arrive
/// computed from the same server-side read, so a badge saying "2 urgent" can
/// never sit above three urgent rows. `detail` does the same one level down for
/// a single problem's history, parts, receipts and links.
///
/// Everything the module writes goes through a mutation that also writes the
/// *other* module's row: making a chore inserts a real task, booking a visit
/// inserts a real calendar event, adding parts inserts real shopping items. The
/// phone never keeps a private shadow of any of it.
@DependencyClient
public struct IssuesClient: Sendable {
    /// Live problems plus the household's state of repair, in one payload.
    public var board: @Sendable (HomeID) -> AsyncThrowingStream<IssueBoard, any Error> = { _ in .never }
    /// Live rollup of one problem. `nil` once it is gone.
    public var detail: @Sendable (IssueID) -> AsyncThrowingStream<IssueDetail?, any Error> = { _ in .never }

    public var create: @Sendable (NewIssue) async throws -> IssueID
    public var update: @Sendable (IssueID, IssueEdit) async throws -> Void
    /// Moves a problem along. The note is why it is stuck, for `.blocked`, and
    /// what fixed it, for `.fixed`.
    public var setStatus: @Sendable (IssueID, IssueStatus, String?) async throws -> Void
    /// `nil` takes the name off it.
    public var assign: @Sendable (IssueID, UserID?) async throws -> Void
    /// "This is happening to me too." Returns how many people are affected now.
    public var toggleMeToo: @Sendable (IssueID) async throws -> Int
    public var remove: @Sendable (IssueID) async throws -> Void

    public var comment: @Sendable (IssueID, String) async throws -> Void
    public var removeComment: @Sendable (IssueEntryID) async throws -> Void

    // MARK: The plan

    /// Turns the problem into a chore on the household's task list.
    public var makeChore: @Sendable (IssueID, UserID?, Date?) async throws -> Void
    /// Puts the repair visit in the household's calendar.
    public var scheduleVisit: @Sendable (IssueID, VisitBooking) async throws -> EventID
    /// Sends the parts to the shopping list in one write. Returns how many were
    /// added — the server skips anything already outstanding, so the count is
    /// what the household actually gained.
    public var addParts: @Sendable (IssueID, [String]) async throws -> StockUpResult

    // MARK: Photos

    /// Uploads one image and hands back its storage id.
    ///
    /// The bytes never pass through a mutation: the server signs a one-shot URL,
    /// the phone posts straight to it, and only the id it answers with goes into
    /// the document. A five-megapixel photo does not belong in the transaction
    /// that records it.
    /// Uploads both sizes and hands back both ids. They are taken together
    /// because they are stored together — a full picture filed without its
    /// thumbnail leaves the board drawing the wrong row's photo.
    public var uploadPhoto: @Sendable (IssuePhotoUpload) async throws -> IssuePhotoIDs
    public var attachPhotos: @Sendable (IssueID, [IssuePhotoIDs]) async throws -> Void
    public var removePhoto: @Sendable (IssueID, String) async throws -> Void
}

/// When somebody is coming, and who.
public struct VisitBooking: Equatable, Sendable {
    public var startsAt: Date
    public var endsAt: Date
    /// Overrides the title the server would build from the vendor's name.
    public var title: String?
    public var location: String?
    /// Whole minutes before to nudge the household.
    public var reminders: [Int]

    public init(
        startsAt: Date,
        endsAt: Date,
        title: String? = nil,
        location: String? = nil,
        reminders: [Int] = [60]
    ) {
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.title = title
        self.location = location
        self.reminders = reminders
    }
}

extension IssuesClient: DependencyKey {
    public static let liveValue = IssuesClient(
        board: { homeID in
            ConvexConnection.shared.subscribe(
                to: "issues:byHome",
                args: [
                    "homeId": homeID,
                    // The server has no timezone, and the month figures on the
                    // History face are wall-clock questions. Without this a
                    // household in UTC+13 would find the first evening of every
                    // month filed under the previous one.
                    "tzOffsetMinutes": (TimeZone.current.secondsFromGMT() / 60).convexNumber,
                ],
                as: IssueBoard.self
            )
        },
        detail: { id in
            ConvexConnection.shared.subscribe(
                to: "issues:detail", args: ["id": id], as: IssueDetail?.self
            )
        },

        create: { new in
            let title = new.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                throw AppError.validation(String(localized: L10n.issuesErrorTitle))
            }
            var args: [String: ConvexEncodable?] = [
                "homeId": new.homeID,
                "title": title,
                "area": new.area.rawValue,
                "category": new.category.rawValue,
                "severity": new.severity.rawValue,
            ]
            if let details = new.details?.trimmingCharacters(in: .whitespacesAndNewlines),
               !details.isEmpty {
                args["details"] = details
            }
            if let assignee = new.assignedTo { args["assignedTo"] = assignee }
            if let dueBy = new.dueBy { args["dueBy"] = dueBy.convexMillis }
            if let estimate = new.costEstimate, estimate > 0 {
                args["costEstimate"] = estimate.convexNumber
                args["currency"] = new.currency ?? Money.deviceDefault
            }
            if let vendor = new.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !vendor.isEmpty {
                args["vendorName"] = vendor
            }
            if let phone = new.vendorPhone?.trimmingCharacters(in: .whitespacesAndNewlines),
               !phone.isEmpty {
                args["vendorPhone"] = phone
            }
            if let link = new.vendorURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !link.isEmpty {
                args["vendorUrl"] = link
            }
            if let warranty = new.warrantyUntil { args["warrantyUntil"] = warranty.convexMillis }
            if !new.photos.isEmpty {
                // `[String]` is not `ConvexEncodable` — only `[ConvexEncodable?]`
                // is — so the array has to be widened element by element.
                args["photos"] = new.photos.map { $0.full as ConvexEncodable? }
                args["photoThumbs"] = new.photos.map { $0.thumbnail as ConvexEncodable? }
            }
            return try await ConvexConnection.shared.mutate(
                "issues:create", args: args, as: IssueID.self
            )
        },

        update: { id, edit in
            var args = edit.arguments
            args["id"] = id
            try await ConvexConnection.shared.mutate("issues:update", args: args)
        },

        setStatus: { id, status, note in
            var args: [String: ConvexEncodable?] = ["id": id, "status": status.rawValue]
            if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                args["note"] = note
            }
            try await ConvexConnection.shared.mutate("issues:setStatus", args: args)
        },

        assign: { id, userID in
            // Sent even when nil: an absent argument would read as "leave it
            // alone", and taking somebody's name off a repair has to be sayable.
            try await ConvexConnection.shared.mutate(
                "issues:assign", args: ["id": id, "userId": userID]
            )
        },

        toggleMeToo: { id in
            let result = try await ConvexConnection.shared.mutate(
                "issues:toggleMeToo", args: ["id": id], as: AffectedCount.self
            )
            return result.affected
        },

        remove: { id in
            try await ConvexConnection.shared.mutate("issues:remove", args: ["id": id])
        },

        comment: { id, body in
            let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw AppError.validation(String(localized: L10n.issuesErrorComment))
            }
            try await ConvexConnection.shared.mutate(
                "issues:comment", args: ["id": id, "body": text]
            )
        },

        removeComment: { id in
            try await ConvexConnection.shared.mutate("issues:removeComment", args: ["id": id])
        },

        makeChore: { id, assignee, due in
            var args: [String: ConvexEncodable?] = ["id": id]
            if let assignee { args["assignedTo"] = assignee }
            if let due { args["dueDate"] = due.convexMillis }
            try await ConvexConnection.shared.mutate("issues:makeChore", args: args)
        },

        scheduleVisit: { id, booking in
            guard booking.endsAt >= booking.startsAt else {
                throw AppError.validation(String(localized: L10n.issuesErrorVisitOrder))
            }
            var args: [String: ConvexEncodable?] = [
                "id": id,
                "startsAt": booking.startsAt.convexMillis,
                "endsAt": booking.endsAt.convexMillis,
                "reminders": booking.reminders.map { $0.convexNumber as ConvexEncodable? },
                // The offset the visit was booked at, not the one now: every
                // other row in `events` carries one, and an appointment written
                // without it is the row that trips up whatever reads them next.
                "tzOffset": EventsClient.tzOffset(at: booking.startsAt),
            ]
            if let title = booking.title?.trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                args["title"] = title
            }
            if let place = booking.location?.trimmingCharacters(in: .whitespacesAndNewlines),
               !place.isEmpty {
                args["location"] = place
            }
            let result = try await ConvexConnection.shared.mutate(
                "issues:scheduleVisit", args: args, as: ScheduledVisit.self
            )
            return result.eventId
        },

        addParts: { id, names in
            let cleaned = names
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !cleaned.isEmpty else { return StockUpResult() }
            return try await ConvexConnection.shared.mutate(
                "issues:addParts",
                args: ["id": id, "names": cleaned.map { $0 as ConvexEncodable? }],
                as: StockUpResult.self
            )
        },

        uploadPhoto: { photo in
            // Two round trips, not one: the bytes never pass through a mutation,
            // so each size needs its own signed URL. They are small and they go
            // out together.
            async let full = ConvexConnection.shared.upload(
                photo.full.data,
                contentType: photo.full.contentType,
                signedBy: "issues:uploadUrl"
            )
            async let thumbnail = ConvexConnection.shared.upload(
                photo.thumbnail.data,
                contentType: photo.thumbnail.contentType,
                signedBy: "issues:uploadUrl"
            )
            return try await IssuePhotoIDs(full: full, thumbnail: thumbnail)
        },

        attachPhotos: { id, photos in
            guard !photos.isEmpty else { return }
            try await ConvexConnection.shared.mutate(
                "issues:attachPhotos",
                args: [
                    "id": id,
                    "storageIds": photos.map { $0.full as ConvexEncodable? },
                    // Same order, same length. `attachPhotos` pairs them by
                    // index, so the two arrays are one value in two fields.
                    "thumbIds": photos.map { $0.thumbnail as ConvexEncodable? },
                ]
            )
        },

        removePhoto: { id, storageID in
            try await ConvexConnection.shared.mutate(
                "issues:removePhoto", args: ["id": id, "storageId": storageID]
            )
        }
    )

    public static let testValue = IssuesClient()
}

// MARK: - Argument building

extension IssueEdit {
    var arguments: [String: ConvexEncodable?] {
        var args: [String: ConvexEncodable?] = [:]
        if let title { args["title"] = title.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let details { args["details"] = details }
        if let area { args["area"] = area.rawValue }
        if let category { args["category"] = category.rawValue }
        if let severity { args["severity"] = severity.rawValue }
        // The doubled optional: the outer one is "was this field mentioned",
        // the inner one is the value. Convex takes an explicit null to clear.
        if let dueBy { args["dueBy"] = dueBy?.convexMillis }
        if let costEstimate {
            args["costEstimate"] = costEstimate.map(\.convexNumber) ?? nil
            if let costEstimate, costEstimate > 0 {
                args["currency"] = currency ?? Money.deviceDefault
            }
        } else if let currency {
            args["currency"] = currency
        }
        if let vendorName { args["vendorName"] = vendorName }
        if let vendorPhone { args["vendorPhone"] = vendorPhone }
        if let vendorURL { args["vendorUrl"] = vendorURL }
        if let warrantyUntil { args["warrantyUntil"] = warrantyUntil?.convexMillis }
        return args
    }
}

/// `issues:toggleMeToo` answers with what it actually did.
private struct AffectedCount: Decodable {
    let affected: Int
}

/// `issues:scheduleVisit` hands back the calendar event it wrote, so the screen
/// can offer to open it.
private struct ScheduledVisit: Decodable {
    let eventId: EventID
}

extension DependencyValues {
    public var issues: IssuesClient {
        get { self[IssuesClient.self] }
        set { self[IssuesClient.self] = newValue }
    }
}
