import ComposableArchitecture
import SwiftUI

// The gates a view can wear. Each asks the shared `.pro` standing and, when a
// house has no Plus, asks the paywall through `PaywallBroker`: a screen asks,
// it does not navigate.

extension View {
    /// A control that needs Plus. For a house with it, nothing changes. For a
    /// house without, a small lock sits on the control and a tap opens the
    /// paywall for `feature` instead of doing the thing. Quiet: never a grey,
    /// dead control.
    func proLocked(_ feature: ProFeature) -> some View {
        modifier(ProLockedModifier(feature: feature))
    }

    /// `proLocked` for a control that is only sometimes Plus.
    @ViewBuilder
    func proLocked(if feature: ProFeature?) -> some View {
        if let feature { proLocked(feature) } else { self }
    }

    /// A module that is Plus as a whole. A free house with nothing in it sees
    /// the locked screen; one with data sees it read-only under a banner.
    /// Loaded-ness is the screen's to say, so nothing flashes shut mid-load.
    func proModule(_ feature: ProFeature, hasData: Bool, isLoaded: Bool) -> some View {
        modifier(ProModuleModifier(feature: feature, hasData: hasData, isLoaded: isLoaded))
    }
}

private struct ProLockedModifier: ViewModifier {
    let feature: ProFeature
    @Shared(.pro) private var pro

    func body(content: Content) -> some View {
        if pro.isPro {
            content
        } else {
            content
                // The control underneath is never reached by touch, and
                // VoiceOver's activate is taken over: the control keeps its
                // own label and says what happens instead.
                .allowsHitTesting(false)
                .accessibilityHint(Text(L10n.proLockedHint))
                .accessibilityAction(.default) { PaywallBroker.shared.request(feature) }
                .overlay { ProLockTap(feature: feature) }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(3)
                        .background(.thinMaterial, in: .circle)
                        .offset(x: 4, y: -4)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        }
    }
}

/// The touch that replaces a locked control's own. Not an element of its
/// own: VoiceOver meets the control, with its label.
private struct ProLockTap: View {
    let feature: ProFeature

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture { PaywallBroker.shared.request(feature) }
            .accessibilityHidden(true)
    }
}

private struct ProModuleModifier: ViewModifier {
    let feature: ProFeature
    let hasData: Bool
    let isLoaded: Bool
    @Shared(.pro) private var pro

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if !pro.isPro, hasData { ProReadOnlyBanner(feature: feature) }
            }
            .overlay {
                if !pro.isPro, isLoaded, !hasData {
                    ProLockedScreen(feature: feature)
                        .transition(.opacity)
                }
            }
    }
}

/// "Read-only. Adding more needs Plus." with the way to the paywall.
struct ProReadOnlyBanner: View {
    let feature: ProFeature

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L10n.proReadOnlyBanner)
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button { PaywallBroker.shared.request(feature) } label: {
                Text(L10n.proReadOnlyUpgrade)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
        }
        .padding(.leading, 14)
        .padding(.trailing, 2)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 4)
    }
}

/// A whole module a house without Plus has nothing in: a still of what it
/// looks like and the way to the plans. Fills the screen the module would.
struct ProLockedScreen: View {
    let feature: ProFeature
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.sectionSpacing) {
                ProPreview(feature: feature)
                VStack(spacing: 8) {
                    Text(feature.paywallTitle)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text(L10n.proLockedSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                PrimaryButton(L10n.proLockedUpgrade, symbol: "lock.open.fill") {
                    PaywallBroker.shared.request(feature)
                }
                .frame(maxWidth: 320)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 40)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .background(Backdrop(tint: theme.accent))
    }
}

/// A made-up still of the thing a feature adds: three rows of glass with a
/// glyph and a couple of bars each. Not a screenshot, so it never drifts and
/// never shows anybody's data.
struct ProPreview: View {
    let feature: ProFeature?
    @Environment(\.theme) private var theme

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, symbol in
                    HStack(spacing: 12) {
                        Image(systemName: symbol)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(tints[index % tints.count])
                            .frame(width: 34, height: 34)
                            .background(tints[index % tints.count].opacity(0.14), in: .circle)
                        VStack(alignment: .leading, spacing: 6) {
                            Capsule().fill(.primary.opacity(0.16)).frame(width: 120 - CGFloat(index) * 14, height: 8)
                            Capsule().fill(.primary.opacity(0.08)).frame(width: 70 + CGFloat(index) * 10, height: 6)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var tints: [Color] { [theme.accent, Palette.hotPink, Palette.success] }

    private var rows: [String] {
        switch feature {
        case .calendar, .eventFromElsewhere:
            ["calendar", "party.popper.fill", "bell.fill"]
        case .finance, .expenseFromElsewhere:
            ["creditcard.fill", "arrow.left.arrow.right", "chart.pie.fill"]
        case .shoppingCategories:
            ["carrot.fill", "cup.and.saucer.fill", "sparkles"]
        case .customMovieLists:
            ["film.stack.fill", "popcorn.fill", "star.fill"]
        case .archiveNow:
            ["archivebox.fill", "checkmark.circle.fill", "tray.full.fill"]
        case nil:
            ["calendar", "creditcard.fill", "cart.fill"]
        }
    }
}
