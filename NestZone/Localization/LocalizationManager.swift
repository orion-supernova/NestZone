import Foundation
import SwiftUI

enum Language: String, CaseIterable {
    case english = "en"
    case turkish = "tr"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }
}

enum LocalizationKey: Hashable {
    case done
    case hello(name: String)
    case tasksCount(count: Int)
    case todaysTasks
    case statistics
    case kitchen
    case shopping
    case laundry
    case assigned(name: String)
    case settingsTitle
    case appearance
    case theme
    case account
    case profile
    case notifications
    case general
    case help
    case about
    case logout
    case language

    func hash(into hasher: inout Hasher) {
        switch self {
        case .done:
            hasher.combine(0)
        case .hello(let name):
            hasher.combine(1)
            hasher.combine(name)
        case .tasksCount(let count):
            hasher.combine(2)
            hasher.combine(count)
        case .todaysTasks:
            hasher.combine(3)
        case .statistics:
            hasher.combine(4)
        case .kitchen:
            hasher.combine(5)
        case .shopping:
            hasher.combine(6)
        case .laundry:
            hasher.combine(7)
        case .assigned(let name):
            hasher.combine(8)
            hasher.combine(name)
        case .settingsTitle:
            hasher.combine(9)
        case .appearance:
            hasher.combine(10)
        case .theme:
            hasher.combine(11)
        case .account:
            hasher.combine(12)
        case .profile:
            hasher.combine(13)
        case .notifications:
            hasher.combine(14)
        case .general:
            hasher.combine(15)
        case .help:
            hasher.combine(16)
        case .about:
            hasher.combine(17)
        case .logout:
            hasher.combine(18)
        case .language:
            hasher.combine(19)
        }
    }

    static func == (lhs: LocalizationKey, rhs: LocalizationKey) -> Bool {
        switch (lhs, rhs) {
        case (.done, .done),
             (.todaysTasks, .todaysTasks),
             (.statistics, .statistics),
             (.kitchen, .kitchen),
             (.shopping, .shopping),
             (.laundry, .laundry),
             (.settingsTitle, .settingsTitle),
             (.appearance, .appearance),
             (.theme, .theme),
             (.account, .account),
             (.profile, .profile),
             (.notifications, .notifications),
             (.general, .general),
             (.help, .help),
             (.about, .about),
             (.logout, .logout),
             (.language, .language):
            return true
        case (.hello(let name1), .hello(let name2)):
            return name1 == name2
        case (.tasksCount(let count1), .tasksCount(let count2)):
            return count1 == count2
        case (.assigned(let name1), .assigned(let name2)):
            return name1 == name2
        default:
            return false
        }
    }
}

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published private(set) var currentLanguage: Language = .english
    
    private init() {
        if let storedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: storedLanguage) {
            currentLanguage = language
        }
    }
    
    private let translations: [Language: [LocalizationKey: String]] = [
        .english: [
            .done: "Done",
            .hello(name: "*"): "Hello %@!",
            .tasksCount(count: 0): "You have %d tasks today",
            .todaysTasks: "TODAY'S TASKS",
            .statistics: "HOUSE STATISTICS",
            .kitchen: "Kitchen Cleaning",
            .shopping: "Shopping",
            .laundry: "Laundry",
            .assigned(name: "*"): "%@'s turn",
            .settingsTitle: "Settings",
            .appearance: "Appearance",
            .theme: "Theme",
            .account: "Account",
            .profile: "Profile",
            .notifications: "Notifications",
            .general: "General",
            .help: "Help",
            .about: "About",
            .logout: "Logout",
            .language: "Language"
        ],
        
        .turkish: [
            .done: "Tamam",
            .hello(name: "*"): "Merhaba %@!",
            .tasksCount(count: 0): "Bugün %d görevin var",
            .todaysTasks: "BUGÜNKÜ GÖREVLER",
            .statistics: "EV İSTATİSTİKLERİ",
            .kitchen: "Mutfak Temizliği",
            .shopping: "Market Alışverişi",
            .laundry: "Çamaşır",
            .assigned(name: "*"): "%@'ın sırası",
            .settingsTitle: "Ayarlar",
            .appearance: "Görünüm",
            .theme: "Tema",
            .account: "Hesap",
            .profile: "Profil",
            .notifications: "Bildirimler",
            .general: "Genel",
            .help: "Yardım",
            .about: "Hakkında",
            .logout: "Çıkış Yap",
            .language: "Dil"
        ]
    ]
    
    func localizedText(_ key: LocalizationKey) -> String {
        var lookupKey = key
        switch key {
        case .hello(let name) where name != "*":
            lookupKey = .hello(name: "*")
        case .tasksCount:
            lookupKey = .tasksCount(count: 0)
        case .assigned(let name) where name != "*":
            lookupKey = .assigned(name: "*")
        default:
            break
        }
        
        guard let baseText = translations[currentLanguage]?[lookupKey] else {
            return "Missing translation"
        }
        
        switch key {
        case .hello(let name):
            return String(format: baseText, name)
        case .tasksCount(let count):
            return String(format: baseText, count)
        case .assigned(let name):
            return String(format: baseText, name)
        default:
            return baseText
        }
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguage")
        objectWillChange.send()
    }
}

// Helper for easier access
extension LocalizationManager {
    static func text(_ key: LocalizationKey) -> String {
        return LocalizationManager.shared.localizedText(key)
    }
}
