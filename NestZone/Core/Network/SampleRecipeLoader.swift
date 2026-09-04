import Foundation

/// The starter recipes bundled with the app, shown in Explore before a home has
/// saved any of its own.
///
/// The old loader probed four candidate bundle subdirectories at every call and
/// re-parsed the JSON each time. These ship as module resources now, so there is
/// exactly one path, and the decoded result is cached for the process.
enum SampleRecipeLoader {
    private static let cache = Cache()

    static func load() async -> [Recipe] {
        let language = await MainActor.run { L10n.locale.language.languageCode?.identifier ?? "en" }
        let code = ["en", "tr"].contains(language) ? language : "en"
        if let cached = await cache.recipes(for: code) { return cached }

        guard let url = Bundle.main.url(
            forResource: "sample_recipes_\(code)", withExtension: "json"
        ) else {
            ConvexConnection.log.error("sample recipes missing for \(code, privacy: .public)")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([SampleRecipe].self, from: data)
            let recipes = decoded.map(\.asRecipe)
            await cache.store(recipes, for: code)
            return recipes
        } catch {
            ConvexConnection.log.error(
                "sample recipes failed to decode: \(String(describing: error), privacy: .public)"
            )
            return []
        }
    }

    private actor Cache {
        private var storage: [String: [Recipe]] = [:]
        func recipes(for code: String) -> [Recipe]? { storage[code] }
        func store(_ recipes: [Recipe], for code: String) { storage[code] = recipes }
    }
}

/// Wire shape of the bundled JSON, which predates the Convex schema and so uses
/// plain `id` and camelCase keys.
private struct SampleRecipe: Decodable {
    let id: String
    let title: String
    let description: String?
    let ingredients: [String]?
    let steps: [String]?
    let tags: [String]?
    let prepTime: Int?
    let cookTime: Int?
    let servings: Int?
    let difficulty: String?

    var asRecipe: Recipe {
        Recipe(
            id: RecipeID(id),
            title: title,
            summary: description,
            ingredients: ingredients ?? [],
            steps: steps ?? [],
            tags: tags ?? [],
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings,
            difficulty: difficulty.flatMap(Recipe.Difficulty.init(rawValue:)),
            // Sentinel the Explore screen filters on: these are not stored
            // against any real home.
            homeID: Recipe.exploreHomeID
        )
    }
}

extension Recipe {
    /// Marks a recipe as one of the bundled samples rather than a saved one.
    public static let exploreHomeID = HomeID("explore")

    public var isSample: Bool { homeID == Self.exploreHomeID }
}
