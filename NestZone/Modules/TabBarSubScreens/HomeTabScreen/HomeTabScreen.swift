import SwiftUI

struct HomeTabScreen: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = HomeTabViewModel()
    @EnvironmentObject var tabNavigationHelper: TabNavigationHelper
    
    @State private var animateHeader = false
    @State private var animateStats = false
    @State private var showingShoppingView = false
    @State private var showingWhatToWatch = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                SimpleHeaderView()
                    .environmentObject(viewModel)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .opacity(animateHeader ? 1 : 0)
                    .offset(y: animateHeader ? 0 : -50)
                
                NavigableStatsSection(showingShoppingView: $showingShoppingView)
                    .environmentObject(viewModel)
                    .environmentObject(tabNavigationHelper)
                    .padding(.top, 40)
                    .opacity(animateStats ? 1 : 0)
                    .offset(y: animateStats ? 0 : 50)
                
                MiniGamesSection {
                    showingWhatToWatch = true
                }
                .padding(.top, 24)
                .padding(.bottom, 100)
                .opacity(animateStats ? 1 : 0)
                .offset(y: animateStats ? 0 : 50)
            }
        }
        .background(
            RadialGradient(
                colors: [
                    selectedTheme.colors(for: colorScheme).background,
                    Color.purple.opacity(0.05),
                    Color.blue.opacity(0.03)
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 1000
            )
        )
        .refreshable {
            await viewModel.refreshData()
        }
        .onAppear {
            startAnimations()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showingShoppingView) {
            ShoppingListView()
        }
        .fullScreenCover(isPresented: $showingWhatToWatch) {
            WhatToWatchView()
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 1.0)) {
            animateHeader = true
        }
        
        withAnimation(.easeOut(duration: 1.0).delay(0.4)) {
            animateStats = true
        }
    }
}

struct SimpleHeaderView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @EnvironmentObject private var viewModel: HomeTabViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizationManager.text(.hello(name: authManager.currentUser?.name ?? "User")))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    selectedTheme.colors(for: colorScheme).text,
                                    Color.purple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Manage your shared home together! ")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    if let name = authManager.currentUser?.name, let firstChar = name.first {
                        Text(String(firstChar).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("?")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct MiniGamesSection: View {
    let onTapWhatToWatch: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Mini Games")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Spacer()
            }
            .padding(.horizontal, 24)
            
            Button(action: onTapWhatToWatch) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink.opacity(0.2), Color.purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "film.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What to watch tonight")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Can't decide what movie to pick for the night? Let's play a game to solve this!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.pink.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 20)
        }
    }
}

struct NavigableStatsSection: View {
    @EnvironmentObject private var viewModel: HomeTabViewModel
    @EnvironmentObject var tabNavigationHelper: TabNavigationHelper
    @Binding var showingShoppingView: Bool
    
    let statConfigs = [
        ("note.text", "Notes", [Color.blue, Color.cyan]),
        ("list.bullet.clipboard.fill", "Shopping", [Color.green, Color.mint]),
        ("exclamationmark.triangle.fill", "Issues", [Color.red, Color.pink]),
        ("checkmark.circle.fill", "Tasks Done", [Color.orange, Color.yellow])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("House Statistics")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal, 24)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(statConfigs.enumerated()), id: \.offset) { index, config in
                    NavigableStatCard(
                        icon: config.0,
                        title: config.1,
                        count: getStatCount(for: index),
                        change: getStatChange(for: index),
                        gradient: config.2,
                        index: index,
                        action: {
                            switch index {
                            case 0:
                                tabNavigationHelper.navigateToTab(.notes)
                            case 1:
                                showingShoppingView = true
                            case 2:
                                tabNavigationHelper.navigateToTab(.management)
                            case 3:
                                tabNavigationHelper.navigateToTab(.management)
                            default:
                                break
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func getStatCount(for index: Int) -> String {
        switch index {
        case 0: return "\(viewModel.noteCount)"
        case 1: return "\(viewModel.shoppingListCount)"
        case 2: return "\(viewModel.issueCount)"
        case 3: return "\(getCompletedTasksCount())"
        default: return "0"
        }
    }
    
    private func getStatChange(for index: Int) -> String {
        let change: Int
        switch index {
        case 0: change = viewModel.noteChange
        case 1: change = viewModel.shoppingChange
        case 2: change = viewModel.issueChange
        case 3: change = viewModel.completedTasksChange
        default: change = 0
        }
        
        return change >= 0 ? "+\(change)" : "\(change)"
    }
    
    private func getCompletedTasksCount() -> Int {
        return viewModel.tasks.filter { $0.isCompleted }.count
    }
}

struct NavigableStatCard: View {
    let icon: String
    let title: String
    let count: String
    let change: String
    let gradient: [Color]
    let index: Int
    let action: () -> Void
    
    @State private var isPressed = false
    
    private var shouldShowChange: Bool {
        return change != "+0" && change != "0" && change != "-0"
    }
    
    var body: some View {
        Button {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            withAnimation(.spring(response: 0.2)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2)) {
                    isPressed = false
                }
                action()
            }
        } label: {
            VStack(spacing: 16) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: gradient.map { $0.opacity(0.2) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Spacer()
                    
                    if shouldShowChange {
                        Text(change)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: change.hasPrefix("+") ? 
                                                [Color.green.opacity(0.2), Color.mint.opacity(0.3)] :
                                                [Color.red.opacity(0.2), Color.pink.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: change.hasPrefix("+") ? [.green, .mint] : [.red, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(count)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Spacer()
                    }
                    
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.3) } + [Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: gradient[0].opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
    }
}

#Preview {
    HomeTabScreen()
        .environmentObject(PocketBaseAuthManager())
        .environmentObject(TabNavigationHelper())
}
