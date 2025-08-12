import SwiftUI

struct ChatHeader: View {
    let conversation: PocketBaseConversation
    let onBackTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button {
                onBackTapped()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(LocalizationManager.messagesChatHeaderBack)
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(getTitle())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if conversation.isGroupChat {
                    Text(LocalizationManager.messagesChatMembersCount(conversation.participants.count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Profile/More button placeholder
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }
    
    private func getTitle() -> String {
        if conversation.isGroupChat {
            return conversation.title ?? LocalizationManager.messagesConversationCardHouseholdChat
        } else {
            return LocalizationManager.messagesConversationCardDirectMessage
        }
    }
}

#Preview {
    ChatHeader(
        conversation: PocketBaseConversation(
            id: "test",
            participants: ["user1", "user2", "user3"],
            homeId: "home1",
            isGroupChat: true,
            title: "Family Chat",
            lastMessage: "Hello everyone!",
            lastMessageAt: "2025-01-01T00:00:00Z",
            created: "2025-01-01T00:00:00Z",
            updated: "2025-01-01T00:00:00Z"
        )
    ) {
        // Back action
    }
}