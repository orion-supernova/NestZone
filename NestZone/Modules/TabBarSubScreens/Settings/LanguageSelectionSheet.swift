import SwiftUI

struct LanguageSelectionSheet: View {
    @Binding var isShowingSheet: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var animateButtons = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(Language.allCases.enumerated()), id: \.element) { index, language in
                        LanguageButton(
                            language: language,
                            isSelected: localizationManager.currentLanguage == language
                        ) {
                            withAnimation(.spring(duration: 0.3)) {
                                localizationManager.setLanguage(language)
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
            .navigationTitle(LocalizationManager.text(.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.text(.done)) {
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

struct LanguageButton: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.displayName)
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
                            ? selectedTheme.colors(for: colorScheme).accent.opacity(0.5)
                            : selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(duration: 0.2), value: isPressed)
    }
}

#Preview {
    LanguageSelectionSheet(isShowingSheet: .constant(true))
}
