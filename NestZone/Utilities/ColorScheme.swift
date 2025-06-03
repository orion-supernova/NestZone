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
                background: colorScheme == .dark ? .black : .white,
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white,
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red
            )
        case .cyberpunk:
            return ThemeColors(
                primary: [.pink, .green],
                secondary: [.cyan],
                accent: .yellow,
                background: colorScheme == .dark ? .black : .white,
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white,
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red
            )
        case .retroWave:
            return ThemeColors(
                primary: [.pink, .purple],
                secondary: [.cyan],
                accent: .yellow,
                background: colorScheme == .dark ? .black : .white,
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white,
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red
            )
        case .neonNight:
            return ThemeColors(
                primary: [.green, .cyan],
                secondary: [.purple],
                accent: .yellow,
                background: colorScheme == .dark ? .black : .white,
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white,
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red
            )
        case .deepOcean:
            return ThemeColors(
                primary: [.blue, .cyan],
                secondary: [.blue],
                accent: .green,
                background: colorScheme == .dark ? .black : .white,
                cardBackground: colorScheme == .dark ? Color(white: 0.15) : .white,
                text: colorScheme == .dark ? .white : .black,
                textSecondary: .gray,
                destructive: .red
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
}
