import SwiftUI

struct LoadingButton: View {
    let title: String
    let icon: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Button(action: {
            guard isEnabled && !isLoading else { return }
            
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
                if isLoading {
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(isLoading ? LocalizationManager.commonLoading : title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: isEnabled ? selectedTheme.colors(for: colorScheme).primary : [selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: isEnabled ? selectedTheme.colors(for: colorScheme).primary[0].opacity(0.3) : .clear,
                radius: isPressed ? 8 : 12,
                y: isPressed ? 4 : 6
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingButton(
            title: "Save Changes",
            icon: "checkmark.circle.fill",
            isLoading: false,
            isEnabled: true,
            action: { print("Button tapped") }
        )
        
        LoadingButton(
            title: "Loading...",
            icon: "arrow.2.circlepath",
            isLoading: true,
            isEnabled: true,
            action: { print("Button tapped") }
        )
        
        LoadingButton(
            title: "Disabled Button",
            icon: "xmark.circle.fill",
            isLoading: false,
            isEnabled: false,
            action: { print("Button tapped") }
        )
    }
    .padding()
}