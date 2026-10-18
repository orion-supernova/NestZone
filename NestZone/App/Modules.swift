import ComposableArchitecture
import SwiftUI

/// The household's modules, each of which lives in exactly one tab group.
///
/// Every module is the same kind of thing — a place the household keeps
/// something — and the tab bar holds them in three groups by what a household
/// does with them rather than one tab apiece. A tab for the shopping list alone
/// was, in a tester's words, overkill.
public enum HubModule: String, CaseIterable, Identifiable, Sendable {
    // Declaration order is segment order within each group: the one reached
    // for most often comes first.
    case tasks, shopping, notes, calendar, recipes, movies, finance, maintenance

    public var id: String { rawValue }

    /// The tab group this module lives in. One answer per module, so a module
    /// is never on two tabs and never on none.
    public var group: TabGroup {
        switch self {
        case .tasks, .shopping, .notes: .lists
        case .calendar, .recipes, .movies: .plans
        case .finance, .maintenance: .house
        }
    }

    /// The module's one name, used on its segment and everywhere it is
    /// mentioned. It used to have two or three — "Money" on a tab, "Bills &
    /// Finance" in a list — and pinning a module renamed it.
    public var title: LocalizedStringResource {
        switch self {
        case .tasks: L10n.tabBarTasks
        case .shopping: L10n.tabBarShopping
        case .notes: L10n.tabBarNotes
        case .calendar: L10n.tabBarCalendar
        case .recipes: L10n.tabBarRecipes
        case .movies: L10n.tabBarMovies
        case .finance: L10n.tabBarFinance
        case .maintenance: L10n.tabBarProblems
        }
    }

    public var symbol: String {
        switch self {
        case .tasks: "checklist"
        case .notes: "note.text"
        case .shopping: "cart.fill"
        case .recipes: "fork.knife"
        case .movies: "film.fill"
        case .maintenance: "wrench.adjustable.fill"
        case .finance: "dollarsign.circle.fill"
        case .calendar: "calendar.badge.clock"
        }
    }

    public var tint: Color {
        switch self {
        case .tasks: Palette.statTasks
        case .notes: Palette.statNotes
        case .shopping: Palette.success
        case .recipes: Palette.warning
        case .movies: Palette.violet
        case .maintenance: Palette.cyan
        case .finance: Palette.indigo
        // Not `Palette.danger`. Red is the one hue on Today that means
        // something — an urgent repair, a bill that is late — and a calendar
        // permanently painted red made the alarm look like the ordinary state
        // of the module next to it.
        case .calendar: Palette.hotPink
        }
    }
}

/// A tab that holds several modules behind a segment switch.
///
/// Three groups, by what a household does: things it keeps lists of, things it
/// plans, and the upkeep of the house itself. With Today and Messages that is
/// five tabs, every one of which holds related things — which is what replaced
/// the two pinned single-module tabs and the Household list of everything else.
public enum TabGroup: String, CaseIterable, Identifiable, Sendable {
    case lists, plans, house

    public var id: String { rawValue }

    /// The modules on this tab, in segment order.
    public var modules: [HubModule] {
        HubModule.allCases.filter { $0.group == self }
    }

    /// What the tab opens on before anybody has picked a segment.
    public var defaultModule: HubModule { modules[0] }

    public var title: LocalizedStringResource {
        switch self {
        case .lists: L10n.tabBarLists
        case .plans: L10n.tabBarPlans
        case .house: L10n.tabBarHouse
        }
    }

    public var symbol: String {
        switch self {
        case .lists: "checklist"
        case .plans: "calendar"
        case .house: "house.fill"
        }
    }
}

/// The segment each group was last left on, as this person left it.
///
/// On the device rather than on the server: it is how one person likes their
/// phone to open, not a fact about the household, so no app version is ever
/// asked to understand it.
public enum TabSegments {
    /// The remembered segment for every group, read from storage.
    ///
    /// Stored as one comma-joined list of module names, one per group, and read
    /// by membership rather than position — so a name a later build retired,
    /// or a group with nothing stored yet, simply falls back to its first
    /// segment instead of opening on a module from another tab.
    public static var stored: [TabGroup: HubModule] {
        @Shared(.tabSegmentsRaw) var raw: String
        return parse(raw)
    }

    public static func parse(_ raw: String) -> [TabGroup: HubModule] {
        var segments: [TabGroup: HubModule] = [:]
        for name in raw.split(separator: ",") {
            guard let module = HubModule(rawValue: String(name)),
                  segments[module.group] == nil else { continue }
            segments[module.group] = module
        }
        for group in TabGroup.allCases where segments[group] == nil {
            segments[group] = group.defaultModule
        }
        return segments
    }

    /// Remembers that `module` was the last segment shown on its tab.
    public static func remember(_ module: HubModule) {
        @Shared(.tabSegmentsRaw) var raw: String
        var segments = parse(raw)
        segments[module.group] = module
        let joined = TabGroup.allCases.compactMap { segments[$0]?.rawValue }.joined(separator: ",")
        guard joined != raw else { return }
        $raw.withLock { $0 = joined }
    }
}
