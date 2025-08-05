import SwiftUI
import Foundation

@MainActor
class ChatDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [PocketBaseMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var newMessageText = ""
    
    // MARK: - Private Properties
    private let messagesManager = MessagesManager.shared
    private let conversation: PocketBaseConversation
    private let currentUserId: String
    private var onMessageSent: (() -> Void)?
    private var hasInitialLoad = false
    
    // MARK: - Initialization
    init(conversation: PocketBaseConversation, currentUserId: String, onMessageSent: (() -> Void)? = nil) {
        self.conversation = conversation
        self.currentUserId = currentUserId
        self.onMessageSent = onMessageSent
        
        print("DEBUG: ChatDetailViewModel initialized for conversation: \(conversation.id)")
        
        // Load messages only once
        Task {
            await loadMessages()
        }
    }
    
    // MARK: - Public Methods
    func loadMessages() async {
        // Only load once unless explicitly refreshed
        guard !hasInitialLoad else {
            print("DEBUG: ChatDetailViewModel - Messages already loaded")
            return
        }
        
        isLoading = true
        errorMessage = nil
        hasInitialLoad = true
        
        print("DEBUG: ChatDetailViewModel - Loading messages for: \(conversation.id)")
        
        do {
            let loadedMessages = try await messagesManager.fetchMessages(for: conversation.id)
            messages = loadedMessages
            print("DEBUG: ChatDetailViewModel - Loaded \(loadedMessages.count) messages")
            
            // Mark messages as read
            await markMessagesAsRead()
            
        } catch {
            print("DEBUG: ChatDetailViewModel - Error loading messages: \(error)")
            errorMessage = "Failed to load messages"
        }
        
        isLoading = false
    }
    
    func sendMessage() async {
        let messageText = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        print("DEBUG: ChatDetailViewModel - Sending message: \(messageText)")
        
        // Clear input immediately
        let textToSend = messageText
        newMessageText = ""
        
        do {
            let message = try await messagesManager.sendMessage(
                conversationId: conversation.id,
                senderId: currentUserId,
                content: textToSend
            )
            
            print("DEBUG: ChatDetailViewModel - Message sent successfully: \(message.id)")
            
            // Add to local messages immediately
            messages.append(message)
            
            // Notify parent that a message was sent
            onMessageSent?()
            
        } catch {
            print("DEBUG: ChatDetailViewModel - Error sending message: \(error)")
            // Restore text if sending failed
            newMessageText = textToSend
            errorMessage = "Failed to send message"
        }
    }
    
    func canSendMessage() -> Bool {
        return !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Private Methods
    private func markMessagesAsRead() async {
        let unreadMessages = messages.filter { !$0.readBy.contains(currentUserId) && $0.senderId != currentUserId }
        
        guard !unreadMessages.isEmpty else {
            print("DEBUG: ChatDetailViewModel - No unread messages to mark")
            return
        }
        
        print("DEBUG: ChatDetailViewModel - Marking \(unreadMessages.count) messages as read")
        
        for message in unreadMessages {
            do {
                try await messagesManager.markMessageAsRead(messageId: message.id, userId: currentUserId)
            } catch {
                print("DEBUG: ChatDetailViewModel - Failed to mark message as read: \(error)")
            }
        }
    }
}