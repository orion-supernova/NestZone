import Foundation

/// Who in the household actually does the chores.
///
/// The Home tab could always say how many tasks were finished but never by whom,
/// which in a shared home is the more interesting half of the question. The
/// server tallies this in one pass over the task list and sends the result; see
/// `convex/stats.ts`. Deliberately *not* derived on-device from
/// `tasks:listByHome` — that would mean shipping every task the household has
/// ever had to the phone to draw one ring.
public struct HomeContributions: Codable, Hashable, Sendable {
    /// Days the counts cover. `0` means the household's whole history.
    public var windowDays: Int
    /// Everything finished in the window, including work credited to nobody.
    public var totalCompleted: Int
    /// Finished by someone who has since left the home, or by a migrated row
    /// that carries no author at all. Kept visible rather than dropped, so the
    /// shares still add up to the total.
    public var unattributed: Int
    /// One row per current member, including the ones who have done nothing.
    public var members: [MemberContribution]
    /// A dense daily histogram, oldest first — empty days included, so the
    /// chart shows the gaps instead of closing them up.
    public var days: [ContributionDay]

    public init(
        windowDays: Int = 0,
        totalCompleted: Int = 0,
        unattributed: Int = 0,
        members: [MemberContribution] = [],
        days: [ContributionDay] = []
    ) {
        self.windowDays = windowDays
        self.totalCompleted = totalCompleted
        self.unattributed = unattributed
        self.members = members
        self.days = days
    }

    public static let empty = HomeContributions()
}

/// One person's share of the housework.
public struct MemberContribution: Codable, Identifiable, Hashable, Sendable {
    public let userID: UserID
    public var name: String?
    public var email: String?
    /// Finished inside the window.
    public var completed: Int
    /// Still open and assigned to them — what they owe the house right now.
    public var openAssigned: Int
    /// Of those, past their due date.
    public var overdue: Int
    /// Consecutive days up to today with at least one completion. Counted over
    /// the household's whole history, not the window: a streak is a property of
    /// the person, and it would be odd for it to shrink when you tap "week".
    public var streak: Int

    public var cleaning: Int
    public var shopping: Int
    public var maintenance: Int
    public var general: Int

    public var id: UserID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case name, email, completed, openAssigned, overdue, streak
        case cleaning, shopping, maintenance, general
    }

    public init(
        userID: UserID,
        name: String? = nil,
        email: String? = nil,
        completed: Int = 0,
        openAssigned: Int = 0,
        overdue: Int = 0,
        streak: Int = 0,
        cleaning: Int = 0,
        shopping: Int = 0,
        maintenance: Int = 0,
        general: Int = 0
    ) {
        self.userID = userID
        self.name = name
        self.email = email
        self.completed = completed
        self.openAssigned = openAssigned
        self.overdue = overdue
        self.streak = streak
        self.cleaning = cleaning
        self.shopping = shopping
        self.maintenance = maintenance
        self.general = general
    }
}

extension MemberContribution {
    /// Same fallback chain as `User.displayName` — the stats query returns the
    /// raw profile fields rather than a resolved name, so both sides agree.
    public var displayName: String { User.displayName(name: name, email: email) }

    public var initials: String { User.initials(from: displayName) }

    /// What kind of work this person does, biggest first, zeroes dropped.
    public var byKind: [(kind: HouseTask.Kind, count: Int)] {
        [
            (.cleaning, cleaning),
            (.shopping, shopping),
            (.maintenance, maintenance),
            (.general, general),
        ]
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
    }
}

/// One person's share of the whole, ready to be drawn as a segment of a bar or
/// a ring. Plain data: `Design` decides what colour a `seed` becomes.
public struct ContributionSlice: Identifiable, Hashable, Sendable {
    public let id: String
    /// The share this slice takes, `0...1`. Slices are expected to sum to ~1.
    public let value: Double
    /// The member id the colour is derived from. `nil` for work credited to
    /// nobody, which draws grey.
    public let seed: String?
    public let label: String

    public init(id: String, value: Double, seed: String?, label: String) {
        self.id = id
        self.value = value
        self.seed = seed
        self.label = label
    }
}

/// One bar of the activity chart.
public struct ContributionDay: Codable, Hashable, Sendable, Identifiable {
    /// Midnight local to the *viewer* — the query is told the device's offset,
    /// so a household in UTC+13 sees chores land on the day they happened.
    public var start: Timestamp
    public var total: Int
    /// Only the members who did something that day.
    public var counts: [Count]

    public var id: Double { start.milliseconds }

    public struct Count: Codable, Hashable, Sendable, Identifiable {
        public let userID: UserID
        public let count: Int

        public var id: UserID { userID }

        enum CodingKeys: String, CodingKey {
            case userID = "userId"
            case count
        }

        public init(userID: UserID, count: Int) {
            self.userID = userID
            self.count = count
        }
    }

    public init(start: Timestamp, total: Int, counts: [Count] = []) {
        self.start = start
        self.total = total
        self.counts = counts
    }
}

// MARK: - Derived

extension HomeContributions {
    /// Nothing has been finished in this window.
    public var isEmpty: Bool { totalCompleted == 0 }

    /// Work with a name on it. Differs from `totalCompleted` by `unattributed`.
    public var attributed: Int { members.reduce(0) { $0 + $1.completed } }

    /// Busiest first; ties broken by name so the order never flickers between
    /// two people on the same count.
    public var ranked: [MemberContribution] {
        members.sorted {
            $0.completed != $1.completed
                ? $0.completed > $1.completed
                : $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    /// Fraction of everything done in the window, `0...1`. Measured against the
    /// total rather than the attributed subtotal, so the unattributed slice has
    /// room and the segments of a bar still fill it exactly.
    public func share(of member: MemberContribution) -> Double {
        totalCompleted > 0 ? Double(member.completed) / Double(totalCompleted) : 0
    }

    public var unattributedShare: Double {
        totalCompleted > 0 ? Double(unattributed) / Double(totalCompleted) : 0
    }

    /// The tallest bar in the histogram, which the chart scales against. At
    /// least 1, so an empty week draws a flat baseline rather than dividing by
    /// zero.
    public var busiestDay: Int { max(days.map(\.total).max() ?? 0, 1) }

    /// The segments of the ring and of the bar, in leaderboard order, with the
    /// work credited to nobody trailing last.
    ///
    /// One definition, used by both the Home tab's summary bar and the full
    /// screen's donut — two of these would be free to drift apart, and the tab
    /// is meant to be a smaller view of exactly the same thing.
    public var slices: [ContributionSlice] {
        var slices = ranked
            .filter { $0.completed > 0 }
            .map {
                ContributionSlice(
                    id: $0.userID.rawValue,
                    value: share(of: $0),
                    seed: $0.userID.rawValue,
                    label: $0.displayName
                )
            }
        if unattributed > 0 {
            slices.append(ContributionSlice(
                id: "unattributed",
                value: unattributedShare,
                seed: nil,
                label: String(localized: L10n.contributionsUnattributed)
            ))
        }
        return slices
    }

    /// How evenly the work is split, `0...1`.
    ///
    /// Total variation distance from a perfectly even split, normalised and
    /// flipped: `1` is everyone doing exactly their share, `0` is one person
    /// doing all of it. `nil` when the question is meaningless — a household of
    /// one, or a window in which nobody did anything.
    public var balance: Double? {
        let people = members.count
        guard people > 1, attributed > 0 else { return nil }
        let even = 1.0 / Double(people)
        let deviation = members.reduce(0.0) {
            $0 + abs(Double($1.completed) / Double(attributed) - even)
        }
        // The worst case — one person doing everything — is exactly `2(1 - 1/n)`.
        return max(0, 1 - deviation / (2 * (1 - even)))
    }
}

// MARK: - Window

/// How far back the contribution stats look.
public enum ContributionWindow: Int, CaseIterable, Hashable, Sendable, Identifiable {
    case week = 7
    case month = 30
    /// Everything the household has ever done. `0` is what the query reads as
    /// "no lower bound".
    case allTime = 0

    public var id: Int { rawValue }

    /// Days to look back over, as the query expects it.
    public var days: Int { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .week: L10n.contributionsWindowWeek
        case .month: L10n.contributionsWindowMonth
        case .allTime: L10n.contributionsWindowAllTime
        }
    }
}
