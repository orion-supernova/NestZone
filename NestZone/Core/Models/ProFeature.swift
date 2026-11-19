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
        }
    }

    /// The modules that are Plus as a whole, as opposed to one control.
    public var module: HubModule? {
        switch self {
        case .calendar: .calendar
        case .finance: .finance
        default: nil
        }
    }
}
