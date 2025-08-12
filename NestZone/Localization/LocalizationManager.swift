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

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published private(set) var currentLanguage: Language = .english
    private var fileTranslations: [Language: [String: String]] = [:]

    private init() {
        if let storedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: storedLanguage) {
            currentLanguage = language
        }
        loadFileTranslations()
    }

    private func loadFileTranslations() {
        for language in Language.allCases {
            let fileName = language.rawValue
            var loadedTranslations: [String: String] = [:]
            
            // Try multiple possible locations
            let possiblePaths = [
                // Direct in bundle root
                Bundle.main.url(forResource: fileName, withExtension: "json"),
                // In Localization subdirectory
                Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Localization"),
                // In Locales subdirectory
                Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Locales"),
                // In Localization/Locales subdirectory
                Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Localization/Locales")
            ]
            
            var foundFile = false
            for url in possiblePaths {
                if let url = url {
                    do {
                        let data = try Data(contentsOf: url)
                        if let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                            loadedTranslations = dict
                            foundFile = true
                            print("✅ Successfully loaded \(dict.count) translations for \(language.rawValue) from: \(url.lastPathComponent)")
                            break
                        }
                    } catch {
                        print("⚠️ Error parsing JSON for \(language.rawValue) at \(url.path): \(error)")
                        continue
                    }
                }
            }
            
            if !foundFile {
                print("❌ Could not find translation file for language: \(language.rawValue)")
                print("📁 Bundle path: \(Bundle.main.bundlePath)")
                print("📁 Bundle resources: \(Bundle.main.paths(forResourcesOfType: "json", inDirectory: nil))")
            }
            
            fileTranslations[language] = loadedTranslations
        }
    }

    func localized(_ key: String) -> String {
        if let value = fileTranslations[currentLanguage]?[key] {
            return value
        }
        if let fallback = fileTranslations[.english]?[key] {
            return fallback
        }
        print("🔍 Missing translation for key: \(key)")
        return key
    }

    func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        let formatString = localized(key)
        return String(format: formatString, locale: Locale.current, arguments: args)
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguage")
        loadFileTranslations()
        objectWillChange.send()
    }
}

// Helper for easier access
extension LocalizationManager {
    static func t(_ key: String) -> String {
        return LocalizationManager.shared.localized(key)
    }
    static func tFormat(_ key: String, _ args: CVarArg...) -> String {
        return LocalizationManager.shared.localizedFormat(key, args)
    }
}