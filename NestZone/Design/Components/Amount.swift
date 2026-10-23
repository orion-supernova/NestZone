import SwiftUI

/// An amount of the companion's money: its glyph and its number — "🍃 250"
/// with the system's leaf, "✨ 1,000" with its sparkle.
///
/// SF Symbols rather than drawn coins: they take the weight and size of the
/// text beside them at every Dynamic Type size and with Bold Text, and the
/// symbol effects are the motion — the glyph bounces when the amount
/// changes, and the number rolls. The colour is on the glyph only; the
/// number stays in the text's colour, so it keeps its contrast anywhere.
public struct Amount: View {
    public enum Currency: Sendable {
        case leaves, sparkles

        public var symbol: String {
            switch self {
            case .leaves: "leaf.fill"
            case .sparkles: "sparkle"
            }
        }

        var color: Color {
            switch self {
            case .leaves: Palette.leaf
            case .sparkles: Palette.sparkle
            }
        }

        public var wash: Color {
            switch self {
            case .leaves: Palette.leafWash
            case .sparkles: Palette.sparkleWash
            }
        }
    }

    let currency: Currency
    let value: Int
    var glyphScale: Image.Scale = .small
    /// The glyph in the label's own colour — on an accent button, where a
    /// label stays one colour.
    var plain = false

    public init(_ currency: Currency, _ value: Int, glyphScale: Image.Scale = .small, plain: Bool = false) {
        self.currency = currency
        self.value = value
        self.glyphScale = glyphScale
        self.plain = plain
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            glyph
            Text(value, format: .number)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(currency == .leaves ? L10n.shopLeavesCount(value) : L10n.shopSparklesCount(value)))
    }

    @ViewBuilder
    private var glyph: some View {
        let image = Image(systemName: currency.symbol)
            .imageScale(glyphScale)
            .symbolEffect(.bounce, value: reduceMotion ? 0 : value)
        if plain {
            image
        } else {
            image
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(currency.color)
                .symbolColorRenderingMode(.gradient)
        }
    }
}

/// The house jar in a line: Leaves, then Sparkles, and a plus where it opens
/// the Sparkles store. Leaves never get the plus: earned money can't be
/// topped up.
public struct JarAmounts: View {
    let leaves: Int
    let sparkles: Int
    var opensStore = true

    public init(leaves: Int, sparkles: Int, opensStore: Bool = true) {
        self.leaves = leaves
        self.sparkles = sparkles
        self.opensStore = opensStore
    }

    public var body: some View {
        HStack(spacing: 10) {
            Amount(.leaves, leaves, glyphScale: .medium)
            HStack(spacing: 4) {
                Amount(.sparkles, sparkles, glyphScale: .medium)
                if opensStore {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accessoryStrong)
                }
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        // The numbers in the text's colour, even inside a tinted toolbar
        // button.
        .foregroundStyle(.primary)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L10n.companionJar))
        .accessibilityValue(Text(L10n.companionJarBoth(leaves, sparkles)))
        .accessibilityHint(opensStore ? Text(L10n.shopAddSparkles) : Text(verbatim: ""))
        .accessibilityShowsLargeContentViewer()
    }
}
