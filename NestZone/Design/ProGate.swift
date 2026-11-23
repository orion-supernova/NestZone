import ComposableArchitecture
import SwiftUI

// The gates a view can wear. Each asks the shared `.pro` standing and, when a
// house has no Plus, asks the paywall through `PaywallBroker`: a screen asks,
// it does not navigate.

extension View {
    /// A control that needs Plus. For a house with it, nothing is drawn. For a
    /// house without, a small lock sits on the control and a tap opens the
    /// paywall for `feature` instead of doing the thing. Quiet: never a grey,
    /// dead control.
    func proLocked(_ feature: ProFeature, placement: PlusBadgePlacement = .corner) -> some View {
        modifier(ProLockedModifier(feature: feature, placement: placement))
    }

    /// `proLocked` for a control that is only sometimes Plus.
    @ViewBuilder
    func proLocked(if feature: ProFeature?, placement: PlusBadgePlacement = .corner) -> some View {
        if let feature { proLocked(feature, placement: placement) } else { self }
    }

    /// A Plus control that is open to everyone in some states (taking a film
    /// off a custom list is free). A free house sees the lock only while
    /// `gated`; a Plus house sees nothing on the control itself.
    @ViewBuilder
    func proLocked(if feature: ProFeature?, gated: Bool, placement: PlusBadgePlacement = .corner) -> some View {
        if let feature { modifier(ProLockedModifier(feature: feature, gated: gated, placement: placement)) } else { self }
    }

    /// The Plus lock in a control's top corner, while the house has no Plus.
    /// With Plus there is nothing to draw: an icon-only control stays clean,
    /// and the lock fades away when the house upgrades. For a control that
    /// gates itself (its reducer asks for the paywall); `proLocked` wears this
    /// for the rest. `shown: false` draws nothing, for a list of controls only
    /// some of which are Plus.
    func plusBadge(isLocked: Bool, shown: Bool = true, placement: PlusBadgePlacement = .corner) -> some View {
        modifier(PlusBadgeModifier(isLocked: isLocked, shown: shown, placement: placement))
    }

    /// A module that is Plus as a whole. A free house with nothing in it sees
    /// the locked screen; one with data sees it read-only under a banner.
    /// Loaded-ness is the screen's to say, so nothing flashes shut mid-load.
    func proModule(_ feature: ProFeature, hasData: Bool, isLoaded: Bool) -> some View {
        modifier(ProModuleModifier(feature: feature, hasData: hasData, isLoaded: isLoaded))
    }
}

/// Where the Plus mark sits on its control.
enum PlusBadgePlacement {
    /// Hanging off the top corner: for a control that draws freely around it.
    case corner
    /// Inside the control's own bounds, smaller: for a toolbar button, whose
    /// glass capsule clips anything drawn past its edge.
    case inset
}

/// What Plus looks like, in one place. Every lock, tag, brand tile, the
/// Settings card, the paywall and the locked screens read these, so changing
/// the tag's wash or the tile's glyph is an edit here and nowhere else.
///
/// Plus is a word, not a symbol: "PLUS" in a small tag where a label is, the
/// house mark where the brand is, and nothing at all on an icon-only control
/// of a house that has it. The lock is the only glyph, and only while locked.
/// (Sparkles were Plus's symbol once; they read as magic and clashed with the
/// Sparkles currency, which keeps `sparkle`.)
enum PlusStyle {
    /// A Plus thing a house without Plus cannot use yet.
    static let lockedSymbol = "lock.fill"
    /// The way in: "see the plans", "get Plus".
    static let unlockSymbol = "lock.open.fill"
    /// The app's mark in the brand tile.
    static let brandSymbol = "house.fill"

    /// The colour of Plus: today the theme's accent, so it suits every theme.
    static func tint(_ theme: AppTheme) -> Color { theme.accent }
    /// What is drawn on a fill of `tint`.
    static func onTint(_ theme: AppTheme) -> Color { theme.onAccent }
    /// A fill that carries a glyph in `onTint`: the accent as a fill.
    static func fill(_ theme: AppTheme) -> Color { theme.accentFill }

    // MARK: The tag

    /// The tag's word. Plain "PLUS" in both languages, from the catalog.
    static let tagFont = Font.caption2.weight(.heavy)
    static let tagTracking: CGFloat = 0.6
    /// Horizontal and vertical padding that make a `caption2` tag about 16 pt.
    static let tagPadding = EdgeInsets(top: 1.5, leading: 6, bottom: 1.5, trailing: 6)
    /// How much of the accent washes behind the ink. Ink on this over a white
    /// or a dark card holds 4.5:1 or better in every theme (plus-badge.html).
    static let tagWashOpacity = 0.14

    /// The tag's wash, a stored colour per theme: nothing is built in a body.
    static func tagWash(_ theme: AppTheme) -> Color {
        switch theme {
        case .basic: washViolet
        case .cyberpunk: washMagenta
        case .retroWave: washPink
        case .neonNight: washEmerald
        case .deepOcean: washBlue
        }
    }

    private static let washViolet = Palette.violet.opacity(tagWashOpacity)
    private static let washMagenta = Palette.magenta.opacity(tagWashOpacity)
    private static let washPink = Palette.hotPink.opacity(tagWashOpacity)
    private static let washEmerald = Palette.emeraldFill.opacity(tagWashOpacity)
    private static let washBlue = Palette.oceanBlue.opacity(tagWashOpacity)
}

/// The "PLUS" wordmark: a capsule with the word in the theme's ink on a soft
/// wash of its accent. For beside a label (a segment title, a row, a header)
/// of a house that has Plus. It carries no glyph, so it needs no explaining,
/// and it is as tall as a line of `caption2` so it never hangs off bounds.
struct PlusTag: View {
    var font: Font = PlusStyle.tagFont
    @Environment(\.theme) private var theme

    var body: some View {
        Text(L10n.plusTag)
            .font(font)
            .tracking(PlusStyle.tagTracking)
            .foregroundStyle(.accentText)
            .lineLimit(1)
            .fixedSize()
            .padding(PlusStyle.tagPadding)
            .background(PlusStyle.tagWash(theme), in: .capsule)
            .accessibilityLabel(Text(L10n.proName))
    }
}

/// The app's mark as a tile: `house.fill` in white on the accent fill, in a
/// continuous rounded square like an app icon. The AppIcon asset cannot be
/// drawn from code (the system keeps it out of the asset catalog's reach), and
/// a screenshot of it would not follow the theme; the tile does.
struct PlusBrandTile: View {
    var size: CGFloat = 28
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: PlusStyle.brandSymbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(PlusStyle.onTint(theme))
            .frame(width: size, height: size)
            .background(PlusStyle.fill(theme), in: .rect(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// "NestZone [PLUS]": the brand tile (optionally), the app's name and the
/// tag, for the places Plus is introduced rather than merely marked.
struct PlusLockup: View {
    /// The tile's side; nil draws the name and the tag alone.
    var tileSize: CGFloat? = 28
    var font: Font = .system(.headline, design: .rounded, weight: .bold)
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let tileSize { PlusBrandTile(size: tileSize) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L10n.appName).font(font)
                PlusTag()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.proFullName))
    }
}

/// The lock every Plus feature wears while the house has no Plus: a grey lock
/// on frosted glass. With Plus there is no badge at all (see `plusBadge`).
struct PlusBadge: View {
    var isInset = false

    var body: some View {
        Image(systemName: PlusStyle.lockedSymbol)
            .font(.system(size: isInset ? 7 : 8.5, weight: .bold))
            .foregroundStyle(.secondaryText)
            .frame(width: isInset ? 12 : 16, height: isInset ? 12 : 16)
            .background(.thinMaterial, in: .circle)
    }
}

private struct PlusBadgeModifier: ViewModifier {
    let isLocked: Bool
    let shown: Bool
    let placement: PlusBadgePlacement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            ZStack {
                if shown, isLocked {
                    PlusBadge(isInset: placement == .inset)
                        .offset(x: placement == .corner ? 4 : 0, y: placement == .corner ? -4 : 0)
                        .transition(.opacity)
                }
            }
            // The lock fades away when the house upgrades. Reduce Motion: it
            // is simply gone.
            .animation(reduceMotion ? nil : Motion.fade, value: isLocked)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// The badge's inline form, for a title or a row's trailing edge where a
/// corner badge has nothing to sit on: the grey lock while locked, and the
/// PLUS tag once the house has it. One turns into the other in place.
struct PlusMark: View {
    let isLocked: Bool
    /// The lock's size. The tag has its own.
    var font: Font = .caption2.weight(.bold)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isLocked {
                Image(systemName: PlusStyle.lockedSymbol)
                    .font(font)
                    .foregroundStyle(.secondaryText)
                    .transition(.opacity)
            } else {
                PlusTag().transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.fade, value: isLocked)
        .accessibilityHidden(true)
    }
}

/// A row's title with the PLUS tag after it while the house has Plus. For a
/// Plus row whose lock hangs off its corner while locked (`proLocked`): the
/// tag is the same mark, where there is text to put it beside.
struct PlusTitle: View {
    let title: LocalizedStringResource
    @Shared(.pro) private var pro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: LocalizedStringResource) { self.title = title }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
            if pro.isPro { PlusTag().transition(.opacity) }
        }
        .animation(reduceMotion ? nil : Motion.fade, value: pro.isPro)
    }
}

private struct ProLockedModifier: ViewModifier {
    let feature: ProFeature
    var gated = true
    var placement: PlusBadgePlacement = .corner
    @Shared(.pro) private var pro

    func body(content: Content) -> some View {
        // The badge sits above the branches, so one lock fades away when Plus
        // arrives rather than being swapped out with the control.
        Group {
            if pro.isPro || !gated {
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
            }
        }
        .plusBadge(isLocked: !pro.isPro && gated, placement: placement)
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
                PlusLockup(tileSize: 32)
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
