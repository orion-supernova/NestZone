import SwiftUI
import UIKit

struct TabBarScreen: View {
    @State private var selectedTab: Tab = .home
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = TabBarScreenViewModel()
    @StateObject private var tabNavigationHelper = TabNavigationHelper()

    enum Tab: String, CaseIterable {
        case home = "Home"
        case management = "Hub"
        case notes = "Notes" 
        case messages = "Messages"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .management: return "list.bullet.rectangle.fill"
            case .notes: return "note.text"
            case .messages: return "message.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var localizedTitle: String {
            switch self {
            case .home: return LocalizationManager.tabBarHome
            case .management: return LocalizationManager.tabBarHub
            case .notes: return LocalizationManager.tabBarNotes
            case .messages: return LocalizationManager.tabBarMessages
            case .settings: return LocalizationManager.tabBarSettings
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading View
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(selectedTheme.colors(for: colorScheme).primary[0])
                    Text(LocalizationManager.tabBarLoading)
                        .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                }
            } else if viewModel.homes.isEmpty {
                NoHomesView()
                    .environmentObject(viewModel)
                    .environmentObject(authManager)
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        HomeTabScreen()
                            .environmentObject(tabNavigationHelper)
                    }
                    .tag(Tab.home)
                    .tabItem {
                        Label(Tab.home.localizedTitle, systemImage: Tab.home.icon)
                    }
                    .accessibilityIdentifier("HomeTab")
                    
                    NavigationStack {
                        ManagementTabScreen()
                    }
                    .tag(Tab.management)
                    .tabItem {
                        Label(Tab.management.localizedTitle, systemImage: Tab.management.icon)
                    }
                    .accessibilityIdentifier("ManagementTab")
                    
                    NavigationStack {
                        NotesView()
                    }
                    .tag(Tab.notes)
                    .tabItem {
                        Label(Tab.notes.localizedTitle, systemImage: Tab.notes.icon)
                    }
                    .accessibilityIdentifier("NotesTab")
                    
                    NavigationStack {
                        MessagesView()
                    }
                    .tag(Tab.messages)
                    .tabItem {
                        Label(Tab.messages.localizedTitle, systemImage: Tab.messages.icon)
                    }
                    .accessibilityIdentifier("MessagesTab")
                    
                    NavigationStack {
                        SettingsView()
                    }
                    .tag(Tab.settings)
                    .tabItem {
                        Label(Tab.settings.localizedTitle, systemImage: Tab.settings.icon)
                    }
                    .accessibilityIdentifier("SettingsTab")
                }
                .tint(selectedTheme.colors(for: colorScheme).primary[0])
                .onReceive(tabNavigationHelper.$targetTab) { tab in
                    if let tab = tab {
                        selectedTab = tab
                        tabNavigationHelper.targetTab = nil
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .task {
            // Try to refresh auth on app start
            if authManager.currentUser == nil {
                try? await authManager.refreshAuth()
                print(authManager.currentUser)
            }
            do {
                try await viewModel.fetchUserHome(authManager: authManager)
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
}

// Helper class for tab navigation
class TabNavigationHelper: ObservableObject {
    @Published var targetTab: TabBarScreen.Tab?
    
    func navigateToTab(_ tab: TabBarScreen.Tab) {
        targetTab = tab
    }
}

#Preview {
    TabBarScreen()
}