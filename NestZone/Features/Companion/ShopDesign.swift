import SwiftUI

// What the companion adds to the shop's look, and nothing more. The shop is an
// ordinary NestZone screen that happens to sell things — glass cards on the
// Backdrop, the theme's accent, SF Symbols, the app's own type, `Amount` for
// money and `.depth` for the one button that spends. Only the little window
// each thing stands in is the companion's: its sky, as it is right now.

// MARK: - The stage follows the hour

/// The light in the shop: day or dusk by the scene's own curve, so the
/// windows things stand in turn when Today's sky does. The Lab can hold it at
/// dusk.
struct ShopStage: Equatable, Sendable {
    var hour: Int

    var isNight: Bool { SceneFrame.dayness(Double(hour)) < 0.5 }

    /// A companion's portrait is drawn in its stage's light.
    var portraitHour: Int { isNight ? 21 : 13 }

    static let night = ShopStage(hour: 21)
}

extension EnvironmentValues {
    @Entry var shopStage = ShopStage(hour: 13)
}

extension SceneInk {
    static let dayWell = LinearGradient(colors: [daySkyTop, daySkyBottom], startPoint: .top, endPoint: .bottom)
    static let duskWell = LinearGradient(colors: [nightSkyTop, nightSkyBottom], startPoint: .top, endPoint: .bottom)
    /// The soft shadow at a thing's feet: a gradient, not a blur — a blur on
    /// every tile is an offscreen pass each.
    static let wellShadow = EllipticalGradient(colors: [Color.black.opacity(0.22), .clear], center: .center)
}

/// The window a thing stands in: the companion's sky as it is now, with a
/// soft shadow at its feet. What can't be had today is shown faded in it; its
/// words never are.
struct StageWell<Art: View>: View {
    var cornerRadius: CGFloat = Metrics.tightRadius
    var faded = false
    var shadow = true
    @ViewBuilder let art: Art
    @Environment(\.shopStage) private var stage

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(stage.isNight ? SceneInk.duskWell : SceneInk.dayWell)
            if shadow {
                Ellipse().fill(SceneInk.wellShadow)
                    .frame(height: 12)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
            }
            art
                .saturation(faded ? 0 : 1)
                .opacity(faded ? 0.5 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Prices and badges

extension Price {
    var currency: Amount.Currency {
        switch self {
        case .leaves: .leaves
        case .sparkles: .sparkles
        }
    }

    var amount: Int {
        switch self {
        case let .leaves(amount), let .sparkles(amount): amount
        }
    }

    /// "250 Leaves", for VoiceOver.
    var spoken: String {
        switch self {
        case let .leaves(amount): String(localized: L10n.shopLeavesCount(amount))
        case let .sparkles(amount): String(localized: L10n.shopSparklesCount(amount))
        }
    }
}

/// A price on a thing: its currency's glyph and number on that currency's
/// faint wash. Only what costs something gets one.
struct PriceTag: View {
    let price: Price

    var body: some View {
        Amount(price.currency, price.amount)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(price.currency.wash))
    }
}

/// What the house has: a check in the corner of its window.
struct HaveBadge: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title3)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Palette.success)
            .accessibilityHidden(true)
    }
}

/// What can't be had yet: a lock that wiggles when it's tapped anyway.
struct LockBadge: View {
    var wiggle = 0

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .symbolEffect(.wiggle, value: wiggle)
            .frame(width: 24, height: 24)
            .background(.ultraThinMaterial, in: .circle)
            .accessibilityHidden(true)
    }
}

/// A thing hopping in its window when it's tapped.
struct Hop: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: reduceMotion ? 0 : trigger) { content, y in
            content.offset(y: y)
        } keyframes: { _ in
            CubicKeyframe(-6, duration: 0.12)
            SpringKeyframe(0, duration: 0.3, spring: .init(duration: 0.3, bounce: 0.5))
        }
    }
}
