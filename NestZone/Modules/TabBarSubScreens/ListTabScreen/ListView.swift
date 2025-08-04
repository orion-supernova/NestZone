import SwiftUI

struct ListView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    
    @State private var animateCards = false
    @State private var animateHeader = false
    @State private var showingShoppingView = false
    
    // Mock data for demonstration
    @State private var modules: [ModuleData] = [
        ModuleData(type: .shopping, itemCount: 12, recentActivity: "Added milk to groceries", progress: 0.65),
        ModuleData(type: .recipes, itemCount: 8, recentActivity: "Saved pasta recipe", progress: 0.80),
        ModuleData(type: .maintenance, itemCount: 3, recentActivity: "Fixed kitchen sink", progress: 0.33),
        ModuleData(type: .finance, itemCount: 5, recentActivity: "Split electricity bill", progress: 0.40),
        ModuleData(type: .notes, itemCount: 15, recentActivity: "Added shopping reminder", progress: 0.90),
        ModuleData(type: .calendar, itemCount: 4, recentActivity: "House party scheduled", progress: 0.25)
    ]
    
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
                // Header section - Fixed height
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
                    
                    if module.type.comingSoon {
                        Text("Soon")
                            .font(.system(size: 11, weight: .black))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange, Color.red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .foregroundColor(.white)
                            .shadow(color: Color.orange.opacity(0.4), radius: 4, x: 0, y: 2)
                    } else {
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
                .frame(height: 50) // Fixed header height
                
                Spacer(minLength: 16) // Flexible spacer
                
                // Title section - Fixed height
                VStack(alignment: .leading, spacing: 6) {
                    Text(module.type.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [selectedTheme.colors(for: colorScheme).text, moduleGradient[0]],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(module.type.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(height: 50) // Fixed title section height
                
                Spacer(minLength: 16) // Flexible spacer
                
                // Bottom section - Fixed height
                if !module.type.comingSoon {
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(Int(module.progress * 100))%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: moduleGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Spacer()
                            
                            Text("Complete")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            GeometryReader { geometry in
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: moduleGradient + [moduleGradient[1].opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * module.progress, height: 6)
                                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: module.progress)
                            }
                            .frame(height: 6)
                        }
                    }
                    .frame(height: 40) // Fixed bottom section height
                } else {
                    VStack(spacing: 6) {
                        Text("Coming Soon")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Stay tuned!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 40) // Fixed bottom section height - same as progress section
                }
            }
            .padding(20)
            .frame(width: (UIScreen.main.bounds.width - 60) / 2, height: 200) // Fixed card dimensions
            .contentShape(Rectangle()) // Make entire area tappable
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: moduleGradient.map { $0.opacity(0.05) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: moduleGradient.map { $0.opacity(0.6) } + [Color.clear, Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
        )
        .shadow(
            color: moduleGradient[0].opacity(0.2),
            radius: 15,
            x: 0,
            y: 8
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

// Create the dedicated ShoppingListView
struct ShoppingListView: View {
    @StateObject private var viewModel = ListTabViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingNewItemSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Shopping Header
                    ShoppingHeaderView()
                        .environmentObject(viewModel)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    
                    // Shopping Categories
                    ShoppingCategoriesSection()
                        .environmentObject(viewModel)
                        .padding(.top, 32)
                }
            }
            .background(
                RadialGradient(
                    colors: [
                        Color(.systemGray6),
                        Color.green.opacity(0.08),
                        Color.blue.opacity(0.05)
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 1200
                )
            )
            .navigationTitle("Shopping Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewItemSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .sheet(isPresented: $showingNewItemSheet) {
                RainbowNewItemSheet()
                    .environmentObject(viewModel)
            }
        }
    }
}

struct ShoppingHeaderView: View {
    @EnvironmentObject private var viewModel: ListTabViewModel
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shopping Lists 🛒")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.primary, Color.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Let's get everything you need! ✨")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
            }
            
            // Statistics
            HStack(spacing: 12) {
                MiniShoppingCard(
                    title: "Total",
                    count: "\(viewModel.totalItems)",
                    gradient: [.blue, .purple]
                )
                
                MiniShoppingCard(
                    title: "Done",
                    count: "\(viewModel.completedItems)",
                    gradient: [.green, .mint]
                )
                
                MiniShoppingCard(
                    title: "Left",
                    count: "\(viewModel.pendingItems)",
                    gradient: [.orange, .red]
                )
            }
        }
    }
}

struct ShoppingCategoriesSection: View {
    @EnvironmentObject private var viewModel: ListTabViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Shopping Categories")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        ShimmerCategoryCard()
                    }
                }
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(ShoppingItem.ShoppingCategory.allCases, id: \.self) { category in
                        if let items = viewModel.categories[category], !items.isEmpty {
                            VibrantCategoryCard(category: category, items: items, index: ShoppingItem.ShoppingCategory.allCases.firstIndex(of: category) ?? 0)
                                .environmentObject(viewModel)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct MiniShoppingCard: View {
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

struct ShimmerCategoryCard: View {
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 18)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 14)
                        .frame(maxWidth: 150)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

struct VibrantCategoryCard: View {
    let category: ShoppingItem.ShoppingCategory
    let items: [ShoppingItem]
    let index: Int
    @EnvironmentObject private var viewModel: ListTabViewModel
    @State private var isPressed = false
    @State private var isExpanded = false
    
    var categoryGradient: [Color] {
        viewModel.getCategoryColor(category)
    }
    
    var completedCount: Int {
        items.filter { $0.isPurchased }.count
    }
    
    var progress: Double {
        guard !items.isEmpty else { return 0.0 }
        return Double(completedCount) / Double(items.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Header
            Button {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    // Category Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: categoryGradient.map { $0.opacity(0.2) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: viewModel.getCategoryIcon(category))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: categoryGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.getCategoryName(category))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(completedCount) of \(items.count) completed")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(20)
            }
            .buttonStyle(.plain)
            
            // Expanded Items List
            if isExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { itemIndex, item in
                        VibrantShoppingItem(item: item, gradient: categoryGradient, index: itemIndex)
                            .environmentObject(viewModel)
                        
                        if itemIndex < items.count - 1 {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPressed)
    }
}

struct VibrantShoppingItem: View {
    let item: ShoppingItem
    let gradient: [Color]
    let index: Int
    @EnvironmentObject private var viewModel: ListTabViewModel
    @State private var isPressed = false
    @State private var showingDeleteAlert = false
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Completion Button
            Button {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                
                Task {
                    await viewModel.toggleItemCompletion(item)
                }
            } label: {
                ZStack {
                    if item.isPurchased {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 28, height: 28)
                    }
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: item.isPurchased ? gradient : [Color.gray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)
                    
                    if item.isPurchased {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .strikethrough(item.isPurchased)
                    .opacity(item.isPurchased ? 0.7 : 1.0)
                
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if let quantity = item.quantity, quantity > 1 {
                Text("×\(Int(quantity))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(gradient[0].opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .offset(x: offset)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        offset = max(value.translation.width, -80)
                    }
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        if value.translation.width < -50 {
                            showingDeleteAlert = true
                        }
                        offset = 0
                    }
                }
        )
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteItem(item)
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(item.name)'?")
        }
    }
}

// Create the dedicated RainbowNewItemSheet
struct RainbowNewItemSheet: View {
    @EnvironmentObject private var viewModel: ListTabViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemName = ""
    @State private var itemDescription = ""
    @State private var quantity: Double = 1.0
    @State private var selectedCategory: ShoppingItem.ShoppingCategory = .groceries
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $itemName)
                    TextField("Description (Optional)", text: $itemDescription)
                }
                
                Section("Quantity & Category") {
                    Stepper("Quantity: \(Int(quantity))", value: $quantity, in: 1...99)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ShoppingItem.ShoppingCategory.allCases, id: \.self) { category in
                            Text(viewModel.getCategoryName(category)).tag(category)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task {
                            await viewModel.addItem(
                                name: itemName,
                                description: itemDescription.isEmpty ? nil : itemDescription,
                                quantity: quantity,
                                category: selectedCategory
                            )
                            dismiss()
                        }
                    }
                    .disabled(itemName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ListView()
        .environmentObject(PocketBaseAuthManager())
}