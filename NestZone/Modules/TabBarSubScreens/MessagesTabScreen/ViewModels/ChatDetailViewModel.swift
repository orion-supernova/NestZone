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
    private let realtimeManager = PocketBaseRealtimeManager.shared
    private let conversation: PocketBaseConversation
    private let currentUserId: String
    private var onMessageSent: (() -> Void)?
    private var hasInitialLoad = false
    private var isSubscribedToRealtime = false
    
    // MARK: - Initialization
    init(conversation: PocketBaseConversation, currentUserId: String, onMessageSent: (() -> Void)? = nil) {
        self.conversation = conversation
        self.currentUserId = currentUserId
        self.onMessageSent = onMessageSent
        
        print("DEBUG: ChatDetailViewModel initialized for conversation: \(conversation.id)")
        
        // Load messages only
        Task {
            await loadMessages()
        }
    }
    
    deinit {
        print("DEBUG: ChatDetailViewModel - deinit called")
        // Clean up realtime subscription synchronously
        Task { @MainActor in
            await cleanupRealtimeSubscription()
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
            
            // Add to local messages immediately if not already there (from realtime)
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
            
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
    
    func onViewAppear() async {
        // Prevent duplicate subscriptions
        guard !isSubscribedToRealtime else {
            print("DEBUG: ChatDetailViewModel - Already subscribed, skipping setup")
            return
        }
        await setupRealtimeSubscription()
    }
    
    func onViewDisappear() async {
        await cleanupRealtimeSubscription()
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
    
    // MARK: - Realtime Support
    
    private func setupRealtimeSubscription() async {
        guard !isSubscribedToRealtime else {
            print("DEBUG: ChatDetailViewModel - Already subscribed to realtime")
            return
        }
        
        print("DEBUG: ChatDetailViewModel - Setting up realtime subscription for conversation: \(conversation.id)")
        
        do {
            print("DEBUG: ChatDetailViewModel - Creating callback closure")
            
            try await realtimeManager.subscribe(to: "messages") { [weak self] event in
                print("DEBUG: ChatDetailViewModel - Callback triggered with event: \(event.action)")
                guard let self = self else { 
                    print("DEBUG: ChatDetailViewModel - Self is nil in callback")
                    return 
                }
                Task { @MainActor in
                    print("DEBUG: ChatDetailViewModel - Processing event on main actor")
                    await self.handleRealtimeEvent(event)
                }
            }
            
            isSubscribedToRealtime = true
            print("DEBUG: ChatDetailViewModel - Successfully subscribed to realtime updates")
            
        } catch {
            print("DEBUG: ChatDetailViewModel - Failed to setup realtime subscription: \(error)")
            // Don't show error to user for realtime failures, just log them
            print("DEBUG: Chat will work without realtime updates")
        }
    }
    
    private func cleanupRealtimeSubscription() async {
        guard isSubscribedToRealtime else { 
            print("DEBUG: ChatDetailViewModel - Not subscribed, skipping cleanup")
            return 
        }
        
        print("DEBUG: ChatDetailViewModel - Cleaning up realtime subscription")
        
        do {
            try await realtimeManager.unsubscribe(from: "messages")
            isSubscribedToRealtime = false
            print("DEBUG: ChatDetailViewModel - Successfully unsubscribed from realtime")
        } catch {
            print("DEBUG: ChatDetailViewModel - Failed to unsubscribe from realtime: \(error)")
        }
    }
    
    private func handleRealtimeEvent(_ event: PocketBaseRealtimeEvent) async {
        print("DEBUG: ChatDetailViewModel - Received realtime event: \(event.action)")
        print("DEBUG: ChatDetailViewModel - Event record keys: \(event.record.keys)")
        
        do {
            // Try to decode the message from the event record
            let messageData = try JSONSerialization.data(withJSONObject: event.record)
            let message = try JSONDecoder().decode(PocketBaseMessage.self, from: messageData)
            
            print("DEBUG: ChatDetailViewModel - Parsed message: \(message.id) for conversation: \(message.conversationId)")
            
            // Only handle messages for this conversation
            guard message.conversationId == conversation.id else {
                print("DEBUG: ChatDetailViewModel - Message not for this conversation (\(conversation.id)), ignoring")
                return
            }
            
            switch event.action {
            case .create:
                // Add new message if not already present
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                    print("DEBUG: ChatDetailViewModel - Added new message from realtime: \(message.id)")
                    
                    // Mark as read if it's from another user
                    if message.senderId != currentUserId {
                        try await messagesManager.markMessageAsRead(messageId: message.id, userId: currentUserId)
                    }
                }
                
            case .update:
                // Update existing message
                if let index = messages.firstIndex(where: { $0.id == message.id }) {
                    messages[index] = message
                    print("DEBUG: ChatDetailViewModel - Updated message from realtime: \(message.id)")
                }
                
            case .delete:
                // Remove deleted message
                messages.removeAll { $0.id == message.id }
                print("DEBUG: ChatDetailViewModel - Removed deleted message from realtime: \(message.id)")
            }
            
        } catch {
            print("DEBUG: ChatDetailViewModel - Failed to parse realtime message: \(error)")
            print("DEBUG: ChatDetailViewModel - Raw event record: \(event.record)")
        }
    }
}