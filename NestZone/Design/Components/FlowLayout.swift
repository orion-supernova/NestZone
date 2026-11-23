import SwiftUI

/// Lays subviews out in rows, wrapping when a row runs out of width.
///
/// SwiftUI has no built-in wrapping stack, and the alternative — a `LazyVGrid`
/// with fixed columns — forces every chip to the same width, which looks wrong
/// for text of varying length.
public struct FlowLayout: Layout {
    private let spacing: CGFloat
    private let lineSpacing: CGFloat
    /// Where a row sits when it is narrower than the layout: `.leading` (the
    /// default) or `.trailing`. A row that is not the full width used to hug
    /// the leading edge whatever the caller's frame said.
    private let alignment: HorizontalAlignment

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8, alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // Never narrower than the widest piece: a stack probes its children
        // with a zero width to learn their minimum, and answering that with
        // one piece per row reported a tower of rows — chore rows ~160 pt
        // tall, problem chips broken mid-word. A piece is never squeezed below
        // its own width; the layout only wraps between pieces.
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = max(proposal.width ?? .infinity, widest)
        let rows = layout(subviews: subviews, width: width)
        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height + (total > 0 ? lineSpacing : 0)
        }
        let used = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width.map { max($0, widest) } ?? used, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var y = bounds.minY
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        for row in layout(subviews: subviews, width: max(bounds.width, widest)) {
            var x = alignment == .trailing ? bounds.maxX - row.width : bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layout(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
