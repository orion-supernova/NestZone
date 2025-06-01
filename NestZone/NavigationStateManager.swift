import SwiftUI

class NavigationStateManager: ObservableObject {
    static let shared = NavigationStateManager()
    
    @Published var currentScreen: String = "home"
    @Published var shouldShowFloatingMenu = true
    
    private init() {} // Singleton
}