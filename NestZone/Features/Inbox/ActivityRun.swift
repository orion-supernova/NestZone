import Foundation

/// One line of the timeline: a single thing somebody did, or a run of the same
/// kind of thing by the same person in a short stretch.
///
/// Six things added to the shopping list in a minute are one event in the
/// household's life, and six rows is a wall. Merging happens here, on the
/// client, over the rows already loaded, so the server's feed, its paging
/// cursor and the read watermarks stay exactly as they were.
///
/// What may merge: the same person, the same category, the same words (the
/// title once the name is taken off, so "added" never merges with "finished a
/// task"), next to each other in the feed, each within `window` of the one
/// before it. Rows are newest-first and a day section is built apart from the
/// next, so a run never crosses midnight.
///
/// Stable as pages arrive: a merge only ever looks at neighbours, an older
/// page appends below the rows in hand, and a run that reaches the page edge
/// simply grows downward. Its `id` is its oldest row for that reason: new
/// rows land on top, so the newest row is the one that changes.
public struct ActivityRun: Identifiable, Equatable, Sendable {
    /// Gap between two neighbours that still counts as one stretch.
    static let window: TimeInterval = 30 * 60

    public var id: ActivityID { rows[rows.count - 1].id }
    /// Newest first, at least one.
    public let rows: [HomeActivity]
    /// "Sam added 6 things to Shopping". `nil` for a single row.
    public let sentence: String?
    /// The names of what was done, on one line: "Milk, eggs, bread".
    public let preview: String

    public var first: HomeActivity { rows[0] }
    public var isMerged: Bool { rows.count > 1 }

    init(rows: [HomeActivity]) {
        self.rows = rows
        if rows.count > 1, let name = rows[0].shownActorName {
            sentence = Self.sentence(for: rows[0], name: name, count: rows.count)
            preview = rows.map(\.body).filter { !$0.isEmpty }.joined(separator: ", ")
        } else {
            sentence = nil
            preview = ""
        }
    }

    /// Folds newest-first rows into runs. One pass, order kept.
    static func merge(_ rows: [HomeActivity]) -> [ActivityRun] {
        var runs: [ActivityRun] = []
        var bucket: [HomeActivity] = []

        func flush() {
            guard !bucket.isEmpty else { return }
            runs.append(ActivityRun(rows: bucket))
            bucket = []
        }

        for row in rows {
            if let last = bucket.last, !canJoin(row, after: last) { flush() }
            bucket.append(row)
        }
        flush()
        return runs
    }

    private static func canJoin(_ older: HomeActivity, after newer: HomeActivity) -> Bool {
        guard let actor = older.actor, actor == newer.actor,
              older.category == newer.category,
              older.phrase == newer.phrase,
              older.shownActorName != nil
        else { return false }
        return newer.created.date.timeIntervalSince(older.created.date) <= window
    }

    /// The sentence for the stretch. The few things the server says in
    /// English are rebuilt in the app's language; anything else gets the plain
    /// count, so a new kind of row merges honestly rather than wrongly.
    private static func sentence(for row: HomeActivity, name: String, count: Int) -> String {
        let phrase = row.phrase.lowercased()
        let resource: LocalizedStringResource = switch (row.category, phrase) {
        case (.shopping, "added"): L10n.inboxRunShoppingAdded(name, count)
        case (.tasks, "added a task"): L10n.inboxRunTasksAdded(name, count)
        case (.tasks, "finished a task"): L10n.inboxRunTasksDone(name, count)
        case (.calendar, "added an event"): L10n.inboxRunCalendarAdded(name, count)
        case (.movies, "added a film"): L10n.inboxRunMoviesAdded(name, count)
        case (.recipes, "added a recipe"): L10n.inboxRunRecipesAdded(name, count)
        case (.notes, "left a note"): L10n.inboxRunNotesLeft(name, count)
        case (.messages, ""): L10n.inboxRunMessages(name, count)
        default: L10n.inboxRunGeneric(name, count, String(localized: row.category.label))
        }
        return String(localized: resource)
    }
}

extension HomeActivity {
    /// Who did it, as this person should see them (the screenshot persona
    /// stands in for a real name), or `nil` when the app did it itself.
    var shownActorName: String? {
        guard let actor else { return nil }
        let name = StoreDemo.personaName(for: actor) ?? actorName
        return (name?.isEmpty == false) ? name : nil
    }

    /// The title with the person's name taken off the front: the server
    /// writes "Sam added", and "added" is what two rows have in common.
    var phrase: String {
        guard let name = actorName, !name.isEmpty, title.hasPrefix(name) else { return title }
        return String(title.dropFirst(name.count)).trimmingCharacters(in: .whitespaces)
    }
}
