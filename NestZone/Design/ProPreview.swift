import SwiftUI

/// A made-up miniature of the thing a Plus feature adds, with real, short
/// sample rows so it reads as the feature and never as a loading screen. Not a
/// screenshot, so it never drifts, and the samples are generic on purpose:
/// nobody's household, nobody's name.
///
/// Every colour here is a `Palette` constant or the theme's accent, and every
/// string is localized. One still, nothing animates.
struct ProPreview: View {
    let feature: ProFeature?
    @Environment(\.theme) private var theme

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        // A picture of a screen, not a screen: VoiceOver gets the title above
        // it, not three made-up rows.
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        switch feature {
        case .calendar, .eventFromElsewhere:
            eventRow(day: "14", L10n.proPreviewDinnerParty, L10n.proPreviewSaturday, tint: theme.accent)
            eventRow(day: "16", L10n.proPreviewPlumber, L10n.proPreviewMonday, tint: Palette.hotPink)
        case .finance, .expenseFromElsewhere:
            moneyRow("cart.fill", L10n.proPreviewGroceries, L10n.proPreviewPaidByYou, L10n.proPreviewAmountGroceries, tint: Palette.success)
            moneyRow("bolt.fill", L10n.proPreviewElectricity, L10n.proPreviewPaidByHousemate, L10n.proPreviewAmountBill, tint: Palette.amber)
        case .shoppingCategories:
            aisle("carrot.fill", L10n.proPreviewFruitVeg, [L10n.proPreviewApples, L10n.proPreviewSpinach], tint: Palette.success)
            aisle("birthday.cake.fill", L10n.proPreviewBakery, [L10n.proPreviewBread], tint: Palette.amber)
        case .customMovieLists:
            movieList(L10n.proPreviewListFriday, tiles: Self.posterSetA)
            movieList(L10n.proPreviewListMust, tiles: Self.posterSetB)
        case .archiveNow:
            archiveRow(L10n.proPreviewDishes)
            archiveRow(L10n.proPreviewBins)
            archiveShelf
        case .issues:
            issueRow(L10n.proPreviewTap, L10n.proPreviewUrgent, tint: Palette.danger)
            issueRow(L10n.proPreviewBulb, L10n.proPreviewOpen, tint: Palette.warning)
        case .messages:
            bubble(L10n.proPreviewMessageBread, mine: false)
            bubble(L10n.proPreviewMessageMovie, mine: false)
            bubble(L10n.proPreviewMessageYes, mine: true)
        case .multipleHomes:
            homeCard(L10n.proPreviewHomeFlat, current: true)
            homeCard(L10n.proPreviewHomeCabin, current: false)
        case .matureContent:
            posterGrid
        case nil:
            eventRow(day: "14", L10n.proPreviewDinnerParty, L10n.proPreviewSaturday, tint: theme.accent)
            moneyRow("cart.fill", L10n.proPreviewGroceries, L10n.proPreviewPaidByYou, L10n.proPreviewAmountGroceries, tint: Palette.success)
            aisle("carrot.fill", L10n.proPreviewFruitVeg, [L10n.proPreviewApples, L10n.proPreviewSpinach], tint: Palette.success)
        }
    }

    // MARK: Rows

    private func eventRow(day: String, _ title: LocalizedStringResource, _ when: LocalizedStringResource, tint: Color) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: day)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(when).font(.caption).foregroundStyle(.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private func moneyRow(
        _ symbol: String,
        _ title: LocalizedStringResource,
        _ who: LocalizedStringResource,
        _ amount: LocalizedStringResource,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            glyph(symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(who).font(.caption).foregroundStyle(.secondaryText)
            }
            Spacer(minLength: 8)
            Text(amount)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func aisle(_ symbol: String, _ title: LocalizedStringResource, _ items: [LocalizedStringResource], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol).foregroundStyle(tint)
            }
            .groupLabel()
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                    Text(item).font(.subheadline)
                }
            }
        }
    }

    private func issueRow(_ title: LocalizedStringResource, _ status: LocalizedStringResource, tint: Color) -> some View {
        HStack(spacing: 12) {
            glyph("wrench.adjustable.fill", tint: tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text(status)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(.primary)
                .background(tint.opacity(0.14), in: .capsule)
        }
    }

    private func bubble(_ text: LocalizedStringResource, mine: Bool) -> some View {
        HStack {
            if mine { Spacer(minLength: 40) }
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(mine ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
                .background(
                    mine ? AnyShapeStyle(theme.accentFill) : AnyShapeStyle(.primary.opacity(0.08)),
                    in: .rect(cornerRadius: 16, style: .continuous)
                )
            if !mine { Spacer(minLength: 40) }
        }
    }

    private func archiveRow(_ title: LocalizedStringResource) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Palette.success)
            Text(title)
                .font(.subheadline)
                .strikethrough()
                .foregroundStyle(.secondaryText)
            Spacer(minLength: 0)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiaryText)
        }
    }

    private var archiveShelf: some View {
        Label {
            Text(L10n.proPreviewArchived)
        } icon: {
            Image(systemName: "archivebox.fill")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(theme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.accent.opacity(0.12), in: .capsule)
    }

    private func homeCard(_ name: LocalizedStringResource, current: Bool) -> some View {
        HStack(spacing: 12) {
            glyph("house.fill", tint: current ? theme.accent : Palette.violet)
            Text(name).font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            if current {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.ink)
            }
        }
        .padding(12)
        .background(.primary.opacity(current ? 0.08 : 0.04), in: .rect(cornerRadius: Metrics.tightRadius, style: .continuous))
    }

    // MARK: Posters

    private func movieList(_ name: LocalizedStringResource, tiles: [Color]) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: -10) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { _, color in
                    poster(color, width: 30, height: 44)
                        .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.background, lineWidth: 1.5) }
                }
            }
            Text(name).font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
    }

    private var posterGrid: some View {
        HStack(spacing: 8) {
            ForEach(Array(Self.posterSetC.enumerated()), id: \.offset) { index, color in
                poster(color, width: nil, height: 84)
                    .overlay(alignment: .topLeading) {
                        if index.isMultiple(of: 2) {
                            Text(verbatim: "18+")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Palette.danger, in: .capsule)
                                .padding(4)
                        }
                    }
            }
        }
    }

    private func poster(_ color: Color, width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.gradient)
            .frame(width: width, height: height)
            .overlay(alignment: .bottom) {
                Image(systemName: "film")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 4)
            }
    }

    private func glyph(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(tint.opacity(0.14), in: .circle)
    }

    // Built once, never in `body`.
    private static let posterSetA: [Color] = [Palette.hotPink, Palette.indigo, Palette.violet]
    private static let posterSetB: [Color] = [Palette.amber, Palette.success, Palette.hotPink]
    private static let posterSetC: [Color] = [Palette.indigo, Palette.violet, Palette.hotPink, Palette.amber]
}
