import SwiftUI

struct AuthenticationScreen: View {
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = AuthenticationViewModel()
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var animateHeader = false
    @State private var animateContent = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var lastDragValue: DragGesture.Value?
    
    private var theme: ThemeColors {
        selectedTheme.colors(for: colorScheme)
    }
    
    // Password validation computed properties
    private var passwordValidationState: ValidationState {
        if password.isEmpty {
            return .neutral
        }
        return password.count >= 8 ? .valid : .invalid
    }
    
    private var passwordValidationMessage: String {
        if password.isEmpty {
            return ""
        }
        return password.count >= 8 ? LocalizationManager.authPasswordValid : LocalizationManager.authPasswordTooShort
    }
    
    private var confirmPasswordValidationState: ValidationState {
        if confirmPassword.isEmpty {
            return .neutral
        }
        if password.isEmpty {
            return .invalid
        }
        return password == confirmPassword ? .valid : .invalid
    }
    
    private var confirmPasswordValidationMessage: String {
        if confirmPassword.isEmpty {
            return ""
        }
        if password.isEmpty {
            return LocalizationManager.authConfirmPasswordEmpty
        }
        return password == confirmPassword ? LocalizationManager.authPasswordsMatch : LocalizationManager.authPasswordsMismatch
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .opacity(animateHeader ? 1 : 0)
                        .offset(y: animateHeader ? 0 : -40)
                    
                    modeToggle
                        .padding(.horizontal, 24)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                    
                    formFields
                        .padding(.horizontal, 24)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 30)
                    
                    submitButton
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 40)
                    
                    Spacer(minLength: keyboardHeight > 0 ? 180 : 60)
                }
                .padding(.bottom, keyboardHeight > 0 ? 80 : 0)
            }
            .background(background)
            .navigationTitle(isLoginMode ? LocalizationManager.authSignInTitle : LocalizationManager.authCreateAccountTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                hideKeyboard()
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        // Only dismiss keyboard when scrolling down (positive translation.height)
                        if let lastValue = lastDragValue {
                            let deltaY = value.translation.height - lastValue.translation.height
                            if deltaY > 0 && abs(deltaY) > 10 { // Scrolling down with some threshold
                                hideKeyboard()
                            }
                        }
                        lastDragValue = value
                    }
                    .onEnded { _ in
                        lastDragValue = nil
                    }
            )
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: keyboardHeight > 0 ? 40 : 0)
                    .animation(.easeInOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .onAppear {
            setupKeyboardObservers()
            withAnimation(.easeOut(duration: 0.8)) {
                animateHeader = true
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateContent = true
            }
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .alert(LocalizationManager.commonErrorTitle, isPresented: .constant(viewModel.errorMessage != nil)) {
            Button(LocalizationManager.commonOkButton) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private var background: some View {
        ZStack {
            RadialGradient(
                colors: [
                    theme.background,
                    theme.primaryColor.opacity(0.06),
                    theme.secondaryPrimaryColor.opacity(0.04)
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 1200
            )
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [theme.secondary[0].opacity(0.25), theme.secondary[0].opacity(0.05)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .offset(x: -40, y: geo.size.height * 0.2)
                    .blur(radius: 25)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [theme.primaryColor.opacity(0.25), theme.primaryColor.opacity(0.05)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .offset(x: geo.size.width - 60, y: geo.size.height * 0.6)
                    .blur(radius: 30)
            }
        }
        .ignoresSafeArea()
    }
    
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.authWelcomeTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.text, theme.primaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(isLoginMode ? LocalizationManager.authSignInSubtitle : LocalizationManager.authCreateAccountSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.secondaryPrimaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.purple, .pink, .orange, .yellow, .green, .cyan, .blue, .purple],
                            center: .center
                        )
                    )
                    .frame(width: 52, height: 52)
                Circle()
                    .fill(theme.background)
                    .frame(width: 48, height: 48)
                Image(systemName: "house.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.secondaryPrimaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
    
    private var modeToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    isLoginMode = true
                }
            } label: {
                Text(LocalizationManager.authLoginButton)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isLoginMode ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                isLoginMode ?
                                LinearGradient(
                                    colors: [theme.primaryColor, theme.secondaryPrimaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                            )
                    )
            }
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    isLoginMode = false
                }
            } label: {
                Text(LocalizationManager.authSignUpButton)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(!isLoginMode ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                !isLoginMode ?
                                LinearGradient(
                                    colors: [theme.primaryColor, theme.secondaryPrimaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                            )
                    )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
        )
    }
    
    private var formFields: some View {
        VStack(spacing: 16) {
            if !isLoginMode {
                PremiumTextField(
                    title: LocalizationManager.authFullNameLabel,
                    placeholder: LocalizationManager.authFullNamePlaceholder,
                    text: $fullName,
                    icon: "person.fill",
                    isRequired: true
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            
            PremiumTextField(
                title: LocalizationManager.authEmailLabel,
                placeholder: LocalizationManager.authEmailPlaceholder,
                text: $email,
                icon: "envelope.fill",
                isRequired: true,
                isSecure: false,
                keyboardType: .emailAddress
            )
            
            PremiumTextField(
                title: LocalizationManager.authPasswordLabel,
                placeholder: LocalizationManager.authPasswordPlaceholder,
                text: $password,
                icon: "lock.fill",
                isRequired: true,
                isSecure: true,
                validationState: isLoginMode ? .neutral : passwordValidationState,
                validationMessage: isLoginMode ? "" : passwordValidationMessage
            )
            
            if !isLoginMode {
                PremiumTextField(
                    title: LocalizationManager.authConfirmPasswordLabel,
                    placeholder: LocalizationManager.authConfirmPasswordPlaceholder,
                    text: $confirmPassword,
                    icon: "lock.fill",
                    isRequired: true,
                    isSecure: true,
                    validationState: confirmPasswordValidationState,
                    validationMessage: confirmPasswordValidationMessage
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }
    
    private var submitButton: some View {
        LoadingButton(
            title: isLoginMode ? LocalizationManager.authLoginButton : LocalizationManager.authCreateAccountButton,
            icon: isLoginMode ? "arrow.right" : "sparkles",
            isLoading: viewModel.isLoading,
            isEnabled: isFormValid
        ) {
            Task {
                if isLoginMode {
                    await viewModel.login(authManager: authManager, email: email, password: password)
                } else {
                    await viewModel.register(
                        authManager: authManager,
                        email: email,
                        password: password,
                        fullName: fullName
                    )
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty &&
                   !password.isEmpty &&
                   !fullName.isEmpty &&
                   password == confirmPassword &&
                   password.count >= 8 &&
                   email.contains("@")
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeInOut(duration: 0.25)) {
                    keyboardHeight = frame.height
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

#Preview {
    AuthenticationScreen()
        .environmentObject(PocketBaseAuthManager())
}