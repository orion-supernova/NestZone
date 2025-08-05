import SwiftUI

struct VibrantModuleCard: View {
    let module: ModuleData
    let index: Int
    @Binding var showingShoppingView: Bool
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var iconBounce = false
    
    var moduleGradient: [Color] {
        module.type.colors
    }
    
    var body: some View {
        Button {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
                iconBounce = true
            }
            
            // Navigate to module
            if module.type == .shopping {
                showingShoppingView = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3)) {
                    isPressed = false
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6)) {
                    iconBounce = false
                }
            }
        } label: {
            VStack(spacing: 0) {
                // Header section with icon and count
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: moduleGradient.map { $0.opacity(0.3) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: module.type.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: moduleGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(iconBounce ? 1.3 : 1.0)
                            .animation(.interpolatingSpring(duration: 0.6, bounce: 0.8), value: iconBounce)
                    }
                    
                    Spacer()
                    
                    // Item count badge - only show if count > 0
                    if module.itemCount > 0 {
                        Text("\(module.itemCount)")
                            .font(.system(size: 14, weight: .black))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: moduleGradient,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .foregroundColor(.white)
                            .shadow(color: moduleGradient[0].opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(height: 50)
                
                Spacer(minLength: 20)
                
                // Title and subtitle section
                VStack(alignment: .leading, spacing: 8) {
                    Text(module.type.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [selectedTheme.colors(for: colorScheme).text, moduleGradient[0]],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(module.type.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 20)
            }
            .padding(18)
            .frame(width: (UIScreen.main.bounds.width - 60) / 2, height: 180)
            .contentShape(Rectangle())
        }
        .background(
            ZStack {
                // Background with material
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: moduleGradient.map { $0.opacity(0.08) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                
                // Enhanced border stroke
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        LinearGradient(
                            colors: moduleGradient.map { $0.opacity(0.7) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(
            color: moduleGradient[0].opacity(0.25),
            radius: 12,
            x: 0,
            y: 6
        )
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPressed)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                iconBounce = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    iconBounce = false
                }
            }
        }
    }
}

#Preview {
    @State var showingShoppingView = false
    let sampleModule = ModuleData(
        type: .shopping,
        itemCount: 5,
        recentActivity: "Added milk to groceries",
        progress: 0.65
    )
    
    VibrantModuleCard(
        module: sampleModule,
        index: 0,
        showingShoppingView: $showingShoppingView
    )
    .padding()
}