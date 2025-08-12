import SwiftUI

struct NoHomesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCreateHome = false
    @State private var showJoinHome = false
    @State private var animateContent = false
    @EnvironmentObject var viewModel: TabBarScreenViewModel
    @EnvironmentObject var authManager: PocketBaseAuthManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - Same gradient style as HomeSetupFlow
                LinearGradient(
                    colors: [
                        selectedTheme.colors(for: colorScheme).background,
                        Color.purple.opacity(0.1),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Content - Using WelcomeCard style
                    VStack(spacing: 36) {
                        Text(LocalizationManager.noHomesGetStartedTitle)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
                        
                        VStack(spacing: 20) {
                            WelcomeCard(
                                title: LocalizationManager.homeSetupCreateHomeTitle,
                                subtitle: LocalizationManager.homeSetupCreateHomeSubtitle,
                                icon: "house.circle.fill",
                                gradient: [.purple, .blue],
                                action: { showCreateHome = true }
                            )
                            
                            WelcomeCard(
                                title: LocalizationManager.homeSetupJoinHomeTitle,
                                subtitle: LocalizationManager.homeSetupJoinHomeSubtitle,
                                icon: "person.2.circle.fill",
                                gradient: [.blue, .cyan],
                                action: { showJoinHome = true }
                            )
                        }
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 50)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
        .sheet(isPresented: $showCreateHome, onDismiss: {
            showCreateHome = false
            Task {
                try await viewModel.fetchUserHome(authManager: authManager)
            }
        }) {
            CreateHomeView()
        }
        .sheet(isPresented: $showJoinHome, onDismiss: {
            showJoinHome = false
            Task {
                try await viewModel.fetchUserHome(authManager: authManager)
            }
        }) {
            JoinHomeView()
        }
    }
}

struct WelcomeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3)) {
                    isPressed = false
                }
                action()
            }
        } label: {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial)
                    .shadow(color: gradient[0].opacity(0.2), radius: 12, x: 0, y: 6)
            )
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
    }
}

struct OnboardingHero: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var rotate = false
    
    var body: some View {
        ZStack {
            // Gradient blobs
            Circle()
                .fill(
                    LinearGradient(
                        colors: selectedTheme.colors(for: colorScheme).primary,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .opacity(0.35)
                .offset(x: -70, y: -40)
                .scaleEffect(rotate ? 1.02 : 0.98)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: rotate)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.cyan, Color.blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 210, height: 210)
                .blur(radius: 50)
                .opacity(0.28)
                .offset(x: 60, y: -10)
                .scaleEffect(rotate ? 0.98 : 1.02)
                .animation(.easeInOut(duration: 4).delay(0.6).repeatForever(autoreverses: true), value: rotate)
            
            // Glass card with icon and subtle animated ring
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 200, height: 200)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue, Color.cyan, Color.purple]),
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 16).repeatForever(autoreverses: false), value: rotate)
                    .blur(radius: 0.2)
                    .opacity(0.9)
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: Color.purple.opacity(0.25), radius: 10, x: 0, y: 6)
                    
                    Image(systemName: "house.and.flag.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.top, 8)
        }
        .frame(height: 230)
        .onAppear { rotate = true }
    }
}

#Preview {
    NoHomesView()
}
