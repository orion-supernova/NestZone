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
            // Premium violet/indigo core with amber accent
            return ThemeColors(
                primary: [Color(hex: "7C3AED"), Color(hex: "4F46E5")],
                secondary: [Color(hex: "22D3EE"), Color(hex: "A78BFA")],
                accent: Color(hex: "F59E0B"),
                background: colorScheme == .dark ? Color(hex: "0B0F19") : Color(hex: "F5F7FB"),
                cardBackground: colorScheme == .dark ? Color(hex: "141826") : Color.white.opacity(0.85),
                text: colorScheme == .dark ? Color(hex: "F3F4F6") : Color(hex: "0B1220"),
                textSecondary: Color(hex: "94A3B8"),
                destructive: Color(hex: "EF4444"),
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.6)
            )
            
        case .cyberpunk:
            // Electric magenta + neon green with lemon accent
            return ThemeColors(
                primary: [Color(hex: "FF1F8A"), Color(hex: "46FF8B")],
                secondary: [Color(hex: "22D3EE"), Color(hex: "7C3AED")],
                accent: Color(hex: "FDE047"),
                background: colorScheme == .dark ? Color(hex: "06060A") : Color(hex: "0A0A0F").opacity(0.06),
                cardBackground: colorScheme == .dark ? Color(hex: "141218") : Color.white.opacity(0.85),
                text: colorScheme == .dark ? Color(hex: "F8FAFC") : Color(hex: "0B1220"),
                textSecondary: Color(hex: "94A3B8"),
                destructive: Color(hex: "EF4444"),
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.6)
            )
            
        case .retroWave:
            // Sunset pink + ultraviolet with cyan accent
            return ThemeColors(
                primary: [Color(hex: "FF4D8D"), Color(hex: "7A5AF8")],
                secondary: [Color(hex: "22D3EE"), Color(hex: "F472B6")],
                accent: Color(hex: "F59E0B"),
                background: colorScheme == .dark ? Color(hex: "0A0A12") : Color(hex: "F8FAFF"),
                cardBackground: colorScheme == .dark ? Color(hex: "141426") : Color.white.opacity(0.85),
                text: colorScheme == .dark ? Color(hex: "EDE9FE") : Color(hex: "0B1220"),
                textSecondary: Color(hex: "94A3B8"),
                destructive: Color(hex: "EF4444"),
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.6)
            )
            
        case .neonNight:
            // Emerald to cyan primary, purple secondary, warm accent
            return ThemeColors(
                primary: [Color(hex: "10B981"), Color(hex: "06B6D4")],
                secondary: [Color(hex: "7C3AED"), Color(hex: "9333EA")],
                accent: Color(hex: "F59E0B"),
                background: colorScheme == .dark ? Color(hex: "05070B") : Color(hex: "F4F7FB"),
                cardBackground: colorScheme == .dark ? Color(hex: "10151C") : Color.white.opacity(0.85),
                text: colorScheme == .dark ? Color(hex: "E5E7EB") : Color(hex: "0B1220"),
                textSecondary: Color(hex: "94A3B8"),
                destructive: Color(hex: "EF4444"),
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.6)
            )
            
        case .deepOcean:
            // Deep blue through cyan, cool accent
            return ThemeColors(
                primary: [Color(hex: "1D4ED8"), Color(hex: "06B6D4")],
                secondary: [Color(hex: "2563EB"), Color(hex: "60A5FA")],
                accent: Color(hex: "34D399"),
                background: colorScheme == .dark ? Color(hex: "050B14") : Color(hex: "F2F7FF"),
                cardBackground: colorScheme == .dark ? Color(hex: "0F172A") : Color.white.opacity(0.85),
                text: colorScheme == .dark ? Color(hex: "E2E8F0") : Color(hex: "0B1220"),
                textSecondary: Color(hex: "94A3B8"),
                destructive: Color(hex: "EF4444"),
                glassMaterial: colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.6)
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
    
    var primaryColor: Color {
        return primary.first ?? .purple
    }
    
    var secondaryPrimaryColor: Color {
        return primary.count > 1 ? primary[1] : primary.first ?? .purple
    }
}