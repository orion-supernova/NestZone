import Foundation

/// The tour's one question, "Who do you live with?". Stored per device under
/// `Shared.householdKind` as its raw value and used for nothing but tone.
public enum HouseholdKind: String, CaseIterable, Identifiable, Sendable {
    case partner, flatmates, family, solo

    public var id: String { rawValue }

    var symbol: String {
        switch self {
        case .partner: "heart.fill"
        case .flatmates: "person.3.fill"
        case .family: "figure.2.and.child.holdinghands"
        case .solo: "person.fill"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .partner: L10n.onboardingHouseholdPartner
        case .flatmates: L10n.onboardingHouseholdFlatmates
        case .family: L10n.onboardingHouseholdFamily
        case .solo: L10n.onboardingHouseholdSolo
        }
    }
}
