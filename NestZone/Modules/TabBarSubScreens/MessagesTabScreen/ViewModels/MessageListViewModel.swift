import SwiftUI
import Foundation
import Combine
import ConvexMobile

@MainActor
class MessageListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var conversations: [PocketBaseConversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var unreadCounts: [String: Int] = [:]

    // MARK: - Private Properties
    private let messagesManager = MessagesManager.shared
    private var currentUserId: String?
    private var homeChangeObserver: NSObjectProtocol?
    /// Live Convex subscription to the home's conversations.
    private var conversationsSubscription: AnyCancellable?

    // MARK: - Initialization
    init() {
        setupHomeChangeObserver()
    }

    deinit {
        if let observer = homeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupHomeChangeObserver() {
        homeChangeObserver = NotificationCenter.default.addObserver(
            forName: .homeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.subscribeConversations() }
        }
    }

    // MARK: - Public Methods
    func setup(authManager: ConvexAuthManager) {
        self.currentUserId = authManager.currentUser?.id
        subscribeConversations()
    }

    func refresh() async {
        subscribeConversations()
    }

    func addNewConversation(_ conversation: PocketBaseConversation) {
        // The live subscription will surface it; insert optimistically for immediacy.
        if !conversations.contains(where: { $0.id == conversation.id }) {
            conversations.insert(conversation, at: 0)
        }
        Task { await loadUnreadCountForConversation(conversation) }
    }

    // MARK: - Subscription
    private func subscribeConversations() {
        guard let homeId = HomeSelectionManager.shared.selectedHomeId else {
            conversations = []
            conversationsSubscription = nil
            return
        }

        isLoading = true
        conversationsSubscription = Convex.client
            .subscribe(to: "conversations:listByHome", with: ["homeId": homeId], yielding: [PocketBaseConversation].self)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] convos in
                guard let self else { return }
                self.isLoading = false
                // Most-recent activity first.
                self.conversations = convos.sorted {
                    ($0.lastMessageAt ?? $0.updated ?? 0) > ($1.lastMessageAt ?? $1.updated ?? 0)
                }
                Task { await self.loadUnreadCounts() }
            }
    }

    // MARK: - Unread counts
    private func loadUnreadCounts() async {
        guard currentUserId != nil else { return }
        var newUnreadCounts: [String: Int] = [:]
        for conversation in conversations {
            await loadUnreadCountForConversation(conversation, into: &newUnreadCounts)
        }
        unreadCounts = newUnreadCounts
    }

    private func loadUnreadCountForConversation(_ conversation: PocketBaseConversation) async {
        var tempCounts = unreadCounts
        await loadUnreadCountForConversation(conversation, into: &tempCounts)
        unreadCounts = tempCounts
    }

    private func loadUnreadCountForConversation(_ conversation: PocketBaseConversation, into counts: inout [String: Int]) async {
        guard let currentUserId = currentUserId else { return }
        do {
            counts[conversation.id] = try await messagesManager.getUnreadMessageCount(
                for: conversation.id, userId: currentUserId
            )
        } catch {
            counts[conversation.id] = 0
        }
    }
}
