import ComposableArchitecture
import Foundation
import SwiftUI

/// The household's saved recipes, plus the bundled Explore collection.
@Reducer
public struct RecipesFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var saved: IdentifiedArrayOf<Recipe> = []
        public var samples: IdentifiedArrayOf<Recipe> = []
        public var isLoading = true
        public var tab: Tab = .mine
        public var searchText = ""
        public var difficultyFilter: Recipe.Difficulty?
        public var maxMinutes: Int?

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID) { self.homeID = homeID }

        public enum Tab: String, CaseIterable, Hashable, Sendable {
            case mine, explore
        }

        public var visible: [Recipe] {
            let source = tab == .mine
                ? saved.sorted { Timestamp.newestFirst($0.created, $1.created) }
                : Array(samples)
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return source.filter { recipe in
                if let difficultyFilter, recipe.difficulty != difficultyFilter { return false }
                if let maxMinutes, let total = recipe.totalMinutes, total > maxMinutes { return false }
                guard !query.isEmpty else { return true }
                return recipe.title.localizedCaseInsensitiveContains(query)
                    || recipe.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }

        public var hasActiveFilters: Bool {
            difficultyFilter != nil || maxMinutes != nil
        }
    }

    @Reducer
    public enum Destination {
        case detail(RecipeDetailFeature)
        case compose(ComposeRecipeFeature)
    }

    public enum Action: BindableAction {
        case task
        case savedUpdated([Recipe])
        case samplesLoaded([Recipe])
        case loadFailed(AppError)
        case recipeTapped(Recipe)
        case composeTapped
        case clearFiltersTapped
        case deleteTapped(RecipeID)
        case writeFailed(AppError)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case confirmDelete(RecipeID)
        }
    }

    private enum CancelID { case saved }

    @Dependency(\.recipes) var recipesClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { [homeID = state.homeID] send in
                        for try await recipes in recipesClient.byHome(homeID) {
                            await send(.savedUpdated(recipes))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.saved, cancelInFlight: true),

                    .run { send in
                        await send(.samplesLoaded(recipesClient.samples()))
                    }
                )

            case let .savedUpdated(recipes):
                state.isLoading = false
                state.saved = IdentifiedArray(uniqueElements: recipes)
                return .none

            case let .samplesLoaded(recipes):
                state.samples = IdentifiedArray(uniqueElements: recipes)
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .recipeTapped(recipe):
                state.destination = .detail(
                    RecipeDetailFeature.State(recipe: recipe, homeID: state.homeID)
                )
                return .none

            case .composeTapped:
                state.destination = .compose(
                    ComposeRecipeFeature.State(homeID: state.homeID)
                )
                return .none

            case .clearFiltersTapped:
                state.difficultyFilter = nil
                state.maxMinutes = nil
                return .none

            case let .deleteTapped(id):
                state.alert = .confirmDeleteRecipe(
                    id, title: state.saved[id: id]?.title ?? ""
                )
                return .none

            case let .alert(.presented(.confirmDelete(id))):
                return .run { send in
                    try await recipesClient.remove(id)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .destination(.presented(.compose(.finished))),
                 .destination(.presented(.detail(.deleted))):
                state.destination = nil
                return .none

            case .binding, .destination, .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == RecipesFeature.Action.Alert {
    static func confirmDeleteRecipe(_ id: RecipeID, title: String) -> Self {
        AlertState {
            TextState(String(localized: L10n.commonDelete))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete(id)) {
                TextState(String(localized: L10n.commonDelete))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.recipesDetailDeleteAlertMessage(title)))
        }
    }
}

/// One recipe, with a step-by-step cooking mode.
@Reducer
public struct RecipeDetailFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var recipe: Recipe
        public var homeID: HomeID
        public var checkedIngredients: Set<Int> = []
        public var isCooking = false
        public var step = 0
        public var isSaving = false

        public init(recipe: Recipe, homeID: HomeID) {
            self.recipe = recipe
            self.homeID = homeID
        }

        /// A bundled sample can be saved into the home; a saved one can't.
        public var canSaveToHome: Bool { recipe.isSample }
    }

    public enum Action: Equatable {
        case ingredientToggled(Int)
        case startCookingTapped
        case stopCookingTapped
        case stepChanged(Int)
        case saveToHomeTapped
        case saved
        case deleteTapped
        case deleted
        case failed(AppError)
    }

    @Dependency(\.recipes) var recipes
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .ingredientToggled(index):
                if state.checkedIngredients.contains(index) {
                    state.checkedIngredients.remove(index)
                } else {
                    state.checkedIngredients.insert(index)
                }
                return .none

            case .startCookingTapped:
                state.isCooking = true
                state.step = 0
                return .none

            case .stopCookingTapped:
                state.isCooking = false
                return .none

            case let .stepChanged(step):
                state.step = max(0, min(step, state.recipe.steps.count - 1))
                return .none

            case .saveToHomeTapped:
                guard state.canSaveToHome, !state.isSaving else { return .none }
                state.isSaving = true
                let new = NewRecipe(
                    title: state.recipe.title,
                    summary: state.recipe.summary,
                    ingredients: state.recipe.ingredients,
                    steps: state.recipe.steps,
                    tags: state.recipe.tags,
                    prepTime: state.recipe.prepTime,
                    cookTime: state.recipe.cookTime,
                    servings: state.recipe.servings,
                    difficulty: state.recipe.difficulty,
                    homeID: state.homeID
                )
                return .run { send in
                    try await recipes.create(new)
                    await send(.saved)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .saved:
                state.isSaving = false
                return .run { _ in await dismiss() }

            case .deleteTapped:
                let id = state.recipe.id
                return .run { send in
                    try await recipes.remove(id)
                    await send(.deleted)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .deleted, .failed:
                state.isSaving = false
                return .none
            }
        }
    }
}

/// Writing a new recipe.
@Reducer
public struct ComposeRecipeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var title = ""
        public var summary = ""
        public var ingredients: [String] = [""]
        public var steps: [String] = [""]
        public var tags: [String] = []
        public var prepTime = 15
        public var cookTime = 30
        public var servings = 2
        public var difficulty: Recipe.Difficulty = .easy
        public var isSubmitting = false
        public var inlineError: String?

        public init(homeID: HomeID) { self.homeID = homeID }

        public var canSubmit: Bool {
            !isSubmitting && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// Blank rows are scaffolding for typing, not content.
        var cleanedIngredients: [String] {
            ingredients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        var cleanedSteps: [String] {
            steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    public enum Action: Equatable, BindableAction {
        case addIngredientTapped
        case removeIngredient(Int)
        case addStepTapped
        case removeStep(Int)
        case tagToggled(String)
        case submitTapped
        case failed(AppError)
        case finished
        case binding(BindingAction<State>)
    }

    @Dependency(\.recipes) var recipes

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .addIngredientTapped:
                state.ingredients.append("")
                return .none

            case let .removeIngredient(index):
                guard state.ingredients.indices.contains(index) else { return .none }
                state.ingredients.remove(at: index)
                if state.ingredients.isEmpty { state.ingredients = [""] }
                return .none

            case .addStepTapped:
                state.steps.append("")
                return .none

            case let .removeStep(index):
                guard state.steps.indices.contains(index) else { return .none }
                state.steps.remove(at: index)
                if state.steps.isEmpty { state.steps = [""] }
                return .none

            case let .tagToggled(tag):
                if let index = state.tags.firstIndex(of: tag) {
                    state.tags.remove(at: index)
                } else if state.tags.count < RecipeTag.maxSelectable {
                    state.tags.append(tag)
                }
                return .none

            case .submitTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                let new = NewRecipe(
                    title: state.title,
                    summary: state.summary.isEmpty ? nil : state.summary,
                    ingredients: state.cleanedIngredients,
                    steps: state.cleanedSteps,
                    tags: state.tags,
                    prepTime: state.prepTime,
                    cookTime: state.cookTime,
                    servings: state.servings,
                    difficulty: state.difficulty,
                    homeID: state.homeID
                )
                return .run { send in
                    try await recipes.create(new)
                    await send(.finished)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .failed(error):
                state.isSubmitting = false
                state.inlineError = error.errorDescription
                return .none

            case .finished, .binding:
                return .none
            }
        }
    }
}

public enum RecipeTag {
    public static let maxSelectable = 5
    public static let suggestions = [
        "breakfast", "lunch", "dinner", "dessert", "snack",
        "vegetarian", "vegan", "quick", "healthy", "comfort",
    ]
}

extension Recipe.Difficulty {
    public var title: LocalizedStringResource {
        switch self {
        case .easy: L10n.recipesDifficultyEasy
        case .medium: L10n.recipesDifficultyMedium
        case .hard: L10n.recipesDifficultyHard
        }
    }

    public var tint: Color {
        switch self {
        case .easy: Palette.success
        case .medium: Palette.warning
        case .hard: Palette.danger
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension RecipesFeature.Destination.State: Equatable {}
