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
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.currentUser == nil {
                    AuthenticationScreen()
                        .environmentObject(authManager)
                } else {
                    TabBarScreen()
                        .environmentObject(authManager)
                }
            }
        }
    }
}