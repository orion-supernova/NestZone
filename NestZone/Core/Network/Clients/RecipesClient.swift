import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct RecipesClient: Sendable {
    public var byHome: @Sendable (HomeID) -> AsyncThrowingStream<[Recipe], any Error> = { _ in .never }
    public var create: @Sendable (NewRecipe) async throws -> Void
    public var remove: @Sendable (RecipeID) async throws -> Void
    /// The starter recipes bundled with the app, in the current language.
    public var samples: @Sendable () async -> [Recipe] = { [] }
}

public struct NewRecipe: Equatable, Sendable {
    public var title: String
    public var summary: String?
    public var ingredients: [String]
    public var steps: [String]
    public var tags: [String]
    public var prepTime: Int?
    public var cookTime: Int?
    public var servings: Int?
    public var difficulty: Recipe.Difficulty?
    public var homeID: HomeID

    public init(
        title: String,
        summary: String? = nil,
        ingredients: [String] = [],
        steps: [String] = [],
        tags: [String] = [],
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        servings: Int? = nil,
        difficulty: Recipe.Difficulty? = nil,
        homeID: HomeID
    ) {
        self.title = title
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
        self.tags = tags
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.difficulty = difficulty
        self.homeID = homeID
    }
}

extension RecipesClient: DependencyKey {
    public static let liveValue = RecipesClient(
        byHome: { homeID in
            ConvexConnection.shared.subscribe(
                to: "recipes:listByHome", args: ["homeId": homeID], as: [Recipe].self
            )
        },
        create: { recipe in
            let trimmed = recipe.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.recipeTitleEmpty",
                    defaultValue: "Give the recipe a title."
                ))
            }
            var args: [String: ConvexEncodable?] = [
                "title": trimmed,
                "homeId": recipe.homeID,
                "ingredients": recipe.ingredients.map { $0 as ConvexEncodable? },
                "steps": recipe.steps.map { $0 as ConvexEncodable? },
                "tags": recipe.tags.map { $0 as ConvexEncodable? },
            ]
            if let summary = recipe.summary, !summary.isEmpty { args["description"] = summary }
            if let prep = recipe.prepTime { args["prep_time"] = prep }
            if let cook = recipe.cookTime { args["cook_time"] = cook }
            if let servings = recipe.servings { args["servings"] = servings }
            if let difficulty = recipe.difficulty { args["difficulty"] = difficulty.rawValue }
            try await ConvexConnection.shared.mutate("recipes:create", args: args)
        },
        remove: { id in
            try await ConvexConnection.shared.mutate("recipes:remove", args: ["id": id])
        },
        samples: { await SampleRecipeLoader.load() }
    )

    public static let testValue = RecipesClient()
}

extension DependencyValues {
    public var recipes: RecipesClient {
        get { self[RecipesClient.self] }
        set { self[RecipesClient.self] = newValue }
    }
}
