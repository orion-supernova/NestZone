import SwiftUI

struct JoinHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = HomeManagementViewModel()
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var inviteCode = ""
    @State private var animateFields = false
    @State private var showSuccess = false
    @FocusState private var isCodeFieldFocused: Bool
    
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
                                    .scaleEffect(animateFields ? 1 : 0.8)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateFields)
                                
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: selectedTheme.colors(for: colorScheme).primary,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .scaleEffect(animateFields ? 1 : 0.6)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateFields)
                            }
                            
                            VStack(spacing: 8) {
                                Text(LocalizationManager.homeSetupJoinHomeTitle)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                                
                                Text(LocalizationManager.homeSetupJoinHomeSubtitle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .opacity(animateFields ? 1 : 0)
                            .offset(y: animateFields ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateFields)
                        }
                        .padding(.top, 24)
                        .padding(.horizontal, 24)
                        
                        // Form Field
                        VStack(spacing: 24) {
                            PremiumTextField(
                                title: LocalizationManager.joinHomeInviteCodeLabel,
                                placeholder: LocalizationManager.joinHomeInviteCodePlaceholder,
                                text: $inviteCode,
                                icon: "key.fill",
                                isRequired: true
                            )
                            .autocorrectionDisabled()
                            .focused($isCodeFieldFocused)
                            .opacity(animateFields ? 1 : 0)
                            .offset(x: animateFields ? 0 : -20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateFields)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 32)
                        
                        // Join Button
                        VStack(spacing: 16) {
                            LoadingButton(
                                title: LocalizationManager.joinHomeButton,
                                icon: "person.2.circle.fill",
                                isLoading: viewModel.isLoading,
                                isEnabled: !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ) {
                                Task {
                                    await viewModel.joinHome(
                                        inviteCode: inviteCode,
                                        authManager: authManager
                                    )
                                }
                            }
                            .opacity(animateFields ? 1 : 0)
                            .offset(y: animateFields ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateFields)
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
            withAnimation {
                animateFields = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCodeFieldFocused = true
            }
        }
        .onChange(of: viewModel.homeJoined) { _, newValue in
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
            SuccessOverlay(show: $showSuccess, message: LocalizationManager.joinHomeSuccessMessage)
        )
        .overlay(
            ErrorOverlay(show: $viewModel.showError, message: viewModel.errorMessage ?? "")
        )
    }
}

#Preview {
    JoinHomeView()
        .environmentObject(PocketBaseAuthManager())
}