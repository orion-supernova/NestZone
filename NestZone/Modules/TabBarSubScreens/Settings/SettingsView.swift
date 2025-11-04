import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingThemeSheet = false
    @State private var isShowingLanguageSheet = false
    @State private var isShowingSwitchHomeSheet = false
    @State private var isShowingJoinHomeSheet = false
    @StateObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @EnvironmentObject private var homeManager: HomeSelectionManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    
                    VStack(spacing: 24) {
                        homeManagementSection
                        appearanceSection
                        accountSection
                        generalSection
                        logoutSection
                        
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(selectedTheme.colors(for: colorScheme).background)
            .navigationTitle(LocalizationManager.settingsScreenTitle)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $isShowingThemeSheet) {
                ThemeSelectionSheet(isShowingSheet: $isShowingThemeSheet)
            }
            .sheet(isPresented: $isShowingLanguageSheet) {
                LanguageSelectionSheet(isShowingSheet: $isShowingLanguageSheet)
            }
            .sheet(isPresented: $isShowingSwitchHomeSheet) {
                SwitchHomeSheet()
                    .environmentObject(homeManager)
            }
            .sheet(isPresented: $isShowingJoinHomeSheet, onDismiss: {
                Task {
                    try? await homeManager.fetchUserHomes(authManager: authManager)
                }
            }) {
                JoinHomeView()
                    .environmentObject(authManager)
            }
            .tint(selectedTheme.colors(for: colorScheme).primary[0])
        }
    }
    
    private var profileHeader: some View {
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
                Text(LocalizationManager.settingsProfileWelcomeBack)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                
                Text(LocalizationManager.settingsProfileCustomizeExperience)
                    .font(.subheadline)
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 32)
    }
    
    @ViewBuilder
    private var homeManagementSection: some View {
        if let home = homeManager.selectedHome {
            SettingsSection(title: LocalizationManager.settingsHomeManagementTitle) {
                homeContent(for: home)
            }
        }
    }
    
    private func homeContent(for home: Home) -> some View {
        VStack(spacing: 0) {
            currentHomeInfo(for: home)
            
            if homeManager.hasMultipleHomes {
                Divider()
                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.15))
                    .padding(.vertical, 12)
                
                switchHomeButton
            }
            
            // Join Another Home Button - Always show
            Divider()
                .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.15))
                .padding(.vertical, 12)
            
            joinAnotherHomeButton
        }
    }
    
    private func currentHomeInfo(for home: Home) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationManager.settingsCurrentHomeTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                    
                    Text(home.name)
                        .font(.caption)
                        .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                }
                
                Spacer()
                
                Text("\(home.members.count) \(home.members.count == 1 ? LocalizationManager.settingsMembersSingular : LocalizationManager.settingsMembersPlural)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).primary.first ?? .blue)
            }
            
            if let inviteCode = home.inviteCode {
                inviteCodeSection(inviteCode: inviteCode)
            }
        }
    }
    
    private func inviteCodeSection(inviteCode: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizationManager.settingsInviteCodeTitle)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
            
            HStack {
                Text(inviteCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(selectedTheme.colors(for: colorScheme).background.opacity(0.8)))
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = inviteCode
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc").font(.system(size: 12, weight: .semibold))
                        Text(LocalizationManager.settingsInviteCodeCopyButton).font(.caption).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)))
                }
            }
            
            Text(LocalizationManager.settingsInviteCodeHelpText)
                .font(.caption2)
                .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
        }
        .padding(.top, 8)
    }
    
    private var switchHomeButton: some View {
        SettingsButton(action: { isShowingSwitchHomeSheet = true }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Text(LocalizationManager.switchHomeButton)
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
    
    private var joinAnotherHomeButton: some View {
        SettingsButton(action: { isShowingJoinHomeSheet = true }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Text(LocalizationManager.joinAnotherHomeButton)
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
    
    private var appearanceSection: some View {
        SettingsSection(title: LocalizationManager.settingsAppearanceTitle) {
            VStack(spacing: 0) {
                themeRow
                
                Divider()
                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.15))
                    .padding(.vertical, 12)
                
                languageRow
            }
        }
    }
    
    private var themeRow: some View {
        SettingsButton(action: { isShowingThemeSheet = true }) {
            HStack(spacing: 16) {
                iconView(icon: "paintbrush.pointed.fill", gradient: selectedTheme.colors(for: colorScheme).primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationManager.settingsThemeTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                    
                    HStack(spacing: 8) {
                        Text(selectedTheme.rawValue)
                            .font(.caption)
                            .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                        
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
    }
    
    private var languageRow: some View {
        SettingsButton(action: { isShowingLanguageSheet = true }) {
            HStack(spacing: 16) {
                iconView(icon: "globe", gradient: [.blue, .cyan])
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationManager.settingsLanguageTitle)
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
    
    private func iconView(icon: String, gradient: [Color]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .shadow(color: gradient.first?.opacity(0.4) ?? .gray.opacity(0.4), radius: 8, x: 0, y: 4)
            
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
        }
    }
    
    private var accountSection: some View {
        SettingsSection(title: LocalizationManager.settingsAccountTitle) {
            VStack(spacing: 0) {
                SettingsRow(title: LocalizationManager.settingsProfileTitle, icon: "person.crop.circle.fill", iconGradient: [.green, .mint]) {}
                
                Divider()
                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.15))
                    .padding(.vertical, 12)
                
                SettingsRow(title: LocalizationManager.settingsNotificationsTitle, icon: "bell.fill", iconGradient: [.orange, .yellow]) {}
            }
        }
    }
    
    private var generalSection: some View {
        SettingsSection(title: LocalizationManager.settingsGeneralTitle) {
            VStack(spacing: 0) {
                SettingsRow(title: LocalizationManager.settingsHelpTitle, icon: "questionmark.circle.fill", iconGradient: [.blue, .indigo]) {}
                
                Divider()
                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.15))
                    .padding(.vertical, 12)
                
                SettingsRow(title: LocalizationManager.settingsAboutTitle, icon: "info.circle.fill", iconGradient: [.purple, .pink]) {}
            }
        }
    }
    
    private var logoutSection: some View {
        SettingsSection(title: "") {
            SettingsButton(action: {
                authManager.logout()
                homeManager.clearSelection()
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    
                    Text(LocalizationManager.settingsLogoutButtonTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                    
                    Spacer()
                }
            }
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
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            withAnimation(.spring(response: 0.2)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2)) {
                    isPressed = false
                }
                action()
            }
        } label: {
            content
                .contentShape(Rectangle())
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
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
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        } label: {
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
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    SettingsView()
}