import ComposableArchitecture
import SwiftUI

public struct TasksView: View {
    @Bindable var store: StoreOf<TasksFeature>

    @Environment(\.theme) private var theme

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.composeTapped) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(L10n.tasksComposeTitle))
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
                Button { store.send(.historyTapped) } label: {
                    Text(L10n.tasksHistoryButton)
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
                    onToggle: { store.send(.toggled(task.id)) }
                )
                // Only the first screenful is choreographed: List realises rows
                // as they scroll in, so staggering all of them would fade every
                // arriving row in behind a delay.
                .appearInPlace(index < 8 ? index : 0)
                .glassListRow()
                // Which verb a row gets is decided by the row, not by a dialog
                // asking the person to choose between two meanings of "delete"
                // while their finger is still on the screen. An unfinished
                // chore can be thrown away; a finished one is a thing the
                // household did, so the most the list may do is stop showing
                // it.
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if task.isCompleted {
                        Button {
                            store.send(.archiveTapped(task.id))
                        } label: {
                            Label { Text(L10n.tasksArchiveAction) } icon: {
                                Image(systemName: "archivebox")
                            }
                        }
                        .tint(Palette.warning)
                    } else {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(task.id))
                        } label: {
                            Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                        }
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

    /// Just the card. The swipe is the List's, and it reaches VoiceOver as an
    /// action without being asked to.
    var body: some View { card }

    private var card: some View {
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

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

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
        .accessibilityAction(named: Text(L10n.tasksToggleAction), onToggle)
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
