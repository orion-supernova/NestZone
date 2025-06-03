import SwiftUI
import UIKit

struct TabBarScreen: View {
    @State private var selectedTab: Tab = .home
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = TabBarScrenViewModel()

    enum Tab: String, CaseIterable {
        case home = "Home"
        case list = "List"
        case notes = "Notes"
        case recipes = "Recipes"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .list: return "list.bullet.rectangle.fill"
            case .notes: return "note.text"
            case .recipes: return "fork.knife"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeTabScreen()
            }
            .tag(Tab.home)
            .tabItem {
                Label(Tab.home.rawValue, systemImage: Tab.home.icon)
            }
            .accessibilityIdentifier("HomeTab")
            
            NavigationStack {
                ListView()
            }
            .tag(Tab.list)
            .tabItem {
                Label(Tab.list.rawValue, systemImage: Tab.list.icon)
            }
            .accessibilityIdentifier("ListTab")
            .overlay(
                Button {
                    selectedTab = .list
                } label: {
                    Image(systemName: Tab.list.icon)
                        .opacity(0.001)
                }
                .frame(width: 60, height: 60)
                .position(x: UIScreen.main.bounds.width / 4, y: UIScreen.main.bounds.height - 40)
            )
            
            NavigationStack {
                NotesView()
            }
            .tag(Tab.notes)
            .tabItem {
                Label(Tab.notes.rawValue, systemImage: Tab.notes.icon)
            }
            .accessibilityIdentifier("NotesTab")
            
            NavigationStack {
                Text("Recipes")
            }
            .tag(Tab.recipes)
            .tabItem {
                Label(Tab.recipes.rawValue, systemImage: Tab.recipes.icon)
            }
            .accessibilityIdentifier("RecipesTab")
            
            NavigationStack {
                SettingsView()
            }
            .tag(Tab.settings)
            .tabItem {
                Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
            }
            .accessibilityIdentifier("SettingsTab")
        }
        .tint(selectedTheme.colors(for: colorScheme).primary[0])
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

#Preview {
    TabBarScreen()
}
