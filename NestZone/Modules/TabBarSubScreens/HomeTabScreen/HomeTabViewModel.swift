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
        errorMessage = error.localizedDescription
    }
    
    private func loadTasks() async throws {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            tasks = []
            return
        }
        
        let items: [PocketBaseTask] = try await Convex.once(
            "tasks:listByHome", args: ["homeId": homeId], as: [PocketBaseTask].self
        )
        // Newest first, latest 10.
        tasks = Array(items.sorted { ($0.created ?? 0) > ($1.created ?? 0) }.prefix(10))
    }

    /// Count items whose `created` ms falls within [start, end).
    private func countCreated<T>(_ items: [T], from start: Date, to end: Date,
                                 _ created: (T) -> Double?) -> Int {
        let lo = start.convexMillis, hi = end.convexMillis
        return items.filter { let c = created($0) ?? 0; return c >= lo && c < hi }.count
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
            // Stats are best-effort: a failure here must not blank the task list.
            print("DEBUG: Failed to load statistics, zeroing counters:", error)
            
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
    
    // Cached lists for the current stats pass, so current/previous week share one fetch.
    private var statsShopping: [ShoppingItem] = []
    private var statsNotes: [PocketBaseNote] = []
    private var statsTasks: [PocketBaseTask] = []

    private func loadCurrentWeekStats(homeId: String) async throws {
        // One fetch each; window counting happens client-side on `created` ms.
        async let shopping: [ShoppingItem] = Convex.once(
            "shopping:listByHome", args: ["homeId": homeId], as: [ShoppingItem].self)
        async let notes: [PocketBaseNote] = Convex.once(
            "notes:listByHome", args: ["homeId": homeId], as: [PocketBaseNote].self)
        async let tasksList: [PocketBaseTask] = Convex.once(
            "tasks:listByHome", args: ["homeId": homeId], as: [PocketBaseTask].self)
        statsShopping = try await shopping
        statsNotes = try await notes
        statsTasks = try await tasksList

        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        shoppingListCount = countCreated(statsShopping, from: weekAgo, to: now) { $0.created }
        noteCount = countCreated(statsNotes, from: weekAgo, to: now) { $0.created }
        issueCount = statsTasks.filter { $0.priority == .high && !$0.isCompleted }.count
        messageCount = noteCount
    }

    private func loadPreviousWeekStats(homeId: String) async throws {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        let prevShopping = countCreated(statsShopping, from: twoWeeksAgo, to: weekAgo) { $0.created }
        shoppingChange = shoppingListCount - prevShopping

        let prevNotes = countCreated(statsNotes, from: twoWeeksAgo, to: weekAgo) { $0.created }
        noteChange = noteCount - prevNotes
        messageChange = noteChange

        let prevIssues = statsTasks.filter {
            $0.priority == .high && !$0.isCompleted
                && countCreated([$0], from: twoWeeksAgo, to: weekAgo, { $0.created }) == 1
        }.count
        issueChange = issueCount - prevIssues
    }
    
    private func calculateCompletedTasksChange() {
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        
        // Count tasks completed this week (updated this week with isCompleted = true)
        let thisWeekCompleted = tasks.filter { task in
            guard task.isCompleted, let ms = task.updated else { return false }
            let updatedDate = Date(convexMillis: ms)
            return updatedDate >= weekAgo && updatedDate <= today
        }.count

        // Count tasks completed last week
        let lastWeekCompleted = tasks.filter { task in
            guard task.isCompleted, let ms = task.updated else { return false }
            let updatedDate = Date(convexMillis: ms)
            return updatedDate >= twoWeeksAgo && updatedDate < weekAgo
        }.count
        
        completedTasksChange = thisWeekCompleted - lastWeekCompleted
    }
    
    func refreshData() async {
        await loadHomeData()
    }
    
    func toggleTaskCompletion(_ task: PocketBaseTask) async {
        // Offline/permission-denied path: reflect the toggle locally only.
        if showingPermissionsError {
            // Update the in-memory copy so the row still responds
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
                    updated: Date().convexMillis,
                    dueDate: task.dueDate
                )
            }
            return
        }

        do {
            try await Convex.run("tasks:update", args: [
                "id": task.id,
                "is_completed": !task.isCompleted,
            ])
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
        if let dueMs = task.dueDate {
            let dueDate = Date(convexMillis: dueMs)
            do {
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