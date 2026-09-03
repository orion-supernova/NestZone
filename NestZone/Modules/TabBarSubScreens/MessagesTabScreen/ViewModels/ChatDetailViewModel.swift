import SwiftUI
import Foundation
import Combine
import ConvexMobile

@MainActor
class ChatDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [PocketBaseMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var newMessageText = ""
    @Published var userCache: [String: PocketBaseUser] = [:]

    // MARK: - Private Properties
    private let messagesManager = MessagesManager.shared
    private let userService = UserService.shared
    private let conversation: PocketBaseConversation
    private let currentUserId: String
    private var onMessageSent: (() -> Void)?

    /// Live Convex subscription to this conversation's messages. Replaces the entire
    /// PocketBase SSE realtime manager: new/updated messages are pushed automatically.
    private var messagesSubscription: AnyCancellable?

    // MARK: - Initialization
    init(conversation: PocketBaseConversation, currentUserId: String, onMessageSent: (() -> Void)? = nil) {
        self.conversation = conversation
        self.currentUserId = currentUserId
        self.onMessageSent = onMessageSent
    }

    // MARK: - Lifecycle
    func onViewAppear() async {
        subscribeToMessages()
    }

    func onViewDisappear() async {
        messagesSubscription?.cancel()
        messagesSubscription = nil
    }

    /// Explicit refresh (e.g. pull-to-refresh). The live subscription already keeps
    /// `messages` current, so this just (re)establishes it.
    func loadMessages() async {
        subscribeToMessages()
    }

    // MARK: - Subscription
    private func subscribeToMessages() {
        guard messagesSubscription == nil else { return }
        isLoading = true

        messagesSubscription = Convex.client
            .subscribe(
                to: "messages:listByConversation",
                with: ["conversationId": conversation.id, "limit": 200],
                yielding: [PocketBaseMessage].self
            )
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                guard let self else { return }
                self.isLoading = false
                self.messages = msgs   // server returns oldest -> newest
                Task {
                    await self.loadUserData()
                    // Mark anything not from us as read while the chat is open.
                    try? await self.messagesManager.markConversationRead(conversationId: self.conversation.id)
                }
            }
    }

    // MARK: - Users
    func loadUserData() async {
        var userIds = Set<String>()
        for message in messages {
            userIds.insert(message.senderId)
            userIds.formUnion(message.readBy)
        }
        userIds.formUnion(conversation.participants)
        userCache = await userService.getUsers(ids: Array(userIds))
    }

    func getUserName(for userId: String) -> String {
        userCache[userId]?.name ?? userService.getUserName(for: userId)
    }

    // MARK: - Sending
    func sendMessage() async {
        let messageText = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }

        let textToSend = messageText
        newMessageText = ""   // clear input immediately (optimistic)

        do {
            // No local append needed — the live subscription delivers the new message.
            try await messagesManager.sendMessage(conversationId: conversation.id, content: textToSend)
            onMessageSent?()
        } catch {
            newMessageText = textToSend   // restore on failure
            errorMessage = "Failed to send message"
        }
    }

    func canSendMessage() -> Bool {
        !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
