import SwiftUI

/// One choice in the profile-photo sheet.
struct AvatarSourceRow: View {
    let option: AvatarSource
    let tint: Color
    let action: () -> Void

    private var accent: Color { option.isDestructive ? Palette.danger : tint }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: option.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.14), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(option.isDestructive ? Palette.danger : .primary)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, Metrics.cardPadding)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(cornerRadius: Metrics.tightRadius)
        // The subtitle explains the row; read together they are one sentence,
        // and read apart the title alone is ambiguous between two of them.
        .accessibilityElement(children: .combine)
    }
}
