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
            if let url = Bundle.main.url(forResource: language.rawValue, withExtension: "json") {
                do {
                    let data = try Data(contentsOf: url)
                    if let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                        fileTranslations[language] = dict
                    }
                } catch {
                    // If loading fails, keep previous or empty mapping
                    fileTranslations[language] = fileTranslations[language] ?? [:]
                }
            } else {
                // No file, ensure an empty mapping exists
                fileTranslations[language] = fileTranslations[language] ?? [:]
            }
        }
    }

    func localized(_ key: String) -> String {
        if let value = fileTranslations[currentLanguage]?[key] {
            return value
        }
        if let fallback = fileTranslations[.english]?[key] {
            return fallback
        }
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