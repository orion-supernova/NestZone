import SwiftUI

struct NoHomesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCreateHome = false
    @State private var showJoinHome = false
    @State private var animateContent = false
    @State private var animateButtons = false
    @EnvironmentObject var viewModel: TabBarScreenViewModel
    @EnvironmentObject var authManager: PocketBaseAuthManager
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                // Main Content
                VStack(spacing: 32) {
                    // Icon with animation
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: selectedTheme.colors(for: colorScheme).primary.map { $0.opacity(0.1) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(animateContent ? 1 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
                        
                        Image(systemName: "house.slash")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: selectedTheme.colors(for: colorScheme).primary,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(animateContent ? 1 : 0.6)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateContent)
                    }
                    
                    // Text Content
                    VStack(spacing: 16) {
                        Text("No Homes Available")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
                        
                        Text("Create your first home or join an existing one to start organizing your shared space")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateContent)
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    PremiumButton(
                        title: "Create New Home",
                        icon: "plus.circle.fill",
                        style: .primary,
                        action: { showCreateHome = true }
                    )
                    .scaleEffect(animateButtons ? 1 : 0.9)
                    .opacity(animateButtons ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateButtons)
                    
                    PremiumButton(
                        title: "Join Existing Home",
                        icon: "person.2.circle.fill",
                        style: .secondary,
                        action: { showJoinHome = true }
                    )
                    .scaleEffect(animateButtons ? 1 : 0.9)
                    .opacity(animateButtons ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: animateButtons)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 32)
            }
        }
        .background(selectedTheme.colors(for: colorScheme).background)
        .onAppear {
            withAnimation {
                animateContent = true
                animateButtons = true
            }
        }
        .sheet(isPresented: $showCreateHome, onDismiss: {
            // Reset state when sheet is dismissed
            showCreateHome = false
            Task {
                try await viewModel.fetchUserHome(authManager: authManager)
            }
        }) {
            CreateHomeView()
        }
        .sheet(isPresented: $showJoinHome, onDismiss: {
            // Reset state when sheet is dismissed
            showJoinHome = false
            Task {
                try await viewModel.fetchUserHome(authManager: authManager)
            }
        }) {
            JoinHomeView()
        }
    }
}

struct PremiumButton: View {
    let title: String
    let icon: String
    let style: ButtonStyle
    let action: () -> Void
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    enum ButtonStyle {
        case primary, secondary
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(style == .primary ? .white : selectedTheme.colors(for: colorScheme).text)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if style == .primary {
                        LinearGradient(
                            colors: selectedTheme.colors(for: colorScheme).primary,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        selectedTheme.colors(for: colorScheme).cardBackground
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: (style == .primary ? selectedTheme.colors(for: colorScheme).primary[0] : Color.black).opacity(0.2),
                radius: isPressed ? 8 : 12,
                y: isPressed ? 4 : 6
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NoHomesView()
}
