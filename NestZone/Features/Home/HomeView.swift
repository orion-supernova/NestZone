import ComposableArchitecture
import SwiftUI

/// Today.
///
/// From the top: the day in one sentence, the one thing that is wrong (if
/// anything is), then this person's sections in their order — each drawn only
/// when it has something in it, unless it was set to Always — and a short row
/// of ways into everything else. No section draws an empty state: "nothing
/// here" is what the sentence is for.
public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    @Environment(\.theme) private var theme
    @Namespace private var glass

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header.appear(0)
                if store.showsSetup {
                    setupCard.appear(1)
                }
                if let hero = store.hero {
                    heroCard(hero).appear(1)
                }
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
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.tabBarHome))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - The sentence

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            glanceText
                .font(.system(.title2, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
                .animation(Motion.spring, value: store.glance)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .redacted(reason: store.loaded.contains([.tasks, .bills, .issues]) ? [] : .placeholder)
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
        guard let name = store.greetingName else { return String(localized: part) }
        return "\(String(localized: part)) · \(String(localized: L10n.homeHi(name)))"
    }

    private var glanceText: Text {
        let clauses = store.glance
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
            Text(L10n.glanceIssue(issue.title)).foregroundStyle(Palette.danger)
        case let .alarm(.bill(bill)):
            switch bill.urgency(now: store.now) {
            case .overdue:
                Text(lateText(bill)).foregroundStyle(Palette.danger)
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
            if visibility == .always || store.movieNightIsTimely {
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

    /// A section: a small label over its rows. The label is a footnote, not a
    /// headline with an icon and a button — those used to be taller than the
    /// rows under them.
    private func block(_ section: TodaySection, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// What a section set to Always says when it has nothing: one line, not a
    /// card with an illustration and a button.
    private func quietLine(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
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
                    .foregroundStyle(isDone ? Palette.success : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(setupTitle(step))
                    .font(.subheadline.weight(.medium))
                    .strikethrough(isDone, color: .secondary)
                    .foregroundStyle(isDone ? .secondary : .primary)
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
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(tint)
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
                ) { store.send(.taskToggled(task.id)) }
                    .glassEffectID(task.id.rawValue, in: glass)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            if store.hiddenChoreCount > 0 {
                Button { store.send(.showMoreChoresTapped) } label: {
                    Text(L10n.homeMoreChores(store.hiddenChoreCount))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.accent)
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
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .glassControl()
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
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

    // MARK: - Movie night

    private var movieNightRow: some View {
        Button { store.send(.delegate(.openMovieNight)) } label: {
            HStack(spacing: 12) {
                Image(systemName: "popcorn.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(theme.gradient, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.homeMinigamesWatchTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(store.movieRoundIsOpen ? L10n.homeMovieRoundOpen : L10n.homeMinigamesWatchDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    /// Ways into the things Today summarises, as plain links at the bottom —
    /// where the "See all" capsules and the unlabelled chart button on every
    /// section header used to be.
    private var shelf: some View {
        FlowLayout(spacing: 16, lineSpacing: 6) {
            shelfLink(L10n.homeShelfAllChores) { store.send(.delegate(.openTasks)) }
            shelfLink(L10n.homeShelfContributions) { store.send(.delegate(.openContributions)) }
                .accessibilityIdentifier("ContributionsButton")
            shelfLink(L10n.hubStatsTitle) { store.send(.delegate(.openStats)) }
            shelfLink(L10n.homeShelfEditToday) { store.send(.delegate(.openCustomize)) }
                .accessibilityIdentifier("EditTodayButton")
        }
        .padding(.leading, 4)
        .padding(.top, 4)
    }

    private func shelfLink(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(minHeight: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
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
                    .foregroundStyle(Palette.danger)
                    .frame(width: 44, height: 44)
                    .background(Palette.danger.opacity(0.16), in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kicker)
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.danger)
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
                    .tint(Palette.danger)
                    .accessibilityIdentifier("HeroClaim")
                }
                Button(action: open) {
                    HStack(spacing: 4) {
                        Text(L10n.commonOpen)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
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

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Palette.success : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 34, height: 34)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .sensoryFeedback(.success, trigger: task.isCompleted) { _, done in done }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                if let due = task.dueDate, !task.isCompleted {
                    Text(dueText(due.date))
                        .font(.caption2)
                        .foregroundStyle(due.date < Calendar.current.startOfDay(for: now) ? Palette.danger : .secondary)
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
        .accessibilityAction(named: Text(L10n.tasksToggleAction), onToggle)
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
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                Button(action: onAccept) {
                    Label { Text(L10n.homeDinnerFromEventAction) } icon: { Image(systemName: "fork.knife") }
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glassProminent)

                Button(action: onDecideOther) {
                    Text(L10n.homeDinnerFromEventOther)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(minHeight: Metrics.minTapTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .contain)
    }
}
