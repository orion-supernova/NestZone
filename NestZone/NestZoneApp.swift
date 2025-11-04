//
//  NestZoneApp.swift
//  NestZone
//
//  Created by muratcankoc on 01/06/2025.
//

import SwiftUI

@main
struct NestZoneApp: App {
    @StateObject private var authManager = PocketBaseAuthManager()
    @StateObject private var homeManager = HomeSelectionManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.currentUser == nil {
                    AuthenticationScreen()
                        .environmentObject(authManager)
                        .environmentObject(homeManager)
                } else {
                    TabBarScreen()
                        .environmentObject(authManager)
                        .environmentObject(homeManager)
                }
            }
        }
    }
}