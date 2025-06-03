import SwiftUI
import Combine
import UIKit

// MARK: - Models
struct ListItem: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool
    var date: Date
    var image: UIImage?
}

enum CategoryType: String, CaseIterable {
    case generic = "Generic"
    case shopping = "Shopping"
    case places = "Places to Visit"
    case maintenance = "House Maintenance"
    
    var defaultIcon: String {
        switch self {
        case .generic: return "list.bullet"
        case .shopping: return "cart.fill"
        case .places: return "map.fill"
        case .maintenance: return "wrench.fill"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .generic: return .gray
        case .shopping: return .purple
        case .places: return .green
        case .maintenance: return .blue
        }
    }
}

struct ListCategory: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var color: Color
    var items: [ListItem]
    var type: CategoryType = .generic
}

// MARK: - Views
struct ListView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var categories: [ListCategory] = [
        ListCategory(
            name: "House Maintenance",
            icon: "wrench.fill",
            color: .blue,
            items: [
                ListItem(title: "Fix bathroom sink", isCompleted: false, date: Date(), image: nil),
                ListItem(title: "Replace living room light bulb", isCompleted: true, date: Date(), image: nil),
                ListItem(title: "Clean air filters", isCompleted: false, date: Date(), image: nil)
            ],
            type: .maintenance
        ),
        ListCategory(
            name: "Places to Visit",
            icon: "map.fill",
            color: .green,
            items: [
                ListItem(title: "Local Farmers Market", isCompleted: false, date: Date(), image: nil),
                ListItem(title: "New Italian Restaurant", isCompleted: false, date: Date(), image: nil)
            ],
            type: .places
        ),
        ListCategory(
            name: "Home Improvement",
            icon: "house.fill",
            color: .orange,
            items: [
                ListItem(title: "Paint bedroom walls", isCompleted: false, date: Date(), image: nil),
                ListItem(title: "Buy new curtains", isCompleted: false, date: Date(), image: nil)
            ],
            type: .generic
        ),
        ListCategory(
            name: "Shopping",
            icon: "cart.fill",
            color: .purple,
            items: [
                ListItem(title: "Weekly groceries", isCompleted: false, date: Date(), image: nil),
                ListItem(title: "Kitchen supplies", isCompleted: true, date: Date(), image: nil)
            ],
            type: .shopping
        )
    ]
    @State private var showingNewItemSheet = false
    @State private var showingNewCategorySheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach($categories) { $category in
                    CategoryCard(category: $category, categories: $categories)
                        .id(category.id)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(category.name) category with \(category.items.count) items")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingNewItemSheet = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    
                    Button {
                        showingNewCategorySheet = true
                    } label: {
                        Label("Add Category", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(selectedTheme.colors(for: colorScheme).primary[0])
                }
                .accessibilityLabel("Add new item or category")
            }
        }
        .background(selectedTheme.colors(for: colorScheme).background)
        .sheet(isPresented: $showingNewItemSheet) {
            GlobalNewItemSheet(categories: $categories, isPresented: $showingNewItemSheet)
        }
        .sheet(isPresented: $showingNewCategorySheet) {
            NewCategorySheet(categories: $categories, isPresented: $showingNewCategorySheet)
        }
    }
}

// MARK: - CategoryCard
struct CategoryCard: View {
    @Binding var category: ListCategory
    @Binding var categories: [ListCategory]
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    @State private var showingDetailView = false
    @Namespace private var animation
    
    var completedCount: Int {
        category.items.filter { $0.isCompleted }.count
    }
    
    var progress: Double {
        guard !category.items.isEmpty else { return 0.0 }
        return Double(completedCount) / Double(category.items.count)
    }
    
    var estimatedCost: Double {
        Double(category.items.count * 25)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                
                withAnimation(.spring(duration: 0.6, bounce: 0.1)) {
                    showingDetailView = true
                }
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(category.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                        
                        Text("\(completedCount) of \(category.items.count) completed")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                    }
                    
                    Spacer()
                    
                    if category.type == .shopping {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(estimatedCost, specifier: "%.0f")")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(category.color)
                            Text("budget")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                        }
                    } else if category.type == .places {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(category.items.count)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(category.color)
                            Text("places")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                        }
                    }
                    
                    ZStack {
                        Circle()
                            .stroke(category.color.opacity(0.2), lineWidth: 3)
                            .frame(width: 36, height: 36)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(category.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: progress)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(category.color)
                    }
                    
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(duration: 0.4, bounce: 0.3), value: isExpanded)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(20)
            .background(selectedTheme.colors(for: colorScheme).cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 16 : 16))
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach($category.items) { $item in
                        SwipeableRow(itemTitle: item.title) {
                            ListItemRow(item: $item)
                        } onDelete: {
                            category.items.removeAll { $0.id == item.id }
                        }
                        if item.id != category.items.last?.id {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .background(selectedTheme.colors(for: colorScheme).cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(selectedTheme.colors(for: colorScheme).cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .fullScreenCover(isPresented: $showingDetailView) {
            CategoryDetailView(category: $category, categories: $categories)
        }
    }
}

// MARK: - CategoryDetailView
struct CategoryDetailView: View {
    @Binding var category: ListCategory
    @Binding var categories: [ListCategory]
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingNewItemSheet = false
    @State private var showingDeleteAlert = false
    @Namespace private var heroAnimation
    @State private var slideItemID: UUID?
    
    var completedCount: Int {
        category.items.filter { $0.isCompleted }.count
    }
    
    var progress: Double {
        guard !category.items.isEmpty else { return 0.0 }
        return Double(completedCount) / Double(category.items.count)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundStyle(selectedTheme.colors(for: colorScheme).primary[0])
                        }
                        
                        Spacer()
                        
                        Button {
                            showingNewItemSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(selectedTheme.colors(for: colorScheme).primary[0])
                        }
                        
                        Button {
                            let impactMed = UIImpactFeedbackGenerator(style: .medium)
                            impactMed.impactOccurred()
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(selectedTheme.colors(for: colorScheme).destructive)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: category.icon)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(category.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.name)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                                
                                Text("\(completedCount) of \(category.items.count) completed")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                            }
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Progress")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                                
                                Spacer()
                                
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(category.color)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(category.color.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(category.color)
                                        .frame(width: geometry.size.width * progress, height: 8)
                                        .animation(.easeInOut(duration: 0.8), value: progress)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(24)
                    .background(selectedTheme.colors(for: colorScheme).cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    
                    LazyVStack(spacing: 12) {
                        ForEach($category.items) { $item in
                            SwipeableRow(itemTitle: item.title) {
                                ListItemRow(item: $item)
                            } onDelete: {
                                category.items.removeAll { $0.id == item.id }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 20)
            }
        }
        .background(selectedTheme.colors(for: colorScheme).background)
        .sheet(isPresented: $showingNewItemSheet) {
            CategoryNewItemSheet(category: $category, isPresented: $showingNewItemSheet)
        }
        .alert("Delete Category", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation {
                    dismiss()
                    if let index = categories.firstIndex(where: { $0.id == category.id }) {
                        categories.remove(at: index)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(category.name)' and all its items? This action cannot be undone.")
        }
    }
}

// MARK: - SwipeableRow
struct SwipeableRow<Content: View>: View {
    let content: Content
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var showingDeleteAlert = false
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    let itemTitle: String
    
    init(itemTitle: String, @ViewBuilder content: @escaping () -> Content, onDelete: @escaping () -> Void) {
        self.content = content()
        self.onDelete = onDelete
        self.itemTitle = itemTitle
    }
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity)
                    .background(selectedTheme.colors(for: colorScheme).cardBackground)
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                withAnimation(.spring()) {
                                    offset = value.translation.width
                                    if offset < -60 {
                                        offset = -60
                                    }
                                    if offset > 0 {
                                        offset = 0
                                    }
                                }
                            }
                            .onEnded { value in
                                withAnimation(.spring()) {
                                    if value.translation.width < -50 {
                                        isSwiped = true
                                        offset = -60
                                    } else {
                                        isSwiped = false
                                        offset = 0
                                    }
                                }
                            }
                    )
                
                if offset < 0 {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 50)
                            .background(selectedTheme.colors(for: colorScheme).destructive)
                    }
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .clipped()
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                withAnimation(.spring()) {
                    offset = 0
                    isSwiped = false
                }
            }
            Button("Delete", role: .destructive) {
                withAnimation(.spring()) {
                    onDelete()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(itemTitle)'? This action cannot be undone.")
        }
    }
}

// MARK: - ListItemRow
struct ListItemRow: View {
    @Binding var item: ListItem
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var offset = CGSize.zero
    
    var body: some View {
        HStack(spacing: 16) {
            Button {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                
                withAnimation(.spring(duration: 0.3)) {
                    item.isCompleted.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(item.isCompleted ? selectedTheme.colors(for: colorScheme).primary[0] : Color.clear)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .stroke(item.isCompleted ? selectedTheme.colors(for: colorScheme).primary[0] : selectedTheme.colors(for: colorScheme).textSecondary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).text)
                    .strikethrough(item.isCompleted)
                    .opacity(item.isCompleted ? 0.6 : 1.0)
                    .lineLimit(2)
                
                Text(item.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
            }
            
            Spacer()
            
            if let image = item.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(selectedTheme.colors(for: colorScheme).cardBackground)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(duration: 0.2), value: isPressed)
    }
}

// MARK: - CategoryNewItemSheet
struct CategoryNewItemSheet: View {
    @Binding var category: ListCategory
    @Binding var isPresented: Bool
    @State private var itemTitle = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Item Title", text: $itemTitle)
                }
                
                Section("Image") {
                    Button {
                        showingImagePicker = true
                    } label: {
                        HStack {
                            Text(selectedImage == nil ? "Add Image" : "Change Image")
                            Spacer()
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to \(category.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        withAnimation {
                            let newItem = ListItem(
                                title: itemTitle,
                                isCompleted: false,
                                date: Date(),
                                image: selectedImage
                            )
                            category.items.append(newItem)
                            isPresented = false
                        }
                    }
                    .disabled(itemTitle.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

// MARK: - GlobalNewItemSheet
struct GlobalNewItemSheet: View {
    @Binding var categories: [ListCategory]
    @Binding var isPresented: Bool
    @State private var selectedCategoryIndex = 0
    @State private var itemTitle = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Item Title", text: $itemTitle)
                }
                
                Section("Image") {
                    Button {
                        showingImagePicker = true
                    } label: {
                        HStack {
                            Text(selectedImage == nil ? "Add Image" : "Change Image")
                            Spacer()
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategoryIndex) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                Text(category.name)
                            }
                            .tag(index)
                        }
                    }
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        withAnimation {
                            let newItem = ListItem(
                                title: itemTitle,
                                isCompleted: false,
                                date: Date(),
                                image: selectedImage
                            )
                            categories[selectedCategoryIndex].items.append(newItem)
                            isPresented = false
                        }
                    }
                    .disabled(itemTitle.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

// MARK: - NewCategorySheet
struct NewCategorySheet: View {
    @Binding var categories: [ListCategory]
    @Binding var isPresented: Bool
    @State private var categoryName = ""
    @State private var selectedType: CategoryType = .generic
    @State private var selectedIcon = "list.bullet"
    @State private var selectedColor: Color = .gray
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .gray, .brown, .cyan]
    let icons = ["list.bullet", "star.fill", "heart.fill", "bookmark.fill", "tag.fill", "flag.fill", "bell.fill", "car.fill", "house.fill", "person.fill"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $categoryName)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(CategoryType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: selectedType) { _, newType in
                        selectedIcon = newType.defaultIcon
                        selectedColor = newType.defaultColor
                    }
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(selectedIcon == icon ? .white : selectedColor)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? selectedColor : Color.clear)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        withAnimation {
                            let newCategory = ListCategory(
                                name: categoryName,
                                icon: selectedIcon,
                                color: selectedColor,
                                items: [],
                                type: selectedType
                            )
                            categories.append(newCategory)
                            isPresented = false
                        }
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
        }
    }
}

// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
