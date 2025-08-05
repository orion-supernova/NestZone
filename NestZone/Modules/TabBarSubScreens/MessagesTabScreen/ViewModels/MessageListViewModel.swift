import SwiftUI
import Foundation

@MainActor
class MessageListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var conversations: [PocketBaseConversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var unreadCounts: [String: Int] = [:]
    
    // MARK: - Private Properties
    private let messagesManager = MessagesManager.shared
    private let pocketBase = PocketBaseManager.shared
    private var currentHomeId: String?
    private var currentUserId: String?
    private var hasInitialLoad = false
    
    // MARK: - Initialization
    init() {
        print("DEBUG: MessageListViewModel initialized")
    }
    
    // MARK: - Public Methods
    func setup(authManager: PocketBaseAuthManager) {
        self.currentUserId = authManager.currentUser?.id
        
        // Only load once per setup
        guard !hasInitialLoad else {
            print("DEBUG: MessageListViewModel - Already loaded, skipping")
            return
        }
        
        Task {
            await loadConversations()
        }
    }
    
    func refresh() async {
        print("DEBUG: MessageListViewModel - Manual refresh triggered")
        await loadConversations()
    }
    
    func addNewConversation(_ conversation: PocketBaseConversation) {
        print("DEBUG: Adding new conversation: \(conversation.id)")
        conversations.insert(conversation, at: 0)
        
        // Load unread count for the new conversation
        Task {
            await loadUnreadCountForConversation(conversation)
        }
    }
    
    // MARK: - Private Methods
    private func loadConversations() async {
        guard let currentUserId = currentUserId else {
            errorMessage = "User not authenticated"
            return
        }
        
        // Prevent multiple simultaneous loads
        if isLoading {
            print("DEBUG: MessageListViewModel - Load already in progress, skipping")
            return
        }
        
        isLoading = true
        errorMessage = nil
        hasInitialLoad = true
        
        print("DEBUG: MessageListViewModel - Loading conversations")
        
        do {
            // Get user's home
            let userResponse: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(currentUserId)",
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            guard let homeId = userResponse.home_id.first else {
                errorMessage = "No home found"
                isLoading = false
                return
            }
            
            currentHomeId = homeId
            print("DEBUG: MessageListViewModel - Home ID: \(homeId)")
            
            // Load conversations
            let freshConversations = try await messagesManager.fetchConversations(for: homeId)
            print("DEBUG: MessageListViewModel - Loaded \(freshConversations.count) conversations")
            
            // Update state
            conversations = freshConversations
            
            // Load unread counts
            await loadUnreadCounts()
            
            print("DEBUG: MessageListViewModel - Load completed successfully")
            
        } catch {
            print("DEBUG: MessageListViewModel - Error: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func loadUnreadCounts() async {
        guard let currentUserId = currentUserId else { return }
        
        print("DEBUG: MessageListViewModel - Loading unread counts for \(conversations.count) conversations")
        
        var newUnreadCounts: [String: Int] = [:]
        
        for conversation in conversations {
            await loadUnreadCountForConversation(conversation, into: &newUnreadCounts)
        }
        
        unreadCounts = newUnreadCounts
        print("DEBUG: MessageListViewModel - Unread counts loaded")
    }
    
    private func loadUnreadCountForConversation(_ conversation: PocketBaseConversation) async {
        var tempCounts = unreadCounts
        await loadUnreadCountForConversation(conversation, into: &tempCounts)
        unreadCounts = tempCounts
    }
    
    private func loadUnreadCountForConversation(_ conversation: PocketBaseConversation, into counts: inout [String: Int]) async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            let count = try await messagesManager.getUnreadMessageCount(
                for: conversation.id,
                userId: currentUserId
            )
            counts[conversation.id] = count
        } catch {
            print("DEBUG: MessageListViewModel - Failed to get unread count for \(conversation.id): \(error)")
            counts[conversation.id] = 0
        }
    }
}