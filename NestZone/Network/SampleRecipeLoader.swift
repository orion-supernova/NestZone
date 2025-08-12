
import Foundation

// Model for sample recipes from JSON (different from database Recipe model)
struct SampleRecipe: Codable {
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
}

class SampleRecipeLoader {
    static func loadRecipes(forLanguage language: String) -> [Recipe] {
        // Try multiple potential paths
        let possibleSubdirectories = ["Locales/SampleRecipes", "SampleRecipes", "Resources/SampleRecipes"]
        
        for subdirectory in possibleSubdirectories {
            if let url = Bundle.main.url(forResource: "sample_recipes_" + language, withExtension: "json", subdirectory: subdirectory) {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let sampleRecipes = try decoder.decode([SampleRecipe].self, from: data)
                    return convertToRecipes(sampleRecipes)
                } catch {
                    continue
                }
            }
        }
        
        // Try without subdirectory
        if let url = Bundle.main.url(forResource: "sample_recipes_" + language, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let sampleRecipes = try decoder.decode([SampleRecipe].self, from: data)
                return convertToRecipes(sampleRecipes)
            } catch {
                // Silent fail
            }
        }
        
        return []
    }
    
    private static func convertToRecipes(_ sampleRecipes: [SampleRecipe]) -> [Recipe] {
        let now = ISO8601DateFormatter().string(from: Date())
        
        return sampleRecipes.map { sample in
            let difficulty: Recipe.Difficulty? = {
                guard let diffStr = sample.difficulty else { return nil }
                return Recipe.Difficulty(rawValue: diffStr)
            }()
            
            return Recipe(
                id: sample.id,
                title: sample.title,
                description: sample.description,
                ingredients: sample.ingredients,
                steps: sample.steps,
                tags: sample.tags,
                prepTime: sample.prepTime,
                cookTime: sample.cookTime,
                servings: sample.servings,
                difficulty: difficulty,
                image: nil,
                homeId: "explore", // Mark as explore recipes
                createdBy: nil,
                created: now,
                updated: now
            )
        }
    }
}
