import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe
    
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
        return total > 0 ? "\(total)min" : "—"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recipe icon area
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: gradient.map { $0.opacity(0.2) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 90)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient(colors: gradient.map { $0.opacity(0.6) }, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
                    .overlay(
                        HStack {
                            Spacer()
                            VStack {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                Spacer()
                            }
                            .padding(10)
                        }
                    )
            }
            
            // Title
            Text(recipe.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(minHeight: 40, alignment: .top)
            
            // Info badges - better layout with wrapping
            VStack(alignment: .leading, spacing: 6) {
                // First row: Time and servings
                HStack(spacing: 6) {
                    Label(timeText, systemImage: "clock")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(gradient[0].opacity(0.15)))
                        .foregroundStyle(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                    
                    if let servings = recipe.servings {
                        Label("\(servings)", systemImage: "person.2.fill")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(gradient[0].opacity(0.15)))
                            .foregroundStyle(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                    }
                    
                    Spacer()
                }
                
                // Second row: Difficulty
                HStack {
                    if let difficulty = recipe.difficulty {
                        Text(difficulty.rawValue.capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(difficultyColor(difficulty).opacity(0.2)))
                            .foregroundColor(difficultyColor(difficulty))
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(height: 180)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: gradient[0].opacity(0.15), radius: 10, x: 0, y: 6)
        .contentShape(Rectangle())
    }
    
    // Difficulty colors
    private func difficultyColor(_ difficulty: Recipe.Difficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}