import SwiftUI

/// One thing Plus adds, as the details page lists it: a symbol in its tint, a
/// one-line title and what a person can do with it.
///
/// A table built once, not in a `body`: the colours are `Palette` constants
/// and the copy is resolved where it is drawn.
struct PlusDetail: Identifiable {
    let feature: ProFeature
    let symbol: String
    let tint: Color
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var id: ProFeature { feature }
}

/// The page's sections, in reading order. Every `ProFeature` is in exactly one
/// (`PlusDetail.groups` is checked against `ProFeature.allCases` in Debug), so
/// a new gate cannot ship without a line saying what it is.
struct PlusDetailGroup: Identifiable {
    let title: LocalizedStringResource
    let details: [PlusDetail]

    var id: ProFeature { details[0].feature }
}

extension PlusDetail {
    static let groups: [PlusDetailGroup] = {
        let groups = [
            PlusDetailGroup(title: L10n.plusGroupPlan, details: [
                PlusDetail(feature: .calendar, symbol: "calendar.badge.clock", tint: Palette.hotPink,
                           title: L10n.plusFeatureCalendarTitle, text: L10n.plusFeatureCalendarText),
                PlusDetail(feature: .eventFromElsewhere, symbol: "calendar.badge.plus", tint: Palette.eventParty,
                           title: L10n.plusFeatureEventTitle, text: L10n.plusFeatureEventText),
            ]),
            PlusDetailGroup(title: L10n.plusGroupMoney, details: [
                PlusDetail(feature: .finance, symbol: "dollarsign.circle.fill", tint: Palette.indigo,
                           title: L10n.plusFeatureMoneyTitle, text: L10n.plusFeatureMoneyText),
                PlusDetail(feature: .expenseFromElsewhere, symbol: "plus.circle.fill", tint: Palette.cyan,
                           title: L10n.plusFeatureExpenseTitle, text: L10n.plusFeatureExpenseText),
            ]),
            PlusDetailGroup(title: L10n.plusGroupHouse, details: [
                PlusDetail(feature: .issues, symbol: "wrench.adjustable.fill", tint: Palette.eventOutdoor,
                           title: L10n.plusFeatureIssuesTitle, text: L10n.plusFeatureIssuesText),
                PlusDetail(feature: .messages, symbol: "bubble.left.and.bubble.right.fill", tint: Palette.amber,
                           title: L10n.plusFeatureMessagesTitle, text: L10n.plusFeatureMessagesText),
                PlusDetail(feature: .shoppingCategories, symbol: "cart.fill", tint: Palette.success,
                           title: L10n.plusFeatureShoppingTitle, text: L10n.plusFeatureShoppingText),
                PlusDetail(feature: .archiveNow, symbol: "archivebox.fill", tint: Palette.eventChore,
                           title: L10n.plusFeatureArchiveTitle, text: L10n.plusFeatureArchiveText),
            ]),
            PlusDetailGroup(title: L10n.plusGroupMovies, details: [
                PlusDetail(feature: .customMovieLists, symbol: "film.stack.fill", tint: Palette.violet,
                           title: L10n.plusFeatureListsTitle, text: L10n.plusFeatureListsText),
                PlusDetail(feature: .matureContent, symbol: "eye.trianglebadge.exclamationmark", tint: Palette.eventDeadline,
                           title: L10n.plusFeatureMatureTitle, text: L10n.plusFeatureMatureText),
            ]),
            PlusDetailGroup(title: L10n.plusGroupHomes, details: [
                PlusDetail(feature: .multipleHomes, symbol: "house.fill", tint: Palette.oceanBlue,
                           title: L10n.plusFeatureHomesTitle, text: L10n.plusFeatureHomesText),
            ]),
        ]
        #if DEBUG
        let listed = Set(groups.flatMap(\.details).map(\.feature))
        assert(listed == Set(ProFeature.allCases), "A Plus feature has no line on the details page.")
        #endif
        return groups
    }()
}
