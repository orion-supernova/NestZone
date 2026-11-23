import ComposableArchitecture
import SwiftUI

/// The NestZone Plus paywall.
///
/// An ordinary NestZone screen that happens to sell something: glass cards on
/// the Backdrop, the theme's accent, SF Symbols, no countdown and exactly one
/// "Best value". The one button that spends is `.depth`. Success is a stamp and
/// a haptic, never confetti, because it is money moving.
struct PaywallView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    private static let privacyURL = URL(string: "https://walhallaa.com/nestzone-privacy-terms")!
    private static let termsURL = URL(string: "https://walhallaa.com/nestzone-privacy-terms#terms")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    hero
                    ProPreview(feature: store.feature)
                    benefits
                    seeEverything
                    coverage
                    if store.isCovered {
                        covered
                    } else {
                        plans
                    }
                    legal
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, Metrics.stackSpacing)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { store.send(.closeTapped) } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text(L10n.paywallClose))
                        // Closing would cancel the settling of a payment.
                        .disabled(store.isPurchasing || store.isRestoring)
                }
            }
            .overlay { if store.didSucceed { successStamp } }
            .animation(reduceMotion ? Motion.fade : Motion.spring, value: store.didSucceed)
            .sensoryFeedback(.success, trigger: store.stamps)
            .task { await store.send(.task).finish() }
            // Not swipe-dismissable while a payment is in flight.
            .interactiveDismissDisabled(store.isPurchasing || store.isRestoring)
        }
    }

    // MARK: Top

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: store.feature?.symbol ?? PlusStyle.symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.accentText)
                .frame(width: 72, height: 72)
                .glassEffect(.regular.tint(theme.accent.opacity(0.18)), in: .circle)
                .accessibilityHidden(true)
            Text(store.feature?.paywallTitle ?? L10n.paywallTitleGeneral)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(L10n.paywallSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var benefits: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                benefit("calendar.badge.clock", Palette.hotPink, L10n.paywallBenefitCalendar)
                benefit("dollarsign.circle.fill", Palette.indigo, L10n.paywallBenefitMoney)
                benefit("cart.fill", Palette.success, L10n.paywallBenefitShopping)
                benefit("bubble.left.and.bubble.right.fill", Palette.amber, L10n.paywallBenefitMessages)
                benefit("film.stack.fill", Palette.violet, L10n.paywallBenefitMore)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The short list above is a taste; the page behind this has every line.
    /// Pushed on the paywall's own stack, so Back lands on the plans.
    private var seeEverything: some View {
        NavigationLink {
            PlusDetailsView(status: store.status, homeNames: store.homeNames)
        } label: {
            HStack(spacing: 6) {
                Text(L10n.plusSeeEverything)
                Image(systemName: "chevron.forward").font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.accentText)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }

    private func benefit(_ symbol: String, _ tint: Color, _ text: LocalizedStringResource) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text).font(.subheadline)
        }
    }

    /// Who the subscription is for, and who is already paying.
    private var coverage: some View {
        VStack(spacing: 4) {
            if !store.houseName.isEmpty {
                Text(L10n.paywallCoversHouse(store.houseName))
                    .font(.subheadline.weight(.semibold))
            }
            if let carrier = store.status.carrier, store.status.isPro {
                Text(store.status.mine
                    ? L10n.paywallCarriedByYou
                    : L10n.paywallCarriedBy(carrier.name ?? User.displayName(name: nil, email: nil)))
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: Plans

    @ViewBuilder
    private var plans: some View {
        if store.isLoading {
            SkeletonList(rows: 2, height: 120)
        } else if store.isUnavailable {
            VStack(spacing: 10) {
                Text(L10n.paywallUnavailableTitle).font(.headline)
                Text(store.isConnectionError ? L10n.paywallUnavailableMessage : L10n.paywallNoPlansMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                    .multilineTextAlignment(.center)
                SecondaryButton(L10n.commonRetry) { store.send(.task) }
            }
            .frame(maxWidth: .infinity)
            .padding(Metrics.cardPadding)
            .glassCard()
        } else {
            VStack(spacing: Metrics.stackSpacing) {
                GlassGroup(spacing: Metrics.stackSpacing) {
                    ForEach(store.packages) { package in
                        PlanCard(
                            package: package,
                            isSelected: package.id == store.selected?.id
                        ) {
                            // No spring and no symbol replace under Reduce
                            // Motion: the tick and the haptic still say it.
                            store.send(.packageTapped(package.id), animation: reduceMotion ? nil : Motion.spring)
                        }
                    }
                }

                if let message = store.message { messageLine(message) }

                Button { store.send(.purchaseTapped) } label: {
                    HStack(spacing: 8) {
                        if store.isPurchasing { ProgressView().tint(theme.onAccent) }
                        Text(ctaTitle)
                    }
                }
                .buttonStyle(.depth)
                .disabled(store.isPurchasing || store.isRestoring || store.selected == nil)
                .accessibilityIdentifier("PaywallSubscribe")

                // Renewal terms stand next to the button, before the tap.
                Text(L10n.paywallRenewsNote)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var ctaTitle: LocalizedStringResource {
        guard let days = store.selected?.trialDays else { return L10n.paywallSubscribe }
        return L10n.paywallStartTrialDays(days)
    }

    private func messageLine(_ message: PaywallFeature.State.Message) -> some View {
        copy(for: message)
            .font(.footnote)
            .foregroundStyle(.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
    }

    private func copy(for message: PaywallFeature.State.Message) -> Text {
        switch message {
        case .pending: Text(L10n.paywallPending)
        case .notYetCredited: Text(L10n.paywallNotYetCredited)
        case .nothingToRestore: Text(L10n.paywallNothingToRestore)
        case let .failed(error): Text(verbatim: error.errorDescription ?? "")
        }
    }

    private var covered: some View {
        Label { Text(L10n.paywallSuccessMessage) } icon: {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.success)
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(Metrics.cardPadding)
        .glassCard()
    }

    // MARK: Fine print

    private var legal: some View {
        VStack(spacing: 10) {
            Button { store.send(.restoreTapped) } label: {
                HStack(spacing: 6) {
                    if store.isRestoring { ProgressView().controlSize(.small) }
                    Text(L10n.paywallRestore)
                }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .disabled(store.isPurchasing || store.isRestoring)

            Text(L10n.paywallDisclosureFull)
                .font(.footnote)
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Button { openURL(Self.termsURL) } label: { Text(L10n.settingsTermsOfUse) }
                Button { openURL(Self.privacyURL) } label: { Text(L10n.settingsPrivacyPolicy) }
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.plain)
            .foregroundStyle(.accentText)
        }
        .padding(.bottom, Metrics.stackSpacing)
    }

    // MARK: Success

    /// A stamp, not a burst: it lands where the sale was and sits there.
    private var successStamp: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.success)
            Text(L10n.paywallSuccessTitle).font(.title3.weight(.bold))
            Text(L10n.paywallSuccessMessage).font(.subheadline).foregroundStyle(.secondaryText)
        }
        .padding(32)
        .glassEffect(.regular, in: .rect(cornerRadius: Metrics.cardRadius))
        .transition(reduceMotion ? .opacity : .scale(scale: 1.4).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}

/// One plan, as a glass card that can be picked.
private struct PlanCard: View {
    let package: PlusPackage
    let isSelected: Bool
    let pick: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: pick) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? theme.ink : Palette.textSecondary)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(package.kind == .yearly ? L10n.paywallYearly : L10n.paywallMonthly)
                            .font(.headline)
                        if package.kind == .yearly {
                            Text(L10n.paywallBestValue)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .foregroundStyle(theme.onAccent)
                                .background(theme.accent, in: .capsule)
                        }
                    }
                    // The billed price and its period lead; anything per month
                    // is a side note, smaller and quieter (Guideline 3.1.2).
                    Text(billedLine).font(.system(.title3, design: .rounded, weight: .bold))
                    if let trial = trialLine {
                        Text(trial).font(.subheadline.weight(.medium)).foregroundStyle(.accentText)
                    }
                    Text(note).font(.footnote).foregroundStyle(.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressableQuiet)
        .glassCard(tinted: isSelected ? theme.accent.opacity(0.14) : nil, interactive: true)
        .sensoryFeedback(.selection, trigger: isSelected) { _, now in now }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "$19.99/year": the amount that is billed, and how often.
    private var billedLine: LocalizedStringResource {
        package.kind == .yearly
            ? L10n.paywallPricePerYear(package.price)
            : L10n.paywallPricePerMonth(package.price)
    }

    /// "7 days free, then $19.99/year", only when the plan starts with a trial.
    private var trialLine: LocalizedStringResource? {
        guard let days = package.trialDays else { return nil }
        return L10n.paywallTrialThen(String(localized: L10n.paywallDaysFree(days)), String(localized: billedLine))
    }

    private var note: LocalizedStringResource {
        if package.kind == .monthly { return L10n.paywallBilledMonthlyNote }
        guard let perMonth = package.pricePerMonth else { return L10n.paywallBilledYearlyPlain }
        return L10n.paywallBilledYearlyNote(perMonth)
    }
}
