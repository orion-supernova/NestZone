import SwiftUI

/// One number on the Home tab, with its week-over-week trend.
public struct StatTile: View {
    private let title: LocalizedStringResource
    private let value: Int
    private let change: Int?
    private let symbol: String
    private let tint: Color
    private let action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped to bounce the trend arrow. See `trend(_:)`.
    @State private var trendHops = 0

    public init(
        title: LocalizedStringResource,
        value: Int,
        change: Int? = nil,
        symbol: String,
        tint: Color,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.change = change
        self.symbol = symbol
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { tile }
                .buttonStyle(.pressable)
        } else {
            tile
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
                if let change, change != 0 {
                    trend(change)
                }
            }
            AnimatedNumber(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Without this the tile answers a tap only where a glyph actually is:
        // `glassCard` is a `glassEffect`, a rendering pass that contributes no
        // hit region, so the 16pt padding ring and the gaps between the icon,
        // the number and the label are all dead. On a tile this size that reads
        // as the card being broken rather than as a near miss.
        .contentShape(.rect)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value, format: .number))
    }

    private func trend(_ change: Int) -> some View {
        HStack(spacing: 2) {
            trendArrow(up: change > 0)
            Text(abs(change), format: .number)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(change > 0 ? Palette.success : .secondary)
        .contentTransition(.numericText(value: Double(change)))
        .onAppear { trendHops += 1 }
        .onChange(of: change) { _, _ in trendHops += 1 }
    }

    /// The arrow hops the way the week went — up for more, down for fewer — as
    /// the tile arrives and whenever the figure moves. Still under Reduce
    /// Motion, where the counter it watches stops moving.
    ///
    /// Two branches rather than one stored effect, as `DinnerView` does it:
    /// naming the effect's type would mean importing `Symbols` for the sake of
    /// one parameter.
    @ViewBuilder
    private func trendArrow(up: Bool) -> some View {
        let arrow = Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
            .font(.caption2.weight(.bold))
        let hops = reduceMotion ? 0 : trendHops
        if up {
            arrow.symbolEffect(.bounce.up, options: .nonRepeating, value: hops)
        } else {
            arrow.symbolEffect(.bounce.down, options: .nonRepeating, value: hops)
        }
    }
}
