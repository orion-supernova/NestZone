import SwiftUI

struct CreateHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: ConvexAuthManager
    @StateObject private var viewModel = HomeManagementViewModel()
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var homeName = ""
    @State private var homeAddress = ""
    @State private var showSuccess = false
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isAddressFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: selectedTheme.colors(for: colorScheme).primary.map { $0.opacity(0.1) },
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "house.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: selectedTheme.colors(for: colorScheme).primary,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                            }
                            .appear(step: 0)

                            VStack(spacing: 8) {
                                Text("Create New Home")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                                
                                Text(LocalizationManager.createHomeSubtitle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                            }
                            .appear(step: 1)
                        }
                        .padding(.top, 24)
                        
                        // Form Fields
                        VStack(spacing: 24) {
                            PremiumTextField(
                                title: LocalizationManager.createHomeNameLabel,
                                placeholder: LocalizationManager.createHomeNamePlaceholder,
                                text: $homeName,
                                icon: "house.fill",
                                isRequired: true
                            )
                            .autocorrectionDisabled()
                            .focused($isNameFieldFocused)
                            .appear(step: 2)
                            
                            PremiumTextField(
                                title: LocalizationManager.createHomeAddressLabel,
                                placeholder: LocalizationManager.createHomeAddressPlaceholder,
                                text: $homeAddress,
                                icon: "location.fill",
                                isRequired: false
                            )
                            .autocorrectionDisabled()
                            .focused($isAddressFieldFocused)
                            .appear(step: 3)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 32)
                        
                        // Create Button
                        VStack(spacing: 16) {
                            LoadingButton(
                                title: LocalizationManager.createHomeButton,
                                icon: "plus.circle.fill",
                                isLoading: viewModel.isLoading,
                                isEnabled: !homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ) {
                                Task {
                                    await viewModel.createHome(
                                        name: homeName,
                                        address: homeAddress.isEmpty ? nil : homeAddress,
                                        authManager: authManager
                                    )
                                }
                            }
                            .appear(step: 4)
                            .buttonStyle(.pressable)
                            .shake(trigger: viewModel.errorShakeCount)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                    }
                }
            }
            .background(selectedTheme.colors(for: colorScheme).background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizationManager.commonCancel) {
                        dismiss()
                    }
                    .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                isNameFieldFocused = true
            }
        }
        .onChange(of: viewModel.homeCreated) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
        .overlay(
            SuccessOverlay(show: $showSuccess, message: LocalizationManager.createHomeSuccessMessage)
        )
        .overlay(
            ErrorOverlay(show: $viewModel.showError, message: viewModel.errorMessage ?? "")
        )
    }
}

#Preview {
    CreateHomeView()
        .environmentObject(ConvexAuthManager())
}