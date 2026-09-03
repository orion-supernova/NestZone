import SwiftUI

struct ManagementTabScreen: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: ConvexAuthManager
    @StateObject private var viewModel = ManagementTabViewModel()
    
    @State private var animateCards = false
    @State private var animateHeader = false
    @State private var showingShoppingView = false
    @State private var showingRecipesView = false
    @State private var showingMoviesView = false
    
    // Dynamic modules data based on real data
    var modules: [ModuleData] {
        [
            ModuleData(
                type: .shopping, 
                itemCount: viewModel.totalItems, 
                recentActivity: viewModel.totalItems > 0 ? LocalizationManager.managementModuleShoppingSubtitleDynamic(viewModel.pendingItems) : LocalizationManager.managementModuleShoppingSubtitleEmpty, 
                progress: viewModel.totalItems > 0 ? Double(viewModel.completedItems) / Double(viewModel.totalItems) : 0.0
            ),
            ModuleData(type: .recipes, itemCount: 0, recentActivity: LocalizationManager.managementModuleRecipesSubtitle, progress: 0.0),
            ModuleData(type: .movies, itemCount: 0, recentActivity: LocalizationManager.managementModuleMoviesSubtitle, progress: 0.0),
            ModuleData(type: .maintenance, itemCount: 0, recentActivity: LocalizationManager.managementModuleMaintenanceSubtitle, progress: 0.0),
            ModuleData(type: .finance, itemCount: 0, recentActivity: LocalizationManager.managementModuleFinanceSubtitle, progress: 0.0),
            ModuleData(type: .calendar, itemCount: 0, recentActivity: LocalizationManager.managementModuleCalendarSubtitle, progress: 0.0)
        ]
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Colorful Header
                ModuleHubHeaderView()
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .opacity(animateHeader ? 1 : 0)
                
                // Module Cards Grid (directly without wrapper)
                ModuleCardsSection(modules: modules, showingShoppingView: $showingShoppingView, showingRecipesView: $showingRecipesView, showingMoviesView: $showingMoviesView)
                    .padding(.top, 40)
                    .padding(.bottom, 100)
                    .opacity(animateCards ? 1 : 0)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    selectedTheme.colors(for: colorScheme).background,
                    Color.purple.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            startAnimations()
        }
        .fullScreenCover(isPresented: $showingShoppingView) {
            ShoppingListView()
                .environmentObject(viewModel)
        }
        .fullScreenCover(isPresented: $showingRecipesView) {
            RecipeListView()
        }
        .fullScreenCover(isPresented: $showingMoviesView) {
            MovieListsView()
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.35)) {
            animateHeader = true
            animateCards = true
        }
    }
}

#Preview {
    ManagementTabScreen()
        .environmentObject(ConvexAuthManager())
}