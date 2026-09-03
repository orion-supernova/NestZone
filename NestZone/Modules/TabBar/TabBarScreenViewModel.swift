//
//  TabBarScreenViewModel.swift
//  NestZone
//
//  Created by muratcankoc on 03/06/2025.
//

import SwiftUI

@MainActor
class TabBarScreenViewModel: ObservableObject {
    // MARK: - Properties
    @Published var homes: [Home] = []
    @Published var isLoading = true

    // MARK: - Public Methods
    func fetchUserHome(authManager: ConvexAuthManager) async throws {
        isLoading = true
        defer { isLoading = false }
        // Auth is implicit in the Convex client; the server scopes to the caller.
        self.homes = try await Convex.once("homes:listMine", as: [Home].self)
    }
}