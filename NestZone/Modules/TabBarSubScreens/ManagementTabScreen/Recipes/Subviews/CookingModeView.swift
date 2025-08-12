import SwiftUI

struct CookingModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPhase: CookingPhase = .ingredients
    @State private var currentIndex: Int = 0
    @State private var checkedIngredients: Set<Int> = []
    @State private var showingQuitAlert = false
    
    enum CookingPhase {
        case ingredients, cooking
    }
    
    var ingredients: [String] {
        recipe.ingredients ?? []
    }
    
    var steps: [String] {
        recipe.steps ?? []
    }
    
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
    
    var body: some View {
        ZStack {
            // Background
            RadialGradient(
                colors: [
                    gradient[0].opacity(0.08),
                    gradient[1].opacity(0.04),
                    Color(.systemBackground)
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 1200
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                cookingHeader
                
                // Progress indicator
                progressIndicator
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                
                // Main content
                Spacer()
                
                if currentPhase == .ingredients {
                    ingredientsPhase
                } else {
                    cookingPhase
                }
                
                Spacer()
                
                // Bottom controls
                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .alert(LocalizationManager.recipesCookingQuitAlertTitle, isPresented: $showingQuitAlert) {
            Button(LocalizationManager.commonCancel, role: .cancel) { }
            Button(LocalizationManager.recipesCookingQuitAlertQuitButton, role: .destructive) {
                dismiss()
            }
        } message: {
            Text(LocalizationManager.recipesCookingQuitAlertMessage)
        }
    }
    
    private var cookingHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    showingQuitAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(currentPhase == .ingredients ? LocalizationManager.recipesCookingPrepareIngredients : LocalizationManager.recipesCookingCookRecipe)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(recipe.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Timer button (placeholder)
                Button {
                    // Timer functionality
                } label: {
                    Image(systemName: "timer")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text(LocalizationManager.recipesCookingProgressLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if currentPhase == .ingredients {
                    Text(LocalizationManager.recipesCookingIngredientsProgress(checkedIngredients.count, ingredients.count))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                } else {
                    Text(LocalizationManager.recipesCookingStepsProgress(currentIndex + 1, max(steps.count, 1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                }
            }
            
            ProgressView(value: currentPhase == .ingredients ?
                         Double(checkedIngredients.count) / Double(max(ingredients.count, 1)) :
                         Double(currentIndex + 1) / Double(max(steps.count, 1)))
            .progressViewStyle(LinearProgressViewStyle(tint: gradient[0]))
            .frame(height: 6)
        }
    }
    
    private var ingredientsPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationManager.recipesCookingCheckIngredientsInstruction)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                        IngredientCheckItem(
                            ingredient: ingredient,
                            isChecked: checkedIngredients.contains(index),
                            gradient: gradient
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if checkedIngredients.contains(index) {
                                    checkedIngredients.remove(index)
                                } else {
                                    _ = checkedIngredients.insert(index)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var cookingPhase: some View {
        VStack(spacing: 20) {
            if currentIndex < steps.count {
                CookingStepCard(
                    step: steps[currentIndex],
                    stepNumber: currentIndex + 1,
                    totalSteps: steps.count,
                    gradient: gradient
                )
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var bottomControls: some View {
        HStack(spacing: 16) {
            // INGREDIENTS PHASE: show nothing until all checked; then show Start Cooking
            if currentPhase == .ingredients {
                Spacer()
                if ingredients.count > 0 && checkedIngredients.count == ingredients.count {
                    Button {
                        withAnimation(.spring()) {
                            currentPhase = .cooking
                            currentIndex = 0
                        }
                    } label: {
                        HStack {
                            Text(LocalizationManager.recipesCookingStartCookingButton)
                            Image(systemName: "play.fill")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                        )
                        .shadow(color: gradient[0].opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
                Spacer()
            } else {
                // COOKING PHASE: Back and Next/Finish
                Button {
                    withAnimation(.spring()) {
                        if currentIndex > 0 {
                            currentIndex -= 1
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(LocalizationManager.recipesCookingBackButton)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule().stroke(gradient[0].opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .disabled(currentIndex == 0)
                
                Spacer()
                
                Button {
                    withAnimation(.spring()) {
                        if currentIndex < max(steps.count - 1, 0) {
                            currentIndex += 1
                        } else {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Text(currentIndex == max(steps.count - 1, 0) ? LocalizationManager.recipesCookingFinishButton : LocalizationManager.recipesCookingNextStepButton)
                        Image(systemName: currentIndex == max(steps.count - 1, 0) ? "checkmark" : "chevron.right")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        Capsule().fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                    )
                    .shadow(color: gradient[0].opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .disabled(steps.isEmpty)
            }
        }
    }
}

// MARK: - Ingredient Check Item
struct IngredientCheckItem: View {
    let ingredient: String
    let isChecked: Bool
    let gradient: [Color]
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isChecked ? 
                              LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .stroke(
                            isChecked ? 
                            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)
                    
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(ingredient)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .strikethrough(isChecked)
                    .opacity(isChecked ? 0.7 : 1.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isChecked ? gradient[0].opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cooking Step Card
struct CookingStepCard: View {
    let step: String
    let stepNumber: Int
    let totalSteps: Int
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        
                        Text("\(stepNumber)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Step \(stepNumber) of \(totalSteps)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Text(step)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LinearGradient(colors: gradient.map { $0.opacity(0.4) }, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    )
            )
        }
    }
}