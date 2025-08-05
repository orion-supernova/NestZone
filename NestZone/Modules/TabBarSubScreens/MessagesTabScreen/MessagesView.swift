import SwiftUI

struct MessagesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @State private var conversations: [PocketBaseConversation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingNewMessage = false
    @State private var currentHome: Home?
    @State private var unreadCounts: [String: Int] = [:]
    @State private var selectedConversation: PocketBaseConversation?
    @State private var refreshTimer: Timer?
    
    private let messagesManager = MessagesManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with colorful gradients
                RadialGradient(
                    colors: [
                        selectedTheme.colors(for: colorScheme).background,
                        Color.blue.opacity(0.05),
                        Color.cyan.opacity(0.03)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
                
                // Floating colorful shapes
                GeometryReader { geometry in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .offset(x: geometry.size.width - 60, y: 50)
                        .blur(radius: 30)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.4), Color.pink.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .offset(x: 20, y: geometry.size.height * 0.7)
                        .blur(radius: 35)
                }
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Messages")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Spacer()
                        
                        Button {
                            showingNewMessage = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Content
                    if isLoading {
                        loadingView
                    } else if conversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationsList
                    }
                }
            }
            .onAppear {
                print("DEBUG: MessagesView appeared - refreshing conversations")
                Task {
                    await loadData()
                }
                startPeriodicRefresh()
            }
            .onDisappear {
                stopPeriodicRefresh()
            }
            .refreshable {
                print("DEBUG: Pull to refresh triggered")
                await loadData()
            }
            .fullScreenCover(isPresented: $showingNewMessage) {
                NewMessageView(
                    home: currentHome,
                    currentUserId: authManager.currentUser?.id ?? ""
                ) { newConversation in
                    // Add new conversation and refresh the list to get updated data
                    conversations.insert(newConversation, at: 0)
                    Task {
                        print("DEBUG: New conversation created - refreshing conversation list")
                        await loadDataSilently()
                    }
                }
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatDetailView(
                    conversation: conversation,
                    currentUserId: authManager.currentUser?.id ?? ""
                )
                .onDisappear {
                    // Add a delay before refreshing to ensure server updates are complete
                    print("DEBUG: Returned from chat detail - refreshing conversations with delay")
                    Task {
                        // Wait a moment for server to process any pending updates
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                        await loadData() // Use full refresh instead of silent to ensure we get latest data
                    }
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
    }
    
    private func loadData() async {
        guard let currentUser = authManager.currentUser else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("DEBUG: Starting fresh data load for conversations")
        
        do {
            // Get user's home info
            let pocketBase = PocketBaseManager.shared
            let userResponse: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(currentUser.id)",
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            print("DEBUG: User response: \(userResponse)")
            print("DEBUG: User home_id: \(userResponse.home_id)")
            
            guard let homeId = userResponse.home_id.first else {
                errorMessage = "No home found"
                isLoading = false
                return
            }
            
            print("DEBUG: Loading data for home ID: \(homeId)")
            
            // Get home details
            let home: Home = try await pocketBase.request(
                endpoint: "/api/collections/homes/records/\(homeId)",
                requiresAuth: true,
                responseType: Home.self
            )
            
            currentHome = home
            print("DEBUG: Home loaded: \(home.name) with \(home.members.count) members")
            
            // Load conversations (this will get the latest from server)
            print("DEBUG: Fetching fresh conversations for home: \(homeId)")
            let freshConversations = try await messagesManager.fetchConversations(for: homeId)
            print("DEBUG: Found \(freshConversations.count) conversations")
            
            // Update conversations array
            conversations = freshConversations
            
            // Clear old unread counts and load fresh ones
            unreadCounts = [:]
            for conversation in conversations {
                print("DEBUG: Loading unread count for conversation: \(conversation.id)")
                do {
                    let unreadCount = try await messagesManager.getUnreadMessageCount(
                        for: conversation.id,
                        userId: currentUser.id
                    )
                    unreadCounts[conversation.id] = unreadCount
                    print("DEBUG: Conversation \(conversation.id) has \(unreadCount) unread messages")
                } catch {
                    print("DEBUG: Failed to get unread count for conversation \(conversation.id): \(error)")
                    unreadCounts[conversation.id] = 0
                }
            }
            
            print("DEBUG: Data refresh completed successfully")
            
        } catch {
            print("DEBUG: Error loading messages data: \(error)")
            if let pocketBaseError = error as? PocketBaseManager.PocketBaseError {
                errorMessage = pocketBaseError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    private func startPeriodicRefresh() {
        stopPeriodicRefresh() // Stop any existing timer
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            print("DEBUG: Periodic refresh triggered")
            Task {
                await loadDataSilently()
            }
        }
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // Silent refresh that doesn't show loading indicator
    private func loadDataSilently() async {
        guard let currentUser = authManager.currentUser else { return }
        
        do {
            // Get user's home info
            let pocketBase = PocketBaseManager.shared
            let userResponse: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(currentUser.id)",
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            print("DEBUG: User response: \(userResponse)")
            print("DEBUG: User home_id: \(userResponse.home_id)")
            
            guard let homeId = userResponse.home_id.first else { return }
            
            print("DEBUG: Loading data for home ID: \(homeId)")
            
            // Silently fetch fresh conversations
            let freshConversations = try await messagesManager.fetchConversations(for: homeId)
            
            // Update conversations if there are changes
            if freshConversations.count != conversations.count ||
               !freshConversations.elementsEqual(conversations, by: { $0.id == $1.id && $0.updated == $1.updated }) {
                print("DEBUG: Conversations updated during silent refresh")
                conversations = freshConversations
                
                // Update unread counts for new/changed conversations
                for conversation in conversations {
                    if unreadCounts[conversation.id] == nil {
                        let unreadCount = try await messagesManager.getUnreadMessageCount(
                            for: conversation.id,
                            userId: currentUser.id
                        )
                        unreadCounts[conversation.id] = unreadCount
                    }
                }
            }
            
        } catch {
            print("DEBUG: Silent refresh failed: \(error)")
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 16)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 14)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .redacted(reason: .placeholder)
            }
        }
        .padding(.top, 30)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No Messages Yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Create a group chat to stay connected with your household")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingNewMessage = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.message.fill")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Create Group Chat")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(conversations, id: \.id) { conversation in
                    ConversationCard(
                        conversation: conversation,
                        home: currentHome,
                        unreadCount: unreadCounts[conversation.id] ?? 0,
                        currentUserId: authManager.currentUser?.id ?? ""
                    )
                    .padding(.horizontal, 24)
                    .onTapGesture {
                        selectedConversation = conversation
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
    }
}

struct ConversationCard: View {
    let conversation: PocketBaseConversation
    let home: Home?
    let unreadCount: Int
    let currentUserId: String
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text(getInitials())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Online indicator (placeholder for now)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .offset(x: 18, y: 18)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(getTitle())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                    
                    Spacer()
                    
                    Text(formatDate())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(conversation.lastMessage ?? "No messages yet")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func getInitials() -> String {
        if conversation.isGroupChat {
            return "GC"
        }
        
        // For now, just show generic initials since we don't have user details
        return "HM" // Household Member
    }
    
    private func getTitle() -> String {
        if conversation.isGroupChat {
            return conversation.title ?? "Household Chat"
        } else {
            // Get the other participant count
            let otherParticipants = conversation.participants.filter { $0 != currentUserId }
            if otherParticipants.count == 1 {
                return "Direct Message"
            } else {
                return "Chat"
            }
        }
    }
    
    private func formatDate() -> String {
        guard let lastMessageAt = conversation.lastMessageAt,
              !lastMessageAt.isEmpty else {
            return ""
        }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: lastMessageAt) else {
            return ""
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "HH:mm"
        return displayFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        MessagesView()
            .environmentObject(PocketBaseAuthManager())
    }
}