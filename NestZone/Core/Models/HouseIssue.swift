import Foundation

// House problems: everything in a shared home that is broken, and what the
// household is doing about it.
//
// Deliberately not a second `HouseTask`. A chore is a thing to *do* and it is
// finished the moment somebody does it; a problem is a thing that is *wrong*. It
// outlives attempts to fix it, it costs money, it needs parts, somebody has to
// be called, and the same one comes back next winter. So it carries its own
// state machine and its own history, and links out to the modules that already
// own the work — the task list, the calendar, the shopping list, the ledger.
//
// Presentation (colour, symbol, title) lives in `Design`, the same way a
// spending category's does: which colour stands for "urgent" is a design
// decision, and `Core` should not import SwiftUI to hold a broken tap.

// MARK: - Vocabulary

/// How far along a problem is.
///
/// The order of the cases is the order the stepper draws them in, and
/// `rank` — not the case order — is what sorting and progress are measured
/// against, because two of them share a rank.
public enum IssueStatus: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    /// Somebody has said it is broken. Nothing has happened yet.
    case reported
    /// The household has seen it and agrees it is real.
    case acknowledged
    /// Somebody is coming, or a date is set.
    case scheduled
    /// Being worked on now.
    case inProgress
    /// Stuck on something outside the house — a part, a landlord, a quote.
    case blocked
    /// Fixed.
    case fixed
    /// Decided against: the wobbly shelf everyone has made peace with.
    case wontFix

    public var id: String { rawValue }

    /// Whether a problem in this state is still outstanding.
    ///
    /// The client's copy of `issues.is_open`, which the server maintains and
    /// indexes. Derived here rather than decoded so a row this build has not
    /// seen the status of still lands on the right side of the line.
    public var isOpen: Bool { self != .fixed && self != .wontFix }

    /// How far along, for sorting and for the progress the stepper shows.
    ///
    /// `blocked` shares a rank with `inProgress` on purpose: waiting on a part
    /// is not progress, but it is not a step backwards either, and a household
    /// that sees "blocked" sort below "reported" reads it as the problem having
    /// been forgotten about.
    public var rank: Int {
        switch self {
        case .reported: 0
        case .acknowledged: 1
        case .scheduled: 2
        case .inProgress, .blocked: 3
        case .fixed, .wontFix: 4
        }
    }

    /// The four rungs the detail screen draws as a track. `blocked` and
    /// `wontFix` are deliberately off it — they are places a problem can end up,
    /// not steps on the way somewhere.
    public static let ladder: [IssueStatus] = [
        .reported, .acknowledged, .scheduled, .inProgress, .fixed,
    ]

    /// The next rung up, for the one-tap "move it along" control. `nil` once
    /// there is nowhere further to go.
    public var next: IssueStatus? {
        switch self {
        case .reported: .acknowledged
        case .acknowledged: .scheduled
        case .scheduled: .inProgress
        // A problem that was stuck and is moving again is being worked on, not
        // being re-scheduled: whatever it was waiting for has arrived.
        case .blocked: .inProgress
        case .inProgress: .fixed
        case .fixed, .wontFix: nil
        }
    }
}

/// How badly it matters.
///
/// Four steps, not five. The distinction a household can actually hold is
/// "annoying / needs doing / needs doing soon / do not wait"; a ten-point scale
/// is a scale nobody agrees on, and one everybody quietly stops setting.
public enum IssueSeverity: String, Codable, CaseIterable, Hashable, Sendable, Identifiable, Comparable {
    case cosmetic, minor, major, urgent

    public var id: String { rawValue }

    public var rank: Int {
        switch self {
        case .cosmetic: 0
        case .minor: 1
        case .major: 2
        case .urgent: 3
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

/// Where in the house it is.
///
/// A list rather than free text, and that is the whole reason the module can
/// ever say anything interesting: a household writes "tap drips" and "kitchen
/// tap dripping again" for the same fault, so "this is the third time the
/// kitchen plumbing has gone" is only answerable if the *where* is chosen.
public enum IssueArea: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case kitchen, bathroom, bedroom, living, hallway, laundry
    case garage, garden, balcony, basement, roof, exterior
    case whole, other

    public var id: String { rawValue }

    /// The two shelves of the room picker: inside, and everything else.
    public var isIndoors: Bool {
        switch self {
        case .kitchen, .bathroom, .bedroom, .living, .hallway, .laundry, .basement: true
        case .garage, .garden, .balcony, .roof, .exterior, .whole, .other: false
        }
    }

    public static var indoors: [IssueArea] { allCases.filter(\.isIndoors) }
    public static var outdoors: [IssueArea] { allCases.filter { !$0.isIndoors } }
}

/// What kind of thing is broken — which is really the question "who do you
/// call".
public enum IssueCategory: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case plumbing, electrical, heating, appliance, furniture, structural
    case internet, pest, damp, safety, cosmetic, other

    public var id: String { rawValue }

    /// Which pocket the repair comes out of, when somebody logs what it cost.
    ///
    /// The ledger has its own vocabulary and this maps onto it rather than
    /// adding an eleventh category to it: a plumber is a household cost, and a
    /// budget for "household" that quietly did not count plumbers would be
    /// worse than no budget at all.
    public var spendCategory: SpendCategory {
        switch self {
        case .plumbing, .electrical, .heating, .structural, .damp, .pest: .household
        case .appliance, .furniture, .cosmetic, .other: .household
        case .internet: .subscriptions
        case .safety: .health
        }
    }
}

/// What an entry on a problem's timeline is.
public enum IssueEntryKind: String, Codable, CaseIterable, Hashable, Sendable {
    /// Somebody wrote something.
    case comment
    /// The status moved. Carries both ends of the move.
    case status
    /// Something was attached — a chore, a visit, parts, a receipt.
    case link
    /// The app said something on the household's behalf.
    case system
}

// MARK: - The problem

/// One thing that is wrong with the house.
///
/// The rollups at the bottom — `partsOpen`, `spent`, `ageDays` — are computed by
/// `issues:byHome` and arrive on the row rather than being derived here. They
/// cannot be derived here: the phone does not hold the shopping list or the
/// ledger while it is looking at this screen, and downloading either to draw a
/// caption is the mistake every other module in this app was rebuilt to stop
/// making.
public struct HouseIssue: Codable, Identifiable, Hashable, Sendable {
    public let id: IssueID
    public var title: String
    public var details: String?
    public var area: IssueArea
    public var category: IssueCategory
    public var severity: IssueSeverity
    public var status: IssueStatus
    public var homeID: HomeID?

    public var reportedBy: UserID?
    public var assignedTo: UserID?

    /// When it has to be sorted out by, if anything makes it urgent.
    public var dueBy: Timestamp?
    /// Why it is stuck. Only meaningful while `status` is `.blocked`.
    public var blockedReason: String?

    public var resolvedAt: Timestamp?
    public var resolvedBy: UserID?
    /// What actually fixed it, for the next time it happens.
    public var resolution: String?

    /// What the household expects it to cost, in minor units.
    public var costEstimate: Int?
    /// ISO 4217 for `costEstimate`. Per-document, like every other amount here.
    public var currency: String?

    public var vendorName: String?
    public var vendorPhone: String?
    public var vendorURL: String?
    /// Covered until. A broken appliance is a different problem under warranty.
    public var warrantyUntil: Timestamp?

    /// Everyone who has said this is happening to them too, the reporter
    /// included. The cheapest useful signal a shared house has.
    public var meToo: [UserID]

    /// The chore made of it, if somebody made one.
    public var taskID: TaskID?
    /// The visit booked for it, if somebody booked one.
    public var eventID: EventID?

    /// When anything last happened here — a comment, a status move, a part
    /// added. Not `updated`, which every incidental patch bumps.
    public var lastActivityAt: Timestamp?
    public var created: Timestamp?
    public var updated: Timestamp?

    // MARK: Rolled up by the server

    /// The first photo, ready to load. Only the first: the list draws one
    /// thumbnail per row and resolving every picture on every push would be a
    /// storage read per photo, for pictures nothing on that screen will draw.
    public var thumbnailURL: String?
    /// Every photo, resolved. Populated by `issues:detail` only.
    ///
    /// Ids *and* URLs, because the screen has to do two things with a picture —
    /// draw it and delete it — and a signed storage URL is not required to
    /// contain the id it was built from. Working one back out of the other is a
    /// guess that deletes the wrong photo.
    public var photos: [IssuePhotoRef]
    public var photoCount: Int
    /// Parts on the shopping list for this that nobody has bought yet.
    public var partsOpen: Int
    /// What it has cost so far, in the currency its first receipt was in.
    public var spent: Int
    public var spentCurrency: String?
    /// How long it has been broken, counted on the server so every screen ages
    /// a problem against the same clock.
    public var ageDays: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, details, area, category, severity, status
        case homeID = "home_id"
        case reportedBy = "reported_by"
        case assignedTo = "assigned_to"
        case dueBy = "due_by"
        case blockedReason = "blocked_reason"
        case resolvedAt = "resolved_at"
        case resolvedBy = "resolved_by"
        case resolution
        case costEstimate = "cost_estimate"
        case currency
        case vendorName = "vendor_name"
        case vendorPhone = "vendor_phone"
        case vendorURL = "vendor_url"
        case warrantyUntil = "warranty_until"
        case meToo = "me_too"
        case taskID = "task_id"
        case eventID = "event_id"
        case lastActivityAt = "last_activity_at"
        case created, updated
        case thumbnailURL = "thumbnail_url"
        case photos = "photo_refs"
        case photoCount = "photo_count"
        case partsOpen = "parts_open"
        case spent
        case spentCurrency = "spent_currency"
        case ageDays = "age_days"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(IssueID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        details = try c.decodeIfPresent(String.self, forKey: .details)
        // Lenient throughout: a list is decoded as one array, so a value a
        // newer client wrote must degrade its own row rather than blank the
        // whole screen.
        area = c.decodeLenient(IssueArea.self, forKey: .area, default: .other)
        category = c.decodeLenient(IssueCategory.self, forKey: .category, default: .other)
        severity = c.decodeLenient(IssueSeverity.self, forKey: .severity, default: .minor)
        status = c.decodeLenient(IssueStatus.self, forKey: .status, default: .reported)
        homeID = try c.decodeIfPresent(HomeID.self, forKey: .homeID)
        reportedBy = try c.decodeIfPresent(UserID.self, forKey: .reportedBy)
        assignedTo = try c.decodeIfPresent(UserID.self, forKey: .assignedTo)
        dueBy = try c.decodeIfPresent(Timestamp.self, forKey: .dueBy)
        blockedReason = try c.decodeIfPresent(String.self, forKey: .blockedReason)
        resolvedAt = try c.decodeIfPresent(Timestamp.self, forKey: .resolvedAt)
        resolvedBy = try c.decodeIfPresent(UserID.self, forKey: .resolvedBy)
        resolution = try c.decodeIfPresent(String.self, forKey: .resolution)
        // `decodeNumberIfPresent`, never `contains(_:)`: Convex writes an absent
        // field as an explicit null, and a key holding null is just as *present*
        // as one holding a number — which is how an event with no budget once
        // came back as a budget of zero.
        costEstimate = c.decodeNumberIfPresent(forKey: .costEstimate)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        vendorName = try c.decodeIfPresent(String.self, forKey: .vendorName)
        vendorPhone = try c.decodeIfPresent(String.self, forKey: .vendorPhone)
        vendorURL = try c.decodeIfPresent(String.self, forKey: .vendorURL)
        warrantyUntil = try c.decodeIfPresent(Timestamp.self, forKey: .warrantyUntil)
        meToo = try c.decodeIfPresent([UserID].self, forKey: .meToo) ?? []
        taskID = try c.decodeIfPresent(TaskID.self, forKey: .taskID)
        eventID = try c.decodeIfPresent(EventID.self, forKey: .eventID)
        lastActivityAt = try c.decodeIfPresent(Timestamp.self, forKey: .lastActivityAt)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
        updated = try c.decodeIfPresent(Timestamp.self, forKey: .updated)
        thumbnailURL = try c.decodeIfPresent(String.self, forKey: .thumbnailURL)
        photos = try c.decodeIfPresent([IssuePhotoRef].self, forKey: .photos) ?? []
        photoCount = c.decodeNumber(forKey: .photoCount)
        partsOpen = c.decodeNumber(forKey: .partsOpen)
        spent = c.decodeNumber(forKey: .spent)
        spentCurrency = try c.decodeIfPresent(String.self, forKey: .spentCurrency)
        ageDays = c.decodeNumber(forKey: .ageDays)
    }

    public init(
        id: IssueID,
        title: String,
        details: String? = nil,
        area: IssueArea = .other,
        category: IssueCategory = .other,
        severity: IssueSeverity = .minor,
        status: IssueStatus = .reported,
        homeID: HomeID? = nil,
        reportedBy: UserID? = nil,
        assignedTo: UserID? = nil,
        dueBy: Timestamp? = nil,
        blockedReason: String? = nil,
        resolvedAt: Timestamp? = nil,
        resolvedBy: UserID? = nil,
        resolution: String? = nil,
        costEstimate: Int? = nil,
        currency: String? = nil,
        vendorName: String? = nil,
        vendorPhone: String? = nil,
        vendorURL: String? = nil,
        warrantyUntil: Timestamp? = nil,
        meToo: [UserID] = [],
        taskID: TaskID? = nil,
        eventID: EventID? = nil,
        lastActivityAt: Timestamp? = nil,
        created: Timestamp? = nil,
        updated: Timestamp? = nil,
        thumbnailURL: String? = nil,
        photos: [IssuePhotoRef] = [],
        photoCount: Int = 0,
        partsOpen: Int = 0,
        spent: Int = 0,
        spentCurrency: String? = nil,
        ageDays: Int = 0
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.area = area
        self.category = category
        self.severity = severity
        self.status = status
        self.homeID = homeID
        self.reportedBy = reportedBy
        self.assignedTo = assignedTo
        self.dueBy = dueBy
        self.blockedReason = blockedReason
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.resolution = resolution
        self.costEstimate = costEstimate
        self.currency = currency
        self.vendorName = vendorName
        self.vendorPhone = vendorPhone
        self.vendorURL = vendorURL
        self.warrantyUntil = warrantyUntil
        self.meToo = meToo
        self.taskID = taskID
        self.eventID = eventID
        self.lastActivityAt = lastActivityAt
        self.created = created
        self.updated = updated
        self.thumbnailURL = thumbnailURL
        self.photos = photos
        self.photoCount = photoCount
        self.partsOpen = partsOpen
        self.spent = spent
        self.spentCurrency = spentCurrency
        self.ageDays = ageDays
    }
}

extension HouseIssue {
    public var isOpen: Bool { status.isOpen }

    /// Past its date and still not sorted out.
    public var isOverdue: Bool {
        guard let dueBy, isOpen else { return false }
        return dueBy.date < Date()
    }

    /// Whole days until the date. Negative once it has passed.
    public func daysUntilDue(now: Date = Date()) -> Int? {
        guard let dueBy else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: dueBy.date)
        ).day
    }

    /// Still covered by somebody else's promise to fix it.
    ///
    /// Worth its own flag rather than a date comparison at each call site: a
    /// broken appliance under warranty is a phone call, and one a fortnight out
    /// of warranty is a bill — which is exactly the moment a household most
    /// wants to be told.
    public var isUnderWarranty: Bool {
        guard let warrantyUntil else { return false }
        return warrantyUntil.date > Date()
    }

    /// How many people have said this is happening to them.
    public var affectedCount: Int { meToo.count }

    public func isAffected(_ userID: UserID?) -> Bool {
        guard let userID else { return false }
        return meToo.contains(userID)
    }

    /// Whether it has gone quiet. The client's read of the same silence the
    /// server's daily sweep nudges about, so the screen and the notification
    /// agree about which problems have been forgotten.
    public static let staleDays = 7

    public var isStale: Bool {
        guard isOpen, severity != .cosmetic else { return false }
        guard let lastActivityAt else { return false }
        return Date().timeIntervalSince(lastActivityAt.date) > Double(Self.staleDays) * 86_400
    }

    /// How loudly a row asks to be looked at, so one sort order can carry
    /// "what needs me" without four nested comparisons at the call site.
    ///
    /// Overdue outranks urgent on purpose: urgency is somebody's opinion when
    /// the report was filed, and a date that has passed is a fact.
    public var attention: Int {
        guard isOpen else { return -1 }
        var score = severity.rank * 10
        if isOverdue { score += 45 }
        if isStale { score += 12 }
        // Three people reporting a cold radiator is the heating. Capped, so a
        // popular annoyance never outranks something genuinely urgent.
        score += min(affectedCount - 1, 3) * 4
        return score
    }

    /// What the composer should carry over when somebody logs a receipt against
    /// this — the title, so the ledger row explains itself without being typed.
    public var expenseTitle: String { title }
}

/// One picture on a problem: what to draw, and what to delete.
public struct IssuePhotoRef: Codable, Identifiable, Hashable, Sendable {
    /// The `_storage` id. Never shown; only ever handed back to
    /// `issues:removePhoto`.
    public let id: String
    public let url: String

    public init(id: String, url: String) {
        self.id = id
        self.url = url
    }
}

// MARK: - The timeline

/// One entry in a problem's history: something somebody said, or something the
/// app watched happen.
public struct IssueEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: IssueEntryID
    public var kind: IssueEntryKind
    /// Absent for an entry the app wrote rather than a person.
    public var authorID: UserID?
    public var body: String?
    public var fromStatus: IssueStatus?
    public var toStatus: IssueStatus?
    public var created: Timestamp

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case kind
        case authorID = "author_id"
        case body
        case fromStatus = "from_status"
        case toStatus = "to_status"
        case created
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(IssueEntryID.self, forKey: .id)
        kind = c.decodeLenient(IssueEntryKind.self, forKey: .kind, default: .system)
        authorID = try c.decodeIfPresent(UserID.self, forKey: .authorID)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        fromStatus = c.decodeLenientIfPresent(IssueStatus.self, forKey: .fromStatus)
        toStatus = c.decodeLenientIfPresent(IssueStatus.self, forKey: .toStatus)
        created = try c.decodeIfPresent(Timestamp.self, forKey: .created)
            ?? Timestamp(milliseconds: 0)
    }

    public init(
        id: IssueEntryID,
        kind: IssueEntryKind,
        authorID: UserID? = nil,
        body: String? = nil,
        fromStatus: IssueStatus? = nil,
        toStatus: IssueStatus? = nil,
        created: Timestamp
    ) {
        self.id = id
        self.kind = kind
        self.authorID = authorID
        self.body = body
        self.fromStatus = fromStatus
        self.toStatus = toStatus
        self.created = created
    }

    /// Whether the person who wrote it may take it back. Only their own words:
    /// the rest of the timeline is the record of what happened, and a history
    /// anybody can edit is not a history.
    public func isRemovable(by userID: UserID?) -> Bool {
        kind == .comment && authorID != nil && authorID == userID
    }
}

// MARK: - The board

/// Everything the Problems screen draws, in one payload.
///
/// Rows and aggregates together, deliberately: the counters, the room grid and
/// the list under them are computed from one read on the server, so a badge
/// saying "2 urgent" can never sit above three urgent rows. Three subscriptions
/// would be three pushes on every comment and three chances to disagree.
public struct IssueBoard: Codable, Hashable, Sendable {
    public var issues: [HouseIssue]
    public var summary: IssueSummary

    public init(issues: [HouseIssue] = [], summary: IssueSummary = .empty) {
        self.issues = issues
        self.summary = summary
    }

    enum CodingKeys: String, CodingKey {
        case issues, summary
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        issues = try c.decodeIfPresent([HouseIssue].self, forKey: .issues) ?? []
        summary = try c.decodeIfPresent(IssueSummary.self, forKey: .summary) ?? .empty
    }

    public static let empty = IssueBoard()
}

/// The state of repair of one house.
public struct IssueSummary: Codable, Hashable, Sendable {
    public var open: Int
    public var closed: Int
    public var urgent: Int
    public var overdue: Int
    public var unassigned: Int
    /// When the longest-standing open problem was reported.
    public var oldestOpenAt: Timestamp?
    public var fixedThisMonth: Int
    /// How long the household actually takes, over the settled window.
    public var medianFixMs: Double?
    /// Repairs in the last twelve months, and in this one.
    public var repairSpentYear: Int
    public var repairSpentMonth: Int
    public var repairCurrency: String?

    public var byStatus: [StatusCount]
    public var bySeverity: [SeverityCount]
    public var byArea: [AreaCount]
    public var byCategory: [CategoryCount]
    /// Where this house keeps going wrong — the one thing a list of problems
    /// cannot tell you by being read.
    public var repeats: [RepeatOffender]

    // Each of these decodes its enum leniently, and that matters more here than
    // it looks. The whole board — rows *and* aggregates — arrives as one
    // payload, so a single tally naming a status this build has not heard of
    // would throw and blank the entire screen rather than degrade one bar of a
    // chart. Degrading a field always beats losing a list.

    public struct StatusCount: Codable, Hashable, Sendable, Identifiable {
        public var status: IssueStatus
        public var count: Int
        public var id: String { status.rawValue }

        public init(status: IssueStatus, count: Int) {
            self.status = status
            self.count = count
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            status = c.decodeLenient(IssueStatus.self, forKey: .status, default: .reported)
            count = c.decodeNumber(forKey: .count)
        }
    }

    public struct SeverityCount: Codable, Hashable, Sendable, Identifiable {
        public var severity: IssueSeverity
        public var count: Int
        public var id: String { severity.rawValue }

        public init(severity: IssueSeverity, count: Int) {
            self.severity = severity
            self.count = count
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            severity = c.decodeLenient(IssueSeverity.self, forKey: .severity, default: .minor)
            count = c.decodeNumber(forKey: .count)
        }
    }

    public struct AreaCount: Codable, Hashable, Sendable, Identifiable {
        public var area: IssueArea
        public var count: Int
        public var id: String { area.rawValue }

        public init(area: IssueArea, count: Int) {
            self.area = area
            self.count = count
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            area = c.decodeLenient(IssueArea.self, forKey: .area, default: .other)
            count = c.decodeNumber(forKey: .count)
        }
    }

    public struct CategoryCount: Codable, Hashable, Sendable, Identifiable {
        public var category: IssueCategory
        public var count: Int
        public var id: String { category.rawValue }

        public init(category: IssueCategory, count: Int) {
            self.category = category
            self.count = count
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            category = c.decodeLenient(IssueCategory.self, forKey: .category, default: .other)
            count = c.decodeNumber(forKey: .count)
        }
    }

    public struct RepeatOffender: Codable, Hashable, Sendable, Identifiable {
        public var area: IssueArea
        public var category: IssueCategory
        public var count: Int
        public var id: String { "\(area.rawValue)|\(category.rawValue)" }

        public init(area: IssueArea, category: IssueCategory, count: Int) {
            self.area = area
            self.category = category
            self.count = count
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            area = c.decodeLenient(IssueArea.self, forKey: .area, default: .other)
            category = c.decodeLenient(IssueCategory.self, forKey: .category, default: .other)
            count = c.decodeNumber(forKey: .count)
        }
    }

    public init(
        open: Int = 0,
        closed: Int = 0,
        urgent: Int = 0,
        overdue: Int = 0,
        unassigned: Int = 0,
        oldestOpenAt: Timestamp? = nil,
        fixedThisMonth: Int = 0,
        medianFixMs: Double? = nil,
        repairSpentYear: Int = 0,
        repairSpentMonth: Int = 0,
        repairCurrency: String? = nil,
        byStatus: [StatusCount] = [],
        bySeverity: [SeverityCount] = [],
        byArea: [AreaCount] = [],
        byCategory: [CategoryCount] = [],
        repeats: [RepeatOffender] = []
    ) {
        self.open = open
        self.closed = closed
        self.urgent = urgent
        self.overdue = overdue
        self.unassigned = unassigned
        self.oldestOpenAt = oldestOpenAt
        self.fixedThisMonth = fixedThisMonth
        self.medianFixMs = medianFixMs
        self.repairSpentYear = repairSpentYear
        self.repairSpentMonth = repairSpentMonth
        self.repairCurrency = repairCurrency
        self.byStatus = byStatus
        self.bySeverity = bySeverity
        self.byArea = byArea
        self.byCategory = byCategory
        self.repeats = repeats
    }

    enum CodingKeys: String, CodingKey {
        case open, closed, urgent, overdue, unassigned
        case oldestOpenAt, fixedThisMonth, medianFixMs
        case repairSpentYear, repairSpentMonth, repairCurrency
        case byStatus, bySeverity, byArea, byCategory, repeats
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        open = c.decodeNumber(forKey: .open)
        closed = c.decodeNumber(forKey: .closed)
        urgent = c.decodeNumber(forKey: .urgent)
        overdue = c.decodeNumber(forKey: .overdue)
        unassigned = c.decodeNumber(forKey: .unassigned)
        oldestOpenAt = try c.decodeIfPresent(Timestamp.self, forKey: .oldestOpenAt)
        fixedThisMonth = c.decodeNumber(forKey: .fixedThisMonth)
        medianFixMs = try c.decodeIfPresent(Double.self, forKey: .medianFixMs)
        repairSpentYear = c.decodeNumber(forKey: .repairSpentYear)
        repairSpentMonth = c.decodeNumber(forKey: .repairSpentMonth)
        repairCurrency = try c.decodeIfPresent(String.self, forKey: .repairCurrency)
        byStatus = try c.decodeIfPresent([StatusCount].self, forKey: .byStatus) ?? []
        bySeverity = try c.decodeIfPresent([SeverityCount].self, forKey: .bySeverity) ?? []
        byArea = try c.decodeIfPresent([AreaCount].self, forKey: .byArea) ?? []
        byCategory = try c.decodeIfPresent([CategoryCount].self, forKey: .byCategory) ?? []
        repeats = try c.decodeIfPresent([RepeatOffender].self, forKey: .repeats) ?? []
    }

    public static let empty = IssueSummary()

    public func count(of area: IssueArea) -> Int {
        byArea.first { $0.area == area }?.count ?? 0
    }

    public func count(of severity: IssueSeverity) -> Int {
        bySeverity.first { $0.severity == severity }?.count ?? 0
    }

    public func count(of status: IssueStatus) -> Int {
        byStatus.first { $0.status == status }?.count ?? 0
    }

    /// The typical time to fix, in whole days. `nil` until the household has
    /// actually fixed something — a "0 days" figure over no repairs is a claim,
    /// not a statistic.
    public var medianFixDays: Int? {
        guard let medianFixMs, medianFixMs > 0 else { return nil }
        return max(1, Int((medianFixMs / 86_400_000).rounded()))
    }

    /// How well the house is holding up, 0 to 1.
    ///
    /// Not a count and not an average of one: it is what the hero card draws as
    /// a ring, and it has to move for the reasons a household would say the
    /// house is in a worse state — something urgent, something overdue,
    /// something that has been broken for weeks — rather than merely for
    /// *more* things. Five niggles is a to-do list; one flooded bathroom is not.
    ///
    /// Deliberately never quite zero: a screen that reads 0% tells a household
    /// its home is a write-off over a blocked drain.
    public var health: Double {
        guard open > 0 else { return 1 }
        let weight = Double(open) + Double(urgent) * 3 + Double(overdue) * 2
        return max(0.06, 1 - min(1, weight / 18))
    }

    /// Nothing outstanding at all. The one state worth celebrating, and the
    /// only one the screen is allowed to be smug about.
    public var isAllClear: Bool { open == 0 }
}

// MARK: - The detail

/// Everything hanging off one problem: its history, its parts, its receipts,
/// the chore, the visit, and what has gone wrong here before.
public struct IssueDetail: Codable, Hashable, Sendable {
    public var issue: HouseIssue
    public var timeline: [IssueEntry]
    public var parts: [IssuePart]
    public var partsTotal: Int
    public var partsPurchased: Int
    public var expenses: [IssueExpense]
    /// The currency the spend total is in. `nil` until the first receipt.
    public var currency: String?
    public var spent: Int
    /// The chore, if there is one and it still exists.
    public var task: IssueTaskLink?
    /// The visit, if there is one and it still exists.
    public var event: IssueEventLink?
    /// Times this exact fault has been settled before, newest first.
    public var previously: [IssuePrecedent]

    enum CodingKeys: String, CodingKey {
        case issue, timeline, parts
        case partsTotal = "parts_total"
        case partsPurchased = "parts_purchased"
        case expenses, currency, spent, task, event, previously
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        issue = try c.decode(HouseIssue.self, forKey: .issue)
        timeline = try c.decodeIfPresent([IssueEntry].self, forKey: .timeline) ?? []
        parts = try c.decodeIfPresent([IssuePart].self, forKey: .parts) ?? []
        partsTotal = c.decodeNumber(forKey: .partsTotal)
        partsPurchased = c.decodeNumber(forKey: .partsPurchased)
        expenses = try c.decodeIfPresent([IssueExpense].self, forKey: .expenses) ?? []
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        spent = c.decodeNumber(forKey: .spent)
        task = try c.decodeIfPresent(IssueTaskLink.self, forKey: .task)
        event = try c.decodeIfPresent(IssueEventLink.self, forKey: .event)
        previously = try c.decodeIfPresent([IssuePrecedent].self, forKey: .previously) ?? []
    }

    public init(
        issue: HouseIssue,
        timeline: [IssueEntry] = [],
        parts: [IssuePart] = [],
        partsTotal: Int = 0,
        partsPurchased: Int = 0,
        expenses: [IssueExpense] = [],
        currency: String? = nil,
        spent: Int = 0,
        task: IssueTaskLink? = nil,
        event: IssueEventLink? = nil,
        previously: [IssuePrecedent] = []
    ) {
        self.issue = issue
        self.timeline = timeline
        self.parts = parts
        self.partsTotal = partsTotal
        self.partsPurchased = partsPurchased
        self.expenses = expenses
        self.currency = currency
        self.spent = spent
        self.task = task
        self.event = event
        self.previously = previously
    }

    /// How much of the shopping is done. `nil` when nothing was ever needed —
    /// a bar reading 0% over no parts is a job that has not started rather than
    /// a job with nothing to do.
    public var partsProgress: Double? {
        guard partsTotal > 0 else { return nil }
        return Double(partsPurchased) / Double(partsTotal)
    }

    public var hasEverythingItNeeds: Bool { partsTotal > 0 && partsPurchased == partsTotal }

    /// What was spent against what was expected. `nil` when nobody guessed.
    public var estimateProgress: Double? {
        guard let estimate = issue.costEstimate, estimate > 0 else { return nil }
        return Double(spent) / Double(estimate)
    }

    public var isOverEstimate: Bool {
        guard let estimate = issue.costEstimate, estimate > 0 else { return false }
        return spent > estimate
    }

    /// The chore has been done but nobody has said whether it worked.
    ///
    /// The screen's one genuinely useful prompt, and the reason finishing a
    /// chore does not close the problem on its own: "call the plumber" is a
    /// chore somebody can finish while the tap goes on dripping.
    public var awaitsVerdict: Bool {
        guard issue.isOpen, let task else { return false }
        return task.isCompleted
    }
}

/// A part on the shopping list, as the problem sees it.
public struct IssuePart: Codable, Identifiable, Hashable, Sendable {
    public let id: ShoppingItemID
    public var name: String
    public var isPurchased: Bool
    public var category: ShoppingItem.Category

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case isPurchased = "is_purchased"
        case category
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ShoppingItemID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        isPurchased = try c.decodeIfPresent(Bool.self, forKey: .isPurchased) ?? false
        category = c.decodeLenient(ShoppingItem.Category.self, forKey: .category, default: .other)
    }

    public init(
        id: ShoppingItemID,
        name: String,
        isPurchased: Bool = false,
        category: ShoppingItem.Category = .household
    ) {
        self.id = id
        self.name = name
        self.isPurchased = isPurchased
        self.category = category
    }
}

/// One receipt against a repair.
public struct IssueExpense: Codable, Identifiable, Hashable, Sendable {
    public let id: ExpenseID
    public var title: String
    public var amount: Int
    public var currency: String
    public var category: SpendCategory
    public var paidBy: UserID?
    public var spentAt: Timestamp

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, amount, currency, category
        case paidBy = "paid_by"
        case spentAt = "spent_at"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ExpenseID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        amount = c.decodeNumber(forKey: .amount)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "EUR"
        category = c.decodeLenient(SpendCategory.self, forKey: .category, default: .other)
        paidBy = try c.decodeIfPresent(UserID.self, forKey: .paidBy)
        spentAt = try c.decodeIfPresent(Timestamp.self, forKey: .spentAt)
            ?? Timestamp(milliseconds: 0)
    }

    public init(
        id: ExpenseID,
        title: String,
        amount: Int,
        currency: String,
        category: SpendCategory = .household,
        paidBy: UserID? = nil,
        spentAt: Timestamp
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.paidBy = paidBy
        self.spentAt = spentAt
    }
}

/// The chore made of a problem, read through so a deleted one simply stops
/// being shown rather than leaving a link the screen has to explain.
public struct IssueTaskLink: Codable, Identifiable, Hashable, Sendable {
    public let id: TaskID
    public var title: String
    public var isCompleted: Bool
    public var assignedTo: UserID?
    public var dueDate: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case isCompleted = "is_completed"
        case assignedTo = "assigned_to"
        case dueDate = "due_date"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(TaskID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        assignedTo = try c.decodeIfPresent(UserID.self, forKey: .assignedTo)
        dueDate = try c.decodeIfPresent(Timestamp.self, forKey: .dueDate)
    }

    public init(
        id: TaskID,
        title: String,
        isCompleted: Bool = false,
        assignedTo: UserID? = nil,
        dueDate: Timestamp? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.assignedTo = assignedTo
        self.dueDate = dueDate
    }
}

/// The visit booked for a problem.
public struct IssueEventLink: Codable, Identifiable, Hashable, Sendable {
    public let id: EventID
    public var title: String
    public var startsAt: Timestamp
    public var endsAt: Timestamp
    public var location: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case location
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(EventID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        startsAt = try c.decodeIfPresent(Timestamp.self, forKey: .startsAt)
            ?? Timestamp(milliseconds: 0)
        endsAt = try c.decodeIfPresent(Timestamp.self, forKey: .endsAt) ?? startsAt
        location = try c.decodeIfPresent(String.self, forKey: .location)
    }

    public init(
        id: EventID,
        title: String,
        startsAt: Timestamp,
        endsAt: Timestamp,
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.location = location
    }

    /// The day the calendar has to open on to show it.
    public var day: CalendarDay { CalendarDay(startsAt.date) }

    public var hasHappened: Bool { endsAt.date < Date() }
}

/// A time this exact fault was settled before.
public struct IssuePrecedent: Codable, Identifiable, Hashable, Sendable {
    public let id: IssueID
    public var title: String
    public var status: IssueStatus
    public var resolvedAt: Timestamp?
    /// What fixed it last time — the single most useful sentence on the screen
    /// when the same thing goes again.
    public var resolution: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, status
        case resolvedAt = "resolved_at"
        case resolution
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(IssueID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        status = c.decodeLenient(IssueStatus.self, forKey: .status, default: .fixed)
        resolvedAt = try c.decodeIfPresent(Timestamp.self, forKey: .resolvedAt)
        resolution = try c.decodeIfPresent(String.self, forKey: .resolution)
    }

    public init(
        id: IssueID,
        title: String,
        status: IssueStatus = .fixed,
        resolvedAt: Timestamp? = nil,
        resolution: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.resolvedAt = resolvedAt
        self.resolution = resolution
    }
}

// MARK: - Writes

/// Everything needed to report a problem.
public struct NewIssue: Equatable, Sendable {
    public var homeID: HomeID
    public var title: String
    public var details: String?
    public var area: IssueArea
    public var category: IssueCategory
    public var severity: IssueSeverity
    public var assignedTo: UserID?
    public var dueBy: Date?
    /// Minor units. `nil` when nobody has guessed.
    public var costEstimate: Int?
    public var currency: String?
    public var vendorName: String?
    public var vendorPhone: String?
    public var vendorURL: String?
    public var warrantyUntil: Date?
    /// `_storage` ids already uploaded by the composer. The bytes never travel
    /// through a mutation — see `IssuesClient.uploadPhoto`.
    /// Storage id pairs for photos already uploaded, in the order they were
    /// picked. Both sizes, because the board and the detail screen want
    /// different ones.
    public var photos: [IssuePhotoIDs]

    public init(
        homeID: HomeID,
        title: String,
        details: String? = nil,
        area: IssueArea = .other,
        category: IssueCategory = .other,
        severity: IssueSeverity = .minor,
        assignedTo: UserID? = nil,
        dueBy: Date? = nil,
        costEstimate: Int? = nil,
        currency: String? = nil,
        vendorName: String? = nil,
        vendorPhone: String? = nil,
        vendorURL: String? = nil,
        warrantyUntil: Date? = nil,
        photos: [IssuePhotoIDs] = []
    ) {
        self.homeID = homeID
        self.title = title
        self.details = details
        self.area = area
        self.category = category
        self.severity = severity
        self.assignedTo = assignedTo
        self.dueBy = dueBy
        self.costEstimate = costEstimate
        self.currency = currency
        self.vendorName = vendorName
        self.vendorPhone = vendorPhone
        self.vendorURL = vendorURL
        self.warrantyUntil = warrantyUntil
        self.photos = photos
    }
}

/// A partial update. Only the fields set here are sent.
///
/// Three of them are doubled optionals for the reason `EventEdit.recurrence`
/// is: absent leaves the field alone, `.some(nil)` clears it, `.some(value)`
/// replaces it. A plain optional could not say "there is no deadline any more"
/// without also being how you say "don't touch the deadline".
public struct IssueEdit: Equatable, Sendable {
    public var title: String?
    public var details: String?
    public var area: IssueArea?
    public var category: IssueCategory?
    public var severity: IssueSeverity?
    public var dueBy: Date??
    public var costEstimate: Int??
    public var currency: String?
    public var vendorName: String?
    public var vendorPhone: String?
    public var vendorURL: String?
    public var warrantyUntil: Date??

    public init(
        title: String? = nil,
        details: String? = nil,
        area: IssueArea? = nil,
        category: IssueCategory? = nil,
        severity: IssueSeverity? = nil,
        dueBy: Date?? = nil,
        costEstimate: Int?? = nil,
        currency: String? = nil,
        vendorName: String? = nil,
        vendorPhone: String? = nil,
        vendorURL: String? = nil,
        warrantyUntil: Date?? = nil
    ) {
        self.title = title
        self.details = details
        self.area = area
        self.category = category
        self.severity = severity
        self.dueBy = dueBy
        self.costEstimate = costEstimate
        self.currency = currency
        self.vendorName = vendorName
        self.vendorPhone = vendorPhone
        self.vendorURL = vendorURL
        self.warrantyUntil = warrantyUntil
    }
}
