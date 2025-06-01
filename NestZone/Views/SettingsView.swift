import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingThemeSheet = false
    @State private var isShowingLanguageSheet = false
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section(LocalizationManager.text(.appearance)) {
                    Button(action: { isShowingThemeSheet = true }) {
                        HStack {
                            Label(LocalizationManager.text(.theme), systemImage: "paintbrush.fill")
                            Spacer()
                            Text(selectedTheme.rawValue)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).text)

                    Button(action: { isShowingLanguageSheet = true }) {
                        HStack {
                            Label(LocalizationManager.text(.language), systemImage: "globe")
                            Spacer()
                            Text(localizationManager.currentLanguage.displayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                }

                // Account Section
                Section(LocalizationManager.text(.account)) {
                    NavigationLink {
                        Text("Profil Detayları")
                    } label: {
                        Label(LocalizationManager.text(.profile), systemImage: "person.fill")
                    }

                    NavigationLink {
                        Text("Bildirim Ayarları")
                    } label: {
                        Label(LocalizationManager.text(.notifications), systemImage: "bell.fill")
                    }
                }

                // General Section
                Section(LocalizationManager.text(.general)) {
                    NavigationLink {
                        Text("Yardım Merkezi")
                    } label: {
                        Label(LocalizationManager.text(.help), systemImage: "questionmark.circle.fill")
                    }

                    NavigationLink {
                        Text("Hakkında")
                    } label: {
                        Label(LocalizationManager.text(.about), systemImage: "info.circle.fill")
                    }
                }

                // Danger Zone
                Section {
                    Button(action: {}) {
                        HStack {
                            Label(LocalizationManager.text(.logout), 
                                  systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle(LocalizationManager.text(.settingsTitle))
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
