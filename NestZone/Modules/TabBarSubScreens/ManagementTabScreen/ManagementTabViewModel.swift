import SwiftUI
import Foundation

@MainActor
class ManagementTabViewModel: ObservableObject {
    @Published var shoppingItems: [ShoppingItem] = []
    @Published var categories: [ShoppingItem.ShoppingCategory: [ShoppingItem]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Statistics
    @Published var totalItems = 0
    @Published var completedItems = 0
    @Published var pendingItems = 0
    @Published var totalEstimatedCost: Double = 0.0
    
    private let pocketBase = PocketBaseManager.shared
    private var homeChangeObserver: NSObjectProtocol?
    
    init() {
        setupHomeChangeObserver()
        Task {
            await loadShoppingData()
        }
    }
    
    deinit {
        if let observer = homeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupHomeChangeObserver() {
        homeChangeObserver = NotificationCenter.default.addObserver(
            forName: .homeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadShoppingData()
            }
        }
    }
    
    func loadShoppingData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load shopping items
            try await loadShoppingItems()
            
            // Calculate statistics
            calculateStatistics()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func loadShoppingItems() async throws {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            shoppingItems = []
            categories = [:]
            return
        }
        
        let filter = "home_id = '\(homeId)'"
        let sort = "-created"
        
        let response: PocketBaseListResponse<ShoppingItem> = try await pocketBase.getCollection(
            "shopping_items",
            responseType: PocketBaseListResponse<ShoppingItem>.self,
            filter: filter,
            sort: sort
        )
        
        shoppingItems = response.items
        
        // Group by category
        categories = Dictionary(grouping: shoppingItems) { $0.category }
    }
    
    private func calculateStatistics() {
        totalItems = shoppingItems.count
        completedItems = shoppingItems.filter { $0.isPurchased }.count
        pendingItems = totalItems - completedItems
        
        // Estimate cost based on item count and category
        totalEstimatedCost = shoppingItems.reduce(0.0) { total, item in
            let baseCost = switch item.category {
            case .groceries: 15.0
            case .household: 25.0
            case .cleaning: 12.0
            case .other: 20.0
            }
            
            let quantity = item.quantity ?? 1.0
            return total + (baseCost * quantity)
        }
    }
    
    func refreshData() async {
        await loadShoppingData()
    }
    
    func toggleItemCompletion(_ item: ShoppingItem) async {
        do {
            let updatedData = ["is_purchased": !item.isPurchased]
            let _: ShoppingItem = try await pocketBase.updateRecord(
                in: "shopping_items",
                id: item.id,
                data: updatedData,
                responseType: ShoppingItem.self
            )
            
            // Refresh items after update
            try await loadShoppingItems()
            calculateStatistics()
            
        } catch {
            errorMessage = LocalizationManager.managementErrorUpdateItem(error.localizedDescription)
        }
    }
    
    func addItem(name: String, description: String?, quantity: Double?, category: ShoppingItem.ShoppingCategory) async {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            errorMessage = "No home selected"
            return
        }
        
        do {
            let itemData: [String: Any] = [
                "name": name,
                "description": description ?? "",
                "quantity": quantity ?? 1.0,
                "is_purchased": false,
                "category": category.rawValue,
                "home_id": homeId
            ]
            
            let _: ShoppingItem = try await pocketBase.createRecord(
                in: "shopping_items",
                data: itemData,
                responseType: ShoppingItem.self
            )
            
            // Refresh items after adding
            try await loadShoppingItems()
            calculateStatistics()
            
        } catch {
            errorMessage = LocalizationManager.managementErrorAddItem(error.localizedDescription)
        }
    }
    
    func deleteItem(_ item: ShoppingItem) async {
        do {
            try await pocketBase.deleteRecord(from: "shopping_items", id: item.id)
            
            // Refresh items after deletion
            try await loadShoppingItems()
            calculateStatistics()
            
        } catch {
            errorMessage = LocalizationManager.managementErrorDeleteItem(error.localizedDescription)
        }
    }
    
    func updateItem(_ item: ShoppingItem, name: String, description: String?, quantity: Double?) async {
        do {
            let updatedData: [String: Any] = [
                "name": name,
                "description": description ?? "",
                "quantity": quantity ?? 1.0
            ]
            
            let _: ShoppingItem = try await pocketBase.updateRecord(
                in: "shopping_items",
                id: item.id,
                data: updatedData,
                responseType: ShoppingItem.self
            )
            
            // Refresh items after update
            try await loadShoppingItems()
            calculateStatistics()
            
        } catch {
            errorMessage = LocalizationManager.managementErrorUpdateItem(error.localizedDescription)
        }
    }
    
    // Helper methods for UI
    func getCategoryColor(_ category: ShoppingItem.ShoppingCategory) -> [Color] {
        switch category {
        case .groceries:
            return [.green, .mint]
        case .household:
            return [.blue, .cyan]
        case .cleaning:
            return [.purple, .pink]
        case .other:
            return [.orange, .yellow]
        }
    }
    
    func getCategoryIcon(_ category: ShoppingItem.ShoppingCategory) -> String {
        switch category {
        case .groceries:
            return "basket.fill"
        case .household:
            return "house.fill"
        case .cleaning:
            return "sparkles"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
    
    func getCategoryName(_ category: ShoppingItem.ShoppingCategory) -> String {
        switch category {
        case .groceries:
            return LocalizationManager.shoppingCategoryGroceries
        case .household:
            return LocalizationManager.shoppingCategoryHousehold
        case .cleaning:
            return LocalizationManager.shoppingCategoryCleaning
        case .other:
            return LocalizationManager.shoppingCategoryOther
        }
    }
    
    func getProgress(for category: ShoppingItem.ShoppingCategory) -> Double {
        let categoryItems = categories[category] ?? []
        guard !categoryItems.isEmpty else { return 0.0 }
        
        let completedCount = categoryItems.filter { $0.isPurchased }.count
        return Double(completedCount) / Double(categoryItems.count)
    }
    
    func getEstimatedCost(for category: ShoppingItem.ShoppingCategory) -> Double {
        let categoryItems = categories[category] ?? []
        return categoryItems.reduce(0.0) { total, item in
            let baseCost = switch category {
            case .groceries: 15.0
            case .household: 25.0
            case .cleaning: 12.0
            case .other: 20.0
            }
            
            let quantity = item.quantity ?? 1.0
            return total + (baseCost * quantity)
        }
    }
}