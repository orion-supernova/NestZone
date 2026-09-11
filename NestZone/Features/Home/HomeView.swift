import ComposableArchitecture
import SwiftUI

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    @Environment(\.theme) private var theme
    @Namespace private var glass

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.sectionSpacing) {
                greeting.appear(0)
                tonightCard.appear(1)
                statsGrid.appear(2)
                if !store.state.upNext.isEmpty {
                    upNextSection.appear(3)
                }
                tasksSection.appear(4)
                movieNightCard.appear(5)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.tabBarHome))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(state: \.dinner, action: \.dinner)) {
            DinnerSheet(store: $0)
        }
        .sheet(item: $store.scope(state: \.occasion, action: \.occasion)) {
            EventComposerSheet(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.homeHelloUser(store.user?.displayName ?? ""))
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(L10n.homeHeaderSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Tonight

    /// What the household is doing about dinner, or an invitation to decide.
    ///
    /// Top of the tab on purpose: it is the question a shared home asks itself
    /// every single day, and the answer changes what the shopping list and the
    /// recipes are for.
    private var tonightCard: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.dinnerTonightTitle, symbol: "moon.stars.fill") {
                if store.tonight != nil {
                    Button { store.send(.decideDinnerTapped) } label: {
                        Text(L10n.dinnerChangeButton)
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }

            Group {
                if let plan = store.tonight {
                    DinnerPlanCard(
                        plan: plan,
                        action: {
                            if let recipe = plan.recipe {
                                store.send(.delegate(.openRecipe(recipe)))
                            } else {
                                store.send(.decideDinnerTapped)
                            }
                        },
                        onOpenEvent: plan.event.map { event in
                            {
                                store.send(.delegate(.openEventID(
                                    event.id,
                                    CalendarDay(MealDate.date(plan.date) ?? Date())
                                )))
                            }
                        },
                        onMakeOccasion: { store.send(.makeOccasionTapped) }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else if let occurrence = store.state.dinnerSuggestion {
                    // The household has already answered "what are we eating" —
                    // it just answered it in the calendar. Offering it here
                    // beats making somebody remember to open the event and
                    // press a button in it.
                    SuggestedDinnerCard(
                        occurrence: occurrence,
                        onAccept: { store.send(.dinnerSuggestionAccepted) },
                        onDecideOther: { store.send(.decideDinnerTapped) }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else {
                    UndecidedDinnerCard { store.send(.decideDinnerTapped) }
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(Motion.spring, value: store.tonight)
            .animation(Motion.spring, value: store.state.dinnerSuggestion)
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.homeStatsTitle, symbol: "chart.bar.fill")

            GlassGroup(spacing: 18) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: Metrics.stackSpacing)],
                    spacing: Metrics.stackSpacing
                ) {
                    // One task tile, not two. It used to carry "Tasks Done" —
                    // an all-time total that only ever grows — beside "Issues",
                    // a high-priority count that reads 0 in any household that
                    // never sets priority. Both were about tasks, and the Tasks
                    // section directly below now tells the whole story: the
                    // split, the recent rows, and the done count in the ring
                    // behind it. What is left is the one task number that moves
                    // day to day, and `openTasks` had been computed server-side
                    // and thrown away this whole time.
                    Group {
                    StatTile(
                        title: L10n.homeStatsTodoTitle,
                        value: store.stats.openTasks,
                        symbol: "checklist.unchecked",
                        tint: Palette.statTasks
                    ) { store.send(.delegate(.openTasks)) }

                    StatTile(
                        title: L10n.homeStatsShoppingTitle,
                        value: store.stats.shoppingItems,
                        change: store.stats.shoppingChange,
                        symbol: "cart.fill",
                        tint: Palette.statShopping
                    ) { store.send(.delegate(.openShoppingList)) }

                    StatTile(
                        title: L10n.homeStatsNotesTitle,
                        value: store.stats.notes,
                        change: store.stats.notesChange,
                        symbol: "note.text",
                        tint: Palette.statNotes
                    ) { store.send(.delegate(.openNotes)) }

                    // `stats:forHome` has counted unread messages since the
                    // server took the tiles over; nothing had ever displayed it.
                    StatTile(
                        title: L10n.homeStatsMessagesTitle,
                        value: store.stats.unreadMessages,
                        change: store.stats.messagesChange,
                        symbol: "bubble.left.and.bubble.right.fill",
                        tint: Palette.statMessages
                    ) { store.send(.delegate(.openMessages)) }

                    // What is still broken.
                    //
                    // Not the tile that used to sit here under this name: that
                    // one counted high-priority *tasks* and read 0 in any home
                    // that never set a priority, which is why it went. This is
                    // its own table, its own index, and a number that falls
                    // when somebody fixes something. It goes red when any of it
                    // is urgent or overdue — the one counter on this grid where
                    // "3" and "3, one of them a leak" are different facts.
                    StatTile(
                        title: L10n.homeStatsIssuesTitle,
                        value: store.stats.openIssues,
                        change: store.stats.issuesChange,
                        symbol: "wrench.adjustable.fill",
                        tint: store.stats.urgentIssues > 0 ? Palette.danger : Palette.statIssues
                    ) { store.send(.delegate(.openIssues)) }
                    }
                    // The five counters that come off `stats:forHome`, so they
                    // wait on it and on nothing else. A `Group` inside a grid
                    // flattens to its children, so these stay five cells and the
                    // modifier lands on each.
                    .redacted(reason: store.loaded.contains(.stats) ? [] : .placeholder)

                    // The one tile whose number is not from `stats:forHome`.
                    // It is counted here from the short agenda the card below
                    // already subscribes to, rather than added to the server's
                    // summary — one capped query answers both, and a badge that
                    // could disagree with the list under it is the exact failure
                    // the Finance screen's bill counters were moved client-side
                    // to avoid.
                    StatTile(
                        title: L10n.homeStatsEventsTitle,
                        value: store.state.eventsThisWeek,
                        symbol: "calendar",
                        tint: Palette.statEvents
                    ) { store.send(.delegate(.openCalendar)) }
                    // Counted from the agenda, so it waits on the agenda.
                    .redacted(reason: store.loaded.contains(.upcoming) ? [] : .placeholder)
                }
            }
        }
    }

    // MARK: - Up next

    /// What the household is about to do, and what it is doing right now.
    ///
    /// A count cannot say "the party started an hour ago", which is the one
    /// thing on this tab that stops being true while you are looking at it —
    /// hence a live countdown and a badge rather than another number.
    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            // Its own section, with its own heading. It used to hang off the
            // bottom of the statistics grid, which made a list of dated things
            // read as a footnote to four counters rather than as the answer to
            // a different question.
            SectionHeader(L10n.homeUpNextTitle, symbol: "calendar.badge.clock") {
                // The same glass control the Tasks section uses. Bare accent
                // text next to a glass capsule two sections down read as two
                // different kinds of thing when they do the same job.
                //
                // No icon button beside it, unlike Tasks: that one opens
                // Contributions, a different screen about the same data, and
                // events have no equivalent second destination. An icon that
                // went where "See all" already goes would be decoration.
                Button { store.send(.delegate(.openCalendar)) } label: {
                    Text(L10n.commonSeeAll).font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
            upNextCard
        }
    }

    private var upNextCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(store.state.upNext.enumerated()), id: \.element.id) { index, occurrence in
                    if index > 0 {
                        Divider().opacity(0.4).padding(.leading, 52)
                    }
                    upNextRow(occurrence).appear(index)
                }
            }
        }
        .animation(Motion.spring, value: store.state.upNext.map(\.id))
    }

    private func upNextRow(_ occurrence: EventOccurrence) -> some View {
        Button { store.send(.delegate(.openEvent(occurrence))) } label: {
            HStack(spacing: 12) {
                Image(systemName: occurrence.kind.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(occurrence.kind.tint)
                    .frame(width: 32, height: 32)
                    .background(occurrence.kind.tint.opacity(0.14), in: .circle)
                    .bounces(when: occurrence.isInProgress)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(occurrence.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if occurrence.isInProgress {
                            NowBadge()
                        }
                    }
                    Text(whenText(occurrence))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if occurrence.isInProgress {
                    // The countdown has nothing left to count, and the badge
                    // beside the title has already said it.
                    EmptyView()
                } else {
                    CountdownText(occurrence.start)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, Metrics.cardPadding)
            .padding(.vertical, 11)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }

    /// "Today · 19:00 – 23:00", or the day for anything further out.
    private func whenText(_ occurrence: EventOccurrence) -> String {
        let day = CalendarDay(occurrence.start)
        let today = CalendarDay.today
        let label: String = if day == today {
            String(localized: L10n.calendarToday)
        } else if day == today.advanced(by: 1) {
            String(localized: L10n.calendarTomorrowLabel)
        } else {
            occurrence.start.formatted(
                Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)
            )
        }
        return occurrence.isAllDay ? label : "\(label) · \(occurrence.timeText)"
    }

    // MARK: - Movie night

    private var movieNightCard: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.homeMinigamesTitle, symbol: "sparkles")

            Button { store.send(.delegate(.openMovieNight)) } label: {
                HStack(spacing: 16) {
                    Image(systemName: "popcorn.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(theme.gradient, in: .rect(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.homeMinigamesWatchTitle).font(.headline)
                        Text(L10n.homeMinigamesWatchDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                }
                .padding(Metrics.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .glassCard(interactive: true)
        }
    }

    // MARK: - Tasks

    /// Chores, and the way into who has been doing them.
    ///
    /// The split lives behind the chart button in this header rather than in a
    /// card above the rows. It was tried as a full-width strip at the top of
    /// this stack, and it read as a very large first task: two different kinds
    /// of thing — a summary and the items it summarises — stacked in one column
    /// with the same surface. A header control says "there is more about this
    /// section" without competing with the rows for the same glance.
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.homeTasksTitle, symbol: "checklist") {
                HStack(spacing: 8) {
                    Button { store.send(.delegate(.openContributions)) } label: {
                        Image(systemName: "chart.pie.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .accessibilityLabel(Text(L10n.contributionsSectionTitle))
                    .accessibilityIdentifier("ContributionsButton")

                    Button { store.send(.delegate(.openTasks)) } label: {
                        Text(L10n.commonSeeAll).font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }

            GlassList {
                if !store.loaded.contains(.tasks) {
                    SkeletonList(rows: 3, height: 56)
                } else if store.tasks.isEmpty {
                    EmptyStateView(
                        title: L10n.homeTasksEmptyTitle,
                        message: L10n.homeTasksEmptyMessage,
                        symbol: "checkmark.seal",
                        action: .init(title: L10n.commonAdd) {
                            store.send(.delegate(.openTasks))
                        },
                        isCompact: true
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(store.recentTasks) { task in
                        TaskRow(task: task) { store.send(.taskToggled(task.id)) }
                            .glassEffectID(task.id.rawValue, in: glass)
                    }
                }
            }
        }
        .animation(Motion.spring, value: store.tasks)
    }
}


/// "Now" — the household is in the middle of this.
///
/// The only endlessly-repeating animation on this tab, and there is never more
/// than one on screen: a row is either happening or it is not, and the whole
/// point of the badge is that it is alive.
private struct NowBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Palette.danger)
                .frame(width: 5, height: 5)
                .pulse()
            Text(L10n.calendarNowBadge)
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
        }
        .foregroundStyle(Palette.danger)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Palette.danger.opacity(0.14), in: .capsule)
        .transition(.scale.combined(with: .opacity))
    }
}

private struct TaskRow: View {
    let task: HouseTask
    let onToggle: () -> Void

    @Environment(\.theme) private var theme

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

                if let due = task.dueDate {
                    Text(due.date, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(task.isOverdue ? Palette.danger : .secondary)
                }
            }

            Spacer(minLength: 0)

            if task.isUrgent {
                Badge(
                    String(localized: L10n.tasksPriorityHigh),
                    tint: Palette.danger,
                    symbol: "exclamationmark"
                )
            }
        }
        .glassRow()
        .animation(Motion.spring, value: task.isCompleted)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(task.isCompleted ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: Text(L10n.tasksToggleAction), onToggle)
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
            HStack(spacing: 16) {
                Image(systemName: occurrence.kind.symbol)
                    .font(.title2)
                    .foregroundStyle(occurrence.kind.tint)
                    .frame(width: 52, height: 52)
                    .background(
                        occurrence.kind.tint.opacity(0.14),
                        in: .rect(cornerRadius: 14, style: .continuous)
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

            PrimaryButton(L10n.homeDinnerFromEventAction, symbol: "fork.knife") {
                onAccept()
            }

            Button(action: onDecideOther) {
                Text(L10n.homeDinnerFromEventOther)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Metrics.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .contain)
    }
}
