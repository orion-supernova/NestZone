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
        /// Cooking runs in two phases, the way the old app did it: gather
        /// everything first, then work through the steps. You cannot start
        /// cooking until every ingredient is checked off.
        public var phase: Phase = .ingredients
        public var step = 0
        public var isSaving = false
        public var timer = StepTimer()
        @Presents public var alert: AlertState<Action.Alert>?

        public enum Phase: Equatable, Sendable { case ingredients, cooking }

        public init(recipe: Recipe, homeID: HomeID) {
            self.recipe = recipe
            self.homeID = homeID
        }

        /// A bundled sample can be saved into the home; a saved one can't.
        public var canSaveToHome: Bool { recipe.isSample }

        /// There is something to walk through. Independent of whether the
        /// recipe is saved.
        public var canCook: Bool { !recipe.steps.isEmpty }

        /// True once everything is gathered — and vacuously true for a recipe
        /// that lists no ingredients, which would otherwise strand the cook in
        /// phase one with a button that could never enable.
        public var allIngredientsChecked: Bool {
            recipe.ingredients.isEmpty
                || checkedIngredients.count == recipe.ingredients.count
        }

        public var progress: Double {
            switch phase {
            case .ingredients:
                guard !recipe.ingredients.isEmpty else { return 0 }
                return Double(checkedIngredients.count) / Double(recipe.ingredients.count)
            case .cooking:
                guard !recipe.steps.isEmpty else { return 0 }
                return Double(step + 1) / Double(recipe.steps.count)
            }
        }

        public var isLastStep: Bool { step >= recipe.steps.count - 1 }

        public var currentStepText: String {
            recipe.steps.indices.contains(step) ? recipe.steps[step] : ""
        }

        /// A duration mentioned in the current step, if there is one, so the
        /// timer can be offered with the right value already filled in.
        public var suggestedDuration: StepDuration? {
            StepDuration.firstMatch(in: currentStepText)
        }
    }

    /// A countdown attached to the step you are on.
    public struct StepTimer: Equatable, Sendable {
        public var totalSeconds: Int = 0
        public var remainingSeconds: Int = 0
        public var isRunning = false

        public init() {}

        public var isFinished: Bool { isRunning == false && totalSeconds > 0 && remainingSeconds == 0 }

        public var formatted: String {
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }

        public var progress: Double {
            guard totalSeconds > 0 else { return 0 }
            return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
        }
    }

    public enum Action: Equatable {
        case ingredientToggled(Int)
        case beginCookingTapped
        case startStepsTapped
        case quitCookingTapped
        case quitConfirmed
        case stepChanged(Int)
        case nextStepTapped
        case previousStepTapped
        case timerRequested(seconds: Int)
        case timerTicked
        case timerStopped
        case timerFinished
        case saveToHomeTapped
        case saved
        case deleteTapped
        case deleted
        case failed(AppError)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable { case confirmQuit }
    }

    private enum CancelID { case timer }

    @Dependency(\.recipes) var recipes
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.continuousClock) var clock
    @Dependency(\.push) var push

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

            case .beginCookingTapped:
                state.isCooking = true
                state.step = 0
                state.checkedIngredients = []
                // Nothing to gather means nothing to show in phase one.
                state.phase = state.recipe.ingredients.isEmpty ? .cooking : .ingredients
                return .none

            case .startStepsTapped:
                guard state.allIngredientsChecked else { return .none }
                state.phase = .cooking
                state.step = 0
                return .none

            case .quitCookingTapped:
                // Leaving loses the session, so it asks first.
                state.alert = .confirmQuitCooking()
                return .none

            case .alert(.presented(.confirmQuit)), .quitConfirmed:
                state.isCooking = false
                state.phase = .ingredients
                state.timer = StepTimer()
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in await push.cancelTimer() }
                )

            case let .stepChanged(step):
                state.step = max(0, min(step, max(state.recipe.steps.count - 1, 0)))
                // A timer belongs to the step it was started on.
                state.timer = StepTimer()
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in await push.cancelTimer() }
                )

            case .nextStepTapped:
                guard !state.isLastStep else {
                    state.isCooking = false
                    state.phase = .ingredients
                    state.timer = StepTimer()
                    return .merge(
                        .cancel(id: CancelID.timer),
                        .run { _ in await push.cancelTimer() }
                    )
                }
                return .send(.stepChanged(state.step + 1))

            case .previousStepTapped:
                guard state.step > 0 else { return .none }
                return .send(.stepChanged(state.step - 1))

            case let .timerRequested(seconds):
                guard seconds > 0 else { return .none }
                // Asking here rather than at launch: the prompt lands at the
                // moment its purpose is self-evident.
                state.timer = StepTimer()
                state.timer.totalSeconds = seconds
                state.timer.remainingSeconds = seconds
                state.timer.isRunning = true
                return .merge(
                    // The on-screen countdown.
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.timerTicked)
                        }
                    }
                    .cancellable(id: CancelID.timer, cancelInFlight: true),

                    // And a local notification, because the in-app clock stops
                    // mattering the moment the cook switches away — which is
                    // exactly when a timer earns its keep.
                    .run { [step = state.currentStepText] _ in
                        guard await push.requestAuthorization() else { return }
                        await push.scheduleTimer(seconds, step)
                    }
                )

            case .timerTicked:
                guard state.timer.isRunning else { return .none }
                state.timer.remainingSeconds -= 1
                guard state.timer.remainingSeconds <= 0 else { return .none }
                state.timer.remainingSeconds = 0
                state.timer.isRunning = false
                return .concatenate(
                    .cancel(id: CancelID.timer),
                    .send(.timerFinished)
                )

            case .timerStopped:
                state.timer = StepTimer()
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in await push.cancelTimer() }
                )

            case .timerFinished:
                // The notification already fired if we were backgrounded;
                // clear it so a returning cook does not see a stale banner.
                state.alert = .timerFinished()
                return .run { _ in await push.cancelTimer() }

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

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == RecipeDetailFeature.Action.Alert {
    static func confirmQuitCooking() -> Self {
        AlertState {
            TextState(String(localized: L10n.recipesCookingQuitAlertTitle))
        } actions: {
            ButtonState(role: .destructive, action: .confirmQuit) {
                TextState(String(localized: L10n.recipesCookingQuitAlertQuitButton))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.recipesCookingQuitAlertMessage))
        }
    }

    static func timerFinished() -> Self {
        AlertState {
            TextState(String(localized: L10n.recipesTimerDoneTitle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonOkButton))
            }
        } message: {
            TextState(String(localized: L10n.recipesTimerDoneMessage))
        }
    }
}

/// A duration written into a recipe step, e.g. "simmer for 10 minutes".
///
/// Recipes phrase times in prose, so the timer reads the step rather than making
/// the cook translate it into a number while their hands are full.
public struct StepDuration: Equatable, Sendable {
    public let seconds: Int
    public let phrase: String

    // Built per call: `Regex` is not `Sendable`, so it cannot be a shared
    // static. Matching one short step string is cheap and only happens when the
    // step changes.
    private static var pattern: Regex<(Substring, Substring, Substring)> {
        /(\d{1,3})\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)/.ignoresCase()
    }

    public static func firstMatch(in text: String) -> StepDuration? {
        guard let match = text.firstMatch(of: pattern) else { return nil }
        guard let value = Int(match.1) else { return nil }
        let unit = match.2.lowercased()
        let multiplier = if unit.hasPrefix("h") { 3600 }
            else if unit.hasPrefix("m") { 60 }
            else { 1 }
        let seconds = value * multiplier
        guard (1...(6 * 3600)).contains(seconds) else { return nil }
        return StepDuration(seconds: seconds, phrase: String(match.0))
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
