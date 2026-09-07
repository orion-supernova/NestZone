import SwiftUI

// The shapes the household's money is drawn with.
//
// Hand-rolled rather than Swift Charts, for the same three reasons the
// contribution charts are: every mark has to carry a fixed identity colour —
// a category's, a member's — the surfaces sit on glass and the framework's
// opaque plot background fights it, and the data is a handful of marks, which
// is cheaper as a dozen shapes than as a chart engine.
//
// Nothing here allocates a colour per frame: category tints are `static let`
// constants on `Palette`, member tints come from `MemberTint`, which caches,
// and everything else is arithmetic over `Double`s.

// MARK: - Presentation

/// What a category looks like.
///
/// Here rather than on the model for the same reason `ContributionSlice.tint`
/// is here: which colour stands for which category is a `Design` decision, and
/// `Core` should not have to import SwiftUI to hold a spending category.
extension SpendCategory {
    public var title: LocalizedStringResource {
        switch self {
        case .groceries: L10n.financeCategoryGroceries
        case .utilities: L10n.financeCategoryUtilities
        case .rent: L10n.financeCategoryRent
        case .household: L10n.financeCategoryHousehold
        case .dining: L10n.financeCategoryDining
        case .transport: L10n.financeCategoryTransport
        case .health: L10n.financeCategoryHealth
        case .entertainment: L10n.financeCategoryEntertainment
        case .subscriptions: L10n.financeCategorySubscriptions
        case .other: L10n.financeCategoryOther
        }
    }

    public var symbol: String {
        switch self {
        case .groceries: "basket.fill"
        case .utilities: "bolt.fill"
        case .rent: "house.fill"
        case .household: "lightbulb.fill"
        case .dining: "fork.knife"
        case .transport: "car.fill"
        case .health: "cross.case.fill"
        case .entertainment: "party.popper.fill"
        case .subscriptions: "arrow.triangle.2.circlepath"
        case .other: "square.grid.2x2.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .groceries: Palette.spendGroceries
        case .utilities: Palette.spendUtilities
        case .rent: Palette.spendRent
        case .household: Palette.spendHousehold
        case .dining: Palette.spendDining
        case .transport: Palette.spendTransport
        case .health: Palette.spendHealth
        case .entertainment: Palette.spendEntertainment
        case .subscriptions: Palette.spendSubscriptions
        case .other: Palette.spendOther
        }
    }
}

extension BillCycle {
    public var title: LocalizedStringResource {
        switch self {
        case .once: L10n.financeCycleOnce
        case .weekly: L10n.financeCycleWeekly
        case .biweekly: L10n.financeCycleBiweekly
        case .monthly: L10n.financeCycleMonthly
        case .quarterly: L10n.financeCycleQuarterly
        case .yearly: L10n.financeCycleYearly
        }
    }

    public var symbol: String {
        switch self {
        case .once: "1.circle.fill"
        case .weekly, .biweekly: "calendar.badge.clock"
        case .monthly: "calendar"
        case .quarterly, .yearly: "calendar.badge.exclamationmark"
        }
    }
}

extension Bill {
    /// How a reminder offset reads. Zero is "on the day" rather than "0 days
    /// before", and a week is a week rather than seven days — the two offsets
    /// people actually name.
    public static func reminderTitle(_ days: Int) -> LocalizedStringResource {
        switch days {
        case 0: L10n.financeReminderOnDay
        case 7: L10n.financeReminderWeekBefore
        default: L10n.financeReminderDaysBefore(days)
        }
    }
}

extension SplitMode {
    public var title: LocalizedStringResource {
        switch self {
        case .equal: L10n.financeSplitEqual
        case .shares: L10n.financeSplitShares
        case .exact: L10n.financeSplitExact
        }
    }

    public var symbol: String {
        switch self {
        case .equal: "equal.circle"
        case .shares: "chart.pie"
        case .exact: "pencil.and.list.clipboard"
        }
    }
}

extension Bill.Urgency {
    public var tint: Color {
        switch self {
        case .overdue: Palette.danger
        case .dueToday: Palette.warning
        case .dueSoon: Palette.amber
        case .upcoming: Palette.success
        }
    }

    /// True only for the state that has already gone wrong. Used to decide
    /// which single row on the screen is allowed to pulse.
    public var demandsAttention: Bool { self == .overdue }
}

extension BudgetProgress.Health {
    public var tint: Color {
        switch self {
        case .healthy: Palette.success
        case .close: Palette.warning
        case .over: Palette.danger
        }
    }
}

// MARK: - Money in motion

/// An amount that rolls to its new value instead of snapping.
///
/// `AnimatedNumber`'s currency-shaped twin. Kept separate rather than made
/// generic because the interpolation has to happen on the *minor units* and the
/// formatting on the way out: interpolating formatted strings gives you
/// "€1,2O3.4" halfway through, and interpolating a `Decimal` cannot be
/// `animatableData`, which must be a `VectorArithmetic`.
public struct MoneyText: View, Animatable {
    private var minorUnits: Double
    private let currency: String
    private let compact: Bool
    /// Whether to spell a negative amount with a sign. Off where the label
    /// already says "you owe" and the minus would be saying it twice.
    private let signed: Bool

    public init(_ minorUnits: Int, currency: String, compact: Bool = false, signed: Bool = false) {
        self.minorUnits = Double(minorUnits)
        self.currency = currency
        self.compact = compact
        self.signed = signed
    }

    // `nonisolated` because SwiftUI drives animatable data off the render
    // thread, while `View` conformance is main-actor isolated.
    public nonisolated var animatableData: Double {
        get { minorUnits }
        set { minorUnits = newValue }
    }

    public var body: some View {
        let rounded = Int(minorUnits.rounded())
        let shown = signed ? rounded : abs(rounded)
        Text(compact
            ? Money.compactText(shown, currency: currency)
            : Money.text(shown, currency: currency))
            .contentTransition(.numericText(value: minorUnits))
            .monospacedDigit()
    }
}

// MARK: - Where the money went

/// The month's spend, split by category.
///
/// Segments are stroked arcs rather than filled wedges, so each can carry a
/// rounded cap and its own soft shadow — the ring reads as a raised band above
/// the card rather than as a flat pie. Selecting one thickens it and swaps the
/// centre to that category, which is the whole interaction: a donut nobody can
/// interrogate is a decoration.
public struct SpendDonut: View {
    private let categories: [CategoryTotal]
    private let total: Int
    private let currency: String
    @Binding private var selection: SpendCategory?
    private let diameter: CGFloat
    private let thickness: CGFloat

    /// Angular gap between segments, as a fraction of the circle.
    private static let gap = 0.006
    /// The shortest arc that still reads as a segment rather than as nothing.
    private static let minArc = 0.005

    @State private var drawn = false

    public init(
        categories: [CategoryTotal],
        total: Int,
        currency: String,
        selection: Binding<SpendCategory?> = .constant(nil),
        diameter: CGFloat = 190,
        thickness: CGFloat = 24
    ) {
        self.categories = categories
        self.total = total
        self.currency = currency
        self._selection = selection
        self.diameter = diameter
        self.thickness = thickness
    }

    private struct Arc {
        let category: SpendCategory
        let start: Double
        let trimEnd: Double
    }

    /// Running start offset for each segment, so segment *n* begins where *n-1*
    /// ended. Computed once per layout, not once per segment.
    private var arcs: [Arc] {
        guard total > 0 else { return [] }
        var cursor = 0.0
        return categories.filter { $0.total > 0 }.map { row in
            let start = cursor
            cursor += Double(row.total) / Double(total)
            return Arc(
                category: row.category,
                start: start,
                trimEnd: max(start + Self.gap + Self.minArc, cursor - Self.gap)
            )
        }
    }

    /// What the middle says: the selected category if there is one, the whole
    /// month if there is not.
    private var centreAmount: Int {
        guard let selection else { return total }
        return categories.first { $0.category == selection }?.total ?? 0
    }

    public var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: thickness)

            ForEach(arcs, id: \.category) { arc in
                let isSelected = selection == arc.category
                let isDimmed = selection != nil && !isSelected
                Circle()
                    .trim(from: arc.start + Self.gap, to: arc.trimEnd)
                    .stroke(
                        arc.category.tint,
                        style: StrokeStyle(
                            lineWidth: thickness * (isSelected ? 1.3 : 1),
                            lineCap: .round
                        )
                    )
                    .shadow(color: arc.category.tint.opacity(isSelected ? 0.6 : 0.35), radius: 5, y: 2)
                    .opacity(isDimmed ? 0.32 : 1)
            }
            // Zero at twelve o'clock rather than three, so the biggest slice
            // starts where the eye does.
            .rotationEffect(.degrees(-90))
            .scaleEffect(drawn ? 1 : 0.86)
            .opacity(drawn ? 1 : 0)

            VStack(spacing: 2) {
                if let selection {
                    Image(systemName: selection.symbol)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(selection.tint)
                }
                MoneyText(centreAmount, currency: currency, compact: true)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(selection?.title ?? L10n.financeDonutCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, thickness + 8)
            .transition(.opacity)
        }
        .frame(width: diameter, height: diameter)
        .animation(Motion.spring, value: categories)
        .animation(Motion.spring, value: selection)
        .onAppear { withAnimation(Motion.celebrate) { drawn = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.financeDonutCaption))
        .accessibilityValue(Text(Money.text(total, currency: currency)))
    }
}

/// Who is which colour, and how much of the month each took.
public struct SpendLegend: View {
    private let categories: [CategoryTotal]
    private let total: Int
    private let currency: String
    @Binding private var selection: SpendCategory?

    public init(
        categories: [CategoryTotal],
        total: Int,
        currency: String,
        selection: Binding<SpendCategory?> = .constant(nil)
    ) {
        self.categories = categories
        self.total = total
        self.currency = currency
        self._selection = selection
    }

    public var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(categories.filter { $0.total > 0 }) { row in
                let isSelected = selection == row.category
                Button {
                    // Tapping the selected one clears it, so the ring can always
                    // be put back without hunting for a "show all" control.
                    selection = isSelected ? nil : row.category
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(row.category.tint)
                            .frame(width: 8, height: 8)
                        Text(row.category.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        if total > 0 {
                            Text(
                                Double(row.total) / Double(total),
                                format: .percent.precision(.fractionLength(0))
                            )
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(row.category.tint)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        row.category.tint.opacity(isSelected ? 0.2 : 0.08),
                        in: .capsule
                    )
                    .contentShape(.capsule)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(row.category.title))
                .accessibilityValue(Text(Money.text(row.total, currency: currency)))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(Motion.spring, value: selection)
    }
}

// MARK: - Six months

/// Monthly spend over the last half-year, with the shown month picked out.
///
/// Tapping a bar moves the whole screen to that month — the chart is the
/// fastest way back through the ledger, and a history you can only look at is
/// half a control.
public struct SpendBars: View {
    private let points: [SpendPoint]
    private let currency: String
    private let selected: CalendarMonth
    private let height: CGFloat
    private let onSelect: (CalendarMonth) -> Void

    @Environment(\.theme) private var theme
    @State private var grown = false

    public init(
        points: [SpendPoint],
        currency: String,
        selected: CalendarMonth,
        height: CGFloat = 116,
        onSelect: @escaping (CalendarMonth) -> Void
    ) {
        self.points = points
        self.currency = currency
        self.selected = selected
        self.height = height
        self.onSelect = onSelect
    }

    /// At least 1, so a household with no history draws a flat baseline rather
    /// than dividing by zero.
    private var tallest: Int { max(points.map(\.total).max() ?? 0, 1) }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(points) { point in
                bar(point)
            }
        }
        .frame(height: height + 34)
        // A quiet rule under the bars. An empty stretch then reads as nothing
        // standing on the axis rather than as a chart that failed to draw.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.bottom, 18)
        }
        .animation(Motion.spring, value: points)
        .onAppear { withAnimation(Motion.arrive.delay(0.08)) { grown = true } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.financeTrendTitle))
    }

    private func bar(_ point: SpendPoint) -> some View {
        let month = CalendarMonth(year: point.year, month: point.month)
        let isSelected = month == selected
        let fraction = Double(point.total) / Double(tallest)

        return Button { onSelect(month) } label: {
            VStack(spacing: 5) {
                // The figure sits above the selected bar only. Six of them at
                // once is a table, not a chart.
                Text(Money.compactText(point.total, currency: currency))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .opacity(isSelected ? 1 : 0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(theme.accent.opacity(0.28)))
                    // A month with no spend still gets a sliver, so the column
                    // reads as "nothing here" rather than as a missing bar.
                    .frame(height: max(3, height * (grown ? fraction : 0)))
                    .shadow(
                        color: isSelected ? theme.accent.opacity(0.4) : .clear,
                        radius: 6, y: 3
                    )

                Text(point.date, format: .dateTime.month(.narrow))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.secondary))
                    .frame(height: 13)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(point.date, format: .dateTime.month(.wide).year()))
        .accessibilityValue(Text(Money.text(point.total, currency: currency)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Balances

/// Who owes whom, as a diverging bar around a shared zero line.
///
/// A stacked share bar is the wrong shape for this: balances are signed, and
/// the only question anyone asks of them — am I up or down, and by how much
/// against everyone else — is answered by which side of the line a bar is on
/// and how far it reaches. Bars carry each member's own colour, so a row here
/// and their avatar in the ledger are visibly the same person.
public struct BalanceBars: View {
    private let members: [MemberFinance]
    private let currency: String
    private let currentUserID: UserID?

    @State private var grown = false

    public init(members: [MemberFinance], currency: String, currentUserID: UserID? = nil) {
        self.members = members
        self.currency = currency
        self.currentUserID = currentUserID
    }

    /// The widest bar, which everything else is measured against. At least one
    /// minor unit, so a fully settled house does not divide by zero.
    private var extreme: Int { max(members.map { abs($0.net) }.max() ?? 0, 1) }

    public var body: some View {
        VStack(spacing: 10) {
            ForEach(members) { member in
                row(member)
            }
        }
        .overlay(alignment: .center) {
            // The zero line, drawn once behind every row rather than per row —
            // it is one axis, and four stacked segments of it never quite line
            // up.
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)
        }
        .animation(Motion.spring, value: members)
        .onAppear { withAnimation(Motion.arrive.delay(0.1)) { grown = true } }
    }

    private func row(_ member: MemberFinance) -> some View {
        let isOwed = member.net > 0
        let fraction = Double(abs(member.net)) / Double(extreme)
        let tint = MemberTint.color(for: member.userID.rawValue)

        return HStack(spacing: 0) {
            // Owing reaches left, being owed reaches right. The two halves are
            // equal widths whatever the data, so the axis stays put as the
            // numbers move.
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                if !isOwed && member.net != 0 {
                    Text(Money.compactText(abs(member.net), currency: currency))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Capsule(style: .continuous)
                    .fill(isOwed ? Color.clear : tint.opacity(0.85))
                    .frame(width: isOwed ? 0 : barWidth(fraction), height: 18)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 6) {
                Capsule(style: .continuous)
                    .fill(isOwed ? tint.opacity(0.85) : Color.clear)
                    .frame(width: isOwed ? barWidth(fraction) : 0, height: 18)
                if isOwed {
                    Text(Money.compactText(member.net, currency: currency))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .center) {
            // The name rides the axis, so a row is readable even when its bar
            // is a stub.
            Text(member.userID == currentUserID
                ? String(localized: L10n.financeYou)
                : member.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .background(.background.opacity(0.6), in: .capsule)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(member.displayName))
        .accessibilityValue(Text(
            member.net >= 0
                ? L10n.financeIsOwedAmount(Money.text(member.net, currency: currency))
                : L10n.financeOwesAmount(Money.text(abs(member.net), currency: currency))
        ))
    }

    /// Bars are laid out as a fraction of half the row, which is not known here
    /// — `GeometryReader` per row would cost a layout pass each. A fixed
    /// maximum with a floor keeps every non-zero balance visible.
    private func barWidth(_ fraction: Double) -> CGFloat {
        guard grown else { return 0 }
        return max(4, 120 * fraction)
    }
}

// MARK: - Budgets

/// One category's monthly ceiling, and how much of it is gone.
///
/// The ring keeps going past full rather than clamping: a budget at 140% has to
/// look different from one exactly spent, and a bar that stops at the end says
/// they are the same. The overshoot draws as a second, darker sweep over the
/// first.
public struct BudgetRing: View {
    private let progress: BudgetProgress
    private let currency: String
    private let diameter: CGFloat
    private let thickness: CGFloat

    @State private var drawn = false

    public init(
        progress: BudgetProgress,
        currency: String,
        diameter: CGFloat = 86,
        thickness: CGFloat = 9
    ) {
        self.progress = progress
        self.currency = currency
        self.diameter = diameter
        self.thickness = thickness
    }

    private var swept: Double { min(progress.progress, 1) }
    /// How far past the limit, as a fraction of the limit, capped at a full
    /// second lap — beyond that the ring has said all it can.
    private var overshoot: Double { min(max(progress.progress - 1, 0), 1) }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: thickness)

            Circle()
                .trim(from: 0, to: drawn ? swept : 0)
                .stroke(
                    progress.health.tint,
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if overshoot > 0 {
                Circle()
                    .trim(from: 0, to: drawn ? overshoot : 0)
                    .stroke(
                        Palette.danger,
                        style: StrokeStyle(lineWidth: thickness * 0.55, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.danger.opacity(0.5), radius: 4)
            }

            VStack(spacing: 1) {
                Image(systemName: progress.category.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progress.category.tint)
                Text(progress.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: progress.progress))
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(Motion.spring, value: progress)
        .onAppear { withAnimation(Motion.celebrate.delay(0.05)) { drawn = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(progress.category.title))
        .accessibilityValue(Text(L10n.financeBudgetSpentOf(
            Money.text(progress.spent, currency: currency),
            Money.text(progress.limit, currency: currency)
        )))
    }
}

// MARK: - Split preview

/// How one expense lands on the household, as a single stacked line.
///
/// The composer's most useful control is not a control: it is this, updating as
/// the split is edited, so "two shares each and one for the lodger" stops being
/// an abstraction before anybody presses save.
public struct SplitBar: View {
    private let splits: [ExpenseSplit]
    private let total: Int
    private let height: CGFloat

    /// Gap between segments. Small enough that a 3% sliver is still its own
    /// block rather than merging into its neighbour.
    private static let gap: CGFloat = 2

    public init(splits: [ExpenseSplit], total: Int, height: CGFloat = 10) {
        self.splits = splits
        self.total = total
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let visible = splits.filter { $0.amount > 0 }
            let available = max(
                0,
                geo.size.width - Self.gap * CGFloat(max(visible.count - 1, 0))
            )
            HStack(spacing: Self.gap) {
                ForEach(visible) { split in
                    Capsule(style: .continuous)
                        .fill(MemberTint.color(for: split.userID.rawValue))
                        // A share below about 2% rounds to nothing at this
                        // width; a floor keeps the person on the bar instead of
                        // erasing them.
                        .frame(width: max(3, available * fraction(of: split)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .background(Capsule(style: .continuous).fill(.quaternary))
        .clipShape(Capsule(style: .continuous))
        .animation(Motion.spring, value: splits)
        .accessibilityHidden(true)
    }

    private func fraction(of split: ExpenseSplit) -> Double {
        total > 0 ? Double(split.amount) / Double(total) : 0
    }
}

// MARK: - Trend

/// A tiny line for a run of values — the shape of the last six months, sitting
/// beside the number it explains.
///
/// Deliberately axis-less and label-less: it is a sparkline, and the moment it
/// grows a scale it is competing with the chart it was meant to summarise.
public struct Sparkline: View {
    private let values: [Int]
    private let tint: Color

    @State private var drawn = false

    public init(values: [Int], tint: Color) {
        self.values = values
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            let points = normalised(in: geo.size)
            ZStack {
                if points.count > 1 {
                    // The fill under the line, which is what makes a 20pt-tall
                    // shape read as a trend rather than as a scratch.
                    path(points, closed: true, in: geo.size)
                        .fill(tint.opacity(0.18))
                    path(points, closed: false, in: geo.size)
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { drawn = true } }
        .accessibilityHidden(true)
    }

    private func normalised(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let low = Double(values.min() ?? 0)
        let high = Double(values.max() ?? 1)
        let span = max(high - low, 1)
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * step,
                y: size.height * (1 - CGFloat((Double(value) - low) / span))
            )
        }
    }

    private func path(_ points: [CGPoint], closed: Bool, in size: CGSize) -> Path {
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        if closed {
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Celebration

/// The one genuinely playful moment on this screen: everything squares up.
///
/// A burst of chips that rise, drift and fade. Driven by the timeline's own
/// clock rather than by an animated `@State` value, because `withAnimation`
/// interpolates *view* properties and not the stored number a `Canvas` reads —
/// animating the progress that way would hand every frame the final value and
/// draw nothing at all. `task(id:)` owns the flight, so it cancels cleanly when
/// the view goes away mid-burst and never leaves a timer behind.
public struct ConfettiBurst: View {
    private let trigger: Int
    private let tints: [Color]

    @State private var startedAt: Date?
    @State private var seed = 0

    /// Enough to read as a burst, few enough that a mid-range phone never drops
    /// a frame drawing it.
    private static let count = 18
    private static let duration: TimeInterval = 1.1

    /// - Parameter trigger: increment to fire. Starts at zero, which fires
    ///   nothing — the burst belongs to an event, not to the view appearing.
    public init(
        trigger: Int,
        tints: [Color] = [Palette.success, Palette.amber, Palette.cyan, Palette.violet]
    ) {
        self.trigger = trigger
        self.tints = tints
    }

    public var body: some View {
        TimelineView(.animation(paused: startedAt == nil)) { timeline in
            Canvas { context, size in
                guard let startedAt else { return }
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                let linear = min(max(elapsed / Self.duration, 0), 1)
                guard linear < 1 else { return }
                // Eased out, so the chips leave fast and settle slowly.
                let progress = CGFloat(1 - pow(1 - linear, 2))

                for index in 0..<Self.count {
                    let flight = Flight(index: index, seed: seed, size: size)
                    let x = size.width / 2 + flight.drift * progress * size.width * 0.4
                    let y = size.height / 2
                        - flight.reach * progress
                        + flight.gravity * progress * progress
                    var chip = context
                    chip.opacity = Double(1 - progress)
                    chip.translateBy(x: x, y: y)
                    chip.rotate(by: .radians(Double(flight.spin * progress)))
                    chip.fill(
                        Path(
                            roundedRect: CGRect(x: -3, y: -4.5, width: 6, height: 9),
                            cornerRadius: 1.5
                        ),
                        with: .color(tints[index % tints.count])
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: trigger) {
            guard trigger > 0 else { return }
            seed &+= 1
            startedAt = .now
            // Stops the timeline again once the burst is spent; a `TimelineView`
            // left unpaused redraws at display rate forever.
            try? await Task.sleep(for: .seconds(Self.duration))
            startedAt = nil
        }
    }

    /// One chip's flight, derived from its index and the burst's seed so a
    /// single burst is stable frame to frame while two bursts differ.
    private struct Flight {
        let drift: CGFloat
        let reach: CGFloat
        let gravity: CGFloat
        let spin: CGFloat

        init(index: Int, seed: Int, size: CGSize) {
            // A cheap hash, not a random number generator: the canvas redraws
            // every frame, and drawing fresh randomness each time would shake
            // the chips rather than fly them.
            let hash = UInt64(bitPattern: Int64(index &* 2_654_435_761 &+ seed &* 40_503))
            let a = Double(hash % 1000) / 1000
            let b = Double((hash / 1000) % 1000) / 1000
            let c = Double((hash / 1_000_000) % 1000) / 1000
            drift = CGFloat(a * 2 - 1)
            reach = CGFloat(size.height * (0.25 + 0.45 * b))
            gravity = CGFloat(size.height * (0.5 + 0.5 * c))
            spin = CGFloat(6 * (a - 0.5) * .pi)
        }
    }
}
