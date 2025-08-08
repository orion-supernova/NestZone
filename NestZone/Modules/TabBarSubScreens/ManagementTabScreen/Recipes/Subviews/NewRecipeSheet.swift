import SwiftUI

struct NewRecipeSheet: View {
    @EnvironmentObject private var viewModel: RecipeViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var prepTime: String = ""
    @State private var cookTime: String = ""
    @State private var servings: String = ""
    @State private var difficulty: Recipe.Difficulty = .easy
    @State private var ingredientsText: String = ""
    @State private var stepsText: String = ""
    @FocusState private var focusedField: Field?
    
    private let maxTags = 6
    
    enum Field {
        case title, description, prep, cook, servings, ingredients, steps
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    
                    // Title + Description
                    VStack(spacing: 12) {
                        PremiumTextField(
                            title: "Recipe Title",
                            placeholder: "e.g., Spaghetti Carbonara",
                            text: $title,
                            icon: "fork.knife",
                            isRequired: true
                        )
                        .focused($focusedField, equals: .title)
                        
                        PremiumTextField(
                            title: "Description", 
                            placeholder: "Short description (optional)",
                            text: $description,
                            icon: "text.alignleft",
                            isRequired: false
                        )
                        .focused($focusedField, equals: .description)
                    }
                    .padding(.horizontal, 20)
                    
                    // Tags
                    tagsSection
                        .padding(.horizontal, 20)
                    
                    // Numbers + Difficulty
                    numbersSection
                        .padding(.horizontal, 20)
                    
                    // Ingredients
                    editorSection(
                        title: "Ingredients (one per line)",
                        text: $ingredientsText,
                        field: .ingredients
                    )
                    .padding(.horizontal, 20)
                    
                    // Steps
                    editorSection(
                        title: "Steps (one per line)",
                        text: $stepsText,
                        field: .steps
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
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
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { createRecipe() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create Delicious ✨")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                )
            Text("Add a new recipe with tags, timing, ingredients, and steps.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(viewModel.allowedTags, id: \.self) { tag in
                    TagChoicePill(
                        title: displayTitle(tag),
                        isSelected: selectedTags.contains(tag)
                    ) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else if selectedTags.count < maxTags {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
            
            if selectedTags.count >= maxTags {
                Text("You can select up to \(maxTags) tags.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient(colors: [.orange.opacity(0.4), .yellow.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
        )
    }
    
    private var numbersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time & Servings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                SimpleNumberField("Prep (min)", text: $prepTime)
                    .focused($focusedField, equals: .prep)
                SimpleNumberField("Cook (min)", text: $cookTime)
                    .focused($focusedField, equals: .cook)
                SimpleNumberField("Servings", text: $servings)
                    .focused($focusedField, equals: .servings)
            }
            
            Picker("Difficulty", selection: $difficulty) {
                ForEach(Recipe.Difficulty.allCases, id: \.self) { d in
                    Text(d.rawValue.capitalized).tag(d)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient(colors: [.orange.opacity(0.4), .yellow.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
        )
    }
    
    private func editorSection(title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            TextEditor(text: text)
                .focused($focusedField, equals: field)
                .frame(minHeight: field == .ingredients ? 120 : 140)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(LinearGradient(colors: [.orange.opacity(0.35), .yellow.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        )
                )
        }
    }
    
    private func createRecipe() {
        let orderedTags = viewModel.allowedTags.filter { selectedTags.contains($0) }
        let ingredients = ingredientsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let steps = stepsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        Task {
            await viewModel.addRecipe(
                title: title,
                description: description.isEmpty ? nil : description,
                tags: orderedTags,
                prepTime: Int(prepTime),
                cookTime: Int(cookTime),
                servings: Int(servings),
                difficulty: difficulty,
                ingredients: ingredients.isEmpty ? nil : ingredients,
                steps: steps.isEmpty ? nil : steps
            )
            dismiss()
        }
    }
    
    private func displayTitle(_ value: String) -> String {
        value
            .split(separator: " ")
            .map { part in
                part.split(separator: "-").map { $0.capitalized }.joined(separator: "-")
            }
            .joined(separator: " ")
    }
}

// MARK: - Simple inputs for recipe sheet
struct SimpleNumberField: View {
    var placeholder: String
    @Binding var text: String
    
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient(colors: [.orange.opacity(0.35), .yellow.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
            )
    }
}

struct TagChoicePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color(.secondarySystemBackground))
                )
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}