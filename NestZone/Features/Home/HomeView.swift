import ComposableArchitecture
import SwiftUI

/// Today.
///
/// From the top: the day in one sentence, the one thing that is wrong (if
/// anything is), then this person's sections in their order — each drawn only
/// when it has something in it, unless it was set to Always — and a short row
/// of ways into everything else. No section draws an empty state: "nothing
/// here" is what the sentence is for.
public struct HomeView<Companion: View>: View {
    @Bindable var store: StoreOf<HomeFeature>
    /// The companion, drawn under the sentence — small on a day when something
    /// is wrong, so the alarm stays the first thing on the screen. Handed in by
    /// the tab container: Today does not own it.
    private let companion: (_ compact: Bool) -> Companion

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass
    @State private var isScrolling = false
    @State private var position = ScrollPosition(edge: .top)
    /// The day went quiet while this screen was up, so "All clear" earns its
    /// check. Never set by a day that was already quiet when it loaded: a mark
    /// that is always there says nothing.
    @State private var clearedHere = false
    /// When this person last ticked a chore on Today. A day that goes quiet
    /// within a second of that went quiet because of them, and only then does
    /// the phone tap — the same change arriving from somebody else's phone is
    /// theirs to feel, not this one's.
    @State private var lastOwnTick = Date.distantPast
    /// Taps on a meeting's Join: the person's own, so they tick.
    @State private var joins = 0
    @State private var allClears = 0

    public init(store: StoreOf<HomeFeature>, @ViewBuilder companion: @escaping (_ compact: Bool) -> Companion) {
        self.store = store
        self.companion = companion
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if store.user.map({ !$0.hasName }) == true {
                    NameReminderRow { store.send(.delegate(.openEditName)) }
                        .appear(0)
                }
                header.appear(0)
                if store.showsSetup {
                    setupCard.appear(1)
                }
                if let hero = store.hero {
                    heroCard(hero).appear(1)
                }
                companion(store.hero != nil)
                    .environment(\.isScrolling, isScrolling)
                    .appear(1)
                ForEach(Array(store.layout.shown.enumerated()), id: \.element) { index, section in
                    self.section(section).appear(index + 2)
                }
                shelf
            }
            .animation(Motion.spring, value: store.layout.shown)
            .animation(Motion.spring, value: store.hero)
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .onScrollPhaseChange { _, phase in isScrolling = phase.isScrolling }
        .scrollPosition($position)
        #if DEBUG || MEASURE
        .task { await flickForever() }
        #endif
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.tabBarHome))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    #if DEBUG || MEASURE
    /// `-todayScroll 1` flicks Today to the bottom and back, quickly and over
    /// and over, so its scroll can be profiled on a simulator nobody touches.
    ///
    /// `-todayGlide 1` is the calm version for an App Store preview: after two
    /// seconds Today drifts to the bottom over five, once, and stays there.
    private func flickForever() async {
        if UserDefaults.standard.bool(forKey: "todayGlide") {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeInOut(duration: 5)) { position.scrollTo(edge: .bottom) }
            return
        }
        guard UserDefaults.standard.bool(forKey: "todayScroll") else { return }
        var down = true
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 0.45)) { position.scrollTo(edge: down ? .bottom : .top) }
            down.toggle()
        }
    }
    #endif

    // MARK: - The sentence

    private var header: some View {
        // Read once: the sentence is built from most of the screen's state,
        // and the text, its animation and the check all want the same answer.
        let glance = store.glance
        return VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                glanceText(glance)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                    .animation(Motion.spring, value: glance)
                    .accessibilityAddTraits(.isHeader)
                if glance.isEmpty, clearedHere {
                    allClearMark
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .redacted(reason: store.loaded.contains([.tasks, .bills, .issues]) ? [] : .placeholder)
        .onChange(of: glance.isEmpty) { wasClear, isClear in
            guard isClear, !wasClear, store.loaded.contains([.tasks, .bills, .issues]) else {
                if !isClear { clearedHere = false }
                return
            }
            withAnimation(Motion.spring) { clearedHere = true }
            if Date.now.timeIntervalSince(lastOwnTick) < 1 { allClears += 1 }
        }
        .sensoryFeedback(.success, trigger: allClears)
    }

    /// The check that draws itself beside "All clear" when the last thing on
    /// the day is dealt with. A fade under Reduce Motion.
    @ViewBuilder
    private var allClearMark: some View {
        let mark = Image(systemName: "checkmark.circle.fill")
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(Palette.successText)
            .accessibilityHidden(true)
        if reduceMotion {
            mark.transition(.opacity)
        } else {
            mark.transition(.symbolEffect(.drawOn))
        }
    }

    /// "Tuesday evening · Hi Murat".
    private var eyebrow: String {
        let weekday = store.now.formatted(Date.FormatStyle().weekday(.wide).locale(L10n.locale))
        let part = switch store.dayPart {
        case .morning: L10n.homeDayMorning(weekday)
        case .afternoon: L10n.homeDayAfternoon(weekday)
        case .evening: L10n.homeDayEvening(weekday)
        case .night: L10n.homeDayNight(weekday)
        }
        // The line opens with the weekday in some languages, and Swedish (like
        // Turkish) writes weekdays in lowercase: "tisdag kväll". The start of a
        // line still takes a capital, whatever the language.
        let day = Self.capitalizingFirst(String(localized: part))
        guard let name = store.greetingName else { return day }
        return "\(day) · \(String(localized: L10n.homeHi(name)))"
    }

    private static func capitalizingFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased(with: L10n.locale) + text.dropFirst()
    }

    private func glanceText(_ clauses: [GlanceClause]) -> Text {
        guard !clauses.isEmpty else { return Text(L10n.glanceAllClear) }
        var text = Text(verbatim: "")
        for (index, clause) in clauses.enumerated() {
            if index > 0 {
                text = text + Text(verbatim: " · ").foregroundStyle(Palette.accessory)
            }
            text = text + clauseText(clause)
        }
        return text
    }

    private func clauseText(_ clause: GlanceClause) -> Text {
        switch clause {
        case let .alarm(.issue(issue)):
            Text(L10n.glanceIssue(issue.title)).foregroundStyle(Palette.dangerText)
        case let .alarm(.bill(bill)):
            switch bill.urgency(now: store.now) {
            case .overdue:
                Text(lateText(bill)).foregroundStyle(Palette.dangerText)
            case .dueToday:
                Text(L10n.glanceBillToday(bill.title))
            case .dueSoon, .upcoming:
                Text(L10n.glanceBillDue(bill.title, weekday(bill.dueDate.date)))
            }
        case let .happening(event):
            Text(L10n.glanceHappening(event.title))
        case let .eventToday(event):
            Text(L10n.glanceEventToday(event.title, event.start.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale)
            )))
        case let .tonight(plan):
            Text(L10n.glanceTonight(plan.dockHeadline))
        case let .chores(count):
            Text(L10n.glanceChores(count))
        case let .next(event):
            if Calendar.current.isDate(event.start, inSameDayAs: store.now.addingTimeInterval(24 * 3600)) {
                Text(L10n.glanceNextTomorrow(event.title))
            } else {
                Text(L10n.glanceNextOn(event.title, weekday(event.start)))
            }
        }
    }

    /// "Internet is 3 days late" — a day said as a day, not as "1 days".
    private func lateText(_ bill: Bill) -> LocalizedStringResource {
        let days = max(-bill.daysUntilDue(now: store.now), 1)
        return days == 1 ? L10n.glanceBillLateOneDay(bill.title) : L10n.glanceBillLateDays(bill.title, days)
    }

    /// A weekday within the week, a short date beyond it.
    private func weekday(_ date: Date) -> String {
        if date.timeIntervalSince(store.now) < 6 * 24 * 3600 {
            return date.formatted(Date.FormatStyle().weekday(.wide).locale(L10n.locale))
        }
        return date.formatted(Date.FormatStyle().day().month(.abbreviated).locale(L10n.locale))
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(_ section: TodaySection) -> some View {
        let visibility = store.layout.visibility(of: section)
        switch section {
        case .needsYou:
            if !store.needsRows.isEmpty {
                block(section) { needsRows }
            } else if visibility == .always, store.hero == nil {
                block(section) { quietLine(L10n.homeNeedsYouClear) }
            }
        case .pinnedNote:
            if !store.shownPinnedNotes.isEmpty {
                block(section) { pinnedNotes }
            } else if visibility == .always, store.loaded.contains(.notes) {
                block(section) { quietLine(L10n.homePinnedNoteQuiet) }
            }
        case .tonight:
            if store.showsTonight {
                block(section) { tonight }
            }
        case .tasks:
            if !store.chores.isEmpty {
                block(section) { chores }
            } else if visibility == .always, store.loaded.contains(.tasks) {
                block(section) { quietLine(L10n.homeTasksClear) }
            }
        case .upNext:
            if !store.comingUp.isEmpty {
                block(section) { comingUp }
            } else if visibility == .always, store.loaded.contains(.upcoming) {
                block(section) { quietLine(L10n.homeUpNextClear) }
            }
        case .movieNight:
            if store.showsMovieNight {
                movieNightRow
            }
        case .stats:
            if visibility == .always {
                block(section) { statsGrid }
            } else if !store.counters.isEmpty {
                counters
            }
        }
    }

    /// A section: a small label over its rows. The label is one line of
    /// subheadline (`groupLabel`), not a headline with an icon and a button —
    /// those used to be taller than the rows under them.
    private func block(_ section: TodaySection, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .groupLabel()
                .padding(.leading, 4)
            content()
        }
    }

    /// What a section set to Always says when it has nothing: one line, not a
    /// card with an illustration and a button.
    private func quietLine(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondaryText)
            .padding(.leading, 4)
    }

    // MARK: - Getting started

    /// What a new household gets instead of a welcome sheet: four things that
    /// make the app useful, each of which ticks itself once it is true.
    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.homeSetupTitle)
                    .font(.headline)
                Spacer(minLength: 0)
                Button { store.send(.setupClosed) } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(L10n.commonClose))
            }
            ForEach(HomeFeature.State.SetupStep.allCases) { step in
                setupRow(step, isDone: store.finishedSetup.contains(step))
            }
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .animation(Motion.spring, value: store.finishedSetup)
    }

    private func setupRow(_ step: HomeFeature.State.SetupStep, isDone: Bool) -> some View {
        Button { store.send(.setupStepTapped(step)) } label: {
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? Palette.successText : Palette.textSecondary)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                Text(setupTitle(step))
                    .font(.subheadline.weight(.medium))
                    .strikethrough(isDone, color: Palette.textSecondary)
                    .foregroundStyle(isDone ? Palette.textSecondary : .primary)
                Spacer(minLength: 0)
                if !isDone {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                }
            }
            .frame(minHeight: 32)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(isDone)
        .accessibilityIdentifier("Setup.\(step.rawValue)")
    }

    private func setupTitle(_ step: HomeFeature.State.SetupStep) -> LocalizedStringResource {
        switch step {
        case .invite: L10n.homeSetupInvite
        case .firstChore: L10n.homeSetupFirstChore
        case .dinner: L10n.homeSetupDinner
        case .customize: L10n.homeSetupCustomize
        }
    }

    // MARK: - The one card

    @ViewBuilder
    private func heroCard(_ alarm: HomeFeature.State.Alarm) -> some View {
        switch alarm {
        case let .issue(issue):
            HeroCard(
                symbol: "wrench.adjustable.fill",
                kicker: issueKicker(issue),
                title: issue.title,
                primary: claimAction(issue),
                open: { store.send(.delegate(.openIssue(issue.id))) }
            )
        case let .bill(bill):
            HeroCard(
                symbol: "dollarsign.circle.fill",
                kicker: String(localized: lateText(bill)),
                title: bill.title,
                primary: nil,
                open: { store.send(.delegate(.openFinance)) }
            )
        }
    }

    /// "Urgent · nobody's on it" — who has it is the question an urgent repair
    /// actually raises.
    private func issueKicker(_ issue: HouseIssue) -> String {
        let state = String(localized: issue.isOverdue ? L10n.homeHeroOverdue : L10n.homeHeroUrgent)
        let who: String = if issue.assignedTo == nil {
            String(localized: L10n.homeHeroNobody)
        } else if issue.assignedTo == store.user?.id {
            String(localized: L10n.homeHeroYou)
        } else {
            String(localized: L10n.homeHeroSomeone(
                store.members[id: issue.assignedTo!]?.displayName ?? ""
            ))
        }
        return "\(state) · \(who)"
    }

    private func claimAction(_ issue: HouseIssue) -> (LocalizedStringResource, () -> Void)? {
        guard store.user != nil, issue.assignedTo != store.user?.id else { return nil }
        return (L10n.homeHeroClaim, { store.send(.issueClaimed(issue.id)) })
    }

    // MARK: - Needs you

    private var needsRows: some View {
        GlassList {
            ForEach(store.needsRows) { alarm in
                switch alarm {
                case let .issue(issue):
                    needsRow(
                        symbol: "wrench.adjustable.fill",
                        tint: Palette.danger,
                        title: issue.title,
                        detail: String(localized: issue.isOverdue ? L10n.homeNeedsYouOverdue : L10n.homeNeedsYouUrgent)
                    ) { store.send(.delegate(.openIssue(issue.id))) }
                case let .bill(bill):
                    needsRow(
                        symbol: "dollarsign.circle.fill",
                        tint: bill.urgency(now: store.now) == .overdue ? Palette.danger : Palette.warning,
                        title: bill.title,
                        detail: billDetail(bill)
                    ) { store.send(.delegate(.openFinance)) }
                }
            }
        }
        .animation(Motion.spring, value: store.needsRows)
    }

    private func needsRow(
        symbol: String,
        tint: Color,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.14), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    // Words stay the secondary colour: the tint as text was
                    // orange on white (2.2:1) and red (3.6:1). The glyph in
                    // its wash carries the colour.
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
            }
            .contentShape(.rect)
            .glassRow()
        }
        .buttonStyle(.pressable)
    }

    private func billDetail(_ bill: Bill) -> String {
        switch bill.urgency(now: store.now) {
        case .overdue: String(localized: L10n.homeNeedsYouOverdue)
        case .dueToday: String(localized: L10n.homeNeedsYouDueToday)
        case .dueSoon, .upcoming:
            String(localized: L10n.homeNeedsYouDue(
                bill.dueDate.date.formatted(Date.FormatStyle().weekday(.wide).locale(L10n.locale))
            ))
        }
    }

    // MARK: - Tonight

    @ViewBuilder
    private var tonight: some View {
        Group {
            if let plan = store.tonight {
                DinnerPlanCard(
                    plan: plan,
                    action: {
                        if let recipe = plan.recipe {
                            store.send(.delegate(.openRecipe(recipe)))
                        } else {
                            store.send(.delegate(.decideDinner))
                        }
                    },
                    onOpenEvent: plan.event.map { event in
                        {
                            store.send(.delegate(.openEventID(
                                event.id,
                                CalendarDay(MealDate.date(plan.date) ?? store.now)
                            )))
                        }
                    },
                    onMakeOccasion: { store.send(.delegate(.makeOccasion)) }
                )
            } else if let occurrence = store.dinnerSuggestion {
                SuggestedDinnerCard(
                    occurrence: occurrence,
                    onAccept: { store.send(.delegate(.acceptDinnerSuggestion)) },
                    onDecideOther: { store.send(.delegate(.decideDinner)) }
                )
            } else {
                UndecidedDinnerCard { store.send(.delegate(.decideDinner)) }
            }
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
        .animation(Motion.spring, value: store.tonight)
        .animation(Motion.spring, value: store.dinnerSuggestion)
    }

    // MARK: - Chores

    private var chores: some View {
        GlassList {
            ForEach(store.visibleChores) { task in
                TaskRow(
                    task: task,
                    assignee: task.assignedTo.flatMap { store.members[id: $0] },
                    isMine: task.assignedTo != nil && task.assignedTo == store.user?.id,
                    now: store.now
                ) {
                    lastOwnTick = .now
                    store.send(.taskToggled(task.id))
                }
                    .glassEffectID(task.id.rawValue, in: glass)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            if store.hiddenChoreCount > 0 {
                Button { store.send(.showMoreChoresTapped) } label: {
                    Text(L10n.homeMoreChores(store.hiddenChoreCount))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.accentText)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .frame(minHeight: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
            }
        }
        .animation(Motion.spring, value: store.visibleChores.map(\.id))
    }

    // MARK: - Coming up

    private var comingUp: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(store.comingUp) { occurrence in
                        HStack(spacing: 6) {
                            Button { store.send(.delegate(.openEvent(occurrence))) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: occurrence.kind.symbol)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(occurrence.kind.tint)
                                    Text(occurrence.title)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(whenText(occurrence))
                                        .font(.caption)
                                        .foregroundStyle(.secondaryText)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .glassControl()
                            }
                            .buttonStyle(.pressable)

                            // A meeting about to start, or under way, and
                            // nothing else: not a control on every chip.
                            if occurrence.canJoin(at: store.now) {
                                Button {
                                    joins += 1
                                    store.send(.joinTapped(occurrence))
                                } label: {
                                    Label { Text(L10n.meetingJoin) } icon: { Image(systemName: "video.fill") }
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(theme.onAccent)
                                        .padding(.horizontal, 12)
                                        .frame(minHeight: 36)
                                        .background(theme.accentFill, in: .capsule)
                                        .contentShape(.capsule)
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
        .sensoryFeedback(.impact(weight: .light), trigger: joins)
    }

    /// "20:00" today, "tomorrow", the weekday this week, a short date after.
    private func whenText(_ occurrence: EventOccurrence) -> String {
        if Calendar.current.isDate(occurrence.start, inSameDayAs: store.now) {
            return occurrence.isAllDay ? String(localized: L10n.calendarToday) : occurrence.timeText
        }
        if Calendar.current.isDate(occurrence.start, inSameDayAs: store.now.addingTimeInterval(24 * 3600)) {
            return String(localized: L10n.calendarTomorrowLabel)
        }
        return weekday(occurrence.start)
    }

    // MARK: - Counters

    /// The counters, as the few that are asking for something.
    private var counters: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(store.counters, id: \.self) { counter in
                Button { open(counter) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: symbol(counter))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tint(counter))
                        Text(title(counter))
                            .font(.footnote.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .glassControl()
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func open(_ counter: HomeFeature.State.Counter) {
        switch counter {
        case .shopping: store.send(.delegate(.openShoppingList))
        case .unread: store.send(.delegate(.openMessages))
        case .problems: store.send(.delegate(.openIssues))
        case .events: store.send(.delegate(.openCalendar))
        }
    }

    private func title(_ counter: HomeFeature.State.Counter) -> LocalizedStringResource {
        switch counter {
        case let .shopping(n): L10n.homeCounterShopping(n)
        case let .unread(n): L10n.homeCounterUnread(n)
        case let .problems(n): L10n.homeCounterProblems(n)
        case let .events(n): L10n.homeCounterEvents(n)
        }
    }

    private func symbol(_ counter: HomeFeature.State.Counter) -> String {
        switch counter {
        case .shopping: "cart.fill"
        case .unread: "bubble.left.and.bubble.right.fill"
        case .problems: "wrench.adjustable.fill"
        case .events: "calendar"
        }
    }

    private func tint(_ counter: HomeFeature.State.Counter) -> Color {
        switch counter {
        case .shopping: Palette.statShopping
        case .unread: Palette.statMessages
        case .problems: store.stats.urgentIssues > 0 ? Palette.danger : Palette.statIssues
        case .events: Palette.statEvents
        }
    }

    /// The full grid, for anybody who set the counters to Always.
    private var statsGrid: some View {
        HouseStatsGrid(
            stats: store.stats,
            eventsThisWeek: store.eventsThisWeek,
            statsLoaded: store.loaded.contains(.stats),
            eventsLoaded: store.loaded.contains(.upcoming)
        ) { tile in
            switch tile {
            case .tasks: store.send(.delegate(.openTasks))
            case .shopping: store.send(.delegate(.openShoppingList))
            case .notes: store.send(.delegate(.openNotes))
            case .messages: store.send(.delegate(.openMessages))
            case .issues: store.send(.delegate(.openIssues))
            case .events: store.send(.delegate(.openCalendar))
            }
        }
    }

    // MARK: - Pinned note

    /// The pinned notes as sticky cards, at most two side by side, and a line
    /// to the rest. A tap anywhere opens Notes: the card is the house's
    /// reference (the Wi-Fi, the bin day), read at a glance and not edited here.
    private var pinnedNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(store.shownPinnedNotes) { note in
                    StickyNote(
                        text: note.body,
                        color: StickyColor.parse(note.color),
                        seed: note.id.rawValue
                    ) { EmptyView() }
                    .frame(maxWidth: .infinity)
                }
                if store.shownPinnedNotes.count == 1 {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
            // The tilted cards' corners reach past their frames.
            .padding(.vertical, 4)
            .contentShape(.rect)
            .onTapGesture { store.send(.delegate(.openNotes)) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: store.shownPinnedNotes.map(\.body).joined(separator: ". ")))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { store.send(.delegate(.openNotes)) }

            if store.morePinnedNotes > 0 {
                Button { store.send(.delegate(.openNotes)) } label: {
                    HStack(spacing: 4) {
                        Text(L10n.homePinnedMore(store.morePinnedNotes))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.accentText)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.accessory)
                    }
                    .frame(minHeight: Metrics.minTapTarget, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Movie night

    private var movieNightRow: some View {
        Button { store.send(.delegate(.openMovieNight)) } label: {
            HStack(spacing: 12) {
                Image(systemName: "popcorn.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.onAccent)
                    .frame(width: 32, height: 32)
                    .background(theme.gradient, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.homeMinigamesWatchTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(store.movieRoundIsOpen ? L10n.homeMovieRoundOpen : L10n.homeMinigamesWatchDescription)
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
            }
            .contentShape(.rect)
            .glassRow()
        }
        .buttonStyle(.pressable)
    }

    // MARK: - The shelf

    /// Ways into the things Today summarises, at the bottom — where the "See
    /// all" capsules and the unlabelled chart button on every section header
    /// used to be. Four equal glass pills in a 2x2 grid: a glyph and a short
    /// label each, every label on one line (shrinking a little before it
    /// would wrap), so the four are always the same height — one pill taller
    /// than its neighbours read as a mistake. At accessibility sizes the
    /// labels may wrap, all alike.
    private var shelf: some View {
        GlassGroup(spacing: 10) {
            LazyVGrid(columns: shelfColumns, spacing: 10) {
                shelfPill(L10n.homeShelfAllChores, symbol: "checklist") {
                    store.send(.delegate(.openTasks))
                }
                shelfPill(L10n.homeShelfContributions, symbol: "person.2") {
                    store.send(.delegate(.openContributions))
                }
                .accessibilityIdentifier("ContributionsButton")
                shelfPill(L10n.hubStatsTitle, symbol: "square.grid.2x2") {
                    store.send(.delegate(.openStats))
                }
                shelfPill(L10n.homeShelfEditToday, symbol: "slider.horizontal.3") {
                    store.send(.delegate(.openCustomize))
                }
                .accessibilityIdentifier("EditTodayButton")
            }
        }
        .padding(.top, 4)
    }

    private var shelfColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private func shelfPill(
        _ title: LocalizedStringResource,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.accentText)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .oneLineUnlessAccessibility()
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
            .contentShape(.rect(cornerRadius: Metrics.tightRadius, style: .continuous))
        }
        .buttonStyle(.pressable)
        .glassCard(cornerRadius: Metrics.tightRadius, interactive: true)
    }
}

/// The one big card on Today: something wrong, who has it, and the way to
/// take it on without leaving the tab.
private struct HeroCard: View {
    let symbol: String
    let kicker: String
    let title: String
    let primary: (LocalizedStringResource, () -> Void)?
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(Palette.dangerText)
                    .frame(width: 44, height: 44)
                    .background(Palette.danger.opacity(0.16), in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kicker)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.dangerText)
                        .lineLimit(1)
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                if let primary {
                    Button(action: primary.1) {
                        Text(primary.0)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.answerNo)
                    .accessibilityIdentifier("HeroClaim")
                }
                Button(action: open) {
                    HStack(spacing: 4) {
                        Text(L10n.commonOpen)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondaryText)
                    .frame(minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tinted: Palette.danger.opacity(0.12))
        .accessibilityElement(children: .contain)
    }
}

private struct TaskRow: View {
    let task: HouseTask
    let assignee: User?
    let isMine: Bool
    let now: Date
    let onToggle: () -> Void

    /// Ticks from this checkbox, counted at the tap. The chore itself also
    /// changes when somebody else finishes it, and their tick is not this
    /// phone's to buzz or pop for. The row outlives its tick here — Today
    /// holds a ticked chore for a beat before it goes — so the haptic can live
    /// on it.
    @State private var ticks = 0
    @State private var pops = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Palette.successText : Palette.textSecondary)
                    // The tick grows out of the ring rather than swapping in.
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                    // Squash, overshoot, settle. Idle until a tap moves the
                    // counter, so a row scrolling past costs nothing.
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        CubicKeyframe(0.8, duration: 0.08)
                        SpringKeyframe(1.18, duration: 0.12)
                        SpringKeyframe(1, duration: 0.15, spring: .init(duration: 0.15, bounce: 0.5))
                    }
                    .frame(width: 34, height: 34)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .sensoryFeedback(.success, trigger: ticks)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(task.isCompleted ? Palette.textSecondary : .primary)
                    .lineLimit(1)
                    // The line alone, swept across by a copy of the title whose
                    // letters are clear. Only there while the chore is done, so
                    // an open row — nearly every row Today draws — carries
                    // nothing extra while the screen scrolls.
                    .overlay(alignment: .leading) {
                        if task.isCompleted {
                            Text(task.title)
                                .font(.subheadline.weight(.medium))
                                .strikethrough(color: Palette.textSecondary)
                                .foregroundStyle(.clear)
                                .lineLimit(1)
                                .transition(strikeTransition)
                                .accessibilityHidden(true)
                        }
                    }

                if let due = task.dueDate, !task.isCompleted {
                    Text(dueText(due.date))
                        .font(.caption)
                        .foregroundStyle(due.date < Calendar.current.startOfDay(for: now) ? Palette.dangerText : Palette.textSecondary)
                }
            }

            Spacer(minLength: 0)

            if let assignee {
                Avatar(user: assignee, size: 22, viewable: false)
            }
        }
        .glassRow()
        .animation(Motion.spring, value: task.isCompleted)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(task.isCompleted ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: Text(L10n.tasksToggleAction), toggle)
    }

    /// Only ticking celebrates; reopening is a correction. Reduce Motion keeps
    /// the new glyph and the haptic and drops the squash.
    private func toggle() {
        if !task.isCompleted {
            ticks += 1
            if !reduceMotion { pops += 1 }
        }
        onToggle()
    }

    private var strikeTransition: AnyTransition {
        reduceMotion ? .opacity : AnyTransition(Strike()).animation(.easeOut(duration: 0.25))
    }

    /// The strikethrough drawing itself across the title, left to right. A
    /// horizontal scale, not a mask: the letters on this layer are clear, so
    /// the line is all there is to stretch, and no offscreen pass is paid for
    /// it on the screen that has to scroll the smoothest.
    private struct Strike: Transition {
        func body(content: Content, phase: TransitionPhase) -> some View {
            content.scaleEffect(x: phase.isIdentity ? 1 : 0.01, anchor: .leading)
        }
    }

    private func dueText(_ date: Date) -> String {
        if Calendar.current.isDate(date, inSameDayAs: now) {
            return String(localized: L10n.homeChoreDueToday)
        }
        return date.formatted(.relative(presentation: .named).locale(L10n.locale))
    }
}

/// Tonight is undecided, but something in the calendar today has a menu.
///
/// The reverse of the link the event sheet writes. Planning a dinner party —
/// menu, shopping, budget — used to do nothing for that day's tonight card
/// unless somebody went back into the event and pressed "make it dinner"; the
/// answer existed and this tab did not know it.
///
/// An offer, not a decision. An event with a menu is strong evidence about
/// dinner, and evidence is not a reason to write on a household's behalf — so
/// the way to a different answer stays one tap away underneath.
private struct SuggestedDinnerCard: View {
    @Environment(\.theme) private var theme
    let occurrence: EventOccurrence
    let onAccept: () -> Void
    let onDecideOther: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: occurrence.kind.symbol)
                    .font(.headline)
                    .foregroundStyle(occurrence.kind.tint)
                    .frame(width: 44, height: 44)
                    .background(
                        occurrence.kind.tint.opacity(0.14),
                        in: .rect(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(occurrence.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(L10n.homeDinnerFromEventMenu(occurrence.recipeIDs.count))
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                Button(action: onAccept) {
                    Label { Text(L10n.homeDinnerFromEventAction) } icon: { Image(systemName: "fork.knife") }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.glassProminent)
                .tint(theme.accentFill)

                Button(action: onDecideOther) {
                    Text(L10n.homeDinnerFromEventOther)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondaryText)
                        .frame(minHeight: Metrics.minTapTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .contain)
    }
}

extension HomeView where Companion == EmptyView {
    public init(store: StoreOf<HomeFeature>) {
        self.init(store: store) { _ in EmptyView() }
    }
}
