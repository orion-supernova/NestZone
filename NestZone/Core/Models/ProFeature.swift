import Foundation

/// Everything NestZone Plus gates, in one list.
///
/// Every gate in the app asks this enum, and the server throws the same names
/// (`ConvexError { code: "PRO_REQUIRED", feature }`), so what is Plus is a
/// decision made here and in `lib/pro.ts` and nowhere else. The raw values are
/// the server's.
public enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case calendar
    case finance
    case shoppingCategories
    case customMovieLists
    case archiveNow
    /// Making an event from somewhere other than the Calendar: Add anything, a
    /// dinner party, a problem's visit.
    case eventFromElsewhere
    /// Logging money from somewhere other than Money: Add anything, a problem's
    /// cost.
    case expenseFromElsewhere
    /// House problems, as a whole: reporting, moving along, commenting, and
    /// everything a problem's plan books (a visit, parts, a chore).
    case issues
    /// A second home, created or joined. Someone already in two keep them.
    case multipleHomes
    /// Adult titles in the movie catalogue, in search and in the game.
    case matureContent

    public var id: String { rawValue }

    /// An unknown name from a newer server is `nil`, never a crash.
    public init?(serverName: String?) {
        guard let serverName, let feature = Self(rawValue: serverName) else { return nil }
        self = feature
    }

    public var symbol: String {
        switch self {
        case .calendar, .eventFromElsewhere: "calendar.badge.clock"
        case .finance, .expenseFromElsewhere: "dollarsign.circle.fill"
        case .shoppingCategories: "cart.fill"
        case .customMovieLists: "film.stack.fill"
        case .archiveNow: "archivebox.fill"
        case .issues: "wrench.adjustable.fill"
        case .multipleHomes: "house.fill"
        case .matureContent: "eye.trianglebadge.exclamationmark"
        }
    }

    /// The modules that are Plus as a whole, as opposed to one control.
    public var module: HubModule? {
        switch self {
        case .calendar: .calendar
        case .finance: .finance
        case .issues: .maintenance
        default: nil
        }
    }
}
