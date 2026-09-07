import SwiftUI

// The calendar's own visual vocabulary: the month grid, the week timeline, and
// the row an event is drawn as everywhere else.
//
// They live in Design/Components rather than in the feature for the same reason
// `FinanceCharts` does — they are pure views over values, they hold no store,
// and they are the pieces most likely to be reused by whatever shows an event
// next.

// MARK: - The month, as a grid of days

/// Six weeks of days, aligned to the reader's own first weekday.
///
/// Always six, even for a month that fits in five. A grid that changes height
/// between March and April makes the whole screen jump on every scrub, and the
/// jump is far more distracting than one row of greyed-out days.
public struct MonthGrid: Equatable, Sendable {
    public let month: CalendarMonth
    /// 42 days, in order.
    public let days: [CalendarDay]

    public init(month: CalendarMonth, calendar: Calendar = .current) {
        self.month = month
        let first = CalendarDay(year: month.year, month: month.month, day: 1)
        let firstDate = first.date(calendar)
        // `firstWeekday` is 1-based with 1 = Sunday; `component(.weekday:)` uses
        // the same scale, so the offset is the plain difference, wrapped.
        let weekday = calendar.component(.weekday, from: firstDate)
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        let start = first.advanced(by: -lead, calendar: calendar)

        var days: [CalendarDay] = []
        days.reserveCapacity(42)
        var cursor = start
        for _ in 0..<42 {
            days.append(cursor)
            cursor = cursor.advanced(by: 1, calendar: calendar)
        }
        self.days = days
    }

    public func isInMonth(_ day: CalendarDay) -> Bool {
        day.year == month.year && day.month == month.month
    }

    /// The seven days of the week containing `day`, in the reader's week order.
    public static func week(containing day: CalendarDay, calendar: Calendar = .current) -> [CalendarDay] {
        let weekday = calendar.component(.weekday, from: day.date(calendar))
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        let start = day.advanced(by: -lead, calendar: calendar)
        return (0..<7).map { start.advanced(by: $0, calendar: calendar) }
    }

    /// Column headings — "M T W T F S S" — in the reader's own order and
    /// language. From `Calendar`, not the string catalogue: the system already
    /// has these correct everywhere, and a hand-maintained copy would be one
    /// more thing to get wrong per locale.
    public static var weekdayHeadings: [String] {
        var calendar = Calendar.current
        calendar.locale = L10n.locale
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + first) % symbols.count] }
    }

    /// Whether a day falls on the locale's weekend, so the grid can say so
    /// without the household having to count columns.
    public static func isWeekend(_ day: CalendarDay, calendar: Calendar = .current) -> Bool {
        calendar.isDateInWeekend(day.date(calendar))
    }
}

// MARK: - One day in the grid

/// A single cell: the date, up to three dots for what is on, and the states
/// that matter — today, selected, outside the month.
public struct DayCell: View {
    private let day: CalendarDay
    private let kinds: [EventKind]
    private let extra: Int
    private let isInMonth: Bool
    private let isSelected: Bool
    private let isToday: Bool
    private let namespace: Namespace.ID
    private let action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        day: CalendarDay,
        kinds: [EventKind],
        extra: Int = 0,
        isInMonth: Bool,
        isSelected: Bool,
        isToday: Bool,
        namespace: Namespace.ID,
        action: @escaping () -> Void
    ) {
        self.day = day
        self.kinds = kinds
        self.extra = extra
        self.isInMonth = isInMonth
        self.isSelected = isSelected
        self.isToday = isToday
        self.namespace = namespace
        self.action = action
    }

    private var numberColour: Color {
        if isSelected { return .white }
        if !isInMonth { return Color.secondary.opacity(0.4) }
        if isToday { return theme.accent }
        return .primary
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // The selection is one shape that slides between cells
                    // rather than one per cell fading in and out — the movement
                    // is what tells you where you came from.
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "calendarDay", in: namespace)
                    } else if isToday {
                        Circle().strokeBorder(theme.accent.opacity(0.5), lineWidth: 1.5)
                    }
                    Text(day.day, format: .number)
                        .font(.system(
                            .subheadline,
                            design: .rounded,
                            weight: isToday || isSelected ? .bold : .medium
                        ))
                        .foregroundStyle(numberColour)
                        .monospacedDigit()
                }
                .frame(width: 32, height: 32)

                // Fixed height whether or not there are dots, so a day filling
                // up does not nudge the row below it.
                HStack(spacing: 3) {
                    ForEach(Array(kinds.enumerated()), id: \.offset) { index, kind in
                        Circle()
                            .fill(kind.tint)
                            .frame(width: 5, height: 5)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .scale.combined(with: .opacity)
                            )
                            .zIndex(Double(index))
                    }
                    if extra > 0 {
                        Text("+\(extra)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 6)
                .animation(Motion.spring, value: kinds)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isInMonth ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.date().formatted(
            Date.FormatStyle(date: .complete, time: .omitted).locale(L10n.locale)
        )))
        .accessibilityValue(kinds.isEmpty
            ? Text(L10n.calendarNothingOn)
            : Text(L10n.calendarEventCount(kinds.count + extra)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - An event, as a row

/// The row an event is drawn as in the agenda, the day list and the detail
/// sheet's neighbours.
///
/// A coloured rail rather than a coloured card: at four events on a Saturday,
/// four tinted glass panels turn the screen into a paint chart, while four rails
/// against one surface still read as a list.
public struct EventRow: View {
    private let occurrence: EventOccurrence
    private let rsvp: RSVPStatus?
    private let attendees: [AvatarStack.Member]
    private let showsDate: Bool
    private let action: () -> Void

    @Environment(\.theme) private var theme

    public init(
        occurrence: EventOccurrence,
        rsvp: RSVPStatus? = nil,
        attendees: [AvatarStack.Member] = [],
        showsDate: Bool = false,
        action: @escaping () -> Void
    ) {
        self.occurrence = occurrence
        self.rsvp = rsvp
        self.attendees = attendees
        self.showsDate = showsDate
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Capsule()
                    .fill(occurrence.kind.tint)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: occurrence.kind.symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(occurrence.kind.tint)
                            // Bounces exactly once, when the event becomes the
                            // one that is happening. Nothing else on the row
                            // moves, so it reads as "this, now".
                            .bounces(when: occurrence.isInProgress)
                        Text(occurrence.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if occurrence.isRecurring {
                            Image(systemName: "repeat")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Palette.accessory)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(showsDate ? dateAndTime : occurrence.timeText)
                            .font(.caption)
                            .foregroundStyle(occurrence.isInProgress ? theme.accent : .secondary)
                            .monospacedDigit()
                        if let location = occurrence.location, !location.isEmpty {
                            Text("·").foregroundStyle(.tertiary)
                            Label {
                                Text(location).lineLimit(1)
                            } icon: {
                                Image(systemName: "mappin")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if !planBadges.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(planBadges, id: \.self) { section in
                                Image(systemName: section.symbol)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(section.tint)
                                    .padding(4)
                                    .background(section.tint.opacity(0.14), in: .circle)
                            }
                        }
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 6) {
                    if let rsvp {
                        Image(systemName: rsvp.symbol)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(rsvp.tint)
                            // Replaces rather than cross-fades, so changing your
                            // mind reads as the glyph turning into the other one.
                            .contentTransition(.symbolEffect(.replace))
                    }
                    if !attendees.isEmpty {
                        AvatarStack(members: attendees, size: 20, maxVisible: 3)
                    }
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .opacity(occurrence.isPast ? 0.55 : 1)
        .animation(Motion.fade, value: rsvp)
        .accessibilityElement(children: .combine)
    }

    /// What the row can say about the plan without a second query: an event
    /// carries its own budget and menu, so those two are free. What has been
    /// *spent* and *bought* needs the rollup, and belongs on the detail screen.
    private var planBadges: [PlanSection] {
        var badges: [PlanSection] = []
        if occurrence.budget != nil { badges.append(.budget) }
        if !occurrence.recipeIDs.isEmpty { badges.append(.menu) }
        if occurrence.url?.isEmpty == false { badges.append(.tickets) }
        return badges
    }

    private var dateAndTime: String {
        let date = occurrence.start.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)
        )
        return occurrence.isAllDay ? date : "\(date) · \(occurrence.timeText)"
    }
}

// MARK: - The week, as a timeline

/// A day laid out against the clock, with overlapping events sharing the width.
///
/// The only view in the calendar that is about *duration* rather than order,
/// which is the whole reason it exists: "Thursday is solid from six" is a shape,
/// not a list.
public struct DayTimeline: View {
    private let day: CalendarDay
    private let occurrences: [EventOccurrence]
    private let action: (EventOccurrence) -> Void

    @Environment(\.theme) private var theme

    /// Tall enough that a half-hour block still has room for a title, short
    /// enough that a working day is one scroll.
    private let hourHeight: CGFloat = 52
    private let gutter: CGFloat = 46

    public init(
        day: CalendarDay,
        occurrences: [EventOccurrence],
        action: @escaping (EventOccurrence) -> Void
    ) {
        self.day = day
        self.occurrences = occurrences
        self.action = action
    }

    private var allDay: [EventOccurrence] { occurrences.filter(\.isAllDay) }
    private var timed: [EventOccurrence] { occurrences.filter { !$0.isAllDay } }

    /// The hours actually worth drawing.
    ///
    /// A calendar that always starts at midnight spends its first third on
    /// hours nobody has ever booked. This starts an hour before the earliest
    /// event and ends an hour after the latest, widened to at least 08:00–22:00
    /// so an empty day still looks like a day.
    private var hourRange: ClosedRange<Int> {
        let calendar = Calendar.current
        var lower = 8
        var upper = 22
        for occurrence in timed {
            lower = min(lower, calendar.component(.hour, from: occurrence.start))
            let endHour = calendar.component(.hour, from: occurrence.end)
            let endMinute = calendar.component(.minute, from: occurrence.end)
            upper = max(upper, endMinute > 0 ? endHour + 1 : endHour)
        }
        return max(0, lower - 1)...min(24, max(upper + 1, lower + 4))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !allDay.isEmpty {
                allDayBand
            }
            timeline
        }
    }

    private var allDayBand: some View {
        VStack(spacing: 6) {
            ForEach(allDay) { occurrence in
                Button { action(occurrence) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: occurrence.kind.symbol)
                            .font(.caption2.weight(.semibold))
                        Text(occurrence.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(L10n.calendarAllDay)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(occurrence.kind.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        occurrence.kind.tint.opacity(0.14),
                        in: .rect(cornerRadius: 10, style: .continuous)
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private var timeline: some View {
        let hours = Array(hourRange)
        let height = CGFloat(hours.count) * hourHeight

        return ZStack(alignment: .topLeading) {
            // Hour rules and labels.
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 8) {
                        Text(label(for: hour))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: gutter - 8, alignment: .trailing)
                        Rectangle()
                            .fill(Color.primary.opacity(0.07))
                            .frame(height: 1)
                    }
                    .frame(height: hourHeight, alignment: .top)
                }
            }

            // The blocks.
            ForEach(laidOut, id: \.occurrence.id) { placed in
                block(placed, origin: hours.first ?? 0)
            }

            if let now = nowOffset(in: hourRange) {
                nowLine.offset(y: now)
            }
        }
        .frame(height: height, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private var nowLine: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Palette.danger)
                .frame(width: 7, height: 7)
                // The one endlessly-repeating animation the calendar allows
                // itself, and there is never more than one on screen: the point
                // of the line is that it is alive.
                .pulse()
            Rectangle()
                .fill(Palette.danger)
                .frame(height: 1.5)
        }
        .padding(.leading, gutter - 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func block(_ placed: Placed, origin: Int) -> some View {
        let calendar = Calendar.current
        let startOfDay = day.date(calendar)
        let minutes = placed.occurrence.start.timeIntervalSince(startOfDay) / 60
        let top = (minutes / 60 - Double(origin)) * hourHeight
        // A fifteen-minute event still needs to be readable and still needs to
        // be tappable, so blocks have a floor rather than a true height.
        let raw = placed.occurrence.duration / 3600 * Double(hourHeight)
        let height = max(28, raw - 2)

        return GeometryReader { proxy in
            let usable = proxy.size.width - gutter
            let width = usable / CGFloat(placed.lanes)
            Button { action(placed.occurrence) } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(placed.occurrence.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(height > 40 ? 2 : 1)
                    if height > 40 {
                        Text(placed.occurrence.timeText)
                            .font(.system(size: 10))
                            .opacity(0.8)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(placed.occurrence.kind.tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    placed.occurrence.kind.tint.opacity(0.16),
                    in: .rect(cornerRadius: 8, style: .continuous)
                )
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(placed.occurrence.kind.tint)
                        .frame(width: 3)
                        .padding(.vertical, 3)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .frame(width: max(40, width - 3), height: height)
            .offset(x: gutter + width * CGFloat(placed.lane), y: max(0, top))
        }
        .frame(height: 0, alignment: .topLeading)
    }

    private func label(for hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour % 24
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale)
        )
    }

    /// Where "now" falls, or `nil` if it is not this day or not in view.
    private func nowOffset(in range: ClosedRange<Int>) -> CGFloat? {
        let calendar = Calendar.current
        guard CalendarDay(Date(), calendar: calendar) == day else { return nil }
        let minutes = Date().timeIntervalSince(day.date(calendar)) / 60
        let offset = (minutes / 60 - Double(range.lowerBound)) * hourHeight
        let height = CGFloat(range.count) * hourHeight
        guard offset >= 0, offset <= height else { return nil }
        return offset
    }

    private struct Placed {
        let occurrence: EventOccurrence
        /// Which column of the overlap group it sits in.
        let lane: Int
        /// How many columns that group needs.
        let lanes: Int
    }

    /// Assigns overlapping events to side-by-side columns.
    ///
    /// A greedy sweep rather than anything cleverer: events arrive sorted, a
    /// group is a run of them that overlaps, and each takes the first free
    /// column. Two events at six o'clock become two half-width blocks instead
    /// of one hiding under the other, which is the entire requirement.
    private var laidOut: [Placed] {
        let sorted = timed.sorted { $0.startsAt < $1.startsAt }
        var out: [Placed] = []
        var group: [EventOccurrence] = []
        var groupEnd: Date?

        func flush() {
            guard !group.isEmpty else { return }
            var lanes: [Date] = []          // when each column becomes free
            var assignment: [Int] = []
            for occurrence in group {
                if let free = lanes.firstIndex(where: { $0 <= occurrence.start }) {
                    lanes[free] = occurrence.end
                    assignment.append(free)
                } else {
                    lanes.append(occurrence.end)
                    assignment.append(lanes.count - 1)
                }
            }
            for (occurrence, lane) in zip(group, assignment) {
                out.append(Placed(occurrence: occurrence, lane: lane, lanes: lanes.count))
            }
            group = []
            groupEnd = nil
        }

        for occurrence in sorted {
            if let end = groupEnd, occurrence.start >= end {
                flush()
            }
            group.append(occurrence)
            groupEnd = max(groupEnd ?? occurrence.end, occurrence.end)
        }
        flush()
        return out
    }
}

// MARK: - Counting down

/// How long until something starts, kept current by the app's shared clock.
///
/// The mirror image of `RelativeTimeText`, which only ever looks backwards. One
/// timer for the whole app rather than a `TimelineView` per card, and no network
/// traffic at all — the date is already in hand, only the phrasing goes stale.
public struct CountdownText: View {
    private let date: Date

    public init(_ date: Date) { self.date = date }

    public var body: some View {
        // Reading the tick is what subscribes this view to it; the phrase is
        // computed against the real clock so a label that appears between two
        // ticks is still right to the minute it is drawn.
        let _ = RelativeTimeClock.shared.tick
        Text(CountdownText.phrase(for: date))
    }

    static func phrase(for date: Date, now: Date = .now) -> LocalizedStringResource {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return L10n.calendarHappeningNow }

        let minutes = Int(seconds) / 60
        if minutes < 1 { return L10n.calendarStartingNow }
        if minutes < 60 { return L10n.calendarInMinutes(minutes) }

        let hours = minutes / 60
        if hours < 24 { return L10n.calendarInHours(hours) }

        let days = hours / 24
        if days == 1 { return L10n.calendarTomorrow }
        if days < 30 { return L10n.calendarInDays(days) }
        return L10n.calendarInMonths(max(1, days / 30))
    }
}

// MARK: - Progress

/// A ring with a number in it: budget spent, shopping bought.
///
/// Two arcs and a label, sized for a card corner. `trim` rather than a `Gauge`
/// so the same shape can carry a currency, a fraction or a percentage without
/// the system's own formatting fighting the app's.
public struct PlanRing: View {
    private let progress: Double
    private let tint: Color
    private let symbol: String
    private let size: CGFloat
    private let isOver: Bool

    public init(
        progress: Double,
        tint: Color,
        symbol: String,
        size: CGFloat = 44,
        isOver: Bool = false
    ) {
        self.progress = progress
        self.tint = tint
        self.symbol = symbol
        self.size = size
        self.isOver = isOver
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: size * 0.11)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    isOver ? Palette.danger : tint,
                    style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(isOver ? Palette.danger : tint)
        }
        .frame(width: size, height: size)
        .animation(Motion.spring, value: progress)
        .accessibilityHidden(true)
    }
}
