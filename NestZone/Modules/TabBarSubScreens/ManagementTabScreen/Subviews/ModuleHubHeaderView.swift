import SwiftUI

struct ModuleHubHeaderView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 32) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Management Hub 🏠")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    selectedTheme.colors(for: colorScheme).text,
                                    Color.purple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Manage everything in one place! ✨")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
                
                // Animated hub icon
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.purple, .pink, .red, .orange, .yellow, .green, .cyan, .blue, .purple],
                                center: .center
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Circle()
                        .fill(selectedTheme.colors(for: colorScheme).background)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                }
            }
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

#Preview {
    ModuleHubHeaderView()
        .environmentObject(PocketBaseAuthManager())
        .padding()
}