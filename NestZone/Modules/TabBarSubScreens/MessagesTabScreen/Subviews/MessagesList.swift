import SwiftUI

struct ChatMessagesList: View {
    let messages: [PocketBaseMessage]
    let conversation: PocketBaseConversation
    let currentUserId: String
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages, id: \.id) { message in
                        MessageBubble(
                            message: message,
                            isCurrentUser: message.senderId == currentUserId,
                            conversation: conversation
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
}

#Preview {
    ChatMessagesList(
        messages: [
            PocketBaseMessage(
                id: "1",
                conversationId: "conv1",
                senderId: "user1",
                content: "Hey everyone!",
                messageType: .text,
                file: nil,
                readBy: ["user1", "user2"],
                created: "2025-01-01T10:00:00Z",
                updated: "2025-01-01T10:00:00Z"
            ),
            PocketBaseMessage(
                id: "2",
                conversationId: "conv1",
                senderId: "user2",
                content: "Hello! How's everyone doing?",
                messageType: .text,
                file: nil,
                readBy: ["user2"],
                created: "2025-01-01T10:05:00Z",
                updated: "2025-01-01T10:05:00Z"
            ),
            PocketBaseMessage(
                id: "3",
                conversationId: "conv1",
                senderId: "user3",
                content: "Good morning! Beautiful day today 🌞",
                messageType: .text,
                file: nil,
                readBy: ["user3", "user1"],
                created: "2025-01-01T10:10:00Z",
                updated: "2025-01-01T10:10:00Z"
            )
        ],
        conversation: PocketBaseConversation(
            id: "conv1",
            participants: ["user1", "user2", "user3"],
            homeId: "home1",
            isGroupChat: true,
            title: "Family Chat",
            lastMessage: "Good morning!",
            lastMessageAt: "2025-01-01T10:10:00Z",
            created: "2025-01-01T00:00:00Z",
            updated: "2025-01-01T10:10:00Z"
        ),
        currentUserId: "user2"
    )
}