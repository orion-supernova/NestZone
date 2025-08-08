import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: RecipeViewModel
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var showingCookingMode = false
    
    var gradient: [Color] {
        if let tags = recipe.tags, tags.contains(where: { $0.lowercased().contains("dessert") }) {
            return [.pink, .orange]
        } else if let tags = recipe.tags, tags.contains(where: { $0.lowercased().contains("breakfast") }) {
            return [.yellow, .orange]
        } else if let tags = recipe.tags, tags.contains(where: { $0.lowercased().contains("dinner") }) {
            return [.red, .orange]
        } else {
            return [.orange, .yellow]
        }
    }
    
    var timeText: String {
        let prep = recipe.prepTime ?? 0
        let cook = recipe.cookTime ?? 0
        let total = prep + cook
        return total > 0 ? "\(total) min total" : "No time specified"
    }
    
    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with recipe card preview
                    recipeHeader
                    
                    // Recipe info cards
                    infoSection
                    
                    // Ingredients section
                    if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                        ingredientsSection(ingredients)
                    }
                    
                    // Steps section
                    if let steps = recipe.steps, !steps.isEmpty {
                        stepsSection(steps)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120) // Space for floating button
            }
            .background(
                RadialGradient(
                    colors: [
                        gradient[0].opacity(0.06),
                        gradient[1].opacity(0.04),
                        Color(.systemBackground)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
            )
            
            VStack {
                Spacer()
                
                Button {
                    showingCookingMode = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Start Preparing")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: gradient[0].opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only show delete for user's own recipes (not explore recipes)
            if recipe.homeId != "explore" {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCookingMode) {
            CookingModeView(recipe: recipe)
        }
        .alert("Delete Recipe", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteRecipe(recipe)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(recipe.title)'? This action cannot be undone.")
        }
    }
    
    private var recipeHeader: some View {
        VStack(spacing: 16) {
            // Recipe card (smaller version of the grid card)
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: gradient.map { $0.opacity(0.2) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(LinearGradient(colors: gradient.map { $0.opacity(0.6) }, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        )
                        .overlay(
                            HStack {
                                Spacer()
                                VStack {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    Spacer()
                                }
                                .padding(16)
                            }
                        )
                        .rotationEffect(.degrees(-1.5))
                }
                
                Text(recipe.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                if let description = recipe.description {
                    Text(description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private var infoSection: some View {
        HStack(spacing: 12) {
            if let prep = recipe.prepTime, prep > 0 {
                InfoCard(title: "Prep", value: "\(prep) min", icon: "timer", gradient: gradient)
            }
            if let cook = recipe.cookTime, cook > 0 {
                InfoCard(title: "Cook", value: "\(cook) min", icon: "flame.fill", gradient: gradient)
            }
            if let servings = recipe.servings {
                InfoCard(title: "Serves", value: "\(servings)", icon: "person.2.fill", gradient: gradient)
            }
            if let difficulty = recipe.difficulty {
                InfoCard(title: "Level", value: difficulty.rawValue.capitalized, icon: "star.fill", gradient: gradient)
            }
        }
    }
    
    private func ingredientsSection(_ ingredients: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("Ingredients")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(spacing: 12) {
                        Text("\(index + 1).")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                            .frame(width: 20)
                        
                        Text(ingredient)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
        }
    }
    
    private func stepsSection(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.number")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("Instructions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                            
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text(step)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}