import Foundation

/// A chore. Named `HouseTask` rather than `Task` so it never shades
/// `_Concurrency.Task` at a call site.
public struct HouseTask: Codable, Identifiable, Hashable, Sendable {
    public let id: TaskID
    public var title: String
    public var details: String?
    public var createdBy: UserID?
    public var updatedBy: UserID?
    public var assignedTo: UserID?
    public var isCompleted: Bool
    public var image: String?
    public var homeID: HomeID?
    public var priority: Priority
    public var kind: Kind
    public var dueDate: Timestamp?
    /// Set when this chore exists because something in the house is broken.
    ///
    /// A link, not an owner, in both directions: deleting the problem leaves
    /// the chore standing (somebody still has to do it) and deleting the chore
    /// leaves the problem standing (it is still broken). What it buys is the
    /// one thing neither could say alone — finishing the chore is news on the
    /// problem's timeline.
    public var issueID: IssueID?
    public var created: Timestamp?
    public var updated: Timestamp?

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case cleaning, shopping, maintenance, general
    }

    public enum Priority: String, Codable, CaseIterable, Sendable, Comparable {
        case low, medium, high

        private var rank: Int {
            switch self {
            case .low: 0
            case .medium: 1
            case .high: 2
            }
        }

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case details = "description"
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case assignedTo = "assigned_to"
        case isCompleted = "is_completed"
        case image
        case homeID = "home_id"
        case priority
        case kind = "type"
        case dueDate = "due_date"
        case issueID = "issue_id"
        case created, updated
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(TaskID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        details = try c.decodeIfPresent(String.self, forKey: .details)
        createdBy = try c.decodeIfPresent(UserID.self, forKey: .createdBy)
        updatedBy = try c.decodeIfPresent(UserID.self, forKey: .updatedBy)
        assignedTo = try c.decodeIfPresent(UserID.self, forKey: .assignedTo)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        image = try c.decodeIfPresent(String.self, forKey: .image)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        priority = c.decodeLenient(Priority.self, forKey: .priority, default: .medium)
        kind = c.decodeLenient(Kind.self, forKey: .kind, default: .general)
        dueDate = try c.decodeIfPresent(Timestamp.self, forKey: .dueDate)
        issueID = try c.decodeIfPresent(IssueID.self, forKey: .issueID)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
    }

    public init(
        id: TaskID,
        title: String,
        details: String? = nil,
        createdBy: UserID? = nil,
        updatedBy: UserID? = nil,
        assignedTo: UserID? = nil,
        isCompleted: Bool = false,
        image: String? = nil,
        homeID: HomeID? = nil,
        priority: Priority = .medium,
        kind: Kind = .general,
        dueDate: Timestamp? = nil,
        issueID: IssueID? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.assignedTo = assignedTo
        self.isCompleted = isCompleted
        self.image = image
        self.homeID = homeID
        self.priority = priority
        self.kind = kind
        self.dueDate = dueDate
        self.issueID = issueID
        self.created = created
        self.updated = updated
    }
}

extension HouseTask {
    /// High-priority and still open — what the Home tab surfaces as "needs attention".
    public var isUrgent: Bool { priority == .high && !isCompleted }

    public var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate.date < Date()
    }
}
