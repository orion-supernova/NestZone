import SwiftUI

/// A titled section divider. Every screen used to hand-roll this with a
/// different font, weight and padding; this is the one version.
public struct SectionHeader<Trailing: View>: View {
    private let title: LocalizedStringResource
    private let subtitle: LocalizedStringResource?
    private let symbol: String?
    private let trailing: Trailing

    public init(
        _ title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        symbol: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    public init(
        _ title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        symbol: String? = nil
    ) {
        self.init(title, subtitle: subtitle, symbol: symbol) { EmptyView() }
    }
}
