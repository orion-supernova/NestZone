import ComposableArchitecture
import SwiftUI

public struct TasksView: View {
    @Bindable var store: StoreOf<TasksFeature>

    @Environment(\.theme) private var theme

    /// Chores this person ticked on this screen, for the haptic. Counted at the
    /// tap rather than read off the chore, because the chore also changes when
    /// somebody else ticks it on their phone, and that is not this phone's to
    /// buzz for. Kept on the list rather than the row: in To do a ticked row
    /// leaves the list in the same frame as the tap, and a row that is already
    /// on its way out cannot be relied on to play anything.
    @State private var ticks = 0

    public init(store: StoreOf<TasksFeature>) {
        self.store = store
    }

    /// A real `List`, so the swipe is the system's rather than a rebuild of it.
    ///
    /// This screen has now had all three: `.swipeActions` in a `LazyVStack`,
    /// where it compiled and did nothing; `SwipeToDelete`, which worked until
    /// the row's glass started leaning toward the finger and then won the touch
    /// about half the time; and this. `UISwipeActionsConfiguration` does not
    /// race anything, so the row keeps its lean and the swipe still lands.
    /// Recipes went the same way for the same reason.
    public var body: some View {
        List {
            Picker(selection: $store.filter) {
                ForEach(TasksFeature.State.Filter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            } label: { EmptyView() }
            .pickerStyle(.segmented)
            .glassListRow(insets: .init(
                top: 0,
                leading: Metrics.screenPadding,
                bottom: Metrics.stackSpacing,
                trailing: Metrics.screenPadding
            ))

            doneWindowNote

            list
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, Metrics.scrollBottomInset, for: .scrollContent)
        // Rows are exactly as tall as their card; without this the filter bar
        // is padded out to the system's 44pt minimum.
        .environment(\.defaultMinListRowHeight, 0)
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.tasksScreenTitle))
        .navigationBarTitleDisplayMode(.inline)
        .segmentToolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.composeTapped) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(L10n.tasksComposeTitle))
            }
            // A header control, not a card over the rows: tried as a strip at
            // the top of a list, the split read as a very large first task.
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.contributionsTapped) } label: {
                    Image(systemName: "chart.pie")
                }
                .accessibilityLabel(Text(L10n.contributionsSectionTitle))
                .accessibilityIdentifier("TasksContributionsButton")
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(
            state: \.destination?.compose, action: \.destination.compose
        )) { ComposeTaskSheet(store: $0) }
        .alert($store.scope(state: \.alert, action: \.alert))
        // Above the floating tab bar, not under it: the offer is worth nothing
        // if the bar is sitting on the button.
        .overlay(alignment: .bottom) {
            if let pending = store.pendingRemoval {
                UndoToast(
                    pending.kind == .archive
                        ? L10n.tasksTaskArchived(pending.task.title)
                        : L10n.tasksTaskDeleted(pending.task.title),
                    symbol: pending.kind == .archive ? "archivebox" : "trash"
                ) {
                    store.send(.undoRemovalTapped)
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, Metrics.scrollBottomInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: store.visible)
        .animation(Motion.spring, value: store.pendingRemoval)
        .sensoryFeedback(.success, trigger: ticks)
    }

    /// What happens to a chore after it is ticked, said above the list it
    /// happens to rather than under it.
    ///
    /// The Done list is bounded — it has to be, or it is every chore the
    /// household has ever finished sitting on top of the ones it has not — and
    /// a bounded list that does not say so reads as one that lost things. So it
    /// says so, before the rows rather than after them: this is the scope of
    /// what you are about to read, and scope belongs at the top. Underneath a
    /// screenful of chores it was something you found only by scrolling past
    /// everything it was meant to explain.
    ///
    /// The destination is a glass capsule, the same control the Home, Finance
    /// and Issues screens use to reach the full version of a summary. It was a
    /// leading chevron, which in a list is the disclosure idiom — it promises
    /// to unfold something in place, and this pushes a screen.
    ///
    /// The sentence itself comes from the filter — see `scopeNote`. To do gets
    /// none, and so gets no block at all.
    @ViewBuilder
    private var doneWindowNote: some View {
        if let note = store.state.scopeNote, !store.isLoading {
            HStack(alignment: .top, spacing: 12) {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Text alone, like every other capsule of this kind in the app.
                // A symbol beside it costs about a quarter of the width the
                // sentence needs, and on a small phone that is two more lines
                // of wrap to save a glyph nobody was reading.
                Button { store.send(.openArchiveTapped) } label: {
                    Text(L10n.tasksArchiveButton)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .fixedSize()
            }
            .glassListRow(insets: .init(
                top: 0,
                leading: Metrics.screenPadding,
                bottom: Metrics.stackSpacing,
                trailing: Metrics.screenPadding
            ))
        }
    }

    @ViewBuilder
    private var list: some View {
        if store.isLoading {
            SkeletonList(rows: 5, height: 64)
                .glassListRow()
        } else if store.visible.isEmpty {
            // An empty Done tab is not an empty task list, and offering "Add a
            // task" under "Nothing to do" would be answering a question nobody
            // asked. The note below this already says where the older ones
            // went; this says why the list in front of them is short.
            if store.filter == .done {
                EmptyStateView(
                    title: L10n.tasksDoneEmptyTitle,
                    message: L10n.tasksDoneEmptyMessage,
                    symbol: "checkmark.seal"
                )
                .padding(.top, 48)
                .glassListRow()
            } else {
                EmptyStateView(
                    title: L10n.homeTasksEmptyTitle,
                    message: L10n.homeTasksEmptyMessage,
                    symbol: "checkmark.seal",
                    action: .init(title: L10n.commonAdd) { store.send(.composeTapped) }
                )
                .padding(.top, 48)
                .glassListRow()
            }
        } else {
            ForEach(Array(store.visible.enumerated()), id: \.element.id) { index, task in
                TaskListRow(
                    task: task,
                    assignee: store.state.assigneeName(for: task),
                    onToggle: {
                        if !task.isCompleted { ticks += 1 }
                        store.send(.toggled(task.id))
                    }
                )
                // Only the first screenful is choreographed: List realises rows
                // as they scroll in, so staggering all of them would fade every
                // arriving row in behind a delay.
                .appearInPlace(index < 8 ? index : 0)
                .glassListRow()
                // A finished chore gets both verbs, because they are genuinely
                // different things to want and neither is a good guess at the
                // other: Archive files it and the record stays; Delete destroys
                // the record and stops to say so by name. An open chore gets
                // only Delete — nobody ever did it, so there is nothing to file
                // and nothing to warn about.
                //
                // Full swipe only where it is cheap. Carrying on past the edge
                // is a gesture for something you can shrug off, which archiving
                // is; on a finished row it would land on whichever of the two
                // buttons happened to be outermost.
                .swipeActions(edge: .trailing, allowsFullSwipe: !task.isCompleted) {
                    Button(role: .destructive) {
                        store.send(.deleteTapped(task.id))
                    } label: {
                        Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                    }

                    if task.isCompleted {
                        Button {
                            store.send(.archiveTapped(task.id))
                        } label: {
                            Label { Text(L10n.tasksArchiveAction) } icon: {
                                Image(systemName: "archivebox")
                            }
                        }
                        .tint(Palette.warning)
                    }
                }
            }
        }
    }
}

private struct TaskListRow: View {
    let task: HouseTask
    let assignee: String?
    let onToggle: () -> Void

    /// Ticks from this row's own checkbox, for the pop. Local for the same
    /// reason the haptic is: a chore somebody else finished arrives as a plain
    /// change of glyph, not as a celebration of a tap nobody here made.
    @State private var pops = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Just the card. The swipe is the List's, and it reaches VoiceOver as an
    /// action without being asked to.
    var body: some View { card }

    private var card: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Palette.success : Color.secondary)
                    // The tick grows out of the ring rather than swapping in.
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                    // Squash, overshoot, settle: the box answers the thumb.
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

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    // The strikethrough is drawn by a second copy of the title
                    // whose letters are clear, so the line alone can be swept
                    // across — left to right as the chore is ticked, back the
                    // other way when it is reopened. It exists only while the
                    // chore is done, so an open row carries nothing extra.
                    .overlay(alignment: .leading) {
                        if task.isCompleted {
                            Text(task.title)
                                .font(.subheadline.weight(.medium))
                                .strikethrough(color: .secondary)
                                .foregroundStyle(.clear)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .transition(strikeTransition)
                                .accessibilityHidden(true)
                        }
                    }

                HStack(spacing: 8) {
                    Label {
                        Text(task.kind.title)
                    } icon: {
                        Image(systemName: task.kind.symbol)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if let assignee {
                        Text(assignee).font(.caption2).foregroundStyle(.secondary)
                    }

                    if let due = task.dueDate {
                        Text(due.date, format: .relative(presentation: .named))
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? Palette.danger : .secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if !task.isCompleted, task.priority != .medium {
                Badge(String(localized: task.priority.title), tint: task.priority.tint)
            }
        }
        .glassRow()
        .animation(Motion.spring, value: task.isCompleted)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(task.isCompleted ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: Text(L10n.tasksToggleAction), toggle)
    }

    /// Only ticking pops; reopening a chore is a correction, not an event.
    /// Under Reduce Motion the glyph still changes and the phone still taps —
    /// it is the squash and the overshoot that go.
    private func toggle() {
        if !task.isCompleted, !reduceMotion { pops += 1 }
        onToggle()
    }

    private var strikeTransition: AnyTransition {
        reduceMotion ? .opacity : AnyTransition(Strike()).animation(.easeOut(duration: 0.25))
    }

    /// The strikethrough drawing itself across the title. A horizontal scale
    /// rather than a mask, because the letters on this layer are clear — all
    /// there is to stretch is the line, and a stretched line is a growing one.
    private struct Strike: Transition {
        func body(content: Content, phase: TransitionPhase) -> some View {
            content.scaleEffect(x: phase.isIdentity ? 1 : 0.01, anchor: .leading)
        }
    }
}

struct ComposeTaskSheet: View {
    @Bindable var store: StoreOf<ComposeTaskFeature>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $store.title) { Text(L10n.tasksTitleLabel) }
                        .textInputAutocapitalization(.sentences)
                    TextField(text: $store.details, axis: .vertical) {
                        Text(L10n.tasksDetailsLabel)
                    }
                    .lineLimit(2...5)
                }

                Section {
                    Picker(selection: $store.kind) {
                        ForEach(HouseTask.Kind.allCases, id: \.self) { kind in
                            Label { Text(kind.title) } icon: {
                                Image(systemName: kind.symbol)
                            }
                            .tag(kind)
                        }
                    } label: {
                        Text(L10n.tasksKindLabel)
                    }

                    Picker(selection: $store.priority) {
                        ForEach(HouseTask.Priority.allCases, id: \.self) { priority in
                            Text(priority.title).tag(priority)
                        }
                    } label: {
                        Text(L10n.tasksPriorityLabel)
                    }
                    .pickerStyle(.segmented)

                    Picker(selection: $store.assignee) {
                        Text(L10n.tasksAssigneeNone).tag(UserID?.none)
                        ForEach(store.members) { member in
                            Text(member.displayName).tag(UserID?.some(member.id))
                        }
                    } label: {
                        Text(L10n.tasksAssigneeLabel)
                    }
                }

                Section {
                    Toggle(isOn: $store.hasDueDate) { Text(L10n.tasksDueDateLabel) }
                    if store.hasDueDate {
                        DatePicker(
                            selection: $store.dueDate,
                            displayedComponents: [.date]
                        ) {
                            Text(L10n.tasksDueDateLabel)
                        }
                        .datePickerStyle(.graphical)
                    }
                }

                if let error = store.inlineError {
                    Section {
                        Label { Text(error) } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                        .foregroundStyle(Palette.danger)
                    }
                }
            }
            .animation(Motion.spring, value: store.hasDueDate)
            .navigationTitle(Text(L10n.tasksComposeTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.send(.submitTapped) } label: {
                        if store.isSubmitting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(L10n.commonSave).bold()
                        }
                    }
                    .disabled(!store.canSubmit)
                }
            }
        }
        .presentationDetents([.large])
    }
}
