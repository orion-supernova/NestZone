import SwiftUI
import Foundation

@MainActor
class HomeTabViewModel: ObservableObject {
    @Published var tasks: [PocketBaseTask] = []
    @Published var todayProgress: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingPermissionsError = false
    
    // Statistics
    @Published var messageCount = 0
    @Published var shoppingListCount = 0
    @Published var issueCount = 0
    @Published var noteCount = 0
    
    // Weekly changes for statistics
    @Published var messageChange = 0
    @Published var shoppingChange = 0
    @Published var issueChange = 0
    @Published var noteChange = 0
    
    private let pocketBase = PocketBaseManager.shared
    private var currentHomeId: String?
    
    init() {
        Task {
            await loadHomeData()
        }
    }
    
    func loadHomeData() async {
        isLoading = true
        errorMessage = nil
        showingPermissionsError = false
        
        do {
            // First get the current user's home
            await getCurrentHome()
            
            // Add small delay to prevent request conflicts
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Then load all data in parallel
            try await loadTasks()
            try await loadStatistics()
            
            // Calculate today's progress
            calculateTodayProgress()
            
        } catch {
            if error.localizedDescription.contains("cancelled") {
                // Retry once if request was cancelled
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await loadHomeData()
            } else {
                await handleLoadError(error)
            }
        }
        
        isLoading = false
    }
    
    private func handleLoadError(_ error: Error) async {
        print("DEBUG: Handling load error:", error)
        
        // Check if this is a permissions error (403)
        if let pocketBaseError = error as? PocketBaseManager.PocketBaseError,
           case .forbidden = pocketBaseError {
            
            print("DEBUG: Detected permissions error - loading mock data for development")
            showingPermissionsError = true
            
            // Load mock data for development
            loadMockData()
            
            errorMessage = "Backend permissions issue detected. Using mock data for development. Please configure PocketBase to allow authenticated users to access tasks."
            
        } else {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadMockData() {
        // Create mock tasks for development/demo purposes
        let mockTasks = [
            PocketBaseTask(
                id: "mock1",
                title: "Clean Kitchen",
                description: "Deep clean the kitchen including dishes and counters",
                createdBy: "user1",
                updatedBy: nil,
                assignedTo: "user1",
                isCompleted: false,
                image: nil,
                homeId: currentHomeId ?? "mock_home",
                priority: .high,
                type: .cleaning,
                created: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
                updated: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
                dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400))
            ),
            PocketBaseTask(
                id: "mock2",
                title: "Buy Groceries",
                description: "Weekly grocery shopping - milk, bread, fruits",
                createdBy: "user2",
                updatedBy: nil,
                assignedTo: "user2",
                isCompleted: true,
                image: nil,
                homeId: currentHomeId ?? "mock_home",
                priority: .medium,
                type: .shopping,
                created: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800)),
                updated: ISO8601DateFormatter().string(from: Date()),
                dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400))
            ),
            PocketBaseTask(
                id: "mock3",
                title: "Fix Leaky Faucet",
                description: "Repair the bathroom faucet that's been dripping",
                createdBy: "user1",
                updatedBy: nil,
                assignedTo: "user3",
                isCompleted: false,
                image: nil,
                homeId: currentHomeId ?? "mock_home",
                priority: .high,
                type: .maintenance,
                created: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-259200)),
                updated: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-259200)),
                dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(172800))
            ),
            PocketBaseTask(
                id: "mock4",
                title: "Plan Weekly Menu",
                description: "Plan meals for the upcoming week",
                createdBy: "user2",
                updatedBy: nil,
                assignedTo: "user1",
                isCompleted: false,
                image: nil,
                homeId: currentHomeId ?? "mock_home",
                priority: .low,
                type: .general,
                created: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-43200)),
                updated: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-43200)),
                dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(43200))
            )
        ]
        
        tasks = mockTasks
        
        // Mock statistics
        messageCount = noteCount // Use actual note count
        shoppingListCount = 5
        issueCount = 2
        noteCount = 8
        
        messageChange = noteChange // Use actual note change
        shoppingChange = -1
        issueChange = 1
        noteChange = 2
        
        print("DEBUG: Loaded \(tasks.count) mock tasks for development")
    }
    
    private func getCurrentHome() async {
        do {
            let response: PocketBaseListResponse<Home> = try await pocketBase.getCollection(
                "homes",
                responseType: PocketBaseListResponse<Home>.self
            )
            
            currentHomeId = response.items.first?.id
            print("DEBUG: Current Home ID: \(currentHomeId ?? "nil")")
        } catch {
            print("Error getting home: \(error)")
            // Don't throw error here, we can still work with mock data
        }
    }
    
    private func loadTasks() async throws {
        guard let homeId = currentHomeId else { 
            print("DEBUG: No home ID available")
            return 
        }
        
        let filter = "home_id = '\(homeId)'"
        let sort = "-created"
        
        print("DEBUG: Loading tasks with filter: \(filter)")
        
        do {
            let response: PocketBaseListResponse<PocketBaseTask> = try await pocketBase.getCollection(
                "tasks",
                responseType: PocketBaseListResponse<PocketBaseTask>.self,
                filter: filter,
                sort: sort
            )
            
            tasks = Array(response.items.prefix(10)) // Show latest 10 tasks
            print("DEBUG: Loaded \(tasks.count) tasks")
            
        } catch {
            // Re-throw the error so it can be handled by the calling function
            throw error
        }
    }
    
    private func loadStatistics() async throws {
        guard let homeId = currentHomeId else { return }
        
        do {
            // Load current week statistics
            try await loadCurrentWeekStats(homeId: homeId)
            
            // Load previous week for comparison
            try await loadPreviousWeekStats(homeId: homeId)
        } catch {
            // If we can't load stats due to permissions, use mock data
            print("DEBUG: Failed to load statistics, using mock data:", error)
            
            // Use mock statistics (already set in loadMockData if needed)
            messageCount = 0 // Start with 0, will be set to noteCount in loadCurrentWeekStats
            shoppingListCount = 0
            issueCount = 0
            noteCount = 0
            
            messageChange = 0
            shoppingChange = 0
            issueChange = 0
            noteChange = 0
        }
    }
    
    private func loadCurrentWeekStats(homeId: String) async throws {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekAgoString = ISO8601DateFormatter().string(from: weekAgo)
        
        do {
            // Shopping Lists
            let shoppingFilter = "home_id = '\(homeId)' && created >= '\(weekAgoString)'"
            let shoppingResponse: PocketBaseListResponse<ShoppingItem> = try await pocketBase.getCollection(
                "shopping_items",
                responseType: PocketBaseListResponse<ShoppingItem>.self,
                filter: shoppingFilter
            )
            shoppingListCount = shoppingResponse.totalItems
            
            // Notes
            let notesFilter = "home_id = '\(homeId)' && created >= '\(weekAgoString)'"
            let notesResponse: PocketBaseListResponse<PocketBaseNote> = try await pocketBase.getCollection(
                "notes",
                responseType: PocketBaseListResponse<PocketBaseNote>.self,
                filter: notesFilter
            )
            noteCount = notesResponse.totalItems
            
            // Issues (high priority tasks)
            let issueFilter = "home_id = '\(homeId)' && priority = 'high' && is_completed = false"
            let issueResponse: PocketBaseListResponse<PocketBaseTask> = try await pocketBase.getCollection(
                "tasks",
                responseType: PocketBaseListResponse<PocketBaseTask>.self,
                filter: issueFilter
            )
            issueCount = issueResponse.totalItems
            
            // Messages (use notes count - they're the same for now)
            messageCount = noteCount
            
        } catch {
            print("Error loading current week stats: \(error)")
            throw error
        }
    }
    
    private func loadPreviousWeekStats(homeId: String) async throws {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let twoWeeksAgoString = ISO8601DateFormatter().string(from: twoWeeksAgo)
        let weekAgoString = ISO8601DateFormatter().string(from: weekAgo)
        
        do {
            // Previous week shopping
            let prevShoppingFilter = "home_id = '\(homeId)' && created >= '\(twoWeeksAgoString)' && created < '\(weekAgoString)'"
            let prevShoppingResponse: PocketBaseListResponse<ShoppingItem> = try await pocketBase.getCollection(
                "shopping_items",
                responseType: PocketBaseListResponse<ShoppingItem>.self,
                filter: prevShoppingFilter
            )
            shoppingChange = shoppingListCount - prevShoppingResponse.totalItems
            
            // Previous week notes
            let prevNotesFilter = "home_id = '\(homeId)' && created >= '\(twoWeeksAgoString)' && created < '\(weekAgoString)'"
            let prevNotesResponse: PocketBaseListResponse<PocketBaseNote> = try await pocketBase.getCollection(
                "notes",
                responseType: PocketBaseListResponse<PocketBaseNote>.self,
                filter: prevNotesFilter
            )
            noteChange = noteCount - prevNotesResponse.totalItems
            
            // Messages change (same as notes for now)
            messageChange = noteChange
            
            // Issues change - calculate based on current vs previous high priority tasks
            issueChange = max(-2, min(2, Int.random(in: -1...1))) // Demo values
            
        } catch {
            print("Error loading previous week stats: \(error)")
            throw error
        }
    }
    
    private func calculateTodayProgress() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayTasks = tasks.filter { task in
            let formatter = ISO8601DateFormatter()
            if let taskDate = formatter.date(from: task.created) {
                return taskDate >= today && taskDate < tomorrow
            }
            return false
        }
        
        guard !todayTasks.isEmpty else {
            todayProgress = 0.0
            return
        }
        
        let completedTasks = todayTasks.filter { $0.isCompleted }
        todayProgress = Double(completedTasks.count) / Double(todayTasks.count)
    }
    
    func refreshData() async {
        await loadHomeData()
    }
    
    func toggleTaskCompletion(_ task: PocketBaseTask) async {
        // Don't try to update if we're using mock data
        if showingPermissionsError {
            // Just update the local mock data
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = PocketBaseTask(
                    id: task.id,
                    title: task.title,
                    description: task.description,
                    createdBy: task.createdBy,
                    updatedBy: task.updatedBy,
                    assignedTo: task.assignedTo,
                    isCompleted: !task.isCompleted,
                    image: task.image,
                    homeId: task.homeId,
                    priority: task.priority,
                    type: task.type,
                    created: task.created,
                    updated: ISO8601DateFormatter().string(from: Date()),
                    dueDate: task.dueDate
                )
                calculateTodayProgress()
            }
            return
        }
        
        do {
            let updatedData = ["is_completed": !task.isCompleted]
            let _: PocketBaseTask = try await pocketBase.updateRecord(
                in: "tasks",
                id: task.id,
                data: updatedData,
                responseType: PocketBaseTask.self
            )
            
            // Refresh tasks after update
            try await loadTasks()
            calculateTodayProgress()
            
        } catch {
            errorMessage = "Failed to update task: \(error.localizedDescription)"
        }
    }
    
    // Helper methods for UI
    func getTaskProgress(_ task: PocketBaseTask) -> Double {
        return task.isCompleted ? 1.0 : 0.65 // For demo, assume partial progress if not completed
    }
    
    func getTimeLeftText(_ task: PocketBaseTask) -> String {
        if let dueDateString = task.dueDate {
            let formatter = ISO8601DateFormatter()
            if let dueDate = formatter.date(from: dueDateString) {
                let now = Date()
                let components = Calendar.current.dateComponents([.hour, .day], from: now, to: dueDate)
                
                if let days = components.day, days > 0 {
                    return "\(days) day\(days == 1 ? "" : "s") left"
                } else if let hours = components.hour, hours > 0 {
                    return "\(hours) hour\(hours == 1 ? "" : "s") left"
                } else {
                    return "Due now"
                }
            }
        }
        return "No deadline"
    }
    
    func getUserName(for userId: String?) -> String {
        // For now, return demo names. In a full implementation, you'd cache user data
        guard let userId = userId else { return "Unassigned" }
        
        let names = ["Sarah", "Mike", "Emma", "Alex", "Jordan", "Taylor"]
        let index = abs(userId.hashValue) % names.count
        return names[index]
    }
    
    func getTaskTypeColor(_ type: PocketBaseTask.TaskType) -> [Color] {
        switch type {
        case .cleaning:
            return [.blue, .cyan]
        case .shopping:
            return [.green, .mint]
        case .maintenance:
            return [.orange, .yellow]
        case .general:
            return [.purple, .pink]
        }
    }
    
    func getPriorityColor(_ priority: PocketBaseTask.TaskPriority) -> Color {
        switch priority {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    func getTaskIcon(_ type: PocketBaseTask.TaskType) -> String {
        switch type {
        case .cleaning:
            return "sparkles"
        case .shopping:
            return "basket.fill"
        case .maintenance:
            return "wrench.adjustable.fill"
        case .general:
            return "list.bullet"
        }
    }
}