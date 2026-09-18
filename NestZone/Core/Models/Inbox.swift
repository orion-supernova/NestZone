import Foundation
import SwiftUI

/// What the bell in the corner knows about.
///
/// Two feeds that share a button and nothing else. `HomeActivity` is what the
/// household did — the durable half of every push this app has ever sent.
/// `AppUpdate` is what the app did: a release note, written by hand, never
/// pushed. See `backend/convex/inbox.ts` for why those are two tables.

// MARK: - The badge

/// Everything the bell needs, in one payload.
///
/// One value rather than four, for the reason `IssueBoard` is one value: a
/// count and the list it sits over have to come from the same read, or a badge
/// saying "3" ends up over four rows. It also carries the watermarks, because
/// the panel marks the feed read the moment it opens and still has to draw the
/// "new" marks against what it opened *with* — otherwise the row you came to
/// read stops looking new while you are reading it.
public struct InboxBadge: Codable, Equatable, Sendable {
    /// Unread household activity, capped at `cap`.
    public var activity: Int
    /// Unread published release notes, capped at `cap`.
    public var updates: Int
    /// The newest unread category, so the bell can say what kind of thing is
    /// waiting before it is opened.
    public var latestCategory: ActivityCategory?
    /// How far this person has read their household's feed. `nil` before they
    /// ever have.
    public var activityReadAt: Timestamp?
    public var updatesReadAt: Timestamp?
    /// Whether this account may write the changelog. Server's answer, not the
    /// client's guess — it decides whether the Admin button is drawn, and
    /// every write behind it is checked again on the server.
    public var isAdmin: Bool
    /// Where the server stopped counting, so "99+" is never hardcoded here.
    public var cap: Int
    /// How far back the server was willing to count.
    ///
    /// The fallback watermark for somebody who has never opened the panel. It
    /// travels with the counts so the "new" marks on the rows and the number on
    /// the bell are taken against the same line — a client guessing its own
    /// floor would mark every row in the household's history new while the bell
    /// said four.
    public var activityFloor: Timestamp?
    public var updatesFloor: Timestamp?

    public init(
        activity: Int = 0,
        updates: Int = 0,
        latestCategory: ActivityCategory? = nil,
        activityReadAt: Timestamp? = nil,
        updatesReadAt: Timestamp? = nil,
        isAdmin: Bool = false,
        cap: Int = 99,
        activityFloor: Timestamp? = nil,
        updatesFloor: Timestamp? = nil
    ) {
        self.activity = activity
        self.updates = updates
        self.latestCategory = latestCategory
        self.activityReadAt = activityReadAt
        self.updatesReadAt = updatesReadAt
        self.isAdmin = isAdmin
        self.cap = cap
        self.activityFloor = activityFloor
        self.updatesFloor = updatesFloor
    }

    enum CodingKeys: String, CodingKey {
        case activity, updates, latestCategory, activityReadAt, updatesReadAt, isAdmin, cap
        case activityFloor, updatesFloor
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activity = c.decodeNumber(forKey: .activity)
        updates = c.decodeNumber(forKey: .updates)
        latestCategory = c.decodeLenientIfPresent(ActivityCategory.self, forKey: .latestCategory)
        activityReadAt = try c.decodeIfPresent(Timestamp.self, forKey: .activityReadAt)
        updatesReadAt = try c.decodeIfPresent(Timestamp.self, forKey: .updatesReadAt)
        isAdmin = ((try? c.decodeIfPresent(Bool.self, forKey: .isAdmin)) ?? nil) ?? false
        cap = c.decodeNumber(forKey: .cap, default: 99)
        activityFloor = try c.decodeIfPresent(Timestamp.self, forKey: .activityFloor)
        updatesFloor = try c.decodeIfPresent(Timestamp.self, forKey: .updatesFloor)
    }

    /// The line each feed's "new" marks are drawn against.
    ///
    /// The watermark when there is one; the server's counting floor when there
    /// is not. Never `nil` in practice, and when it is — a payload from a
    /// server too old to send a floor — everything reads as new, which errs
    /// towards showing somebody a mark they have already seen rather than
    /// hiding one they have not.
    public var activityBaseline: Timestamp? { activityReadAt ?? activityFloor }
    public var updatesBaseline: Timestamp? { updatesReadAt ?? updatesFloor }

    /// Everything waiting, across both feeds.
    public var total: Int { activity + updates }

    public var hasUnread: Bool { total > 0 }

    /// What the pip says. One number, and a "+" when the server stopped
    /// counting rather than a figure nobody can read in a 20-point capsule.
    public var pipText: String {
        total > cap ? "\(cap)+" : "\(total)"
    }
}

// MARK: - Household activity

/// One thing that happened in a household.
///
/// Immutable by construction: it is the record of something that has already
/// happened, which is what lets the panel subscribe to the newest page and
/// fetch everything older exactly once.
public struct HomeActivity: Codable, Identifiable, Hashable, Sendable {
    public let id: ActivityID
    /// Which part of the app it came from. Decoded leniently — the server
    /// stores this as a free string so that a module added tomorrow cannot
    /// break the *recording* of its own notification.
    public var category: ActivityCategory
    public var title: String
    public var body: String
    /// Who did it. `nil` for something the app noticed by itself — a nightly
    /// sweep finding an overdue bill.
    public var actor: UserID?
    /// Their name as it stood at the time. Denormalised server-side so a page
    /// of thirty rows is one read and not thirty-one.
    ///
    /// No photo travels with it, and none needs to: `Avatar(initials:seed:)`
    /// resolves the face from `AvatarDirectory` off the user id.
    public var actorName: String?
    public var created: Timestamp

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case category, title, body, actor, created
        case actorName = "actor_name"
    }

    public init(
        id: ActivityID,
        category: ActivityCategory,
        title: String,
        body: String,
        actor: UserID? = nil,
        actorName: String? = nil,
        created: Timestamp
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.body = body
        self.actor = actor
        self.actorName = actorName
        self.created = created
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ActivityID.self, forKey: .id)
        category = c.decodeLenient(ActivityCategory.self, forKey: .category, default: .other)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        actor = try c.decodeIfPresent(UserID.self, forKey: .actor)
        actorName = try c.decodeIfPresent(String.self, forKey: .actorName)
        created = try c.decode(Timestamp.self, forKey: .created)
    }

    /// Whether this arrived after the panel was last opened.
    ///
    /// Measured against the watermark the panel *opened* with rather than the
    /// live one, which is what keeps a row looking new while it is being read.
    public func isNew(since watermark: Timestamp?) -> Bool {
        guard let watermark else { return true }
        return created > watermark
    }
}

/// Which part of the app a notification came from.
///
/// The same vocabulary `push` routes a tap by, which is why this is also what
/// decides where tapping a row in the panel goes. `.other` is the lenient
/// fallback: a category added server-side degrades to a plain row rather than
/// throwing and blanking the feed.
public enum ActivityCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case tasks, shopping, finance, calendar, issues, notes
    case messages, movies, meals, recipes, polls, home
    case other

    public var symbol: String {
        switch self {
        case .tasks: "checkmark.circle.fill"
        case .shopping: "cart.fill"
        case .finance: "creditcard.fill"
        case .calendar: "calendar"
        case .issues: "wrench.and.screwdriver.fill"
        case .notes: "note.text"
        case .messages: "bubble.left.and.bubble.right.fill"
        case .movies: "film.fill"
        case .meals: "fork.knife"
        case .recipes: "book.closed.fill"
        case .polls: "chart.bar.fill"
        case .home: "house.fill"
        case .other: "bell.fill"
        }
    }

    /// The colour the glyph is drawn in.
    ///
    /// Reuses the Home tab's tile hues wherever a category has one, so the same
    /// subject is the same colour in both places — a household learns to find
    /// shopping by its green, and a feed that disagreed would undo that. Fixed
    /// constants from `Palette`, never built in a `body`.
    public var tint: Color {
        switch self {
        case .tasks: Palette.statTasks
        case .shopping: Palette.statShopping
        case .notes: Palette.statNotes
        case .messages: Palette.statMessages
        case .calendar: Palette.statEvents
        case .issues: Palette.statIssues
        case .finance: Palette.spendRent
        case .movies: Palette.eventScreen
        case .meals: Palette.eventFood
        case .recipes: Palette.spendDining
        case .polls: Palette.cyan
        case .home: Palette.eventPeople
        case .other: Palette.spendOther
        }
    }

    public var label: LocalizedStringResource {
        switch self {
        case .tasks: L10n.inboxCategoryTasks
        case .shopping: L10n.inboxCategoryShopping
        case .finance: L10n.inboxCategoryFinance
        case .calendar: L10n.inboxCategoryCalendar
        case .issues: L10n.inboxCategoryIssues
        case .notes: L10n.inboxCategoryNotes
        case .messages: L10n.inboxCategoryMessages
        case .movies: L10n.inboxCategoryMovies
        case .meals: L10n.inboxCategoryMeals
        case .recipes: L10n.inboxCategoryRecipes
        case .polls: L10n.inboxCategoryPolls
        case .home: L10n.inboxCategoryHome
        case .other: L10n.inboxCategoryOther
        }
    }

    /// Whether tapping a row of this kind goes anywhere.
    ///
    /// `.other` is the only one that does not, because by definition this build
    /// does not know what it is. A row that looks tappable and is not is worse
    /// than one that plainly is not.
    public var isRoutable: Bool { self != .other }
}

/// One page of a household's feed, with the cursor for the next one.
public struct ActivityPage: Codable, Equatable, Sendable {
    public var rows: [HomeActivity]
    /// `created` of the oldest row examined. Feed the next page this as
    /// `before`. `nil` when there was nothing to read.
    public var cursor: Timestamp?
    public var hasMore: Bool
    /// How long the server keeps a household's log, so the screen can state the
    /// rule it is obeying rather than printing a number that can drift from it.
    public var retentionDays: Int

    public init(
        rows: [HomeActivity] = [],
        cursor: Timestamp? = nil,
        hasMore: Bool = false,
        retentionDays: Int = 90
    ) {
        self.rows = rows
        self.cursor = cursor
        self.hasMore = hasMore
        self.retentionDays = retentionDays
    }

    enum CodingKeys: String, CodingKey { case rows, cursor, hasMore, retentionDays }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rows = try c.decodeIfPresent([HomeActivity].self, forKey: .rows) ?? []
        cursor = try c.decodeIfPresent(Timestamp.self, forKey: .cursor)
        hasMore = ((try? c.decodeIfPresent(Bool.self, forKey: .hasMore)) ?? nil) ?? false
        retentionDays = c.decodeNumber(forKey: .retentionDays, default: 90)
    }
}

/// How much of each kind a household's feed holds, for the filter chips.
///
/// Its own read, because it is answered once when the panel opens while the
/// feed itself is re-read on every filter change and every scroll.
// `Decodable` rather than `Codable`: nothing ever sends this back, and its
// coding keys deliberately do not match its members — the wire carries a list
// of rows and this holds a dictionary keyed by a lenient enum.
public struct ActivityCategoryCounts: Decodable, Equatable, Sendable {
    public var total: Int
    public var counts: [ActivityCategory: Int]

    public init(total: Int = 0, counts: [ActivityCategory: Int] = [:]) {
        self.total = total
        self.counts = counts
    }

    enum CodingKeys: String, CodingKey { case total, categories }

    private struct Row: Decodable {
        let category: String
        let count: Int

        enum CodingKeys: String, CodingKey { case category, count }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            category = try c.decodeIfPresent(String.self, forKey: .category) ?? "other"
            count = c.decodeNumber(forKey: .count)
        }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = c.decodeNumber(forKey: .total)
        let rows = try c.decodeIfPresent([Row].self, forKey: .categories) ?? []
        // A category this build does not recognise gets **no chip**, rather
        // than being folded into `.other`.
        //
        // Folding looks kinder and is a lie. A chip is a filter, the filter is
        // sent back to the server as a category string, and `other` there means
        // rows literally stored as `"other"` — not "everything this build has
        // no name for". So a chip counting five rows from a module added
        // server-side would open on none of them, which is the one thing a
        // count over a list may never do.
        //
        // They are not lost: `All` has no category argument at all, so it
        // returns them like anything else. An unnamed chip is worse than no
        // chip; a chip that lies is worse than both.
        counts = rows.reduce(into: [:]) { acc, row in
            guard let key = ActivityCategory(rawValue: row.category) else { return }
            acc[key, default: 0] += row.count
        }
    }

    /// The categories that have anything in them, busiest first.
    ///
    /// Only these get a chip, for two reasons: a filter guaranteed to come back
    /// empty wastes a tap, and — see the decoder — a category this build cannot
    /// name is one it cannot filter by either.
    ///
    /// `total` is deliberately *not* the sum of these. It counts every row the
    /// caller can see, including ones in categories with no chip, because it is
    /// what `All` will actually show.
    public var present: [(category: ActivityCategory, count: Int)] {
        counts
            .map { (category: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                lhs.count == rhs.count
                    ? lhs.category.rawValue < rhs.category.rawValue
                    : lhs.count > rhs.count
            }
    }
}

// MARK: - The changelog

/// One release note.
///
/// `Decodable` rather than `Codable`: nothing ever sends one of these back —
/// writes go through `UpdateDraft`, which is a different shape — and its
/// `translations` arrive as an array and are held as a dictionary, so a
/// synthesised encoder would not round-trip anyway.
public struct AppUpdate: Decodable, Identifiable, Hashable, Sendable {
    public let id: AppUpdateID
    /// "1.4.0", or `nil` for an announcement not tied to a release.
    public var version: String?
    public var kind: UpdateKind
    public var title: String
    public var body: String
    /// Short bullets, drawn as a list under the body.
    public var highlights: [String]
    /// The same note in the app's other languages, keyed by language code.
    ///
    /// The fields above are the base text *and* the fallback. A note whose
    /// Turkish was never written reads in English rather than reading as
    /// nothing, which is the only sensible failure for a changelog — see
    /// `text(for:)`.
    public var translations: [String: LocalizedUpdate]
    /// Floats to the top of the feed.
    public var isPinned: Bool
    /// `nil` while it is a draft — which is the only state in which anybody but
    /// its author can fail to see it.
    public var publishedAt: Timestamp?
    public var created: Timestamp
    public var updated: Timestamp?

    public var isDraft: Bool { publishedAt == nil }

    /// The date to show. A draft has no publication date, so it shows when it
    /// was written; only its author ever sees one.
    public var displayDate: Timestamp { publishedAt ?? created }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case version, kind, title, body, highlights, translations, created, updated
        case isPinned = "pinned"
        case publishedAt = "published_at"
    }

    public init(
        id: AppUpdateID,
        version: String? = nil,
        kind: UpdateKind = .announcement,
        title: String,
        body: String,
        highlights: [String] = [],
        translations: [String: LocalizedUpdate] = [:],
        isPinned: Bool = false,
        publishedAt: Timestamp? = nil,
        created: Timestamp,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.version = version
        self.kind = kind
        self.title = title
        self.body = body
        self.highlights = highlights
        self.translations = translations
        self.isPinned = isPinned
        self.publishedAt = publishedAt
        self.created = created
        self.updated = updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(AppUpdateID.self, forKey: .id)
        version = try c.decodeIfPresent(String.self, forKey: .version)
        kind = c.decodeLenient(UpdateKind.self, forKey: .kind, default: .announcement)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        highlights = try c.decodeIfPresent([String].self, forKey: .highlights) ?? []
        // An array on the wire so the language is a validated field like any
        // other; a dictionary here because every read of it is a lookup by code.
        let rows = ((try? c.decodeIfPresent([LocalizedUpdate.Row].self, forKey: .translations)) ?? nil) ?? []
        translations = rows.reduce(into: [:]) { acc, row in
            let code = row.language.lowercased()
            guard !code.isEmpty else { return }
            acc[code] = LocalizedUpdate(
                title: row.title, body: row.body, highlights: row.highlights
            )
        }
        isPinned = ((try? c.decodeIfPresent(Bool.self, forKey: .isPinned)) ?? nil) ?? false
        publishedAt = try c.decodeIfPresent(Timestamp.self, forKey: .publishedAt)
        created = try c.decode(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    /// The note as this reader should see it.
    ///
    /// The base text is the fallback, and it is a real fallback rather than a
    /// placeholder: an untranslated note reads in English, which somebody can
    /// at least act on, where an empty card is a bug with rounded corners.
    ///
    /// Matched on the language code alone, so `tr-TR` and `tr` find the same
    /// entry — a household's phone is rarely set to the bare code. Defaults to
    /// `L10n.locale` rather than the system's, because this app has its own
    /// language picker and the changelog has to follow the same one every other
    /// string in the app does.
    public func text(for locale: Locale = L10n.locale) -> LocalizedUpdate {
        let base = LocalizedUpdate(title: title, body: body, highlights: highlights)
        guard let code = locale.language.languageCode?.identifier.lowercased() else {
            return base
        }
        return translations[code] ?? base
    }

    /// Whether this was published after the panel was last opened.
    public func isNew(since watermark: Timestamp?) -> Bool {
        guard let published = publishedAt else { return false }
        guard let watermark else { return true }
        return published > watermark
    }
}

/// One release note's words, in one language.
public struct LocalizedUpdate: Equatable, Hashable, Sendable {
    public var title: String
    public var body: String
    public var highlights: [String]

    public init(title: String, body: String, highlights: [String] = []) {
        self.title = title
        self.body = body
        self.highlights = highlights
    }

    public var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// How one arrives: an array element carrying its own language code.
    struct Row: Decodable {
        let language: String
        let title: String
        let body: String
        let highlights: [String]

        enum CodingKeys: String, CodingKey { case language, title, body, highlights }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            language = try c.decodeIfPresent(String.self, forKey: .language) ?? ""
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
            highlights = try c.decodeIfPresent([String].self, forKey: .highlights) ?? []
        }
    }
}

/// What a release note *is*.
///
/// Four, because a changelog people read is one where every entry is obviously
/// one of "you can now do a thing", "a thing you do got better", "a thing that
/// was broken isn't", and "something we want to tell you".
public enum UpdateKind: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case feature, improvement, fix, announcement

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .feature: "sparkles"
        case .improvement: "wand.and.stars"
        case .fix: "bandage.fill"
        case .announcement: "megaphone.fill"
        }
    }

    /// Fixed constants, and far enough apart to be told apart on a chip the
    /// size of a word.
    public var tint: Color {
        switch self {
        case .feature: Palette.violet
        case .improvement: Palette.cyan
        case .fix: Palette.emerald
        case .announcement: Palette.amber
        }
    }

    public var label: LocalizedStringResource {
        switch self {
        case .feature: L10n.inboxKindFeature
        case .improvement: L10n.inboxKindImprovement
        case .fix: L10n.inboxKindFix
        case .announcement: L10n.inboxKindAnnouncement
        }
    }
}

/// What the admin panel sends when it saves a release note.
///
/// One shape for both a new entry and an edit — `id` absent is a new one —
/// because the panel is one form for both and two argument lists would have to
/// be kept identical by hand.
public struct UpdateDraft: Equatable, Sendable {
    public var id: AppUpdateID?
    public var version: String
    public var kind: UpdateKind
    public var title: String
    public var body: String
    public var highlights: [String]
    /// The other languages, keyed by code. Half-written ones — a title with no
    /// body, or the reverse — are dropped by the server rather than stored, so
    /// the reader falls back to a complete English note instead of reading a
    /// heading with nothing under it.
    public var translations: [String: LocalizedUpdate]
    public var isPinned: Bool
    /// Explicit on every save rather than inherited, because "leave it alone"
    /// is precisely the wrong default for the flag that decides whether a
    /// half-written note is on everybody's phone.
    public var publish: Bool

    public init(
        id: AppUpdateID? = nil,
        version: String = "",
        kind: UpdateKind = .feature,
        title: String = "",
        body: String = "",
        highlights: [String] = [],
        translations: [String: LocalizedUpdate] = [:],
        isPinned: Bool = false,
        publish: Bool = false
    ) {
        self.id = id
        self.version = version
        self.kind = kind
        self.title = title
        self.body = body
        self.highlights = highlights
        self.translations = translations
        self.isPinned = isPinned
        self.publish = publish
    }

    /// Seeds the form from an entry being edited.
    public init(editing update: AppUpdate) {
        self.init(
            id: update.id,
            version: update.version ?? "",
            kind: update.kind,
            title: update.title,
            body: update.body,
            highlights: update.highlights,
            translations: update.translations,
            isPinned: update.isPinned,
            publish: !update.isDraft
        )
    }

    public var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The same draft, headed for the shelf or for everybody's phone.
    ///
    /// A copy rather than a mutation because the value is about to cross into
    /// an effect, and a captured `var` cannot.
    public func publishing(_ publish: Bool) -> UpdateDraft {
        var copy = self
        copy.publish = publish
        return copy
    }
}
