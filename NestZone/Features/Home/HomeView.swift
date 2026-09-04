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
                statsGrid.appear(1)
                movieNightCard.appear(2)
                tasksSection.appear(3)
            }
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

    // MARK: - Stats

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.homeStatsTitle, symbol: "chart.bar.fill")

            GlassGroup(spacing: 18) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: Metrics.stackSpacing)],
                    spacing: Metrics.stackSpacing
                ) {
                    StatTile(
                        title: L10n.homeStatsTasksDoneTitle,
                        value: store.stats.completedTasks,
                        change: store.stats.completedTasksChange,
                        symbol: "checkmark.circle.fill",
                        tint: Palette.success
                    ) { store.send(.delegate(.openTasks)) }

                    StatTile(
                        title: L10n.homeStatsShoppingTitle,
                        value: store.stats.shoppingItems,
                        change: store.stats.shoppingChange,
                        symbol: "cart.fill",
                        tint: theme.accent
                    ) { store.send(.delegate(.openShoppingList)) }

                    StatTile(
                        title: L10n.homeStatsNotesTitle,
                        value: store.stats.notes,
                        change: store.stats.notesChange,
                        symbol: "note.text",
                        tint: theme.support
                    ) { store.send(.delegate(.openNotes)) }

                    StatTile(
                        title: L10n.homeStatsIssuesTitle,
                        value: store.stats.urgentTasks,
                        symbol: "exclamationmark.triangle.fill",
                        tint: Palette.warning
                    ) { store.send(.delegate(.openTasks)) }
                }
            }
            .redacted(reason: store.isLoading ? .placeholder : [])
        }
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
                        .foregroundStyle(.tertiary)
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

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.homeTasksTitle, symbol: "checklist") {
                Button { store.send(.delegate(.openTasks)) } label: {
                    Text(L10n.commonSeeAll).font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

            if store.isLoading {
                SkeletonList(rows: 3, height: 56)
            } else if store.tasks.isEmpty {
                EmptyStateView(
                    title: L10n.homeTasksEmptyTitle,
                    message: L10n.homeTasksEmptyMessage,
                    symbol: "checkmark.seal",
                    action: .init(title: L10n.commonAdd) { store.send(.delegate(.openTasks)) },
                    isCompact: true
                )
                .frame(maxWidth: .infinity)
            } else {
                GlassGroup {
                    VStack(spacing: Metrics.stackSpacing) {
                        ForEach(store.recentTasks) { task in
                            TaskRow(task: task) { store.send(.taskToggled(task.id)) }
                                .glassEffectID(task.id.rawValue, in: glass)
                        }
                    }
                }
            }
        }
        .animation(Motion.spring, value: store.tasks)
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
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .animation(Motion.spring, value: task.isCompleted)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(task.isCompleted ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: Text(L10n.tasksToggleAction), onToggle)
    }
}
