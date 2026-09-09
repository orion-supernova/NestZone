import Foundation

/// The Home tab's summary numbers.
///
/// These used to be computed on-device by downloading three entire collections
/// (`shopping:listByHome`, `notes:listByHome`, `tasks:listByHome`) and filtering
/// them by date in Swift — every time the tab appeared. The server computes them
/// now and sends this instead; see `convex/stats.ts`.
///
/// Every field here is displayed. `completedTasks`, `urgentTasks` and
/// `completedTasksChange` used to sit in this struct too, unread by anything
/// since the Home tab dropped the "Tasks Done" and "Issues" tiles — and the
/// server went on collecting the household's entire tasks table on every launch
/// to fill them in. A number nobody shows is not free.
public struct HomeStats: Codable, Hashable, Sendable {
    public var openTasks: Int
    public var shoppingItems: Int
    public var notes: Int
    public var unreadMessages: Int
    /// What is still broken about the house.
    ///
    /// Not the counter that used to sit here under this name: that one was a
    /// high-priority *task* count, and it read 0 in any household that never
    /// set a priority. This comes from its own table and its own index, and it
    /// falls when somebody fixes something.
    public var openIssues: Int
    /// How many of those are urgent or already past their date — the half that
    /// decides whether the tile is worth shouting about.
    public var urgentIssues: Int

    /// Change against the previous 7-day window, for the trend chips.
    public var shoppingChange: Int
    public var notesChange: Int
    public var messagesChange: Int
    public var issuesChange: Int

    public init(
        openTasks: Int = 0,
        shoppingItems: Int = 0,
        notes: Int = 0,
        unreadMessages: Int = 0,
        openIssues: Int = 0,
        urgentIssues: Int = 0,
        shoppingChange: Int = 0,
        notesChange: Int = 0,
        messagesChange: Int = 0,
        issuesChange: Int = 0
    ) {
        self.openTasks = openTasks
        self.shoppingItems = shoppingItems
        self.notes = notes
        self.unreadMessages = unreadMessages
        self.openIssues = openIssues
        self.urgentIssues = urgentIssues
        self.shoppingChange = shoppingChange
        self.notesChange = notesChange
        self.messagesChange = messagesChange
        self.issuesChange = issuesChange
    }

    enum CodingKeys: String, CodingKey {
        case openTasks, shoppingItems, notes, unreadMessages
        case openIssues, urgentIssues
        case shoppingChange, notesChange, messagesChange, issuesChange
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Defaulted one field at a time rather than by synthesised decoding: a
        // phone updated before its deployment is answered by a server that has
        // never heard of these counters, and a dashboard that throws rather
        // than reading zero would take the whole Home tab down over a tile.
        openTasks = c.decodeNumber(forKey: .openTasks)
        shoppingItems = c.decodeNumber(forKey: .shoppingItems)
        notes = c.decodeNumber(forKey: .notes)
        unreadMessages = c.decodeNumber(forKey: .unreadMessages)
        openIssues = c.decodeNumber(forKey: .openIssues)
        urgentIssues = c.decodeNumber(forKey: .urgentIssues)
        shoppingChange = c.decodeNumber(forKey: .shoppingChange)
        notesChange = c.decodeNumber(forKey: .notesChange)
        messagesChange = c.decodeNumber(forKey: .messagesChange)
        issuesChange = c.decodeNumber(forKey: .issuesChange)
    }

    public static let empty = HomeStats()
}
