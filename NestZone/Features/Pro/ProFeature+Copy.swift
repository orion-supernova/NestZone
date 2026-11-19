import Foundation

extension ProFeature {
    /// "Money is part of Plus": what the paywall and a locked screen lead with.
    var paywallTitle: LocalizedStringResource {
        switch self {
        case .calendar: L10n.paywallTitleCalendar
        case .finance: L10n.paywallTitleFinance
        case .shoppingCategories: L10n.paywallTitleShoppingCategories
        case .customMovieLists: L10n.paywallTitleCustomMovieLists
        case .archiveNow: L10n.paywallTitleArchiveNow
        case .eventFromElsewhere: L10n.paywallTitleEventFromElsewhere
        case .expenseFromElsewhere: L10n.paywallTitleExpenseFromElsewhere
        }
    }
}
