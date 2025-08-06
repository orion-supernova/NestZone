import SwiftUI

struct ChatHeader: View {
    let conversation: PocketBaseConversation
    let onBackTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: onBackTapped) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                
                // Avatar and Title
                HStack(spacing: 12) {
                    ModernChatAvatar(conversation: conversation)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(getTitle())
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(conversation.participants.count) members")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Info button for group chats
                if conversation.isGroupChat {
                    Button {
                        // TODO: Show chat info
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            Divider()
        }
    }
    
    private func getTitle() -> String {
        if conversation.isGroupChat {
            return conversation.title ?? "Group Chat"
        } else {
            return "Direct Message"
        }
    }
}

struct ModernChatAvatar: View {
    let conversation: PocketBaseConversation
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
            
            Text(conversation.isGroupChat ? "GC" : "DM")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    VStack {
        ChatHeader(
            conversation: PocketBaseConversation(
                id: "test",
                participants: ["user1", "user2", "user3"],
                homeId: "home1",
                isGroupChat: true,
                title: "Family Chat",
                lastMessage: "Hello",
                lastMessageAt: "2025-01-01T00:00:00Z",
                created: "2025-01-01T00:00:00Z",
                updated: "2025-01-01T00:00:00Z"
            ),
            onBackTapped: {}
        )
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}