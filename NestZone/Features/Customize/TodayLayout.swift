import Foundation

/// A section of the Today screen that a person can reorder and set to show
/// automatically, always, or never.
public enum TodaySection: String, CaseIterable, Identifiable, Sendable {
    case tonight, needsYou, upNext, tasks, stats, movieNight

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .tonight: L10n.dinnerTonightTitle
        case .needsYou: L10n.homeNeedsYouTitle
        case .upNext: L10n.homeUpNextTitle
        case .tasks: L10n.homeTasksTitle
        case .stats: L10n.hubStatsTitle
        case .movieNight: L10n.homeMinigamesWatchTitle
        }
    }

    public var symbol: String {
        switch self {
        case .tonight: "moon.stars.fill"
        case .needsYou: "exclamationmark.circle.fill"
        case .upNext: "calendar.badge.clock"
        case .tasks: "checklist"
        case .stats: "chart.bar.fill"
        case .movieNight: "popcorn.fill"
        }
    }

    /// What "Automatic" means for this section, in a sentence Customize can
    /// show under its picker. Each section decides differently, and a setting
    /// called Automatic that does not say what it automates is a guess.
    public var automaticMeaning: LocalizedStringResource {
        switch self {
        case .tonight: L10n.customizeAutoTonight
        case .needsYou: L10n.customizeAutoNeedsYou
        case .upNext: L10n.customizeAutoUpNext
        case .tasks: L10n.customizeAutoTasks
        case .stats: L10n.customizeAutoStats
        case .movieNight: L10n.customizeAutoMovieNight
        }
    }
}

/// When a section of Today is drawn.
public enum SectionVisibility: String, CaseIterable, Identifiable, Sendable {
    /// Only while it has something to say. What every section starts as: a
    /// tester's verdict on the old Today was that an empty section still took
    /// a screenful to say so.
    case automatic
    /// Even when there is nothing in it, as one quiet line.
    case always
    /// Not on Today. What it showed is still where it always was, in Lists,
    /// Plans or House.
    case off

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .automatic: L10n.customizeVisibilityAutomatic
        case .always: L10n.customizeVisibilityAlways
        case .off: L10n.customizeVisibilityOff
        }
    }
}

/// Which Today sections show, when, and in what order.
///
/// Nothing here removes a section from the app — one set to Off is one menu
/// away in Customize, and what it showed is still reachable from its tab.
public struct TodayLayout: Equatable, Sendable {
    /// Every section, in display order, the ones set to Off included.
    public var order: [TodaySection]
    /// Sections not listed are Automatic.
    public var visibility: [TodaySection: SectionVisibility]

    public init(order: [TodaySection], visibility: [TodaySection: SectionVisibility] = [:]) {
        self.order = order
        self.visibility = visibility.filter { $0.value != .automatic }
    }

    /// What Today shows before anybody chooses: everything, each part only
    /// when it has something in it. Whatever is wrong comes first, because it
    /// is the one thing on the screen with a date that can pass.
    public static let `default` = TodayLayout(
        order: [.needsYou, .tonight, .tasks, .upNext, .movieNight, .stats]
    )

    public func visibility(of section: TodaySection) -> SectionVisibility {
        visibility[section] ?? .automatic
    }

    public mutating func set(_ section: TodaySection, to value: SectionVisibility) {
        visibility[section] = value == .automatic ? nil : value
    }

    /// The sections that may be drawn, in order. Whether an Automatic one
    /// actually is depends on whether it has anything in it, which only Today
    /// knows.
    public var shown: [TodaySection] { order.filter { visibility(of: $0) != .off } }

    /// One comma-joined string: a plain name is Automatic, `+name` is Always
    /// and `-name` is Off.
    public var raw: String {
        order.map { section in
            switch visibility(of: section) {
            case .automatic: section.rawValue
            case .always: "+\(section.rawValue)"
            case .off: "-\(section.rawValue)"
            }
        }
        .joined(separator: ",")
    }

    /// Reads a stored layout. Unknown names are skipped; a section the stored
    /// value does not mention — one added by a later build — goes at the end
    /// as Automatic, so nothing ever goes missing.
    public init(raw: String) {
        var order: [TodaySection] = []
        var visibility: [TodaySection: SectionVisibility] = [:]
        for token in raw.split(separator: ",") {
            let mark = token.first
            let name = String(token.drop { $0 == "-" || $0 == "+" })
            guard let section = TodaySection(rawValue: name), !order.contains(section) else { continue }
            order.append(section)
            switch mark {
            case "+": visibility[section] = .always
            case "-": visibility[section] = .off
            default: break
            }
        }
        for section in Self.default.order where !order.contains(section) {
            order.append(section)
        }
        self.init(order: order, visibility: visibility)
    }
}
