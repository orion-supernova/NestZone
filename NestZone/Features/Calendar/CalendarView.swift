import ComposableArchitecture
import SwiftUI

/// Calendar & Events.
///
/// One window, three resolutions. The month grid is for "when is that", the
/// week timeline is for "how full is Thursday", and the agenda is for "what is
/// coming" — so they share a scrubber, a filter row and a subscription, and swap
/// as a zoom rather than a slide. They are three views of one month, not three
/// places, so changing between them reads as moving closer or further away,
/// never sideways.
public struct CalendarView: View {
    @Bindable var store: StoreOf<CalendarFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var daySelection
    @Namespace private var modePill
    /// The row with its delete button showing, if any. Held here rather than in
    /// each row so opening one closes the last, as the system list does.
    @State private var revealedID: EventOccurrence.ID?
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    /// Which way the last switch between faces went — see `FaceZoom`.
    @State private var zoom = FaceZoom()
    /// The month grid's frame inside its own face, so a zoom to or from the
    /// month can centre on the selected day's cell.
    @State private var gridFrame: CGRect?
    /// Your own answers on the next-up card — see `RSVPTaps`.
    @State private var rsvpTaps = RSVPTaps()

    public init(store: StoreOf<CalendarFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.sectionSpacing) {
                monthScrubber
                modePicker
                if isSearching { searchField }
                if store.state.showsFilterRow { filterRow }

                // Overlaid rather than stacked. In the lazy stack the face on its
                // way out and the one on its way in sat one above the other for
                // the length of the transition, so the new face arrived a whole
                // screen down and jumped up when the old one left.
                ZStack(alignment: .top) {
                    // Any filter replaces the calendar rather than thinning it
                    // in place.
                    //
                    // The grid and the timeline are both about *one day*, so a
                    // filter could only ever remove dots from days nobody was
                    // looking at: picking "house party" while sitting on today
                    // emptied the panel under the grid and left Saturday's
                    // party reachable only by spotting its dot and tapping the
                    // right cell. Asking for a subset should show you the
                    // subset.
                    if store.state.isFiltering {
                        resultsPage
                            .transition(.opacity.combined(with: .offset(y: 10)))
                    } else {
                        // Nested, so a filter coming on or off cross-fades the
                        // whole calendar away while a change of face zooms —
                        // the zoom only ever runs between two faces.
                        ZStack(alignment: .top) {
                            modeFace
                                // Each face is its own view, not three states of
                                // one. Without the id all three share an
                                // identity, so SwiftUI swaps the content in
                                // place, the transition never has an insertion
                                // to run, and none of the `appear` staggers
                                // inside it ever see a second `onAppear` —
                                // switching to an empty week looks like nothing
                                // happened at all.
                                .id(store.mode)
                                .transition(FaceZoomTransition(zoom: zoom, reduceMotion: reduceMotion))
                        }
                        .transition(.opacity.combined(with: .offset(y: 10)))
                    }
                }
            }
            .padding(.bottom, Metrics.scrollBottomInset)
            .animation(Motion.spring, value: store.mode)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.managementModuleCalendarTitle))
        .navigationBarTitleDisplayMode(.inline)
        .segmentToolbar {
            ToolbarItem(placement: .topBarLeading) { searchToggle }
            ToolbarItem(placement: .primaryAction) { historyButton }
            ToolbarItem(placement: .primaryAction) { addButton }
        }
        .safeAreaInset(edge: .bottom) {
            if let pending = store.pendingDeletion {
                UndoToast(L10n.calendarEventDeleted(pending.occurrence.title)) {
                    store.send(.undoDeleteTapped)
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: store.pendingDeletion)
        .animation(Motion.spring, value: isSearching)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(
            state: \.destination?.compose,
            action: \.destination.compose
        )) { store in
            EventComposerSheet(store: store)
        }
        .sheet(item: $store.scope(
            state: \.destination?.detail,
            action: \.destination.detail
        )) { store in
            EventDetailSheet(store: store)
        }
        .sheet(item: $store.scope(
            state: \.destination?.history,
            action: \.destination.history
        )) { store in
            EventHistorySheet(store: store)
        }
    }

    // MARK: - Chrome

    /// Where finished events go: a year of them, and what they came to.
    private var historyButton: some View {
        Button { store.send(.historyTapped) } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .accessibilityLabel(Text(L10n.calendarHistoryTitle))
    }

    private var addButton: some View {
        Button { store.send(.addTapped) } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel(Text(L10n.calendarAddEvent))
    }

    private var searchToggle: some View {
        Button {
            withAnimation(Motion.spring) { isSearching.toggle() }
            if isSearching {
                isSearchFocused = true
            } else {
                store.send(.binding(.set(\.search, "")))
            }
        } label: {
            Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                // The glyph turns into the other one rather than cross-fading,
                // which is what says the button is a toggle.
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(Text(isSearching ? L10n.commonCancel : L10n.commonSearch))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField(text: $store.search) {
                Text(L10n.calendarSearchPlaceholder)
            }
            .focused($isSearchFocused)
            .segmentFocus($isSearchFocused)
            .font(.subheadline)
            .submitLabel(.search)
            // Always in the hierarchy, faded rather than inserted.
            //
            // As a conditional it was added to the row on the first keystroke,
            // inside an animation, which makes SwiftUI re-lay-out and re-commit
            // the text field's binding — two `.binding` actions for one letter.
            // It also moved the field's trailing edge under the caret while
            // somebody was typing into it.
            Button {
                store.send(.binding(.set(\.search, "")))
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Palette.accessory)
            }
            .buttonStyle(.plain)
            .opacity(store.search.isEmpty ? 0 : 1)
            .disabled(store.search.isEmpty)
            .accessibilityHidden(store.search.isEmpty)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(Motion.spring, value: store.search.isEmpty)
    }

    /// The month everything on this screen is about.
    ///
    /// Tapping the name jumps to today, which is the only destination anybody
    /// scrubs *to*. Unlike the ledger's, this one steps forward without limit —
    /// a calendar is mostly about the future, and stopping at the current month
    /// would make it useless.
    private var monthScrubber: some View {
        HStack(spacing: 4) {
            stepper(-1, symbol: "chevron.left", label: L10n.calendarPreviousMonth)

            Button { store.send(.todayTapped) } label: {
                VStack(spacing: 1) {
                    Text(store.month.date, format: .dateTime.month(.wide).year())
                        .font(.headline)
                        .contentTransition(.numericText())
                    if !store.month.isCurrent {
                        Text(L10n.calendarJumpToToday)
                            .font(.caption2)
                            .foregroundStyle(theme.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .disabled(store.month.isCurrent && store.selectedDay == .today)

            stepper(1, symbol: "chevron.right", label: L10n.calendarNextMonth)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.month)
        .sensoryFeedback(.selection, trigger: store.month)
    }

    private func stepper(
        _ step: Int,
        symbol: String,
        label: LocalizedStringResource
    ) -> some View {
        Button { store.send(.monthStepped(by: step)) } label: {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.accessoryStrong)
                .frame(width: Metrics.minTapTarget, height: 34)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(label))
    }

    /// The three faces, as a sliding pill.
    ///
    /// Hand-rolled rather than a `.segmented` picker, for the reason the Finance
    /// screen's is: the pill has to carry the theme accent and glide between
    /// slots, and a system segmented control on glass draws its own opaque track
    /// underneath the blur.
    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(CalendarFeature.State.Mode.allCases) { mode in
                let isSelected = store.mode == mode
                Button { switchFace(to: mode) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.symbol)
                            .font(.caption2.weight(.semibold))
                            // The icon you just chose acknowledges the tap; the
                            // one you left goes quiet without a fuss.
                            .bounces(when: isSelected)
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    // Each slot only marks where the pill can land.
                    .matchedGeometryEffect(id: mode, in: modePill)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        // One pill for the whole control rather than one per slot: a pill that
        // is a different view in every slot can glide between them, but it
        // cannot stretch on the way, because nothing lives through the move.
        .background {
            Capsule()
                .fill(theme.accent)
                .matchedGeometryEffect(id: store.mode, in: modePill, isSource: false)
                // Pulled across rather than slid: a quarter wider mid-way,
                // settling back to its slot as it lands.
                .keyframeAnimator(
                    initialValue: CGFloat(1),
                    trigger: reduceMotion ? nil : store.mode
                ) { pill, stretch in
                    pill.scaleEffect(x: stretch, y: 1)
                } keyframes: { _ in
                    CubicKeyframe(1.25, duration: 0.14)
                    SpringKeyframe(1, duration: 0.28, spring: .init(duration: 0.3, bounce: 0.3))
                }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.mode)
        // The mode is this screen's own state — nothing pushed from the server
        // moves it — so the tick can key on it directly.
        .sensoryFeedback(.selection, trigger: store.mode)
    }

    /// Records which way the zoom goes, then switches.
    ///
    /// The order matters: both faces read `zoom` while their transitions run,
    /// and the switch is what starts them.
    private func switchFace(to mode: CalendarFeature.State.Mode) {
        let from = store.mode
        guard mode != from else { return }
        // Month, week, agenda: widest to narrowest, so a step to the right is a
        // step in.
        let order = CalendarFeature.State.Mode.allCases
        zoom.inward = (order.firstIndex(of: mode) ?? 0) > (order.firstIndex(of: from) ?? 0)
        zoom.pivot = mode == .month || from == .month ? monthPivot : nil
        store.send(.modeSelected(mode))
    }

    /// The selected day's cell, in the month face's own coordinates.
    ///
    /// `nil` until the grid has been on screen once — a calendar opened on the
    /// agenda has no cell to measure, and zooms about the middle instead.
    private var monthPivot: CGPoint? {
        let days = store.grid.days
        guard let frame = gridFrame,
              let index = days.firstIndex(of: store.selectedDay) else { return nil }
        let rows = CGFloat((days.count + 6) / 7)
        return CGPoint(
            x: frame.minX + frame.width * (CGFloat(index % 7) + 0.5) / 7,
            y: frame.minY + frame.height * (CGFloat(index / 7) + 0.5) / rows
        )
    }

    private var filterRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if store.state.canFilterMine || store.onlyMine {
                        Chip(
                            String(localized: L10n.calendarOnlyMine),
                            symbol: store.onlyMine ? "person.fill.checkmark" : "person",
                            isSelected: store.onlyMine
                        ) {
                            store.send(.onlyMineToggled)
                        }
                    }

                    if store.state.canFilterNeedsAnswer || store.needsAnswer {
                        Chip(
                            String(localized: L10n.calendarFilterNeedsAnswer),
                            symbol: "questionmark.circle",
                            isSelected: store.needsAnswer
                        ) {
                            store.send(.needsAnswerToggled)
                        }
                    }

                    if store.state.canFilterPlanned || store.withPlan {
                        Chip(
                            String(localized: L10n.calendarFilterHasPlan),
                            symbol: "list.bullet.clipboard",
                            isSelected: store.withPlan
                        ) {
                            store.send(.withPlanToggled)
                        }
                    }

                    ForEach(store.presentKinds) { kind in
                        Chip(
                            String(localized: kind.title),
                            symbol: kind.symbol,
                            isSelected: store.kindFilter == kind
                        ) {
                            store.send(.kindFilterTapped(kind))
                        }
                    }

                    if store.state.isFiltering {
                        Chip(
                            String(localized: L10n.calendarClearFilters),
                            symbol: "xmark"
                        ) {
                            store.send(.filtersCleared)
                        }
                    }
                }
                // Room for the press effect to grow into. A chip lifts and
                // scales under a long press, and inside a horizontal ScrollView
                // that overflow is clipped to the row's own height — so a held
                // chip came out shaved off at the top and bottom.
                .padding(.vertical, 6)
                .padding(.horizontal, Metrics.screenPadding)
            }
            .scrollIndicators(.hidden)
            // The other half of the same problem: the clip happens at the
            // scroll view's bounds, so the padding above only helps once the
            // view is allowed to draw outside them.
            .scrollClipDisabled()

            // What the filters actually did.
            //
            // Without this a filter that removes nothing is indistinguishable
            // from one that is broken — and both of these are often no-ops on
            // real data, because "just mine" counts events you created and in
            // most households that is all of them.
            if store.state.isFiltering {
                Text(L10n.calendarFilterCount(
                    store.state.visibleCount, store.state.totalCount
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .padding(.horizontal, Metrics.screenPadding)
                .transition(.opacity)
            }
        }
        .animation(Motion.spring, value: store.kindFilter)
        .animation(Motion.spring, value: store.onlyMine)
        // No tick of its own: every filter here is a `Chip`, which ticks on
        // its own taps.
    }

    /// Whichever of the three faces the picker is on.
    @ViewBuilder
    private var modeFace: some View {
        switch store.mode {
        case .month: monthPage
        case .week: weekPage
        case .agenda: agendaPage
        }
    }

    // MARK: - Month

    @ViewBuilder
    private var monthPage: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            GlassCard(padding: 12) {
                VStack(spacing: 6) {
                    weekdayHeadings
                    grid
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            // A horizontal drag anywhere on the grid changes the month, which is
            // the gesture everybody tries first. Simultaneous rather than
            // exclusive, so a vertical scroll that starts on the grid still
            // reaches the scroll view.
            .simultaneousGesture(monthSwipe)

            dayPanel
                .padding(.horizontal, Metrics.screenPadding)
        }
        // The grid is measured against the face itself, inside the zoom, so the
        // measurement holds still while the face scales around it.
        .coordinateSpace(.named(monthFaceSpace))
    }

    private var weekdayHeadings: some View {
        HStack(spacing: 0) {
            ForEach(Array(MonthGrid.weekdayHeadings.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let grid = store.grid
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
            ForEach(grid.days) { day in
                let kinds = store.state.dots(on: day)
                DayCell(
                    day: day,
                    kinds: kinds,
                    extra: max(0, store.state.count(on: day) - kinds.count),
                    isInMonth: grid.isInMonth(day),
                    isSelected: day == store.selectedDay,
                    isToday: day == .today,
                    namespace: daySelection
                ) {
                    store.send(.daySelected(day))
                }
            }
        }
        .animation(Motion.spring, value: store.selectedDay)
        .sensoryFeedback(.selection, trigger: store.selectedDay)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(monthFaceSpace))
        } action: { gridFrame = $0 }
        // The whole grid is redrawn when the month changes, and the redraw is
        // the transition: cells cross-fade rather than sliding, because the
        // dates underneath them have changed identity entirely.
        .transition(.opacity)
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) * 1.5,
                      abs(horizontal) > 50 else { return }
                store.send(.monthStepped(by: horizontal < 0 ? 1 : -1))
            }
    }

    /// What is on the selected day, under the grid.
    private var dayPanel: some View {
        let items = store.state.occurrences(on: store.selectedDay)
        return VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayHeading(store.selectedDay))
                        .font(.title3.weight(.semibold))
                        .contentTransition(.numericText())
                    if !items.isEmpty {
                        Text(L10n.calendarEventCount(items.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                Spacer(minLength: 8)
                Button { store.send(.addOnDayTapped(store.selectedDay)) } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.bold))
                        .frame(width: 32, height: 32)
                        .contentShape(.circle)
                }
                .buttonStyle(.pressable)
                .glassEffect(.regular.tint(theme.accent.opacity(0.2)).interactive(), in: .circle)
                .accessibilityLabel(Text(L10n.calendarAddEvent))
            }

            if store.isLoading {
                SkeletonList(rows: 2, height: 72)
            } else if items.isEmpty {
                emptyDay
            } else {
                eventList(items, showsDate: false)
            }
        }
        .animation(Motion.spring, value: items.map(\.id))
    }

    /// Everything the active filters keep, wherever it falls in the window.
    ///
    /// One page for search and for the chips, because they are the same
    /// question asked two ways: "show me the subset". The calendar and the
    /// day panel are hidden while it is up — a grid is for browsing a month,
    /// and neither of them can show a match that is not on the selected day.
    private var resultsPage: some View {
        let results = store.state.matches
        return VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            if store.isLoading {
                SkeletonList(rows: 4, height: 76)
                    .padding(.horizontal, Metrics.screenPadding)
            } else if results.isEmpty {
                EmptyStateView(
                    title: L10n.calendarNoMatches,
                    message: store.state.isSearchActive
                        ? L10n.calendarSearchNoMatchesMessage
                        : L10n.calendarNoMatchesMessage,
                    symbol: store.state.isSearchActive
                        ? "magnifyingglass"
                        : "line.3.horizontal.decrease.circle",
                    action: .init(title: L10n.calendarClearFilters) {
                        store.send(.filtersCleared)
                    },
                    isCompact: true
                )
                .padding(.top, 12)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.calendarSearchResults(results.count))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer(minLength: 8)
                    Button { store.send(.filtersCleared) } label: {
                        Text(L10n.calendarClearFilters).font(.caption2.weight(.medium))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(.horizontal, Metrics.screenPadding)

                // Dated, because a match three weeks out is the normal case and
                // "Thursday" alone does not say which Thursday.
                eventList(results, showsDate: true)
                    .padding(.horizontal, Metrics.screenPadding)
            }
        }
        .animation(Motion.spring, value: results.map(\.id))
    }

    private var emptyDay: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(theme.accent.opacity(0.7))
                .bounces()
            Text(store.isFiltering ? L10n.calendarNoMatches : L10n.calendarNothingOn)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // MARK: - Week

    @ViewBuilder
    private var weekPage: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            weekStrip
            GlassCard(padding: 14) {
                if store.isLoading {
                    SkeletonList(rows: 4, height: 44)
                } else {
                    DayTimeline(
                        day: store.selectedDay,
                        occurrences: store.state.occurrences(on: store.selectedDay)
                    ) { occurrence in
                        store.send(.eventTapped(occurrence.id))
                    }
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 4) {
            ForEach(store.state.visibleWeek) { day in
                let isSelected = day == store.selectedDay
                let count = store.state.count(on: day)
                Button { store.send(.daySelected(day)) } label: {
                    VStack(spacing: 4) {
                        Text(weekdayLetter(day))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.8) : .secondary)
                        Text(day.day, format: .number)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(isSelected ? .white : (day == .today ? theme.accent : .primary))
                            .monospacedDigit()
                        // A bar rather than dots: at week resolution the useful
                        // signal is "how much", not "what kind".
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.8) : theme.accent.opacity(0.6))
                            .frame(width: 14, height: 3)
                            .opacity(count > 0 ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.accent)
                                .matchedGeometryEffect(id: "calendarWeekDay", in: daySelection)
                        }
                    }
                    .contentShape(.rect)
                }
                // The same squash as a day in the month grid.
                .buttonStyle(DayPressStyle())
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .rect(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.selectedDay)
        .sensoryFeedback(.selection, trigger: store.selectedDay)
    }

    // MARK: - Agenda

    @ViewBuilder
    private var agendaPage: some View {
        let days = store.state.agendaDays
        VStack(spacing: Metrics.sectionSpacing) {
            if let next = store.nextUp, !store.isFiltering {
                nextUpCard(next).appear(0)
            }

            if store.isLoading {
                SkeletonList(rows: 4, height: 76)
                    .padding(.horizontal, Metrics.screenPadding)
            } else if days.isEmpty {
                // A filtered-empty screen has to offer the way out. Before, it
                // said "No matches" and left the person to work out which of
                // the chips above was responsible for it.
                EmptyStateView(
                    title: store.isFiltering ? L10n.calendarNoMatches : L10n.calendarEmptyTitle,
                    message: store.isFiltering
                        ? L10n.calendarNoMatchesMessage
                        : L10n.calendarEmptyMessage,
                    symbol: store.isFiltering
                        ? "line.3.horizontal.decrease.circle"
                        : "calendar.badge.plus",
                    action: store.isFiltering
                        ? .init(title: L10n.calendarClearFilters) {
                            store.send(.filtersCleared)
                        }
                        : .init(title: L10n.calendarAddFirstEvent) {
                            store.send(.addTapped)
                        },
                    isCompact: true
                )
                .padding(.top, 12)
            } else {
                ForEach(Array(days.enumerated()), id: \.element.day) { index, section in
                    VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(dayHeading(section.day))
                                .font(.subheadline.weight(.semibold))
                            Text(section.day.date(), format: .dateTime.weekday(.wide))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            Badge("\(section.items.count)", tint: theme.accent)
                        }
                        eventList(section.items, showsDate: false)
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .appear(index + 1)
                }
            }
        }
    }

    /// The next thing that has not happened yet, with a live countdown.
    ///
    /// The one card that answers "what now" rather than "what then", so it is
    /// deliberately never filtered — hiding the next thing because somebody
    /// typed in the search box is a good way to miss it.
    private func nextUpCard(_ occurrence: EventOccurrence) -> some View {
        Button { store.send(.eventTapped(occurrence.id)) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: occurrence.kind.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(occurrence.kind.tint)
                        .bounces(when: occurrence.isInProgress)
                    Text(occurrence.isInProgress ? L10n.calendarHappeningNow : L10n.calendarNextUp)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    CountdownText(occurrence.start)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(occurrence.isInProgress ? Palette.danger : theme.accent)
                        .contentTransition(.numericText())
                }

                Text(occurrence.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 10) {
                    Label {
                        Text(occurrence.timeText)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    if let location = occurrence.location, !location.isEmpty {
                        Label {
                            Text(location).lineLimit(1)
                        } icon: {
                            Image(systemName: "mappin.and.ellipse")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if !occurrence.going.isEmpty {
                        AvatarStack(members: avatars(for: occurrence.going), size: 24)
                    }
                }

                rsvpBar(for: occurrence)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassCard(tinted: occurrence.kind.tint.opacity(0.18))
        .padding(.horizontal, Metrics.screenPadding)
    }

    /// Going / maybe / can't — answerable without opening anything.
    ///
    /// Three buttons rather than a menu: an RSVP is the one thing on this screen
    /// somebody is *asked* for, and burying it a tap deep is how a household
    /// ends up with an event nobody ever answered.
    private func rsvpBar(for occurrence: EventOccurrence) -> some View {
        let mine = occurrence.rsvp(of: store.currentUserID)
        return HStack(spacing: 6) {
            ForEach(RSVPStatus.allCases) { status in
                let isMine = mine == status
                Button {
                    store.send(.rsvpTapped(occurrence, status))
                    // Only a tap that took. The reducer refuses one while the
                    // last is still in flight, and that is not an answer to
                    // acknowledge.
                    let now = store.state.occurrences[id: occurrence.id]?
                        .rsvp(of: store.currentUserID)
                    if now != mine { rsvpTaps.record(now) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: status.symbol)
                            .font(.caption2.weight(.bold))
                            // Keyed on your tap, not on the answer: the card
                            // appearing, or somebody's push, is not a choice.
                            .symbolEffect(
                                .bounce,
                                options: .nonRepeating,
                                value: reduceMotion ? 0 : rsvpTaps.bounces(of: status)
                            )
                        Text(status.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isMine ? .white : status.tint)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        isMine ? AnyShapeStyle(status.tint) : AnyShapeStyle(status.tint.opacity(0.14)),
                        in: .capsule
                    )
                    .contentShape(.capsule)
                }
                .buttonStyle(.pressableQuiet)
                .accessibilityAddTraits(isMine ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(Motion.spring, value: mine)
        .sensoryFeedback(trigger: rsvpTaps, RSVPTaps.feedback)
    }

    // MARK: - Shared pieces

    private func eventList(_ items: [EventOccurrence], showsDate: Bool) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, occurrence in
                SwipeToDelete(
                    isRevealed: Binding(
                        get: { revealedID == occurrence.id },
                        set: { revealedID = $0 ? occurrence.id : nil }
                    ),
                    onDelete: {
                        // A repeating event swiped away removes just that date.
                        // Deleting the whole series from a swipe is too much
                        // reach for one gesture; the sheet asks properly.
                        store.send(.deleteTapped(
                            occurrence,
                            occurrence.isRecurring ? .occurrence : .series
                        ))
                    }
                ) {
                    EventRow(
                        occurrence: occurrence,
                        rsvp: occurrence.rsvp(of: store.currentUserID),
                        attendees: avatars(for: occurrence.going),
                        showsDate: showsDate
                    ) {
                        store.send(.eventTapped(occurrence.id))
                    }
                    .glassCard(cornerRadius: Metrics.tightRadius)
                }
                .contextMenu {
                    // Nothing to answer once it is over, and nothing to edit
                    // unless the series it belongs to carries on.
                    if !occurrence.isPast {
                        ForEach(RSVPStatus.allCases) { status in
                            Button { store.send(.rsvpTapped(occurrence, status)) } label: {
                                Label { Text(status.title) } icon: {
                                    Image(systemName: status.symbol)
                                }
                            }
                        }
                        Divider()
                    }
                    if occurrence.isEditable {
                        Button {
                            store.send(.editTapped(occurrence, .series))
                        } label: {
                            Label {
                                Text(occurrence.isPast ? L10n.calendarEditSeries : L10n.commonEdit)
                            } icon: { Image(systemName: "pencil") }
                        }
                    }
                    if occurrence.isRecurring {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(occurrence, .occurrence))
                        } label: {
                            Label { Text(L10n.calendarSkipThisOne) } icon: {
                                Image(systemName: "calendar.badge.minus")
                            }
                        }
                    }
                    Button(role: .destructive) {
                        store.send(.deleteTapped(occurrence, .series))
                    } label: {
                        // A one-off has no series to delete, and calling its
                        // single date "all events" named something that does
                        // not exist. Same action either way — `.series` on an
                        // event that happens once is just that event.
                        Label {
                            Text(occurrence.isRecurring
                                ? L10n.calendarDeleteSeries
                                : L10n.calendarDeleteEvent)
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .appear(index)
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
    }

    private func avatars(for ids: [UserID]) -> [AvatarStack.Member] {
        ids.compactMap { id in
            guard let member = store.state.member(id) else { return nil }
            return AvatarStack.Member(id: id.rawValue, initials: member.initials)
        }
    }

    /// "Today", "Tomorrow", or the date. The two relative words are worth the
    /// special case: they are the only two a person reads without decoding.
    private func dayHeading(_ day: CalendarDay) -> String {
        let today = CalendarDay.today
        if day == today { return String(localized: L10n.calendarToday) }
        if day == today.advanced(by: 1) { return String(localized: L10n.calendarTomorrowLabel) }
        if day == today.advanced(by: -1) { return String(localized: L10n.calendarYesterday) }
        return day.date().formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)
        )
    }

    private func weekdayLetter(_ day: CalendarDay) -> String {
        var calendar = Calendar.current
        calendar.locale = L10n.locale
        let index = calendar.component(.weekday, from: day.date(calendar)) - 1
        let symbols = calendar.veryShortWeekdaySymbols
        return index >= 0 && index < symbols.count ? symbols[index] : ""
    }
}

// MARK: - Switching faces

/// The month face's coordinate space, which the grid is measured in.
private let monthFaceSpace = "calendarMonthFace"

/// Which way the last switch went, and the point it zoomed about.
///
/// A reference rather than `@State` values, on purpose. A face on its way out
/// keeps the transition it was last drawn with, so a direction held as a value
/// reached the outgoing face one switch late — month → week → month zoomed the
/// week face out the wrong way. The picker writes here before it sends, and
/// each face's transition reads it when its phase is actually evaluated.
private final class FaceZoom {
    /// Month → week → agenda is wide to narrow: inward.
    var inward = true
    /// Where the zoom is centred, in the faces' shared coordinates — the
    /// selected day's cell whenever the month is one end of the switch, and
    /// `nil` (the middle of what is on screen) otherwise.
    var pivot: CGPoint?
}

/// A face arriving or leaving as a zoom.
///
/// Inward, the old face swells past you and fades while the new one rises from
/// a little under its size; outward is the same film run backwards. Under
/// Reduce Motion it is a cross-fade and nothing else.
private struct FaceZoomTransition: Transition {
    let zoom: FaceZoom
    let reduceMotion: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .modifier(PivotScale(scale: scale(for: phase), pivot: zoom.pivot))
            .opacity(phase.isIdentity ? 1 : 0)
    }

    private func scale(for phase: TransitionPhase) -> CGFloat {
        guard !reduceMotion else { return 1 }
        switch phase {
        case .willAppear: return zoom.inward ? 0.92 : 1.08
        case .identity: return 1
        case .didDisappear: return zoom.inward ? 1.08 : 0.92
        }
    }
}

/// Scales about a point in the view's own coordinates rather than a fraction of
/// its size, so two faces of different heights zoom about the same spot on the
/// screen.
private struct PivotScale: GeometryEffect {
    var scale: CGFloat
    let pivot: CGPoint?

    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // With no day to zoom on: the middle of what is likely on screen, not
        // the middle of an agenda that may run a metre below it.
        let point = pivot ?? CGPoint(x: size.width / 2, y: min(size.height / 2, 240))
        return ProjectionTransform(
            CGAffineTransform(translationX: point.x, y: point.y)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -point.x, y: -point.y)
        )
    }
}

// MARK: - Answering

/// Your own RSVP taps, counted — what the answer's bounce and haptic key on.
///
/// Never the answer itself. That also changes when the sheet opens on one, when
/// a live push lands, and when a refused write is rolled back, and a phone
/// should not tap its owner's hand for something they did not do.
struct RSVPTaps: Equatable {
    /// Per answer, bumped only when a tap lands on it, so only that glyph
    /// bounces — not the one being left.
    private var landed: [RSVPStatus: Int] = [:]
    /// Every tap that changed the answer.
    private var count = 0
    /// What the last one changed it to; `nil` for taking an answer back.
    private var answer: RSVPStatus?

    mutating func record(_ answer: RSVPStatus?) {
        count += 1
        self.answer = answer
        if let answer { landed[answer, default: 0] += 1 }
    }

    func bounces(of status: RSVPStatus) -> Int {
        landed[status, default: 0]
    }

    /// For `sensoryFeedback(trigger:_:)`: nothing unless a tap was recorded,
    /// and a little more than a tick for saying you are coming.
    static func feedback(_ old: RSVPTaps, _ new: RSVPTaps) -> SensoryFeedback? {
        guard new.count != old.count else { return nil }
        return new.answer == .going ? .success : .selection
    }
}
