import SwiftUI

struct ChatMessagesList: View {
    let messages: [PocketBaseMessage]
    let conversation: PocketBaseConversation
    let currentUserId: String
    
    @FocusState.Binding var isInputFocused: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let previousMessage = index > 0 ? messages[index - 1] : nil
                        let nextMessage = index < messages.count - 1 ? messages[index + 1] : nil
                        
                        MessageBubble(
                            message: message,
                            previousMessage: previousMessage,
                            nextMessage: nextMessage,
                            isCurrentUser: message.senderId == currentUserId,
                            conversation: conversation
                        )
                        .id(message.id)
                    }
                    
                    // Spacer to ensure last message is visible above keyboard
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere on the messages list
                isInputFocused = false
            }
            .onAppear {
                // Scroll to bottom when view appears with a small delay to ensure layout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                // Scroll to bottom when new messages arrive
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                // Scroll to bottom when keyboard appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview("Messages List Preview") {
    struct PreviewWrapper: View {
        @FocusState private var isInputFocused: Bool
        
        var body: some View {
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
                        senderId: "user2",
                        content: "Good morning! Beautiful day today 🌞",
                        messageType: .text,
                        file: nil,
                        readBy: ["user2", "user1"],
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
                currentUserId: "user1",
                isInputFocused: $isInputFocused
            )
        }
    }
    
    return PreviewWrapper()
}