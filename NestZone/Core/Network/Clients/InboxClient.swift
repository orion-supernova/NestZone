import ComposableArchitecture
import Foundation
import ConvexMobile

/// The bell in the corner: the household's notification log, and the app's own
/// changelog.
///
/// Three reads with three deliberately different lifetimes, which is the whole
/// performance story of this feature:
///
/// - `badge` is live for as long as a home is open. It is the only one that is
///   always on, so it is the only one the server floors — it never counts more
///   than a fortnight back, whatever the watermark says, and it answers both
///   counts, both watermarks and the admin flag in one payload so a number can
///   never contradict the list beneath it.
/// - `activity` is live only while the panel is open, and only over the newest
///   page. A chore ticked in the kitchen appears at the top while somebody is
///   looking; nothing else needs a socket.
/// - `olderActivity` is a genuine one-shot read, and is the one exception this
///   module takes to "every read is a live subscription". An activity row is
///   immutable — it is the record of something that has already happened, and
///   there is no later state for a subscription to deliver. A household's year
///   of history therefore costs one query per page turn rather than one live
///   query per page, held open, for as long as the panel is up.
@DependencyClient
public struct InboxClient: Sendable {
    /// Live counts for the bell. One subscription, open while a home is.
    public var badge: @Sendable (HomeID) -> AsyncThrowingStream<InboxBadge, any Error> = { _ in .never }

    /// The newest page of a household's feed, live.
    ///
    /// `category` filters server-side through its own index — a range, not a
    /// scan over everything the household has ever done.
    public var activity: @Sendable (HomeID, ActivityCategory?) -> AsyncThrowingStream<ActivityPage, any Error> = { _, _ in .never }

    /// One page of history, fetched once. `before` is the previous page's
    /// cursor.
    public var olderActivity: @Sendable (HomeID, ActivityCategory?, Timestamp) async throws -> ActivityPage

    /// How much of each kind the feed holds, for the filter chips. Read once
    /// when the panel opens, not on every page turn.
    public var activityCategories: @Sendable (HomeID) -> AsyncThrowingStream<ActivityCategoryCounts, any Error> = { _ in .never }

    /// The published changelog, live. Not paged — see `inbox:updates`.
    public var updates: @Sendable () -> AsyncThrowingStream<[AppUpdate], any Error> = { .never }

    /// Moves this person's watermark to the newest row they were actually
    /// shown. Never moves it backwards.
    public var markActivityRead: @Sendable (HomeID, Timestamp?) async throws -> Void
    public var markUpdatesRead: @Sendable (Timestamp?) async throws -> Void

    // MARK: The admin panel

    /// Every changelog entry, drafts included. Admin-only; the server refuses
    /// anybody else, whatever the client believes about itself.
    public var allUpdates: @Sendable () -> AsyncThrowingStream<[AppUpdate], any Error> = { .never }
    public var saveUpdate: @Sendable (UpdateDraft) async throws -> AppUpdateID
    public var setUpdatePublished: @Sendable (AppUpdateID, Bool) async throws -> Void
    public var removeUpdate: @Sendable (AppUpdateID) async throws -> Void

    // MARK: Is there a newer build?

    /// What the newest version is, from the App Store and from the changelog.
    ///
    /// An action rather than a subscription, and a button rather than a poll:
    /// the answer changes when a build is approved, which is a handful of times
    /// a year, and an app that watches it live would hold a socket open for a
    /// string that does not move. The server caches the App Store's answer for
    /// six hours on top of that.
    public var latestRelease: @Sendable () async throws -> ReleaseCheck
}

/// What the two places that know about versions currently say.
///
/// The comparison is not in here on purpose. The server reports the facts —
/// what the store serves, what the changelog has notes for — and the *client*
/// decides what they mean for the build it happens to be, which is the same
/// division that makes a release note say "coming soon" on an older phone.
public struct ReleaseCheck: Decodable, Equatable, Sendable {
    /// What the App Store will actually hand somebody who taps Update. `nil`
    /// when the app is not published yet, which is a state and not a failure.
    public var storeVersion: String?
    public var storeURL: URL?
    /// The newest version this deployment has release notes for. Runs *ahead*
    /// of the store — notes go live when the work lands, while the build is
    /// still in review — which is what lets the app say "there is something
    /// coming" rather than only "you are up to date".
    public var changelogVersion: String?
    public var checkedAt: Timestamp

    enum CodingKeys: String, CodingKey {
        case storeVersion, storeUrl, changelogVersion, checkedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        storeVersion = try c.decodeIfPresent(String.self, forKey: .storeVersion)
        // Lenient, like every other URL in this app: an address the phone
        // cannot parse degrades this one field rather than throwing.
        storeURL = (try? c.decodeIfPresent(String.self, forKey: .storeUrl))
            .flatMap { $0.flatMap(URL.init(string:)) }
        changelogVersion = try c.decodeIfPresent(String.self, forKey: .changelogVersion)
        checkedAt = try c.decodeIfPresent(Timestamp.self, forKey: .checkedAt) ?? Timestamp(.now)
    }

    public init(
        storeVersion: String? = nil,
        storeURL: URL? = nil,
        changelogVersion: String? = nil,
        checkedAt: Timestamp = Timestamp(.now)
    ) {
        self.storeVersion = storeVersion
        self.storeURL = storeURL
        self.changelogVersion = changelogVersion
        self.checkedAt = checkedAt
    }
}

extension InboxClient: DependencyKey {
    public static let liveValue = InboxClient(
        badge: { homeID in
            ConvexConnection.shared.subscribe(
                to: "inbox:badge", args: ["homeId": homeID], as: InboxBadge.self
            )
        },

        activity: { homeID, category in
            ConvexConnection.shared.subscribe(
                to: "inbox:activity",
                args: [
                    "homeId": homeID,
                    // Absent rather than null for "everything": the server
                    // branches on which index to read, and an explicit null is
                    // not the same statement as an omitted argument.
                    "category": category?.rawValue,
                ],
                as: ActivityPage.self
            )
        },

        olderActivity: { homeID, category, before in
            try await ConvexConnection.shared.first(
                "inbox:activity",
                args: [
                    "homeId": homeID,
                    "category": category?.rawValue,
                    "before": before.milliseconds,
                ],
                as: ActivityPage.self
            )
        },

        activityCategories: { homeID in
            ConvexConnection.shared.subscribe(
                to: "inbox:activityCategories",
                args: ["homeId": homeID],
                as: ActivityCategoryCounts.self
            )
        },

        updates: {
            ConvexConnection.shared.subscribe(
                to: "inbox:updates", args: [:], as: [AppUpdate].self
            )
        },

        markActivityRead: { homeID, at in
            var args: [String: ConvexEncodable?] = ["homeId": homeID]
            // The newest row the panel actually displayed, not `now`. A panel
            // opened on a page that is a minute stale must not mark read what
            // it never showed.
            if let at { args["at"] = at.milliseconds }
            try await ConvexConnection.shared.mutate("inbox:markActivityRead", args: args)
        },

        markUpdatesRead: { at in
            var args: [String: ConvexEncodable?] = [:]
            if let at { args["at"] = at.milliseconds }
            try await ConvexConnection.shared.mutate("inbox:markUpdatesRead", args: args)
        },

        allUpdates: {
            ConvexConnection.shared.subscribe(
                to: "inbox:allUpdates", args: [:], as: [AppUpdate].self
            )
        },

        saveUpdate: { draft in
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                throw AppError.validation(String(localized: L10n.inboxAdminErrorTitle))
            }
            let body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else {
                throw AppError.validation(String(localized: L10n.inboxAdminErrorBody))
            }

            var args: [String: ConvexEncodable?] = [
                "kind": draft.kind.rawValue,
                "title": title,
                "body": body,
                "pinned": draft.isPinned,
                "publish": draft.publish,
            ]
            if let id = draft.id { args["id"] = id }

            let version = draft.version.trimmingCharacters(in: .whitespacesAndNewlines)
            if !version.isEmpty { args["version"] = version }

            let highlights = draft.highlights
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !highlights.isEmpty {
                // `[String]` is not `ConvexEncodable` — only `[ConvexEncodable?]`
                // is — so the array has to be widened element by element.
                args["highlights"] = highlights.map { $0 as ConvexEncodable? }
            }

            return try await ConvexConnection.shared.mutate(
                "inbox:saveUpdate", args: args, as: AppUpdateID.self
            )
        },

        setUpdatePublished: { id, published in
            try await ConvexConnection.shared.mutate(
                "inbox:setUpdatePublished", args: ["id": id, "published": published]
            )
        },

        removeUpdate: { id in
            try await ConvexConnection.shared.mutate("inbox:removeUpdate", args: ["id": id])
        },

        latestRelease: {
            try await ConvexConnection.shared.act(
                "inbox:latestRelease", as: ReleaseCheck.self
            )
        }
    )

    public static let testValue = InboxClient()
}

extension DependencyValues {
    public var inbox: InboxClient {
        get { self[InboxClient.self] }
        set { self[InboxClient.self] = newValue }
    }
}
