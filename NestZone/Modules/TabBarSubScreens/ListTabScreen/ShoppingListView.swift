import SwiftUI

// MARK: - Main Shopping List View
struct ShoppingListView: View {
    @StateObject private var viewModel = ListTabViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingNewItemSheet = false
    @AppStorage("shoppingListViewMode") private var isGroupedView = true // Persist view mode preference
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Shopping Header
                    ShoppingHeaderView()
                        .environmentObject(viewModel)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    
                    // Simplified View Mode Toggle
                    SimplifiedViewModeToggle(isGroupedView: $isGroupedView)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    
                    // Content based on view mode
                    if isGroupedView {
                        // Shopping Categories (Grouped View)
                        ShoppingCategoriesSection()
                            .environmentObject(viewModel)
                            .padding(.top, 32)
                    } else {
                        // Plain List View
                        ShoppingPlainListSection()
                            .environmentObject(viewModel)
                            .padding(.top, 32)
                    }
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

// MARK: - Simplified View Mode Toggle
struct SimplifiedViewModeToggle: View {
    @Binding var isGroupedView: Bool
    @State private var bounceAnimation = false
    
    var body: some View {
        HStack(spacing: 0) {
            PlainViewButton(isGroupedView: $isGroupedView, bounceAnimation: $bounceAnimation)
            GroupedViewButton(isGroupedView: $isGroupedView, bounceAnimation: $bounceAnimation)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

// MARK: - View Mode Components
struct PlainViewButton: View {
    @Binding var isGroupedView: Bool
    @Binding var bounceAnimation: Bool
    
    var body: some View {
        Button {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isGroupedView = false
                bounceAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bounceAnimation = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .bold))
                
                Text("List")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundShape)
            .scaleEffect(scaleEffect)
        }
        .buttonStyle(.plain)
    }
    
    private var textColor: Color {
        isGroupedView ? .secondary : .white
    }
    
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundGradient)
    }
    
    private var backgroundGradient: LinearGradient {
        isGroupedView ? 
        LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom) :
        LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var scaleEffect: CGFloat {
        (!isGroupedView && bounceAnimation) ? 1.05 : 1.0
    }
}

struct GroupedViewButton: View {
    @Binding var isGroupedView: Bool
    @Binding var bounceAnimation: Bool
    
    var body: some View {
        Button {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isGroupedView = true
                bounceAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bounceAnimation = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 16, weight: .bold))
                
                Text("Categories")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundShape)
            .scaleEffect(scaleEffect)
        }
        .buttonStyle(.plain)
    }
    
    private var textColor: Color {
        !isGroupedView ? .secondary : .white
    }
    
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundGradient)
    }
    
    private var backgroundGradient: LinearGradient {
        !isGroupedView ? 
        LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom) :
        LinearGradient(colors: [Color.green, Color.mint], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var scaleEffect: CGFloat {
        (isGroupedView && bounceAnimation) ? 1.05 : 1.0
    }
}

// MARK: - Shopping Header
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

// MARK: - Mini Shopping Card
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

// MARK: - Shopping Categories Section
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

// MARK: - Plain List Section
struct ShoppingPlainListSection: View {
    @EnvironmentObject private var viewModel: ListTabViewModel
    
    // Sort items: incomplete first, then completed
    var sortedItems: [ShoppingItem] {
        viewModel.shoppingItems.sorted { item1, item2 in
            if item1.isPurchased != item2.isPurchased {
                return !item1.isPurchased // Incomplete items first
            }
            return item1.name < item2.name // Then alphabetically
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("All Items")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                // Show total count
                Text("\(sortedItems.count) items")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        ShimmerPlainItem()
                    }
                }
                .padding(.horizontal, 20)
            } else if sortedItems.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "cart")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)
                    
                    Text("No items yet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Add your first shopping item!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            } else {
                // Plain list of all items
                LazyVStack(spacing: 0) {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        VibrantPlainShoppingItem(
                            item: item, 
                            gradient: viewModel.getCategoryColor(item.category), 
                            index: index
                        )
                        .environmentObject(viewModel)
                        
                        if index < sortedItems.count - 1 {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
            }
        }
        .padding(.bottom, 100)
    }
}

// MARK: - Category Card
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
            // Category Header - Make entire area tappable
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
                .contentShape(Rectangle()) // Make entire header area tappable
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

// MARK: - Shopping Items
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

struct VibrantPlainShoppingItem: View {
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
                HStack {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .strikethrough(item.isPurchased)
                        .opacity(item.isPurchased ? 0.7 : 1.0)
                    
                    // Category badge
                    Text(viewModel.getCategoryName(item.category))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(gradient[0].opacity(0.2))
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
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

// MARK: - Shimmer Views
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

struct ShimmerPlainItem: View {
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: 200)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .frame(maxWidth: 120)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Add Item Sheet
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