import SwiftUI
import Foundation

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [PocketBaseNote] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let pocketBase = PocketBaseManager.shared
    private var authManager: PocketBaseAuthManager?
    private var userCache: [String: PocketBaseUser] = [:] // Cache for user information
    private var homeChangeObserver: NSObjectProtocol?
    
    init() {
        setupHomeChangeObserver()
        Task {
            await loadNotes()
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
                await self?.loadNotes()
            }
        }
    }
    
    func setAuthManager(_ authManager: PocketBaseAuthManager) {
        self.authManager = authManager
    }
    
    func loadNotes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load notes
            try await loadNotesFromBackend()
            
            // Load user information for all notes
            try await loadUsersForNotes()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func loadNotesFromBackend() async throws {
        // Get selected home from HomeSelectionManager
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            notes = []
            return
        }
        
        let filter = "home_id = '\(homeId)'"
        let sort = "-created"
        
        let response: PocketBaseListResponse<PocketBaseNote> = try await pocketBase.getCollection(
            "notes",
            responseType: PocketBaseListResponse<PocketBaseNote>.self,
            filter: filter,
            sort: sort
        )
        
        notes = response.items
    }
    
    private func loadUsersForNotes() async throws {
        // Get unique user IDs from notes
        let userIds = Set(notes.compactMap { $0.createdBy })
        
        // Fetch users in batches to avoid too many requests
        for userId in userIds {
            if userCache[userId] == nil {
                do {
                    // Use getCollection with filter to get a specific user
                    let filter = "id = '\(userId)'"
                    let response: PocketBaseListResponse<PocketBaseUser> = try await pocketBase.getCollection(
                        "users",
                        responseType: PocketBaseListResponse<PocketBaseUser>.self,
                        filter: filter
                    )
                    
                    if let user = response.items.first {
                        userCache[userId] = user
                    }
                } catch {
                    print("Error loading user \(userId): \(error)")
                }
            }
        }
    }
    
    func refreshData() async {
        await loadNotes()
    }
    
    func addNote(text: String, color: String) async {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            errorMessage = "No home selected"
            return
        }
        
        do {
            let noteData: [String: Any] = [
                "description": text,
                "home_id": homeId,
                "created_by": authManager?.currentUser?.id ?? "",
                "color": color
            ]
            
            let _: PocketBaseNote = try await pocketBase.createRecord(
                in: "notes",
                data: noteData,
                responseType: PocketBaseNote.self
            )
            
            // Refresh notes after adding
            try await loadNotesFromBackend()
            try await loadUsersForNotes()
            
        } catch {
            errorMessage = "Failed to add note: \(error.localizedDescription)"
        }
    }
    
    func updateNote(_ note: PocketBaseNote, text: String) async {
        do {
            let updatedData: [String: Any] = [
                "description": text
            ]
            
            let _: PocketBaseNote = try await pocketBase.updateRecord(
                in: "notes",
                id: note.id,
                data: updatedData,
                responseType: PocketBaseNote.self
            )
            
            // Refresh notes after update
            try await loadNotesFromBackend()
            try await loadUsersForNotes()
            
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
        }
    }
    
    func deleteNote(_ note: PocketBaseNote) async {
        do {
            try await pocketBase.deleteRecord(from: "notes", id: note.id)
            
            // Refresh notes after deletion
            try await loadNotesFromBackend()
            try await loadUsersForNotes()
            
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }
    
    func canEditNote(_ note: PocketBaseNote) -> Bool {
        return note.createdBy == authManager?.currentUser?.id
    }
    
    // Helper function to get user name for a note
    func getUserName(for note: PocketBaseNote) -> String {
        guard let userId = note.createdBy else {
            return "Unknown"
        }
        
        // Check if it's the current user
        if let currentUser = authManager?.currentUser, currentUser.id == userId {
            return currentUser.name ?? "You"
        }
        
        // Check cache
        if let user = userCache[userId] {
            return user.name ?? "Member"
        }
        
        return "Member"
    }
}