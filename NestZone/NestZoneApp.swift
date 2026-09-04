//
//  NestZoneApp.swift
//  NestZone
//

import ComposableArchitecture
import SwiftUI

/// The app target is a shell. Everything real lives in `Packages/NestZoneKit`,
/// which builds and previews without the app around it.
@main
struct NestZoneApp: App {
    /// One store for the process. `Store` is reference-typed, so this is a
    /// stable root rather than something SwiftUI may recreate.
    @MainActor
    private static let store = Store(initialState: AppFeature.State()) {
        #if DEBUG
        AppFeature()._printChanges(.actionLabels)
        #else
        AppFeature()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }
}
