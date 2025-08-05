import SwiftUI

struct ManagementTabScreen: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = ManagementTabViewModel()
    
    @State private var animateCards = false
    @State private var animateHeader = false
    @State private var showingShoppingView = false
    
    // Dynamic modules data based on real data
    var modules: [ModuleData] {
        [
            ModuleData(
                type: .shopping, 
                itemCount: viewModel.totalItems, 
                recentActivity: viewModel.totalItems > 0 ? "Added \(viewModel.pendingItems) pending items" : "No items yet", 
                progress: viewModel.totalItems > 0 ? Double(viewModel.completedItems) / Double(viewModel.totalItems) : 0.0
            ),
            ModuleData(type: .recipes, itemCount: 0, recentActivity: "Recipe storage & meal planning", progress: 0.0),
            ModuleData(type: .maintenance, itemCount: 0, recentActivity: "House repair tracking", progress: 0.0),
            ModuleData(type: .finance, itemCount: 0, recentActivity: "Bill splitting & budgets", progress: 0.0),
            ModuleData(type: .notes, itemCount: 0, recentActivity: "Quick notes & reminders", progress: 0.0),
            ModuleData(type: .calendar, itemCount: 0, recentActivity: "Shared family calendar", progress: 0.0)
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
                    .offset(y: animateHeader ? 0 : -50)
                
                // Module Cards Grid (directly without wrapper)
                ModuleCardsSection(modules: modules, showingShoppingView: $showingShoppingView)
                    .padding(.top, 40)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 100)
            }
        }
        .background(
            ZStack {
                // Dynamic rainbow background
                RadialGradient(
                    colors: [
                        selectedTheme.colors(for: colorScheme).background,
                        Color.purple.opacity(0.08),
                        Color.blue.opacity(0.05),
                        Color.green.opacity(0.03),
                        Color.orange.opacity(0.02)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
                
                // Floating colorful shapes
                GeometryReader { geometry in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.4), Color.pink.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .offset(x: -50, y: geometry.size.height * 0.2)
                        .blur(radius: 35)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .offset(x: geometry.size.width - 10, y: geometry.size.height * 0.5)
                        .blur(radius: 30)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.4), Color.mint.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.8)
                        .blur(radius: 25)
                }
            }
        )
        .onAppear {
            startAnimations()
        }
        .fullScreenCover(isPresented: $showingShoppingView) {
            ShoppingListView()
                .environmentObject(viewModel)
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 1.0)) {
            animateHeader = true
        }
        
        withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
            animateCards = true
        }
    }
}

#Preview {
    ManagementTabScreen()
        .environmentObject(PocketBaseAuthManager())
}