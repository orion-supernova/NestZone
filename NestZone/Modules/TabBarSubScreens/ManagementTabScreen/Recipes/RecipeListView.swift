import SwiftUI

struct RecipeListView: View {
    @StateObject private var viewModel = RecipeViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingNewRecipe = false
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @State private var showingExplore = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    
                    Button {
                        showingExplore = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                            Text(LocalizationManager.recipesExploreButton)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .orange.opacity(0.25), radius: 10, x: 0, y: 6)
                    }
                    .padding(.horizontal, 20)
                    
                    searchAndTags
                        .padding(.horizontal, 20)
                    
                    if viewModel.isLoading {
                        shimmerGrid
                            .padding(.horizontal, 20)
                    } else if viewModel.filteredRecipes.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.filteredRecipes) { recipe in
                                NavigationLink(destination: RecipeDetailView(recipe: recipe).environmentObject(viewModel)) {
                                    RecipeCard(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteRecipe(recipe)
                                        }
                                    } label: {
                                        Label(LocalizationManager.recipesDeleteButton, systemImage: "trash")
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
            .navigationTitle(LocalizationManager.recipesScreenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizationManager.recipesBackButton) { dismiss() }
                        .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingExplore = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .accessibilityLabel(LocalizationManager.recipesExploreButton)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewRecipe = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingNewRecipe) {
                NewRecipeSheet()
                    .environmentObject(viewModel)
            }
            .fullScreenCover(isPresented: $showingExplore) {
                ExploreRecipesView()
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            viewModel.setAuthManager(authManager)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizationManager.recipesHeaderTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(LocalizationManager.recipesHeaderSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            Spacer()
        }
    }
    
    private var searchAndTags: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(LocalizationManager.recipesSearchPlaceholder, text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TagPill(title: LocalizationManager.recipesTagAll, isSelected: viewModel.selectedTag == nil) {
                        viewModel.selectedTag = nil
                    }
                    ForEach(viewModel.allTags, id: \.self) { tag in
                        TagPill(
                            title: displayTitle(tag),
                            isSelected: viewModel.selectedTag == tag
                        ) {
                            viewModel.selectedTag = tag // keep lowercase value internally
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private func displayTitle(_ value: String) -> String {
        value
            .split(separator: " ") // handle spaces
            .map { part in
                part.split(separator: "-").map { $0.capitalized }.joined(separator: "-")
            }
            .joined(separator: " ")
    }

    private var shimmerGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(LocalizationManager.recipesEmptyStateTitle)
                .font(.system(size: 18, weight: .semibold))
            Text(LocalizationManager.recipesEmptyStateSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TagPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(.ultraThinMaterial)
                    )
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}