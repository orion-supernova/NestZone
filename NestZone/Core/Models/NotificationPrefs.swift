import Foundation
import SwiftUI

/// `notificationPrefs:mine`: which pushes this person has switched off, and
/// when their phone should be quiet.
///
/// Per person, not per home or device: the same choice applies on every phone
/// they use and in every house they are in. It only decides what is *pushed*;
/// the bell's feed keeps everything. No row on the server means everything on
/// and no quiet hours, which is `init()`.
public struct NotificationPrefs: Decodable, Equatable, Sendable {
    /// Topic keys switched off. A set, and not limited to the topics this build
    /// knows: a key a newer build wrote must survive a write from this one.
    public var off: Set<String>
    public var quiet: QuietHours?

    public init(off: Set<String> = [], quiet: QuietHours? = nil) {
        self.off = off
        self.quiet = quiet
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        off = Set(try c.decodeIfPresent([String].self, forKey: .off) ?? [])
        quiet = try c.decodeIfPresent(QuietHours.self, forKey: .quiet)
    }

    enum CodingKeys: String, CodingKey { case off, quiet }

    public func isOn(_ topic: NotificationTopic) -> Bool { !off.contains(topic.rawValue) }

    public mutating func set(_ topic: NotificationTopic, on: Bool) {
        if on { off.remove(topic.rawValue) } else { off.insert(topic.rawValue) }
    }

    /// How many of a group's topics are on.
    public func onCount(in group: NotificationGroup) -> Int {
        group.topics.filter(isOn).count
    }
}

/// A window, in minutes after midnight in `timeZone`, when pushes arrive
/// silently. It may run past midnight (22:00 to 08:00).
public struct QuietHours: Decodable, Equatable, Sendable {
    public var start: Int
    public var end: Int
    public var timeZone: String

    public static let defaultStart = 22 * 60
    public static let defaultEnd = 8 * 60

    public init(start: Int = defaultStart, end: Int = defaultEnd, timeZone: String = TimeZone.current.identifier) {
        self.start = start
        self.end = end
        self.timeZone = timeZone
    }
}

/// One kind of push a person can switch. The raw value is the key the server
/// filters on, so it never changes.
public enum NotificationTopic: String, CaseIterable, Identifiable, Sendable {
    case tasksAssigned = "tasks.assigned"
    case tasksNew = "tasks.new"
    case tasksDone = "tasks.done"
    case shoppingAdded = "shopping.added"
    case shoppingBought = "shopping.bought"
    case notes
    case calendarEvents = "calendar.events"
    case calendarRSVP = "calendar.rsvp"
    case calendarReminders = "calendar.reminders"
    case meals
    case movies
    case financeExpenses = "finance.expenses"
    case financeReminders = "finance.reminders"
    case issuesNew = "issues.new"
    case issuesUpdates = "issues.updates"
    case issuesReminders = "issues.reminders"
    case messagesDirect = "messages.direct"
    case messagesGroup = "messages.group"
    case messagesMentions = "messages.mentions"
    case polls
    case companionReady = "companion.ready"
    case companionVote = "companion.vote"
    case companionNew = "companion.new"
    case homeMembers = "home.members"

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .tasksAssigned: L10n.notifTopicTasksAssigned
        case .tasksNew: L10n.notifTopicTasksNew
        case .tasksDone: L10n.notifTopicTasksDone
        case .shoppingAdded: L10n.tabBarShopping
        // No push is sent for these two today; the keys stay so a stored
        // choice survives if the server starts.
        case .shoppingBought: L10n.notifTopicShoppingBought
        case .notes: L10n.tabBarNotes
        case .calendarEvents: L10n.notifTopicCalendarEvents
        case .calendarRSVP: L10n.notifTopicCalendarRSVP
        case .calendarReminders, .issuesReminders: L10n.notifTopicReminders
        case .meals: L10n.tabBarRecipes
        case .movies: L10n.notifTopicMovies
        case .financeExpenses: L10n.notifTopicFinanceExpenses
        case .financeReminders: L10n.notifTopicFinanceReminders
        case .issuesNew: L10n.notifTopicIssuesNew
        case .issuesUpdates: L10n.notifTopicIssuesUpdates
        case .messagesDirect: L10n.notifTopicMessagesDirect
        case .messagesGroup: L10n.notifTopicMessagesGroup
        case .messagesMentions: L10n.notifTopicMessagesMentions
        case .polls: L10n.notifTopicPolls
        case .companionReady: L10n.notifTopicCompanionReady
        case .companionVote: L10n.notifTopicCompanionVote
        case .companionNew: L10n.notifTopicCompanionNew
        case .homeMembers: L10n.notifTopicHomeMembers
        }
    }

    /// Only the one-topic groups draw their own glyph; the rest sit under
    /// their group's.
    public var symbol: String {
        switch self {
        case .shoppingAdded: "cart.fill"
        case .notes: "note.text"
        case .meals: "fork.knife"
        case .movies: "film.fill"
        case .homeMembers: "person.2.fill"
        default: "bell"
        }
    }
}

/// How the page gathers topics. A group with several topics gets a switch for
/// all of them; `around` is the one-topic modules, each its own row.
public enum NotificationGroup: String, CaseIterable, Identifiable, Sendable {
    case tasks, calendar, money, problems, messages, nestie, around

    public var id: String { rawValue }

    public var topics: [NotificationTopic] {
        switch self {
        case .tasks: [.tasksAssigned, .tasksNew, .tasksDone]
        case .calendar: [.calendarEvents, .calendarReminders]
        case .money: [.financeExpenses, .financeReminders]
        case .problems: [.issuesNew, .issuesUpdates, .issuesReminders]
        case .messages: [.messagesDirect, .messagesGroup, .messagesMentions, .polls]
        case .nestie: [.companionReady, .companionVote, .companionNew]
        case .around: [.shoppingAdded, .notes, .meals, .movies, .homeMembers]
        }
    }

    /// Whether the group has one switch for all its topics.
    public var hasMasterSwitch: Bool { self != .around }

    /// The Plus feature a free house is missing, for the badge and the paywall.
    public var feature: ProFeature? {
        switch self {
        case .calendar: .calendar
        case .money: .finance
        case .problems: .issues
        case .messages: .messages
        default: nil
        }
    }

    public var title: LocalizedStringResource {
        switch self {
        case .tasks: L10n.tabBarTasks
        case .calendar: L10n.tabBarCalendar
        case .money: L10n.tabBarFinance
        case .problems: L10n.tabBarProblems
        case .messages: L10n.tabBarMessages
        case .nestie: L10n.notifGroupNestie
        case .around: L10n.notifGroupAround
        }
    }

    /// The module's own glyph and tint, so a group is recognisable as the tab
    /// it belongs to.
    public var symbol: String {
        switch self {
        case .tasks: HubModule.tasks.symbol
        case .calendar: HubModule.calendar.symbol
        case .money: HubModule.finance.symbol
        case .problems: HubModule.maintenance.symbol
        case .messages: "bubble.left.and.bubble.right.fill"
        case .nestie: "leaf.fill"
        case .around: "house.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .tasks: HubModule.tasks.tint
        case .calendar: HubModule.calendar.tint
        case .money: HubModule.finance.tint
        case .problems: HubModule.maintenance.tint
        case .messages: Palette.oceanBlue
        case .nestie: Palette.emerald
        case .around: Palette.amber
        }
    }
}
