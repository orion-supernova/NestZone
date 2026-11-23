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

    /// A Plus control that is open to everyone in some states (taking a film
    /// off a custom list is free). A Plus house always sees the mark; a free
    /// house sees the lock only while `gated`, and nothing otherwise.
    @ViewBuilder
    func proLocked(if feature: ProFeature?, gated: Bool) -> some View {
        if let feature { modifier(ProLockedModifier(feature: feature, gated: gated)) } else { self }
    }

    /// The Plus badge in a control's top corner: the lock, or the mark once
    /// the house has Plus. For a control that gates itself (its reducer asks
    /// for the paywall); `proLocked` wears this for the rest.
    /// `shown: false` draws nothing, for a list of controls only some of
    /// which are Plus.
    func plusBadge(isLocked: Bool, shown: Bool = true) -> some View {
        overlay(alignment: .topTrailing) {
            if shown {
                PlusBadge(isLocked: isLocked)
                    .offset(x: 4, y: -4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    /// A module that is Plus as a whole. A free house with nothing in it sees
    /// the locked screen; one with data sees it read-only under a banner.
    /// Loaded-ness is the screen's to say, so nothing flashes shut mid-load.
    func proModule(_ feature: ProFeature, hasData: Bool, isLoaded: Bool) -> some View {
        modifier(ProModuleModifier(feature: feature, hasData: hasData, isLoaded: isLoaded))
    }
}

/// What Plus looks like, in one place. Every badge, mark, the Settings row,
/// the paywall and the locked screens read these, so changing the mark or its
/// colour (to purple sparkles, say) is an edit here and nowhere else.
enum PlusStyle {
    /// Plus itself.
    static let symbol = "sparkles"
    /// A Plus thing a house without Plus cannot use yet.
    static let lockedSymbol = "lock.fill"
    /// The way in: "see the plans", "get Plus".
    static let unlockSymbol = "lock.open.fill"

    /// The colour of Plus: today the theme's accent, so it suits every theme.
    static func tint(_ theme: AppTheme) -> Color { theme.accent }
    /// What is drawn on a fill of `tint`.
    static func onTint(_ theme: AppTheme) -> Color { theme.onAccent }

    static func symbol(isLocked: Bool) -> String { isLocked ? lockedSymbol : symbol }
}

/// The mark every Plus feature wears, with Plus or without, so a house that
/// pays sees what it pays for. Without: a lock on frosted glass. With: the
/// same circle in the theme's accent, carrying Plus's sparkles. One shape in
/// one place, so an upgrade is the lock turning into the mark where it sits.
struct PlusBadge: View {
    let isLocked: Bool
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: PlusStyle.symbol(isLocked: isLocked))
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(isLocked ? AnyShapeStyle(.secondaryText) : AnyShapeStyle(PlusStyle.onTint(theme)))
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 16, height: 16)
            .background(isLocked ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(PlusStyle.tint(theme)), in: .circle)
            .animation(reduceMotion ? Motion.fade : Motion.pop, value: isLocked)
    }
}

/// The badge's inline form, for a title or a row's trailing edge where a
/// corner badge has nothing to sit on: the bare glyph, grey while locked and
/// in the accent once open.
struct PlusMark: View {
    let isLocked: Bool
    var font: Font = .caption2.weight(.bold)
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: PlusStyle.symbol(isLocked: isLocked))
            .font(font)
            .foregroundStyle(isLocked ? AnyShapeStyle(.secondaryText) : AnyShapeStyle(PlusStyle.tint(theme)))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}

private struct ProLockedModifier: ViewModifier {
    let feature: ProFeature
    var gated = true
    @Shared(.pro) private var pro

    func body(content: Content) -> some View {
        if pro.isPro {
            content.plusBadge(isLocked: false)
        } else if !gated {
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
                .plusBadge(isLocked: true)
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
            PlusMark(isLocked: true, font: .footnote.weight(.semibold))
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
                        .foregroundStyle(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                PrimaryButton(L10n.proLockedUpgrade, symbol: PlusStyle.unlockSymbol) {
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
