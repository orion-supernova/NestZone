import SwiftUI

struct MessageBubble: View {
    let message: PocketBaseMessage
    let isCurrentUser: Bool
    let conversation: PocketBaseConversation
    
    @StateObject private var userService = UserService.shared
    @State private var senderName: String = ""
    @State private var showingReadReceipts = false
    @State private var readByUsers: [PocketBaseUser] = []
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (only show for group chats and non-current users)
                if conversation.isGroupChat && !isCurrentUser && !senderName.isEmpty {
                    Text(senderName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                // Message content bubble
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                    if let file = message.file, !file.isEmpty {
                        filePreview(file: file, messageType: message.messageType)
                    }
                    
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isCurrentUser ? .white : .primary)
                            .textSelection(.enabled)
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
                .onLongPressGesture {
                    if isCurrentUser && message.readBy.count > 1 {
                        Task {
                            await loadReadReceipts()
                            showingReadReceipts = true
                        }
                    }
                }
                
                // Time and read status
                HStack(spacing: 8) {
                    Text(formatTime())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if isCurrentUser {
                        readStatusView
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            Task {
                await loadSenderName()
            }
        }
        .sheet(isPresented: $showingReadReceipts) {
            ReadReceiptsSheet(
                message: message,
                readByUsers: readByUsers
            )
        }
    }
    
    @ViewBuilder
    private var readStatusView: some View {
        let readCount = message.readBy.count - 1 // Exclude sender
        
        if readCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: readCount == conversation.participants.count - 1 ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundColor(readCount == conversation.participants.count - 1 ? .blue : .secondary)
                
                if readCount > 1 {
                    Text("\(readCount)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func filePreview(file: String, messageType: PocketBaseMessage.MessageType) -> some View {
        switch messageType {
        case .image, .gif:
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
        
        let now = Date()
        let calendar = Calendar.current
        
        // Check if it's today
        if calendar.isDate(date, inSameDayAs: now) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        }
        
        // Check if it's yesterday
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        
        // Check if it's this week
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE" // Day name
            return dayFormatter.string(from: date)
        }
        
        // Older dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        return dateFormatter.string(from: date)
    }
    
    private func loadSenderName() async {
        if let user = await userService.getUser(id: message.senderId) {
            senderName = user.name ?? "User"
        } else {
            // Fallback to a generated name based on user ID
            senderName = "User \(String(message.senderId.suffix(4)))"
        }
    }
    
    private func loadReadReceipts() async {
        let userIds = message.readBy.filter { $0 != message.senderId }
        let users = await userService.getUsers(ids: userIds)
        readByUsers = Array(users.values)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubble(
            message: PocketBaseMessage(
                id: "1",
                conversationId: "conv1",
                senderId: "user1",
                content: "Hello everyone! How are you doing today?",
                messageType: .text,
                file: nil,
                readBy: ["user1", "user2", "user3"],
                created: "2025-01-01T12:00:00Z",
                updated: "2025-01-01T12:00:00Z"
            ),
            isCurrentUser: false,
            conversation: PocketBaseConversation(
                id: "conv1",
                participants: ["user1", "user2", "user3"],
                homeId: "home1",
                isGroupChat: true,
                title: "Family Chat",
                lastMessage: "Hello",
                lastMessageAt: "2025-01-01T12:00:00Z",
                created: "2025-01-01T00:00:00Z",
                updated: "2025-01-01T12:00:00Z"
            )
        )
        
        MessageBubble(
            message: PocketBaseMessage(
                id: "2",
                conversationId: "conv1",
                senderId: "user2",
                content: "I'm doing great! Thanks for asking 😊",
                messageType: .text,
                file: nil,
                readBy: ["user2"],
                created: "2025-01-01T12:05:00Z",
                updated: "2025-01-01T12:05:00Z"
            ),
            isCurrentUser: true,
            conversation: PocketBaseConversation(
                id: "conv1",
                participants: ["user1", "user2", "user3"],
                homeId: "home1",
                isGroupChat: true,
                title: "Family Chat",
                lastMessage: "Hello",
                lastMessageAt: "2025-01-01T12:05:00Z",
                created: "2025-01-01T00:00:00Z",
                updated: "2025-01-01T12:05:00Z"
            )
        )
    }
    .padding()
}