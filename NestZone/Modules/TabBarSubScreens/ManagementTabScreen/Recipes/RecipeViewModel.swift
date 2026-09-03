import SwiftUI
import Foundation
import ConvexMobile

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
    
    private var authManager: ConvexAuthManager?
    private var homeChangeObserver: NSObjectProtocol?
    
    let allowedTags: [String] = [
        "breakfast", "lunch", "dinner", "dessert",
        "vegan", "vegetarian", "gluten-free", "dairy-free",
        "quick", "kids", "snack", "healthy",
        "low-carb", "high-protein", "pasta", "soup", "salad"
    ]
    
    init() {
        setupHomeChangeObserver()
        Task {
            await loadRecipes()
        }
    }
    
    deinit {
        if let observer = homeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupHomeChangeObserver() {
        homeChangeObserver = NotificationCenter.default.addObserver(
            forName: .homeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadRecipes()
            }
        }
    }
    
    func loadRecipes() async {
        isLoading = true
        errorMessage = nil
        do {
            try await loadRecipesFromBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func loadRecipesFromBackend() async throws {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            recipes = []
            return
        }
        
        let items: [Recipe] = try await Convex.once(
            "recipes:listByHome", args: ["homeId": homeId], as: [Recipe].self
        )
        recipes = items.sorted { ($0.created ?? 0) > ($1.created ?? 0) }
    }
    
    func refresh() async {
        await loadRecipes()
    }
    
    func setAuthManager(_ auth: ConvexAuthManager) {
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
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            errorMessage = "No home selected"
            return
        }
        
        // Auth is implicit in the Convex client; created_by is set server-side.
        do {
            let normalizedTags: [String] = tags
                .map { $0.lowercased() }
                .filter { allowedTags.contains($0) }

            var data: [String: ConvexEncodable?] = [
                "homeId": homeId,
                "title": title,
            ]
            if !normalizedTags.isEmpty { data["tags"] = normalizedTags.map { $0 as ConvexEncodable? } }
            if let description, !description.isEmpty { data["description"] = description }
            if let prepTime { data["prep_time"] = Double(prepTime) }
            if let cookTime { data["cook_time"] = Double(cookTime) }
            if let servings { data["servings"] = Double(servings) }
            if let difficulty { data["difficulty"] = difficulty.rawValue }
            if let ingredients, !ingredients.isEmpty { data["ingredients"] = ingredients.map { $0 as ConvexEncodable? } }
            if let steps, !steps.isEmpty { data["steps"] = steps.map { $0 as ConvexEncodable? } }

            let created: Recipe = try await Convex.client.mutation("recipes:create", with: data)
            recipes.insert(created, at: 0)
        } catch {
            errorMessage = LocalizationManager.recipeErrorAddRecipe(error.localizedDescription)
        }
    }

    func deleteRecipe(_ recipe: Recipe) async {
        do {
            try await Convex.client.mutation("recipes:remove", with: ["id": recipe.id])
            try await loadRecipesFromBackend()
        } catch {
            errorMessage = LocalizationManager.recipeErrorDeleteRecipe(error.localizedDescription)
        }
    }
}