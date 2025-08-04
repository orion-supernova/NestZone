import SwiftUI

enum AppTheme: String, CaseIterable {
    case basic = "Basic"
    case cyberpunk = "Cyberpunk"
    case retroWave = "RetroWave"
    case neonNight = "Neon Night"
    case deepOcean = "Deep Ocean"
    
    func colors(for colorScheme: ColorScheme) -> ThemeColors {
        switch self {
        case .basic:
            return ThemeColors(
                primary: [.purple.opacity(0.8)],
                secondary: [.orange],
                accent: .green,
                background: colorScheme == .dark ? .black : Color(.systemGray6),
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white.opacity(0.8),
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red,
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.7)
            )
        case .cyberpunk:
            return ThemeColors(
                primary: [.pink, .green],
                secondary: [.cyan],
                accent: .yellow,
                background: colorScheme == .dark ? .black : Color(.systemGray6),
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white.opacity(0.8),
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red,
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.7)
            )
        case .retroWave:
            return ThemeColors(
                primary: [.pink, .purple],
                secondary: [.cyan],
                accent: .yellow,
                background: colorScheme == .dark ? .black : Color(.systemGray6),
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white.opacity(0.8),
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red,
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.7)
            )
        case .neonNight:
            return ThemeColors(
                primary: [.green, .cyan],
                secondary: [.purple],
                accent: .yellow,
                background: colorScheme == .dark ? .black : Color(.systemGray6),
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white.opacity(0.8),
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red,
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.7)
            )
        case .deepOcean:
            return ThemeColors(
                primary: [.blue, .cyan],
                secondary: [.blue],
                accent: .green,
                background: colorScheme == .dark ? .black : Color(.systemGray6),
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white.opacity(0.8),
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red,
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.7)
            )
        }
    }
}

struct ThemeColors {
    let primary: [Color]
    let secondary: [Color]
    let accent: Color
    let background: Color
    let cardBackground: Color
    let text: Color
    let textSecondary: Color
    let destructive: Color
    let glassMaterial: Color
    
    // Safe accessors for primary colors
    var primaryColor: Color {
        return primary.first ?? .purple
    }
    
    var secondaryPrimaryColor: Color {
        return primary.count > 1 ? primary[1] : primary.first ?? .purple
    }
}