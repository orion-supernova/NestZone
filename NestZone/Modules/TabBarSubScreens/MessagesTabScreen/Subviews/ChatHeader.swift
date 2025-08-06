import SwiftUI

struct ChatHeader: View {
    let conversation: PocketBaseConversation
    let onBackTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button {
                    onBackTapped()
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
                    ChatAvatar(conversation: conversation)
                    
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
                
                // Info button for group chats
                if conversation.isGroupChat {
                    Button {
                        // TODO: Show chat info
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            
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

struct ChatAvatar: View {
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
                .frame(width: 36, height: 36)
            
            Text(conversation.isGroupChat ? "GC" : "DM")
                .font(.system(size: 14, weight: .bold))
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
}