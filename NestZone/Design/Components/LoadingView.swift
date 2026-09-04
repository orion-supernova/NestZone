import SwiftUI

/// The full-screen wait, used only where there is genuinely nothing to show yet.
///
/// Everywhere a list is loading, prefer `.redacted(reason: .placeholder)` over
/// a spinner: it keeps the layout stable and reads as faster.
public struct LoadingView: View {
    private let message: LocalizedStringResource?

    public init(message: LocalizedStringResource? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

/// Rows that stand in for content while it loads. Sized like the real thing, so
/// nothing shifts when the data lands.
public struct SkeletonList: View {
    private let rows: Int
    private let height: CGFloat

    public init(rows: Int = 5, height: CGFloat = 64) {
        self.rows = rows
        self.height = height
    }

    public var body: some View {
        VStack(spacing: Metrics.stackSpacing) {
            ForEach(0..<rows, id: \.self) { index in
                RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                    .fill(.quaternary)
                    .frame(height: height)
                    .opacity(1 - Double(index) * 0.13)
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
        .transition(.opacity)
    }
}
