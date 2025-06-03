import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingThemeSheet = false
    @State private var isShowingLanguageSheet = false
    @StateObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: selectedTheme.colors(for: colorScheme).primary + [selectedTheme.colors(for: colorScheme).primary.first?.opacity(0.8) ?? .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)
                                .shadow(color: selectedTheme.colors(for: colorScheme).primary.first?.opacity(0.3) ?? .purple.opacity(0.3), radius: 20, x: 0, y: 8)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Welcome back!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                            
                            Text("Customize your experience")
                                .font(.subheadline)
                                .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    VStack(spacing: 24) {
                        // Appearance Section
                        SettingsSection(title: LocalizationManager.text(.appearance)) {
                            VStack(spacing: 0) {
                                // Theme Row
                                SettingsButton(action: { isShowingThemeSheet = true }) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(
                                                    LinearGradient(
                                                        colors: selectedTheme.colors(for: colorScheme).primary,
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 40, height: 40)
                                                .shadow(color: selectedTheme.colors(for: colorScheme).primary.first?.opacity(0.4) ?? .purple.opacity(0.4), radius: 8, x: 0, y: 4)
                                            
                                            Image(systemName: "paintbrush.pointed.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundStyle(.white)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(LocalizationManager.text(.theme))
                                                .font(.body)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                                            
                                            HStack(spacing: 8) {
                                                Text(selectedTheme.rawValue)
                                                    .font(.caption)
                                                    .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                                                
                                                // Theme Preview Dots
                                                HStack(spacing: 3) {
                                                    ForEach(selectedTheme.colors(for: colorScheme).primary.prefix(3).indices, id: \.self) { index in
                                                        Circle()
                                                            .fill(selectedTheme.colors(for: colorScheme).primary[index])
                                                            .frame(width: 6, height: 6)
                                                            .shadow(color: selectedTheme.colors(for: colorScheme).primary[index].opacity(0.5), radius: 2, x: 0, y: 1)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                                    }
                                }
                                
                                Divider()
                                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.15))
                                    .padding(.vertical, 12)
                                
                                // Language Row
                                SettingsButton(action: { isShowingLanguageSheet = true }) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.blue, .cyan],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 40, height: 40)
                                                .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                                            
                                            Image(systemName: "globe")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundStyle(.white)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(LocalizationManager.text(.language))
                                                .font(.body)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                                            
                                            Text(localizationManager.currentLanguage.displayName)
                                                .font(.caption)
                                                .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                                    }
                                }
                            }
                        }

                        // Account Section
                        SettingsSection(title: LocalizationManager.text(.account)) {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    title: LocalizationManager.text(.profile),
                                    icon: "person.crop.circle.fill",
                                    iconGradient: [.green, .mint]
                                ) {
                                    // Profile action
                                }
                                
                                Divider()
                                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.15))
                                    .padding(.vertical, 12)
                                
                                SettingsRow(
                                    title: LocalizationManager.text(.notifications),
                                    icon: "bell.fill",
                                    iconGradient: [.orange, .yellow]
                                ) {
                                    // Notifications action
                                }
                            }
                        }

                        // General Section
                        SettingsSection(title: LocalizationManager.text(.general)) {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    title: LocalizationManager.text(.help),
                                    icon: "questionmark.circle.fill",
                                    iconGradient: [.blue, .indigo]
                                ) {
                                    // Help action
                                }
                                
                                Divider()
                                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.15))
                                    .padding(.vertical, 12)
                                
                                SettingsRow(
                                    title: LocalizationManager.text(.about),
                                    icon: "info.circle.fill",
                                    iconGradient: [.purple, .pink]
                                ) {
                                    // About action
                                }
                            }
                        }

                        // Logout Section
                        SettingsSection(title: "") {
                            SettingsButton(action: {
                                authManager.logout()
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.red, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 40, height: 40)
                                            .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                                        
                                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                    
                                    Text(LocalizationManager.text(.logout))
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        // Bottom spacing
                        Color.clear
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(selectedTheme.colors(for: colorScheme).background)
            .navigationTitle(LocalizationManager.text(.settingsTitle))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $isShowingThemeSheet) {
                ThemeSelectionSheet(isShowingSheet: $isShowingThemeSheet)
            }
            .sheet(isPresented: $isShowingLanguageSheet) {
                LanguageSelectionSheet(isShowingSheet: $isShowingLanguageSheet)
            }
            .tint(selectedTheme.colors(for: colorScheme).primary[0])
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                    .padding(.leading, 4)
            }
            
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(selectedTheme.colors(for: colorScheme).cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }
}

struct SettingsButton<Content: View>: View {
    let action: () -> Void
    let content: Content
    @State private var isPressed = false
    
    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
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

struct SettingsRow: View {
    let title: String
    let icon: String
    let iconGradient: [Color]
    let action: () -> Void
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SettingsButton(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: iconGradient.first?.opacity(0.4) ?? .gray.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
