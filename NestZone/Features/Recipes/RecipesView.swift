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

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.stackSpacing) {
                filterBar
                results
            }
            .padding(.bottom, Metrics.scrollBottomInset)
        }
    }

    @ViewBuilder
    private var results: some View {
        if store.isLoading && store.tab == .mine {
            SkeletonList(rows: 4, height: 96)
                .padding(.horizontal, Metrics.screenPadding)
        } else if store.visible.isEmpty {
            emptyState
        } else {
            GlassGroup {
                VStack(spacing: Metrics.stackSpacing) {
                    ForEach(Array(store.visible.enumerated()), id: \.element.id) { index, recipe in
                        RecipeCard(recipe: recipe) { store.send(.recipeTapped(recipe)) }
                            .appear(index)
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
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
    let recipe: Recipe
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
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

    @ViewBuilder
    private var actions: some View {
        if store.canSaveToHome {
            PrimaryButton(
                L10n.recipesExploreAddToMyRecipes,
                symbol: "plus",
                isLoading: store.isSaving
            ) { store.send(.saveToHomeTapped) }
        } else if !store.recipe.steps.isEmpty {
            PrimaryButton(L10n.recipesDetailStartCooking, symbol: "flame.fill") {
                store.send(.startCookingTapped)
            }
        }
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

/// Full-screen, one step at a time — for when your hands are covered in flour.
struct CookingModeView: View {
    @Bindable var store: StoreOf<RecipeDetailFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            ProgressView(
                value: Double(store.step + 1),
                total: Double(max(store.recipe.steps.count, 1))
            )
            .tint(theme.accent)

            Text(L10n.recipesCookingStepsProgress(store.step + 1, store.recipe.steps.count))
                .font(.footnote)
                .foregroundStyle(.secondary)

            TabView(selection: Binding(
                get: { store.step },
                set: { store.send(.stepChanged($0)) }
            )) {
                ForEach(Array(store.recipe.steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 18) {
                        Text(L10n.recipesCookingStepCardTitle(index + 1, store.recipe.steps.count))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                        Text(step)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                        Spacer(minLength: 0)
                    }
                    .padding(Metrics.screenPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .glassCard()
                    .padding(.horizontal, 4)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            SecondaryButton(L10n.commonClose, symbol: "xmark") {
                store.send(.stopCookingTapped)
            }
        }
        .padding(Metrics.screenPadding)
        // Cooking is hands-free by nature; letting the screen sleep mid-step is
        // the single most annoying thing this screen could do.
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
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
                            Text(store.servings, format: .number)
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
