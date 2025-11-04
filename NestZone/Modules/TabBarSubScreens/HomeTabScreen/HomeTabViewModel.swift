import SwiftUI
import Foundation

@MainActor
class HomeTabViewModel: ObservableObject {
    @Published var tasks: [PocketBaseTask] = []
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
    @Published var completedTasksChange = 0
    
    private let pocketBase = PocketBaseManager.shared
    private var homeChangeObserver: NSObjectProtocol?
    
    init() {
        setupHomeChangeObserver()
        Task {
            await loadHomeData()
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
                await self?.loadHomeData()
            }
        }
    }
    
    func loadHomeData() async {
        isLoading = true
        errorMessage = nil
        showingPermissionsError = false
        
        defer {
            isLoading = false
        }
        
        do {
            // Check if we have a selected home
            guard HomeSelectionManager.shared.selectedHomeId != nil else {
                // Clear all data if no home is selected
                tasks = []
                messageCount = 0
                shoppingListCount = 0
                issueCount = 0
                noteCount = 0
                messageChange = 0
                shoppingChange = 0
                issueChange = 0
                noteChange = 0
                completedTasksChange = 0
                return
            }
            
            // Add small delay to prevent request conflicts
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Then load all data in parallel
            try await loadTasks()
            try await loadStatistics()
            
        } catch is CancellationError {
            // Task was cancelled, just return without retrying
            print("DEBUG: Load home data was cancelled")
            return
        } catch {
            await handleLoadError(error)
        }
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
        let mockHomeId = HomeSelectionManager.shared.selectedHomeId ?? "mock_home"
        
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
                homeId: mockHomeId,
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
                homeId: mockHomeId,
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
                homeId: mockHomeId,
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
                homeId: mockHomeId,
                priority: .low,
                type: .general,
                created: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-43200)),
                updated: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-43200)),
                dueDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(43200))
            )
        ]
        
        tasks = mockTasks
        
        // Mock statistics - make them more realistic based on actual mock data
        messageCount = 0 // Will be set to noteCount in loadCurrentWeekStats
        shoppingListCount = 5
        issueCount = mockTasks.filter { $0.priority == .high && !$0.isCompleted }.count // Count actual high priority incomplete tasks
        noteCount = 8
        
        messageChange = 0 // Will be set to noteChange in loadCurrentWeekStats  
        shoppingChange = -1
        issueChange = 0 // More realistic default
        noteChange = 2
        completedTasksChange = 1 // One task completed this week
        
        print("DEBUG: Loaded \(tasks.count) mock tasks for development")
        print("DEBUG: Mock issues count: \(issueCount)")
    }
    
    private func loadTasks() async throws {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            tasks = []
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
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            // Clear stats if no home
            messageCount = 0
            shoppingListCount = 0
            issueCount = 0
            noteCount = 0
            messageChange = 0
            shoppingChange = 0
            issueChange = 0
            noteChange = 0
            completedTasksChange = 0
            return
        }
        
        do {
            // Load current week statistics
            try await loadCurrentWeekStats(homeId: homeId)
            
            // Load previous week for comparison
            try await loadPreviousWeekStats(homeId: homeId)
            
            // Calculate completed tasks change
            calculateCompletedTasksChange()
        } catch {
            // If we can't load stats due to permissions, use mock data
            print("DEBUG: Failed to load statistics, using mock data:", error)
            
            // Clear statistics
            messageCount = 0
            shoppingListCount = 0
            issueCount = 0
            noteCount = 0
            
            messageChange = 0
            shoppingChange = 0
            issueChange = 0
            noteChange = 0
            completedTasksChange = 0
            
            // Still calculate completed tasks change from available task data
            calculateCompletedTasksChange()
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
            
            // Issues change - calculate based on actual previous week high priority tasks
            let prevIssueFilter = "home_id = '\(homeId)' && priority = 'high' && is_completed = false && created >= '\(twoWeeksAgoString)' && created < '\(weekAgoString)'"
            let prevIssueResponse: PocketBaseListResponse<PocketBaseTask> = try await pocketBase.getCollection(
                "tasks",
                responseType: PocketBaseListResponse<PocketBaseTask>.self,
                filter: prevIssueFilter
            )
            issueChange = issueCount - prevIssueResponse.totalItems
            
        } catch {
            print("Error loading previous week stats: \(error)")
            throw error
        }
    }
    
    private func calculateCompletedTasksChange() {
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        
        let formatter = ISO8601DateFormatter()
        
        // Count tasks completed this week (updated this week with isCompleted = true)
        let thisWeekCompleted = tasks.filter { task in
            guard task.isCompleted, let updatedDate = formatter.date(from: task.updated) else { return false }
            return updatedDate >= weekAgo && updatedDate <= today
        }.count
        
        // Count tasks completed last week
        let lastWeekCompleted = tasks.filter { task in
            guard task.isCompleted, let updatedDate = formatter.date(from: task.updated) else { return false }
            return updatedDate >= twoWeeksAgo && updatedDate < weekAgo
        }.count
        
        completedTasksChange = thisWeekCompleted - lastWeekCompleted
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