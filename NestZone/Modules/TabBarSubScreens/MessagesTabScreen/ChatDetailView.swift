import SwiftUI

struct ChatDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatDetailViewModel
    @StateObject private var userService = UserService.shared
    @FocusState private var isMessageFieldFocused: Bool
    
    let conversation: PocketBaseConversation
    let currentUserId: String
    var onMessageSent: (() -> Void)?
    
    init(conversation: PocketBaseConversation, currentUserId: String, onMessageSent: (() -> Void)? = nil) {
        self.conversation = conversation
        self.currentUserId = currentUserId
        self.onMessageSent = onMessageSent
        self._viewModel = StateObject(wrappedValue: ChatDetailViewModel(
            conversation: conversation,
            currentUserId: currentUserId,
            onMessageSent: onMessageSent
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeader(conversation: conversation) {
                dismiss()
            }
            
            // Messages List
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ChatLoadingView()
            } else if viewModel.messages.isEmpty {
                ChatEmptyView()
            } else {
                ChatMessagesList(
                    messages: viewModel.messages,
                    conversation: conversation,
                    currentUserId: currentUserId
                )
            }
            
            // Message Input
            ChatMessageInputView(
                messageText: $viewModel.newMessageText,
                isMessageFieldFocused: $isMessageFieldFocused,
                canSendMessage: viewModel.canSendMessage(),
                onSendMessage: {
                    await viewModel.sendMessage()
                }
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            print("DEBUG: ChatDetailView - onAppear called")
            Task {
                await viewModel.onViewAppear()
                // Pre-load user data for message senders
                await preloadUserData()
            }
        }
        .onDisappear {
            print("DEBUG: ChatDetailView - onDisappear called")
            Task {
                await viewModel.onViewDisappear()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private func preloadUserData() async {
        let uniqueSenderIds = Set(viewModel.messages.map { $0.senderId })
        let _ = await userService.getUsers(ids: Array(uniqueSenderIds))
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(
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
            ),
            currentUserId: "user1"
        )
    }
}