import SwiftUI

struct HomeTabScreen: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = HomeTabViewModel()
    
    @State private var animateCards = false
    @State private var animateHeader = false
    @State private var animateStats = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Colorful Header
                ColorfulHeaderView()
                    .environmentObject(viewModel)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .opacity(animateHeader ? 1 : 0)
                    .offset(y: animateHeader ? 0 : -50)
                
                // Rainbow Quick Actions (Navigation only)
                RainbowQuickActionsView()
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .opacity(animateHeader ? 1 : 0)
                    .offset(y: animateHeader ? 0 : 30)
                
                // Vibrant Tasks Section
                VibrantTasksSection()
                    .environmentObject(viewModel)
                    .padding(.top, 40)
                    .opacity(animateCards ? 1 : 0)
                    .offset(x: animateCards ? 0 : 100)
                
                // Colorful Statistics
                ColorfulStatsSection()
                    .environmentObject(viewModel)
                    .padding(.top, 40)
                    .padding(.bottom, 100)
                    .opacity(animateStats ? 1 : 0)
                    .offset(y: animateStats ? 0 : 50)
            }
        }
        .background(
            ZStack {
                // Dynamic rainbow background
                RadialGradient(
                    colors: [
                        selectedTheme.colors(for: colorScheme).background,
                        selectedTheme.colors(for: colorScheme).primaryColor.opacity(0.1),
                        selectedTheme.colors(for: colorScheme).secondaryPrimaryColor.opacity(0.05),
                        Color.purple.opacity(0.03),
                        Color.pink.opacity(0.02)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1000
                )
                
                // Floating colorful shapes
                GeometryReader { geometry in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .offset(x: -60, y: geometry.size.height * 0.2)
                        .blur(radius: 40)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.4), Color.cyan.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .offset(x: geometry.size.width - 20, y: geometry.size.height * 0.4)
                        .blur(radius: 30)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.5), Color.mint.opacity(0.3)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.8)
                        .blur(radius: 25)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.4), Color.yellow.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)
                        .offset(x: geometry.size.width * 0.8, y: geometry.size.height * 0.7)
                        .blur(radius: 35)
                }
            }
        )
        .refreshable {
            await viewModel.refreshData()
        }
        .onAppear {
            startAnimations()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Backend Configuration Needed", isPresented: $viewModel.showingPermissionsError) {
            Button("OK") {
                viewModel.showingPermissionsError = false
                viewModel.errorMessage = nil
            }
        } message: {
            Text("PocketBase permissions need to be configured to allow authenticated users to access tasks. Using mock data for now.")
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 1.0)) {
            animateHeader = true
        }
        
        withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
            animateCards = true
        }
        
        withAnimation(.easeOut(duration: 1.0).delay(0.6)) {
            animateStats = true
        }
    }
}

struct ColorfulHeaderView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @EnvironmentObject private var viewModel: HomeTabViewModel
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 32) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizationManager.text(.hello(name: authManager.currentUser?.name ?? "User")))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    selectedTheme.colors(for: colorScheme).text,
                                    selectedTheme.colors(for: colorScheme).primaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Ready to conquer today's tasks? 🚀")
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
                
                // Colorful Profile Avatar
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                center: .center
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Circle()
                        .fill(selectedTheme.colors(for: colorScheme).background)
                        .frame(width: 48, height: 48)
                    
                    if let name = authManager.currentUser?.name, let firstChar = name.first {
                        Text(String(firstChar).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        Text("?")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    // Pulsing notification dot
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.red, .pink],
                                center: .center,
                                startRadius: 0,
                                endRadius: 6
                            )
                        )
                        .frame(width: 12, height: 12)
                        .offset(x: 20, y: -20)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                }
            }
            
            // Rainbow Progress Overview
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today's Progress")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("\(Int(viewModel.todayProgress * 100))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Spacer()
                    
                    // Rainbow Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .trim(from: 0, to: viewModel.todayProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 1.5, dampingFraction: 0.8), value: viewModel.todayProgress)
                    }
                }
                
                // Task Summary Cards
                HStack(spacing: 12) {
                    MiniStatCard(
                        title: "Active",
                        count: "\(viewModel.tasks.filter { !$0.isCompleted }.count)",
                        gradient: [.orange, .red]
                    )
                    
                    MiniStatCard(
                        title: "Done",
                        count: "\(viewModel.tasks.filter { $0.isCompleted }.count)",
                        gradient: [.green, .mint]
                    )
                    
                    MiniStatCard(
                        title: "Total",
                        count: "\(viewModel.tasks.count)",
                        gradient: [.blue, .purple]
                    )
                }
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(selectedTheme.colors(for: colorScheme).glassMaterial)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.5),
                                    Color.pink.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

struct MiniStatCard: View {
    let title: String
    let count: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(gradient[0].opacity(0.1))
        )
    }
}

struct RainbowQuickActionsView: View {
    let actions = [
        ("list.bullet.clipboard.fill", "Lists", [Color.green, Color.mint]),
        ("message.fill", "Messages", [Color.blue, Color.cyan]),
        ("bell.fill", "Alerts", [Color.orange, Color.yellow])
    ]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                RainbowActionButton(
                    icon: action.0,
                    title: action.1,
                    gradient: action.2,
                    delay: Double(index) * 0.1,
                    action: {
                        // Navigation actions can be added here if needed
                        // For now, these are just visual elements
                    }
                )
            }
        }
    }
}

struct RainbowActionButton: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let delay: Double
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient + [gradient[0].opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(delay), value: isAnimating)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: gradient.map { $0.opacity(0.5) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3)) {
                    isPressed = false
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                isAnimating = true
            }
        }
    }
}

struct VibrantTasksSection: View {
    @EnvironmentObject private var viewModel: HomeTabViewModel
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(LocalizationManager.text(.todaysTasks))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                Text("\(viewModel.tasks.count) tasks")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(.horizontal, 24)
            
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        ShimmerTaskCard()
                    }
                }
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModel.tasks.enumerated()), id: \.element.id) { index, task in
                        VibrantTaskCard(task: task, index: index)
                            .environmentObject(viewModel)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct VibrantTaskCard: View {
    let task: PocketBaseTask
    let index: Int
    @EnvironmentObject private var viewModel: HomeTabViewModel
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var showingCompletion = false
    
    var taskGradient: [Color] {
        viewModel.getTaskTypeColor(task.type)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    // Animated Task Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: taskGradient.map { $0.opacity(0.2) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: viewModel.getTaskIcon(task.type))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: taskGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(showingCompletion ? 1.3 : 1.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showingCompletion)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [selectedTheme.colors(for: colorScheme).text, taskGradient[0]],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .strikethrough(task.isCompleted)
                        
                        Text(LocalizationManager.text(.assigned(name: viewModel.getUserName(for: task.assignedTo))))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.gray, taskGradient[1]],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        // Animated Priority Indicator
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [viewModel.getPriorityColor(task.priority), viewModel.getPriorityColor(task.priority).opacity(0.5)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 4
                                )
                            )
                            .frame(width: 10, height: 10)
                            .scaleEffect(1.5)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(index) * 0.2), value: true)
                        
                        Text(viewModel.getTimeLeftText(task))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.gray, viewModel.getPriorityColor(task.priority)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Rainbow Progress Bar
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.gray, taskGradient[0]],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.getTaskProgress(task) * 100))%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: taskGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: task.isCompleted ? 
                                            [Color.green, Color.mint] : 
                                            taskGradient + [taskGradient[1].opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * viewModel.getTaskProgress(task), height: 8)
                                .animation(.spring(response: 1.2, dampingFraction: 0.8), value: viewModel.getTaskProgress(task))
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(22)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        LinearGradient(
                            colors: taskGradient.map { $0.opacity(0.4) } + [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
        )
        .shadow(
            color: taskGradient[0].opacity(0.2),
            radius: 15,
            x: 0,
            y: 8
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPressed)
        .onTapGesture {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
                showingCompletion = true
            }
            
            Task {
                await viewModel.toggleTaskCompletion(task)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3)) {
                    isPressed = false
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6)) {
                    showingCompletion = false
                }
            }
        }
    }
}

struct ShimmerTaskCard: View {
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                        .frame(maxWidth: 120)
                }
                
                Spacer()
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 8)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: shimmerOffset)
                .clipped()
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }
}

struct ColorfulStatsSection: View {
    @EnvironmentObject private var viewModel: HomeTabViewModel
    
    let statConfigs = [
        ("message.fill", "Messages", [Color.blue, Color.cyan]),
        ("list.bullet.clipboard.fill", "Shopping", [Color.green, Color.mint]),
        ("exclamationmark.triangle.fill", "Issues", [Color.red, Color.pink]),
        ("note.text", "Notes", [Color.orange, Color.yellow])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(LocalizationManager.text(.statistics))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal, 24)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                ForEach(Array(statConfigs.enumerated()), id: \.offset) { index, config in
                    ColorfulStatCard(
                        icon: config.0,
                        title: config.1,
                        count: getStatCount(for: index),
                        change: getStatChange(for: index),
                        gradient: config.2,
                        index: index
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func getStatCount(for index: Int) -> String {
        switch index {
        case 0: return "\(viewModel.messageCount)"
        case 1: return "\(viewModel.shoppingListCount)"
        case 2: return "\(viewModel.issueCount)"
        case 3: return "\(viewModel.noteCount)"
        default: return "0"
        }
    }
    
    private func getStatChange(for index: Int) -> String {
        let change: Int
        switch index {
        case 0: change = viewModel.messageChange
        case 1: change = viewModel.shoppingChange
        case 2: change = viewModel.issueChange
        case 3: change = viewModel.noteChange
        default: change = 0
        }
        
        return change >= 0 ? "+\(change)" : "\(change)"
    }
}

struct ColorfulStatCard: View {
    let icon: String
    let title: String
    let count: String
    let change: String
    let gradient: [Color]
    let index: Int
    
    @State private var isPressed = false
    @State private var animate = false
    @State private var iconBounce = false
    
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(iconBounce ? 1.2 : 1.0)
                        .animation(.interpolatingSpring(duration: 0.6, bounce: 0.7).delay(Double(index) * 0.1), value: iconBounce)
                }
                
                Spacer()
                
                // Animated Change Indicator
                Text(change)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: change.hasPrefix("+") ? 
                                        [Color.green.opacity(0.2), Color.mint.opacity(0.3)] :
                                        [Color.red.opacity(0.2), Color.pink.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: change.hasPrefix("+") ? [.green, .mint] : [.red, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(animate ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double(index) * 0.3), value: animate)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(count)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animate ? 1.05 : 1.0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animate)
                    
                    Spacer()
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.gray, gradient[0]],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.4) } + [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
        )
        .shadow(
            color: gradient[0].opacity(0.15),
            radius: 12,
            x: 0,
            y: 6
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPressed)
        .onTapGesture {
            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
            
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
                iconBounce = true
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
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                animate = true
                iconBounce = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    iconBounce = false
                }
            }
        }
    }
}

#Preview {
    HomeTabScreen()
        .environmentObject(PocketBaseAuthManager())
}