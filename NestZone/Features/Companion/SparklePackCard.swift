import SwiftUI

/// One pack of Sparkles on the shelf: a glass card with a cluster that grows
/// with the pack, how many Sparkles it is, what more it gives than the 300
/// pack, and the one button that spends real money.
///
/// A tag may sit on the card's top edge ("Best value", or "Starter" on the
/// smallest); it is an overlay, so it never changes the card's height.
/// Nothing in the card can wrap the price: the label is one line that
/// shrinks before it breaks, the card stops growing with Dynamic Type at
/// xxxLarge, and past that the shelf is one column wide.
struct SparklePackCard: View {
    let pack: SparklePack
    /// 0 for the smallest pack: how many sparkles it is drawn with, less one.
    let tier: Int
    let priceText: String
    /// Percent more per unit of money than the 300 pack, if any.
    let bonus: Int?
    let isBest: Bool
    let isStarter: Bool
    /// What this pack is enough for, when the house came here for something.
    let enoughFor: String?
    let note: CompanionFeature.State.PackNote.Kind?
    let isBuying: Bool
    /// Another pack is being bought: this one waits its turn.
    let isWaiting: Bool
    let wide: Bool
    let onFrame: (CGRect) -> Void
    let onBuy: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            SparkleCluster(count: tier + 1)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onFrame($0) }
                .padding(.top, 8)
            // The buy button says the amount and the price; what is left
            // here for VoiceOver is only what the button does not say.
            Text(pack.sparkles, format: .number)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)
            Text(L10n.storePackUnit)
                .font(.subheadline)
                .foregroundStyle(.secondaryText)
                .accessibilityHidden(true)
            // A line is always kept for the bonus, so the cards of a row
            // stand level whether it has one or not.
            Group {
                if let bonus {
                    Text(L10n.storeBonus(bonus))
                } else {
                    Text(verbatim: " ").accessibilityHidden(true)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            if let enoughFor {
                Label {
                    Text(L10n.storeEnoughFor(enoughFor))
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success)
                }
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
            }
            if let note {
                Label {
                    switch note {
                    case .waiting: Text(L10n.storeWaiting)
                    case .failed: Text(L10n.storeDidnt)
                    case .unverified: Text(L10n.storeUnverified)
                    case .retrying: Text(L10n.storeRetrying)
                    }
                } icon: {
                    Image(systemName: note == .failed || note == .unverified ? "exclamationmark.circle" : "clock")
                }
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(note == .failed || note == .unverified ? Palette.dangerText : Color.secondary)
            }
            Spacer(minLength: 4)
            buyButton
                .shake(on: note.map { $0 == .failed || $0 == .unverified ? 1 : 0 } ?? 0)
                .accessibilityLabel(Text(verbatim: "\(Price.sparkles(pack.sparkles).spoken), \(priceText)"))
                .accessibilityIdentifier("Pack.\(pack.sparkles)")
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .glassCard()
        .overlay(alignment: .top) { edgeTag }
        // A wide card has room for the type to grow; two to a row does not.
        .dynamicTypeSize(...(wide ? .accessibility5 : .xxxLarge))
        .opacity(isWaiting ? 0.5 : 1)
        .animation(Motion.fade, value: isWaiting)
    }

    private var buyButton: some View {
        Button(action: onBuy) {
            ZStack {
                // Holds the button's width while it waits.
                Text(verbatim: priceText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .opacity(isBuying ? 0 : 1)
                if isBuying { ProgressView().tint(.white) }
            }
        }
        .buttonStyle(.depth)
        .disabled(isWaiting)
        .allowsHitTesting(!isBuying)
    }

    /// Straddles the card's top edge, so it costs the card no height.
    @ViewBuilder
    private var edgeTag: some View {
        if isBest {
            Text(L10n.storeBestValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(theme.accent, in: .capsule)
                .offset(y: -12)
        } else if isStarter {
            Text(L10n.storeStarter)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondaryText)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(.regularMaterial, in: .capsule)
                .offset(y: -12)
        }
    }
}
