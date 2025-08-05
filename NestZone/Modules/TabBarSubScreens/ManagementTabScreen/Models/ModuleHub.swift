import SwiftUI

enum ModuleType: String, CaseIterable, Identifiable {
    case shopping = "shopping"
    case recipes = "recipes"
    case maintenance = "maintenance"
    case finance = "finance"
    case notes = "notes"
    case calendar = "calendar"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .shopping: return "Shopping Lists"
        case .recipes: return "Recipes"
        case .maintenance: return "House Problems"
        case .finance: return "Bills & Finance"
        case .notes: return "Notes & Ideas"
        case .calendar: return "Calendar & Events"
        }
    }
    
    var subtitle: String {
        switch self {
        case .shopping: return "Manage your shopping lists"
        case .recipes: return "Save delicious recipes & meal plans"
        case .maintenance: return "Track repairs & maintenance tasks"
        case .finance: return "Split bills & manage expenses"
        case .notes: return "Capture ideas & important notes"
        case .calendar: return "Organize events & schedules"
        }
    }
    
    var icon: String {
        switch self {
        case .shopping: return "cart.fill"
        case .recipes: return "fork.knife"
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
        case .maintenance: return [.blue, .cyan]
        case .finance: return [.purple, .pink]
        case .notes: return [.indigo, .blue]
        case .calendar: return [.red, .orange]
        }
    }
    
    var comingSoon: Bool {
        switch self {
        case .shopping: return false
        case .recipes, .maintenance, .finance, .notes, .calendar: return true
        }
    }
}

struct ModuleData {
    let type: ModuleType
    let itemCount: Int
    let recentActivity: String
    let progress: Double
}