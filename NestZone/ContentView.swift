//
//  ContentView.swift
//  NestZone
//
//  Created by muratcankoc on 01/06/2025.
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    
    var body: some View {
        if authManager.currentUser != nil {
            TabBarScreen()
        } else {
            LoginScreen()
        }
    }
}

#Preview {
    ContentView()
}
