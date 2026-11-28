import ComposableArchitecture
import SwiftUI

/// One page of the tour: its picture, a headline and one line.
struct OnboardingPageView: View {
    let store: StoreOf<OnboardingFeature>
    let page: OnboardingFeature.Page
    let isCurrent: Bool

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.sectionSpacing) {
                art
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                extra
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, Metrics.stackSpacing)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Pieces

    @ViewBuilder
    private var art: some View {
        switch page {
        case .welcome: WelcomeArt(isCurrent: isCurrent)
        case .household: EmptyView()
        case .lists: ListsArt(isCurrent: isCurrent)
        case .plans: PlansArt(isCurrent: isCurrent)
        case .house: HouseArt(isCurrent: isCurrent)
        case .nestie: NestieArt(isCurrent: isCurrent)
        case .start: WelcomeArt(isCurrent: isCurrent)
        case .done: DoneArt(isCurrent: isCurrent)
        }
    }

    private var title: LocalizedStringResource {
        switch page {
        case .welcome: L10n.onboardingWelcomeTitle
        case .household: L10n.onboardingHouseholdTitle
        case .lists: L10n.onboardingListsTitle
        case .plans: L10n.onboardingPlansTitle
        case .house: L10n.onboardingHouseTitle
        case .nestie: L10n.onboardingNestieTitle
        case .start: L10n.onboardingStartTitle
        case .done: L10n.onboardingDoneTitle
        }
    }

    private var text: LocalizedStringResource {
        switch page {
        case .welcome: L10n.onboardingWelcomeText
        case .household: L10n.onboardingHouseholdText
        case .lists: L10n.onboardingListsText
        case .plans: L10n.onboardingPlansText
        case .house: L10n.onboardingHouseText
        case .nestie: L10n.onboardingNestieText
        case .start: L10n.onboardingStartText
        case .done: L10n.onboardingDoneText
        }
    }

    @ViewBuilder
    private var extra: some View {
        switch page {
        case .household: household
        case .start: start
        default: EmptyView()
        }
    }

    /// "Who do you live with?": one answer, kept on the phone.
    private var household: some View {
        GlassGroup(spacing: 24) {
            VStack(spacing: Metrics.stackSpacing) {
                ForEach(HouseholdKind.allCases) { kind in
                    let isSelected = store.household == kind
                    Button { store.send(.householdPicked(kind)) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: kind.symbol)
                                .font(.title3)
                                .foregroundStyle(.accentText)
                                .frame(width: 36)
                            Text(kind.title).font(.headline)
                            Spacer(minLength: 0)
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? theme.ink : Palette.textTertiary)
                                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                        }
                        .padding(.horizontal, Metrics.cardPadding)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .glassCard(tinted: isSelected ? theme.accent.opacity(0.14) : nil, interactive: true)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .popIn(1, isCurrent: isCurrent)
    }

    /// First run's way in: the same two doors as the no-home screen, opening
    /// the same sheets.
    private var start: some View {
        GlassList {
            ChoiceCard(
                title: L10n.onboardingStartCreate,
                subtitle: L10n.homeSetupCreateHomeSubtitle,
                symbol: "house.and.flag",
                tint: theme.accent
            ) { store.send(.createTapped) }
            .accessibilityIdentifier("OnboardingCreateHome")

            ChoiceCard(
                title: L10n.onboardingStartJoin,
                subtitle: L10n.homeSetupJoinHomeSubtitle,
                symbol: "person.2.badge.key",
                tint: theme.support
            ) { store.send(.joinTapped) }
            .accessibilityIdentifier("OnboardingJoinHome")
        }
        .popIn(1, isCurrent: isCurrent)
    }
}
