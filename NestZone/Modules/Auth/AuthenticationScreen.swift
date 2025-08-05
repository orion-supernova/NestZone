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
    @State private var animateContent = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.purple.opacity(0.8),
                        Color.blue.opacity(0.6),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Animated floating shapes
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.4), Color.purple.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .offset(x: -100, y: animateContent ? -50 : -80)
                        .blur(radius: 60)
                        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: animateContent)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 150, height: 150)
                        .offset(x: geo.size.width - 50, y: animateContent ? geo.size.height - 100 : geo.size.height - 150)
                        .blur(radius: 40)
                        .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: animateContent)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.pink.opacity(0.3), Color.pink.opacity(0.05)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .offset(x: geo.size.width * 0.8, y: animateContent ? 100 : 150)
                        .blur(radius: 30)
                        .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: animateContent)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: geometry.safeAreaInsets.top + 40)
                        
                        // Header Section
                        VStack(spacing: 32) {
                            // App Logo
                            VStack(spacing: 20) {
                                ZStack {
                                    // Glow effect
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(
                                            RadialGradient(
                                                colors: [Color.white.opacity(0.3), Color.clear],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 50
                                            )
                                        )
                                        .frame(width: 90, height: 90)
                                        .blur(radius: 10)
                                    
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.purple,
                                                    Color.blue,
                                                    Color.cyan
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 80, height: 80)
                                        .shadow(color: Color.purple.opacity(0.5), radius: 25, x: 0, y: 15)
                                    
                                    Image(systemName: "house.fill")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(animateContent ? 1 : 0.8)
                                .rotationEffect(.degrees(animateContent ? 0 : -10))
                                .animation(.spring(response: 1.2, dampingFraction: 0.6).delay(0.2), value: animateContent)
                                
                                // App Name
                                VStack(spacing: 12) {
                                    Text("NestZone")
                                        .font(.system(size: 42, weight: .black, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.white, Color.cyan.opacity(0.9)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    Text("Your smart household companion")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                                }
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 30)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: animateContent)
                            }
                        }
                        
                        Spacer(minLength: 50)
                        
                        // Auth Form Container
                        VStack(spacing: 32) {
                            // Mode Toggle
                            HStack(spacing: 0) {
                                ForEach([true, false], id: \.self) { isLogin in
                                    Button {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            isLoginMode = isLogin
                                        }
                                    } label: {
                                        Text(isLogin ? "Login" : "Sign Up")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(isLoginMode == isLogin ? .white : .white.opacity(0.6))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(
                                                        isLoginMode == isLogin 
                                                        ? LinearGradient(
                                                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                        : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                                                    )
                                            )
                                    }
                                }
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                            )
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: animateContent)
                            
                            // Form Fields
                            VStack(spacing: 20) {
                                if !isLoginMode {
                                    ModernTextField(
                                        title: "Full Name",
                                        placeholder: "Enter your full name",
                                        text: $fullName,
                                        icon: "person.fill"
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                                
                                ModernTextField(
                                    title: "Email",
                                    placeholder: "Enter your email",
                                    text: $email,
                                    icon: "envelope.fill",
                                    keyboardType: .emailAddress
                                )
                                
                                ModernTextField(
                                    title: "Password",
                                    placeholder: "Enter your password",
                                    text: $password,
                                    icon: "lock.fill",
                                    isSecure: true
                                )
                                
                                if !isLoginMode {
                                    ModernTextField(
                                        title: "Confirm Password",
                                        placeholder: "Confirm your password",
                                        text: $confirmPassword,
                                        icon: "lock.fill",
                                        isSecure: true
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                            }
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 30)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: animateContent)
                            
                            // Submit Button
                            ModernActionButton(
                                title: isLoginMode ? "Login" : "Create Account",
                                icon: isLoginMode ? "arrow.right.circle.fill" : "person.badge.plus.fill",
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
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 40)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.0), value: animateContent)
                        }
                        .padding(.horizontal, 28)
                        
                        Spacer(minLength: 60)
                    }
                }
            }
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
}

struct ModernTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    @State private var isFocused = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 22)
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
    }
}

struct ModernActionButton: View {
    let title: String
    let icon: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isPressed = false
                }
                action()
            }
        } label: {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.1)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    if isEnabled {
                        // Glow effect
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                RadialGradient(
                                    colors: [Color.purple.opacity(0.6), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                            .blur(radius: 20)
                        
                        // Main gradient
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.gray.opacity(0.3))
                    }
                }
            )
            .shadow(
                color: isEnabled ? Color.purple.opacity(0.4) : Color.clear,
                radius: isPressed ? 8 : 20,
                x: 0,
                y: isPressed ? 4 : 10
            )
        }
        .disabled(!isEnabled || isLoading)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
    }
}

#Preview {
    AuthenticationScreen()
        .environmentObject(PocketBaseAuthManager())
}