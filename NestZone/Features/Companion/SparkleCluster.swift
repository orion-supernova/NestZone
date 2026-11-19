import SwiftUI

/// A handful of sparkles that grows with the pack it sits on: one for the
/// smallest, a fuller spray for the largest. Symbols only — the shop draws no
/// coins — and still: it is laid out once from the count and never animated.
struct SparkleCluster: View {
    /// How many sparkles, 1 to 6.
    let count: Int

    /// Where each goes in the 84 × 44 frame, centre-out so the biggest sit in
    /// the middle. Worked out per count and kept, never per draw.
    private static let layouts: [[Glyph]] = (1...6).map { n in
        let mid = CGFloat(n - 1) / 2
        return (0..<n).map { i in
            guard n > 1 else { return Glyph(x: 0, y: 0, size: 30) }
            let t = abs(CGFloat(i) - mid) / mid
            let step = min(22, 66 / CGFloat(n - 1))
            return Glyph(x: (CGFloat(i) - mid) * step,
                         y: i.isMultiple(of: 2) ? 4 : -5,
                         size: 14 + 14 * (1 - t))
        }
    }

    private struct Glyph {
        let x, y, size: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(Array(Self.layouts[min(max(count, 1), 6) - 1].enumerated()), id: \.offset) { _, glyph in
                Image(systemName: Amount.Currency.sparkles.symbol)
                    .font(.system(size: glyph.size, weight: .semibold))
                    .foregroundStyle(Palette.sparkle)
                    .symbolColorRenderingMode(.gradient)
                    .offset(x: glyph.x, y: glyph.y)
            }
        }
        .frame(width: 84, height: 44)
        .accessibilityHidden(true)
    }
}
