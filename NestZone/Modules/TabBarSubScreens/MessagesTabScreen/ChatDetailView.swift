import SwiftUI

struct ChatDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @State private var messages: [PocketBaseMessage] = []
    @State private var newMessageText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isMessageFieldFocused: Bool
    
    let conversation: PocketBaseConversation
    let currentUserId: String
    var onMessageSent: (() -> Void)? = nil  // Callback to refresh parent view
    
    private let messagesManager = MessagesManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                
                // Avatar and Title
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Text(conversation.isGroupChat ? "GC" : "DM")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(getTitle())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(conversation.participants.count) members")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            
            Divider()
            
            // Messages List
            if isLoading && messages.isEmpty {
                loadingView
            } else if messages.isEmpty {
                emptyMessagesView
            } else {
                messagesList
            }
            
            // Message Input
            messageInputView
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await loadMessages()
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading messages...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.6))
            
            Text("No Messages Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Be the first to send a message!")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages, id: \.id) { message in
                        MessageBubble(
                            message: message,
                            isCurrentUser: message.senderId == currentUserId
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Type a message...", text: $newMessageText)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .focused($isMessageFieldFocused)
                    .onSubmit {
                        Task {
                            await sendMessage()
                        }
                    }
                
                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: canSend ? [Color.blue, Color.purple] : [Color.gray.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
        }
    }
    
    private var canSend: Bool {
        !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func getTitle() -> String {
        if conversation.isGroupChat {
            return conversation.title ?? "Group Chat"
        } else {
            return "Direct Message"
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        // First test if messages collection exists
        await messagesManager.testMessagesCollection()
        
        do {
            print("DEBUG: Loading messages for conversation: \(conversation.id)")
            messages = try await messagesManager.fetchMessages(for: conversation.id)
            print("DEBUG: Loaded \(messages.count) messages")
            
            // Mark any unread messages as read
            for message in messages where !message.readBy.contains(currentUserId) && message.senderId != currentUserId {
                do {
                    try await messagesManager.markMessageAsRead(messageId: message.id, userId: currentUserId)
                } catch {
                    print("DEBUG: Failed to mark message as read: \(error)")
                }
            }
        } catch {
            print("DEBUG: Error loading messages: \(error)")
            if let pocketBaseError = error as? PocketBaseManager.PocketBaseError {
                switch pocketBaseError {
                case .badRequest:
                    // Messages collection might not exist yet - this is normal for new conversations
                    print("DEBUG: Messages collection not ready yet - showing empty state")
                case .notFound:
                    print("DEBUG: Conversation not found or messages collection doesn't exist")
                    // Don't show error for this case - just show empty state
                default:
                    errorMessage = pocketBaseError.localizedDescription
                }
            } else {
                errorMessage = "Failed to load messages"
            }
        }
        
        isLoading = false
    }
    
    private func sendMessage() async {
        let messageText = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        // Clear input immediately for better UX
        newMessageText = ""
        
        do {
            print("DEBUG: Sending message: \(messageText)")
            let message = try await messagesManager.sendMessage(
                conversationId: conversation.id,
                senderId: currentUserId,
                content: messageText
            )
            
            print("DEBUG: Message sent successfully: \(message.id)")
            print("DEBUG: Conversation should now be updated with latest message")
            
            // Add message to local array immediately
            messages.append(message)
            
            // Notify parent view to refresh
            onMessageSent?()
            
        } catch {
            print("DEBUG: Error sending message: \(error)")
            // Restore the message text if sending failed
            newMessageText = messageText
            errorMessage = "Failed to send message"
        }
    }
}

struct MessageBubble: View {
    let message: PocketBaseMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                    // Show file preview if there's a file
                    if let file = message.file, !file.isEmpty {
                        filePreview(file: file, messageType: message.messageType)
                    }
                    
                    // Show text content if it's not empty
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isCurrentUser ? .white : .primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            isCurrentUser ? 
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.1)],
                                startPoint: .center,
                                endPoint: .center
                            )
                        )
                )
                
                Text(formatTime())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 40)
            }
        }
    }
    
    @ViewBuilder
    private func filePreview(file: String, messageType: PocketBaseMessage.MessageType) -> some View {
        switch messageType {
        case .image, .gif:
            // For now, show a placeholder - in the future this could load the actual image
            HStack(spacing: 8) {
                Image(systemName: messageType == .gif ? "play.rectangle.fill" : "photo.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .blue)
                
                Text(messageType == .gif ? "GIF" : "Photo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .primary)
            }
            
        case .video:
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .blue)
                
                Text("Video")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .primary)
            }
            
        case .document:
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .blue)
                
                Text("Document")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .primary)
            }
            
        case .audio:
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .blue)
                
                Text("Audio")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .primary)
            }
            
        case .text, .system:
            EmptyView()
        }
    }
    
    private func formatTime() -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: message.created) else {
            return ""
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "HH:mm"
        return displayFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(
            conversation: PocketBaseConversation(
                id: "test",
                participants: ["user1", "user2"],
                homeId: "home1",
                isGroupChat: true,
                title: "Test Chat",
                lastMessage: "Hello",
                lastMessageAt: "2025-01-01T00:00:00Z",
                created: "2025-01-01T00:00:00Z",
                updated: "2025-01-01T00:00:00Z"
            ),
            currentUserId: "user1"
        )
    }
}