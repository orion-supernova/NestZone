import SwiftUI

struct ListView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var listViewModel = ListTabViewModel()
    
    @State private var animateCards = false
    @State private var animateHeader = false
    @State private var showingShoppingView = false
    
    // Dynamic modules data based on real data
    var modules: [ModuleData] {
        [
            ModuleData(
                type: .shopping, 
                itemCount: listViewModel.totalItems, 
                recentActivity: "Added milk to groceries", 
                progress: 0.65
            ),
            ModuleData(type: .recipes, itemCount: 0, recentActivity: "Coming soon", progress: 0.0),
            ModuleData(type: .maintenance, itemCount: 0, recentActivity: "Coming soon", progress: 0.0),
            ModuleData(type: .finance, itemCount: 0, recentActivity: "Coming soon", progress: 0.0),
            ModuleData(type: .notes, itemCount: 0, recentActivity: "Coming soon", progress: 0.0),
            ModuleData(type: .calendar, itemCount: 0, recentActivity: "Coming soon", progress: 0.0)
        ]
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Colorful Header
                ModuleHubHeaderView()
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .opacity(animateHeader ? 1 : 0)
                    .offset(y: animateHeader ? 0 : -50)
                
                // Module Cards Grid (directly without wrapper)
                ModuleCardsSection(modules: modules, showingShoppingView: $showingShoppingView)
                    .padding(.top, 40)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 100)
            }
        }
        .background(
            ZStack {
                // Dynamic rainbow background
                RadialGradient(
                    colors: [
                        selectedTheme.colors(for: colorScheme).background,
                        Color.purple.opacity(0.08),
                        Color.blue.opacity(0.05),
                        Color.green.opacity(0.03),
                        Color.orange.opacity(0.02)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
                
                // Floating colorful shapes
                GeometryReader { geometry in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.4), Color.pink.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .offset(x: -50, y: geometry.size.height * 0.2)
                        .blur(radius: 35)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .offset(x: geometry.size.width - 10, y: geometry.size.height * 0.5)
                        .blur(radius: 30)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.4), Color.mint.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.8)
                        .blur(radius: 25)
                }
            }
        )
        .onAppear {
            startAnimations()
        }
        .fullScreenCover(isPresented: $showingShoppingView) {
            ShoppingListView()
                .environmentObject(listViewModel)
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 1.0)) {
            animateHeader = true
        }
        
        withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
            animateCards = true
        }
    }
}

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

struct MiniModuleCard: View {
    let title: String
    let count: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(gradient[0].opacity(0.1))
        )
    }
}

struct ModuleCardsSection: View {
    let modules: [ModuleData]
    @Binding var showingShoppingView: Bool
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 20) {
            ForEach(Array(modules.enumerated()), id: \.element.type.id) { index, module in
                VibrantModuleCard(module: module, index: index, showingShoppingView: $showingShoppingView)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
}

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
    ListView()
        .environmentObject(PocketBaseAuthManager())
}