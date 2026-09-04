import ComposableArchitecture
import SwiftUI

public struct TasksView: View {
    @Bindable var store: StoreOf<TasksFeature>

    @Environment(\.theme) private var theme
    @Namespace private var glass

    public init(store: StoreOf<TasksFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.stackSpacing) {
                Picker(selection: $store.filter) {
                    ForEach(TasksFeature.State.Filter.allCases, id: \.self) { filter in
                        Text(filter.title).tag(filter)
                    }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .padding(.horizontal, Metrics.screenPadding)

                list
            }
            .padding(.bottom, Metrics.scrollBottomInset)
        }
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
        .animation(Motion.spring, value: store.visible)
    }

    @ViewBuilder
    private var list: some View {
        if store.isLoading {
            SkeletonList(rows: 5, height: 64)
                .padding(.horizontal, Metrics.screenPadding)
        } else if store.visible.isEmpty {
            EmptyStateView(
                title: L10n.homeTasksEmptyTitle,
                message: L10n.homeTasksEmptyMessage,
                symbol: "checkmark.seal",
                action: .init(title: L10n.commonAdd) { store.send(.composeTapped) }
            )
            .padding(.top, 48)
        } else {
            GlassGroup {
                VStack(spacing: Metrics.stackSpacing) {
                    ForEach(Array(store.visible.enumerated()), id: \.element.id) { index, task in
                        TaskListRow(
                            task: task,
                            assignee: store.state.assigneeName(for: task),
                            onToggle: { store.send(.toggled(task.id)) },
                            onDelete: { store.send(.deleteTapped(task.id)) }
                        )
                        .glassEffectID(task.id.rawValue, in: glass)
                        .appear(index)
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }
        }
    }
}

private struct TaskListRow: View {
    let task: HouseTask
    let assignee: String?
    let onToggle: () -> Void
    let onDelete: () -> Void

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
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .animation(Motion.spring, value: task.isCompleted)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
            }
        }
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
