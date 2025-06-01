//
//  BaseView.swift
//  NestZone
//
//  Created by muratcankoc on 01/06/2025.
//

import SwiftUI
import UIKit  // For UIImpactFeedbackGenerator

struct BaseView: View {
    @State private var selectedTab: Tab = .home
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var localizationManager = LocalizationManager.shared

    enum Tab: String, CaseIterable {
        case home = "Home"
        case list = "List"
        case chat = "Chat"
        case recipes = "Recipes"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .list: return "list.bullet.rectangle.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .recipes: return "fork.knife"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)
            
            Text("List")
                .tabItem {
                    Label(Tab.list.rawValue, systemImage: Tab.list.icon)
                }
                .tag(Tab.list)
            
            Text("Chat")
                .tabItem {
                    Label(Tab.chat.rawValue, systemImage: Tab.chat.icon)
                }
                .tag(Tab.chat)
            
            Text("Recipes")
                .tabItem {
                    Label(Tab.recipes.rawValue, systemImage: Tab.recipes.icon)
                }
                .tag(Tab.recipes)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
            }
            .tag(Tab.settings)
        }
        .tint(selectedTheme.colors(for: colorScheme).primary[0])
        .environment(\.colorScheme, .dark)
    }
}
