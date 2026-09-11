import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct TasksClient: Sendable {
    /// The working list, plus the rule that bounds its finished half. An
    /// envelope rather than a bare array because the screen states that rule to
    /// the person reading it, and the server owns the number.
    public var byHome: @Sendable (HomeID) -> AsyncThrowingStream<TaskList, any Error> = { _ in .never }
    /// The chores that have left the Done list — finished longer ago than the
    /// window, read from the ledger and so unaffected by anything that happens
    /// to the task rows themselves.
    public var archive: @Sendable (HomeID) -> AsyncThrowingStream<TaskArchive, any Error> = { _ in .never }
    public var create: @Sendable (NewTask) async throws -> Void
    public var setCompleted: @Sendable (TaskID, Bool) async throws -> Void
    public var update: @Sendable (TaskID, TaskEdit) async throws -> Void
    /// Open tasks only — the server refuses a finished one. See `tasks:remove`.
    public var remove: @Sendable (TaskID) async throws -> Void
    /// The deliberate one: deletes a finished chore *and* the record of it
    /// having been done, which moves the contribution split. Never called
    /// without the dialog that says so.
    public var removeFinished: @Sendable (TaskID) async throws -> Void
}

public struct NewTask: Equatable, Sendable {
    public var title: String
    public var details: String?
    public var homeID: HomeID
    public var priority: HouseTask.Priority
    public var kind: HouseTask.Kind
    public var assignedTo: UserID?
    public var dueDate: Date?

    public init(
        title: String,
        details: String? = nil,
        homeID: HomeID,
        priority: HouseTask.Priority = .medium,
        kind: HouseTask.Kind = .general,
        assignedTo: UserID? = nil,
        dueDate: Date? = nil
    ) {
        self.title = title
        self.details = details
        self.homeID = homeID
        self.priority = priority
        self.kind = kind
        self.assignedTo = assignedTo
        self.dueDate = dueDate
    }
}

/// A partial update. Only the fields set here are sent.
public struct TaskEdit: Equatable, Sendable {
    public var title: String?
    public var details: String?
    public var isCompleted: Bool?
    public var priority: HouseTask.Priority?
    public var kind: HouseTask.Kind?
    public var assignedTo: UserID?
    public var dueDate: Date?

    public init(
        title: String? = nil,
        details: String? = nil,
        isCompleted: Bool? = nil,
        priority: HouseTask.Priority? = nil,
        kind: HouseTask.Kind? = nil,
        assignedTo: UserID? = nil,
        dueDate: Date? = nil
    ) {
        self.title = title
        self.details = details
        self.isCompleted = isCompleted
        self.priority = priority
        self.kind = kind
        self.assignedTo = assignedTo
        self.dueDate = dueDate
    }

    var arguments: [String: ConvexEncodable?] {
        var args: [String: ConvexEncodable?] = [:]
        if let title { args["title"] = title }
        if let details { args["description"] = details }
        if let isCompleted { args["is_completed"] = isCompleted }
        if let priority { args["priority"] = priority.rawValue }
        if let kind { args["type"] = kind.rawValue }
        if let assignedTo { args["assigned_to"] = assignedTo }
        if let dueDate { args["due_date"] = dueDate.convexMillis }
        return args
    }
}

extension TasksClient: DependencyKey {
    public static let liveValue = TasksClient(
        byHome: { homeID in
            ConvexConnection.shared.subscribe(
                to: "tasks:listByHome", args: ["homeId": homeID], as: TaskList.self
            )
        },
        archive: { homeID in
            ConvexConnection.shared.subscribe(
                to: "tasks:archive", args: ["homeId": homeID], as: TaskArchive.self
            )
        },
        create: { task in
            let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.taskTitleEmpty",
                    defaultValue: "Give the task a title."
                ))
            }
            var args: [String: ConvexEncodable?] = [
                "title": trimmed,
                "homeId": task.homeID,
                "priority": task.priority.rawValue,
                "type": task.kind.rawValue,
            ]
            if let details = task.details, !details.isEmpty { args["description"] = details }
            if let assignee = task.assignedTo { args["assigned_to"] = assignee }
            if let due = task.dueDate { args["due_date"] = due.convexMillis }
            try await ConvexConnection.shared.mutate("tasks:create", args: args)
        },
        setCompleted: { id, isCompleted in
            try await ConvexConnection.shared.mutate(
                "tasks:update", args: ["id": id, "is_completed": isCompleted]
            )
        },
        update: { id, edit in
            var args = edit.arguments
            args["id"] = id
            try await ConvexConnection.shared.mutate("tasks:update", args: args)
        },
        remove: { id in
            try await ConvexConnection.shared.mutate("tasks:remove", args: ["id": id])
        },
        removeFinished: { id in
            try await ConvexConnection.shared.mutate("tasks:removeFinished", args: ["id": id])
        }
    )

    public static let testValue = TasksClient()
}

extension DependencyValues {
    public var tasks: TasksClient {
        get { self[TasksClient.self] }
        set { self[TasksClient.self] = newValue }
    }
}
