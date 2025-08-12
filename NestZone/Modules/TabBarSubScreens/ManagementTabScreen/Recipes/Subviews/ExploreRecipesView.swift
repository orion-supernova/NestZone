import SwiftUI

struct ExploreRecipesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: RecipeViewModel
    @State private var allSampleRecipes: [Recipe] = []
    
    // Filter states
    @State private var selectedDifficulty: Recipe.Difficulty? = nil
    @State private var selectedTag: String? = nil
    @State private var maxTime: Double = 300 // 5 hours max
    @State private var maxServings: Double = 20
    @State private var showingFilters = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // Computed property for real-time filtering
    private var filteredRecipes: [Recipe] {
        allSampleRecipes.filter { recipe in
            // Difficulty filter
            if let difficulty = selectedDifficulty, recipe.difficulty != difficulty {
                return false
            }
            
            // Tag filter
            if let tag = selectedTag {
                guard let recipeTags = recipe.tags else { return false }
                if !recipeTags.contains(tag) { return false }
            }
            
            // Time filter (total time = prep + cook)
            let totalTime = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0)
            if Double(totalTime) > maxTime {
                return false
            }
            
            // Servings filter
            if let servings = recipe.servings, Double(servings) > maxServings {
                return false
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    
                    // Filter toggle and active filters
                    filterSection
                        .padding(.horizontal, 20)
                    
                    // Results - using computed property for real-time updates
                    if filteredRecipes.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink(destination: RecipeDetailView(recipe: recipe).environmentObject(viewModel)) {
                                    RecipeCard(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        Task {
                                            await viewModel.addRecipe(
                                                title: recipe.title,
                                                description: recipe.description,
                                                tags: recipe.tags ?? [],
                                                prepTime: recipe.prepTime,
                                                cookTime: recipe.cookTime,
                                                servings: recipe.servings,
                                                difficulty: recipe.difficulty,
                                                ingredients: recipe.ingredients,
                                                steps: recipe.steps
                                            )
                                        }
                                    } label: {
                                        Label(LocalizationManager.recipesExploreAddToMyRecipes, systemImage: "plus")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(
                RadialGradient(
                    colors: [
                        Color.orange.opacity(0.06),
                        Color.yellow.opacity(0.04),
                        Color(.systemBackground)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
            )
            .navigationTitle(LocalizationManager.recipesExploreScreenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizationManager.recipesExploreCloseButton) { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FilterSheet(
                selectedDifficulty: $selectedDifficulty,
                selectedTag: $selectedTag,
                maxTime: $maxTime,
                maxServings: $maxServings,
                allTags: availableTags,
                allRecipes: allSampleRecipes
            )
        }
        .onAppear {
            loadSampleRecipes()
        }
    }
}

// MARK: - ExploreRecipesView Extensions
extension ExploreRecipesView {
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizationManager.recipesExploreHeaderTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                Text(LocalizationManager.recipesExploreHeaderSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
            }
            Spacer()
        }
    }
    
    private var availableTags: [String] {
        Array(Set(allSampleRecipes.flatMap { $0.tags ?? [] })).sorted()
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if selectedDifficulty != nil { count += 1 }
        if selectedTag != nil { count += 1 }
        if maxTime < 300 { count += 1 }
        if maxServings < 20 { count += 1 }
        return count
    }
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    showingFilters = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16, weight: .medium))
                        Text(LocalizationManager.recipesExploreFiltersTitle)
                            .font(.system(size: 14, weight: .medium))
                        if activeFilterCount > 0 {
                            Text("(\(activeFilterCount))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .stroke(activeFilterCount > 0 ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if activeFilterCount > 0 {
                    Button(LocalizationManager.recipesExploreFiltersClearAll) {
                        clearAllFilters()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                }
            }
            
            // Active filters display
            if activeFilterCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let difficulty = selectedDifficulty {
                            FilterChip(title: difficulty.localizedString) {
                                selectedDifficulty = nil
                            }
                        }
                        if let tag = selectedTag {
                            FilterChip(title: tag.capitalized) {
                                selectedTag = nil
                            }
                        }
                        if maxTime < 300 {
                            FilterChip(title: "≤ \(Int(maxTime)) min") {
                                maxTime = 300
                            }
                        }
                        if maxServings < 20 {
                            FilterChip(title: "≤ \(Int(maxServings)) servings") {
                                maxServings = 20
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(LocalizationManager.recipesExploreFiltersNoRecipesFound)
                .font(.system(size: 18, weight: .semibold))
            Text(LocalizationManager.recipesExploreFiltersAdjustMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if activeFilterCount > 0 {
                Button(LocalizationManager.recipesExploreFiltersClearButton) {
                    clearAllFilters()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
    
    private func loadSampleRecipes() {
        let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
        
        var loadedRecipes = SampleRecipeLoader.loadRecipes(forLanguage: currentLanguage)
        
        // Fallback to English if current language fails
        if loadedRecipes.isEmpty {
            loadedRecipes = SampleRecipeLoader.loadRecipes(forLanguage: "en")
        }
        
        // SampleRecipeLoader already returns Recipe objects with proper homeId
        allSampleRecipes = loadedRecipes
    }
    
    private func clearAllFilters() {
        selectedDifficulty = nil
        selectedTag = nil
        maxTime = 300
        maxServings = 20
    }
}

// MARK: - Filter Components
struct FilterChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        )
        .foregroundColor(.white)
        .clipShape(Capsule())
    }
}

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDifficulty: Recipe.Difficulty?
    @Binding var selectedTag: String?
    @Binding var maxTime: Double
    @Binding var maxServings: Double
    let allTags: [String]
    
    // Add allRecipes parameter to calculate live count
    let allRecipes: [Recipe]
    
    // Computed property to show live filtered count
    private var filteredCount: Int {
        allRecipes.filter { recipe in
            // Difficulty filter
            if let difficulty = selectedDifficulty, recipe.difficulty != difficulty {
                return false
            }
            
            // Tag filter
            if let tag = selectedTag {
                guard let recipeTags = recipe.tags else { return false }
                if !recipeTags.contains(tag) { return false }
            }
            
            // Time filter (total time = prep + cook)
            let totalTime = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0)
            if Double(totalTime) > maxTime {
                return false
            }
            
            // Servings filter
            if let servings = recipe.servings, Double(servings) > maxServings {
                return false
            }
            
            return true
        }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Live results counter at the top
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("\(filteredCount)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                            )
                        Text(filteredCount == 1 ? LocalizationManager.recipesExploreFilterRecipeFoundSingular : LocalizationManager.recipesExploreFilterRecipeFoundPlural)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Difficulty Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizationManager.recipesExploreFilterDifficultyTitle)
                                .font(.system(size: 18, weight: .semibold))
                            
                            HStack(spacing: 12) {
                                ForEach(Recipe.Difficulty.allCases, id: \.self) { difficulty in
                                    DifficultyPill(
                                        difficulty: difficulty,
                                        isSelected: selectedDifficulty == difficulty
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                        
                        // Tag Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizationManager.recipesExploreFilterCategoryTitle)
                                .font(.system(size: 18, weight: .semibold))
                            
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(allTags, id: \.self) { tag in
                                    TagFilterPill(
                                        tag: tag,
                                        isSelected: selectedTag == tag
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTag = selectedTag == tag ? nil : tag
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Time Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(LocalizationManager.recipesExploreFilterTimeTitle)
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Text(maxTime >= 300 ? LocalizationManager.recipesExploreFilterTimeAny : "≤ \(Int(maxTime)) min")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            
                            Slider(value: $maxTime, in: 10...300, step: 5) {
                                Text(LocalizationManager.recipesExploreFilterMaxTimeLabel)
                            } minimumValueLabel: {
                                Text(LocalizationManager.recipesExploreFilterMaxTimeMinLabel)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } maximumValueLabel: {
                                Text(LocalizationManager.recipesExploreFilterMaxTimeMaxLabel)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .accentColor(.orange)
                        }
                        
                        // Servings Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(LocalizationManager.recipesExploreFilterServingsTitle)
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Text(maxServings >= 20 ? LocalizationManager.recipesExploreFilterServingsAny : "≤ \(Int(maxServings))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            
                            Slider(value: $maxServings, in: 1...20, step: 1) {
                                Text(LocalizationManager.recipesExploreFilterMaxServingsLabel)
                            } minimumValueLabel: {
                                Text(LocalizationManager.recipesExploreFilterMaxServingsMinLabel)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } maximumValueLabel: {
                                Text(LocalizationManager.recipesExploreFilterMaxServingsMaxLabel)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .accentColor(.orange)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(LocalizationManager.recipesExploreFilterSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizationManager.recipesExploreFilterSheetReset) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedDifficulty = nil
                            selectedTag = nil
                            maxTime = 300
                            maxServings = 20
                        }
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizationManager.recipesExploreFilterSheetDone) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                }
            }
        }
    }
}

struct DifficultyPill: View {
    let difficulty: Recipe.Difficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: difficultyIcon)
                    .font(.system(size: 12, weight: .medium))
                Text(difficulty.localizedString)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? 
                          AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)) :
                          AnyShapeStyle(.ultraThinMaterial)
                    )
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    private var difficultyIcon: String {
        switch difficulty {
        case .easy: return "1.circle.fill"
        case .medium: return "2.circle.fill"
        case .hard: return "3.circle.fill"
        }
    }
}

struct TagFilterPill: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag.capitalized)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? 
                              AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)) :
                              AnyShapeStyle(.ultraThinMaterial)
                        )
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recipe.Difficulty Extension
extension Recipe.Difficulty {
    var localizedString: String {
        switch self {
        case .easy:
            return LocalizationManager.recipesDifficultyEasy
        case .medium:
            return LocalizationManager.recipesDifficultyMedium
        case .hard:
            return LocalizationManager.recipesDifficultyHard
        }
    }
}