import SwiftUI
import Foundation
import ConvexMobile

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [PocketBaseNote] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authManager: ConvexAuthManager?
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
    
    func setAuthManager(_ authManager: ConvexAuthManager) {
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

        let items: [PocketBaseNote] = try await Convex.once(
            "notes:listByHome", args: ["homeId": homeId], as: [PocketBaseNote].self
        )
        // Newest first (server returns insertion order).
        notes = items.sorted { ($0.created ?? 0) > ($1.created ?? 0) }
    }

    private func loadUsersForNotes() async throws {
        // Get unique user IDs from notes that aren't cached yet.
        let missing = Set(notes.compactMap { $0.createdBy }).filter { userCache[$0] == nil }
        guard !missing.isEmpty else { return }

        let users: [PocketBaseUser] = try await Convex.once(
            "users:byIds",
            args: ["ids": missing.map { $0 as ConvexEncodable? }],
            as: [PocketBaseUser].self
        )
        for user in users { userCache[user.id] = user }
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
            try await Convex.client.mutation("notes:create", with: [
                "homeId": homeId,
                "description": text,
                "color": color,
            ])

            // Refresh notes after adding
            try await loadNotesFromBackend()
            try await loadUsersForNotes()

        } catch {
            errorMessage = "Failed to add note: \(error.localizedDescription)"
        }
    }

    func updateNote(_ note: PocketBaseNote, text: String) async {
        do {
            try await Convex.client.mutation("notes:update", with: [
                "id": note.id,
                "description": text,
            ])

            // Refresh notes after update
            try await loadNotesFromBackend()
            try await loadUsersForNotes()

        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
        }
    }

    func deleteNote(_ note: PocketBaseNote) async {
        do {
            try await Convex.client.mutation("notes:remove", with: ["id": note.id])

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