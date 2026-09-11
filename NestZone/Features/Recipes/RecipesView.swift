import ComposableArchitecture
import SwiftUI

public struct RecipesView: View {
    @Bindable var store: StoreOf<RecipesFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<RecipesFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .background(Backdrop(tint: theme.accent))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .searchable(text: $store.searchText, prompt: Text(L10n.commonSearch))
            .navigationTitle(Text(L10n.recipesScreenTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { store.send(.composeTapped) } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(L10n.commonAdd))
                }
            }
            .task { await store.send(.task).finish() }
            .navigationDestination(
                item: $store.scope(state: \.destination?.detail, action: \.destination.detail)
            ) { RecipeDetailView(store: $0) }
            .sheet(
                item: $store.scope(state: \.destination?.compose, action: \.destination.compose)
            ) { ComposeRecipeSheet(store: $0) }
            .alert($store.scope(state: \.alert, action: \.alert))
            .animation(Motion.spring, value: store.visible)
    }

    /// A real `List`, so the swipe is the system's rather than a rebuild of it.
    ///
    /// `.swipeActions` only exists on `List`, which is why the shelf used to be
    /// a `LazyVStack` behind a hand-built `SwipeToDelete`. Every bug that came
    /// out of that — a drag the scroll view cancelled leaving the row stranded
    /// half open, a committed row parked off the edge that the confirmation
    /// alert could never bring back, a reveal that grew from nothing instead of
    /// out of the trailing edge — is something `UISwipeActionsConfiguration`
    /// has always handled. The list carries the List's chrome away instead:
    /// clear row backgrounds, no separators, no insets, and the glass card
    /// supplies the whole surface.
    ///
    /// The cost is the `GlassEffectContainer`: it cannot span List cells, so
    /// the cards no longer reach for one another. Glass rows, separate shapes.
    private var content: some View {
        List {
            filterBar
                .glassListRow(insets: .init(
                    top: 0, leading: 0, bottom: Metrics.stackSpacing, trailing: 0
                ))

            results
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, Metrics.scrollBottomInset, for: .scrollContent)
        // The house radius is 32, which suits a short row that reads as a pill.
        // A recipe card is twice that tall and carries four lines, and at 32 the
        // corners eat into the text block and it stops reading as a card. Back
        // to `cardRadius`, said as a difference from the house style rather than
        // as a literal, so everything else here still follows the one place.
        .glassListStyle(.default.with(rowRadius: Metrics.cardRadius))
        // Rows are exactly as tall as their card; without this the filter bar
        // is padded out to the system's 44pt minimum.
        .environment(\.defaultMinListRowHeight, 0)
    }

    @ViewBuilder
    private var results: some View {
        // Both tabs load: Explore reads the bundled catalogue off disk, and
        // showing "no recipes yet" for that moment was a lie with an Add button
        // attached to it.
        if store.isWaiting {
            SkeletonList(rows: 4, height: 96)
                .glassListRow()
        } else if store.visible.isEmpty {
            emptyState
                .glassListRow()
        } else {
            ForEach(Array(store.visible.enumerated()), id: \.element.id) { index, recipe in
                RecipeCard(recipe: recipe) { store.send(.recipeTapped(recipe)) }
                    // Only the first screenful is choreographed. List rows are
                    // realised as they scroll in, so staggering all of them
                    // would fade every arriving row in behind a delay of up to
                    // a third of a second — which reads as the list struggling
                    // to keep up rather than as an entrance.
                    .appear(index < 8 ? index : 0)
                    .glassListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        // Only the home's own shelf: an Explore recipe is
                        // bundled with the app and there is nothing to delete.
                        if store.tab == .mine {
                            Button(role: .destructive) {
                                store.send(.deleteTapped(recipe.id))
                            } label: {
                                Label {
                                    Text(L10n.commonDelete)
                                } icon: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
            }
        }
    }

    private var emptyState: some View {
        let action: EmptyStateView.Action = store.hasActiveFilters
            ? .init(title: L10n.recipesExploreFiltersClearButton) {
                store.send(.clearFiltersTapped)
            }
            : .init(title: L10n.commonAdd) { store.send(.composeTapped) }

        return EmptyStateView(
            title: L10n.recipesEmptyStateTitle,
            message: L10n.recipesEmptyStateSubtitle,
            symbol: "fork.knife",
            action: action
        )
        .padding(.top, 48)
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Picker(selection: $store.tab) {
                    Text(L10n.recipesScreenTitle).tag(RecipesFeature.State.Tab.mine)
                    Text(L10n.recipesExploreButton).tag(RecipesFeature.State.Tab.explore)
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .frame(width: 220)

                ForEach(Recipe.Difficulty.allCases, id: \.self) { difficulty in
                    Chip(
                        String(localized: difficulty.title),
                        isSelected: store.difficultyFilter == difficulty
                    ) {
                        store.difficultyFilter = store.difficultyFilter == difficulty
                            ? nil : difficulty
                    }
                }

                if store.hasActiveFilters {
                    Chip(
                        String(localized: L10n.recipesExploreFiltersClearAll),
                        symbol: "xmark"
                    ) { store.send(.clearFiltersTapped) }
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
        .scrollIndicators(.hidden)
    }
}

private struct RecipeCard: View {
    @Environment(\.glassListStyle) private var style

    let recipe: Recipe
    let action: () -> Void

    var body: some View {
        card
            // Radius and lean from the style, padding from the card itself —
            // it lays out its own content and would be padded twice by
            // `glassRow`. The shelf overrides the radius below.
            .glassCard(cornerRadius: style.rowRadius, interactive: style.rowInteractive)
            // Deliberately not a `Button`, and deliberately no `.contextMenu`.
            // Both hold the touch on the way down to work out whether the press
            // is going to become a tap, a long press or a menu lift, and while
            // they are deciding the enclosing ScrollView is not allowed to pan —
            // so a finger landing on a card could not scroll the list. A
            // `TapGesture` fails the instant the finger moves, which is why the
            // rows in Tasks and Shopping scroll cleanly: neither is a button
            // either. Delete lives on the swipe and in the detail view.
            .contentShape(.rect)
            .onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let summary = recipe.summary {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                if let difficulty = recipe.difficulty {
                    Badge(String(localized: difficulty.title), tint: difficulty.tint)
                }
            }

            HStack(spacing: 12) {
                if let minutes = recipe.totalMinutes {
                    Label {
                        Text(L10n.recipesCardTimeFormat(minutes))
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
                if let servings = recipe.servings {
                    Label {
                        Text(servings, format: .number)
                            .contentTransition(.numericText(value: Double(servings)))
                            .animation(Motion.spring, value: servings)
                    } icon: {
                        Image(systemName: "person.2")
                    }
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecipeDetailView: View {
    @Bindable var store: StoreOf<RecipeDetailFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if store.isCooking {
                CookingModeView(store: store)
            } else {
                overview
            }
        }
        .animation(Motion.spring, value: store.isCooking)
        .background(Backdrop(tint: theme.accent))
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .safeAreaInset(edge: .bottom) {
            if let added = store.addedToList {
                AddedToListToast(count: added) { store.send(.goToShoppingTapped) }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: store.addedToList)
        .navigationTitle(Text(store.recipe.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.canSaveToHome {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) { store.send(.deleteTapped) } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(Text(L10n.commonDelete))
                }
            }
        }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                if let summary = store.recipe.summary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .appear(0)
                }

                facts.appear(1)
                ingredients.appear(2)
                stepsPreview.appear(3)
                actions.appear(4)
            }
            .padding(Metrics.screenPadding)
        }
    }

    private var facts: some View {
        GlassGroup {
            HStack(spacing: Metrics.stackSpacing) {
                if let minutes = store.recipe.totalMinutes {
                    Fact(symbol: "clock", value: "\(minutes)m", label: L10n.recipesDetailTimeTotalFormat(minutes))
                }
                if let servings = store.recipe.servings {
                    Fact(symbol: "person.2", value: "\(servings)", label: L10n.recipesNewRecipeServingsPicker)
                }
                if let difficulty = store.recipe.difficulty {
                    Fact(
                        symbol: "chart.bar",
                        value: String(localized: difficulty.title),
                        label: L10n.recipesNewRecipeDifficultyPicker
                    )
                }
            }
        }
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.recipesDetailIngredientsTitle,
                symbol: "list.bullet"
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(store.recipe.ingredients.enumerated()), id: \.offset) { index, item in
                        Button { store.send(.ingredientToggled(index)) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: store.checkedIngredients.contains(index)
                                    ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(store.checkedIngredients.contains(index)
                                        ? Palette.success : Color.secondary)
                                    .contentTransition(.symbolEffect(.replace))
                                Text(item)
                                    .font(.subheadline)
                                    .strikethrough(store.checkedIngredients.contains(index))
                                    .foregroundStyle(store.checkedIngredients.contains(index)
                                        ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .animation(Motion.spring, value: store.checkedIngredients)
    }

    private var stepsPreview: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.recipesDetailStepsTitle, symbol: "list.number")
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(store.recipe.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(theme.accent, in: .circle)
                            Text(step)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    /// Confirmation lives on the button for a couple of seconds rather than in
    /// an alert — nothing here needs acknowledging.
    /// Three states, and the button says which it is in: nothing on the list,
    /// some of it on the list, all of it.
    private var addToListTitle: LocalizedStringResource {
        if store.isFullyOnList { return L10n.recipesDetailGoToList }
        if store.ingredientsOnList > 0 {
            return L10n.recipesDetailAddMissing(store.missingIngredients.count)
        }
        return L10n.recipesDetailAddToShopping
    }

    private var addToListSymbol: String {
        store.isFullyOnList ? "cart" : "cart.badge.plus"
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Metrics.stackSpacing) {
            // Cooking and saving are independent: a recipe you are browsing in
            // Explore is just as cookable as one you already own, and gating
            // cooking behind "save it first" was wrong.
            if store.canCook {
                // Cooking opens on the ingredient checklist, so unless there is
                // nothing to gather, this button does not start the cooking —
                // it starts the prep. The one at the end of the checklist is
                // what starts the cooking.
                let gathers = !store.recipe.ingredients.isEmpty
                PrimaryButton(
                    gathers ? L10n.recipesDetailStartPreparing : L10n.recipesDetailStartCooking,
                    symbol: gathers ? "checklist" : "flame.fill"
                ) {
                    store.send(.beginCookingTapped)
                }
            }
            // Only for a recipe the home actually has — a bundled sample has no
            // id a meal plan could point at until it is saved — and only when
            // it is not already on tonight's menu, where the offer was noise.
            if !store.canSaveToHome, !store.isTonightsDinner {
                SecondaryButton(L10n.recipesDetailPlanTonight, symbol: "moon.stars.fill") {
                    store.send(.planTonightTapped)
                }
                .disabled(store.isPlanning)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if store.isTonightsDinner {
                // Said, not offered.
                Label {
                    Text(L10n.recipesDetailPlannedTonight)
                } icon: {
                    Image(systemName: "moon.stars.fill")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .transition(.opacity)
            }

            // Sending the ingredients over is useful whether or not the recipe
            // is saved, and whether or not you cook it today.
            if !store.recipe.ingredients.isEmpty {
                VStack(spacing: 6) {
                    SecondaryButton(addToListTitle, symbol: addToListSymbol) {
                        store.send(store.isFullyOnList ? .goToShoppingTapped : .addToShoppingTapped)
                    }
                    .disabled(store.isAddingToList)

                    // What the button would leave behind, said before it is
                    // tapped rather than after.
                    if store.ingredientsOnList > 0 {
                        Text(store.isFullyOnList
                            ? L10n.recipesDetailAllOnList
                            : L10n.recipesDetailOnListCount(
                                store.ingredientsOnList, store.recipe.ingredients.count
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .transition(.opacity)
                    }
                }
                .animation(Motion.spring, value: store.ingredientsOnList)
            }
            if store.canSaveToHome {
                SecondaryButton(L10n.recipesExploreAddToMyRecipes, symbol: "plus") {
                    store.send(.saveToHomeTapped)
                }
                .disabled(store.isSaving)
            }
        }
        .animation(Motion.spring, value: store.isTonightsDinner)
    }
}

private struct Fact: View {
    let symbol: String
    let value: String
    let label: LocalizedStringResource

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.callout).foregroundStyle(.tint)
            Text(value).font(.system(.headline, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: Metrics.tightRadius)
    }
}

/// Full-screen cooking, in two phases: gather everything, then work the steps.
///
/// You cannot start the steps until every ingredient is ticked off — that is the
/// point of the first phase, and it is how the old app worked. The timer is new:
/// the old one had a timer button wired to nothing.
struct CookingModeView: View {
    @Bindable var store: StoreOf<RecipeDetailFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Metrics.stackSpacing) {
            header
            progress

            // Two halves of one session, each its own view: sharing an
            // identity meant the swap happened in place with nothing to
            // animate, so stepping from the ingredients to the first step just
            // blinked.
            Group {
                switch store.phase {
                case .ingredients: ingredients
                case .cooking: steps
                }
            }
            .id(store.phase)
            .transition(.opacity.combined(with: .offset(y: 8)))

            controls
        }
        .padding(Metrics.screenPadding)
        .animation(Motion.spring, value: store.phase)
        .animation(Motion.spring, value: store.step)
        // Cooking is hands-free by nature; a screen that sleeps mid-step is the
        // most annoying thing this view could do.
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var header: some View {
        HStack {
            IconButton(symbol: "xmark", label: L10n.commonClose) {
                store.send(.quitCookingTapped)
            }

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(store.phase == .ingredients
                    ? L10n.recipesCookingPrepareIngredients
                    : L10n.recipesCookingCookRecipe)
                    .font(.headline)
                Text(store.recipe.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Balances the close button so the title stays centred.
            Color.clear.frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
        }
    }

    private var progress: some View {
        VStack(spacing: 6) {
            HStack {
                Text(L10n.recipesCookingProgressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.phase == .ingredients
                    ? L10n.recipesCookingIngredientsProgress(
                        store.checkedIngredients.count, store.recipe.ingredients.count)
                    : L10n.recipesCookingStepsProgress(
                        store.step + 1, max(store.recipe.steps.count, 1)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText())
            }
            ProgressView(value: store.progress)
                .tint(theme.accent)
        }
        .animation(Motion.spring, value: store.progress)
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(L10n.recipesCookingCheckIngredientsInstruction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button { store.send(.allIngredientsToggled) } label: {
                    Text(store.allIngredientsChecked
                        ? L10n.recipesCookingClearAll
                        : L10n.recipesCookingMarkAll)
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .animation(Motion.spring, value: store.allIngredientsChecked)
            }

            ScrollView {
                GlassList {
                    ForEach(Array(store.recipe.ingredients.enumerated()), id: \.offset) { index, item in
                        let isChecked = store.checkedIngredients.contains(index)
                        Button { store.send(.ingredientToggled(index)) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isChecked ? Palette.success : Color.secondary)
                                    .contentTransition(.symbolEffect(.replace))
                                Text(item)
                                    .font(.subheadline)
                                    .strikethrough(isChecked, color: .secondary)
                                    .foregroundStyle(isChecked ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, Metrics.cardPadding)
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                        .glassCard(cornerRadius: Metrics.tightRadius)
                        .sensoryFeedback(.selection, trigger: isChecked)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxHeight: .infinity)
        .transition(.opacity)
    }

    private var steps: some View {
        VStack(spacing: Metrics.stackSpacing) {
            TabView(selection: Binding(
                get: { store.step },
                set: { store.send(.stepChanged($0)) }
            )) {
                ForEach(Array(store.recipe.steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 16) {
                        Text(L10n.recipesCookingStepCardTitle(index + 1, store.recipe.steps.count))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                        Text(step)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                    }
                    .padding(Metrics.cardPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .glassCard()
                    .padding(.horizontal, 2)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            timerBar
        }
        .frame(maxHeight: .infinity)
        .transition(.opacity)
    }

    /// Reads a duration out of the step text so a timer is one tap, not a
    /// number-entry exercise with floury hands.
    @ViewBuilder
    private var timerBar: some View {
        if store.timer.isRunning {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)

                Text(store.timer.formatted)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))

                ProgressView(value: store.timer.progress)
                    .tint(theme.accent)

                Button { store.send(.timerStopped) } label: {
                    Text(L10n.recipesTimerStop).font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack(spacing: 8) {
                if let suggested = store.state.suggestedDuration {
                    Button { store.send(.timerRequested(seconds: suggested.seconds)) } label: {
                        Label {
                            Text(L10n.recipesTimerMinutes(max(suggested.seconds / 60, 1)))
                        } icon: {
                            Image(systemName: "timer")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .tint(theme.accent)
                }
                ForEach([5, 10, 20], id: \.self) { minutes in
                    Button { store.send(.timerRequested(seconds: minutes * 60)) } label: {
                        Text(L10n.recipesTimerMinutes(minutes))
                            .font(.subheadline)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                Spacer(minLength: 0)
            }
            .animation(Motion.spring, value: store.step)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            switch store.phase {
            case .ingredients:
                PrimaryButton(
                    L10n.recipesCookingStartCookingButton,
                    symbol: "play.fill"
                ) { store.send(.startStepsTapped) }
                    .disabled(!store.allIngredientsChecked)
                    .opacity(store.allIngredientsChecked ? 1 : 0.5)

            case .cooking:
                SecondaryButton(L10n.recipesCookingBackButton, symbol: "chevron.left") {
                    store.send(.previousStepTapped)
                }
                .disabled(store.step == 0)
                .opacity(store.step == 0 ? 0.4 : 1)

                PrimaryButton(
                    store.isLastStep
                        ? L10n.recipesCookingFinishButton
                        : L10n.recipesCookingNextStepButton,
                    symbol: store.isLastStep ? "checkmark" : "chevron.right"
                ) { store.send(.nextStepTapped) }
            }
        }
        .animation(Motion.spring, value: store.allIngredientsChecked)
    }
}

struct ComposeRecipeSheet: View {
    @Bindable var store: StoreOf<ComposeRecipeFeature>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $store.title) { Text(L10n.recipesNewRecipeTitleField) }
                    TextField(text: $store.summary, axis: .vertical) {
                        Text(L10n.recipesComposeSummaryLabel)
                    }
                    .lineLimit(2...4)
                }

                Section {
                    Stepper(value: $store.prepTime, in: 0...240, step: 5) {
                        LabeledContent {
                            Text(L10n.recipesCardTimeFormat(store.prepTime))
                        } label: {
                            Text(L10n.recipesNewRecipePrepTimePicker)
                        }
                    }
                    Stepper(value: $store.cookTime, in: 0...480, step: 5) {
                        LabeledContent {
                            Text(L10n.recipesCardTimeFormat(store.cookTime))
                        } label: {
                            Text(L10n.recipesNewRecipeCookTimePicker)
                        }
                    }
                    Stepper(value: $store.servings, in: 1...20) {
                        LabeledContent {
                            // The one number this control exists to change.
                            Text(store.servings, format: .number)
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(store.servings)))
                                .animation(Motion.spring, value: store.servings)
                        } label: {
                            Text(L10n.recipesNewRecipeServingsPicker)
                        }
                    }
                    Picker(selection: $store.difficulty) {
                        ForEach(Recipe.Difficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.title).tag(difficulty)
                        }
                    } label: {
                        Text(L10n.recipesNewRecipeDifficultyPicker)
                    }
                }

                listSection(
                    title: L10n.recipesDetailIngredientsTitle,
                    addTitle: L10n.recipesComposeAddIngredient,
                    values: $store.ingredients,
                    onAdd: { store.send(.addIngredientTapped) },
                    onRemove: { store.send(.removeIngredient($0)) }
                )

                listSection(
                    title: L10n.recipesDetailStepsTitle,
                    addTitle: L10n.recipesComposeAddStep,
                    values: $store.steps,
                    onAdd: { store.send(.addStepTapped) },
                    onRemove: { store.send(.removeStep($0)) }
                )

                Section {
                    // A wrapping row of chips: tags are a small closed set, so a
                    // picker would hide them behind an extra tap.
                    FlowLayout(spacing: 8) {
                        ForEach(RecipeTag.suggestions, id: \.self) { tag in
                            Chip(tag, isSelected: store.tags.contains(tag)) {
                                store.send(.tagToggled(tag))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(L10n.recipesComposeTagsLabel)
                } footer: {
                    Text(L10n.recipesNewRecipeTagsLimitInfo(RecipeTag.maxSelectable))
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
            .navigationTitle(Text(L10n.recipesComposeTitle))
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
    }

    @ViewBuilder
    private func listSection(
        title: LocalizedStringResource,
        addTitle: LocalizedStringResource,
        values: Binding<[String]>,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (Int) -> Void
    ) -> some View {
        Section {
            ForEach(values.indices, id: \.self) { index in
                HStack {
                    TextField(text: values[index], axis: .vertical) {
                        Text(title)
                    }
                    if values.wrappedValue.count > 1 {
                        Button(role: .destructive) { onRemove(index) } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Palette.danger)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button(action: onAdd) {
                Label { Text(addTitle) } icon: { Image(systemName: "plus.circle") }
            }
        } header: {
            Text(title)
        }
    }
}


/// Confirms a batch of ingredients landing on the shopping list, and offers the
/// one thing a person wants next.
private struct AddedToListToast: View {
    let count: Int
    let goToList: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: count > 0 ? "checkmark.circle.fill" : "cart")
                .font(.callout)
                .foregroundStyle(count > 0 ? Palette.success : Color.secondary)
                .symbolEffect(.bounce, options: .nonRepeating, value: count)

            Text(count > 0
                ? L10n.recipesDetailAddedCount(count)
                : L10n.recipesDetailAlreadyOnList)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: goToList) {
                Text(L10n.recipesDetailGoToList)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pressable)
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// A `List` row stripped of the List's own chrome.
///
/// The cards carry their own glass surface and their own spacing, so every
/// default the List would otherwise supply — the row background, the separator,
/// the standard insets — is something to take away rather than to style.

