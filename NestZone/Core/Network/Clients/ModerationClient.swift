import ComposableArchitecture
import Foundation
import ConvexMobile

/// Reporting, blocking and the moderators' queue (App Store guideline 1.2).
///
/// Everything here is a thin call onto `backend/convex/moderation.ts`, which
/// does the checking. The moderator calls are refused by the server for anyone
/// who is not one (`FORBIDDEN`), whatever the phone believes about itself.
@DependencyClient
public struct ModerationClient: Sendable {
    /// Reports a message, a problem photo or a profile photo. The server hides
    /// it from the reporter in the same write.
    public var report: @Sendable (ReportSubject, ReportReason, String?) async throws -> ReportOutcome

    /// What this person has reported and so no longer sees: problem photos by
    /// storage id, faces by user id.
    public var hidden: @Sendable () -> AsyncThrowingStream<[HiddenItem], any Error> = { .never }

    public var blocked: @Sendable () -> AsyncThrowingStream<[BlockedPerson], any Error> = { .never }
    public var block: @Sendable (UserID) async throws -> Void
    public var unblock: @Sendable (UserID) async throws -> Void

    // MARK: Moderators only

    /// Whether this person is a moderator, live.
    public var amModerator: @Sendable () -> AsyncThrowingStream<Bool, any Error> = { .never }
    /// The newest page of open reports, live: a report filed while the screen
    /// is open arrives at the top.
    public var queue: @Sendable () -> AsyncThrowingStream<ReportPage, any Error> = { .never }
    /// One page further back, fetched once. A report that has been settled
    /// cannot come back, so there is nothing for a subscription to deliver.
    public var olderQueue: @Sendable (String) async throws -> ReportPage
    public var detail: @Sendable (ReportID) -> AsyncThrowingStream<ReportDetail?, any Error> = { _ in .never }
    public var dismiss: @Sendable (ReportID) async throws -> Void
    public var deleteContent: @Sendable (ReportID) async throws -> Void
    public var removeFromHome: @Sendable (ReportID) async throws -> Void
    public var suspendChat: @Sendable (ReportID) async throws -> Void
    public var unsuspendChat: @Sendable (UserID) async throws -> Void
}

/// How many reports one page of the queue asks for.
private let queuePageSize = 25

private func queueArgs(cursor: String?) -> [String: ConvexEncodable?] {
    // The cursor is `null` for the first page, not absent: the validator is a
    // union of string and null.
    let cursorValue: ConvexEncodable? = cursor
    return ["paginationOpts": [
        "numItems": queuePageSize.convexNumber,
        "cursor": cursorValue,
    ] as [String: ConvexEncodable?]]
}

extension ModerationClient: DependencyKey {
    public static let liveValue = ModerationClient(
        report: { subject, reason, note in
            var args: [String: ConvexEncodable?] = [
                "kind": subject.kind.rawValue,
                "targetId": subject.targetID,
                "reason": reason.rawValue,
            ]
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { args["note"] = trimmed }
            if let issueID = subject.issueID { args["issueId"] = issueID }
            if let homeID = subject.homeID { args["homeId"] = homeID }
            let answer = try await ConvexConnection.shared.mutate(
                "moderation:report", args: args, as: ReportAnswer.self
            )
            return answer.outcome
        },
        hidden: {
            ConvexConnection.shared.subscribe(
                to: "moderation:hiddenByMe", args: [:], as: [HiddenItem].self
            )
        },
        blocked: {
            ConvexConnection.shared.subscribe(
                to: "moderation:blockedByMe", args: [:], as: [BlockedPerson].self
            )
        },
        block: { userID in
            try await ConvexConnection.shared.mutate("moderation:block", args: ["userId": userID])
        },
        unblock: { userID in
            try await ConvexConnection.shared.mutate("moderation:unblock", args: ["userId": userID])
        },
        amModerator: {
            ConvexConnection.shared.subscribe(to: "moderation:amModerator", args: [:], as: Bool.self)
        },
        queue: {
            ConvexConnection.shared.subscribe(
                to: "moderation:queue", args: queueArgs(cursor: nil), as: ReportPage.self
            )
        },
        olderQueue: { cursor in
            try await ConvexConnection.shared.first(
                "moderation:queue", args: queueArgs(cursor: cursor), as: ReportPage.self
            )
        },
        detail: { id in
            ConvexConnection.shared.subscribe(
                to: "moderation:detail", args: ["reportId": id], as: ReportDetail?.self
            )
        },
        dismiss: { id in
            try await ConvexConnection.shared.mutate("moderation:dismiss", args: ["reportId": id])
        },
        deleteContent: { id in
            try await ConvexConnection.shared.mutate("moderation:deleteContent", args: ["reportId": id])
        },
        removeFromHome: { id in
            try await ConvexConnection.shared.mutate("moderation:removeFromHome", args: ["reportId": id])
        },
        suspendChat: { id in
            try await ConvexConnection.shared.mutate("moderation:suspendChat", args: ["reportId": id])
        },
        unsuspendChat: { userID in
            try await ConvexConnection.shared.mutate("moderation:unsuspendChat", args: ["userId": userID])
        }
    )

    public static let testValue = ModerationClient()

    /// `{ reportId, status }`.
    private struct ReportAnswer: Decodable {
        let status: String

        var outcome: ReportOutcome { ReportOutcome(rawValue: status) ?? .filed }
    }
}

extension DependencyValues {
    public var moderation: ModerationClient {
        get { self[ModerationClient.self] }
        set { self[ModerationClient.self] = newValue }
    }
}
