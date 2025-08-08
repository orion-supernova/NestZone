import SwiftUI
import Foundation

@MainActor
class RecipeViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var searchText: String = ""
    @Published var selectedTag: String? = nil
    
    var allTags: [String] {
        Array(Set(recipes.flatMap { $0.tags ?? [] })).sorted()
    }
    
    var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            let matchesSearch: Bool = {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
                let haystack = [
                    recipe.title,
                    recipe.description ?? "",
                    (recipe.tags ?? []).joined(separator: " ")
                ].joined(separator: " ").lowercased()
                return haystack.contains(searchText.lowercased())
            }()
            
            let matchesTag: Bool = {
                guard let tag = selectedTag, !tag.isEmpty else { return true }
                return (recipe.tags ?? []).contains(tag)
            }()
            
            return matchesSearch && matchesTag
        }
    }
    
    private let pocketBase = PocketBaseManager.shared
    private var currentHomeId: String?
    private var authManager: PocketBaseAuthManager?
    
    let allowedTags: [String] = [
        "breakfast", "lunch", "dinner", "dessert",
        "vegan", "vegetarian", "gluten-free", "dairy-free",
        "quick", "kids", "snack", "healthy",
        "low-carb", "high-protein", "pasta", "soup", "salad"
    ]
    
    init() {
        Task {
            await loadRecipes()
        }
    }
    
    func loadRecipes() async {
        isLoading = true
        errorMessage = nil
        do {
            await getCurrentHome()
            try await loadRecipesFromBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func getCurrentHome() async {
        do {
            let response: PocketBaseListResponse<Home> = try await pocketBase.getCollection(
                "homes",
                responseType: PocketBaseListResponse<Home>.self
            )
            currentHomeId = response.items.first?.id
        } catch {
            print("Error getting home: \(error)")
        }
    }
    
    private func loadRecipesFromBackend() async throws {
        guard let homeId = currentHomeId else { return }
        let filter = "home_id = '\(homeId)'"
        let sort = "-created"
        
        let response: PocketBaseListResponse<Recipe> = try await pocketBase.getCollection(
            "recipes",
            responseType: PocketBaseListResponse<Recipe>.self,
            filter: filter,
            sort: sort
        )
        if !response.items.isEmpty {
            recipes = response.items
        }
        // else keep current recipes (e.g., right after create, when rules hide the new item temporarily)
    }
    
    func refresh() async {
        await loadRecipes()
    }
    
    func setAuthManager(_ auth: PocketBaseAuthManager) {
        self.authManager = auth
    }
    
    func addRecipe(
        title: String,
        description: String?,
        tags: [String],
        prepTime: Int?,
        cookTime: Int?,
        servings: Int?,
        difficulty: Recipe.Difficulty?,
        ingredients: [String]?,
        steps: [String]?
    ) async {
        guard let homeId = currentHomeId else { return }
        guard let userId = authManager?.currentUser?.id else {
            errorMessage = "Missing authentication."
            return
        }
        
        do {
            let normalizedTags: [String] = tags
                .map { $0.lowercased() }
                .filter { allowedTags.contains($0) }
            
            var data: [String: Any] = [
                "title": title,
                "home_id": homeId,
                "created_by": userId
            ]
            
            if !normalizedTags.isEmpty { data["tags"] = normalizedTags }
            if let description, !description.isEmpty { data["description"] = description }
            if let prepTime { data["prep_time"] = prepTime }
            if let cookTime { data["cook_time"] = cookTime }
            if let servings { data["servings"] = servings }
            if let difficulty { data["difficulty"] = difficulty.rawValue }
            if let ingredients, !ingredients.isEmpty { data["ingredients"] = ingredients }
            if let steps, !steps.isEmpty { data["steps"] = steps }
            
            let created: Recipe = try await pocketBase.createRecord(
                in: "recipes",
                data: data,
                responseType: Recipe.self
            )
            recipes.insert(created, at: 0)
        } catch {
            errorMessage = "Failed to add recipe: \(error.localizedDescription)"
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) async {
        do {
            try await pocketBase.deleteRecord(from: "recipes", id: recipe.id)
            try await loadRecipesFromBackend()
        } catch {
            errorMessage = "Failed to delete recipe: \(error.localizedDescription)"
        }
    }
}