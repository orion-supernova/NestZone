import SwiftUI

enum ModuleType: String, CaseIterable, Identifiable {
    case shopping = "shopping"
    case recipes = "recipes"
    case movies = "movies"
    case maintenance = "maintenance"
    case finance = "finance"
    case notes = "notes"
    case calendar = "calendar"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .shopping: return LocalizationManager.managementModuleShoppingTitle
        case .recipes: return LocalizationManager.managementModuleRecipesTitle
        case .movies: return LocalizationManager.managementModuleMoviesTitle
        case .maintenance: return LocalizationManager.managementModuleMaintenanceTitle
        case .finance: return LocalizationManager.managementModuleFinanceTitle
        case .notes: return LocalizationManager.managementModuleNotesTitle
        case .calendar: return LocalizationManager.managementModuleCalendarTitle
        }
    }
    
    var subtitle: String {
        switch self {
        case .shopping: return LocalizationManager.managementModuleShoppingSubtitle
        case .recipes: return LocalizationManager.managementModuleRecipesSubtitle
        case .movies: return LocalizationManager.managementModuleMoviesSubtitle
        case .maintenance: return LocalizationManager.managementModuleMaintenanceSubtitle
        case .finance: return LocalizationManager.managementModuleFinanceSubtitle
        case .notes: return LocalizationManager.managementModuleNotesSubtitle
        case .calendar: return LocalizationManager.managementModuleCalendarSubtitle
        }
    }
    
    var icon: String {
        switch self {
        case .shopping: return "cart.fill"
        case .recipes: return "fork.knife"
        case .movies: return "film.fill"
        case .maintenance: return "wrench.adjustable.fill"
        case .finance: return "dollarsign.circle.fill"
        case .notes: return "note.text"
        case .calendar: return "calendar.circle.fill"
        }
    }
    
    var colors: [Color] {
        switch self {
        case .shopping: return [.green, .mint]
        case .recipes: return [.orange, .yellow]
        case .movies: return [.purple, .pink]
        case .maintenance: return [.blue, .cyan]
        case .finance: return [.indigo, .purple]
        case .notes: return [.teal, .blue]
        case .calendar: return [.red, .orange]
        }
    }
    
    var comingSoon: Bool {
        switch self {
        case .shopping: return false
        case .recipes: return false
        case .movies: return false
        case .maintenance, .finance, .notes, .calendar: return true
        }
    }
}

struct ModuleData {
    let type: ModuleType
    let itemCount: Int
    let recentActivity: String
    let progress: Double
}