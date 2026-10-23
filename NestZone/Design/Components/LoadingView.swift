import SwiftUI

/// The full-screen wait, used only where there is genuinely nothing to show yet.
///
/// Everywhere a list is loading, prefer `.redacted(reason: .placeholder)` over
/// a spinner: it keeps the layout stable and reads as faster.
public struct LoadingView: View {
    private let message: LocalizedStringResource?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @LivePhase private var phase
    /// Where the highlight is across the words: -1 before them, 1 past them.
    @State private var sweep: CGFloat = -1

    /// The highlight: a soft band, solid in the middle. Only its alpha is
    /// used, as a mask.
    private static let band = LinearGradient(
        colors: [.clear, .black, .clear],
        startPoint: .leading,
        endPoint: .trailing
    )

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
                    .overlay {
                        if !reduceMotion {
                            // The same words in the primary colour, seen only
                            // through a band of light passing across them.
                            let travel = sweep
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .mask {
                                    Self.band.visualEffect { band, proxy in
                                        band.offset(x: proxy.size.width * travel)
                                    }
                                }
                                .accessibilityHidden(true)
                        }
                    }
                    // For as long as this view is up, which is exactly as
                    // long as the wait — the same terms the image
                    // placeholder's shimmer runs on. Never under Reduce
                    // Motion, where a sweep that does not end is the very
                    // thing the setting is for, and not for a segment
                    // switched away from.
                    .onChange(of: !reduceMotion && phase == .onScreen, initial: true) { _, sweeping in
                        if sweeping {
                            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                                sweep = 1
                            }
                        } else {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) { sweep = -1 }
                        }
                    }
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
