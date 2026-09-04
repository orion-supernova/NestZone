import Foundation

/// The Home tab's summary numbers.
///
/// These used to be computed on-device by downloading three entire collections
/// (`shopping:listByHome`, `notes:listByHome`, `tasks:listByHome`) and filtering
/// them by date in Swift — every time the tab appeared. The server computes them
/// now and sends this instead; see `convex/stats.ts`.
public struct HomeStats: Codable, Hashable, Sendable {
    public var openTasks: Int
    public var completedTasks: Int
    public var urgentTasks: Int
    public var shoppingItems: Int
    public var notes: Int
    public var unreadMessages: Int

    /// Change against the previous 7-day window, for the trend chips.
    public var completedTasksChange: Int
    public var shoppingChange: Int
    public var notesChange: Int
    public var messagesChange: Int

    public init(
        openTasks: Int = 0,
        completedTasks: Int = 0,
        urgentTasks: Int = 0,
        shoppingItems: Int = 0,
        notes: Int = 0,
        unreadMessages: Int = 0,
        completedTasksChange: Int = 0,
        shoppingChange: Int = 0,
        notesChange: Int = 0,
        messagesChange: Int = 0
    ) {
        self.openTasks = openTasks
        self.completedTasks = completedTasks
        self.urgentTasks = urgentTasks
        self.shoppingItems = shoppingItems
        self.notes = notes
        self.unreadMessages = unreadMessages
        self.completedTasksChange = completedTasksChange
        self.shoppingChange = shoppingChange
        self.notesChange = notesChange
        self.messagesChange = messagesChange
    }

    public static let empty = HomeStats()
}
