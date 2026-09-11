import ComposableArchitecture
import SwiftUI

public struct ShoppingView: View {
    @Bindable var store: StoreOf<ShoppingFeature>

    @Environment(\.theme) private var theme
    @FocusState private var isComposerFocused: Bool

    /// Everything the list shows, kept out of `body` — inline, the whole
    /// screen was one expression and the compiler gave up type-checking it.
    @ViewBuilder
    private var content: some View {
        if store.isLoading {
            SkeletonList(rows: 5, height: 52)
                .glassListRow()
        } else if store.items.isEmpty {
            EmptyStateView(
                title: L10n.shoppingEmptyTitle,
                message: L10n.shoppingEmptyMessage,
                symbol: "cart"
            )
            .padding(.top, 48)
            .glassListRow()
        } else {
            header
            eventSections
            partSections
            mealSections
            viewModeToggle
            if store.isGrouped {
                pendingSections
            } else {
                flatSection
            }
            purchasedSection
        }
    }

    /// Every fold on the screen as one comparable value.
    private struct Folds: Equatable {
        let categories: Set<ShoppingItem.Category>
        let meals: Set<RecipeID>
        let events: Set<EventID>
        let issues: Set<IssueID>
    }

    private var folds: Folds {
        Folds(
            categories: store.collapsed,
            meals: store.collapsedMeals,
            events: store.collapsedEvents,
            issues: store.collapsedIssues
        )
    }

    /// A heading row: the screen's side padding, air above it to stand in for
    /// the section spacing the stack used to provide, and the row gap below.
    private var headerInsets: EdgeInsets {
        .init(
            top: Metrics.sectionSpacing,
            leading: Metrics.screenPadding,
            bottom: Metrics.stackSpacing,
            trailing: Metrics.screenPadding
        )
    }

    public init(store: StoreOf<ShoppingFeature>) {
        self.store = store
    }

    /// A real `List`, so every swipe on this screen is the system's.
    ///
    /// It was a `LazyVStack` behind `SwipeToDelete`, which worked until the row
    /// surface started leaning toward the finger and the two began racing for
    /// the same touch. Recipes and Tasks went this way first;
    /// `UISwipeActionsConfiguration` does not race anything.
    ///
    /// The headers are rows rather than `Section` headers on purpose: a plain
    /// `List` pins section headers to the top as you scroll, and an aisle
    /// heading that sticks over a card it no longer belongs to is worse than
    /// one that scrolls away.
    public var body: some View {
        List { content }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 120, for: .scrollContent)
        // Rows are as tall as their card; without this the chips and headers
        // are padded out to the system's 44pt minimum.
        .environment(\.defaultMinListRowHeight, 0)
        // A collapse is a row insertion now, so the List animates it — but only
        // if the change arrives inside an animation. One value for all four
        // kinds of fold, because four `.animation` modifiers on a list this
        // size is four more things for the type checker to chew on.
        .animation(Motion.spring, value: folds)
        .background(Backdrop(tint: theme.accent))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let pending = store.pendingDeletion {
                    UndoToast(L10n.shoppingItemDeleted(pending.name)) {
                        store.send(.undoDeleteTapped)
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
                composer
            }
            .animation(Motion.spring, value: store.pendingDeletion)
        }
        .navigationTitle(Text(L10n.managementModuleShoppingTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.purchased.isEmpty || store.state.isClearing(.purchased) {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        store.send(.clearPurchasedTapped)
                    } label: {
                        if store.state.isClearing(.purchased) {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                        }
                    }
                    .disabled(store.state.isClearing(.purchased))
                    .accessibilityLabel(Text(L10n.shoppingClearPurchased))
                }
            }
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .animation(Motion.spring, value: store.items)
    }

    /// How much of the shop is done, at a glance.
    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .strokeBorder(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: store.progress)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(store.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)
            .animation(Motion.spring, value: store.progress)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.shoppingHeaderTitle)
                    .font(.headline)
                Text(L10n.shoppingHeaderSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    AnimatedNumber(store.leftCount)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text(L10n.shoppingStatsLeft)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    AnimatedNumber(store.doneCount)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.success)
                    Text(L10n.shoppingStatsDone)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Metrics.cardPadding)
        .glassCard()
        .accessibilityElement(children: .combine)
        .glassListRow(insets: .init(
            top: 0,
            leading: Metrics.screenPadding,
            bottom: Metrics.stackSpacing,
            trailing: Metrics.screenPadding
        ))
    }

    /// Grouped by aisle, or one flat list. Remembered between visits.
    private var viewModeToggle: some View {
        HStack(spacing: 8) {
            ForEach([true, false], id: \.self) { grouped in
                Chip(
                    String(localized: grouped
                        ? L10n.shoppingCategoriesViewMode
                        : L10n.shoppingListViewMode),
                    symbol: grouped ? "rectangle.3.group" : "list.bullet",
                    isSelected: store.isGrouped == grouped
                ) {
                    store.send(.viewModeToggled(grouped: grouped))
                }
            }
            Spacer(minLength: 0)
        }
        .animation(Motion.spring, value: store.isGrouped)
        .glassListRow(insets: headerInsets)
    }

    /// One flat list of everything outstanding.
    private var flatSection: some View {
        ForEach(store.pendingFlat) { item in
            ShoppingRow(
                item: item,
                showsCategory: true,
                onToggle: { store.send(.togglePurchased(item.id)) }
            )
            .glassListRow()
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    store.send(.deleteTapped(item.id))
                } label: {
                    Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                }
            }
        }
    }

    /// Everything that is on the list for something in the calendar, under the
    /// event it belongs to.
    ///
    /// The outermost grouping, above the meals: when a household is shopping for
    /// Saturday, "Saturday" is the thing they are shopping for, and its four
    /// recipes and six loose items split across four aisles is exactly the
    /// problem the meal groups were introduced to solve one level down.
    @ViewBuilder
    private var eventSections: some View {
        ForEach(store.eventGroups, id: \.eventID) { group in
            let isCollapsed = store.state.isCollapsed(event: group.eventID)
            GroupHeader(
                symbol: "calendar",
                title: String(localized: L10n.shoppingForEvent(group.title)),
                done: store.state.doneCount(inEvent: group.eventID),
                total: store.state.totalCount(inEvent: group.eventID),
                isCollapsed: isCollapsed,
                isClearing: store.state.isClearing(.event(group.eventID)),
                onToggle: { store.send(.eventToggled(group.eventID)) },
                onClear: { store.send(.clearEventTapped(group.eventID)) }
            )
            .glassListRow(insets: headerInsets)

            if !isCollapsed {
                ForEach(group.items) { item in
                    ShoppingRow(
                        item: item,
                        showsCategory: false,
                        onToggle: { store.send(.togglePurchased(item.id)) }
                    )
                    .glassListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(item.id))
                        } label: {
                            Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                        }
                    }
                }
            }
        }
    }

    /// Everything on the list because something is broken, under the repair it
    /// belongs to.
    ///
    /// Between the events and the meals, which is the order the reasons actually
    /// nest: a party is an occasion, a repair is a job, a recipe is a dish. Its
    /// own group for the same reason a party's shopping is — the washer and the
    /// PTFE tape are one errand, and split across the hardware and household
    /// aisles they are two things nobody remembers are related.
    @ViewBuilder
    private var partSections: some View {
        ForEach(store.partGroups, id: \.issueID) { group in
            let isCollapsed = store.state.isCollapsed(issue: group.issueID)
            GroupHeader(
                symbol: "wrench.adjustable.fill",
                title: String(localized: L10n.shoppingForRepair(group.title)),
                done: store.state.doneCount(inIssue: group.issueID),
                total: store.state.totalCount(inIssue: group.issueID),
                isCollapsed: isCollapsed,
                isClearing: store.state.isClearing(.issue(group.issueID)),
                onToggle: { store.send(.issueToggled(group.issueID)) },
                onClear: { store.send(.clearPartsTapped(group.issueID)) }
            )
            .glassListRow(insets: headerInsets)

            if !isCollapsed {
                ForEach(group.items) { item in
                    ShoppingRow(
                        item: item,
                        showsCategory: false,
                        onToggle: { store.send(.togglePurchased(item.id)) }
                    )
                    .glassListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(item.id))
                        } label: {
                            Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                        }
                    }
                }
            }
        }
    }

    /// Everything that came over from a recipe, under the meal it belongs to.
    ///
    /// Above the aisles on purpose: a meal is a thing you are shopping *for*,
    /// and splitting its ingredients across four category headings is exactly
    /// what makes a recipe hard to shop.
    @ViewBuilder
    private var mealSections: some View {
        ForEach(store.mealGroups, id: \.recipeID) { group in
            let isCollapsed = store.state.isCollapsed(meal: group.recipeID)
            GroupHeader(
                symbol: "fork.knife",
                title: String(localized: L10n.shoppingForRecipe(group.title)),
                done: store.state.doneCount(inMeal: group.recipeID),
                total: store.state.totalCount(inMeal: group.recipeID),
                isCollapsed: isCollapsed,
                isClearing: store.state.isClearing(.meal(group.recipeID)),
                onToggle: { store.send(.mealToggled(group.recipeID)) },
                onClear: { store.send(.clearMealTapped(group.recipeID)) }
            )
            .glassListRow(insets: headerInsets)

            if !isCollapsed {
                ForEach(group.items) { item in
                    ShoppingRow(
                        item: item,
                        showsCategory: false,
                        onToggle: { store.send(.togglePurchased(item.id)) }
                    )
                    .glassListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(item.id))
                        } label: {
                            Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                        }
                    }
                }
            }
        }
    }

    private var pendingSections: some View {
        ForEach(store.pendingByCategory, id: \.category) { group in
            let isCollapsed = store.state.isCollapsed(group.category)
            CategoryHeader(
                category: group.category,
                done: store.state.doneCount(in: group.category),
                total: store.state.totalCount(in: group.category),
                isCollapsed: isCollapsed,
                isClearing: store.state.isClearing(.category(group.category)),
                onToggle: { store.send(.categoryToggled(group.category)) },
                onClear: { store.send(.clearCategoryTapped(group.category)) }
            )
            .glassListRow(insets: headerInsets)

            if !isCollapsed {
                ForEach(group.items) { item in
                ShoppingRow(
                    item: item,
                    showsCategory: false,
                    onToggle: { store.send(.togglePurchased(item.id)) }
                )
                .glassListRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.send(.deleteTapped(item.id))
                    } label: {
                        Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                    }
                }
            }
            }
        }
    }

    @ViewBuilder
    private var purchasedSection: some View {
        if !store.purchased.isEmpty {
            SectionHeader(L10n.shoppingPurchasedSection, symbol: "checkmark.circle")
                .glassListRow(insets: headerInsets)

            ForEach(store.purchased) { item in
                ShoppingRow(
                    item: item,
                    showsCategory: false,
                    onToggle: { store.send(.togglePurchased(item.id)) }
                )
                .glassListRow()
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    store.send(.deleteTapped(item.id))
                } label: {
                    Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                }
            }
            }
        }
    }

    /// Pinned to the bottom so adding several things in a row never requires
    /// scrolling back up or reopening a sheet.
    private var composer: some View {
        HStack(spacing: 10) {
            Menu {
                Picker(selection: $store.draftCategory) {
                    ForEach(ShoppingItem.Category.allCases, id: \.self) { category in
                        Label { Text(category.title) } icon: {
                            Image(systemName: category.symbol)
                        }
                        .tag(category)
                    }
                } label: { EmptyView() }
            } label: {
                Image(systemName: store.draftCategory.symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(Text(store.draftCategory.title))

            TextField(text: $store.draft) {
                Text(L10n.shoppingAddPlaceholder)
            }
            .focused($isComposerFocused)
            .submitLabel(.done)
            .onSubmit { store.send(.addTapped) }

            Button { store.send(.addTapped) } label: {
                // An item has no id until the server answers, so it cannot be
                // shown as a row yet. The button says the work is happening
                // instead — before, typing and sending looked identical to
                // typing and nothing at all.
                if store.pendingAdds > 0 {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 28, height: 28)
                }
            }
            .buttonStyle(.pressable)
            .disabled(!store.canAdd)
            .opacity(store.canAdd || store.pendingAdds > 0 ? 1 : 0.4)
            .animation(Motion.fade, value: store.canAdd)
            .animation(Motion.fade, value: store.pendingAdds > 0)
            .accessibilityLabel(Text(L10n.commonAdd))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.bottom, 8)
    }
}

private struct ShoppingRow: View {
    let item: ShoppingItem
    /// The flat view has no section headers, so each row says which aisle it is
    /// in. In the grouped view that would just repeat the header.
    var showsCategory: Bool = false
    let onToggle: () -> Void

    /// Just the card. The swipe belongs to the `List` this row sits in — a
    /// hand-built one lost the touch to whatever else wanted it.
    var body: some View { card }

    private var card: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isPurchased ? Palette.success : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 32, height: 32)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .sensoryFeedback(.success, trigger: item.isPurchased) { _, bought in bought }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.subheadline)
                    .strikethrough(item.isPurchased, color: .secondary)
                    .foregroundStyle(item.isPurchased ? .secondary : .primary)
                    .lineLimit(1)
                if showsCategory {
                    Label {
                        Text(item.category.title)
                    } icon: {
                        Image(systemName: item.category.symbol)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if let quantity = item.quantity, quantity > 1 {
                Text(quantity, format: .number.precision(.fractionLength(0...1)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: quantity))
                    .animation(Motion.spring, value: quantity)
            }
        }
        .glassRow()
        .animation(Motion.spring, value: item.isPurchased)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(item.isPurchased ? [.isButton, .isSelected] : .isButton)
    }
}

/// A collapsible aisle header with its own progress.
private struct CategoryHeader: View {
    let category: ShoppingItem.Category
    let done: Int
    let total: Int
    let isCollapsed: Bool
    let isClearing: Bool
    let onToggle: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: category.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                    .background(.tint.opacity(0.14), in: .circle)

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(L10n.shoppingCategoryCompletedItems(done, total))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(isCollapsed ? L10n.commonSeeAll : L10n.commonClose))

            GroupMenu(isClearing: isClearing, onClear: onClear)
        }
        .animation(Motion.spring, value: isCollapsed)
    }
}

/// The destructive action a group header carries. Its own control, because a
/// `Button` inside another `Button`'s label never receives a tap.
private struct GroupMenu: View {
    /// True while this group's clear is still in flight. The rows are already
    /// gone — this is here so a slow network reads as work in progress rather
    /// than as a menu that did nothing.
    var isClearing: Bool = false
    let onClear: () -> Void

    var body: some View {
        Menu {
            Button(role: .destructive, action: onClear) {
                Label { Text(L10n.shoppingRemoveAll) } icon: {
                    Image(systemName: "trash")
                }
            }
        } label: {
            Group {
                if isClearing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.accessoryStrong)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(.rect)
        }
        .disabled(isClearing)
        .animation(Motion.fade, value: isClearing)
        .accessibilityLabel(Text(L10n.shoppingRemoveAll))
    }
}


/// A foldable heading for anything the list is shopping *for* — a meal, an
/// event — with its own progress. The aisle headers' twin.
///
/// One view for both, because they differ only in a symbol and a phrase: two
/// copies of this drifted apart in every other place this app tried it.
private struct GroupHeader: View {
    let symbol: String
    let title: String
    let done: Int
    let total: Int
    let isCollapsed: Bool
    let isClearing: Bool
    let onToggle: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                    .background(.tint.opacity(0.14), in: .circle)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(L10n.shoppingCategoryCompletedItems(done, total))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(isCollapsed ? L10n.commonSeeAll : L10n.commonClose))

            GroupMenu(isClearing: isClearing, onClear: onClear)
        }
        .animation(Motion.spring, value: isCollapsed)
    }
}
