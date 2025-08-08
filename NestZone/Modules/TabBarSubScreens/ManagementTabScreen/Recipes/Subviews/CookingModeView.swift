import SwiftUI

struct CookingModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPhase: CookingPhase = .ingredients
    @State private var currentIndex: Int = 0
    @State private var checkedIngredients: Set<Int> = []
    @State private var completedSteps: Set<Int> = []
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
    
    var canProceed: Bool {
        switch currentPhase {
        case .ingredients:
            return checkedIngredients.count == ingredients.count
        case .cooking:
            return currentIndex == steps.count - 1 && completedSteps.contains(currentIndex)
        }
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
        .alert("Quit Cooking", isPresented: $showingQuitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Are you sure you want to quit cooking? Your progress will be lost.")
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
                    Text(currentPhase == .ingredients ? "Prepare Ingredients" : "Cook Recipe")
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
                Text("Progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if currentPhase == .ingredients {
                    Text("\(checkedIngredients.count)/\(ingredients.count) ingredients")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                } else {
                    Text("Step \(currentIndex + 1)/\(steps.count)")
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
            Text("Check off each ingredient as you gather it")
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
                    gradient: gradient,
                    isCompleted: completedSteps.contains(currentIndex)
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        _ = completedSteps.insert(currentIndex)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var bottomControls: some View {
        HStack(spacing: 16) {
            // Back button
            if (currentPhase == .ingredients && !checkedIngredients.isEmpty) || 
               (currentPhase == .cooking && currentIndex > 0) {
                Button {
                    withAnimation(.spring()) {
                        if currentPhase == .cooking && currentIndex > 0 {
                            currentIndex -= 1
                            completedSteps.remove(currentIndex)
                        } else if currentPhase == .ingredients {
                            // Reset some ingredients
                            if let lastChecked = checkedIngredients.max() {
                                checkedIngredients.remove(lastChecked)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
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
            }
            
            Spacer()
            
            // Next/Start Cooking/Finish button
            Button {
                withAnimation(.spring()) {
                    if currentPhase == .ingredients && canProceed {
                        currentPhase = .cooking
                        currentIndex = 0
                    } else if currentPhase == .cooking {
                        if currentIndex < steps.count - 1 {
                            currentIndex += 1
                        } else if canProceed {
                            // Recipe completed
                            dismiss()
                        }
                    }
                }
            } label: {
                HStack {
                    Text(nextButtonText)
                    Image(systemName: nextButtonIcon)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            canProceedToNext ? 
                            LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                        )
                )
                .shadow(color: canProceedToNext ? gradient[0].opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!canProceedToNext)
        }
    }
    
    private var nextButtonText: String {
        if currentPhase == .ingredients {
            return canProceed ? "Start Cooking" : "Gather Ingredients"
        } else {
            if currentIndex == steps.count - 1 {
                return canProceed ? "Finish" : "Complete Step"
            } else {
                return "Next Step"
            }
        }
    }
    
    private var nextButtonIcon: String {
        if currentPhase == .ingredients {
            return "flame.fill"
        } else {
            return currentIndex == steps.count - 1 ? "checkmark" : "chevron.right"
        }
    }
    
    private var canProceedToNext: Bool {
        if currentPhase == .ingredients {
            return true // Can always try to gather ingredients
        } else {
            return completedSteps.contains(currentIndex) || currentIndex < steps.count - 1
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
    let isCompleted: Bool
    let onComplete: () -> Void
    
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
                        
                        Text(isCompleted ? "Completed" : "In Progress")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(
                                    isCompleted ? 
                                    LinearGradient(colors: [.green], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                                )
                            )
                            .foregroundColor(.white)
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
            
            if !isCompleted {
                Button {
                    onComplete()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Mark as Complete")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                    )
                    .shadow(color: gradient[0].opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }
        }
    }
}