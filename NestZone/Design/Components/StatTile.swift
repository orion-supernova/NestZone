import SwiftUI

/// One number on the Home tab, with its week-over-week trend.
public struct StatTile: View {
    private let title: LocalizedStringResource
    private let value: Int
    private let change: Int?
    private let symbol: String
    private let tint: Color
    private let action: (() -> Void)?

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
        .glassCard(cornerRadius: Metrics.tightRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value, format: .number))
    }

    private func trend(_ change: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(abs(change), format: .number)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(change > 0 ? Palette.success : .secondary)
        .contentTransition(.numericText(value: Double(change)))
    }
}
