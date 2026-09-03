import SwiftUI

struct ThemeSelectionSheet: View {
    @Binding var isShowingSheet: Bool
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateButtons = false
    
    private func themeIcon(for theme: AppTheme) -> String {
        switch theme {
        case .basic: return "circle.grid.cross.fill"
        case .cyberpunk: return "bolt.circle.fill"
        case .retroWave: return "sunset.fill"
        case .neonNight: return "sparkles"
        case .deepOcean: return "water.waves"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(AppTheme.allCases.enumerated()), id: \.element) { index, theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: selectedTheme == theme
                        ) {
                            withAnimation(.spring(duration: 0.3)) {
                                selectedTheme = theme
                                isShowingSheet = false
                            }
                            
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                        .offset(y: animateButtons ? 0 : 50)
                        .opacity(animateButtons ? 1 : 0)
                        .animation(
                            .spring(
                                response: 0.3,
                                dampingFraction: 0.8,
                                blendDuration: 0
                            )
                            .delay(Double(index) * 0.1),
                            value: animateButtons
                        )
                    }
                }
                .padding()
            }
            .background(selectedTheme.colors(for: colorScheme).background)
            .navigationTitle(LocalizationManager.settingsThemeChooseTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizationManager.commonDone) {
                        isShowingSheet = false
                    }
                }
            }
            .onAppear {
                withAnimation {
                    animateButtons = true
                }
            }
            .onDisappear {
                animateButtons = false
            }
        }
    }
}

struct ThemeButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var themeIcon: String {
        switch theme {
        case .basic: return "circle.grid.cross.fill"
        case .cyberpunk: return "bolt.circle.fill"
        case .retroWave: return "sunset.fill"
        case .neonNight: return "sparkles"
        case .deepOcean: return "water.waves"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: themeIcon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: theme.colors(for: colorScheme).primary,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(theme.rawValue)
                    .font(.headline)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(selectedTheme.colors(for: colorScheme).accent)
                        .symbolEffect(.bounce, value: isSelected)
                }
            }
            .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedTheme.colors(for: colorScheme).cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected
                            ? theme.colors(for: colorScheme).primary[0].opacity(0.5)
                            : selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(duration: 0.2), value: isPressed)
        .onTapGesture {
            withAnimation {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
            
            action()
        }
    }
}

#Preview {
    ThemeSelectionSheet(isShowingSheet: .constant(true))
}