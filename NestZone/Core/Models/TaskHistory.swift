import Foundation

/// The household's working task list, and the rule that bounds it.
///
/// `tasks:listByHome` returns both because the Tasks screen says the rule out
/// loud — "finished chores stay here for 30 days" — and a screen that states a
/// number the server does not agree with is worse than one that says nothing.
/// The window lives on the server; this carries it to the sentence.
public struct TaskList: Codable, Hashable, Sendable {
    public var tasks: [HouseTask]
    /// How long a finished chore stays on the Done list before it moves to
    /// History. Nothing is lost when one rolls off — see `TaskCompletion`.
    public var doneWindowDays: Int

    public init(tasks: [HouseTask] = [], doneWindowDays: Int = 30) {
        self.tasks = tasks
        self.doneWindowDays = doneWindowDays
    }

    public static let empty = TaskList()
}

/// One chore, finished, as the household's permanent record of it.
///
/// Deliberately not a `HouseTask`. A task is current state — it can be renamed,
/// reopened, archived and deleted — and this is history, which none of those
/// may rewrite. The distinction is the whole reason `task_completions` exists
/// on the server: the contribution split used to be tallied from the task rows
/// themselves, so deleting a finished chore quietly took somebody's credit for
/// it away with it.
public struct TaskCompletion: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let taskID: TaskID
    /// What the chore was called when it was finished.
    public var title: String
    public var kind: HouseTask.Kind
    public var completedAt: Timestamp
    /// Who it counts for. `nil` for work finished by somebody who has since
    /// left the home, or imported without an author — kept visible rather than
    /// dropped, so the shares still add up to the total.
    public var userID: UserID?
    public var name: String?
    public var email: String?
    /// Whether the chore behind this was put away early.
    public var isArchived: Bool
    /// Whether putting it back would actually return it to the Done list. False
    /// once the completion is older than the Done window, where restoring it
    /// would be a button that appears to do nothing.
    public var canRestore: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case taskID = "taskId"
        case title
        case kind = "type"
        case completedAt
        case userID = "userId"
        case name, email, isArchived, canRestore
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        taskID = try c.decode(TaskID.self, forKey: .taskID)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        kind = c.decodeLenient(HouseTask.Kind.self, forKey: .kind, default: .general)
        completedAt = try c.decode(Timestamp.self, forKey: .completedAt)
        userID = try c.decodeIfPresent(UserID.self, forKey: .userID)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        canRestore = try c.decodeIfPresent(Bool.self, forKey: .canRestore) ?? false
    }

    public init(
        id: String,
        taskID: TaskID,
        title: String,
        kind: HouseTask.Kind = .general,
        completedAt: Timestamp,
        userID: UserID? = nil,
        name: String? = nil,
        email: String? = nil,
        isArchived: Bool = false,
        canRestore: Bool = false
    ) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.kind = kind
        self.completedAt = completedAt
        self.userID = userID
        self.name = name
        self.email = email
        self.isArchived = isArchived
        self.canRestore = canRestore
    }
}

extension TaskCompletion {
    /// Same fallback chain as `User.displayName`, so a name reads the same here
    /// as it does on the leaderboard.
    public var displayName: String? {
        userID == nil ? nil : User.displayName(name: name, email: email)
    }

    public var initials: String? { displayName.map(User.initials(from:)) }
}

/// A page of the household's record of finished work.
public struct TaskHistory: Codable, Hashable, Sendable {
    public var entries: [TaskCompletion]
    /// How many rows the server was willing to return.
    public var limit: Int
    /// Whether that ceiling was reached, so the screen can say it is showing
    /// the most recent rather than implying it is showing everything.
    public var isTruncated: Bool

    public init(entries: [TaskCompletion] = [], limit: Int = 200, isTruncated: Bool = false) {
        self.entries = entries
        self.limit = limit
        self.isTruncated = isTruncated
    }

    public static let empty = TaskHistory()
}
