import SwiftUI

// The three shapes the contribution stats are drawn with.
//
// Hand-rolled rather than Swift Charts, for three reasons: every mark has to
// carry a member's own colour and match their avatar, the surfaces have to sit
// on glass without the framework's opaque plot background fighting it, and a
// household has at most a handful of members — so the whole drawing is a dozen
// shapes, which is cheaper than a chart engine and animates with a plain spring.
//
// Nothing here allocates a colour per frame: tints come from `MemberTint`, which
// caches, and geometry is arithmetic over `Double`s.

/// What colour a slice draws in. The slice itself is a domain value (see
/// `Core/Models/Contributions.swift`); which colour stands for which person is
/// this layer's business.
extension ContributionSlice {
    var tint: Color { seed.map(MemberTint.color(for:)) ?? MemberTint.unattributed }

    var fill: AnyShapeStyle {
        seed.map { AnyShapeStyle(MemberTint.gradient(for: $0)) }
            ?? AnyShapeStyle(MemberTint.unattributed)
    }
}

// MARK: - Share bar

/// A single stacked bar: the whole household's split in one line.
///
/// The compact form, for the Home tab, where the split is a glance and not a
/// screen.
public struct ShareBar: View {
    private let slices: [ContributionSlice]
    private let height: CGFloat

    /// Gap between segments. Small enough that a 3% sliver is still visible as
    /// its own block rather than merging into its neighbour.
    private static let gap: CGFloat = 2

    public init(slices: [ContributionSlice], height: CGFloat = 12) {
        self.slices = slices
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let visible = slices.filter { $0.value > 0 }
            let available = max(0, geo.size.width - Self.gap * CGFloat(max(visible.count - 1, 0)))
            HStack(spacing: Self.gap) {
                ForEach(visible) { slice in
                    Capsule(style: .continuous)
                        .fill(slice.fill)
                        // A share below about 2% rounds to nothing at this
                        // width; a floor keeps the person on the chart instead
                        // of erasing them.
                        .frame(width: max(3, available * slice.value))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .background(Capsule(style: .continuous).fill(.quaternary))
        .clipShape(Capsule(style: .continuous))
        .animation(Motion.spring, value: slices)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.contributionsShareBarLabel))
        .accessibilityValue(Text(
            slices
                .filter { $0.value > 0 }
                .map { "\($0.label) \($0.value.formatted(.percent.precision(.fractionLength(0))))" }
                .joined(separator: ", ")
        ))
    }
}

// MARK: - Donut

/// The hero ring: everyone's share of the work, with the total in the middle.
///
/// Segments are stroked arcs rather than filled wedges, which is what lets each
/// one carry a rounded cap and its own soft shadow — the ring reads as a raised
/// band sitting above the card rather than as a flat pie.
public struct ContributionDonut: View {
    private let slices: [ContributionSlice]
    private let total: Int
    private let caption: LocalizedStringResource
    private let diameter: CGFloat
    private let thickness: CGFloat

    /// Angular gap between segments, as a fraction of the circle.
    private static let gap = 0.006

    @State private var drawn = false

    public init(
        slices: [ContributionSlice],
        total: Int,
        caption: LocalizedStringResource,
        diameter: CGFloat = 180,
        thickness: CGFloat = 26
    ) {
        self.slices = slices
        self.total = total
        self.caption = caption
        self.diameter = diameter
        self.thickness = thickness
    }

    /// The shortest arc that still reads as a segment rather than as nothing.
    /// Below this the two gaps eat the slice whole and a real contributor
    /// disappears off the ring.
    private static let minArc = 0.005

    private struct Arc {
        let slice: ContributionSlice
        let start: Double
        let trimEnd: Double
    }

    /// Running start offset for each slice, so segment *n* begins where *n-1*
    /// ended. Computed once per layout, not per segment.
    private var arcs: [Arc] {
        var cursor = 0.0
        return slices.filter { $0.value > 0 }.map { slice in
            let start = cursor
            cursor += slice.value
            return Arc(
                slice: slice,
                start: start,
                trimEnd: max(start + Self.gap + Self.minArc, cursor - Self.gap)
            )
        }
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: thickness)

            ForEach(arcs, id: \.slice.id) { arc in
                Circle()
                    .trim(from: arc.start + Self.gap, to: arc.trimEnd)
                    .stroke(arc.slice.fill, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    .shadow(color: arc.slice.tint.opacity(0.45), radius: 5, y: 2)
            }
            // Zero at twelve o'clock rather than three, so the biggest share
            // starts where the eye does.
            .rotationEffect(.degrees(-90))
            // Draws itself in on first appearance: the ring sweeping to its
            // final split is the one moment on this screen worth animating.
            .scaleEffect(drawn ? 1 : 0.86)
            .opacity(drawn ? 1 : 0)

            VStack(spacing: 2) {
                AnimatedNumber(total)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(Motion.spring, value: slices)
        .onAppear { withAnimation(Motion.celebrate) { drawn = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(caption))
        .accessibilityValue(Text(total, format: .number))
    }
}

// MARK: - Activity

/// Daily completions over the window, stacked by who did them.
///
/// One column per day including the empty ones — the gaps are the interesting
/// part, and a chart that closes them up would claim a household is busier than
/// it is.
public struct ActivityChart: View {
    private let days: [ContributionDay]
    private let busiest: Int
    private let height: CGFloat

    public init(days: [ContributionDay], busiest: Int, height: CGFloat = 108) {
        self.days = days
        self.busiest = busiest
        self.height = height
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(days) { day in
                    column(day)
                }
            }
            .frame(height: height)
            // A quiet rule under the bars. An empty stretch then reads as
            // nothing standing on the axis, rather than as a chart that failed
            // to draw — which is what a run of bare days looked like.
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 1)
            }

            if let first = days.first, let last = days.last {
                HStack {
                    Text(first.start.date, format: .dateTime.day().month(.abbreviated))
                    Spacer(minLength: 0)
                    Text(last.start.date, format: .dateTime.day().month(.abbreviated))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .animation(Motion.spring, value: days)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.contributionsActivityTitle))
        .accessibilityValue(Text(L10n.contributionsActivityBusiestDay(busiest)))
    }

    private func column(_ day: ContributionDay) -> some View {
        VStack(spacing: 1) {
            Spacer(minLength: 0)
            ForEach(day.counts) { count in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MemberTint.color(for: count.userID.rawValue))
                    .frame(height: height * Double(count.count) / Double(busiest))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Legend

/// Who is which colour. Wraps, because a household can be bigger than a line.
public struct ContributionLegend: View {
    private let slices: [ContributionSlice]

    public init(slices: [ContributionSlice]) {
        self.slices = slices
    }

    public var body: some View {
        FlowLayout(spacing: 10, lineSpacing: 6) {
            ForEach(slices.filter { $0.value > 0 }) { slice in
                HStack(spacing: 5) {
                    Circle()
                        .fill(slice.fill)
                        .frame(width: 8, height: 8)
                    Text(slice.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(slice.value, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }
}
